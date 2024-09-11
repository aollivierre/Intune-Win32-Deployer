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


# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'dev', 'Machine')

# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-Host "Running in development mode" -ForegroundColor Yellow
        # Your development logic here
    }
    'prod' {
        Write-Host "Running in production mode" -ForegroundColor Green
        # Your production logic here
    }
    default {
        Write-Host "Unknown mode. Defaulting to production." -ForegroundColor Red
        # Default to production
    }
}

$mode = $env:EnvironmentMode

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

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

#endregion FIRING UP MODULE STARTER


#################################################################################################################################
################################################# START VARIABLES ###############################################################
#################################################################################################################################

# Read configuration from the JSON file
# Assign values from JSON to variables

# Read configuration from the JSON file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$env:MYMODULE_CONFIG_PATH = $configPath

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Read configuration from the JSON file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$env:MYMODULE_CONFIG_PATH = $configPath

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Assign values from JSON to variables
$PackageName = $config.PackageName
$PackageUniqueGUID = $config.PackageUniqueGUID
$Version = $config.Version
$PackageExecutionContext = $config.PackageExecutionContext
# $RepetitionInterval = $config.RepetitionInterval
$ScriptMode = $config.ScriptMode

#################################################################################################################################
################################################# END VARIABLES #################################################################
#################################################################################################################################


# ################################################################################################################################
# ############### CALLING AS SYSTEM to simulate Intune deployment as SYSTEM (Uncomment for debugging) ############################
# ################################################################################################################################

# Example usage
$privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
$PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"
$ScriptToRunAsSystem = $MyInvocation.MyCommand.Path

Ensure-RunningAsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem -TargetFolder $privateFolderPath


# ################################################################################################################################
# ################################################ END CALLING AS SYSTEM (Uncomment for debugging) ###############################
# ################################################################################################################################
    
    
#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################

# Define the variables to be used for the function
# $PSADTdownloadParams = @{
#     GithubRepository     = "psappdeploytoolkit/psappdeploytoolkit"
#     FilenamePatternMatch = "PSAppDeployToolkit*.zip"
#     ZipExtractionPath    = Join-Path "$PSScriptRoot\private" "PSAppDeployToolkit"
# }

# Call the function with the variables
# Download-PSAppDeployToolkit @PSADTdownloadParams



#################################################################################################################################
################################################# END DOWNLOADING PSADT #########################################################
#################################################################################################################################


###########################################################################################################################
#############################################STARTING THE MAIN SCHEDULED TASK LOGIC HERE###################################
###########################################################################################################################

$global:Path_local = Set-LocalPathBasedOnContext


Write-EnhancedLog -Message "calling Initialize-ScriptVariables" -Level "INFO"


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





# Assuming $global:Path_local and $global:Path_PR are set from previous initialization
Ensure-ScriptPathsExist -Path_local $global:Path_local -Path_PR $global:Path_PR

if (-not (Test-Path -Path $global:Path_PR -PathType Container)) {
    Write-EnhancedLog -Message "Failed to create $global:Path_PR. Please check permissions and path validity." -Level "ERROR"
}
else {
    Write-EnhancedLog -Message "$global:Path_PR exists." -Level "INFO"
}


# Copy-FilesToPath -DestinationPath $global:Path_PR
Copy-FilesToPath -SourcePath $PSScriptRoot -DestinationPath $global:Path_PR



# Assuming $global:Path_PR is set to your destination path and Write-EnhancedLog is defined
# Verify-CopyOperation -DestinationPath $global:Path_PR

Verify-CopyOperation -SourcePath $PSScriptRoot -DestinationPath $global:Path_PR

# Ensure the script runs with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-EnhancedLog -Message "Script requires administrative privileges to write to $Path_local." -Level "ERROR"
    exit
}

# Pre-defined paths
$Path_local = "C:\Program Files\_MEM"
$DataFolder = "Data"
$DataFolderPath = Join-Path -Path $Path_local -ChildPath $DataFolder

# Ensure the Data folder exists
if (-not (Test-Path -Path $DataFolderPath -PathType Container)) {
    New-Item -ItemType Directory -Path $DataFolderPath -Force | Out-Null
    Write-EnhancedLog -Message "Data folder created at $DataFolderPath" -Level "INFO"
}
else {
    Write-EnhancedLog -Message "Data folder already exists at $DataFolderPath" -Level "INFO"
}

# Then call Create-VBShiddenPS
$FileName = "run-ps-hidden.vbs"
try {
    $global:Path_VBShiddenPS = Create-VBShiddenPS -Path_local $Path_local -DataFolder $DataFolder -FileName $FileName
    # Validation of the VBScript file creation
    if (Test-Path -Path $global:Path_VBShiddenPS) {
        Write-EnhancedLog -Message "Validation successful: VBScript file exists at $global:Path_VBShiddenPS" -Level "INFO"
    }
    else {
        Write-EnhancedLog -Message "Validation failed: VBScript file does not exist at $global:Path_VBShiddenPS. Check script execution and permissions." -Level "WARNING"
    }
}
catch {
    Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR"
}




# Ensure global variables are initialized correctly beforehand

# Define the parameters in a hashtable using global variables, including ScriptMode
$CheckAndExecuteTaskparams = @{
    schtaskName             = $global:schtaskName
    Version                 = $global:Version
    Path_PR                 = $global:Path_PR
    ScriptMode              = $global:ScriptMode # Assuming you have this variable defined globally
    PackageExecutionContext = $global:PackageExecutionContext # Assuming you have this variable defined globally
}

# Call the function using splatting with dynamically set global variables
CheckAndExecuteTask @CheckAndExecuteTaskparams
