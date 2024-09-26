# $mode = $env:EnvironmentMode

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

# Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")

# Wait-Debugger

# Define a hashtable for splatting
# $moduleStarterParams = @{
#     Mode                   = 'prod'
#     SkipPSGalleryModules   = $false
#     SkipCheckandElevate    = $false
#     SkipPowerShell7Install = $false
#     SkipEnhancedModules    = $false
#     SkipGitRepos           = $true
    # ExecutionMode          = 'series'
# }

# Call the function using the splat
# Invoke-ModuleStarter @moduleStarterParams

# Import-Module 'C:\code\modulesv2\EnhancedSchedTaskAO\EnhancedSchedTaskAO.psm1' -Force

#endregion FIRING UP MODULE STARTER

#region HANDLE PSF MODERN LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE PSF MODERN LOGGING                                          #
#                                                                                               #
#################################################################################################
Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

# Define the base logs path and job name
$JobName = "M365Updates"
$parentScriptName = Get-ParentScriptName
Write-EnhancedLog -Message "Parent Script Name: $parentScriptName"

# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
$paramGetPSFCSVLogFilePath = @{
    LogsPath         = 'C:\Logs\PSF'
    JobName          = $jobName
    parentScriptName = $parentScriptName
}

$csvLogFilePath = Get-PSFCSVLogFilePath @paramGetPSFCSVLogFilePath

$instanceName = "$parentScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Configure the PSFramework logging provider to use CSV format
$paramSetPSFLoggingProvider = @{
    Name            = 'logfile'
    InstanceName    = $instanceName  # Use a unique instance name
    FilePath        = $csvLogFilePath  # Use the dynamically generated file path
    Enabled         = $true
    FileType        = 'CSV'
    EnableException = $true
}
Set-PSFLoggingProvider @paramSetPSFLoggingProvider

#endregion HANDLE PSF MODERN LOGGING


#region HANDLE Transript LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE Transript LOGGING                                           #
#                                                                                               #
#################################################################################################
# Start the script with error handling
try {
    # Generate the transcript file path
    $GetTranscriptFilePathParams = @{
        TranscriptsPath  = "C:\Logs\Transcript"
        JobName          = $jobName
        parentScriptName = $parentScriptName
    }
    $transcriptPath = Get-TranscriptFilePath @GetTranscriptFilePathParams
    
    # Start the transcript
    Write-EnhancedLog -Message "Starting transcript at: $transcriptPath"
    Start-Transcript -Path $transcriptPath
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -level 'ERROR'
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
}
#endregion HANDLE Transript LOGGING

try {
    #region Script Logic
    #################################################################################################
    #                                                                                               #
    #                                    Script Logic                                               #
    #                                                                                               #
    #################################################################################################

    # ################################################################################################################################
    # ############### CALLING AS SYSTEM to simulate Intune deployment as SYSTEM (Uncomment for debugging) ############################
    # ################################################################################################################################

    # Example usage
    # $ensureRunningAsSystemParams = @{
    #     PsExec64Path = Join-Path -Path $PSScriptRoot -ChildPath "private\PsExec64.exe"
    #     ScriptPath   = $MyInvocation.MyCommand.Path
    #     TargetFolder = Join-Path -Path $PSScriptRoot -ChildPath "private"
    # }

    # Ensure-RunningAsSystem @ensureRunningAsSystemParams



    function Invoke-OfficeCleanup {
        <#
        .SYNOPSIS
        Cleans up and uninstalls Office using SaRA and setup configurations.
    
        .PARAMETER ScriptDirectory
        The directory where the SaRA and setup files are located.
    
        .PARAMETER SaRAExe
        The executable file for the SaRA tool.
    
        .PARAMETER SaRAArguments
        The arguments to pass to SaRA for cleanup (e.g., Office scrub).
    
        .PARAMETER SetupExe
        The executable file for the Office setup.
    
        .PARAMETER SetupArguments
        The arguments to pass to the setup executable.
    
        .PARAMETER UninstallConfig
        The XML configuration file for uninstalling Office.
        #>
    
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$ScriptDirectory,
    
            [Parameter(Mandatory = $true)]
            [string]$SaRAExe,
    
            [Parameter(Mandatory = $true)]
            [string]$SaRAArguments,
    
            [Parameter(Mandatory = $true)]
            [string]$SetupExe,
    
            [Parameter(Mandatory = $true)]
            [string]$SetupArguments,
    
            [Parameter(Mandatory = $true)]
            [string]$UninstallConfig
        )
    
        Begin {
            Write-EnhancedLog -Message "Starting Invoke-OfficeCleanup function..." -Level "NOTICE"
            Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
        }
    
        Process {
            try {
                # Define full paths for SaRA and setup executables
                $SaRAExePath = Join-Path -Path $ScriptDirectory -ChildPath $SaRAExe
                $SetupExePath = Join-Path -Path $ScriptDirectory -ChildPath $SetupExe
                $UninstallConfigPath = Join-Path -Path $ScriptDirectory -ChildPath $UninstallConfig
    
                # Validate that the files exist
                if (-not (Test-Path -Path $SaRAExePath)) {
                    throw "SaRA executable not found at $SaRAExePath"
                }
    
                if (-not (Test-Path -Path $SetupExePath)) {
                    throw "Setup executable not found at $SetupExePath"
                }
    
                if (-not (Test-Path -Path $UninstallConfigPath)) {
                    throw "Uninstall configuration file not found at $UninstallConfigPath"
                }
    
                # Splatting for SaRA process
                $SaRASplat = @{
                    FilePath     = $SaRAExePath
                    ArgumentList = $SaRAArguments
                    Wait         = $true
                }
    
                # Run SaRA for Office cleanup
                Write-EnhancedLog -Message "Running SaRA for Office cleanup with arguments: $SaRAArguments" -Level "INFO"
                Start-Process @SaRASplat
                Write-EnhancedLog -Message "SaRA cleanup completed successfully." -Level "INFO"
    
                # Splatting for Office uninstallation
                $UninstallSplat = @{
                    FilePath     = $SetupExePath
                    ArgumentList = @($SetupArguments, $UninstallConfigPath)
                    Wait         = $true
                }
    
                # Run setup for Office uninstallation
                Write-EnhancedLog -Message "Running setup for Office uninstallation with config: $UninstallConfigPath" -Level "INFO"
                Start-Process @UninstallSplat
                Write-EnhancedLog -Message "Office uninstallation completed successfully." -Level "INFO"
            }
            catch {
                Write-EnhancedLog -Message "An error occurred during Office cleanup or uninstallation: $($_.Exception.Message)" -Level "ERROR"
                Handle-Error -ErrorRecord $_
                throw
            }
        }
    
        End {
            Write-EnhancedLog -Message "Exiting Invoke-OfficeCleanup function" -Level "NOTICE"
        }
    }
    

    # Cleanup and uninstall Office
    # $cleanupParams = @{
    #     ScriptDirectory = "$PSScriptRoot"
    #     SaRAExe         = "SaRACmd_17_01_1903_000\SaRAcmd.exe"
    #     SaRAArguments   = "-S OfficeScrubScenario -AcceptEula -OfficeVersion All"
    #     SetupExe        = "setup.exe"
    #     SetupArguments  = "/configure"
    #     UninstallConfig = "uninstall.xml"
    # }
    # Invoke-OfficeCleanup @cleanupParams

 
    function Invoke-OfficeInstall {
        <#
        .SYNOPSIS
        Installs Office using the setup executable and configuration file.
    
        .PARAMETER SetupExePath
        The full path to the setup executable for the Office installation.
    
        .PARAMETER SetupArguments
        The arguments to pass to the setup executable.
    
        .PARAMETER InstallConfig
        The XML configuration file for installing Office.
        #>
    
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$SetupExePath,
    
            [Parameter(Mandatory = $true)]
            [string]$SetupArguments,
    
            [Parameter(Mandatory = $true)]
            [string]$InstallConfig
        )
    
        Begin {
            Write-EnhancedLog -Message "Starting Invoke-OfficeInstall function..." -Level "NOTICE"
            Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
        }
    
        Process {
            try {
                # Validate that the setup.exe and config.xml files exist
                if (-not (Test-Path -Path $SetupExePath)) {
                    throw "Setup executable not found at $SetupExePath"
                }
    
                if (-not (Test-Path -Path $InstallConfig)) {
                    throw "Install configuration file not found at $InstallConfig"
                }
    
                # Splatting for Office installation
                $InstallSplat = @{
                    FilePath     = $SetupExePath
                    ArgumentList = @($SetupArguments, $InstallConfig)
                    Wait         = $true
                    WindowStyle  = "Hidden"
                }
    
                # Run setup for Office installation
                Write-EnhancedLog -Message "Running setup for Office installation with config: $InstallConfig" -Level "INFO"
                Start-Process @InstallSplat
                Write-EnhancedLog -Message "Office installation completed successfully." -Level "INFO"
            }
            catch {
                Write-EnhancedLog -Message "An error occurred during Office installation: $($_.Exception.Message)" -Level "ERROR"
                Handle-Error -ErrorRecord $_
                throw
            }
        }
    
        End {
            Write-EnhancedLog -Message "Exiting Invoke-OfficeInstall function" -Level "NOTICE"
        }
    }
    
    # # Example usage
    # try {
    #     # Step 1: Download ODT
    #     $downloadParams = @{
    #         DestinationDirectory = "$env:TEMP"
    #         MaxRetries           = 3
    #     }
    #     $odtInfo = Download-ODT @downloadParams
    
    #     if ($odtInfo.Status -eq 'Success') {
    #         Write-EnhancedLog -Message "ODT setup.exe located at: $($odtInfo.FullPath)"
    
    #         # Step 2: Install Office
    #         $installParams = @{
    #             SetupExePath   = $odtInfo.FullPath
    #             SetupArguments = "/configure"
    #             InstallConfig  = "$PSScriptRoot\config.xml"
    #         }
    #         Invoke-OfficeInstall @installParams
    #     } else {
    #         Write-EnhancedLog -Message "Failed to download or extract ODT." -level 'ERROR'
    #     }
    # }
    # catch {
    #     Write-EnhancedLog -Message "An error occurred: $($_.Exception.Message)" -level 'ERROR'
    # }
    





    # Run the detection script and capture the exit code
    & "$PSScriptroot\Detection.ps1"
    $exitCode = $LASTEXITCODE

    # $exitCode = '1' # Simulating Remediation

    # Based on the exit code, decide whether to run the remediation
    switch ($exitCode) {
        0 { Write-EnhancedLog -Message "Microsoft 365 Apps is up-to-date. No action required." -Lebel 'INFO' }
        1 {
            Write-EnhancedLog -Message "Update required. Running the remediation script..." -Level 'WARNING'
        
            try {
                # Step 1: Download ODT
                $downloadParams = @{
                    DestinationDirectory = "$env:TEMP"
                    MaxRetries           = 3
                }
                $odtInfo = Download-ODT @downloadParams

                if ($odtInfo.Status -eq 'Success') {
                    Write-EnhancedLog -Message "ODT setup.exe located at: $($odtInfo.FullPath)"

                    # Step 2: Install Office
                    $installParams = @{
                        SetupExePath   = $odtInfo.FullPath
                        SetupArguments = "/configure"
                        InstallConfig  = "$PSScriptRoot\config.xml"
                    }
                    Invoke-OfficeInstall @installParams
                }
                else {
                    Write-EnhancedLog -Message "Failed to download or extract ODT." -level 'ERROR'
                }
            }
            catch {
                Write-EnhancedLog -Message "An error occurred: $($_.Exception.Message)" -level 'ERROR'
            }
        }
        2 { Write-EnhancedLog -Message "Microsoft 365 Apps not installed. Remediation skipped." -level 'ERROR' }
        3 { Write-EnhancedLog -Message "Failed to retrieve version/build information." -level 'ERROR' }
        default { Write-EnhancedLog -Message "Unexpected exit code: $exitCode" -level 'ERROR' }
    }
    
    #endregion Script Logic
    
    #region HANDLE PSF LOGGING
    #################################################################################################
    #                                                                                               #
    #                                 HANDLE PSF LOGGING                                            #
    #                                                                                               #
    #################################################################################################
    # $parentScriptName = Get-ParentScriptName
    # Write-EnhancedLog -Message "Parent Script Name: $parentScriptName"

    # $HandlePSFLoggingParams = @{
    #     SystemSourcePathWindowsPS = "C:\Windows\System32\config\systemprofile\AppData\Roaming\WindowsPowerShell\PSFramework\Logs\"
    #     SystemSourcePathPS        = "C:\Windows\System32\config\systemprofile\AppData\Roaming\PowerShell\PSFramework\Logs\"
    #     UserSourcePathWindowsPS   = "$env:USERPROFILE\AppData\Roaming\WindowsPowerShell\PSFramework\Logs\"
    #     UserSourcePathPS          = "$env:USERPROFILE\AppData\Roaming\PowerShell\PSFramework\Logs\"
    #     PSFPath                   = "C:\Logs\PSF"
    #     ParentScriptName          = $parentScriptName
    #     JobName                   = $JobName
    #     SkipSYSTEMLogCopy         = $true
    #     SkipSYSTEMLogRemoval      = $true
    # }

    # Handle-PSFLogging @HandlePSFLoggingParams
    #endregion
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -level 'ERROR'
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
} 
finally {
    # Ensure that the transcript is stopped even if an error occurs
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -level 'ERROR'
    }
    
    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false
}