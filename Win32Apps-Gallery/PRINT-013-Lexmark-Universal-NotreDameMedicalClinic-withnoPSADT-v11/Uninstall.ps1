#Unique Tracking ID: eb934004-9280-4ed1-8c21-a7c345802f61, Timestamp: 2024-03-11 01:58:18

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


<#
.SYNOPSIS
Removes a specified printer.

.DESCRIPTION
This function removes the printer with the given name if it exists.

.PARAMETER PrinterName
The name of the printer to be removed.

.EXAMPLE
Remove-PrinterByName -PrinterName "HP LaserJet P3015 - Finance - New"
#>
function Remove-PrinterByName {
    param (
        [Parameter(Mandatory=$true)]
        [string]$PrinterName
    )

    try {
        if (Get-Printer -Name $PrinterName -ErrorAction Stop) {
            Remove-Printer -Name $PrinterName -Confirm:$false
            Write-EnhancedLog -Message "Printer '$PrinterName' removed." -Level "INFO" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-EnhancedLog -Message "Failed to remove printer '$PrinterName': $_" -Level "ERROR" -ForegroundColor Red
    }
}


<#
.SYNOPSIS
Removes a specified printer port.

.DESCRIPTION
This function removes the printer port with the given name if it exists.

.PARAMETER PortName
The name of the printer port to be removed.

.EXAMPLE
Remove-PrinterPortByName -PortName "IP_192.168.53.20"
#>
function Remove-PrinterPortByName {
    param (
        [Parameter(Mandatory=$true)]
        [string]$PortName
    )

    try {
        $portExists = Get-PrinterPort -Name $PortName -ErrorAction Stop
        if ($portExists) {
            Remove-PrinterPort -Name $PortName -Confirm:$false
            Write-EnhancedLog -Message "Printer port '$PortName' removed." -Level "INFO" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-EnhancedLog -Message "Failed to remove printer port '$PortName': $_" -Level "ERROR" -ForegroundColor Red
    }
}



<#
.SYNOPSIS
Loads printer configuration from a JSON file.

.DESCRIPTION
This function reads the printer configuration from a specified JSON file and returns it as a custom object.

.PARAMETER ConfigPath
The path to the JSON configuration file.

.EXAMPLE
$printerConfig = Get-PrinterConfig -ConfigPath "printer.json"
#>
function Get-PrinterConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath
    )

    try {
        if (Test-Path -Path $ConfigPath) {
            $configContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            return $configContent
        } else {
            Write-EnhancedLog -Message "Configuration file not found at path: $ConfigPath" -Level "ERROR" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-EnhancedLog -Message "Failed to read configuration file: $_" -Level "ERROR" -ForegroundColor Red
        return $null
    }
}



# Set the path to your configuration file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "printer.json"

# Load the printer configuration
$printerConfig = Get-PrinterConfig -ConfigPath $configPath

if ($null -ne $printerConfig) {
    # Remove the printer and printer port based on the loaded configuration
    Remove-PrinterByName -PrinterName $printerConfig.PrinterName
    Remove-PrinterPortByName -PortName $printerConfig.PortName
}