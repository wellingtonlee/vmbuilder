# VMBuilder — Automated Malware Analysis VM Builder

Automated builder for a Windows 11 25H2 virtual machine pre-configured for malware analysis. Uses [Packer](https://www.packer.io/) and PowerShell to create a fully provisioned VMware VM with 35+ analysis tools, Windows hardening, and an organized desktop layout.

## Features

- **Two-phase build with checkpoint/resume** — Phase 1 installs the OS and VMware Tools; Phase 2 provisions tools and hardening. If provisioning fails, use `--resume` to retry without repeating the ~1hr OS install
- **VMware Tools** installed automatically during the base build
- **YAML-driven configuration** — Add or remove tools by editing `config/tools.yaml`
- **35 pre-configured tools** including debuggers, disassemblers, PE analyzers, network tools, and system monitors
- **Full Windows hardening** — Defender, Windows Update, telemetry, Cortana, UAC, SmartScreen, and firewall disabled
- **Organized desktop** — Tools grouped into category folders (Debuggers, Disassemblers, PE Analysis, Network, System Monitoring, Utilities)
- **Dark mode** with MesloLG Nerd Font, visible file extensions, and hidden files shown
- **Post-build verification** with JSON report
- **Clean snapshot** automatically created after build

## Prerequisites

- **[Packer](https://www.packer.io/downloads)** (>= 1.10)
- **VMware Workstation** (Windows/Linux) or **VMware Fusion** (macOS)
- **Python 3.8+** with pip
- **CD ISO creation tool** — one of `xorriso`, `mkisofs`, `hdiutil`, or `oscdimg` on PATH
  - **Windows:** copy the appropriate `oscdimg.exe` from the `oscdimg/` directory in this repo to a directory on your PATH (binaries are provided for [amd64](oscdimg/amd64/), [arm64](oscdimg/arm64/), [x86](oscdimg/x86/), and [arm](oscdimg/arm/)), or `choco install schily-cdrtools` (provides `mkisofs`)
  - **macOS:** `hdiutil` is built-in (no action needed)
  - **Linux:** `sudo apt install xorriso` or `sudo dnf install xorriso`
- **Windows 11 25H2 ISO** — [Download from Microsoft](https://www.microsoft.com/software-download/windows11)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/wellingtonlee/vmbuilder.git
   cd vmbuilder
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure:**
   ```bash
   cp config/config.example.yaml config/config.yaml
   ```
   Edit `config/config.yaml` and set `iso.path` to your Windows 11 25H2 ISO location.

4. **Review tools** (optional):
   Edit `config/tools.yaml` to enable/disable tools or update download URLs.
   Tools with `PLACEHOLDER` URLs must be updated before building.

5. **Validate configuration:**
   ```bash
   python build.py --config config/config.yaml --validate-only
   ```

6. **Build the VM:**
   ```bash
   python build.py --config config/config.yaml
   ```

   The full build runs in two phases:
   - **Phase 1 (base):** Installs Windows from ISO and VMware Tools (~1hr). Output saved to `output-base/`.
   - **Phase 2 (provision):** Clones the base VM, installs tools, applies hardening. Output saved to `output/`.

7. **Resume after a failed build:**

   If Phase 2 fails (e.g., a tool download URL is broken), the base VM is preserved. Fix the issue and rerun only Phase 2:
   ```bash
   python build.py --config config/config.yaml --resume
   ```
   This skips the entire OS installation and picks up from the base checkpoint, saving roughly an hour per retry.

## Configuration

### VM Settings (`config/config.yaml`)

| Setting | Default | Description |
|---------|---------|-------------|
| `vm.name` | `MalwareAnalysis-Win11-25H2` | VM name |
| `vm.cpus` | `4` | CPU cores (1-32) |
| `vm.memory_mb` | `8192` | RAM in MB (2048-65536) |
| `vm.disk_size_mb` | `102400` | Disk in MB (40960-1048576) |
| `vm.username` | `malware` | Local admin username |
| `vm.password` | `malware` | Local admin password |
| `iso.path` | — | **Required.** Path to Windows 11 ISO |
| `iso.checksum` | `none` | SHA256 checksum or `none` |
| `output.directory` | `./output` | Build output directory |
| `output.snapshot_name` | `Clean` | Post-build snapshot name |

### Tool Overrides

Override individual tool settings without modifying `tools.yaml`:

```yaml
tool_overrides:
  ida-free:
    enabled: false
  ghidra:
    url: "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.0_build/ghidra_12.0.zip"
```

## Adding a New Tool

Add an entry to `config/tools.yaml`. No code changes needed. Example:

```yaml
- name: pestudio
  display_name: "pestudio"
  method: direct-download
  url: "https://www.winitor.com/tools/pestudio/current/pestudio.zip"
  download_type: zip
  install_dir: "C:\\Tools\\pestudio"
  category: "PE Analysis"
  exe_path: "C:\\Tools\\pestudio\\pestudio.exe"
  enabled: true
```

### Install Methods

| Method | Description | Required Fields |
|--------|-------------|-----------------|
| `choco` | Chocolatey package | `choco_package` |
| `direct-download` | Download from URL | `url`, `download_type` (zip/exe/msi/7z), `install_dir` |
| `winget` | Windows Package Manager | `winget_id` |
| `powershell` | Run a PowerShell command | `command` |
| `shortcut-only` | Create shortcut to existing exe | `depends_on`, `exe_path` |

## Included Tools

### Debuggers
x64dbg, WinDbg, dnSpyEx, ret-sync

### Disassemblers
IDA Free, Ghidra

### PE Analysis
CFF Explorer, Detect-It-Easy, PE-Bear, imHex, Capa, Capa rules, Capa explorer web, FLOSS

### Network
Wireshark, FakeNet-NG, Fiddler Classic, WinDump

### System Monitoring
Sysinternals Suite (Process Explorer, Process Monitor, Autoruns, TCPView, WinObj), System Informer, ProcDOT, Regshot, API Monitor v2, Regfsnotify

### Utilities
7-Zip, Sublime Text 4, CyberChef, Graphviz, Python, JDK Temurin, YARA

### Other
MesloLG Nerd Font, Microsoft Edge (pre-installed), kernel debug mode (`bcdedit /debug on`)

## Windows Hardening

The build applies the following hardening for malware analysis:

- **Windows Defender** — Disabled (real-time protection, services, tamper protection)
- **Windows Update** — Disabled (wuauserv, UsoSvc, WaaSMedicSvc)
- **Telemetry** — Disabled (DiagTrack, dmwappushservice)
- **Cortana** — Disabled
- **UAC** — Disabled
- **SmartScreen** — Disabled
- **Firewall** — Disabled (required for FakeNet-NG and network analysis)
- **Kernel debug** — Enabled via bcdedit

## CLI Reference

```bash
python build.py [OPTIONS]

Options:
  --config PATH      Path to config YAML (default: config/config.example.yaml)
  --tools PATH       Path to tools YAML (default: config/tools.yaml)
  --validate-only    Validate configuration without building
  --resume           Skip Phase 1 (OS install) and rerun Phase 2 from base checkpoint
  --skip-verify      Skip post-build verification step
  --skip-snapshot    Skip taking snapshots after build
  --clean            Remove all build artifacts (output/, output-base/, .build/)
```

## Project Structure

```
vmbuilder/
├── build.py                  # Host-side orchestrator (two-phase build)
├── config/
│   ├── config.example.yaml   # VM settings template
│   ├── tools.yaml            # Tool definitions (35 tools)
│   └── schema.json           # Config validation schema
├── packer/
│   ├── base/                 # Phase 1: OS install + VMware Tools (vmware-iso)
│   │   ├── windows-base.pkr.hcl
│   │   ├── variables.pkr.hcl
│   │   └── plugins.pkr.hcl
│   └── provision/            # Phase 2: Tool provisioning + hardening (vmware-vmx)
│       ├── windows-provision.pkr.hcl
│       ├── variables.pkr.hcl
│       └── plugins.pkr.hcl
├── answer/
│   ├── autounattend.xml      # Unattended Windows install
│   └── setup-winrm.ps1       # WinRM bootstrap
├── scripts/
│   ├── install/               # Tool installation scripts
│   ├── config/                # OS hardening and configuration
│   └── verify/                # Post-build verification
└── resources/
    └── wallpaper.png          # Optional custom wallpaper
```

## Troubleshooting

### KMODE_EXCEPTION_NOT_HANDLED (0x1E) BSOD during setup
This BSOD occurs during WinPE early boot (before the installer UI appears). Known causes:

1. **Nested virtualization enabled** (`vhv.enable = "TRUE"` in `vmx_data`) — WinPE detects
   exposed VT-x/EPT CPU features and attempts early VBS/Hyper-V initialization, triggering
   an unhandled CPU exception. Fix: set `vhv.enable = "FALSE"` in `packer/windows.pkr.hcl`.
   You can re-enable it in the `.vmx` file after the OS is installed if needed.
2. **Missing NIC driver** (`network_adapter_type = "e1000e"`) — WinPE lacks a native
   e1000e driver. Fix: use `network_adapter_type = "vmxnet3"`.

### UEFI boot hangs at "Press any key to boot from CD/DVD"
The build includes a `boot_wait` (3s) and `boot_command` that sends a spacebar press to get past this prompt. If your system takes longer to reach this screen, increase `boot_wait` in `packer/windows.pkr.hcl` (e.g., `"5s"` or `"10s"`).

### ISO image index mismatch
If Windows setup fails to find the correct edition, verify the image index in your ISO:
```powershell
dism /Get-ImageInfo /ImageFile:D:\sources\install.wim
```
The `autounattend.xml` expects "Windows 11 Pro". Edit the `<Value>` in `answer/autounattend.xml` if your ISO uses a different edition name.

### WinRM connection timeout
If Packer times out waiting for WinRM, ensure the VM has network connectivity and the firewall rule was created. You can increase the timeout in `packer/windows.pkr.hcl` (`winrm_timeout`).

### Provisioning failed — how to retry
If Phase 2 (tool installation, hardening) fails, the base VM in `output-base/` is kept intact. Fix the root cause (e.g., update a broken URL in `config/tools.yaml`), then rerun:
```bash
python build.py --config config/config.yaml --resume
```
This clones the base VM again and reruns all provisioning from scratch. You can iterate on this as many times as needed without waiting for the OS to reinstall.

To start completely fresh (including Phase 1), clean first:
```bash
python build.py --config config/config.yaml --clean
python build.py --config config/config.yaml
```

### Placeholder URLs
Tools with `PLACEHOLDER_UPDATE_ME` in their URLs will fail to download. Update these URLs in `config/tools.yaml` before building:
- IDA Free — Get from [hex-rays.com/ida-free](https://hex-rays.com/ida-free/)
- WinDump — Get from the WinDump project page
- Regfsnotify — Get from the project's download page
- Capa explorer web — Get from [Capa releases](https://github.com/mandiant/capa/releases)
- ret-sync — Get from [ret-sync releases](https://github.com/bootleg/ret-sync/releases)

### "could not find a supported CD ISO creation command"
Packer needs an ISO creation tool to build the answer-file CD. Install one:
- **Windows:** `choco install schily-cdrtools`
- **macOS:** `hdiutil` should already be available
- **Linux:** `sudo apt install xorriso`

## License

MIT
