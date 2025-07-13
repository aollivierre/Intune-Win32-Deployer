<#
.SYNOPSIS
    Installs Cisco Secure Client with Umbrella component for DNS filtering.

.DESCRIPTION
    This script installs Cisco Secure Client components in the following order:
    1. Core VPN component (with VPN disabled for organizations using alternate VPN)
    2. Umbrella component (for DNS-layer security)
    3. DART component (diagnostics and reporting tool)
    
    Designed for Intune Win32 app deployment.

.NOTES
    Version:        1.0
    Creation Date:  2025-01-12
    Purpose:        Intune Win32 App Installation Script
    Compatibility:  PowerShell 5.1
#>

#region Script Configuration
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path $LogPath "CiscoSecureClient_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$MaxRetries = 3
$RetryDelay = 5
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

#region Installation Functions
function Install-MSIPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MSIPath,
        
        [Parameter(Mandatory=$true)]
        [string]$LogName,
        
        [Parameter(Mandatory=$false)]
        [string]$Arguments = "/qn /norestart"
    )
    
    $MSILogFile = Join-Path $LogPath "${LogName}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $MSIName = Split-Path -Leaf $MSIPath
    
    Write-Log "Installing $MSIName..."
    
    # Build the full argument string
    $ArgumentList = "/i `"$MSIPath`" $Arguments /l*v `"$MSILogFile`""
    
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $ArgumentList -Wait -PassThru
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "$MSIName installed successfully."
        return $true
    }
    elseif ($Process.ExitCode -eq 3010) {
        Write-Log "$MSIName installed successfully but requires a reboot." -Level Warning
        return $true
    }
    else {
        Write-Log "$MSIName installation failed with exit code: $($Process.ExitCode)" -Level Error
        return $false
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check for minimum Windows version (Windows 10 1809 or later recommended)
    $OSVersion = [System.Environment]::OSVersion.Version
    if ($OSVersion.Major -lt 10) {
        Write-Log "Windows 10 or later is required. Current version: $($OSVersion.ToString())" -Level Error
        return $false
    }
    
    # Check for administrator privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script must be run with administrator privileges." -Level Error
        return $false
    }
    
    # Check if another installation is in progress
    $MsiExecProcesses = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
    if ($MsiExecProcesses) {
        Write-Log "Another installation is in progress. Waiting..." -Level Warning
        Start-Sleep -Seconds 30
    }
    
    Write-Log "Prerequisites check passed."
    return $true
}
#endregion

#region Main Installation Logic
try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    
    Write-Log "=== Cisco Secure Client Installation Started ==="
    Write-Log "Script Path: $ScriptPath"
    
    # Initialize installation results for marker file
    $installationStartTime = Get-Date
    $installationResults = @{
        InstallationTimestamp = $installationStartTime.ToString('yyyy-MM-dd HH:mm:ss')
        InstallationStatus = "InProgress"
        ComputerName = $env:COMPUTERNAME
        UserContext = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        ScriptVersion = "1.0"
        InstalledVersion = $null
        ComponentsInstalled = @{}
        ComponentsFailed = @{}
        ErrorInfo = @()
        TotalExecutionSeconds = 0
    }
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Exiting." -Level Error
        exit 1
    }
    
    # Define MSI packages to install (per Cisco documentation)
    $MSIPackages = @(
        @{
            Name = "Core VPN"
            File = "cisco-secure-client-win-5.1.10.233-core-vpn-predeploy-k9.msi"
            Arguments = "PRE_DEPLOY_DISABLE_VPN=1 /qn /norestart"
            LogName = "vpninstall"
        },
        @{
            Name = "Umbrella"
            File = "cisco-secure-client-win-5.1.10.233-umbrella-predeploy-k9.msi"
            Arguments = "PRE_DEPLOY_DISABLE_VPN=1 /qn /norestart"
            LogName = "umbrellainstall"
        },
        @{
            Name = "DART"
            File = "cisco-secure-client-win-5.1.10.233-dart-predeploy-k9.msi"
            Arguments = "/qn /norestart"
            LogName = "dartinstall"
        }
    )
    
    $FailedInstalls = @()
    
    # Install each package
    foreach ($Package in $MSIPackages) {
        # First try the subdirectory location
        $MSIPath = Join-Path $ScriptPath "cisco-secure-client-win-5.1.10.233-predeploy-k9\$($Package.File)"
        
        # If not found in subdirectory, try the root directory
        if (-not (Test-Path $MSIPath)) {
            $MSIPath = Join-Path $ScriptPath $Package.File
        }
        
        if (-not (Test-Path $MSIPath)) {
            Write-Log "MSI file not found: $($Package.File)" -Level Error
            $FailedInstalls += $Package.Name
            continue
        }
        
        Write-Log "Installing $($Package.Name) component..."
        
        $RetryCount = 0
        $Success = $false
        
        while ($RetryCount -lt $MaxRetries -and -not $Success) {
            if ($RetryCount -gt 0) {
                Write-Log "Retry attempt $RetryCount for $($Package.Name)..." -Level Warning
                Start-Sleep -Seconds $RetryDelay
            }
            
            $Success = Install-MSIPackage -MSIPath $MSIPath -LogName $Package.LogName -Arguments $Package.Arguments
            $RetryCount++
        }
        
        if (-not $Success) {
            $FailedInstalls += $Package.Name
            $installationResults.ComponentsFailed[$Package.Name] = @{
                Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                Reason = "Installation failed after $MaxRetries attempts"
            }
        } else {
            $installationResults.ComponentsInstalled[$Package.Name] = @{
                Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                Version = "5.1.10.233"
            }
        }
    }
    
    # Update installation results
    $installationResults.InstalledVersion = "5.1.10.233"
    $executionTime = (Get-Date) - $installationStartTime
    $installationResults.TotalExecutionSeconds = [math]::Round($executionTime.TotalSeconds, 2)
    
    # Check installation results
    if ($FailedInstalls.Count -eq 0) {
        $installationResults.InstallationStatus = "Success"
        Write-Log "=== Cisco Secure Client Installation Completed Successfully ==="
        
        # Verify services per documentation (wait for services to initialize)
        Write-Log "Waiting for services to initialize..."
        Start-Sleep -Seconds 15
        
        # Expected services per installation documentation
        $ExpectedServices = @(
            @{Name = "csc_umbrellaagent"; DisplayName = "Cisco Secure Client - Umbrella"},
            @{Name = "vpnagent"; DisplayName = "Cisco Secure Client Agent"},
            @{Name = "acwebsecagent"; DisplayName = "Cisco Secure Client Web Security Agent"}
        )
        
        $ServiceStatus = @()
        $AllServicesRunning = $true
        
        foreach ($ServiceInfo in $ExpectedServices) {
            $Service = Get-Service -Name $ServiceInfo.Name -ErrorAction SilentlyContinue
            
            if ($Service) {
                $ServiceStatus += "$($ServiceInfo.DisplayName): $($Service.Status)"
                Write-Log "Service $($ServiceInfo.Name) status: $($Service.Status)"
                
                # Try to start service if not running
                if ($Service.Status -ne 'Running') {
                    Write-Log "Attempting to start $($ServiceInfo.Name)..." -Level Warning
                    try {
                        Start-Service -Name $ServiceInfo.Name -ErrorAction Stop
                        Start-Sleep -Seconds 5
                        $Service = Get-Service -Name $ServiceInfo.Name
                        Write-Log "Service $($ServiceInfo.Name) is now: $($Service.Status)"
                    }
                    catch {
                        Write-Log "Failed to start $($ServiceInfo.Name): $_" -Level Warning
                        $AllServicesRunning = $false
                    }
                }
            }
            else {
                if ($ServiceInfo.Name -eq "vpnagent" -or $ServiceInfo.Name -eq "acwebsecagent") {
                    Write-Log "Service $($ServiceInfo.Name) not found (expected - VPN is disabled via PRE_DEPLOY_DISABLE_VPN=1)" -Level Info
                    $ServiceStatus += "$($ServiceInfo.DisplayName): Not Found (VPN Disabled)"
                } else {
                    Write-Log "Service $($ServiceInfo.Name) not found" -Level Warning
                    $ServiceStatus += "$($ServiceInfo.DisplayName): Not Found"
                }
            }
        }
        
        Write-Log "Service Status Summary: $($ServiceStatus -join ', ')"
        
        # Installation is successful even if some services aren't running immediately
        # They may start after a reboot
        if (-not $AllServicesRunning) {
            Write-Log "Some services are not running. A reboot may be required." -Level Warning
        }
        
        Write-Log "Installation completed. To verify Umbrella policies, visit: http://examplemalwaredomain.com"
        
        # Save installation marker file
        try {
            $markerDir = "C:\ProgramData\CiscoSecureClient"
            $markerFile = Join-Path $markerDir "installation-results.json"
            
            if (-not (Test-Path $markerDir)) {
                New-Item -Path $markerDir -ItemType Directory -Force | Out-Null
            }
            
            $installationResults | ConvertTo-Json -Depth 10 | Set-Content -Path $markerFile -Encoding UTF8
            Write-Log "Installation marker file saved to: $markerFile"
        }
        catch {
            Write-Log "Failed to save installation marker file: $_" -Level Warning
        }
        
        exit 0
    }
    else {
        $installationResults.InstallationStatus = "Failed"
        Write-Log "=== Installation Failed ===" -Level Error
        Write-Log "Failed components: $($FailedInstalls -join ', ')" -Level Error
        
        # Save installation marker file even on failure
        try {
            $markerDir = "C:\ProgramData\CiscoSecureClient"
            $markerFile = Join-Path $markerDir "installation-results.json"
            
            if (-not (Test-Path $markerDir)) {
                New-Item -Path $markerDir -ItemType Directory -Force | Out-Null
            }
            
            $installationResults.ErrorInfo += @{
                ErrorMessage = "Failed to install components: $($FailedInstalls -join ', ')"
                ErrorTimestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            }
            
            $installationResults | ConvertTo-Json -Depth 10 | Set-Content -Path $markerFile -Encoding UTF8
            Write-Log "Installation marker file saved with failure status to: $markerFile"
        }
        catch {
            Write-Log "Failed to save installation marker file: $_" -Level Warning
        }
        
        exit 1
    }
}
catch {
    Write-Log "Unexpected error during installation: $_" -Level Error
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    
    # Save installation marker file even on unexpected error
    try {
        $installationResults.InstallationStatus = "Error"
        $installationResults.ErrorInfo += @{
            ErrorMessage = $_.Exception.Message
            ErrorType = $_.Exception.GetType().FullName
            ErrorTimestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            StackTrace = $_.ScriptStackTrace
        }
        
        $markerDir = "C:\ProgramData\CiscoSecureClient"
        $markerFile = Join-Path $markerDir "installation-results.json"
        
        if (-not (Test-Path $markerDir)) {
            New-Item -Path $markerDir -ItemType Directory -Force | Out-Null
        }
        
        $installationResults | ConvertTo-Json -Depth 10 | Set-Content -Path $markerFile -Encoding UTF8
        Write-Log "Installation marker file saved with error status to: $markerFile"
    }
    catch {
        Write-Log "CRITICAL: Failed to save installation marker file even in error handler: $_" -Level Error
    }
    
    exit 1
}
#endregion