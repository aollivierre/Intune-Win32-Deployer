#Unique Tracking ID: cbb2948f-1a2f-4646-a8e0-663716e96b69, Timestamp: 2024-03-20 11:53:02
# JSON string
$json = @'
{
    "PrinterName": "Lexamrk Front Desk - Notre Dame Medical Clinic",
    "PrinterIPAddress": "192.168.2.79",
    "PortName": "IP_192.168.2.79",
    "DriverName": "Lexmark Universal v2",
    "InfPathRelative": "Driver\\LMUD1n40.inf",
    "InfFileName": "LMUD1n40.inf",
    "DriverIdentifier": "amd64_51d0ca74e641a8db"
}
'@

# Convert JSON string to a PowerShell object
$Config = $json | ConvertFrom-Json


# Assign values from JSON to variables
# $PackageName = $config.PackageName
# $PackageUniqueGUID = $config.PackageUniqueGUID
# $Version = $config.Version
# $ScriptMode = $config.ScriptMode


# Assign values from JSON to variables
$LoggingDeploymentName = $config.LoggingDeploymentName
    
function Initialize-ScriptAndLogging {
    $ErrorActionPreference = 'SilentlyContinue'
    $deploymentName = "$LoggingDeploymentName" # Replace this with your actual deployment name
    $scriptPath = "C:\code\$deploymentName"
    # $hadError = $false
    
    try {
        if (-not (Test-Path -Path $scriptPath)) {
            New-Item -ItemType Directory -Path $scriptPath -Force | Out-Null
            Write-Host "Created directory: $scriptPath"
        }
    
        $computerName = $env:COMPUTERNAME
        $Filename = "$LoggingDeploymentName"
        $logDir = Join-Path -Path $scriptPath -ChildPath "exports\Logs\$computerName"
        $logPath = Join-Path -Path $logDir -ChildPath "$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')"
            
        if (!(Test-Path $logPath)) {
            Write-Host "Did not find log file at $logPath" -ForegroundColor Yellow
            Write-Host "Creating log file at $logPath" -ForegroundColor Yellow
            $createdLogDir = New-Item -ItemType Directory -Path $logPath -Force -ErrorAction Stop
            Write-Host "Created log file at $logPath" -ForegroundColor Green
        }
            
        $logFile = Join-Path -Path $logPath -ChildPath "$Filename-Transcript.log"
        Start-Transcript -Path $logFile -ErrorAction Stop | Out-Null
    
        $CSVDir = Join-Path -Path $scriptPath -ChildPath "exports\CSV"
        $CSVFilePath = Join-Path -Path $CSVDir -ChildPath "$computerName"
            
        if (!(Test-Path $CSVFilePath)) {
            Write-Host "Did not find CSV file at $CSVFilePath" -ForegroundColor Yellow
            Write-Host "Creating CSV file at $CSVFilePath" -ForegroundColor Yellow
            $createdCSVDir = New-Item -ItemType Directory -Path $CSVFilePath -Force -ErrorAction Stop
            Write-Host "Created CSV file at $CSVFilePath" -ForegroundColor Green
        }
    
        return @{
            ScriptPath  = $scriptPath
            Filename    = $Filename
            LogPath     = $logPath
            LogFile     = $logFile
            CSVFilePath = $CSVFilePath
        }
    
    }
    catch {
        Write-Error "An error occurred while initializing script and logging: $_"
    }
}
$initializationInfo = Initialize-ScriptAndLogging
    
    
    
# Script Execution and Variable Assignment
# After the function Initialize-ScriptAndLogging is called, its return values (in the form of a hashtable) are stored in the variable $initializationInfo.
    
# Then, individual elements of this hashtable are extracted into separate variables for ease of use:
    
# $ScriptPath: The path of the script's main directory.
# $Filename: The base name used for log files.
# $logPath: The full path of the directory where logs are stored.
# $logFile: The full path of the transcript log file.
# $CSVFilePath: The path of the directory where CSV files are stored.
# This structure allows the script to have a clear organization regarding where logs and other files are stored, making it easier to manage and maintain, especially for logging purposes. It also encapsulates the setup logic in a function, making the main script cleaner and more focused on its primary tasks.
    
    
$ScriptPath = $initializationInfo['ScriptPath']
$Filename = $initializationInfo['Filename']
$logPath = $initializationInfo['LogPath']
$logFile = $initializationInfo['LogFile']
$CSVFilePath = $initializationInfo['CSVFilePath']
    
    
    
    
function AppendCSVLog {
    param (
        [string]$Message,
        [string]$CSVFilePath
           
    )
    
    $csvData = [PSCustomObject]@{
        TimeStamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Message      = $Message
    }
    
    $csvData | Export-Csv -Path $CSVFilePath -Append -NoTypeInformation -Force
}
    
    
    
function CreateEventSourceAndLog {
    param (
        [string]$LogName,
        [string]$EventSource
    )
    
    
    # Validate parameters
    if (-not $LogName) {
        Write-Warning "LogName is required."
        return
    }
    if (-not $EventSource) {
        Write-Warning "Source is required."
        return
    }
    
    # Function to create event log and source
    function CreateEventLogSource($logName, $EventSource) {
        try {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                New-EventLog -LogName $logName -Source $EventSource
            }
            else {
                [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $logName)
            }
            Write-Host "Event source '$EventSource' created in log '$logName'" -ForegroundColor Green
        }
        catch {
            Write-Warning "Error creating the event log. Make sure you run PowerShell as an Administrator."
        }
    }
    
    # Check if the event log exists
    if (-not (Get-WinEvent -ListLog $LogName -ErrorAction SilentlyContinue)) {
        # CreateEventLogSource $LogName $EventSource
    }
    # Check if the event source exists
    elseif (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
        # Unregister the source if it's registered with a different log
        $existingLogName = (Get-WinEvent -ListLog * | Where-Object { $_.LogName -contains $EventSource }).LogName
        if ($existingLogName -ne $LogName) {
            Remove-EventLog -Source $EventSource -ErrorAction SilentlyContinue
        }
        # CreateEventLogSource $LogName $EventSource
    }
    else {
        Write-Host "Event source '$EventSource' already exists in log '$LogName'" -ForegroundColor Yellow
    }
}
    
$LogName = (Get-Date -Format "HHmmss") + "_$LoggingDeploymentName"
$EventSource = (Get-Date -Format "HHmmss") + "_$LoggingDeploymentName"
    
# Call the Create-EventSourceAndLog function
CreateEventSourceAndLog -LogName $LogName -EventSource $EventSource
    
# Call the Write-CustomEventLog function with custom parameters and level
# Write-CustomEventLog -LogName $LogName -EventSource $EventSource -EventMessage "Outlook Signature Restore completed with warnings." -EventID 1001 -Level 'WARNING'
    
    
    
    
function Write-EventLogMessage {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
    
        [string]$LogName = "$LoggingDeploymentName",
        [string]$EventSource,
    
        [int]$EventID = 1000  # Default event ID
    )
    
    $ErrorActionPreference = 'SilentlyContinue'
    $hadError = $false
    
    try {
        if (-not $EventSource) {
            throw "EventSource is required."
        }
    
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            # PowerShell version is less than 6, use Write-EventLog
            Write-EventLog -LogName $logName -Source $EventSource -EntryType Information -EventId $EventID -Message $Message
        }
        else {
            # PowerShell version is 6 or greater, use System.Diagnostics.EventLog
            $eventLog = New-Object System.Diagnostics.EventLog($logName)
            $eventLog.Source = $EventSource
            $eventLog.WriteEntry($Message, [System.Diagnostics.EventLogEntryType]::Information, $EventID)
        }
    
        # Write-host "Event log entry created: $Message" 
    }
    catch {
        Write-host "Error creating event log entry: $_" 
        $hadError = $true
    }
    
    if (-not $hadError) {
        # Write-host "Event log message writing completed successfully."
    }
}
    
    
    
    
function Write-EnhancedLog {
    param (
        [string]$Message,
        [string]$Level = 'INFO',
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [string]$CSVFilePath = "$scriptPath\exports\CSV\$(Get-Date -Format 'yyyy-MM-dd')-Log.csv",
        [string]$CentralCSVFilePath = "$scriptPath\exports\CSV\$Filename.csv",
        [switch]$UseModule = $false,
        [string]$Caller = (Get-PSCallStack)[0].Command
    )
    
    # Add timestamp, computer name, and log level to the message
    $formattedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $($env:COMPUTERNAME): [$Level] [$Caller] $Message"
    
    # Set foreground color based on log level
    switch ($Level) {
        'INFO' { $ForegroundColor = [ConsoleColor]::Green }
        'WARNING' { $ForegroundColor = [ConsoleColor]::Yellow }
        'ERROR' { $ForegroundColor = [ConsoleColor]::Red }
    }
    
    # Write the message with the specified colors
    $currentForegroundColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $ForegroundColor
    # Write-output $formattedMessage
    Write-host $formattedMessage
    $Host.UI.RawUI.ForegroundColor = $currentForegroundColor
    
    # Append to CSV file
    AppendCSVLog -Message $formattedMessage -CSVFilePath $CSVFilePath
    AppendCSVLog -Message $formattedMessage -CSVFilePath $CentralCSVFilePath
    
    # Write to event log (optional)
    # Write-CustomEventLog -EventMessage $formattedMessage -Level $Level

    
    # Adjust this line in your script where you call the function
    # Write-EventLogMessage -LogName $LogName -EventSource $EventSource -Message $formattedMessage -EventID 1001
    
}
    
function Export-EventLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName,
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )
    
    try {
        wevtutil epl $LogName $ExportPath
    
        if (Test-Path $ExportPath) {
            Write-EnhancedLog -Message "Event log '$LogName' exported to '$ExportPath'" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
        else {
            Write-EnhancedLog -Message "Event log '$LogName' not exported: File does not exist at '$ExportPath'" -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
        }
    }
    catch {
        Write-EnhancedLog -Message "Error exporting event log '$LogName': $($_.Exception.Message)" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
    }
}
    
# # Example usage
# $LogName = '$LoggingDeploymentNameLog'
# # $ExportPath = 'Path\to\your\exported\eventlog.evtx'
# $ExportPath = "C:\code\$LoggingDeploymentName\exports\Logs\$logname.evtx"
# Export-EventLog -LogName $LogName -ExportPath $ExportPath
    
    
    
    
    
    
#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################
    
    
    
Write-EnhancedLog -Message "Logging works" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)

#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################
    


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
        }
        catch {
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
            }
            catch {
                Write-EnhancedLog -Message "Failed to elevate privileges: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $_
            }
        }
        else {
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
            
            Write-EnhancedLog -Message "SYSTEM session started. Closing elevated session..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            exit

        }
        catch {
            Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
        }
    }
}




# Assuming Invoke-AsSystem and Write-EnhancedLog are already defined
# Update the path to your actual location of PsExec64.exe

Write-EnhancedLog -Message "calling Test-RunningAsSystem" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
if (-not (Test-RunningAsSystem)) {
    $privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
    $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

    Write-EnhancedLog -Message "Current session is not running as SYSTEM. Attempting to invoke as SYSTEM..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)

    $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
    Invoke-AsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem

}
else {
    Write-EnhancedLog -Message "Session is already running as SYSTEM." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
}













#Unique Tracking ID: 9eb1d606-3de1-4ceb-b4ee-718a69e7d01b, Timestamp: 2024-03-11 01:58:18

# Convert JSON string to a PowerShell object
# $Config = $json | ConvertFrom-Json


function AOCheckCertificatePrinterPortAndDriver {

    param(
        # [Parameter(Mandatory)]
        # [string]$CertificateThumbprint,
        
        [Parameter(Mandatory)]
        [string]$PrinterName,
        
        [Parameter(Mandatory)]
        [string]$PrinterDriverName,
        
        [Parameter(Mandatory)]  
        [string]$PrinterIPAddress,

        [Parameter(Mandatory)]  
        [string]$InfFileName,

        [Parameter(Mandatory)]
        [string]$DriverIdentifier  # New parameter
    )


    # $certificateExists = $false
    $printerExists = $false 
    $portExists = $false
    $driverExists = $false
    $driverStoreExists = $false
    # $spoolDriverExists = $false

    # $certificateStorePath = "Cert:\LocalMachine\TrustedPublisher\$CertificateThumbprint"
    $printerRegistryKeyPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Print\Printers\$PrinterName"
    # $driverStorePath = "C:\Windows\System32\DriverStore\FileRepository\$InfFileName`_amd64_634bca3944391527"
    # $spoolDriverPath = "C:\Windows\System32\spool\drivers\x64\PCC\$InfFileName`_amd64_634bca3944391527.cab"

    $driverStorePath = "C:\Windows\System32\DriverStore\FileRepository\$InfFileName`_$DriverIdentifier"
    # $spoolDriverPath = "C:\Windows\System32\spool\drivers\x64\PCC\$InfFileName`_$DriverIdentifier.cab"



    if (Test-Path -Path $driverStorePath) {
        $driverStoreExists = $true
    }
    
    # if (Test-Path -Path $spoolDriverPath) {
    #     $spoolDriverExists = $true
    # }


    # Check for Certificate existence
    # if (Test-Path -Path $certificateStorePath) {
        # $certificateExists = $true
    # }
    # else {
        # Write-Host "Certificate with thumbprint '$CertificateThumbprint' does not exist in TrustedPublisher store."
    # }

    # Check for Printer existence
    try {
        $printerProperty = Get-ItemProperty -Path $printerRegistryKeyPath -Name "Name" -ErrorAction Stop
        
        if ($printerProperty.Name -eq $PrinterName) {
            $printerExists = $true

            $portName = "IP_$PrinterIPAddress"
    
            # Check if printer port exists
            $port = Get-PrinterPort -Name $portName
            if ($port) {
                $portExists = $true 
            }   
   
            # Check if printer driver exists
            $driver = Get-PrinterDriver -Name $PrinterDriverName
            if ($driver) {
                $driverExists = $true
            }
        }
        else {
            # Write-Host "Printer '$PrinterName' not detected."
        }
    }
    catch {
        # Write-Host "Error accessing registry to check for printer: $\_"
    }

    # Check if Certificate, Printer, Port and Drivers exist
    # Final check
    # if ($certificateExists -and $printerExists -and $portExists -and $driverExists -and $driverStoreExists -and $spoolDriverExists) {
    # if ($printerExists -and $portExists -and $driverExists -and $driverStoreExists -and $spoolDriverExists) {
    if ($printerExists -and $portExists -and $driverExists -and $driverStoreExists) {
      
        # Write-Host "Certificate, Printer, Port and Drivers detected successfully."
        Write-Host "Printer, Port and Drivers detected successfully."
        exit 0
    }
    else {
        # Uncomment below to display message when any component is missing
        # Write-Host "One or more components not detected." 
        exit 1
    }
}


# Usage

# $params = @{
#     # CertificateThumbprint = 'F6E9917F79C80297197F3DC35D1909565BB423CD'
#     PrinterName           = "HP LaserJet P3015 - Finance - New"  
#     PrinterDriverName     = "HP Universal Printing PCL 6"
#     PrinterIPAddress      = "192.168.53.20"
#     InfFileName           = "hpcu270u.inf"
# }
 
# AOCheckCertificatePrinterPortAndDriver @params





# Determine the directory where the script is located
# $scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Define the path to the printer setup configuration JSON file
# $printerSetupConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "printer.json"

# Read configuration from the JSON file
# $printerSetupConfig = Get-Content -Path $printerSetupConfigPath -Raw | ConvertFrom-Json




# # Convert the configuration into a hashtable suitable for splatting
# $params = @{
#     PrinterName       = $printerSetupConfig.PrinterName
#     PrinterDriverName = $printerSetupConfig.DriverName
#     PrinterIPAddress  = $printerSetupConfig.PrinterIPAddress
#     InfFileName       = $printerSetupConfig.InfFileName
# }

# # Optional: Add CertificateThumbprint to $params if needed
# # If your JSON file contains a CertificateThumbprint, uncomment the following line
# # $params.CertificateThumbprint = $printerSetupConfig.CertificateThumbprint

# # Call the function with parameters using splatting
# AOCheckCertificatePrinterPortAndDriver @params




# Define the path to the printer setup configuration JSON file
# $printerSetupConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "printer.json"


# # Convert JSON string to a PowerShell object
$printerSetupConfig = $json | ConvertFrom-Json

# Read configuration from the JSON file
# $printerSetupConfig = Get-Content -Path $printerSetupConfigPath -Raw | ConvertFrom-Json

# Convert the configuration into a hashtable suitable for splatting
$params = @{
    PrinterName       = $printerSetupConfig.PrinterName
    PrinterDriverName = $printerSetupConfig.DriverName
    PrinterIPAddress  = $printerSetupConfig.PrinterIPAddress
    InfFileName       = $printerSetupConfig.InfFileName
    DriverIdentifier  = $printerSetupConfig.DriverIdentifier  # Include the new parameter
}

# Call the function with parameters using splatting
AOCheckCertificatePrinterPortAndDriver @params
