   # Define the parameters for the validation
   $params = @{
    SoftwareName  = "Datto RMM"
    MinVersion    = [version]"4.4.2230.2230"
    LatestVersion = [version]"4.4.2230.2230"
    RegistryPath  = "HKLM:\SOFTWARE\Datto RMM"
    ExePath       = "C:\Program Files (x86)\CentraStage\CagService.exe"
}

# Call Validate-SoftwareInstallation
$validationResult = Validate-SoftwareInstallation @params

# Logic based on the result of Validate-SoftwareInstallation
if ($validationResult.IsInstalled) {
    if ($validationResult.MeetsMinRequirement) {
        if ($validationResult.IsUpToDate) {
            Write-Host "$($params.SoftwareName) is installed, meets the minimum requirement, and is up-to-date."
            exit 0  # Software is installed, meets the min version, and is up-to-date
        }
        else {
            Write-Host "$($params.SoftwareName) is installed, meets the minimum requirement, but is not up-to-date. Consider updating."
            exit 1  # Software is installed, meets min version, but is not the latest version
        }
    }
    else {
        Write-Host "$($params.SoftwareName) is installed, but does not meet the minimum version requirement."
        exit 1  # Software is installed but doesn't meet the minimum required version
    }
}
else {
    Write-Host "$($params.SoftwareName) is not installed."
    exit 1  # Software is not installed
}