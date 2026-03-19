# Set-DesktopLayout.ps1
# Creates organized desktop folders and shortcuts for malware analysis tools.
# Reads tool definitions from tools.yaml to create shortcuts by category.

$ErrorActionPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Desktop Layout Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Resolve tools.yaml path
$toolsYamlPath = $env:TOOLS_YAML
if (-not $toolsYamlPath) { $toolsYamlPath = "C:\provision\tools.yaml" }

# Import YAML module
Import-Module powershell-yaml -ErrorAction Stop

# Read and parse tools.yaml
$yamlContent = Get-Content -Path $toolsYamlPath -Raw
$config = ConvertFrom-Yaml $yamlContent
$tools = $config.tools

# Desktop path
$desktopPath = [System.Environment]::GetFolderPath("Desktop")

# Helper function to create a shortcut
function New-Shortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$Arguments = "",
        [string]$IconPath = "",
        [string]$WorkingDirectory = ""
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath

    if ($Arguments) { $shortcut.Arguments = $Arguments }
    if ($WorkingDirectory) {
        $shortcut.WorkingDirectory = $WorkingDirectory
    }
    else {
        $shortcut.WorkingDirectory = Split-Path -Parent $TargetPath
    }
    if ($IconPath) { $shortcut.IconLocation = $IconPath }

    $shortcut.Save()
}

# Define desktop categories (order matters for display)
$categories = @(
    "Debuggers",
    "Disassemblers",
    "PE Analysis",
    "Network",
    "System Monitoring",
    "Utilities"
)

# Create category folders
foreach ($category in $categories) {
    $folderPath = Join-Path $desktopPath $category
    if (-not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
        Write-Host "Created folder: $category" -ForegroundColor Green
    }
}

# Create shortcuts for each enabled tool with a category
$shortcutCount = 0

foreach ($tool in $tools) {
    if ($tool.enabled -ne $true) { continue }
    if (-not $tool.category) { continue }
    if (-not $tool.exe_path) { continue }

    # Verify the executable exists
    if (-not (Test-Path $tool.exe_path)) {
        Write-Host "  WARNING: Executable not found for $($tool.display_name): $($tool.exe_path)" -ForegroundColor DarkYellow
        # Still create the shortcut — it may work after reboot or PATH refresh
    }

    $categoryFolder = Join-Path $desktopPath $tool.category
    if (-not (Test-Path $categoryFolder)) {
        New-Item -ItemType Directory -Path $categoryFolder -Force | Out-Null
    }

    $shortcutFile = Join-Path $categoryFolder "$($tool.display_name).lnk"

    # Handle special cases where the "exe" is actually a URL or HTML file
    if ($tool.exe_path -match "\.(html?|url)$") {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutFile)
        $shortcut.TargetPath = $tool.exe_path
        $shortcut.Save()
    }
    else {
        New-Shortcut -ShortcutPath $shortcutFile -TargetPath $tool.exe_path
    }

    $shortcutCount++
    Write-Host "  Created shortcut: $($tool.category)\$($tool.display_name)" -ForegroundColor DarkGray
}

# Create additional Sysinternals shortcuts (these are bundled in the sysinternals choco package)
$sysinternalsDir = "C:\ProgramData\chocolatey\lib\sysinternals\tools"
$sysinternalsShortcuts = @{
    "Process Explorer" = "procexp64.exe"
    "Process Monitor"  = "Procmon64.exe"
    "Autoruns"         = "autoruns64.exe"
    "TCPView"          = "tcpview64.exe"
}

$monitoringFolder = Join-Path $desktopPath "System Monitoring"
foreach ($entry in $sysinternalsShortcuts.GetEnumerator()) {
    $exePath = Join-Path $sysinternalsDir $entry.Value
    $shortcutFile = Join-Path $monitoringFolder "$($entry.Key).lnk"

    if (-not (Test-Path $shortcutFile)) {
        New-Shortcut -ShortcutPath $shortcutFile -TargetPath $exePath
        $shortcutCount++
        Write-Host "  Created shortcut: System Monitoring\$($entry.Key)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Desktop Layout complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Categories: $($categories.Count)" -ForegroundColor DarkGray
Write-Host "  Shortcuts:  $shortcutCount" -ForegroundColor DarkGray
