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


    # Run the detection script and capture the exit code
    & "$PSScriptRoot\Detection.ps1"


    $exitCode = $LASTEXITCODE

    # $exitCode = '1'

    # Based on the exit code, decide whether to run the remediation
    switch ($exitCode) {
        0 {
            Write-EnhancedLog -Message "Microsoft 365 Apps is up-to-date. No action required." -Level 'INFO'
        }
        1 {
            Write-EnhancedLog -Message "Update required. Running the remediation script..." -Level 'WARNING'
        
            try {
                # Run ServiceUI to execute the Deploy-Application.exe with the required parameters
                $serviceUIPath = "C:\ProgramData\_MEM\Data\PR4B-Install-Microsoft-365-Apps-Updates-8f66cef5-29bd-4210-b723-77f116a2153c\ServiceUI.exe"
                $deployApplicationPath = "C:\ProgramData\_MEM\Data\PR4B-Install-Microsoft-365-Apps-Updates-8f66cef5-29bd-4210-b723-77f116a2153c\PSAppDeployToolkit\Toolkit\Deploy-Application.exe"
                $deploymentType = "install"
            
                # Log the command for reference
                Write-EnhancedLog -Message "Running remediation command: $serviceUIPath -process:explorer.exe `"$deployApplicationPath`" -DeploymentType $deploymentType" -Level 'INFO'

                # Execute the remediation script using ServiceUI
                & "$serviceUIPath" -process:explorer.exe "$deployApplicationPath" -DeploymentType $deploymentType

                if ($LASTEXITCODE -eq 0) {
                    Write-EnhancedLog -Message "Remediation completed successfully." -Level 'INFO'
                }
                else {
                    Write-EnhancedLog -Message "Remediation failed with exit code $LASTEXITCODE." -Level 'ERROR'
                }
            }
            catch {
                Write-EnhancedLog -Message "An error occurred during remediation: $($_.Exception.Message)" -Level 'ERROR'
            }
        }
        2 {
            Write-EnhancedLog -Message "Microsoft 365 Apps not installed. Remediation skipped." -Level 'ERROR'
        }
        3 {
            Write-EnhancedLog -Message "Failed to retrieve version/build information." -Level 'ERROR'
        }
        default {
            Write-EnhancedLog -Message "Unexpected exit code: $exitCode" -Level 'ERROR'
        }
    }


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