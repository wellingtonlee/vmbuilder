# Invoke-PSCommand.ps1
# Executes an arbitrary PowerShell command for tool configuration
#
# Parameters:
#   -Command       PowerShell command to execute
#   -DisplayName   Human-readable name for logging

param(
    [Parameter(Mandatory = $true)]
    [string]$Command,

    [string]$DisplayName = "PowerShell Command"
)

$ErrorActionPreference = "Stop"

Write-Host "  [ps] Executing: $DisplayName" -ForegroundColor Yellow
Write-Host "  [ps] Command: $Command" -ForegroundColor DarkGray

try {
    $output = Invoke-Expression $Command 2>&1
    if ($output) {
        Write-Host "  [ps] Output: $output" -ForegroundColor DarkGray
    }
    Write-Host "  [ps] $DisplayName executed successfully." -ForegroundColor Green
    return @{ Success = $true; Method = "powershell"; Command = $Command }
}
catch {
    Write-Host "  [ps] FAILED: $DisplayName : $_" -ForegroundColor Red
    return @{ Success = $false; Method = "powershell"; Command = $Command; Error = $_.ToString() }
}
