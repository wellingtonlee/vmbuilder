# Install-DirectDownload.ps1
# Downloads and installs a tool from a direct URL
#
# Parameters:
#   -Url           Download URL
#   -DownloadType  Type of download: zip, exe, msi
#   -InstallDir    Target installation directory
#   -SilentArgs    Silent install arguments (for exe/msi)
#   -DisplayName   Human-readable tool name for logging

param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [Parameter(Mandatory = $true)]
    [ValidateSet("zip", "exe", "msi", "7z")]
    [string]$DownloadType,

    [Parameter(Mandatory = $true)]
    [string]$InstallDir,

    [string]$SilentArgs = "",

    [string]$DisplayName = "Unknown"
)

$ErrorActionPreference = "Stop"

Write-Host "  [direct] Installing $DisplayName..." -ForegroundColor Yellow
Write-Host "  [direct] URL: $Url" -ForegroundColor DarkGray

# Create temp download directory
$tempDir = Join-Path $env:TEMP "vmbuilder_downloads"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Determine filename from URL
$fileName = [System.IO.Path]::GetFileName(([System.Uri]$Url).LocalPath)
if (-not $fileName) { $fileName = "$DisplayName.$DownloadType" }
$downloadPath = Join-Path $tempDir $fileName

try {
    # Download file
    Write-Host "  [direct] Downloading..." -ForegroundColor DarkGray
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "VMBuilder/1.0")
    $webClient.DownloadFile($Url, $downloadPath)
    Write-Host "  [direct] Downloaded to $downloadPath" -ForegroundColor DarkGray

    switch ($DownloadType) {
        "zip" {
            # Extract zip to install directory
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            Write-Host "  [direct] Extracting to $InstallDir..." -ForegroundColor DarkGray
            Expand-Archive -Path $downloadPath -DestinationPath $InstallDir -Force

            # If the zip contains a single top-level directory, flatten it
            $children = Get-ChildItem -Path $InstallDir
            if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
                $innerDir = $children[0].FullName
                Get-ChildItem -Path $innerDir | Move-Item -Destination $InstallDir -Force
                Remove-Item -Path $innerDir -Force -Recurse
            }
        }

        "7z" {
            # Extract 7z archive (requires 7-Zip to be installed first)
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            Write-Host "  [direct] Extracting 7z to $InstallDir..." -ForegroundColor DarkGray
            $sevenZip = "C:\Program Files\7-Zip\7z.exe"
            if (-not (Test-Path $sevenZip)) {
                throw "7-Zip not found at $sevenZip. Ensure 7-Zip is installed first."
            }
            & $sevenZip x $downloadPath -o"$InstallDir" -y | Out-Null
        }

        "exe" {
            if ($SilentArgs) {
                Write-Host "  [direct] Running installer with args: $SilentArgs" -ForegroundColor DarkGray
                $process = Start-Process -FilePath $downloadPath -ArgumentList $SilentArgs -Wait -PassThru -NoNewWindow
            }
            else {
                # Try common silent args
                Write-Host "  [direct] Running installer with /S..." -ForegroundColor DarkGray
                $process = Start-Process -FilePath $downloadPath -ArgumentList "/S" -Wait -PassThru -NoNewWindow
            }

            if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
                throw "Installer exited with code $($process.ExitCode)"
            }
        }

        "msi" {
            $msiArgs = "/i `"$downloadPath`" /qn /norestart"
            if ($SilentArgs) { $msiArgs += " $SilentArgs" }
            Write-Host "  [direct] Running msiexec: $msiArgs" -ForegroundColor DarkGray
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
                throw "MSI installer exited with code $($process.ExitCode)"
            }
        }
    }

    Write-Host "  [direct] $DisplayName installed successfully." -ForegroundColor Green
    return @{ Success = $true; Method = "direct-download"; Url = $Url }
}
catch {
    Write-Host "  [direct] FAILED to install $DisplayName : $_" -ForegroundColor Red
    return @{ Success = $false; Method = "direct-download"; Url = $Url; Error = $_.ToString() }
}
finally {
    # Clean up downloaded file
    if (Test-Path $downloadPath) {
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
    }
}
