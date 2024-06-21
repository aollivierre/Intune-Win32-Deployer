#Unique Tracking ID: a49418eb-0a85-400f-a576-d8d879a6b7c6, Timestamp: 2024-04-04 18:30:46
<#
.SYNOPSIS
Checks for the installation of 7zip versions older than 24.01.00.0.

.DESCRIPTION
This script searches the system's uninstallation registry keys for 7zip installations. 
It checks if any installed version is older than 24.01.00.0 and provides feedback based on this condition.

.NOTES
Version:        1.0
Author:         Abdullah Ollivierre
Creation Date:  2024-03-05
#>

# Define global variables
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$softwareNamePattern = "*7-zip*"
$versionThreshold = New-Object Version "24.01.00.0"

# Function to check for 7zip versions older than a specified version
function Find-Older7zipVersion {
    param (
        [string[]]$RegistryPaths,
        [string]$SoftwareNamePattern,
        [version]$VersionThreshold
    )

    foreach ($path in $RegistryPaths) {
        $items = Get-ChildItem -Path $path

        foreach ($item in $items) {
            $app = Get-ItemProperty -Path $item.PsPath
            if ($app.DisplayName -like $SoftwareNamePattern) {
                $appVersion = New-Object Version $app.DisplayVersion
                if ($appVersion -lt $VersionThreshold) {
                    return @{
                        Found = $true
                        ProductCode = $app.PSChildName
                        Version = $app.DisplayVersion
                    }
                }
            }
        }
    }

    return @{Found = $false}
}

# Main script execution
$findResult = Find-Older7zipVersion -RegistryPaths $registryPaths -SoftwareNamePattern $softwareNamePattern -VersionThreshold $versionThreshold

if ($findResult.Found) {
    Write-Output "An older version of 7zip (version $($findResult.Version)) is installed with product code $($findResult.ProductCode)."
    exit 0
} else {
    # Write-Output "No version of 7zip older than $versionThreshold is installed."
    exit 1
}
