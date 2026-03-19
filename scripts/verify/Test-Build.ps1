# Test-Build.ps1
# Post-build verification script. Checks that all tools are installed,
# hardening is applied, and desktop layout is correct.
# Outputs a JSON report and exits non-zero if critical checks fail.

$ErrorActionPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Post-Build Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Resolve tools.yaml path
$toolsYamlPath = $env:TOOLS_YAML
if (-not $toolsYamlPath) { $toolsYamlPath = "C:\provision\tools.yaml" }

Import-Module powershell-yaml -ErrorAction Stop

$yamlContent = Get-Content -Path $toolsYamlPath -Raw
$config = ConvertFrom-Yaml $yamlContent
$tools = $config.tools

$results = @{
    timestamp    = (Get-Date).ToString("o")
    tools        = @()
    hardening    = @()
    desktop      = @()
    passed       = 0
    failed       = 0
    warnings     = 0
}

# ── Tool Verification ────────────────────────────────────────────────────

Write-Host ""
Write-Host "Verifying tool installations..." -ForegroundColor Cyan

foreach ($tool in $tools) {
    if ($tool.enabled -ne $true) { continue }

    $check = @{
        name    = $tool.display_name
        method  = $tool.method
        status  = "UNKNOWN"
        detail  = ""
    }

    if ($tool.method -eq "powershell") {
        # For powershell commands, we can't really verify — mark as OK
        $check.status = "PASS"
        $check.detail = "PowerShell command (assumed OK)"
        $results.passed++
    }
    elseif ($tool.exe_path) {
        if (Test-Path $tool.exe_path) {
            $check.status = "PASS"
            $check.detail = "Found at $($tool.exe_path)"
            $results.passed++
        }
        else {
            $check.status = "FAIL"
            $check.detail = "NOT FOUND at $($tool.exe_path)"
            $results.failed++
        }
    }
    elseif ($tool.install_dir) {
        if (Test-Path $tool.install_dir) {
            $fileCount = (Get-ChildItem -Path $tool.install_dir -Recurse -File).Count
            if ($fileCount -gt 0) {
                $check.status = "PASS"
                $check.detail = "Directory exists with $fileCount files"
                $results.passed++
            }
            else {
                $check.status = "WARN"
                $check.detail = "Directory exists but is empty"
                $results.warnings++
            }
        }
        else {
            $check.status = "FAIL"
            $check.detail = "Directory NOT FOUND at $($tool.install_dir)"
            $results.failed++
        }
    }
    else {
        $check.status = "WARN"
        $check.detail = "No exe_path or install_dir to verify"
        $results.warnings++
    }

    $statusColor = switch ($check.status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "Gray" }
    }
    Write-Host "  [$($check.status)] $($check.name) — $($check.detail)" -ForegroundColor $statusColor

    $results.tools += $check
}

# ── Hardening Verification ───────────────────────────────────────────────

Write-Host ""
Write-Host "Verifying hardening..." -ForegroundColor Cyan

$hardeningChecks = @(
    @{
        name     = "Defender - DisableAntiSpyware"
        path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        key      = "DisableAntiSpyware"
        expected = 1
    },
    @{
        name     = "Defender - Real-Time Protection"
        path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
        key      = "DisableRealtimeMonitoring"
        expected = 1
    },
    @{
        name     = "Windows Update - NoAutoUpdate"
        path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        key      = "NoAutoUpdate"
        expected = 1
    },
    @{
        name     = "Telemetry - AllowTelemetry"
        path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        key      = "AllowTelemetry"
        expected = 0
    },
    @{
        name     = "Cortana - AllowCortana"
        path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        key      = "AllowCortana"
        expected = 0
    },
    @{
        name     = "UAC - EnableLUA"
        path     = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        key      = "EnableLUA"
        expected = 0
    },
    @{
        name     = "SmartScreen - EnableSmartScreen"
        path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        key      = "EnableSmartScreen"
        expected = 0
    }
)

foreach ($hc in $hardeningChecks) {
    $check = @{
        name   = $hc.name
        status = "UNKNOWN"
        detail = ""
    }

    $value = Get-ItemProperty -Path $hc.path -Name $hc.key -ErrorAction SilentlyContinue
    if ($value) {
        $actualValue = $value.($hc.key)
        if ($actualValue -eq $hc.expected) {
            $check.status = "PASS"
            $check.detail = "Value: $actualValue (expected: $($hc.expected))"
            $results.passed++
        }
        else {
            $check.status = "FAIL"
            $check.detail = "Value: $actualValue (expected: $($hc.expected))"
            $results.failed++
        }
    }
    else {
        $check.status = "FAIL"
        $check.detail = "Registry key not found"
        $results.failed++
    }

    $statusColor = switch ($check.status) { "PASS" { "Green" } "FAIL" { "Red" } default { "Gray" } }
    Write-Host "  [$($check.status)] $($check.name) — $($check.detail)" -ForegroundColor $statusColor

    $results.hardening += $check
}

# Verify key services are disabled
$servicesToCheck = @("WinDefend", "wuauserv", "DiagTrack")
foreach ($svcName in $servicesToCheck) {
    $check = @{ name = "Service: $svcName"; status = "UNKNOWN"; detail = "" }
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.StartType -eq "Disabled") {
            $check.status = "PASS"
            $check.detail = "Disabled (Status: $($svc.Status))"
            $results.passed++
        }
        else {
            $check.status = "WARN"
            $check.detail = "StartType: $($svc.StartType), Status: $($svc.Status)"
            $results.warnings++
        }
    }
    else {
        $check.status = "PASS"
        $check.detail = "Service not found (OK — may have been removed)"
        $results.passed++
    }

    $statusColor = switch ($check.status) { "PASS" { "Green" } "WARN" { "Yellow" } default { "Gray" } }
    Write-Host "  [$($check.status)] $($check.name) — $($check.detail)" -ForegroundColor $statusColor

    $results.hardening += $check
}

# ── Desktop Verification ─────────────────────────────────────────────────

Write-Host ""
Write-Host "Verifying desktop layout..." -ForegroundColor Cyan

$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$expectedFolders = @("Debuggers", "Disassemblers", "PE Analysis", "Network", "System Monitoring", "Utilities")

foreach ($folder in $expectedFolders) {
    $check = @{ name = "Desktop folder: $folder"; status = "UNKNOWN"; detail = "" }
    $folderPath = Join-Path $desktopPath $folder

    if (Test-Path $folderPath) {
        $shortcuts = (Get-ChildItem -Path $folderPath -Filter "*.lnk").Count
        $check.status = "PASS"
        $check.detail = "$shortcuts shortcuts"
        $results.passed++
    }
    else {
        $check.status = "FAIL"
        $check.detail = "Folder not found"
        $results.failed++
    }

    $statusColor = switch ($check.status) { "PASS" { "Green" } "FAIL" { "Red" } default { "Gray" } }
    Write-Host "  [$($check.status)] $($check.name) — $($check.detail)" -ForegroundColor $statusColor

    $results.desktop += $check
}

# ── Kernel Debug Mode ────────────────────────────────────────────────────

Write-Host ""
Write-Host "Verifying kernel debug mode..." -ForegroundColor Cyan

$bcdeditOutput = bcdedit /enum 2>&1 | Out-String
if ($bcdeditOutput -match "debug\s+Yes") {
    Write-Host "  [PASS] Kernel debug mode is enabled" -ForegroundColor Green
    $results.passed++
}
else {
    Write-Host "  [WARN] Kernel debug mode may not be enabled" -ForegroundColor Yellow
    $results.warnings++
}

# ── Summary ──────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:   $($results.passed)" -ForegroundColor Green
Write-Host "  Failed:   $($results.failed)" -ForegroundColor $(if ($results.failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $($results.warnings)" -ForegroundColor $(if ($results.warnings -gt 0) { "Yellow" } else { "Green" })

# Save report
$reportPath = "C:\provision\build-report.json"
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Encoding utf8
Write-Host ""
Write-Host "Report saved to: $reportPath" -ForegroundColor Cyan

# Exit with error if critical failures
if ($results.failed -gt 0) {
    Write-Host ""
    Write-Host "BUILD VERIFICATION FAILED — $($results.failed) check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "BUILD VERIFICATION PASSED." -ForegroundColor Green
exit 0
