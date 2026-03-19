#!/usr/bin/env python3
"""
VMBuilder — Automated Windows 11 25H2 Malware Analysis VM Builder

Host-side orchestrator that reads YAML configuration, validates it,
generates Packer variables, and invokes the Packer build.

Usage:
    python build.py                          # uses config/config.example.yaml
    python build.py --config myconfig.yaml   # custom config
    python build.py --validate-only          # validate config without building
    python build.py --skip-verify            # skip post-build verification
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


def detect_vmware():
    """Auto-detect VMware product and vmrun path."""
    system = platform.system()

    if system == "Darwin":
        # macOS — VMware Fusion
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

    # Try PATH
    vmrun = shutil.which("vmrun")
    if vmrun:
        return vmrun, vmrun_type

    return None, vmrun_type


def check_prerequisites():
    """Verify that required tools are available."""
    errors = []

    # Check Packer
    packer = shutil.which("packer")
    if not packer:
        errors.append("Packer not found on PATH. Install from https://www.packer.io/downloads")

    # Check VMware
    vmrun, vmrun_type = detect_vmware()
    if not vmrun:
        errors.append(
            "vmrun not found. Install VMware Workstation (Windows/Linux) "
            "or VMware Fusion (macOS)."
        )

    return errors, packer, vmrun, vmrun_type


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

    # Check required fields
    if not config.get("iso", {}).get("path"):
        errors.append("iso.path is required in the config file")
    elif not os.path.isfile(config["iso"]["path"]):
        errors.append(f"ISO file not found: {config['iso']['path']}")

    # Check VM settings
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

    # Check for placeholder URLs in tools
    enabled_tools = [t for t in tools_config.get("tools", []) if t.get("enabled")]
    for tool in enabled_tools:
        url = tool.get("url", "")
        if "PLACEHOLDER" in url.upper():
            errors.append(
                f"Tool '{tool['display_name']}' has a placeholder URL — "
                f"update it in tools.yaml or disable the tool"
            )

    # Validate with JSON Schema if available
    schema_path = ROOT_DIR / "config" / "schema.json"
    if jsonschema and schema_path.is_file():
        with open(schema_path) as f:
            schema = json.load(f)
        try:
            jsonschema.validate(instance=config, schema=schema)
        except jsonschema.ValidationError as e:
            errors.append(f"Schema validation error: {e.message}")

    return errors


def generate_packer_vars(config, tools_yaml_path):
    """Generate a Packer variables file from the YAML config."""
    vm = config.get("vm", {})
    iso = config.get("iso", {})
    output = config.get("output", {})

    vars_content = f'''# Auto-generated by build.py — do not edit manually
iso_url          = "{iso.get("path", "")}"
iso_checksum     = "{iso.get("checksum", "none")}"
vm_name          = "{vm.get("name", "MalwareAnalysis-Win11-25H2")}"
cpus             = {vm.get("cpus", 4)}
memory           = {vm.get("memory_mb", 8192)}
disk_size        = {vm.get("disk_size_mb", 102400)}
winrm_username   = "{vm.get("username", "malware")}"
winrm_password   = "{vm.get("password", "malware")}"
output_directory = "{output.get("directory", "output")}"
tools_yaml_path  = "{tools_yaml_path}"
'''

    vars_file = ROOT_DIR / "output" / "build.auto.pkrvars.hcl"
    os.makedirs(vars_file.parent, exist_ok=True)

    with open(vars_file, "w") as f:
        f.write(vars_content)

    return vars_file


def run_packer_build(packer_bin, vars_file, skip_verify=False):
    """Run packer init and packer build."""
    packer_dir = ROOT_DIR / "packer"

    # Packer init
    print("\n=== Running packer init ===\n")
    result = subprocess.run(
        [packer_bin, "init", str(packer_dir)],
        cwd=str(ROOT_DIR),
    )
    if result.returncode != 0:
        print("ERROR: packer init failed")
        return result.returncode

    # Packer build
    print("\n=== Running packer build ===\n")
    cmd = [
        packer_bin, "build",
        f"-var-file={vars_file}",
    ]

    if skip_verify:
        cmd.extend(["-except", "verify"])

    cmd.append(str(packer_dir))

    result = subprocess.run(cmd, cwd=str(ROOT_DIR))
    return result.returncode


def take_snapshot(vmrun_bin, vmrun_type, vmx_path, snapshot_name):
    """Take a clean snapshot of the built VM."""
    print(f"\n=== Taking snapshot '{snapshot_name}' ===\n")

    cmd = [vmrun_bin, "-T", vmrun_type, "snapshot", vmx_path, snapshot_name]
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        print(f"Snapshot '{snapshot_name}' created successfully.")
    else:
        print(f"WARNING: Failed to create snapshot: {result.stderr}")

    return result.returncode


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
        "--skip-verify",
        action="store_true",
        help="Skip post-build verification step",
    )
    parser.add_argument(
        "--skip-snapshot",
        action="store_true",
        help="Skip taking a clean snapshot after build",
    )
    args = parser.parse_args()

    print("========================================")
    print(" VMBuilder — Malware Analysis VM Builder")
    print("========================================")
    print()

    # Check prerequisites
    print("Checking prerequisites...")
    errors, packer_bin, vmrun_bin, vmrun_type = check_prerequisites()

    if errors and not args.validate_only:
        for err in errors:
            print(f"  ERROR: {err}")
        sys.exit(1)

    if packer_bin:
        print(f"  Packer: {packer_bin}")
    if vmrun_bin:
        print(f"  vmrun:  {vmrun_bin} (type: {vmrun_type})")
    print()

    # Load configuration
    print(f"Loading config: {args.config}")
    config = load_config(args.config)

    print(f"Loading tools:  {args.tools}")
    tools_config = load_tools(args.tools, config.get("tool_overrides"))

    # Count enabled tools
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
    merged_tools_path = ROOT_DIR / "output" / "tools.merged.yaml"
    os.makedirs(merged_tools_path.parent, exist_ok=True)
    with open(merged_tools_path, "w") as f:
        yaml.dump(tools_config, f, default_flow_style=False, sort_keys=False)

    # Generate Packer variables
    print("\nGenerating Packer variables...")
    vars_file = generate_packer_vars(config, str(merged_tools_path))
    print(f"  Variables written to: {vars_file}")

    # Run Packer build
    exit_code = run_packer_build(packer_bin, vars_file, args.skip_verify)

    if exit_code != 0:
        print(f"\nERROR: Packer build failed with exit code {exit_code}")
        sys.exit(exit_code)

    # Determine output VMX path
    output_dir = config.get("output", {}).get("directory", "output")
    vm_name = config.get("vm", {}).get("name", "MalwareAnalysis-Win11-25H2")
    vmx_path = os.path.join(output_dir, f"{vm_name}.vmx")

    print(f"\nBuild complete! VM located at: {vmx_path}")

    # Take clean snapshot
    if not args.skip_snapshot and vmrun_bin:
        snapshot_name = config.get("output", {}).get("snapshot_name", "Clean")
        take_snapshot(vmrun_bin, vmrun_type, vmx_path, snapshot_name)

    print("\n========================================")
    print(" Build finished successfully!")
    print("========================================")
    print(f"  VM:       {vmx_path}")
    print(f"  Username: {config.get('vm', {}).get('username', 'malware')}")
    print(f"  Password: {config.get('vm', {}).get('password', 'malware')}")
    print()


if __name__ == "__main__":
    main()
