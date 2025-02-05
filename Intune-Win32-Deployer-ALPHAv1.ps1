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

# Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")

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





# Define a hashtable for splatting
# $moduleStarterParams = @{
#     Mode                   = 'PROD'
#     SkipPSGalleryModules   = $FALSE
#     SkipCheckandElevate    = $FALSE
#     SkipPowerShell7Install = $FALSE
#     SkipEnhancedModules    = $FALSE
#     SkipGitRepos           = $true
# }

# # Call the function using the splat
# Invoke-ModuleStarter @moduleStarterParams


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


    #     Start
    #   |
    #   v
    # Check if secrets directory exists
    #   |
    #   +-- [Yes] --> Check if tenant folders exist
    #   |                |
    #   |                +-- [Yes] --> List tenant folders
    #   |                |                |
    #   |                |                v
    #   |                |       Display list and prompt user for tenant selection
    #   |                |                |
    #   |                |                v
    #   |                |       Validate user's selected tenant folder
    #   |                |                |
    #   |                |                +-- [Valid] --> Check if secrets.json exists
    #   |                |                |                 |
    #   |                |                |                 +-- [Yes] --> Load secrets from JSON file
    #   |                |                |                 |                |
    #   |                |                |                 |                v
    #   |                |                |                 |        Check for PFX file
    #   |                |                |                 |                |
    #   |                |                |                 |                +-- [Yes] --> Validate single PFX file
    #   |                |                |                 |                |                 |
    #   |                |                |                 |                |                 v
    #   |                |                |                 |                |        Assign values from secrets to variables
    #   |                |                |                 |                |                 |
    #   |                |                |                 |                |                 v
    #   |                |                |                 |                +--> Write log "PFX file found"
    #   |                |                |                 |
    #   |                |                |                 +-- [No] --> Error: secrets.json not found
    #   |                |                |                
    #   |                |                +-- [Invalid] --> Error: Invalid tenant folder
    #   |                |                
    #   |                +-- [No] --> Error: No tenant folders found
    #   |
    #   +-- [No] --> Error: Secrets directory not found
    #   |
    #   v
    # End


    # Define the path to the secrets directory
    $secretsDirPath = Join-Path -Path $PSScriptRoot -ChildPath "secrets"

    # Check if the secrets directory exists
    if (-Not (Test-Path -Path $secretsDirPath)) {
        Write-Error "Secrets directory not found at '$secretsDirPath'."
        throw "Secrets directory not found"
    }

    # List all folders (tenants) in the secrets directory
    $tenantFolders = Get-ChildItem -Path $secretsDirPath -Directory

    if ($tenantFolders.Count -eq 0) {
        Write-Error "No tenant folders found in the secrets directory."
        throw "No tenant folders found"
    }

    # Display the list of tenant folders and ask the user to confirm
    Write-Host "Available tenant folders:"
    $tenantFolders | ForEach-Object { Write-Host "- $($_.Name)" }

    $selectedTenant = Read-Host "Enter the name of the tenant folder you want to use"

    # Validate the user's selection
    $selectedTenantPath = Join-Path -Path $secretsDirPath -ChildPath $selectedTenant

    if (-Not (Test-Path -Path $selectedTenantPath)) {
        Write-Error "The specified tenant folder '$selectedTenant' does not exist."
        throw "Invalid tenant folder"
    }

    # Define paths for the secrets.json and PFX files
    $secretsJsonPath = Join-Path -Path $selectedTenantPath -ChildPath "secrets.json"
    $pfxFiles = Get-ChildItem -Path $selectedTenantPath -Filter *.pfx

    # Check if secrets.json exists
    if (-Not (Test-Path -Path $secretsJsonPath)) {
        Write-Error "secrets.json file not found in '$selectedTenantPath'."
        throw "secrets.json file not found"
    }

    # Load the secrets from the JSON file
    Write-EnhancedLog -Message "Loading secrets from: $secretsJsonPath" -Level 'INFO'
    $secrets = Get-Content -Path $secretsJsonPath -Raw | ConvertFrom-Json

    # Debug: List all available properties in secrets
    Write-EnhancedLog -Message "Available properties in secrets file:" -Level 'INFO'
    $secrets.PSObject.Properties | ForEach-Object {
        Write-EnhancedLog -Message "Property: $($_.Name) = $($_.Value)" -Level 'INFO'
    }

    # Check if a PFX file exists
    if ($pfxFiles.Count -eq 0) {
        Write-Error "No PFX file found in the '$selectedTenantPath' directory."
        throw "No PFX file found"
    }
    elseif ($pfxFiles.Count -gt 1) {
        Write-Error "Multiple PFX files found in the '$selectedTenantPath' directory. Please ensure there is only one PFX file."
        throw "Multiple PFX files found"
    }

    # Use the first (and presumably only) PFX file found
    $certPath = $pfxFiles[0].FullName
    Write-EnhancedLog -Message "PFX file found: $certPath" -Level 'INFO'

    # Assign values from JSON to variables with detailed logging
    Write-EnhancedLog -Message "Attempting to load TenantID..." -Level 'INFO'
    $tenantId = $secrets.PSObject.Properties['TenantID'].Value
    Write-EnhancedLog -Message "Loaded TenantID: $tenantId" -Level 'INFO'

    Write-EnhancedLog -Message "Attempting to load ClientId..." -Level 'INFO'
    $clientId = $secrets.PSObject.Properties['ClientId'].Value
    Write-EnhancedLog -Message "Loaded ClientId: $clientId" -Level 'INFO'

    Write-EnhancedLog -Message "Attempting to load CertPassword..." -Level 'INFO'
    $CertPassword = $secrets.PSObject.Properties['CertPassword'].Value
    Write-EnhancedLog -Message "CertPassword loaded (value hidden for security)" -Level 'INFO'

    # Validate the required values with detailed error messages
    if ([string]::IsNullOrWhiteSpace($tenantId)) {
        Write-EnhancedLog -Message "TenantID is missing or empty in secrets.json" -Level 'ERROR'
        throw "TenantID is missing or empty in secrets.json"
    }
    if ([string]::IsNullOrWhiteSpace($clientId)) {
        Write-EnhancedLog -Message "ClientId is missing or empty in secrets.json" -Level 'ERROR'
        throw "ClientId is missing or empty in secrets.json"
    }
    if ([string]::IsNullOrWhiteSpace($CertPassword)) {
        Write-EnhancedLog -Message "CertPassword is missing or empty in secrets.json" -Level 'ERROR'
        throw "CertPassword is missing or empty in secrets.json"
    }

    Write-EnhancedLog -Message "Successfully loaded all required authentication details from secrets.json" -Level 'INFO'
    Write-EnhancedLog -Message "TenantID length: $($tenantId.Length) characters" -Level 'INFO'
    Write-EnhancedLog -Message "ClientId length: $($clientId.Length) characters" -Level 'INFO'
    Write-EnhancedLog -Message "CertPassword length: $($CertPassword.Length) characters" -Level 'INFO'


    #endregion LOADING SECRETS FOR GRAPH


    # Read configuration from the JSON file
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    # $env:MYMODULE_CONFIG_PATH = $configPath
    
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

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

    # ################################################################################################################################
    # ################################################ START GRAPH CONNECTING ########################################################
    # ################################################################################################################################
    # # Define the splat for Connect-GraphWithCert
    # $graphParams = @{
    #     tenantId        = $tenantId
    #     clientId        = $clientId
    #     certPath        = $certPath
    #     certPassword    = $certPassword
    #     ConnectToIntune = $true
    #     ConnectToTeams  = $false
    # }

    # # Connect to Microsoft Graph, Intune, and Teams
    # $accessToken = Connect-GraphWithCert @graphParams




    # # # Path to the scopes.json file
    # # $jsonFilePath = "$PSscriptroot\scopes.json"

    # # # Read the JSON file
    # # $jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json

    # # # Extract the scopes
    # # $scopes = $jsonContent.Scopes -join " "

    # # # Connect to Microsoft Graph with the specified scopes
    # # # Connect to Graph interactively
    # # disconnect-Graph
    # # Disconnect-MgGraph -Verbose

    # # # Call the function to connect to Microsoft Graph
    # # Connect-ToMicrosoftGraphIfServerCore -Scopes $scopes



    # Log-Params -Params @{accessToken = $accessToken }

    # # Get-TenantDetails


    # # Wait-Debugger


    # # Get the tenant details
    # $tenantDetails = $null
    # $tenantDetails = Get-TenantDetails
    # if ($null -eq $tenantDetails) {
    #     Write-EnhancedLog -Message "Unable to proceed without tenant details" -Level "ERROR"
    #     throw "Tenant Details name is empty. Cannot proceed without a valid tenant details"
    #     exit
    # }

    # $tenantDetails








    ################################################################################################################################
    ################################################ START GRAPH CONNECTING ########################################################
    ################################################################################################################################

    # Define the splat for Connect-GraphWithCert
    # $graphParams = @{
    #     tenantId        = $tenantId
    #     clientId        = $clientId
    #     certPath        = $certPath
    #     certPassword    = $certPassword
    #     ConnectToIntune = $true
    #     ConnectToTeams  = $false
    # }

    # $accessToken = $null
    # $tenantDetails = $null



    # $tenantId

    # Connect interactively to Intune
    # Connect-ToIntuneInteractive -tenantId $tenantId

    # Connect interactively to Intune
    # Connect-ToIntuneInteractive -tenantId $tenantId -clientId $clientId
    # Connect-ToIntuneInteractive -tenantId $tenantId


    # $accessToken = Connect-GraphWithCert @graphParams





    #   # Disconnect any existing sessions before reconnecting interactively
    #   Disconnect-Graph
    #   Disconnect-MgGraph -Verbose

    #   # Path to the scopes.json file (adjust this path as necessary)
    #   $jsonFilePath = "$PSScriptRoot\scopes.json"

    #   # Read the JSON file and extract scopes
    #   $jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
    #   $scopes = $jsonContent.Scopes -join " "

    #   # Connect to Microsoft Graph interactively using the specified scopes
    #   Write-EnhancedLog -Message "Connecting to Microsoft Graph interactively..." -Level "INFO"
    #   Connect-ToMicrosoftGraphIfServerCore -Scopes $scopes



    try {
        # Log the values right before connecting
        Write-EnhancedLog -Message "Preparing to connect with the following values:" -Level 'INFO'
        Write-EnhancedLog -Message "TenantID: $tenantId" -Level 'INFO'
        Write-EnhancedLog -Message "ClientID: $clientId" -Level 'INFO'
        Write-EnhancedLog -Message "CertPath: $certPath" -Level 'INFO'
        Write-EnhancedLog -Message "CertPassword length: $($CertPassword.Length)" -Level 'INFO'

        # Create hashtable for splatting with explicit string conversions
        $graphParams = @{
            tenantId = [string]$tenantId
            clientId = [string]$clientId
            certPath = [string]$certPath
            certPassword = [string]$CertPassword
            ConnectToIntune = $true
            ConnectToTeams = $false
        }

        # Log the hashtable values
        Write-EnhancedLog -Message "Checking splat parameters:" -Level 'INFO'
        Write-EnhancedLog -Message "tenantId from splat: $($graphParams.tenantId)" -Level 'INFO'
        Write-EnhancedLog -Message "clientId from splat: $($graphParams.clientId)" -Level 'INFO'
        Write-EnhancedLog -Message "certPath from splat: $($graphParams.certPath)" -Level 'INFO'

        # Attempt to connect using the certificate
        Write-EnhancedLog -Message "Attempting to connect to Microsoft Graph using certificate authentication..." -Level "INFO"
        $accessToken = Connect-GraphWithCert @graphParams
        Write-EnhancedLog -Message "Connected using certificate authentication. Access token obtained." -Level "INFO"
    
        # Attempt to get tenant details
        Write-EnhancedLog -Message "Attempting to retrieve tenant details..." -Level "INFO"
        $tenantDetails = Get-TenantDetails

        # Check if tenant details are retrieved successfully
        if ($null -eq $tenantDetails) {
            Write-EnhancedLog -Message "Tenant details could not be retrieved." -Level 'WARNING'
        }
        Write-EnhancedLog -Message "Tenant details retrieved successfully." -Level "INFO"
    }
    catch {
        # Handle any errors during certificate-based authentication
        $errorMessage = "Failed to connect using certificate-based authentication or retrieve tenant details. Reason: $($_.Exception.Message)"
        Write-EnhancedLog -Message $errorMessage -Level "ERROR"
        Write-EnhancedLog -Message "Full error details: $($_ | ConvertTo-Json)" -Level "ERROR"

        # Log that we are falling back to interactive authentication
        Write-EnhancedLog -Message "Falling back to interactive authentication..." -Level "WARNING"

        try {
            Write-EnhancedLog -Message "Attempting interactive authentication with TenantID: $tenantId" -Level "INFO"
            Connect-MSIntuneGraph -TenantID $tenantId -Interactive
            Write-EnhancedLog -Message "Interactive authentication successful" -Level "INFO"
        }
        catch {
            Write-EnhancedLog -Message "Interactive authentication failed: $($_.Exception.Message)" -Level "ERROR"
            Write-EnhancedLog -Message "Full error details: $($_ | ConvertTo-Json)" -Level "ERROR"
            throw
        }
    }

    # Continue with the script logic now that tenant details are retrieved
    Log-Params -Params @{accessToken = $accessToken; tenantDetails = $tenantDetails }

    # Example output of tenant details
    $tenantDetails



 









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