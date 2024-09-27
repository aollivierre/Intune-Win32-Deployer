# JSON string
$json = @'
{
  "PackageName": "PR4B-Install-Microsoft-365-Apps-Updates",
  "PackageUniqueGUID": "8f66cef5-29bd-4210-b723-77f116a2153c",
  "Version": 1,
  "PackageExecutionContext": "SYSTEM",
  "LoggingDeploymentName": "PR4B_TriggerM365Updates",
  "ScriptMode": "Remediation",
  "RunOnDemand": false,
  "UsePSADT": false,
  "TriggerType": "Daily",
  "LogonUserId": "administrator",
  "RepetitionInterval": "P1D"
}
'@


# $mode = $env:EnvironmentMode

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

# Define a hashtable for splatting
# $moduleStarterParams = @{
#     Mode                   = $mode
#     SkipPSGalleryModules   = $true
#     SkipCheckandElevate    = $true
#     SkipPowerShell7Install = $true
#     SkipEnhancedModules    = $true
#     SkipGitRepos           = $true
# }

# Call the function using the splat
# Invoke-ModuleStarter @moduleStarterParams

#endregion FIRING UP MODULE STARTER

#region HANDLE PSF MODERN LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE PSF MODERN LOGGING                                          #
#                                                                                               #
#################################################################################################
# Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

# Define the base logs path and job name
$JobName = "M365Updates"
$parentScriptName = Get-ParentScriptName
Write-Host "Parent Script Name: $parentScriptName"

# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
# $paramGetPSFCSVLogFilePath = @{
#     LogsPath         = 'C:\Logs\PSF'
#     JobName          = $jobName
#     parentScriptName = $parentScriptName
# }

# $csvLogFilePath = Get-PSFCSVLogFilePath @paramGetPSFCSVLogFilePath

# $instanceName = "$parentScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Configure the PSFramework logging provider to use CSV format
# $paramSetPSFLoggingProvider = @{
#     Name            = 'logfile'
#     InstanceName    = $instanceName  # Use a unique instance name
#     FilePath        = $csvLogFilePath  # Use the dynamically generated file path
#     Enabled         = $true
#     FileType        = 'CSV'
#     EnableException = $true
# }
# Set-PSFLoggingProvider @paramSetPSFLoggingProvider

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
    Write-Host "Starting transcript at: $transcriptPath"
    Start-Transcript -Path $transcriptPath
}
catch {
    Write-Host "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-Host "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-Host "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    # Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    # Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

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

    function Get-TranscriptFilePath {
        <#
        .SYNOPSIS
        Generates a file path for storing PowerShell transcripts.
    
        .DESCRIPTION
        The Get-TranscriptFilePath function constructs a unique transcript file path based on the provided transcript directory, job name, and parent script name. It ensures the transcript directory exists, handles context (e.g., SYSTEM account), and logs each step of the process.
    
        .PARAMETER TranscriptsPath
        The base directory where transcript files will be stored.
    
        .PARAMETER JobName
        The name of the job or task, used to distinguish different log files.
    
        .PARAMETER ParentScriptName
        The name of the parent script that is generating the transcript.
    
        .EXAMPLE
        $params = @{
            TranscriptsPath  = 'C:\Transcripts'
            JobName          = 'BackupJob'
            ParentScriptName = 'BackupScript.ps1'
        }
        Get-TranscriptFilePath @params
        Generates a transcript file path for a script called BackupScript.ps1.
        #>
    
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, HelpMessage = "Provide the base path for transcripts.")]
            [ValidateNotNullOrEmpty()]
            [string]$TranscriptsPath,
    
            [Parameter(Mandatory = $true, HelpMessage = "Provide the job name.")]
            [ValidateNotNullOrEmpty()]
            [string]$JobName,
    
            [Parameter(Mandatory = $true, HelpMessage = "Provide the parent script name.")]
            [ValidateNotNullOrEmpty()]
            [string]$ParentScriptName
        )
    
        Begin {
            # Log the start of the function
            Write-IntuneDetectionScriptLog -Message "Starting Get-TranscriptFilePath function..." -Level "NOTICE"
            Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
    
            # Ensure the destination directory exists
            if (-not (Test-Path -Path $TranscriptsPath)) {
                New-Item -ItemType Directory -Path $TranscriptsPath -Force | Out-Null
                Write-IntuneDetectionScriptLog -Message "Created Transcripts directory at: $TranscriptsPath" -Level "INFO"
            }
        }
    
        Process {
            try {
                # Get the current username or fallback to "UnknownUser"
                $username = if ($env:USERNAME) { $env:USERNAME } else { "UnknownUser" }
                Write-IntuneDetectionScriptLog -Message "Current username: $username" -Level "INFO"
    
                # Log the provided parent script name
                Write-IntuneDetectionScriptLog -Message "Parent script name: $ParentScriptName" -Level "INFO"
    
                # Check if running as SYSTEM
                $isSystem = Test-RunningAsSystem
                Write-IntuneDetectionScriptLog -Message "Is running as SYSTEM: $isSystem" -Level "INFO"
    
                # Get the current date for folder structure
                $currentDate = Get-Date -Format "yyyy-MM-dd"
                Write-IntuneDetectionScriptLog -Message "Current date for transcript folder: $currentDate" -Level "INFO"
    
                # Construct the hostname and timestamp for the log file name
                $hostname = $env:COMPUTERNAME
                $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
                $logFolderPath = Join-Path -Path $TranscriptsPath -ChildPath "$currentDate\$ParentScriptName"
    
                # Ensure the log directory exists
                if (-not (Test-Path -Path $logFolderPath)) {
                    New-Item -Path $logFolderPath -ItemType Directory -Force | Out-Null
                    Write-IntuneDetectionScriptLog -Message "Created directory for transcript logs: $logFolderPath" -Level "INFO"
                }
    
                # Generate log file path based on context (SYSTEM or user)
                $logFilePath = if ($isSystem) {
                    "$logFolderPath\$hostname-$JobName-SYSTEM-$ParentScriptName-transcript-$timestamp.log"
                }
                else {
                    "$logFolderPath\$hostname-$JobName-$username-$ParentScriptName-transcript-$timestamp.log"
                }
    
                Write-IntuneDetectionScriptLog -Message "Constructed log file path: $logFilePath" -Level "INFO"
    
                # Sanitize and validate the log file path
                $logFilePath = Sanitize-LogFilePath -LogFilePath $logFilePath
                Validate-LogFilePath -LogFilePath $logFilePath
                Write-IntuneDetectionScriptLog -Message "Log file path sanitized and validated: $logFilePath" -Level "INFO"
    
                # Return the constructed file path
                return $logFilePath
            }
            catch {
                Write-IntuneDetectionScriptLog -Message "An error occurred in Get-TranscriptFilePath: $($_.Exception.Message)" -Level "ERROR"
                Handle-Error -ErrorRecord $_
                throw
            }
        }
    
        End {
            Write-IntuneDetectionScriptLog -Message "Exiting Get-TranscriptFilePath function" -Level "NOTICE"
        }
    }
    
    function Log-Params {
        <#
        .SYNOPSIS
        Logs the provided parameters and their values with the parent function name appended.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [hashtable]$Params
        )
    
        Begin {
            # Get the name of the parent function
            $parentFunctionName = (Get-PSCallStack)[1].Command
    
            # Write-IntuneDetectionScriptLog -Message "Starting Log-Params function in $parentFunctionName" -Level "INFO"
        }
    
        Process {
            try {
                foreach ($key in $Params.Keys) {
                    # Append the parent function name to the key
                    $enhancedKey = "$parentFunctionName.$key"
                    Write-IntuneDetectionScriptLog -Message "$enhancedKey $($Params[$key])" -Level "INFO"
                }
            } catch {
                Write-IntuneDetectionScriptLog -Message "An error occurred while logging parameters in $parentFunctionName $($_.Exception.Message)" -Level "ERROR"
                Handle-Error -ErrorRecord $_
            }
        }
    
        End {
            # Write-IntuneDetectionScriptLog -Message "Exiting Log-Params function in $parentFunctionName" -Level "INFO"
        }
    }

    function Handle-Error {
        param (
            [Parameter(Mandatory = $true)]
            [System.Management.Automation.ErrorRecord]$ErrorRecord
        )
    
        try {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $fullErrorDetails = Get-Error -InputObject $ErrorRecord | Out-String
            } else {
                $fullErrorDetails = $ErrorRecord.Exception | Format-List * -Force | Out-String
            }
    
            Write-IntuneDetectionScriptLog -Message "Exception Message: $($ErrorRecord.Exception.Message)" -Level "ERROR"
            Write-IntuneDetectionScriptLog -Message "Full Exception: $fullErrorDetails" -Level "ERROR"
        } catch {
            # Fallback error handling in case of an unexpected error in the try block
            Write-IntuneDetectionScriptLog -Message "An error occurred while handling another error. Original Exception: $($ErrorRecord.Exception.Message)" -Level "CRITICAL"
            Write-IntuneDetectionScriptLog -Message "Handler Exception: $($_.Exception.Message)" -Level "CRITICAL"
            Write-IntuneDetectionScriptLog -Message "Handler Full Exception: $($_ | Out-String)" -Level "CRITICAL"
        }
    }
    

    function Get-ParentScriptName {
        [CmdletBinding()]
        param ()

        try {
            # Get the current call stack
            $callStack = Get-PSCallStack

            # If there is a call stack, return the top-most script name
            if ($callStack.Count -gt 0) {
                foreach ($frame in $callStack) {
                    if ($frame.ScriptName) {
                        $parentScriptName = $frame.ScriptName
                        # Write-EnhancedModuleStarterLog -Message "Found script in call stack: $parentScriptName" -Level "INFO"
                    }
                }

                if (-not [string]::IsNullOrEmpty($parentScriptName)) {
                    $parentScriptName = [System.IO.Path]::GetFileNameWithoutExtension($parentScriptName)
                    return $parentScriptName
                }
            }

            # If no script name was found, return 'UnknownScript'
            # Write-EnhancedModuleStarterLog -Message "No script name found in the call stack." -Level "WARNING"
            return "UnknownScript"
        }
        catch {
            # Write-EnhancedModuleStarterLog -Message "An error occurred while retrieving the parent script name: $_" -Level "ERROR"
            return "UnknownScript"
        }
    }

    function Write-IntuneDetectionScriptLog {
        param (
            [string]$Message,
            [string]$Level = "INFO"
        )

        # Get the PowerShell call stack to determine the actual calling function
        $callStack = Get-PSCallStack
        $callerFunction = if ($callStack.Count -ge 2) { $callStack[1].Command } else { '<Unknown>' }

        # Get the parent script name
        $parentScriptName = Get-ParentScriptName

        # Prepare the formatted message with the actual calling function information
        $formattedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$parentScriptName.$callerFunction] $Message"

        # Display the log message based on the log level using Write-Host
        switch ($Level.ToUpper()) {
            "DEBUG" { Write-Host $formattedMessage -ForegroundColor DarkGray }
            "INFO" { Write-Host $formattedMessage -ForegroundColor Green }
            "NOTICE" { Write-Host $formattedMessage -ForegroundColor Cyan }
            "WARNING" { Write-Host $formattedMessage -ForegroundColor Yellow }
            "ERROR" { Write-Host $formattedMessage -ForegroundColor Red }
            "CRITICAL" { Write-Host $formattedMessage -ForegroundColor Magenta }
            default { Write-Host $formattedMessage -ForegroundColor White }
        }

        # Append to log file
        $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'IntuneDetectionScript.log')
        $formattedMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
    }


    function Test-RunningAsSystem {
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18"
        $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User

        return $currentSid -eq $systemSid
    }

    function CheckAndElevate {

        <#
    .SYNOPSIS
    Elevates the script to run with administrative privileges if not already running as an administrator.

    .DESCRIPTION
    The CheckAndElevate function checks if the current PowerShell session is running with administrative privileges. If it is not, the function attempts to restart the script with elevated privileges using the 'RunAs' verb. This is useful for scripts that require administrative privileges to perform their tasks.

    .EXAMPLE
    CheckAndElevate

    Checks the current session for administrative privileges and elevates if necessary.

    .NOTES
    This function will cause the script to exit and restart if it is not already running with administrative privileges. Ensure that any state or data required after elevation is managed appropriately.
    #>
        [CmdletBinding()]
        param (
            # Advanced parameters could be added here if needed. For this function, parameters aren't strictly necessary,
            # but you could, for example, add parameters to control logging behavior or to specify a different method of elevation.
            # [switch]$Elevated
        )

        begin {
            try {
                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

                Write-IntuneDetectionScriptLog -Message "Checking for administrative privileges..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Blue)
            }
            catch {
                Write-IntuneDetectionScriptLog -Message "Error determining administrative status: $_" -Level "ERROR"
                throw $_
            }
        }

        process {
            if (-not $isAdmin) {
                try {
                    Write-IntuneDetectionScriptLog -Message "The script is not running with administrative privileges. Attempting to elevate..." -Level "WARNING"
                
                    $arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" $args"
                    Start-Process PowerShell -Verb RunAs -ArgumentList $arguments

                    # Invoke-AsSystem -PsExec64Path $PsExec64Path
                
                    Write-IntuneDetectionScriptLog -Message "Script re-launched with administrative privileges. Exiting current session." -Level "INFO"
                    exit
                }
                catch {
                    Write-IntuneDetectionScriptLog -Message "Failed to elevate privileges: $_" -Level "ERROR"
                    throw $_
                }
            }
            else {
                Write-IntuneDetectionScriptLog -Message "Script is already running with administrative privileges." -Level "INFO"
            }
        }

        end {
            # This block is typically used for cleanup. In this case, there's nothing to clean up,
            # but it's useful to know about this structure for more complex functions.
        }
    }

    function Remove-ExistingPsExec {
        [CmdletBinding()]
        param(
            [string]$TargetFolder = "$PSScriptRoot\private"
        )

        # Full path for PsExec64.exe
        $PsExec64Path = Join-Path -Path $TargetFolder -ChildPath "PsExec64.exe"

        try {
            # Check if PsExec64.exe exists
            if (Test-Path -Path $PsExec64Path) {
                Write-IntuneDetectionScriptLog -Message "Removing existing PsExec64.exe from: $TargetFolder"
                # Remove PsExec64.exe
                Remove-Item -Path $PsExec64Path -Force
                Write-Output "PsExec64.exe has been removed from: $TargetFolder"
            }
            else {
                Write-IntuneDetectionScriptLog -Message "No PsExec64.exe file found in: $TargetFolder"
            }
        }
        catch {
            # Handle any errors during the removal
            Write-Error "An error occurred while trying to remove PsExec64.exe: $_"
        }
    }

    function Download-PsExec {
        [CmdletBinding()]
        param(
            [string]$TargetFolder = "$PSScriptRoot\private"
        )

        Begin {

            Remove-ExistingPsExec
        }



        process {

            # Define the URL for PsExec download
            $url = "https://download.sysinternals.com/files/PSTools.zip"
    
            # Ensure the target folder exists
            if (-Not (Test-Path -Path $TargetFolder)) {
                New-Item -Path $TargetFolder -ItemType Directory
            }
  
            # Full path for the downloaded file
            $zipPath = Join-Path -Path $TargetFolder -ChildPath "PSTools.zip"
  
            try {
                # Download the PSTools.zip file containing PsExec
                Write-IntuneDetectionScriptLog -Message "Downloading PSTools.zip from: $url to: $zipPath"
                Invoke-WebRequest -Uri $url -OutFile $zipPath
  
                # Extract PsExec64.exe from the zip file
                Expand-Archive -Path $zipPath -DestinationPath "$TargetFolder\PStools" -Force
  
                # Specific extraction of PsExec64.exe
                $extractedFolderPath = Join-Path -Path $TargetFolder -ChildPath "PSTools"
                $PsExec64Path = Join-Path -Path $extractedFolderPath -ChildPath "PsExec64.exe"
                $finalPath = Join-Path -Path $TargetFolder -ChildPath "PsExec64.exe"
  
                # Move PsExec64.exe to the desired location
                if (Test-Path -Path $PsExec64Path) {
  
                    Write-IntuneDetectionScriptLog -Message "Moving PSExec64.exe from: $PsExec64Path to: $finalPath"
                    Move-Item -Path $PsExec64Path -Destination $finalPath
  
                    # Remove the downloaded zip file and extracted folder
                    Remove-Item -Path $zipPath -Force
                    Remove-Item -Path $extractedFolderPath -Recurse -Force
  
                    Write-IntuneDetectionScriptLog -Message "PsExec64.exe has been successfully downloaded and moved to: $finalPath"
                }
            }
            catch {
                # Handle any errors during the process
                Write-Error "An error occurred: $_"
            }
        }


  

    }

    function Invoke-AsSystem {
        <#
.SYNOPSIS
Executes a PowerShell script under the SYSTEM context, similar to Intune's execution context.

.DESCRIPTION
The Invoke-AsSystem function executes a PowerShell script using PsExec64.exe to run under the SYSTEM context. This method is useful for scenarios requiring elevated privileges beyond the current user's capabilities.

.PARAMETER PsExec64Path
Specifies the full path to PsExec64.exe. If not provided, it assumes PsExec64.exe is in the same directory as the script.

.EXAMPLE
Invoke-AsSystem -PsExec64Path "C:\Tools\PsExec64.exe"

Executes PowerShell as SYSTEM using PsExec64.exe located at "C:\Tools\PsExec64.exe".

.NOTES
Ensure PsExec64.exe is available and the script has the necessary permissions to execute it.

.LINK
https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
#>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$PsExec64Path,
            [string]$ScriptPathAsSYSTEM  # Path to the PowerShell script you want to run as SYSTEM
        )

        begin {
            CheckAndElevate
            # Define the arguments for PsExec64.exe to run PowerShell as SYSTEM with the script
            $argList = "-accepteula -i -s -d powershell.exe -NoExit -ExecutionPolicy Bypass -File `"$ScriptPathAsSYSTEM`""
            Write-IntuneDetectionScriptLog -Message "Preparing to execute PowerShell as SYSTEM using PsExec64 with the script: $ScriptPathAsSYSTEM" -Level "INFO"

            Download-PsExec
        }

        process {
            try {
                # Ensure PsExec64Path exists
                if (-not (Test-Path -Path $PsExec64Path)) {
                    $errorMessage = "PsExec64.exe not found at path: $PsExec64Path"
                    Write-IntuneDetectionScriptLog -Message $errorMessage -Level "ERROR"
                    throw $errorMessage
                }

                # Run PsExec64.exe with the defined arguments to execute the script as SYSTEM
                $executingMessage = "Executing PsExec64.exe to start PowerShell as SYSTEM running script: $ScriptPathAsSYSTEM"
                Write-IntuneDetectionScriptLog -Message $executingMessage -Level "INFO"
                Start-Process -FilePath "$PsExec64Path" -ArgumentList $argList -Wait -NoNewWindow
            
                Write-IntuneDetectionScriptLog -Message "SYSTEM session started. Closing elevated session..." -Level "INFO"
                exit

            }
            catch {
                Write-IntuneDetectionScriptLog -Message "An error occurred: $_" -Level "ERROR"
            }
        }
    }

    function Initialize-ScriptVariables {
        <#
    .SYNOPSIS
    Initializes global script variables and defines the path for storing related files.

    .DESCRIPTION
    This function initializes global script variables such as PackageName, PackageUniqueGUID, Version, and ScriptMode. Additionally, it constructs the path where related files will be stored based on the provided parameters.

    .PARAMETER PackageName
    The name of the package being processed.

    .PARAMETER PackageUniqueGUID
    The unique identifier for the package being processed.

    .PARAMETER Version
    The version of the package being processed.

    .PARAMETER ScriptMode
    The mode in which the script is being executed (e.g., "Remediation", "PackageName").

    .EXAMPLE
    Initialize-ScriptVariables -PackageName "MyPackage" -PackageUniqueGUID "1234-5678" -Version 1 -ScriptMode "Remediation"

    This example initializes the script variables with the specified values.

    #>

        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$PackageName,

            [Parameter(Mandatory = $true)]
            [string]$PackageUniqueGUID,

            [Parameter(Mandatory = $true)]
            [int]$Version,

            [Parameter(Mandatory = $true)]
            [string]$ScriptMode,

            [Parameter(Mandatory = $true)]
            [string]$PackageExecutionContext
        )

        # Assuming Set-LocalPathBasedOnContext and Test-RunningAsSystem are defined elsewhere
        # $global:Path_local = Set-LocalPathBasedOnContext

        # Default logic for $Path_local if not set by Set-LocalPathBasedOnContext
        if (-not $Path_local) {
            if (Test-RunningAsSystem) {
                # $Path_local = "$ENV:ProgramFiles\_MEM"
                $Path_local = "c:\_MEM"
            }
            else {
                $Path_local = "$ENV:LOCALAPPDATA\_MEM"
            }
        }

        $Path_PR = "$Path_local\Data\$PackageName-$PackageUniqueGUID"
        $schtaskName = "$PackageName-$PackageUniqueGUID"
        $schtaskDescription = "Version $Version"

        try {
            # Assuming Write-IntuneDetectionScriptLog is defined elsewhere
            Write-IntuneDetectionScriptLog -Message "Initializing script variables..." -Level "INFO"

            # Returning a hashtable of all the important variables
            return @{
                PackageName             = $PackageName
                PackageUniqueGUID       = $PackageUniqueGUID
                Version                 = $Version
                ScriptMode              = $ScriptMode
                Path_local              = $Path_local
                Path_PR                 = $Path_PR
                schtaskName             = $schtaskName
                schtaskDescription      = $schtaskDescription
                PackageExecutionContext = $PackageExecutionContext
            }
        }
        catch {
            Write-Error "An error occurred while initializing script variables: $_"
        }
    }

    function Set-LocalPathBasedOnContext {
        Write-IntuneDetectionScriptLog -Message "Checking running context..." -Level "INFO"
        if (Test-RunningAsSystem) {
            Write-IntuneDetectionScriptLog -Message "Running as system, setting path to Program Files" -Level "INFO"
            return "$ENV:Programfiles\_MEM"
        }
        else {
            Write-IntuneDetectionScriptLog -Message "Running as user, setting path to Local AppData" -Level "INFO"
            return "$ENV:LOCALAPPDATA\_MEM"
        }
    }

    # Convert JSON string to a PowerShell object
    $Config = $json | ConvertFrom-Json

    # Assign values from JSON to variables
    $PackageName = $config.PackageName
    $PackageUniqueGUID = $config.PackageUniqueGUID
    $Version = $config.Version
    $PackageExecutionContext = $config.PackageExecutionContext
    # $RepetitionInterval = $config.RepetitionInterval
    $ScriptMode = $config.ScriptMode

    # Assign values from JSON to variables
    # $LoggingDeploymentName = $config.LoggingDeploymentName
    
   
    # $initializationInfo = Initialize-ScriptAndLogging
    
    
    
    # Script Execution and Variable Assignment
    # After the function Initialize-ScriptAndLogging is called, its return values (in the form of a hashtable) are stored in the variable $initializationInfo.
    
    # Then, individual elements of this hashtable are extracted into separate variables for ease of use:
    
    # $ScriptPath: The path of the script's main directory.
    # $Filename: The base name used for log files.
    # $logPath: The full path of the directory where logs are stored.
    # $logFile: The full path of the transcript log file.
    # $CSVFilePath: The path of the directory where CSV files are stored.
    # This structure allows the script to have a clear organization regarding where logs and other files are stored, making it easier to manage and maintain, especially for logging purposes. It also encapsulates the setup logic in a function, making the main script cleaner and more focused on its primary tasks.
    
    
    # $ScriptPath = $initializationInfo['ScriptPath']
    # $Filename = $initializationInfo['Filename']
    # $logPath = $initializationInfo['LogPath']
    # $logFile = $initializationInfo['LogFile']
    # $CSVFilePath = $initializationInfo['CSVFilePath']



    #################################################################################################################################
    ################################################# END LOGGING ###################################################################
    #################################################################################################################################



    # Assuming Invoke-AsSystem and Write-IntuneDetectionScriptLog are already defined
    # Update the path to your actual location of PsExec64.exe

    Write-IntuneDetectionScriptLog -Message "calling Test-RunningAsSystem" -Level "INFO"
    if (-not (Test-RunningAsSystem)) {
        $privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
        $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

        Write-IntuneDetectionScriptLog -Message "Current session is not running as SYSTEM. Attempting to invoke as SYSTEM..." -Level "INFO"

        $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
        Invoke-AsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem

    }
    else {
        Write-IntuneDetectionScriptLog -Message "Session is already running as SYSTEM." -Level "INFO"
    }


    
    
    #################################################################################################################################
    ################################################# END LOGGING ###################################################################
    #################################################################################################################################

    $global:Path_local = Set-LocalPathBasedOnContext

    Write-IntuneDetectionScriptLog -Message "calling Initialize-ScriptVariables" -Level "INFO"
    
    #################################################################################################################################
    ################################################# END LOGGING ###################################################################
    #################################################################################################################################

    # Invocation of the function and storing returned hashtable in a variable
    # $initializationInfo = Initialize-ScriptVariables -PackageName "YourPackageName" -PackageUniqueGUID "YourGUID" -Version 1 -ScriptMode "YourMode"


    # Call Initialize-ScriptVariables with splatting
    $InitializeScriptVariablesParams = @{
        PackageName             = $PackageName
        PackageUniqueGUID       = $PackageUniqueGUID
        Version                 = $Version
        ScriptMode              = $ScriptMode
        PackageExecutionContext = $PackageExecutionContext
    }

    $initializationInfo = Initialize-ScriptVariables @InitializeScriptVariablesParams

    $initializationInfo

    $global:PackageName = $initializationInfo['PackageName']
    $global:PackageUniqueGUID = $initializationInfo['PackageUniqueGUID']
    $global:Version = $initializationInfo['Version']
    $global:ScriptMode = $initializationInfo['ScriptMode']
    $global:Path_local = $initializationInfo['Path_local']
    $global:Path_PR = $initializationInfo['Path_PR']
    $global:schtaskName = $initializationInfo['schtaskName']
    $global:schtaskDescription = $initializationInfo['schtaskDescription']
    $global:PackageExecutionContext = $initializationInfo['PackageExecutionContext']


    # Check if the scheduled task exists and matches the version
    $Task_existing = Get-ScheduledTask -TaskName $schtaskName -ErrorAction SilentlyContinue
    # if ($Task_existing -and $Task_existing.Description -like "Version $Version*") {
    if ($Task_existing -and $Task_existing.Description) {
        Write-Host "Found it!"
        exit 0
    }
    else {
        # Write-Host "Not Found!"
        exit 1
    }
    
    #endregion Script Logic
}
catch {
    Write-IntuneDetectionScriptLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-Host "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-Host "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    # Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    # Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
} 
finally {
    # Ensure that the transcript is stopped even if an error occurs
    if ($transcriptPath) {
        Stop-Transcript
        Write-Host "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-Host "Transcript was not started due to an earlier error." -ForegroundColor Red
    }
    
    # Ensure the log is written before proceeding
    # Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    # Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false
}