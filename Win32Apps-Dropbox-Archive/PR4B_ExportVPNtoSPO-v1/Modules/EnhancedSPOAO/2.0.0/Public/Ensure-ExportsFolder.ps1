function Ensure-ExportsFolder {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    # Construct the full path to the exports folder
    $ExportsBaseFolderPath = Join-Path -Path $BasePath -ChildPath "Exports"
    $ExportsFolderPath = Join-Path -Path $ExportsBaseFolderPath -ChildPath "VPNExport"

    # Check if the base exports folder exists
    if (-Not (Test-Path -Path $ExportsBaseFolderPath)) {
        # Create the base exports folder
        New-Item -ItemType Directory -Path $ExportsBaseFolderPath | Out-Null
        Write-EnhancedLog -Message "Created base exports folder at: $ExportsBaseFolderPath" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }

    # Check if the VPN export folder exists
    if (-Not (Test-Path -Path $ExportsFolderPath)) {
        # Create the VPN export folder
        New-Item -ItemType Directory -Path $ExportsFolderPath | Out-Null
        Write-EnhancedLog -Message "Created VPN export folder at: $ExportsFolderPath" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    } else {
        Write-EnhancedLog -Message "VPN export folder already exists at: $ExportsFolderPath" -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)
    }

    # Return the full path of the exports folder
    return $ExportsFolderPath
}
