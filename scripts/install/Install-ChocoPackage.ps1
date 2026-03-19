# Install-ChocoPackage.ps1
# Installs a tool via Chocolatey
#
# Parameters:
#   -Name          Chocolatey package name
#   -Params        Optional Chocolatey params string (--params)
#   -DisplayName   Human-readable tool name for logging

param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Params = "",

    [string]$DisplayName = $Name
)

$ErrorActionPreference = "Stop"

Write-Host "  [choco] Installing $DisplayName ($Name)..." -ForegroundColor Yellow

$chocoArgs = @("install", $Name, "-y", "--no-progress")
if ($Params) {
    $chocoArgs += "--params"
    $chocoArgs += "`"$Params`""
}

try {
    $output = & choco @chocoArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        # Exit code 3010 = reboot required, still success
        Write-Host "  [choco] First attempt failed (exit $exitCode), retrying..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 5
        $output = & choco @chocoArgs 2>&1
        $exitCode = $LASTEXITCODE
    }

    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        throw "Chocolatey install failed with exit code $exitCode`n$($output -join "`n")"
    }

    Write-Host "  [choco] $DisplayName installed successfully." -ForegroundColor Green
    return @{ Success = $true; Method = "choco"; Package = $Name }
}
catch {
    Write-Host "  [choco] FAILED to install $DisplayName : $_" -ForegroundColor Red
    return @{ Success = $false; Method = "choco"; Package = $Name; Error = $_.ToString() }
}
