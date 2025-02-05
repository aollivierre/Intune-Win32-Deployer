#Unique Tracking ID: e40d98b4-03a5-40dd-b624-e2d68d8c33d6, Timestamp: 2024-04-04 18:30:45
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$softwareNamePattern = "*Datto RMM*"

# Function to check for any installed version of DattoEDR
function Find-DattoEDR {
    param (
        [string[]]$RegistryPaths,
        [string]$SoftwareNamePattern
    )

    foreach ($path in $RegistryPaths) {
        $items = Get-ChildItem -Path $path

        foreach ($item in $items) {
            $app = Get-ItemProperty -Path $item.PsPath
            if ($app.DisplayName -like $SoftwareNamePattern) {
                return @{
                    Found           = $true
                    DisplayName     = $app.DisplayName
                    Version         = $app.DisplayVersion
                    InstallLocation = $app.InstallLocation
                }
            }
        }
    }

    return @{Found = $false }
}

# Main script execution
$findResult = Find-DattoEDR -RegistryPaths $registryPaths -SoftwareNamePattern $softwareNamePattern

if ($findResult.Found) {
    Write-Output "DattoEDR is installed. Details:"
    Write-Output "Name: $($findResult.DisplayName)"
    Write-Output "Version: $($findResult.Version)"
    Write-Output "Install Location: $($findResult.InstallLocation)"
}
else {
    Write-Output "DattoEDR is not installed."
}



# DattoEDR is installed. Details:
# Name: Datto EDR Agent
# Version: 3.8.0.1850
# Install Location:
