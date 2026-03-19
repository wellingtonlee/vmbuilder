# VMBuilder — Automated Malware Analysis VM Builder

Automated builder for a Windows 11 25H2 virtual machine pre-configured for malware analysis. Uses [Packer](https://www.packer.io/) and PowerShell to create a fully provisioned VMware VM with 35+ analysis tools, Windows hardening, and an organized desktop layout.

## Features

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
- **Windows 11 25H2 ISO** — [Download from Microsoft](https://www.microsoft.com/software-download/windows11)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/vmbuilder.git
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

   The build takes approximately 1-2 hours depending on internet speed. The resulting VM will be in the `output/` directory.

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
  --skip-verify      Skip post-build verification step
  --skip-snapshot    Skip taking a clean snapshot after build
```

## Project Structure

```
vmbuilder/
├── build.py                  # Host-side orchestrator
├── config/
│   ├── config.example.yaml   # VM settings template
│   ├── tools.yaml            # Tool definitions (35 tools)
│   └── schema.json           # Config validation schema
├── packer/
│   ├── windows.pkr.hcl       # Packer build template
│   ├── variables.pkr.hcl     # Variable declarations
│   └── plugins.pkr.hcl       # Required plugins
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

### ISO image index mismatch
If Windows setup fails to find the correct edition, verify the image index in your ISO:
```powershell
dism /Get-ImageInfo /ImageFile:D:\sources\install.wim
```
The `autounattend.xml` expects "Windows 11 Pro". Edit the `<Value>` in `answer/autounattend.xml` if your ISO uses a different edition name.

### WinRM connection timeout
If Packer times out waiting for WinRM, ensure the VM has network connectivity and the firewall rule was created. You can increase the timeout in `packer/windows.pkr.hcl` (`winrm_timeout`).

### Placeholder URLs
Tools with `PLACEHOLDER_UPDATE_ME` in their URLs will fail to download. Update these URLs in `config/tools.yaml` before building:
- IDA Free — Get from [hex-rays.com/ida-free](https://hex-rays.com/ida-free/)
- WinDump — Get from the WinDump project page
- Regfsnotify — Get from the project's download page
- Capa explorer web — Get from [Capa releases](https://github.com/mandiant/capa/releases)
- ret-sync — Get from [ret-sync releases](https://github.com/bootleg/ret-sync/releases)

## License

MIT
