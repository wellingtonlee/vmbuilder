# setup-winrm.ps1
# Bootstrap WinRM for Packer communicator
# Runs as FirstLogonCommands from autounattend.xml

$ErrorActionPreference = "Stop"

Write-Host "Configuring WinRM for Packer provisioning..."

# Set network profile to Private (required for WinRM)
$networkProfile = Get-NetConnectionProfile
Set-NetConnectionProfile -Name $networkProfile.Name -NetworkCategory Private

# Enable PSRemoting
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM
winrm quickconfig -q
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'

# Set WinRM to auto-start
Set-Service -Name WinRM -StartupType Automatic
Restart-Service WinRM

# Allow WinRM through firewall
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in action=allow protocol=TCP localport=5985

Write-Host "WinRM configuration complete."
