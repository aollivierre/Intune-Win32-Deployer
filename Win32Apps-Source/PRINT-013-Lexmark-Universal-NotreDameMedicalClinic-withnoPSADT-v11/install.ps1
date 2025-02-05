#Unique Tracking ID: 5e50240e-d376-4c47-9ea6-a4867768cf72, Timestamp: 2024-03-11 01:58:18

param(
    [Parameter(Mandatory=$true)]
    [string]$PrinterName,

    [Parameter(Mandatory=$true)]
    [string]$PrinterIPAddress,

    [Parameter(Mandatory=$true)]
    [string]$PortName,

    [Parameter(Mandatory=$true)]
    [string]$DriverName,

    [Parameter(Mandatory=$true)]
    [string]$InfPathRelative,

    [Parameter(Mandatory=$true)]
    [string]$InfFileName,

    [Parameter(Mandatory=$true)]
    [string]$DriverIdentifier
)

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

# Read configuration from the JSON file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$env:MYMODULE_CONFIG_PATH = $configPath

# $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Assign values from JSON to variables
# $PackageName = $config.PackageName
# $PackageUniqueGUID = $config.PackageUniqueGUID
# $Version = $config.Version
# $PackageExecutionContext = $config.PackageExecutionContext
# $RepetitionInterval = $config.RepetitionInterval
# $ScriptMode = $config.ScriptMode




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

function Get-PrivateScriptPathsAndVariables {
    param (
        [string]$BaseDirectory
    )

    try {
        $privateFolderPath = Join-Path -Path $BaseDirectory -ChildPath "private"
        
        if (-not (Test-Path -Path $privateFolderPath)) {
            throw "Private folder path does not exist: $privateFolderPath"
        }

        # Construct and return a PSCustomObject
        return [PSCustomObject]@{
            BaseDirectory     = $BaseDirectory
            PrivateFolderPath = $privateFolderPath
        }
    }
    catch {
        Write-Host "Error in finding private script files: $_" -ForegroundColor Red
        # Optionally, you could return a PSCustomObject indicating an error state
        # return [PSCustomObject]@{ Error = $_.Exception.Message }
    }
}



# Retrieve script paths and related variables
$DotSourcinginitializationInfo = Get-PrivateScriptPathsAndVariables -BaseDirectory $PSScriptRoot

# $DotSourcinginitializationInfo
$DotSourcinginitializationInfo | Format-List


# Build the path to the module dynamically
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "Private\EnhancedLoggingAO\1.5.0\EnhancedLoggingAO.psm1"

# Import the module using the dynamically built path
Import-Module $modulePath


# ################################################################################################################################
# ################################################ END MODULE LOADING ############################################################
# ################################################################################################################################



function Ensure-LoggingFunctionExists {
    if (Get-Command Write-EnhancedLog -ErrorAction SilentlyContinue) {
        Write-EnhancedLog -Message "Logging works" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }
    else {
        throw "Write-EnhancedLog function not found. Terminating script."
    }
}

# Usage
try {
    Ensure-LoggingFunctionExists
    # Continue with the rest of the script here
    # exit
}
catch {
    Write-Host "Critical error: $_" -ForegroundColor Red
    exit
}


# ################################################################################################################################
# ################################################ END MODULE CHECKING ###########################################################
# ################################################################################################################################



function Test-RunningAsSystem {
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18"
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User

    return $currentSid -eq $systemSid
}

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
function CheckAndElevate {
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

            Write-EnhancedLog -Message "Checking for administrative privileges..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Blue)
        } catch {
            Write-EnhancedLog -Message "Error determining administrative status: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
            throw $_
        }
    }

    process {
        if (-not $isAdmin) {
            try {
                Write-EnhancedLog -Message "The script is not running with administrative privileges. Attempting to elevate..." -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
                
                $arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" $args"
                Start-Process PowerShell -Verb RunAs -ArgumentList $arguments

                # Invoke-AsSystem -PsExec64Path $PsExec64Path
                
                Write-EnhancedLog -Message "Script re-launched with administrative privileges. Exiting current session." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
                exit
            } catch {
                Write-EnhancedLog -Message "Failed to elevate privileges: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $_
            }
        } else {
            Write-EnhancedLog -Message "Script is already running with administrative privileges." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
    }

    end {
        # This block is typically used for cleanup. In this case, there's nothing to clean up,
        # but it's useful to know about this structure for more complex functions.
    }
}



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

function Invoke-AsSystem {
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
        Write-EnhancedLog -Message "Preparing to execute PowerShell as SYSTEM using PsExec64 with the script: $ScriptPathAsSYSTEM" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }

    process {
        try {
            # Ensure PsExec64Path exists
            if (-not (Test-Path -Path $PsExec64Path)) {
                $errorMessage = "PsExec64.exe not found at path: $PsExec64Path"
                Write-EnhancedLog -Message $errorMessage -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $errorMessage
            }

            # Run PsExec64.exe with the defined arguments to execute the script as SYSTEM
            $executingMessage = "Executing PsExec64.exe to start PowerShell as SYSTEM running script: $ScriptPathAsSYSTEM"
            Write-EnhancedLog -Message $executingMessage -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            Start-Process -FilePath "$PsExec64Path" -ArgumentList $argList -Wait -NoNewWindow
        }
        catch {
            Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
        }
    }
}




# Assuming Invoke-AsSystem and Write-EnhancedLog are already defined
# Update the path to your actual location of PsExec64.exe
$privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
$PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

if (-not (Test-RunningAsSystem)) {
    Write-EnhancedLog -Message "Current session is not running as SYSTEM. Attempting to invoke as SYSTEM..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)

    $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
    Invoke-AsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem

} else {
    Write-EnhancedLog -Message "Session is already running as SYSTEM." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
}
    
#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################

       <#
.SYNOPSIS
    Installs a printer driver, creates a printer port, and adds a printer with specified settings, and imports a certificate into TrustedPublisher stores.

.DESCRIPTION
    This function automates the process of installing a printer driver, creating a printer port based on the provided IP address, and adding a printer with the specified name and settings. Additionally, it imports a specified certificate into both the Local Machine and Current User TrustedPublisher stores to ensure the printer driver is trusted. It checks for the existence of the printer driver, port, and printer itself, adding or replacing them as necessary. This function is ideal for setting up printers in a scripted, automated manner, ensuring that the necessary security certificates are in place.

.NOTES
    Version: 1.0
    Author: Abdullah Ollivierre
    Creation Date: 2024-Feb-13
    Last Modified: 2024-Feb-13
    Changes Log:
        1.0 - Initial version with capabilities to install printer drivers, create printer ports, add printers, and import certificates into TrustedPublisher stores.

.LINK
    https://call4cloud.nl/2021/07/what-about-printer-drivers/
    https://anthonyfontanez.com/index.php/2023/12/30/importing-certificates-with-remediations/


.EXAMPLE
    $PrinterName = "SHARP Concorde"
    $PrinterIPAddress = "192.168.53.151"
    $DriverName = "SHARP MX-4071 PCL6"
    $InfPathRelativeToscriptDirectory = "Driver\su2emenu.inf"
    $CertificatePathRelativeToscriptDirectory = "Path\To\Certificate\cert_name.cer"

    Install-PrinterAndCert -PrinterName $PrinterName -PrinterIPAddress $PrinterIPAddress -DriverName $DriverName -InfPathRelativeToscriptDirectory $InfPathRelativeToscriptDirectory -CertificatePathRelativeToscriptDirectory $CertificatePathRelativeToscriptDirectory

    This example sets up a printer named 'SHARP Concord' using the 'SHARP MX-4071 PCL6' driver and the specified IP address. It imports a certificate from the specified path into the TrustedPublisher stores.
#>



<#
.SYNOPSIS
Initializes and validates paths for the printer driver and certificate files, and constructs the printer port name.

.DESCRIPTION
This function prepares the environment for printer installation by constructing the full paths to the INF file and certificate based on the script directory. It also generates the port name based on the printer's IP address. This setup is essential for the subsequent steps of the printer installation process.

.PARAMETER InfPathRelativeToscriptDirectory
The relative path to the INF file from the script directory.

.PARAMETER CertificatePathRelativeToscriptDirectory
The relative path to the certificate file from the script directory.

.PARAMETER PrinterIPAddress
The IP address of the printer, used to construct the port name.

.PARAMETER ScriptDirectory
The directory where the script is located, used as the base for constructing full paths to the INF and certificate files.

.OUTPUTS
Custom object with properties for InfPath, CertPath, and PortName, ready for use in printer installation tasks.

.EXAMPLE
$initializationResult = Initialize-PrinterInstallationVariables -InfPathRelativeToscriptDirectory "Driver\su2emenu.inf" -CertificatePathRelativeToscriptDirectory "sharp.cer" -PrinterIPAddress "192.168.1.100" -ScriptDirectory $scriptDirectory

Initializes the paths and port name for the printer installation process.
#>

function Initialize-PrinterInstallationVariables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InfPathRelativeToscriptDirectory,

        # [Parameter(Mandatory = $true)]
        # [string]$CertificatePathRelativeToscriptDirectory,

        [Parameter(Mandatory = $true)]
        [string]$PrinterIPAddress

        # [Parameter(Mandatory = $true)]
        # [string]$ScriptDirectory
    )

    # $InfPath = Join-Path -Path $ScriptDirectory -ChildPath $InfPathRelativeToscriptDirectory
    $InfPath = Join-Path -Path $PSScriptRoot -ChildPath $InfPathRelativeToscriptDirectory
    # $CertPath = Join-Path -Path $ScriptDirectory -ChildPath $CertificatePathRelativeToscriptDirectory
    $PortName = "IP_$PrinterIPAddress"

    # Return an object with the initialized variables
    return [PSCustomObject]@{
        InfPath = $InfPath
        CertPath = $CertPath
        PortName = $PortName
    }
}




<#
.SYNOPSIS
Imports a certificate for the printer installation process.

.DESCRIPTION
This function imports a specified certificate file into the Trusted Publisher stores of both the Local Machine and Current User. This step is critical for allowing the installation of printer drivers that require signed drivers, especially in environments with strict security policies.

.PARAMETER CertPath
The full path to the certificate file that needs to be imported.

.OUTPUTS
None. This function performs actions but does not return any output. It logs success or failure of the certificate importation process.

.EXAMPLE
Import-PrinterCertificate -CertPath "C:\PrinterInstall\sharp.cer"

Imports the specified certificate into the Trusted Publisher certificate stores of the Local Machine and Current User.
#>

# function Import-PrinterCertificate {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory = $true)]
#         [string]$CertPath
#     )

#     Write-EnhancedLog -Message "Checking certificate file at path: $CertPath" -Level "INFO" -ForegroundColor Green
    
#     # Check if the certificate file exists
#     if (Test-Path -Path $CertPath) {
#         Write-EnhancedLog -Message "Certificate file found. Proceeding with import..." -Level "INFO" -ForegroundColor Green
#         try {
#             Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
#             Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\CurrentUser\TrustedPublisher
#             Write-EnhancedLog -Message "Certificate imported successfully into both LocalMachine and CurrentUser stores." -Level "INFO" -ForegroundColor Green
#         }
#         catch {
#             Write-EnhancedLog -Message "Failed to import certificate. Error: $_" -Level "ERROR" -ForegroundColor Red
#         }
#     }
#     else {
#         Write-EnhancedLog -Message "Certificate file does not exist at the specified path: $CertPath" -Level "ERROR" -ForegroundColor Red
#     }
# }





<#
.SYNOPSIS
Installs the printer driver from a specified INF file.

.DESCRIPTION
This function checks for the existence of the specified INF file and whether the printer driver is already installed. If the driver is not found, it proceeds with the installation using the INF file. This process is crucial for setting up printers that require specific drivers not included with the operating system.

.PARAMETER InfPath
The full path to the printer driver's INF file.

.PARAMETER DriverName
The name of the printer driver to check for and install.

.OUTPUTS
None. This function performs actions but does not return any output. It logs the progress and outcome of the driver installation process.

.EXAMPLE
Install-PrinterDriver -InfPath "C:\PrinterInstall\Driver\su2emenu.inf" -DriverName "SHARP MX-3071 PCL6"

Checks for the SHARP MX-3071 PCL6 driver and installs it using the specified INF file if it's not already installed.
#>

function Install-PrinterDriver {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InfPath,

        [Parameter(Mandatory = $true)]
        [string]$DriverName
    )

    Write-EnhancedLog -Message "Checking INF file at path: $InfPath" -Level "INFO" -ForegroundColor Green

    if (Test-Path -Path $InfPath) {
        Write-EnhancedLog -Message "INF file found. Verifying driver installation status..." -Level "INFO" -ForegroundColor Green
        $DriverExists = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
        if (-not $DriverExists) {
            try {
                Write-EnhancedLog -Message "Driver $DriverName not found. Proceeding with installation." -Level "INFO" -ForegroundColor Green
                pnputil.exe /add-driver $InfPath /install
                Add-PrinterDriver -Name $DriverName
                Write-EnhancedLog -Message "Printer driver $DriverName installed successfully." -Level "INFO" -ForegroundColor Green
            }
            catch {
                Write-EnhancedLog -Message "Failed to install printer driver $DriverName. Error: $_" -Level "ERROR" -ForegroundColor Red
            }
        }
        else {
            Write-EnhancedLog -Message "Printer driver $DriverName already exists. Skipping installation." -Level "INFO" -ForegroundColor Yellow
        }
    }
    else {
        Write-EnhancedLog -Message "INF file does not exist at the specified path: $InfPath" -Level "ERROR" -ForegroundColor Red
    }
}




<#
.SYNOPSIS
Adds or verifies a printer port for a network printer based on the IP address.

.DESCRIPTION
This function checks for the existence of a printer port named after the printer's IP address. If the port does not exist, the function creates it. This step is essential for network printer installations where communication is over a specific IP address.

.PARAMETER PortName
The name of the printer port, typically derived from the printer's IP address.

.PARAMETER PrinterIPAddress
The IP address of the printer, used to create the port if it does not exist.

.OUTPUTS
None. This function performs actions but does not return any output. It logs the status of the printer port creation or existence verification.

.EXAMPLE
Configure-PrinterPort -PortName "IP_192.168.1.100" -PrinterIPAddress "192.168.1.100"

Checks for the existence of a printer port for the IP address 192.168.1.100 and adds it if it does not exist.
#>

function Configure-PrinterPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PortName,

        [Parameter(Mandatory = $true)]
        [string]$PrinterIPAddress
    )

    Write-EnhancedLog -Message "Checking for existence of printer port $PortName" -Level "INFO" -ForegroundColor Green

    $PortExists = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
    if (-not $PortExists) {
        try {
            Write-EnhancedLog -Message "Printer port $PortName does not exist. Adding new port for IP address $PrinterIPAddress." -Level "INFO" -ForegroundColor Green
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterIPAddress
            Write-EnhancedLog -Message "Printer port $PortName added successfully." -Level "INFO" -ForegroundColor Green
        }
        catch {
            Write-EnhancedLog -Message "Failed to add printer port $PortName. Error: $_" -Level "ERROR" -ForegroundColor Red
        }
    }
    else {
        Write-EnhancedLog -Message "Printer port $PortName already exists. No action needed." -Level "INFO" -ForegroundColor Yellow
    }
}




<#
.SYNOPSIS
Adds a new printer or updates an existing one with the specified configuration.

.DESCRIPTION
This function checks if a printer with the given name already exists on the system. If it does, the existing printer is removed, and a new one is added with the specified configuration. If the printer does not exist, it is simply added. This ensures the printer is set up with the correct driver and port settings.

.PARAMETER PrinterName
The name of the printer to be added or updated.

.PARAMETER DriverName
The name of the printer driver to be used.

.PARAMETER PortName
The name of the printer port to be used, typically associated with the printer's IP address.

.OUTPUTS
None. This function performs actions but does not return any output. It logs the outcome of the printer addition or update process.

.EXAMPLE
AddOrUpdatePrinter -PrinterName "SHARP MX-3071" -DriverName "SHARP MX-3071 PCL6" -PortName "IP_192.168.1.100"

Adds or updates the SHARP MX-3071 printer with the specified driver and port.
#>

function AddOrUpdatePrinter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,

        [Parameter(Mandatory = $true)]
        [string]$DriverName,

        [Parameter(Mandatory = $true)]
        [string]$PortName
    )

    Write-EnhancedLog -Message "Checking for existing printer: $PrinterName" -Level "INFO" -ForegroundColor Green

    $PrinterExists = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($PrinterExists) {
        Write-EnhancedLog -Message "Printer $PrinterName already exists. Removing existing printer to update configuration." -Level "INFO" -ForegroundColor Yellow
        Remove-Printer -Name $PrinterName
    }
    
    try {
        Write-EnhancedLog -Message "Adding printer $PrinterName with driver $DriverName on port $PortName." -Level "INFO" -ForegroundColor Green
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName
        Write-EnhancedLog -Message "Printer $PrinterName added or updated successfully." -Level "INFO" -ForegroundColor Green
    }
    catch {
        Write-EnhancedLog -Message "Failed to add or update printer $PrinterName. Error: $_" -Level "ERROR" -ForegroundColor Red
    }
}

# Determine the directory where the script is located
# $scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Define the path to the printer configuration JSON file
# $printerConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "printer.json"

# Read configuration from the JSON file
# $printerConfig = Get-Content -Path $printerConfigPath -Raw | ConvertFrom-Json

# Assign values from JSON to variables
# $PrinterName = $printerConfig.PrinterName
# $PrinterIPAddress = $printerConfig.PrinterIPAddress
# $DriverName = $printerConfig.DriverName
# $InfPathRelative = $printerConfig.InfPathRelative

# Use the variables as needed in your script


# Step 1: Initialize Variables using splatting
$params = @{
    InfPathRelativeToscriptDirectory = $InfPathRelative
    # CertificatePathRelativeToscriptDirectory = $CertificatePathRelative
    PrinterIPAddress = $PrinterIPAddress
    # ScriptDirectory = $scriptDirectory
}

$initializationResult = Initialize-PrinterInstallationVariables @params


# Extracting specific variables from the initialization output
$InfPath = $initializationResult.InfPath
$CertPath = $initializationResult.CertPath
$PortName = $initializationResult.PortName

# Step 2: Import Certificate
# Import-PrinterCertificate -CertPath $CertPath

# Step 3: Install Printer Driver
Install-PrinterDriver -InfPath $InfPath -DriverName $DriverName

# Step 4: Configure Printer Port
Configure-PrinterPort -PortName $PortName -PrinterIPAddress $PrinterIPAddress

# Step 5: Add or Update Printer
AddOrUpdatePrinter -PrinterName $PrinterName -DriverName $DriverName -PortName $PortName

# Optionally, add any completion message or further steps
Write-EnhancedLog -Message "Printer installation and configuration completed successfully." -Level "INFO" -ForegroundColor Green
