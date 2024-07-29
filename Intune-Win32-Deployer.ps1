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

#################################################################################################################################
################################################# START VARIABLES ###############################################################
#################################################################################################################################

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

# $certPath = Join-Path -Path $PSScriptRoot -ChildPath 'graphcert.pfx'


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

Write-Output "PFX file found: $certPath"

$CertPassword = $secrets.CertPassword


# Now populate the connection parameters with values from the secrets file
# $connectionParams = @{
#     clientId     = $secrets.clientId
#     tenantID     = $secrets.tenantID
#     # ClientSecret = $secrets.ClientSecret
#     Clientcert = $certPath
# }

# $TenantName = $secrets.TenantName
# $site_objectid = "your group object id"
# $siteObjectId = $secrets.SiteObjectId

# $document_drive_name = "Documents"
# $document_drive_name = "Documents"
# $documentDriveName = $secrets.DocumentDriveName



# Assign values from JSON to variables
# $PackageName = $config.PackageName
# $PackageUniqueGUID = $config.PackageUniqueGUID
# $Version = $config.Version
# $PackageExecutionContext = $config.PackageExecutionContext
# $RepetitionInterval = $config.RepetitionInterval
# $ScriptMode = $config.ScriptMode


function Initialize-Environment {
    param (
        [string]$WindowsModulePath = "EnhancedBoilerPlateAO\2.0.0\EnhancedBoilerPlateAO.psm1",
        [string]$LinuxModulePath = "/usr/src/code/Modules/EnhancedBoilerPlateAO/2.0.0/EnhancedBoilerPlateAO.psm1"
    )

    function Get-Platform {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return $PSVersionTable.Platform
        }
        else {
            return [System.Environment]::OSVersion.Platform
        }
    }

    function Setup-GlobalPaths {
        if ($env:DOCKER_ENV -eq $true) {
            $global:scriptBasePath = $env:SCRIPT_BASE_PATH
            $global:modulesBasePath = $env:MODULES_BASE_PATH
        }
        else {
            $global:scriptBasePath = $PSScriptRoot
            # $global:modulesBasePath = "$PSScriptRoot\modules"
            $global:modulesBasePath = "c:\code\modules"
        }
    }

    function Setup-WindowsEnvironment {
        # Get the base paths from the global variables
        Setup-GlobalPaths

        # Construct the paths dynamically using the base paths
        $global:modulePath = Join-Path -Path $modulesBasePath -ChildPath $WindowsModulePath
        $global:AOscriptDirectory = Join-Path -Path $scriptBasePath -ChildPath "Win32Apps-DropBox"
        $global:directoryPath = Join-Path -Path $scriptBasePath -ChildPath "Win32Apps-DropBox"
        $global:Repo_Path = $scriptBasePath
        $global:Repo_winget = "$Repo_Path\Win32Apps-DropBox"


        # Import the module using the dynamically constructed path
        Import-Module -Name $global:modulePath -Verbose -Force:$true -Global:$true

        # Log the paths to verify
        Write-Output "Module Path: $global:modulePath"
        Write-Output "Repo Path: $global:Repo_Path"
        Write-Output "Repo Winget Path: $global:Repo_winget"
    }

    function Setup-LinuxEnvironment {
        # Get the base paths from the global variables
        Setup-GlobalPaths

        # Import the module using the Linux path
        Import-Module $LinuxModulePath -Verbose

        # Convert paths from Windows to Linux format
        # $global:AOscriptDirectory = Convert-WindowsPathToLinuxPath -WindowsPath "$PSscriptroot"
        # $global:directoryPath = Convert-WindowsPathToLinuxPath -WindowsPath "$PSscriptroot\Win32Apps-DropBox"
        # $global:Repo_Path = Convert-WindowsPathToLinuxPath -WindowsPath "$PSscriptroot"
        $global:IntuneWin32App = Convert-WindowsPathToLinuxPath -WindowsPath "C:\Code\IntuneWin32App\IntuneWin32App.psm1"

        Import-Module $global:IntuneWin32App -Verbose -Global


        $global:AOscriptDirectory = "$PSscriptroot"
        $global:directoryPath = "$PSscriptroot/Win32Apps-DropBox"
        $global:Repo_Path = "$PSscriptroot"
        $global:Repo_winget = "$global:Repo_Path/Win32Apps-DropBox"
    }

    $platform = Get-Platform
    if ($platform -eq 'Win32NT' -or $platform -eq [System.PlatformID]::Win32NT) {
        Setup-WindowsEnvironment
    }
    elseif ($platform -eq 'Unix' -or $platform -eq [System.PlatformID]::Unix) {
        Setup-LinuxEnvironment
    }
    else {
        throw "Unsupported operating system"
    }
}

# Call the function to initialize the environment
Initialize-Environment


# Example usage of global variables outside the function
Write-Output "Global variables set by Initialize-Environment:"
Write-Output "scriptBasePath: $scriptBasePath"
Write-Output "modulesBasePath: $modulesBasePath"
Write-Output "modulePath: $modulePath"
Write-Output "AOscriptDirectory: $AOscriptDirectory"
Write-Output "directoryPath: $directoryPath"
Write-Output "Repo_Path: $Repo_Path"
Write-Output "Repo_winget: $Repo_winget"








#################################################################################################################################
################################################# END VARIABLES #################################################################
#################################################################################################################################

###############################################################################################################################
############################################### START MODULE LOADING ##########################################################
###############################################################################################################################

<#
.SYNOPSIS
Dot-sources all PowerShell scripts in the 'private' folder relative to the script root.

.DESCRIPTION
This function finds all PowerShell (.ps1) scripts in a 'private' folder located in the script root directory and dot-sources them. It logs the process, including any errors encountered, with optional color coding.

.EXAMPLE
Dot-SourcePrivateScripts

Dot-sources all scripts in the 'private' folder and logs the process.

.NOTES
Ensure the Write-EnhancedLog function is defined before using this function for logging purposes.
#>



Write-Host "Starting to call Get-ModulesFolderPath..."

# Store the outcome in $ModulesFolderPath
try {
  
    $ModulesFolderPath = Get-ModulesFolderPath -WindowsPath "C:\code\modules" -UnixPath "/usr/src/code/modules"
    # $ModulesFolderPath = Get-ModulesFolderPath -WindowsPath "$PsScriptRoot" -UnixPath "/usr/src/code/modules"
    Write-host "Modules folder path: $ModulesFolderPath"

}
catch {
    Write-Error $_.Exception.Message
}


Write-Host "Starting to call Get-ModulesScriptPathsAndVariables..."
# Retrieve script paths and related variables
# $DotSourcinginitializationInfo = Get-ModulesScriptPathsAndVariables -BaseDirectory "c:\" -ModulesFolderPath $ModulesFolderPath
# $DotSourcinginitializationInfo = Get-ModulesScriptPathsAndVariables -BaseDirectory $PSScriptRoot -ModulesFolderPath $ModulesFolderPath
# $DotSourcinginitializationInfo = Get-ModulesScriptPathsAndVariables -BaseDirectory $ModulesFolderPath

# $DotSourcinginitializationInfo
# $DotSourcinginitializationInfo | Format-List

Write-Host "Starting to call Import-LatestModulesLocalRepository..."
Import-LatestModulesLocalRepository -ModulesFolderPath $ModulesFolderPath -ScriptPath $PSScriptRoot


###############################################################################################################################
############################################### END MODULE LOADING ############################################################
###############################################################################################################################
try {
    Ensure-LoggingFunctionExists -LoggingFunctionName "Write-EnhancedLog"
    # Continue with the rest of the script here
    # exit
}
catch {
    Write-Host "Critical error: $_" -ForegroundColor Red
    exit
}

###############################################################################################################################
###############################################################################################################################
###############################################################################################################################

# Setup logging
Write-EnhancedLog -Message "Script Started" -Level "INFO" -ForegroundColor ([ConsoleColor]::Cyan)

################################################################################################################################
################################################################################################################################
################################################################################################################################

# Execute InstallAndImportModulesPSGallery function
InstallAndImportModulesPSGallery -moduleJsonPath "$PSScriptRoot/modules.json"

################################################################################################################################
################################################ END MODULE CHECKING ###########################################################
################################################################################################################################


#to address this bug in https://github.com/MSEndpointMgr/IntuneWin32App/issues/155 use the following function to update the Invoke-AzureStorageBlobUploadFinalize.ps1
function Copy-InvokeAzureStorageBlobUploadFinalize {
    param (
        [string]$sourceFile = "C:\Code\IntuneWin32App\Private\Invoke-AzureStorageBlobUploadFinalize.ps1",
        [string[]]$destinationPaths = @(
            "C:\Users\Administrator\Documents\PowerShell\Modules\IntuneWin32App\1.4.4\Private\Invoke-AzureStorageBlobUploadFinalize.ps1",
            "C:\Users\Administrator\Documents\WindowsPowerShell\Modules\IntuneWin32App\1.4.4\Private\Invoke-AzureStorageBlobUploadFinalize.ps1"
        )
    )

    begin {
        Write-EnhancedLog -Message "Starting the file copy process..." -Level "INFO"
    }

    process {
        foreach ($destination in $destinationPaths) {
            try {
                Write-EnhancedLog -Message "Copying file to $destination" -Level "INFO"
                Copy-Item -Path $sourceFile -Destination $destination -Force
                Write-EnhancedLog -Message "Successfully copied to $destination" -Level "INFO"
            } catch {
                Write-EnhancedLog -Message "Failed to copy to $destination. Error: $_" -Level "ERROR"
                Handle-Error -ErrorRecord $_
            }
        }
    }

    end {
        Write-EnhancedLog -Message "File copy process completed." -Level "INFO"
    }
}

Copy-InvokeAzureStorageBlobUploadFinalize

    
################################################################################################################################
################################################ END LOGGING ###################################################################
################################################################################################################################

#  Define the variables to be used for the function
#  $PSADTdownloadParams = @{
#      GithubRepository     = "psappdeploytoolkit/psappdeploytoolkit"
#      FilenamePatternMatch = "PSAppDeployToolkit*.zip"
#      ZipExtractionPath    = Join-Path "$PSScriptRoot\private" "PSAppDeployToolkit"
#  }

#  Call the function with the variables
#  Download-PSAppDeployToolkit @PSADTdownloadParams

################################################################################################################################
################################################ END DOWNLOADING PSADT #########################################################
################################################################################################################################


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
Remove-IntuneWinFiles -DirectoryPath $directoryPath
####################################################################################
#   GO!
####################################################################################


function Process-Folder {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Folder
    )

    # Construct the path to the printer.json within the current folder
    $printerConfigPath = Join-Path -Path $Folder.FullName -ChildPath "printer.json"

    if (Test-Path -Path $printerConfigPath) {
        Process-PrinterInstallation -PrinterConfigPath $printerConfigPath
        Write-EnhancedLog -Message "Processed printer installation for folder: $($Folder.Name)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }
    else {
        Write-EnhancedLog -Message "printer.json not found in folder: $($Folder.Name)" -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
    }

    Process-Win32App -Folder $Folder
}

function Process-PrinterInstallation {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrinterConfigPath
    )

    $commands = Invoke-PrinterInstallation -PrinterConfigPath $PrinterConfigPath -AppConfigPath $configPath
    Write-Output "Install Command: $($commands.InstallCommand)"
    Write-Output "Uninstall Command: $($commands.UninstallCommand)"
    
    $global:InstallCommandLine = $commands.InstallCommand
    $global:UninstallCommandLine = $commands.UninstallCommand
}

function Process-Win32App {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Folder
    )

    $Prg = [PSCustomObject]@{
        id          = $Folder.Name
        name        = $Folder.Name
        Description = $Folder.Name
    }

    Write-EnhancedLog -Message "Program ID: $($Prg.id)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Program Name: $($Prg.name)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    Write-EnhancedLog -Message "Description: $($Prg.Description)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)

    if ($Prg.id -ne $Prg.name) {
        throw "Error: Program ID ('$($Prg.id)') does not match Program Name ('$($Prg.name)')."
    }

    Define-SourcePath -Prg $Prg
    Check-ApplicationImage -Prg $Prg

    $UploadWin32AppParams = @{
        Prg               = $Prg
        Prg_Path          = $global:Prg_Path
        Prg_img           = $global:Prg_img
        Win32AppsRootPath = $PSScriptRoot
        config            = $config
    }

    Upload-Win32App @UploadWin32AppParams
}

function Define-SourcePath {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Prg
    )

    $global:Prg_Path = Join-Path -Path $Repo_winget -ChildPath $Prg.id
    Write-EnhancedLog -Message "Source path defined: $global:Prg_Path" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
}

function Check-ApplicationImage {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Prg
    )

    $imagePath = Join-Path -Path $global:Prg_Path -ChildPath "$($Prg.id).png"
    if (Test-Path -Path $imagePath) {
        $global:Prg_img = $imagePath
    }
    else {
        $global:Prg_img = "$Repo_Path\resources\template\winget\winget-managed.png"
    }
}

# Retrieve all folder names in the specified directory
$folders = Get-ChildItem -Path $directoryPath -Directory

foreach ($folder in $folders) {
    Process-Folder -Folder $folder
}