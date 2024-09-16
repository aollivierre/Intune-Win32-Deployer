#############################################################################################################
#
#   Tool:           Intune Win32 Deployer
#   Author:         Abdullah Ollivierre
#   Website:        https://github.com/aollivierre
#   Twitter:        https://x.com/ollivierre
#   LinkedIn:       https://www.linkedin.com/in/aollivierre
#
#   Description:    https://github.com/aollivierre
#
#############################################################################################################

<#
    .SYNOPSIS
    Packages any custom app for MEM (Intune) deployment.
    Uploads the packaged into the target Intune tenant.

    .NOTES
    For details on IntuneWin32App go here: https://github.com/aollivierre

#>


#region RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION
#################################################################################################
#                                                                                               #
#                           RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION                           #
#                                                                                               #
#################################################################################################

function Relaunch-InPowerShell5 {
    # Check the current version of PowerShell
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "Hello from PowerShell 7"

        # Get the script path (works inside a function as well)
        $scriptPath = $PSCommandPath

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


#endregion RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION
#################################################################################################
#                                                                                               #
#                           END OF RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION                    #
#                                                                                               #
#################################################################################################


# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'dev', 'Machine')

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
    Mode                   = 'dev'
    SkipPSGalleryModules   = $true
    SkipCheckandElevate    = $true
    SkipPowerShell7Install = $true
    SkipEnhancedModules    = $true
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
$JobName = "Win32AppDeployer"
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


    #region LOADING SECRETS FOR GRAPH
    #################################################################################################
    #                                                                                               #
    #                                 LOADING SECRETS FOR GRAPH                                     #
    #                                                                                               #
    #################################################################################################


    #First, load secrets and create a credential object:
    # Assuming secrets.json is in the same directory as your script
    $secretsPath = Join-Path -Path $PSScriptRoot -ChildPath "secrets.json"

    # Load the secrets from the JSON file
    $secrets = Get-Content -Path $secretsPath -Raw | ConvertFrom-Json

    # Read configuration from the JSON file
    # Assign values from JSON to variables

    # Read configuration from the JSON file
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    $env:MYMODULE_CONFIG_PATH = $configPath

    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    #  Variables from JSON file
    $tenantId = $secrets.TenantId
    $clientId = $secrets.ClientId

    # Find any PFX file in the root directory of the script
    $pfxFiles = Get-ChildItem -Path $PSScriptRoot -Filter *.pfx

    if ($pfxFiles.Count -eq 0) {
        Write-Error "No PFX file found in the root directory."
        throw "No PFX file found"
    }
    elseif ($pfxFiles.Count -gt 1) {
        Write-Error "Multiple PFX files found in the root directory. Please ensure there is only one PFX file."
        throw "Multiple PFX files found"
    }

    # Use the first (and presumably only) PFX file found
    $certPath = $pfxFiles[0].FullName

    Write-EnhancedLog -Message "PFX file found: $certPath" -Level 'INFO'

    $CertPassword = $secrets.CertPassword

    #endregion LOADING SECRETS FOR GRAPH

    # Call the function to initialize the environment
    $envInitialization = Initialize-Win32Environment -scriptpath $PSScriptRoot


    # # Run Initialize-Win32Environment and store the returned object
    # $envInitialization = Initialize-Win32Environment -scriptpath "C:\path\to\your\script.ps1"

    # # Access the properties of the EnvDetails object
    $AOscriptDirectory = $envInitialization.EnvDetails.AOscriptDirectory
    $directoryPath = $envInitialization.EnvDetails.directoryPath
    $Repo_Path = $envInitialization.EnvDetails.Repo_Path
    $Repo_winget = $envInitialization.EnvDetails.Repo_winget

    # Output the extracted values
    Write-EnhancedLog -Message "Global variables set by Initialize-Win32Environment" -Level 'INFO'
    Write-EnhancedLog -Message "AO Script Directory: $AOscriptDirectory"
    Write-EnhancedLog -Message "Directory Path: $directoryPath"
    Write-EnhancedLog -Message "Repository Path: $Repo_Path"
    Write-EnhancedLog -Message "Winget Path: $Repo_winget"



    # Example usage of global variables outside the function
    Write-EnhancedLog -Message "scriptBasePath: $scriptBasePath" -Level 'INFO'
    Write-EnhancedLog -Message "modulesBasePath: $modulesBasePath" -Level 'INFO'
    Write-EnhancedLog -Message "modulePath: $modulePath" -Level 'INFO'

    # Write-EnhancedLog -Message "AOscriptDirectory: $AOscriptDirectory" -Level 'INFO'
    # Write-EnhancedLog -Message "directoryPath: "$envInitialization.EnvDetails.directoryPath"" -Level 'INFO'
    # Write-EnhancedLog -Message "Repo_Path: $Repo_Path" -Level 'INFO'
    # Write-EnhancedLog -Message "Repo_winget: $Repo_winget" -Level 'INFO'


    # Wait-Debugger


    Remove-IntuneWinFiles -DirectoryPath $directoryPath


    # Wait-Debugger



    #to address this bug in https://github.com/MSEndpointMgr/IntuneWin32App/issues/155 use the following function to update the Invoke-AzureStorageBlobUploadFinalize.ps1

    Copy-InvokeAzureStorageBlobUploadFinalize

    ##########################################################################################################################
    ############################################STARTING THE MAIN FUNCTION LOGIC HERE#########################################
    ##########################################################################################################################

    ################################################################################################################################
    ################################################ START Ensure-ScriptPathsExist #################################################
    ################################################################################################################################

    ################################################################################################################################
    ################################################ START GRAPH CONNECTING ########################################################
    ################################################################################################################################
    # Define the splat for Connect-GraphWithCert
    $graphParams = @{
        tenantId        = $tenantId
        clientId        = $clientId
        certPath        = $certPath
        certPassword    = $certPassword
        ConnectToIntune = $true
        ConnectToTeams  = $false
    }

    # Connect to Microsoft Graph, Intune, and Teams
    $accessToken = Connect-GraphWithCert @graphParams

    Log-Params -Params @{accessToken = $accessToken }

    Get-TenantDetails
    #################################################################################################################################
    ################################################# END Connecting to Graph #######################################################
    #################################################################################################################################
 
    ####################################################################################
    #   GO!
    ####################################################################################

    # Wait-Debugger

    # Invoke-ScriptInPS5 -ScriptPath "C:\Code\Intune-Win32-Deployer\UploadWin32App.PS5Script.ps1"


    # Retrieve all folder names in the specified directory
    $folders = Get-ChildItem -Path $directoryPath -Directory

    foreach ($folder in $folders) {

        $ProcessFolderParams = @{
            Folder      = $folder
            config      = $config
            Repo_winget = $Repo_winget
            scriptpath  = $PSScriptRoot
        }
        
        $folderDetails = Process-Folder @ProcessFolderParams
        
    }

 
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