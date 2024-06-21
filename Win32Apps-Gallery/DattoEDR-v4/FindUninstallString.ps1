#Unique Tracking ID: 385bc2ee-ba3a-4292-b774-6ef2ff964363, Timestamp: 2024-04-04 18:30:45
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$uninstallString = $null

foreach ($key in $uninstallKeys) {
    Get-ChildItem -Path $key |
    ForEach-Object {
        $app = Get-ItemProperty -Path $_.PsPath
        if ($app.DisplayName -like "*Datto*") {
            $uninstallString = $app.UninstallString
            break
        }
    }
    
    if ($uninstallString) {
        break
    }
}

if ($null -ne $uninstallString) {
    Write-Host "Found uninstall string: $uninstallString"
    # Execute the uninstall command
    # & cmd /c $uninstallString "/qn"
} else {
    Write-Host "Uninstall string not found."
}



# Found uninstall string: "C:\Program Files\infocyte\agent\agent.exe" --uninstall
