# Debug script to check what's in the registry
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$CiscoProducts = @()

foreach ($Path in $RegistryPaths) {
    if (Test-Path $Path) {
        $Items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
        
        foreach ($Item in $Items) {
            $App = Get-ItemProperty -Path $Item.PSPath -ErrorAction SilentlyContinue
            
            if ($App.DisplayName -like "*Cisco Secure Client*" -or $App.DisplayName -like "*Cisco AnyConnect*") {
                Write-Host "Found: $($App.DisplayName)"
                Write-Host "  Code: $($Item.PSChildName)"
                Write-Host "  Type: $($Item.GetType().Name)"
                $CiscoProducts += @{
                    Name = $App.DisplayName
                    Code = $Item.PSChildName
                }
            }
        }
    }
}

Write-Host "`nTotal found: $($CiscoProducts.Count)"
foreach ($p in $CiscoProducts) {
    Write-Host "Product: $($p['Name']) - Code: $($p['Code'])"
}