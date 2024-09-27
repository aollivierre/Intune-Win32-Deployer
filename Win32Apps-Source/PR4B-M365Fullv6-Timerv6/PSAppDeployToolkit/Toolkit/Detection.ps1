# Note: If you add the Logic to handle PSF and Transcription logging here while calling the script using & "$PSScriptRoot\Detection.ps1" from another script it will cause issues with transcription because it will exit before stopping the transcription

# Function to fetch the latest Microsoft 365 version and build from the web
function Get-LatestM365Version {
    $releaseNotesUrl = "https://learn.microsoft.com/en-us/officeupdates/current-channel"
    $response = Invoke-WebRequest -Uri $releaseNotesUrl -UseBasicParsing -ErrorAction Stop
    $pageContent = $response.Content

    $versionPattern = 'Version (\d{4})'
    $buildPattern = 'Build (\d{5}\.\d{5})'

    $versionMatch = [regex]::Match($pageContent, $versionPattern)
    $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { 'Version not found' }

    $buildMatch = [regex]::Match($pageContent, $buildPattern)
    $build = if ($buildMatch.Success) { $buildMatch.Groups[1].Value } else { 'Build not found' }

    return [pscustomobject]@{
        Version = $version
        Build   = $build
    }
}

# Parameters for validating Microsoft 365 Apps installation
$m365ValidationParams = @{
    SoftwareName        = "Microsoft 365 Apps"
    MinVersion          = [version]"16.0.17928.20156"  
    MaxRetries          = 3
    DelayBetweenRetries = 5
}

$m365ValidationResult = Validate-SoftwareInstallation @m365ValidationParams

if ($null -eq $m365ValidationResult) {
    Write-EnhancedLog -Message "Validation result is null. Exiting." -Level 'ERROR'
    exit 3
}


try {
    $installedVersion = $m365ValidationResult.Version.ToString()
}
catch {
    Write-EnhancedLog -Message "Error retrieving installed version: $_" -Level 'ERROR'
    exit 3
}
# Continue with your existing logic...

$buildPattern = '\d+\.\d+$'
$installedBuildMatch = [regex]::Match($installedVersion, $buildPattern)

if ($installedBuildMatch.Success) {
    $installedBuild = $installedBuildMatch.Value
}
else {
    Write-EnhancedLog -Message "Failed to extract build number from installed version." -Level 'Error'
    exit 3  # Failed to retrieve the build
}

$latestM365Version = Get-LatestM365Version

if ($m365ValidationResult.IsInstalled -and $installedBuild) {
    if ([version]$installedBuild -lt [version]$latestM365Version.Build) {
        Write-EnhancedLog -Message "A newer build of Microsoft 365 Apps is available." -Level 'WARNING'
        Write-EnhancedLog -Message "Installed build: $installedBuild, Latest build: $($latestM365Version.Build)" -Level 'WARNING'
        exit 1  # Update required
    }
    else {
        # Write-EnhancedLog -Message "Microsoft 365 Apps is up-to-date." -Level 'INFO'

        # Optionally output the latest version info
        Write-EnhancedLog -Message "Latest available version from the M365 Release Notes (Current Channel): Version $($latestM365Version.Version) Build: $($latestM365Version.Build)" -ForegroundColor Cyan
        Write-EnhancedLog -Message "Microsoft 365 Apps build $installedBuild is up-to-date." -Level 'INFO'

        exit 0  # No update required
    }
}
else {
    Write-EnhancedLog -Message "Microsoft 365 Apps are not installed or do not meet the minimum version requirement." -Level 'Error'
    exit 2  # Microsoft 365 Apps not installed
}