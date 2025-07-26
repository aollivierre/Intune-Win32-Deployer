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

    # Define a function to process a single tenant
    function Process-SingleTenant {
        param(
            [string]$TenantPath,
            [string]$TenantName,
            [object]$Config,
            [string]$ScriptRoot
        )
        
        Write-EnhancedLog -Message "========================================" -Level 'INFO'
        Write-EnhancedLog -Message "Processing tenant: $TenantName" -Level 'INFO'
        Write-EnhancedLog -Message "========================================" -Level 'INFO'
        Write-EnhancedLog -Message "Tenant path: $TenantPath" -Level 'INFO'
        
        # Define paths for the secrets.json and PFX files
        $secretsJsonPath = Join-Path -Path $TenantPath -ChildPath "secrets.json"
        $pfxFiles = Get-ChildItem -Path $TenantPath -Filter *.pfx

        # Check if secrets.json exists
        if (-Not (Test-Path -Path $secretsJsonPath)) {
            Write-Error "secrets.json file not found in '$TenantPath'."
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
            Write-Error "No PFX file found in the '$TenantPath' directory."
            throw "No PFX file found"
        }
        elseif ($pfxFiles.Count -gt 1) {
            Write-Error "Multiple PFX files found in the '$TenantPath' directory. Please ensure there is only one PFX file."
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

        # Call the function to initialize the environment
        $envInitialization = Initialize-Win32Environment -scriptpath $ScriptRoot

        # Access the properties of the EnvDetails object
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

        Remove-IntuneWinFiles -DirectoryPath $directoryPath

        #to address this bug in https://github.com/MSEndpointMgr/IntuneWin32App/issues/155 use the following function to update the Invoke-AzureStorageBlobUploadFinalize.ps1
        Copy-InvokeAzureStorageBlobUploadFinalize

        ##########################################################################################################################
        ############################################STARTING THE MAIN FUNCTION LOGIC HERE#########################################
        ##########################################################################################################################

        ################################################################################################################################
        ################################################ START GRAPH CONNECTING ########################################################
        ################################################################################################################################

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

            # Attempt to connect using the certificate for custom operations
            Write-EnhancedLog -Message "Attempting to connect to Microsoft Graph using certificate authentication..." -Level "INFO"
            $accessToken = Connect-GraphWithCert @graphParams
            Write-EnhancedLog -Message "Connected using certificate authentication for custom operations. Access token obtained." -Level "INFO"
            
            # CRITICAL: Also authenticate with IntuneWin32App module
            Write-EnhancedLog -Message "Establishing authentication with IntuneWin32App module..." -Level "INFO"
            try {
                # Clear any existing authentication state first
                Write-EnhancedLog -Message "Clearing any existing IntuneWin32App authentication state..." -Level "INFO"
                $Global:AccessToken = $null
                $Global:AuthenticationHeader = $null
                $Global:AccessTokenTenantID = $null
                
                # Extract certificate thumbprint
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $CertPassword)
                $certThumbprint = $cert.Thumbprint
                Write-EnhancedLog -Message "Certificate thumbprint: $certThumbprint" -Level "INFO"
                Write-EnhancedLog -Message "Certificate subject: $($cert.Subject)" -Level "INFO"
                
                # Store the certificate object globally for later use
                $Global:CertObject = $cert
                
                # Connect using IntuneWin32App module - pass the certificate object directly
                Write-EnhancedLog -Message "Calling Connect-MSIntuneGraph with TenantID: $tenantId, ClientID: $clientId" -Level "INFO"
                Connect-MSIntuneGraph -TenantID $tenantId -ClientID $clientId -ClientCert $cert
                Write-EnhancedLog -Message "Successfully authenticated with IntuneWin32App module" -Level "INFO"
            }
            catch {
                Write-EnhancedLog -Message "Failed to authenticate with IntuneWin32App module: $($_.Exception.Message)" -Level "WARNING"
                Write-EnhancedLog -Message "Will attempt interactive authentication if needed later" -Level "INFO"
            }
        
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

        # Store authentication parameters globally for potential reconnection later
        $Global:TenantId = $tenantId
        $Global:ClientId = $clientId
        $Global:CertPath = $certPath
        $Global:CertPassword = $CertPassword
        Write-EnhancedLog -Message "Stored authentication parameters globally for reconnection purposes" -Level "INFO"
        
        # Verify IntuneWin32App module authentication
        if ($null -eq $Global:AuthenticationHeader) {
            Write-EnhancedLog -Message "WARNING: IntuneWin32App module authentication header not found" -Level "WARNING"
            Write-EnhancedLog -Message "Authentication will be attempted when needed during app upload" -Level "INFO"
        }
        else {
            Write-EnhancedLog -Message "IntuneWin32App module authentication verified successfully" -Level "INFO"
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

        # Retrieve all folder names in the specified directory
        $folders = Get-ChildItem -Path $directoryPath -Directory

        foreach ($folder in $folders) {

            $ProcessFolderParams = @{
                Folder      = $folder
                config      = $Config
                Repo_winget = $Repo_winget
                scriptpath  = $ScriptRoot
                Repo_Path   = $Repo_Path
            }
            
            $folderDetails = Process-Folder @ProcessFolderParams
            
        }

        Write-EnhancedLog -Message "========================================" -Level 'INFO'
        Write-EnhancedLog -Message "Completed processing tenant: $TenantName" -Level 'INFO'
        Write-EnhancedLog -Message "========================================" -Level 'INFO'
    }

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

    # Read configuration from the JSON file (do this once, outside tenant processing)
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Check if we have multiple tenants
    if ($tenantFolders.Count -eq 1) {
        # Single tenant - use it automatically without prompting
        $selectedTenant = $tenantFolders[0].Name
        $selectedTenantPath = $tenantFolders[0].FullName
        Write-Host "Using tenant: $selectedTenant" -ForegroundColor Green
        
        # Process the single tenant
        Process-SingleTenant -TenantPath $selectedTenantPath -TenantName $selectedTenant -Config $config -ScriptRoot $PSScriptRoot
    }
    else {
        # Multiple tenants - prompt for selection
        Write-Host "Available tenant folders:"
        $tenantFolders | ForEach-Object -Begin { $i = 1 } -Process {
            Write-Host "$i. $($_.Name)"
            $i++
        }
        Write-Host "$($tenantFolders.Count + 1). All tenants" -ForegroundColor Cyan

        # Prompt user for selection
        do {
            $selection = Read-Host "Enter the number of the tenant folder you want to use (1-$($tenantFolders.Count + 1))"
            
            # Validate the input is a number
            if ($selection -match '^\d+$') {
                $selectedNumber = [int]$selection
            } else {
                $selectedNumber = -1
            }
            
            # Check if selection is within valid range
            if ($selectedNumber -lt 1 -or $selectedNumber -gt ($tenantFolders.Count + 1)) {
                Write-Host "Invalid selection. Please enter a number between 1 and $($tenantFolders.Count + 1)." -ForegroundColor Yellow
            }
        } while ($selectedNumber -lt 1 -or $selectedNumber -gt ($tenantFolders.Count + 1))

        # Check if user selected "All tenants"
        if ($selectedNumber -eq ($tenantFolders.Count + 1)) {
            # Process all tenants
            Write-Host "You selected: All tenants" -ForegroundColor Green
            Write-EnhancedLog -Message "Processing all tenants..." -Level 'INFO'
            
            $successCount = 0
            $failureCount = 0
            
            foreach ($tenantFolder in $tenantFolders) {
                try {
                    Process-SingleTenant -TenantPath $tenantFolder.FullName -TenantName $tenantFolder.Name -Config $config -ScriptRoot $PSScriptRoot
                    $successCount++
                }
                catch {
                    Write-EnhancedLog -Message "Failed to process tenant '$($tenantFolder.Name)': $_" -Level 'ERROR'
                    $failureCount++
                    # Continue with next tenant instead of failing completely
                    continue
                }
            }
            
            Write-EnhancedLog -Message "========================================" -Level 'INFO'
            Write-EnhancedLog -Message "FINAL SUMMARY" -Level 'INFO'
            Write-EnhancedLog -Message "========================================" -Level 'INFO'
            Write-EnhancedLog -Message "Total tenants: $($tenantFolders.Count)" -Level 'INFO'
            Write-EnhancedLog -Message "Successfully processed: $successCount" -Level 'INFO'
            Write-EnhancedLog -Message "Failed: $failureCount" -Level 'INFO'
            Write-EnhancedLog -Message "========================================" -Level 'INFO'
            
            if ($successCount -eq 0) {
                Write-Error "No tenants could be processed successfully."
                throw "No valid tenants found"
            }
        }
        else {
            # Get the selected tenant folder
            $selectedIndex = $selectedNumber - 1
            $selectedTenant = $tenantFolders[$selectedIndex].Name
            $selectedTenantPath = $tenantFolders[$selectedIndex].FullName
            
            Write-Host "You selected: $selectedTenant" -ForegroundColor Green
            
            # Process the selected tenant
            Process-SingleTenant -TenantPath $selectedTenantPath -TenantName $selectedTenant -Config $config -ScriptRoot $PSScriptRoot
        }
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