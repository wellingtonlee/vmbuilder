# Install-Tools.ps1
# Main tool dispatcher — reads tools.yaml and installs each enabled tool
# using the appropriate method handler.

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Installing Malware Analysis Tools" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Resolve paths
$toolsYamlPath = $env:TOOLS_YAML
if (-not $toolsYamlPath) { $toolsYamlPath = "C:\provision\tools.yaml" }
$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import YAML module
Import-Module powershell-yaml -ErrorAction Stop

# Read and parse tools.yaml
Write-Host "Reading tools configuration from: $toolsYamlPath" -ForegroundColor Cyan
$yamlContent = Get-Content -Path $toolsYamlPath -Raw
$config = ConvertFrom-Yaml $yamlContent

$tools = $config.tools
$totalTools = ($tools | Where-Object { $_.enabled -eq $true }).Count
Write-Host "Found $totalTools enabled tools to install." -ForegroundColor Cyan
Write-Host ""

# Track results
$results = @()
$currentTool = 0

foreach ($tool in $tools) {
    if ($tool.enabled -ne $true) {
        Write-Host "[$($tool.display_name)] SKIPPED (disabled)" -ForegroundColor DarkGray
        continue
    }

    $currentTool++
    Write-Host "----------------------------------------" -ForegroundColor DarkCyan
    Write-Host "[$currentTool/$totalTools] $($tool.display_name)" -ForegroundColor Cyan
    Write-Host "  Method: $($tool.method)" -ForegroundColor DarkGray

    $result = $null

    try {
        switch ($tool.method) {
            "choco" {
                $result = & "$scriptsDir\Install-ChocoPackage.ps1" `
                    -Name $tool.choco_package `
                    -Params ($tool.choco_params -as [string]) `
                    -DisplayName $tool.display_name
            }

            "direct-download" {
                $result = & "$scriptsDir\Install-DirectDownload.ps1" `
                    -Url $tool.url `
                    -DownloadType $tool.download_type `
                    -InstallDir $tool.install_dir `
                    -SilentArgs ($tool.silent_args -as [string]) `
                    -DisplayName $tool.display_name
            }

            "powershell" {
                $result = & "$scriptsDir\Invoke-PSCommand.ps1" `
                    -Command $tool.command `
                    -DisplayName $tool.display_name
            }

            "shortcut-only" {
                Write-Host "  [shortcut] $($tool.display_name) — no install needed (bundled with $($tool.depends_on))" -ForegroundColor Green
                $result = @{ Success = $true; Method = "shortcut-only" }
            }

            "winget" {
                Write-Host "  [winget] Installing $($tool.display_name) ($($tool.winget_id))..." -ForegroundColor Yellow
                try {
                    $output = winget install $tool.winget_id --accept-source-agreements --accept-package-agreements --silent 2>&1
                    Write-Host "  [winget] $($tool.display_name) installed successfully." -ForegroundColor Green
                    $result = @{ Success = $true; Method = "winget"; Package = $tool.winget_id }
                }
                catch {
                    Write-Host "  [winget] FAILED to install $($tool.display_name): $_" -ForegroundColor Red
                    $result = @{ Success = $false; Method = "winget"; Package = $tool.winget_id; Error = $_.ToString() }
                }
            }

            default {
                Write-Host "  UNKNOWN method: $($tool.method)" -ForegroundColor Red
                $result = @{ Success = $false; Method = $tool.method; Error = "Unknown install method" }
            }
        }

        # Run post_install commands if defined
        if ($result.Success -and $tool.post_install) {
            Write-Host "  [post] Running post-install commands..." -ForegroundColor Yellow
            try {
                Invoke-Expression $tool.post_install
                Write-Host "  [post] Post-install completed." -ForegroundColor Green
            }
            catch {
                Write-Host "  [post] Post-install FAILED: $_" -ForegroundColor Red
                $result.Success = $false
                $result.Error = "Post-install failed: $_"
            }
        }

        # Add PATH entries if defined
        if ($result.Success -and $tool.add_to_path) {
            Write-Host "  [path] Adding to PATH: $($tool.add_to_path)" -ForegroundColor Yellow
            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$($tool.add_to_path)*") {
                [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$($tool.add_to_path)", "Machine")
                $env:Path = "$env:Path;$($tool.add_to_path)"
            }
        }
    }
    catch {
        Write-Host "  EXCEPTION installing $($tool.display_name): $_" -ForegroundColor Red
        $result = @{ Success = $false; Method = $tool.method; Error = $_.ToString() }
    }

    $results += @{
        Name        = $tool.name
        DisplayName = $tool.display_name
        Method      = $tool.method
        Success     = $result.Success
        Error       = $result.Error
    }
}

# Write install report
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Install Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$succeeded = ($results | Where-Object { $_.Success -eq $true }).Count
$failed = ($results | Where-Object { $_.Success -eq $false }).Count

Write-Host "  Succeeded: $succeeded" -ForegroundColor Green
Write-Host "  Failed:    $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "  Failed tools:" -ForegroundColor Red
    $results | Where-Object { $_.Success -eq $false } | ForEach-Object {
        Write-Host "    - $($_.DisplayName): $($_.Error)" -ForegroundColor Red
    }
}

# Save report to JSON
$reportPath = "C:\provision\install-report.json"
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Encoding utf8
Write-Host ""
Write-Host "Install report saved to: $reportPath" -ForegroundColor Cyan
