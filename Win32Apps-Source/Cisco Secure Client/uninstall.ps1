<#
.SYNOPSIS
    Uninstalls Cisco Secure Client components.

.DESCRIPTION
    This script uninstalls Cisco Secure Client components in reverse order:
    1. DART component
    2. Umbrella component
    3. Core VPN component
    
    Designed for Intune Win32 app deployment.

.NOTES
    Version:        1.0
    Creation Date:  2025-01-12
    Purpose:        Intune Win32 App Uninstallation Script
    Compatibility:  PowerShell 5.1
#>

#region Script Configuration
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path $LogPath "CiscoSecureClient_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
#endregion

#region Logging Functions
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$TimeStamp [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage -Force
    
    # Also write to console for Intune
    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
        default { Write-Output $Message }
    }
}
#endregion

#region Uninstallation Functions
function Stop-CiscoServices {
    Write-Log "Stopping Cisco services..."
    
    $CiscoServices = @(
        "csc_umbrellaagent",
        "vpnagent",
        "acwebsecagent"
    )
    
    foreach ($ServiceName in $CiscoServices) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq 'Running') {
            Write-Log "Stopping service: $ServiceName"
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
}

function Stop-CiscoProcesses {
    Write-Log "Stopping Cisco processes..."
    
    $CiscoProcesses = @(
        "vpnui",
        "vpnagent",
        "csc_umbrellaagent",
        "acwebsecagent"
    )
    
    foreach ($ProcessName in $CiscoProcesses) {
        $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        if ($Processes) {
            Write-Log "Stopping process: $ProcessName"
            $Processes | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }
}

function Uninstall-CiscoComponent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProductName,
        
        [Parameter(Mandatory=$true)]
        [string]$ProductCode
    )
    
    Write-Log "Uninstalling $ProductName..."
    
    # Sanitize product name for log file
    $LogFileName = $ProductName -replace '[^\w\-\.]', '_'
    $UninstallLogFile = Join-Path $LogPath "${LogFileName}_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $ArgumentList = "/x `"$ProductCode`" /qn /norestart /l*v `"$UninstallLogFile`""
    
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $ArgumentList -Wait -PassThru
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "$ProductName uninstalled successfully."
        return $true
    }
    elseif ($Process.ExitCode -eq 3010) {
        Write-Log "$ProductName uninstalled successfully but requires a reboot." -Level Warning
        return $true
    }
    else {
        Write-Log "$ProductName uninstallation failed with exit code: $($Process.ExitCode)" -Level Error
        return $false
    }
}

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
                        # Unknown Cisco product - validate that we have a proper GUID as product code
                        if ($Item.PSChildName -match "^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$") {
                            $InstalledProducts += @{
                                Name = $App.DisplayName
                                Code = $Item.PSChildName
                                Order = 99  # Uninstall unknown products last
                                Version = $App.DisplayVersion
                            }
                        } else {
                            Write-Log "Skipping registry entry with invalid product code format: $($App.DisplayName) [Code: $($Item.PSChildName)]" -Level Warning
                        }
                    }
                    
                    Write-Log "Found: $($App.DisplayName) v$($App.DisplayVersion)"
                }
            }
        }
    }
    
    # Sort by order (uninstall in reverse order of installation)
    # PowerShell 5.1 compatibility: ensure we only return hashtables
    $SortedProducts = @()
    foreach ($Product in $InstalledProducts) {
        if ($Product -is [hashtable]) {
            $SortedProducts += $Product
        }
    }
    
    # Ensure we always return an array, even with single item
    if ($SortedProducts.Count -eq 0) {
        return @()
    } elseif ($SortedProducts.Count -eq 1) {
        return @($SortedProducts[0])
    } else {
        return @($SortedProducts | Sort-Object -Property { $_['Order'] })
    }
}
#endregion

#region Main Uninstallation Logic
try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    
    Write-Log "=== Cisco Secure Client Uninstallation Started ==="
    
    # Check for administrator privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script must be run with administrator privileges." -Level Error
        exit 1
    }
    
    # Stop services and processes
    Stop-CiscoServices
    Stop-CiscoProcesses
    
    # Get installed Cisco products
    $InstalledProducts = Get-CiscoInstalledProducts
    
    if ($InstalledProducts.Count -eq 0) {
        Write-Log "No Cisco Secure Client components found to uninstall."
        exit 0
    }
    
    Write-Log "Found $($InstalledProducts.Count) component(s) to uninstall:"
    foreach ($Product in $InstalledProducts) {
        if ($Product -and $Product['Name']) {
            Write-Log "  - $($Product['Name']) v$($Product['Version']) [Code: $($Product['Code'])]"
        } else {
            Write-Log "  - Invalid entry detected (missing name/code data)"
        }
    }
    
    # Uninstall each component
    $FailedUninstalls = @()
    $ValidProducts = @()
    $SkippedProducts = 0
    
    foreach ($Product in $InstalledProducts) {
        # Ensure we have valid data
        if (-not $Product -or -not $Product['Name'] -or -not $Product['Code']) {
            $SkippedProducts++
            if ($Product -and $Product['Name']) {
                Write-Log "Skipping invalid product entry: $($Product['Name']) (missing product code)" -Level Warning
            } elseif ($Product -and $Product['Code']) {
                Write-Log "Skipping invalid product entry: Code $($Product['Code']) (missing product name)" -Level Warning  
            } else {
                Write-Log "Skipping invalid product entry: Completely malformed registry data" -Level Warning
            }
            continue
        }
        
        $ValidProducts += $Product
    }
    
    if ($SkippedProducts -gt 0) {
        Write-Log "Skipped $SkippedProducts invalid registry entries. Proceeding with $($ValidProducts.Count) valid components."
    }
    
    # Process valid products
    foreach ($Product in $ValidProducts) {
        Write-Log "Uninstalling: $($Product['Name'])"
        $Success = Uninstall-CiscoComponent -ProductName $Product['Name'] -ProductCode $Product['Code']
        
        if (-not $Success) {
            $FailedUninstalls += $Product['Name']
        }
        
        # Wait between uninstalls
        Start-Sleep -Seconds 3
    }
    
    # Clean up remaining folders if all components uninstalled successfully
    if ($FailedUninstalls.Count -eq 0) {
        Write-Log "Cleaning up remaining folders..."
        
        $FoldersToRemove = @(
            "${env:ProgramFiles}\Cisco\Cisco Secure Client",
            "${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client",
            "${env:ProgramFiles}\Cisco\Cisco AnyConnect Secure Mobility Client",
            "${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client",
            "${env:ProgramData}\Cisco\Cisco Secure Client",
            "${env:ProgramData}\Cisco\Cisco AnyConnect Secure Mobility Client"
        )
        
        foreach ($Folder in $FoldersToRemove) {
            if (Test-Path $Folder) {
                Write-Log "Removing folder: $Folder"
                Remove-Item -Path $Folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "=== Cisco Secure Client Uninstallation Completed Successfully ==="
        exit 0
    }
    else {
        Write-Log "=== Uninstallation Failed ===" -Level Error
        Write-Log "Failed to uninstall: $($FailedUninstalls -join ', ')" -Level Error
        exit 1
    }
}
catch {
    Write-Log "Unexpected error during uninstallation: $_" -Level Error
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
#endregion