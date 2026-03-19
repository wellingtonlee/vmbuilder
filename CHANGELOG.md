# Changelog

All notable changes to this project will be documented in this file.

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
