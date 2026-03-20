#!/usr/bin/env python3
"""
VMBuilder — Automated Windows 11 25H2 Malware Analysis VM Builder

Two-phase build:
  Phase 1 (base):      ISO boot -> OS install -> VMware Tools -> shutdown
  Phase 2 (provision): Clone base VM -> tool install -> hardening -> verify

Usage:
    python build.py                          # full build (Phase 1 + 2)
    python build.py --config myconfig.yaml   # custom config
    python build.py --resume                 # skip Phase 1, rerun Phase 2
    python build.py --skip-verify            # skip post-build verification
    python build.py --clean                  # remove all build artifacts
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install PyYAML")
    sys.exit(1)

try:
    import jsonschema
except ImportError:
    jsonschema = None

# Project root directory
ROOT_DIR = Path(__file__).resolve().parent


def hcl_path(p):
    """Normalize a path to forward slashes for HCL compatibility."""
    return str(p).replace("\\", "/")


def detect_vmware():
    """Auto-detect VMware product and vmrun path."""
    system = platform.system()

    if system == "Darwin":
        vmrun_paths = [
            "/Applications/VMware Fusion.app/Contents/Library/vmrun",
            "/Applications/VMware Fusion Tech Preview.app/Contents/Library/vmrun",
        ]
        vmrun_type = "fusion"
    elif system == "Linux":
        vmrun_paths = ["/usr/bin/vmrun"]
        vmrun_type = "ws"
    elif system == "Windows":
        vmrun_paths = [
            r"C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe",
            r"C:\Program Files\VMware\VMware Workstation\vmrun.exe",
        ]
        vmrun_type = "ws"
    else:
        return None, None

    for path in vmrun_paths:
        if os.path.isfile(path):
            return path, vmrun_type

    vmrun = shutil.which("vmrun")
    if vmrun:
        return vmrun, vmrun_type

    return None, vmrun_type


def check_prerequisites():
    """Verify that required tools are available."""
    errors = []

    packer = shutil.which("packer")
    if not packer:
        errors.append("Packer not found on PATH. Install from https://www.packer.io/downloads")

    vmrun, vmrun_type = detect_vmware()
    if not vmrun:
        errors.append(
            "vmrun not found. Install VMware Workstation (Windows/Linux) "
            "or VMware Fusion (macOS)."
        )

    iso_tools = ["xorriso", "mkisofs", "hdiutil", "oscdimg"]
    iso_tool = None
    for tool_name in iso_tools:
        found = shutil.which(tool_name)
        if found:
            iso_tool = found
            break

    if not iso_tool:
        system = platform.system()
        if system == "Windows":
            msg = (
                "No CD ISO creation tool found (need one of: xorriso, mkisofs, hdiutil, oscdimg).\n"
                "         Install mkisofs via Chocolatey:  choco install schily-cdrtools\n"
                "         Or install oscdimg from the Windows ADK:\n"
                "         https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install"
            )
        elif system == "Darwin":
            msg = (
                "No CD ISO creation tool found. hdiutil should be pre-installed on macOS.\n"
                "         If missing, install mkisofs:  brew install cdrtools"
            )
        else:
            msg = (
                "No CD ISO creation tool found (need one of: xorriso, mkisofs).\n"
                "         Install via your package manager, e.g.:\n"
                "           Ubuntu/Debian: sudo apt install xorriso\n"
                "           Fedora/RHEL:   sudo dnf install xorriso"
            )
        errors.append(msg)

    return errors, packer, vmrun, vmrun_type, iso_tool


def load_config(config_path):
    """Load and return the YAML configuration."""
    if not os.path.isfile(config_path):
        print(f"ERROR: Config file not found: {config_path}")
        sys.exit(1)

    with open(config_path) as f:
        config = yaml.safe_load(f)

    return config


def load_tools(tools_path, overrides=None):
    """Load tools.yaml and apply any overrides from config."""
    if not os.path.isfile(tools_path):
        print(f"ERROR: Tools file not found: {tools_path}")
        sys.exit(1)

    with open(tools_path) as f:
        tools_config = yaml.safe_load(f)

    if overrides:
        for tool in tools_config.get("tools", []):
            tool_name = tool.get("name")
            if tool_name in overrides:
                tool.update(overrides[tool_name])

    return tools_config


def validate_config(config, tools_config):
    """Validate the configuration."""
    errors = []

    if not config.get("iso", {}).get("path"):
        errors.append("iso.path is required in the config file")
    elif not os.path.isfile(config["iso"]["path"]):
        errors.append(f"ISO file not found: {config['iso']['path']}")

    vm = config.get("vm", {})
    cpus = vm.get("cpus", 4)
    memory = vm.get("memory_mb", 8192)
    disk = vm.get("disk_size_mb", 102400)

    if not 1 <= cpus <= 32:
        errors.append(f"vm.cpus must be between 1 and 32 (got {cpus})")
    if not 2048 <= memory <= 65536:
        errors.append(f"vm.memory_mb must be between 2048 and 65536 (got {memory})")
    if not 40960 <= disk <= 1048576:
        errors.append(f"vm.disk_size_mb must be between 40960 and 1048576 (got {disk})")

    enabled_tools = [t for t in tools_config.get("tools", []) if t.get("enabled")]
    for tool in enabled_tools:
        url = tool.get("url", "")
        if "PLACEHOLDER" in url.upper():
            errors.append(
                f"Tool '{tool['display_name']}' has a placeholder URL — "
                f"update it in tools.yaml or disable the tool"
            )

    schema_path = ROOT_DIR / "config" / "schema.json"
    if jsonschema and schema_path.is_file():
        with open(schema_path) as f:
            schema = json.load(f)
        try:
            jsonschema.validate(instance=config, schema=schema)
        except jsonschema.ValidationError as e:
            errors.append(f"Schema validation error: {e.message}")

    return errors


def get_base_output_dir(config):
    """Return the absolute path for the Phase 1 (base) output directory."""
    output_dir = config.get("output", {}).get("directory", "output")
    base_dir = Path(f"{output_dir}-base")
    if not base_dir.is_absolute():
        base_dir = ROOT_DIR / base_dir
    return base_dir


def get_provision_output_dir(config):
    """Return the absolute path for the Phase 2 (provision) output directory."""
    output_dir = config.get("output", {}).get("directory", "output")
    prov_dir = Path(output_dir)
    if not prov_dir.is_absolute():
        prov_dir = ROOT_DIR / prov_dir
    return prov_dir


def find_vmx_in_dir(directory):
    """Find the .vmx file inside a directory."""
    directory = Path(directory)
    if not directory.is_dir():
        return None
    vmx_files = list(directory.glob("*.vmx"))
    if vmx_files:
        return str(vmx_files[0])
    return None


def generate_base_vars(config):
    """Generate Packer variables file for Phase 1 (base build)."""
    vm = config.get("vm", {})
    iso = config.get("iso", {})
    base_output = get_base_output_dir(config)

    vars_content = f'''# Auto-generated by build.py — do not edit manually
iso_url          = "{hcl_path(iso.get("path", ""))}"
iso_checksum     = "{iso.get("checksum", "none")}"
vm_name          = "{vm.get("name", "MalwareAnalysis-Win11-25H2")}"
cpus             = {vm.get("cpus", 4)}
memory           = {vm.get("memory_mb", 8192)}
disk_size        = {vm.get("disk_size_mb", 102400)}
winrm_username   = "{vm.get("username", "malware")}"
winrm_password   = "{vm.get("password", "malware")}"
output_directory = "{hcl_path(base_output)}"
'''

    build_dir = ROOT_DIR / ".build"
    vars_file = build_dir / "base.auto.pkrvars.hcl"
    os.makedirs(build_dir, exist_ok=True)

    with open(vars_file, "w") as f:
        f.write(vars_content)

    return vars_file


def generate_provision_vars(config, tools_yaml_path, skip_verify):
    """Generate Packer variables file for Phase 2 (provision build)."""
    vm = config.get("vm", {})
    base_output = get_base_output_dir(config)
    prov_output = get_provision_output_dir(config)

    vmx_path = find_vmx_in_dir(base_output)
    if not vmx_path:
        vm_name = vm.get("name", "MalwareAnalysis-Win11-25H2")
        vmx_path = str(base_output / f"{vm_name}.vmx")

    skip_verify_val = "1" if skip_verify else "0"

    vars_content = f'''# Auto-generated by build.py — do not edit manually
source_path      = "{hcl_path(vmx_path)}"
vm_name          = "{vm.get("name", "MalwareAnalysis-Win11-25H2")}"
winrm_username   = "{vm.get("username", "malware")}"
winrm_password   = "{vm.get("password", "malware")}"
output_directory = "{hcl_path(prov_output)}"
tools_yaml_path  = "{hcl_path(tools_yaml_path)}"
skip_verify      = "{skip_verify_val}"
'''

    build_dir = ROOT_DIR / ".build"
    vars_file = build_dir / "provision.auto.pkrvars.hcl"
    os.makedirs(build_dir, exist_ok=True)

    with open(vars_file, "w") as f:
        f.write(vars_content)

    return vars_file


def run_packer_build(packer_bin, packer_dir, vars_file):
    """Run packer init and packer build for a given directory."""
    # Packer init
    print(f"\n=== Running packer init ({packer_dir.name}) ===\n")
    result = subprocess.run(
        [packer_bin, "init", str(packer_dir)],
        cwd=str(ROOT_DIR),
    )
    if result.returncode != 0:
        print("ERROR: packer init failed")
        return result.returncode

    # Packer build
    print(f"\n=== Running packer build ({packer_dir.name}) ===\n")
    cmd = [
        packer_bin, "build",
        f"-var-file={vars_file}",
        str(packer_dir),
    ]

    result = subprocess.run(cmd, cwd=str(ROOT_DIR))
    return result.returncode


def take_snapshot(vmrun_bin, vmrun_type, vmx_path, snapshot_name):
    """Take a snapshot of a VM."""
    print(f"\n=== Taking snapshot '{snapshot_name}' ===\n")

    cmd = [vmrun_bin, "-T", vmrun_type, "snapshot", vmx_path, snapshot_name]
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        print(f"Snapshot '{snapshot_name}' created successfully.")
    else:
        print(f"WARNING: Failed to create snapshot: {result.stderr}")

    return result.returncode


def clean_build(config=None):
    """Remove all build artifacts (output VM, base VM, .build dir, packer_cache)."""
    print("Cleaning build artifacts...\n")

    dirs_to_clean = [
        ROOT_DIR / ".build",
        ROOT_DIR / "packer_cache",
    ]

    if config:
        output_dir = config.get("output", {}).get("directory", "output")
    else:
        output_dir = "output"

    # Provision output
    output_path = Path(output_dir)
    if not output_path.is_absolute():
        output_path = ROOT_DIR / output_path
    dirs_to_clean.append(output_path)

    # Base output
    base_path = Path(f"{output_dir}-base")
    if not base_path.is_absolute():
        base_path = ROOT_DIR / base_path
    dirs_to_clean.append(base_path)

    removed = 0
    for d in dirs_to_clean:
        if d.exists():
            shutil.rmtree(d)
            print(f"  Removed: {d}")
            removed += 1
        else:
            print(f"  Not found (skip): {d}")

    if removed:
        print(f"\nCleanup complete. Removed {removed} directory(s).")
    else:
        print("\nNothing to clean.")


def main():
    parser = argparse.ArgumentParser(
        description="VMBuilder — Automated Windows 11 Malware Analysis VM Builder"
    )
    parser.add_argument(
        "--config",
        default=str(ROOT_DIR / "config" / "config.example.yaml"),
        help="Path to the configuration YAML file",
    )
    parser.add_argument(
        "--tools",
        default=str(ROOT_DIR / "config" / "tools.yaml"),
        help="Path to the tools YAML file",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate configuration without building",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip Phase 1 (OS install) and rerun Phase 2 (provisioning) from the base checkpoint",
    )
    parser.add_argument(
        "--skip-verify",
        action="store_true",
        help="Skip post-build verification step",
    )
    parser.add_argument(
        "--skip-snapshot",
        action="store_true",
        help="Skip taking snapshots after build",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove all build artifacts and exit",
    )
    args = parser.parse_args()

    print("========================================")
    print(" VMBuilder — Malware Analysis VM Builder")
    print("========================================")
    print()

    # Handle --clean
    if args.clean:
        config = None
        config_path = Path(args.config)
        if config_path.is_file():
            config = load_config(str(config_path))
        clean_build(config)
        sys.exit(0)

    # Check prerequisites
    print("Checking prerequisites...")
    errors, packer_bin, vmrun_bin, vmrun_type, iso_tool = check_prerequisites()

    if errors and not args.validate_only:
        for err in errors:
            print(f"  ERROR: {err}")
        sys.exit(1)

    if packer_bin:
        print(f"  Packer: {packer_bin}")
    if vmrun_bin:
        print(f"  vmrun:  {vmrun_bin} (type: {vmrun_type})")
    if iso_tool:
        print(f"  ISO tool: {iso_tool}")
    print()

    # Load configuration
    print(f"Loading config: {args.config}")
    config = load_config(args.config)

    print(f"Loading tools:  {args.tools}")
    tools_config = load_tools(args.tools, config.get("tool_overrides"))

    enabled_tools = [t for t in tools_config.get("tools", []) if t.get("enabled")]
    print(f"  Enabled tools: {len(enabled_tools)}")
    print()

    # Validate
    print("Validating configuration...")
    validation_errors = validate_config(config, tools_config)

    if validation_errors:
        print("  Validation FAILED:")
        for err in validation_errors:
            print(f"    - {err}")
        sys.exit(1)
    else:
        print("  Validation passed.")

    if args.validate_only:
        print("\n--validate-only specified. Exiting.")
        sys.exit(0)

    # Write merged tools.yaml with overrides applied
    build_dir = ROOT_DIR / ".build"
    os.makedirs(build_dir, exist_ok=True)
    merged_tools_path = build_dir / "tools.merged.yaml"
    with open(merged_tools_path, "w") as f:
        yaml.dump(tools_config, f, default_flow_style=False, sort_keys=False)

    # Resolve output directories
    base_output = get_base_output_dir(config)
    prov_output = get_provision_output_dir(config)
    vm_name = config.get("vm", {}).get("name", "MalwareAnalysis-Win11-25H2")

    # ── Phase 1: Base build (OS + VMware Tools) ─────────────────────────
    if args.resume:
        # --resume: verify base VM exists
        base_vmx = find_vmx_in_dir(base_output)
        if not base_vmx:
            print(f"\nERROR: No base VM found in {base_output}")
            print("  Run a full build first (without --resume) to create the base VM.")
            sys.exit(1)
        print(f"\n--resume: Using existing base VM: {base_vmx}")
    else:
        # Full build: Phase 1
        if base_output.exists():
            print(f"\nERROR: Base output directory already exists: {base_output}")
            print("  Use --resume to rerun provisioning from this checkpoint,")
            print("  or --clean to remove all artifacts and start fresh.")
            sys.exit(1)

        print("\nGenerating Phase 1 (base) variables...")
        base_vars = generate_base_vars(config)
        print(f"  Variables written to: {base_vars}")

        packer_base_dir = ROOT_DIR / "packer" / "base"
        exit_code = run_packer_build(packer_bin, packer_base_dir, base_vars)

        if exit_code != 0:
            print(f"\nERROR: Phase 1 (base) build failed with exit code {exit_code}")
            sys.exit(exit_code)

        # Take "os-installed" snapshot on base VM
        base_vmx = find_vmx_in_dir(base_output)
        if base_vmx and not args.skip_snapshot and vmrun_bin:
            take_snapshot(vmrun_bin, vmrun_type, base_vmx, "os-installed")

    # ── Phase 2: Provision build (tools + hardening) ────────────────────

    # Delete provision output if it exists (Packer needs an empty directory)
    if prov_output.exists():
        print(f"\nRemoving previous provision output: {prov_output}")
        shutil.rmtree(prov_output)

    print("\nGenerating Phase 2 (provision) variables...")
    prov_vars = generate_provision_vars(config, str(merged_tools_path), args.skip_verify)
    print(f"  Variables written to: {prov_vars}")

    packer_prov_dir = ROOT_DIR / "packer" / "provision"
    exit_code = run_packer_build(packer_bin, packer_prov_dir, prov_vars)

    if exit_code != 0:
        print(f"\nERROR: Phase 2 (provision) build failed with exit code {exit_code}")
        print(f"\n  Base VM is preserved at: {base_output}")
        print("  Use --resume to retry provisioning without reinstalling the OS.")
        sys.exit(exit_code)

    # Determine output VMX path
    prov_vmx = find_vmx_in_dir(prov_output)
    if not prov_vmx:
        prov_vmx = str(prov_output / f"{vm_name}.vmx")

    print(f"\nBuild complete! VM located at: {prov_vmx}")

    # Take "Clean" snapshot on provisioned VM
    if not args.skip_snapshot and vmrun_bin:
        snapshot_name = config.get("output", {}).get("snapshot_name", "Clean")
        take_snapshot(vmrun_bin, vmrun_type, prov_vmx, snapshot_name)

    print("\n========================================")
    print(" Build finished successfully!")
    print("========================================")
    print(f"  VM:       {prov_vmx}")
    print(f"  Base:     {base_output}")
    print(f"  Username: {config.get('vm', {}).get('username', 'malware')}")
    print(f"  Password: {config.get('vm', {}).get('password', 'malware')}")
    print()


if __name__ == "__main__":
    main()
