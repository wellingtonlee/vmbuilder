# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-03-20

### Added
- Two-phase build with checkpoint/resume: Phase 1 installs the OS + VMware Tools
  and saves a base VM; Phase 2 clones it for tool provisioning and hardening
- `--resume` flag to rerun Phase 2 from the base checkpoint without repeating
  the ~1hr OS installation
- VMware Tools installation in Phase 1 via `tools_upload_flavor` and
  `Install-VMwareTools.ps1`
- `SKIP_VERIFY` environment variable support in `Test-Build.ps1`

### Changed
- Split monolithic `packer/` into `packer/base/` (vmware-iso) and
  `packer/provision/` (vmware-vmx) directories
- `build.py` now orchestrates two separate `packer build` invocations
- `--skip-verify` now works correctly (previously used `-except verify` which
  only filters builds, not provisioners in HCL2)

### Fixed
- `--skip-verify` flag was silently ignored because Packer HCL2's `-except`
  flag filters build sources, not individual provisioners

## [0.1.3] - 2026-03-20

### Fixed
- Packer build failure during provisioning — `Add-AppxPackage` for winget threw a
  terminating `0x80070005` (Access Denied) error under WinRM's SYSTEM context; made
  winget registration non-fatal since it ships pre-installed on Windows 11 25H2

## [0.1.2] - 2026-03-20

### Fixed
- KMODE_EXCEPTION_NOT_HANDLED (0x1E) BSOD during Windows 11 setup — disabled nested
  virtualization (`vhv.enable = "FALSE"`) which caused WinPE to hit an unhandled CPU
  exception during early VBS/Hyper-V initialization when it detected exposed VT-x features
- Switched `network_adapter_type` from `e1000e` to `vmxnet3` (WinPE lacks a native e1000e driver)
- Pinned VMware hardware version to 21 (`virtualHW.version`) for reproducible builds

## [0.1.1] - 2026-03-20

### Fixed
- UEFI boot hang at "Press any key to boot from CD/DVD" — added `boot_wait` + `boot_command` to send keypress automatically
- Switched `floppy_files` to `cd_files` with `OEMDRV` label — UEFI firmware doesn't reliably mount floppy drives
- Added `DiskID` to all `ModifyPartition` elements in `autounattend.xml` for explicit NVMe disk targeting
- Added `BypassNRO` registry key in specialize pass to skip Win11 25H2 mandatory network/Microsoft account OOBE screen
- Fixed `setup-winrm.ps1` drive path — searches CD drive letters D:-J: instead of hardcoded `a:\` floppy path

## [0.1.0] - 2026-03-19

### Added
- Initial project structure with Packer + PowerShell automation
- YAML-driven tool configuration (`config/tools.yaml`) with 35 malware analysis tools
- Four tool installation methods: choco, direct-download, powershell, winget
- Windows 11 25H2 unattended install with TPM/SecureBoot/RAM bypass
- Full Windows hardening (Defender, Update, telemetry, Cortana, UAC, SmartScreen, firewall)
- OS cosmetic configuration (dark mode, file extensions, hidden files, MesloLG Nerd Font)
- Organized desktop layout with category folders and shortcuts
- Post-build verification script with JSON report
- Host-side Python orchestrator (`build.py`) with config validation
- Auto-detection of VMware Fusion (macOS) vs Workstation (Windows/Linux)
- Clean snapshot creation via vmrun after successful build
