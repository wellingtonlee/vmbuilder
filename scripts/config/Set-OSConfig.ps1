# Set-OSConfig.ps1
# Configures Windows 11 cosmetic and usability settings for malware analysis.
# Dark mode, file extensions, hidden files, console font, wallpaper.

$ErrorActionPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " OS Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$userSid = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $env:USERNAME }).SID
$hkuPath = "Registry::HKU\$userSid"

# ── Dark Mode ────────────────────────────────────────────────────────────

Write-Host "[1/6] Enabling dark mode..." -ForegroundColor Yellow

$themePath = "$hkuPath\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $themePath)) {
    New-Item -Path $themePath -Force | Out-Null
}
Set-ItemProperty -Path $themePath -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $themePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force

# Also set for current user via HKCU
$hkcuThemePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $hkcuThemePath)) {
    New-Item -Path $hkcuThemePath -Force | Out-Null
}
Set-ItemProperty -Path $hkcuThemePath -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $hkcuThemePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force

Write-Host "  Dark mode enabled." -ForegroundColor Green

# ── Show File Extensions ─────────────────────────────────────────────────

Write-Host "[2/6] Showing file extensions..." -ForegroundColor Yellow

$explorerPath = "$hkuPath\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $explorerPath)) {
    New-Item -Path $explorerPath -Force | Out-Null
}
Set-ItemProperty -Path $explorerPath -Name "HideFileExt" -Value 0 -Type DWord -Force

$hkcuExplorerPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $hkcuExplorerPath -Name "HideFileExt" -Value 0 -Type DWord -Force

Write-Host "  File extensions visible." -ForegroundColor Green

# ── Show Hidden Files ────────────────────────────────────────────────────

Write-Host "[3/6] Showing hidden files and protected OS files..." -ForegroundColor Yellow

Set-ItemProperty -Path $hkcuExplorerPath -Name "Hidden" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $hkcuExplorerPath -Name "ShowSuperHidden" -Value 1 -Type DWord -Force

if (Test-Path $explorerPath) {
    Set-ItemProperty -Path $explorerPath -Name "Hidden" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $explorerPath -Name "ShowSuperHidden" -Value 1 -Type DWord -Force
}

Write-Host "  Hidden files and protected OS files visible." -ForegroundColor Green

# ── Disable News and Interests / Widgets ─────────────────────────────────

Write-Host "[4/6] Disabling taskbar widgets..." -ForegroundColor Yellow

# Windows 11 widgets
$widgetsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
New-Item -Path $widgetsPath -Force | Out-Null
Set-ItemProperty -Path $widgetsPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force

# Also disable via user settings
$taskbarPath = "$hkuPath\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (Test-Path $taskbarPath) {
    Set-ItemProperty -Path $taskbarPath -Name "TaskbarDa" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $taskbarPath -Name "TaskbarMn" -Value 0 -Type DWord -Force
}

Set-ItemProperty -Path $hkcuExplorerPath -Name "TaskbarDa" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $hkcuExplorerPath -Name "TaskbarMn" -Value 0 -Type DWord -Force

Write-Host "  Taskbar widgets disabled." -ForegroundColor Green

# ── Set Default Console Font ─────────────────────────────────────────────

Write-Host "[5/6] Setting default console font to MesloLGS NF..." -ForegroundColor Yellow

$consolePath = "HKCU:\Console"
Set-ItemProperty -Path $consolePath -Name "FaceName" -Value "MesloLGS Nerd Font" -Type String -Force
Set-ItemProperty -Path $consolePath -Name "FontSize" -Value 0x000e0000 -Type DWord -Force

# Also set for Windows Terminal if present
$wtSettingsDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (Test-Path $wtSettingsDir) {
    $wtSettingsPath = Join-Path $wtSettingsDir "settings.json"
    if (Test-Path $wtSettingsPath) {
        $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
        if (-not $wtSettings.profiles.defaults) {
            $wtSettings.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value @{} -Force
        }
        $wtSettings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value @{ face = "MesloLGS Nerd Font"; size = 11 } -Force
        $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding utf8
    }
}

Write-Host "  Console font configured." -ForegroundColor Green

# ── Set Wallpaper ────────────────────────────────────────────────────────

Write-Host "[6/6] Configuring wallpaper..." -ForegroundColor Yellow

$wallpaperSource = "C:\provision\scripts\..\..\resources\wallpaper.png"
if (Test-Path "C:\provision\wallpaper.png") {
    $wallpaperSource = "C:\provision\wallpaper.png"
}

if (Test-Path $wallpaperSource) {
    $wallpaperDest = "C:\Windows\Web\Wallpaper\MalwareAnalysis.png"
    Copy-Item -Path $wallpaperSource -Destination $wallpaperDest -Force

    $wallpaperRegPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $wallpaperRegPath -Name "Wallpaper" -Value $wallpaperDest -Type String -Force
    Set-ItemProperty -Path $wallpaperRegPath -Name "WallpaperStyle" -Value "10" -Type String -Force  # Fill

    # Apply wallpaper
    Add-Type -TypeDefinition @"
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@
    [Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperDest, 0x0003)

    Write-Host "  Custom wallpaper applied." -ForegroundColor Green
}
else {
    Write-Host "  No custom wallpaper found, keeping default." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " OS Configuration complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
