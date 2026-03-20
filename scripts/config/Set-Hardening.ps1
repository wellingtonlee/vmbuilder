# Set-Hardening.ps1
# Hardens Windows 11 for malware analysis by disabling security features
# that would interfere with analysis.
#
# All changes are idempotent (safe to run multiple times).

$ErrorActionPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Windows Hardening for Malware Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# -- Disable Windows Defender ---------------------------------------------

Write-Host ""
Write-Host "[1/7] Disabling Windows Defender..." -ForegroundColor Yellow

# Disable real-time protection
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableBlockAtFirstSeen $true
Set-MpPreference -DisableScriptScanning $true
Set-MpPreference -MAPSReporting 0
Set-MpPreference -SubmitSamplesConsent 2

# Disable via Group Policy registry keys
$defenderPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
New-Item -Path $defenderPolicyPath -Force | Out-Null
Set-ItemProperty -Path $defenderPolicyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $defenderPolicyPath -Name "DisableAntiVirus" -Value 1 -Type DWord -Force

New-Item -Path "$defenderPolicyPath\Real-Time Protection" -Force | Out-Null
Set-ItemProperty -Path "$defenderPolicyPath\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "$defenderPolicyPath\Real-Time Protection" -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "$defenderPolicyPath\Real-Time Protection" -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "$defenderPolicyPath\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force

# Disable Defender services
$defenderServices = @("WinDefend", "SecurityHealthService", "wscsvc", "Sense")
foreach ($svc in $defenderServices) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
}

# Disable Tamper Protection via registry
$tamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
Set-ItemProperty -Path $tamperPath -Name "TamperProtection" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

Write-Host "  Defender disabled." -ForegroundColor Green

# -- Disable Windows Update -----------------------------------------------

Write-Host "[2/7] Disabling Windows Update..." -ForegroundColor Yellow

$updateServices = @("wuauserv", "UsoSvc", "WaaSMedicSvc")
foreach ($svc in $updateServices) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
}

# Disable auto-update via registry
$wuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
New-Item -Path $wuPolicyPath -Force | Out-Null
Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $wuPolicyPath -Name "AUOptions" -Value 1 -Type DWord -Force

Write-Host "  Windows Update disabled." -ForegroundColor Green

# -- Disable Telemetry ----------------------------------------------------

Write-Host "[3/7] Disabling telemetry..." -ForegroundColor Yellow

$telemetryServices = @("DiagTrack", "dmwappushservice")
foreach ($svc in $telemetryServices) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
}

$telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
New-Item -Path $telemetryPath -Force | Out-Null
Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force

Write-Host "  Telemetry disabled." -ForegroundColor Green

# -- Disable Cortana ------------------------------------------------------

Write-Host "[4/7] Disabling Cortana..." -ForegroundColor Yellow

$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
New-Item -Path $cortanaPath -Force | Out-Null
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "DisableWebSearch" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -Force

Write-Host "  Cortana disabled." -ForegroundColor Green

# -- Disable UAC ----------------------------------------------------------

Write-Host "[5/7] Disabling UAC..." -ForegroundColor Yellow

$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $uacPath -Name "PromptOnSecureDesktop" -Value 0 -Type DWord -Force

Write-Host "  UAC disabled." -ForegroundColor Green

# -- Disable SmartScreen --------------------------------------------------

Write-Host "[6/7] Disabling SmartScreen..." -ForegroundColor Yellow

$smartScreenPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
New-Item -Path $smartScreenPath -Force | Out-Null
Set-ItemProperty -Path $smartScreenPath -Name "EnableSmartScreen" -Value 0 -Type DWord -Force

$smartScreenEdgePath = "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter"
New-Item -Path $smartScreenEdgePath -Force | Out-Null
Set-ItemProperty -Path $smartScreenEdgePath -Name "EnabledV9" -Value 0 -Type DWord -Force

Write-Host "  SmartScreen disabled." -ForegroundColor Green

# -- Disable Firewall -----------------------------------------------------

Write-Host "[7/7] Disabling Windows Firewall..." -ForegroundColor Yellow

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

Write-Host "  Firewall disabled." -ForegroundColor Green

# -- Summary --------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Hardening complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  - Windows Defender: DISABLED" -ForegroundColor DarkGray
Write-Host "  - Windows Update:   DISABLED" -ForegroundColor DarkGray
Write-Host "  - Telemetry:        DISABLED" -ForegroundColor DarkGray
Write-Host "  - Cortana:          DISABLED" -ForegroundColor DarkGray
Write-Host "  - UAC:              DISABLED" -ForegroundColor DarkGray
Write-Host "  - SmartScreen:      DISABLED" -ForegroundColor DarkGray
Write-Host "  - Firewall:         DISABLED" -ForegroundColor DarkGray
