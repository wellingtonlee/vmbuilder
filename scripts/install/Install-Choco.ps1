# Install-Choco.ps1
# Bootstraps Chocolatey package manager and PowerShell YAML module

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Installing Chocolatey" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Refresh PATH so choco is available
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Configure Chocolatey
choco feature enable -n=allowGlobalConfirmation
choco feature disable -n=showDownloadProgress

Write-Host "Chocolatey installed successfully." -ForegroundColor Green

# Install powershell-yaml module for YAML parsing
Write-Host "Installing powershell-yaml module..." -ForegroundColor Cyan
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name powershell-yaml -Force -Scope AllUsers

Write-Host "powershell-yaml module installed successfully." -ForegroundColor Green

# Ensure winget is available (pre-installed on Windows 11, may need registration)
Write-Host "Ensuring winget is available..." -ForegroundColor Cyan
try {
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    Write-Host "winget registered successfully." -ForegroundColor Green
}
catch {
    Write-Host "winget registration skipped (not fatal): $_" -ForegroundColor Yellow
    Write-Host "winget should already be available on Windows 11 25H2." -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Green
Write-Host " Bootstrap complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
