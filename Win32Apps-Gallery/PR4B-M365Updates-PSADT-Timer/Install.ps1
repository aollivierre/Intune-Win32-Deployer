param (
    [Switch]$SimulatingIntune = $false
)

# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'prod', 'Machine')

function Reset-ModulePaths {
    [CmdletBinding()]
    param ()

    begin {
        # Initialization block, typically used for setup tasks
        write-host "Initializing Reset-ModulePaths function..."
    }

    process {
        try {
            # Log the start of the process
            write-host "Resetting module paths to default values..."

            # Get the current user's Documents path
            $userModulesPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Documents\WindowsPowerShell\Modules')

            # Define the default module paths
            $defaultModulePaths = @(
                "C:\Program Files\WindowsPowerShell\Modules",
                $userModulesPath,
                "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
            )

            # Attempt to reset the PSModulePath environment variable
            $env:PSModulePath = [string]::Join(';', $defaultModulePaths)
            write-host "PSModulePath successfully set to: $($env:PSModulePath -split ';' | Out-String)"

            # Optionally persist the change for the current user
            [Environment]::SetEnvironmentVariable("PSModulePath", $env:PSModulePath, [EnvironmentVariableTarget]::User)
            write-host "PSModulePath environment variable set for the current user."
        }
        catch {
            # Capture and log any errors that occur during the process
            $errorMessage = $_.Exception.Message
            write-host "Error resetting module paths: $errorMessage"

            # Optionally, you could throw the error to halt the script
            throw $_
        }
    }

    end {
        # Finalization block, typically used for cleanup tasks
        write-host "Reset-ModulePaths function completed."
    }
}

Reset-ModulePaths

$currentExecutionPolicy = Get-ExecutionPolicy

# If it's not already set to Bypass, change it
if ($currentExecutionPolicy -ne 'Bypass') {
    Write-Host "Setting Execution Policy to Bypass..."
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}
else {
    Write-Host "Execution Policy is already set to Bypass."
}



#region CHECKING IF RUNNING AS WEB SCRIPT
#################################################################################################
#                                                                                               #
#                                 CHECKING IF RUNNING AS WEB SCRIPT                             #
#                                                                                               #
#################################################################################################

# Create a time-stamped folder in the temp directory
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tempFolder = [System.IO.Path]::Combine($env:TEMP, "Ensure-RunningAsSystem_$timestamp")

# Ensure the temp folder exists
if (-not (Test-Path -Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory | Out-Null
}

# Use the time-stamped temp folder for your paths
$privateFolderPath = Join-Path -Path $tempFolder -ChildPath "private"
$PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

# Check if running as a web script (no $MyInvocation.MyCommand.Path)
if (-not $MyInvocation.MyCommand.Path) {
    Write-Host "Running as web script, downloading and executing locally..."

    # Ensure TLS 1.2 is used for the download
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Create a time-stamped folder in the temp directory
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $downloadFolder = Join-Path -Path $env:TEMP -ChildPath "Install-EnhancedModuleStarterAO_$timestamp"

    # Ensure the folder exists
    if (-not (Test-Path -Path $downloadFolder)) {
        New-Item -Path $downloadFolder -ItemType Directory | Out-Null
    }

    # Download the script to the time-stamped folder
    $localScriptPath = Join-Path -Path $downloadFolder -ChildPath "Install-EnhancedModuleStarterAO.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1" -OutFile $localScriptPath

    # Write-Host "Downloading config.psd1 file..."

    # # Download the config.psd1 file to the time-stamped folder
    # $configFilePath = Join-Path -Path $downloadFolder -ChildPath "config.psd1"
    # Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aollivierre/WinUpdates/main/PR4B_TriggerM365Updates-v4/config.psd1" -OutFile $configFilePath

    # Execute the script locally
    & $localScriptPath

    Exit # Exit after running the script locally
}

else {
    # If running in a regular context, use the actual path of the script
    Write-Host "Not Running as web script, executing locally..."
    $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
    Write-Host "Script path is $ScriptToRunAsSystem"
}


# Wait-Debugger

#endregion CHECKING IF RUNNING AS WEB SCRIPT


function Relaunch-InPowerShell5 {
    # Check the current version of PowerShell
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "Hello from PowerShell 7"

        # Get the script path (works inside a function as well)
        $scriptPath = $PSCommandPath

        Write-Host "Script path to Launch in PowerShell 5 is "$scriptPath""

        # $scriptPath = $MyInvocation.MyCommand.Definition
        $ps5Path = "$($env:SystemRoot)\System32\WindowsPowerShell\v1.0\powershell.exe"

        # Build the argument to relaunch this script in PowerShell 5 with -NoExit
        $ps5Args = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        Write-Host "Relaunching in PowerShell 5..."
        Start-Process -FilePath $ps5Path -ArgumentList $ps5Args

        # Exit the current PowerShell 7 session to allow PowerShell 5 to take over
        exit
    }

    # If relaunching in PowerShell 5
    Write-Host "Hello from PowerShell 5"
    
}

Relaunch-InPowerShell5


# ################################################################################################################################
# ################################################ END Setting Execution Policy ##################################################
# ################################################################################################################################


# Ensure the private folder exists before continuing
if (-not (Test-Path -Path $privateFolderPath)) {
    New-Item -Path $privateFolderPath -ItemType Directory | Out-Null
}



# Conditional check for SimulatingIntune switch
if ($SimulatingIntune) {
    # If not running as a web script, run as SYSTEM using PsExec
    Write-Host "Simulating Intune environment. Running script as SYSTEM..."

    Write-Host "Running as SYSTEM..."


    # Call the function to run as SYSTEM
    $EnsureRunningAsSystemParams = @{
        PsExec64Path = $PsExec64Path
        ScriptPath   = $ScriptToRunAsSystem
        TargetFolder = $privateFolderPath
    }

    # Run Ensure-RunningAsSystem only if SimulatingIntune is set
    Ensure-RunningAsSystem @EnsureRunningAsSystemParams
}
else {
    Write-Host "Not simulating Intune. Skipping SYSTEM execution."
}



# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")

# Wait-Debugger

# Define a hashtable for splatting
$moduleStarterParams = @{
    Mode                   = 'prod'
    SkipPSGalleryModules   = $false
    SkipCheckandElevate    = $false
    SkipPowerShell7Install = $false
    SkipEnhancedModules    = $false
    SkipGitRepos           = $true
}

# Call the function using the splat
Invoke-ModuleStarter @moduleStarterParams


# Wait-Debugger

#endregion FIRING UP MODULE STARTER

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-EnhancedLog -Message "Running in development mode" -Level 'WARNING'
        # Your development logic here
    }
    'prod' {
        Write-EnhancedLog -Message "Running in production mode" -ForegroundColor Green
        # Your production logic here
    }
    default {
        Write-EnhancedLog -Message "Unknown mode. Defaulting to production." -ForegroundColor Red
        # Default to production
    }
}



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
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
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


    #################################################################################################################################
    ################################################# START VARIABLES ###############################################################
    #################################################################################################################################

    # Read configuration from the JSON file
    # Assign values from JSON to variables

    # Read configuration from the JSON file
    # $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    # $env:MYMODULE_CONFIG_PATH = $configPath

    # $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Read configuration from the JSON file
    # $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    # $env:MYMODULE_CONFIG_PATH = $configPath

    # $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Assign values from JSON to variables
    # $PackageName = $config.PackageName
    # $PackageUniqueGUID = $config.PackageUniqueGUID
    # $Version = $config.Version
    # $PackageExecutionContext = $config.PackageExecutionContext
    # $RepetitionInterval = $config.RepetitionInterval
    # $ScriptMode = $config.ScriptMode

    #################################################################################################################################
    ################################################# END VARIABLES #################################################################
    #################################################################################################################################


    # ################################################################################################################################
    # ############### CALLING AS SYSTEM to simulate Intune deployment as SYSTEM (Uncomment for debugging) ############################
    # ################################################################################################################################

    # # Example usage
    # $privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
    # $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"
    # $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path

    # Ensure-RunningAsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem -TargetFolder $privateFolderPath


    # ################################################################################################################################
    # ################################################ END CALLING AS SYSTEM (Uncomment for debugging) ###############################
    # ################################################################################################################################
    
    
    #################################################################################################################################
    ################################################# END LOGGING ###################################################################
    #################################################################################################################################



    ###########################################################################################################################
    #############################################STARTING THE MAIN SCHEDULED TASK LOGIC HERE###################################
    ###########################################################################################################################



    # # # Define the parameters using a hashtable
    # $taskParams = @{
    #     ConfigPath = "$PSScriptroot\config.psd1"
    #     FileName   = "HiddenScript.vbs"
    #     Scriptroot = "$PSScriptroot"
    # }

    # # Call the function with the splatted parameters
    # CreateAndRegisterScheduledTask @taskParams


    #Downloading Service UI and PSADT
    #################################################################################################
    #                                                                                               #
    #                       END Downloading Service UI and PSADT                                    #
    #                                                                                               #
    #################################################################################################
    $DownloadAndInstallServiceUIparams = @{
        TargetFolder           = "$PSScriptRoot"
        DownloadUrl            = "https://download.microsoft.com/download/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
        MsiFileName            = "MicrosoftDeploymentToolkit_x64.msi"
        InstalledServiceUIPath = "C:\Program Files\Microsoft Deployment Toolkit\Templates\Distribution\Tools\x64\ServiceUI.exe"
    }
    Download-And-Install-ServiceUI @DownloadAndInstallServiceUIparams

    $DownloadPSAppDeployToolkitParams = @{
        GithubRepository     = 'PSAppDeployToolkit/PSAppDeployToolkit'
        FilenamePatternMatch = '*.zip'
        DestinationDirectory = $PSScriptRoot
        CustomizationsPath   = "$PSScriptroot\PSADT-Customizations"
    }
    Download-PSAppDeployToolkit @DownloadPSAppDeployToolkitParams
    #endregion Downloading Service UI and PSADT



    # $CreateInteractiveMigrationTaskParams = @{
    #     TaskPath               = "Intune-PR4B"
    #     TaskName               = "PR4B-Install-Microsoft-365-Apps-Updates-8f66cef5-29bd-4210-b723-77f116a2153c"
    #     ServiceUIPath          = "C:\Program Files\_MEM\Data\PR4B-Install-Microsoft-365-Apps-Updates-8f66cef5-29bd-4210-b723-77f116a2153c\ServiceUI.exe"
    #     ToolkitExecutablePath  = "C:\Program Files\_MEM\Data\PR4B-Install-Microsoft-365-Apps-Updates-8f66cef5-29bd-4210-b723-77f116a2153c\PSAppDeployToolkit\Toolkit\Deploy-Application.exe"
    #     ProcessName            = "explorer.exe"
    #     DeploymentType         = "Install"
    #     DeployMode             = "Interactive"
    #     TaskTriggerType        = "AtLogOn"
    #     TaskRepetitionDuration = "P1D"  # 1 day
    #     TaskRepetitionInterval = "PT15M"  # 15 minutes
    #     TaskPrincipalUserId    = "NT AUTHORITY\SYSTEM"
    #     TaskRunLevel           = "Highest"
    #     TaskDescription        = "Install Microsoft 365 Apps Updates Version 1.0"
    #     Delay                  = "PT2H"  # 2 hours delay before starting
    # }

    # Create-InteractiveMigrationTask @CreateInteractiveMigrationTaskParams




    # # Define the parameters using a hashtable
    $taskParams = @{
        ConfigPath = "$PSScriptRoot\config.psd1"
        FileName   = "HiddenScript.vbs"
        Scriptroot = "$PSScriptRoot"
    }

    # Call the function with the splatted parameters
    CreateAndRegisterScheduledTask @taskParams

    

    


    # Wait-Debugger
    

 
    #endregion Script Logic
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
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
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }
    # 

    
    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

}