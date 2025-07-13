# Load the functions without running the main script
$ErrorActionPreference = 'Stop'

# Define the logging function
function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    Write-Host "[$Level] $Message"
}

# Define the Get-CiscoInstalledProducts function
function Get-CiscoInstalledProducts {
    Write-Log "Searching for installed Cisco Secure Client components..."
    
    $InstalledProducts = @()
    
    # Known product codes for version 5.1.10.233
    $KnownProducts = @(
        @{
            Name = "Cisco Secure Client - Diagnostics and Reporting Tool"
            Code = "{B68CDB22-0490-4275-9645-ECF202869592}"
            Order = 1
        },
        @{
            Name = "Cisco Secure Client - Umbrella"
            Code = "{51DAD0BB-84FA-4942-A00C-D4014529D6A5}"
            Order = 2
        },
        @{
            Name = "Cisco Secure Client - AnyConnect VPN"
            Code = "{A39D1E16-8CCD-44EC-9ADF-33C04A3F590F}"
            Order = 3
        }
    )
    
    # Check registry for installed components
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($Path in $RegistryPaths) {
        if (Test-Path $Path) {
            $Items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
            
            foreach ($Item in $Items) {
                $App = Get-ItemProperty -Path $Item.PSPath -ErrorAction SilentlyContinue
                
                if ($App.DisplayName -like "*Cisco Secure Client*" -or $App.DisplayName -like "*Cisco AnyConnect*") {
                    # Check if it's a known product
                    $KnownProduct = $KnownProducts | Where-Object { $_.Code -eq $Item.PSChildName }
                    
                    if ($KnownProduct) {
                        $InstalledProducts += @{
                            Name = $KnownProduct.Name
                            Code = $KnownProduct.Code
                            Order = $KnownProduct.Order
                            Version = $App.DisplayVersion
                        }
                    }
                    else {
                        # Unknown Cisco product
                        $InstalledProducts += @{
                            Name = $App.DisplayName
                            Code = $Item.PSChildName
                            Order = 99  # Uninstall unknown products last
                            Version = $App.DisplayVersion
                        }
                    }
                    
                    Write-Log "Found: $($App.DisplayName) v$($App.DisplayVersion)"
                }
            }
        }
    }
    
    Write-Host "`nBefore sorting:"
    Write-Host "InstalledProducts count: $($InstalledProducts.Count)"
    Write-Host "InstalledProducts type: $($InstalledProducts.GetType().Name)"
    
    # Sort by order (uninstall in reverse order of installation)
    # PowerShell 5.1 compatibility: ensure we only return hashtables
    $SortedProducts = @()
    foreach ($Product in $InstalledProducts) {
        if ($Product -is [hashtable]) {
            $SortedProducts += $Product
        }
    }
    
    Write-Host "`nAfter filtering:"
    Write-Host "SortedProducts count: $($SortedProducts.Count)"
    
    # Ensure we always return an array, even with single item
    if ($SortedProducts.Count -eq 0) {
        return @()
    } elseif ($SortedProducts.Count -eq 1) {
        return @($SortedProducts[0])
    } else {
        return @($SortedProducts | Sort-Object -Property { $_['Order'] })
    }
}

# Test the function
$products = Get-CiscoInstalledProducts

Write-Host "`nFinal result:"
Write-Host "Type: $($products.GetType().Name)"
Write-Host "Count: $($products.Count)"

foreach ($p in $products) {
    Write-Host "`nProduct:"
    Write-Host "  Type: $($p.GetType().Name)"
    if ($p -is [hashtable]) {
        Write-Host "  Name: $($p['Name'])"
        Write-Host "  Code: $($p['Code'])"
    }
}