# Define possible TeamViewer paths
$teamViewerPaths = @(
    "C:\Program Files\TeamViewer\TeamViewer.exe",
    "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"
)

# Set timeout parameters
$timeout = New-TimeSpan -Minutes 3
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

while ($stopwatch.Elapsed -lt $timeout) {
    foreach ($path in $teamViewerPaths) {
        if (Test-Path $path) {
            Write-Output "Found TeamViewer at: $path"
            exit 0
        }
    }
    
    # Wait 10 seconds before next check
    Start-Sleep -Seconds 10
}

# If we get here, TeamViewer wasn't found within the timeout period
Write-Output "TeamViewer not found after 3 minutes of checking"
exit 1