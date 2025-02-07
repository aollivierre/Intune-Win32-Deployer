# Get the directory where the script is located
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolve paths for MSI and settings files
$msiPath = Join-Path -Path $scriptPath -ChildPath "TV.msi"
$settingsFilePath = Join-Path -Path $scriptPath -ChildPath "s.tvopt"

# Verify files exist
if (-not (Test-Path $msiPath)) {
    Write-Error "TeamViewer MSI file not found at: $msiPath"
    exit 1
}

if (-not (Test-Path $settingsFilePath)) {
    Write-Error "TeamViewer settings file not found at: $settingsFilePath"
    exit 1
}

# Install TeamViewer
Start-Process -FilePath "MSIEXEC.EXE" -ArgumentList "/i", $msiPath, "/qn", "CUSTOMCONFIGID=he26pyq", "SETTINGSFILE=$settingsFilePath" -Wait
Start-Sleep -Seconds 30

# Possible TeamViewer installation paths
$teamViewerPaths = @(
    "C:\Program Files\TeamViewer\TeamViewer.exe",
    "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"
)

# Find the actual TeamViewer path
$teamViewerExe = $null
foreach ($path in $teamViewerPaths) {
    if (Test-Path $path) {
        $teamViewerExe = $path
        break
    }
}

if ($teamViewerExe) {
    Start-Process -FilePath $teamViewerExe -ArgumentList "assignment", "--id", "0001CoABChA0Wtyw41UR74SOzFGxK_rXEigIACAAAgAJACbSLLKpBBA6xZ-LyQnQTR-eZS-k2LbZwnYA3hzgn3SyGkDPy2YN1c_GAI_NPqig6Pj2KlsEx8tWXmtGjlI2edd2S45EsUzHcwJ7NxQ8FYG76qUp2Y4MyeLXBJ5zKbYzGP2uIAEQ9-LB8g0="
} else {
    Write-Error "TeamViewer executable not found in any of the expected locations"
    exit 1
}