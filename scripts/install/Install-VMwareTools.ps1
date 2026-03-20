# Install-VMwareTools.ps1
# Mounts the VMware Tools ISO uploaded by Packer and runs the silent installer.

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Installing VMware Tools" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$isoPath = "C:\Windows\Temp\windows.iso"

if (-not (Test-Path $isoPath)) {
    Write-Host "ERROR: VMware Tools ISO not found at $isoPath" -ForegroundColor Red
    exit 1
}

# Mount the ISO
Write-Host "Mounting VMware Tools ISO..."
$mount = Mount-DiskImage -ImagePath $isoPath -PassThru
$driveLetter = ($mount | Get-Volume).DriveLetter

if (-not $driveLetter) {
    Write-Host "ERROR: Failed to mount ISO - no drive letter assigned" -ForegroundColor Red
    exit 1
}

$mountRoot = "${driveLetter}:\"
Write-Host "ISO mounted at $mountRoot"

# Find the installer - prefer setup64.exe, fall back to setup.exe
$installer = Join-Path $mountRoot "setup64.exe"
if (-not (Test-Path $installer)) {
    $installer = Join-Path $mountRoot "setup.exe"
}

if (-not (Test-Path $installer)) {
    Write-Host "ERROR: VMware Tools installer not found on mounted ISO" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $isoPath
    exit 1
}

Write-Host "Running installer: $installer"

$process = Start-Process -FilePath $installer `
    -ArgumentList '/S /v "/qn REBOOT=ReallySuppress"' `
    -Wait -PassThru

$exitCode = $process.ExitCode
Write-Host "Installer exit code: $exitCode"

# Dismount the ISO
Write-Host "Dismounting ISO..."
Dismount-DiskImage -ImagePath $isoPath

# Clean up the uploaded ISO
if (Test-Path $isoPath) {
    Remove-Item -Path $isoPath -Force
    Write-Host "Cleaned up ISO file."
}

# Exit code 0 = success, 3010 = success but reboot needed
if ($exitCode -eq 0 -or $exitCode -eq 3010) {
    Write-Host "VMware Tools installed successfully." -ForegroundColor Green
    if ($exitCode -eq 3010) {
        Write-Host "Reboot required (will be handled by windows-restart provisioner)." -ForegroundColor Yellow
    }
    exit 0
}
else {
    Write-Host "ERROR: VMware Tools installation failed with exit code $exitCode" -ForegroundColor Red
    exit $exitCode
}
