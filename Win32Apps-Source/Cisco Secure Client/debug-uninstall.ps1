# Debug the Get-CiscoInstalledProducts function
. "C:\code\Cisco Secure Client\uninstall.ps1" -DebugPreference 'Continue'

# Get the products
$products = Get-CiscoInstalledProducts

Write-Host "`nTotal products found: $($products.Count)"
Write-Host "Products array type: $($products.GetType().Name)"

for ($i = 0; $i -lt $products.Count; $i++) {
    $p = $products[$i]
    Write-Host "`n[$i] Type: $($p.GetType().Name)"
    if ($p -is [hashtable]) {
        Write-Host "    Name: $($p['Name'])"
        Write-Host "    Code: $($p['Code'])"
        Write-Host "    Order: $($p['Order'])"
    } elseif ($p -is [string]) {
        Write-Host "    String value: '$p'"
    } else {
        Write-Host "    Unknown type value: $p"
    }
}