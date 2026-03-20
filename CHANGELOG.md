# Changelog

All notable changes to this project will be documented in this file.

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
