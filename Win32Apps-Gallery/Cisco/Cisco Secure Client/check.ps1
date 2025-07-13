<#
.SYNOPSIS
    Detects if Cisco Secure Client is installed on the system.

.DESCRIPTION
    This script performs multi-method detection for Cisco Secure Client installation:
    - Marker file analysis (checks previous installation results)
    - Registry detection (primary method)
    - File system detection (secondary method)
    - Service detection (tertiary method)
    - Process detection (to avoid disruption during active sessions)
    
    For Intune Win32 app deployment:
    - Exit 0 = Application is installed (detection successful)
    - Exit 1 = Application is not installed (detection failed)
    
    Runtime tracking:
    - Script includes runtime diagnostics in output
    - Self-terminates after 5 minutes (well within Intune's 30-minute limit)
    - Typical execution time: < 5 seconds

.PARAMETER EnableDebug
    Switch to enable detailed debug logging to console and file.
    When enabled, creates detailed logs in C:\ProgramData\CiscoSecureClient\Logs\

.PARAMETER DisableFileLogging
    Switch to completely disable all file logging operations.
    When enabled, only console output will be created.

.NOTES
    Version:        1.1
    Creation Date:  2025-01-12
    Purpose:        Intune Win32 App Detection Script
    Compatibility:  PowerShell 5.1
    Logging:        Uses comprehensive logging module with CSV export
#>

[CmdletBinding()]
param (
    [switch]$EnableDebug = $false,
    [switch]$DisableFileLogging = $false
)

#region Script Configuration
$MinimumVersion = "5.1.10.233"  # Minimum required version (based on installer package)
$ApplicationName = "Cisco Secure Client"
$script:DisableFileLogging = $DisableFileLogging  # Set script-level variable for logging module

# # Import logging module
# $LoggingModulePath = Join-Path $PSScriptRoot "logging\logging.psm1"
# if (Test-Path $LoggingModulePath) {
#     # Suppress module warnings to prevent STDOUT pollution for Intune
#     Import-Module $LoggingModulePath -Force -WarningAction SilentlyContinue
#     $LoggingMode = if ($EnableDebug) { 'EnableDebug' } else { 'SilentMode' }
#     Write-AppDeploymentLog -Message "=== Cisco Secure Client Detection Script Started ===" -Level Information -Mode $LoggingMode
#     Write-AppDeploymentLog -Message "Script Version: 1.1" -Level Information -Mode $LoggingMode
#     Write-AppDeploymentLog -Message "EnableDebug: $EnableDebug, DisableFileLogging: $DisableFileLogging" -Level Information -Mode $LoggingMode
# } else {
#     # Fallback if logging module not found
#     $LoggingMode = 'Off'
#     if ($EnableDebug) {
#         Write-Host "WARNING: Logging module not found at: $LoggingModulePath" -ForegroundColor Yellow
#     }
# }

# Initialize LoggingMode since module import is commented out
$LoggingMode = if ($EnableDebug) { 'EnableDebug' } else { 'SilentMode' }

#region Logging Function


function Write-AppDeploymentLog {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information',
        [Parameter()]
        [ValidateSet('EnableDebug', 'SilentMode', 'Off')]
        [string]$Mode = 'Off'
    )

    # Determine logging mode - check EnableDebug first, then parameter, then default to Off
    $loggingMode = if ($EnableDebug) { 
        'EnableDebug' 
    } elseif ($Mode -ne 'Off') { 
        $Mode 
    } else { 
        'Off' 
    }

    # Exit early if logging is completely disabled
    if ($loggingMode -eq 'Off') {
        return
    }

    # Enhanced caller information using improved logic from Write-EnhancedLog
    $callStack = Get-PSCallStack
    
    # Simplified and corrected function name detection logic
    $callerFunction = '<Unknown>'
    if ($callStack.Count -ge 2) {
        $caller = $callStack[1]
        
        # Use the same simple approach as Write-EnhancedLog that works correctly
        if ($caller.Command -and $caller.Command -notlike "*.ps1") {
            # This is a function name
            $callerFunction = $caller.Command
        } else {
            # This is either main script execution or a script file name - use MainScript
            $callerFunction = 'MainScript'
        }
    }
    
    # Get parent script name
    $parentScriptName = try {
        Get-ParentScriptName
    } catch {
        "UnknownScript"
    }
    
    # Get line number and script name for detailed logging
    $lineNumber = if ($callStack.Count -ge 2) { $callStack[1].ScriptLineNumber } else { 0 }
    $scriptFileName = if ($callStack.Count -ge 2 -and $callStack[1].ScriptName) { 
        Split-Path -Leaf $callStack[1].ScriptName 
    } else { 
        $parentScriptName 
    }

    # Create enhanced caller information combining both approaches
    $enhancedCallerInfo = "[$parentScriptName.$callerFunction]"
    $detailedCallerInfo = "[$scriptFileName`:$lineNumber $callerFunction]"

    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileLogMessage = "[$timeStamp] [$Level] $enhancedCallerInfo - $Message"
    $consoleLogMessage = "[$Level] $enhancedCallerInfo - $Message" # No timestamp for console

    #region Local File Logging
    # Skip all file logging if DisableFileLogging is set
    if ($script:DisableFileLogging) {
        return
    }
    
    # Use session-based paths if available, otherwise fall back to per-call generation
    if ($script:SessionLogFilePath -and $script:SessionFullLogDirectory) {
        $logFilePath = $script:SessionLogFilePath
        $logDirectory = $script:SessionFullLogDirectory
    } else {
        # Fallback to old method if session variables aren't set
        $userContext = Get-CurrentUser
        $callingScript = Get-CallingScriptName
        $parentScriptName = Get-ParentScriptName
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        
        $logDirectory = "C:\ProgramData\CiscoSecureClient\Logs"
        $fullLogDirectory = Join-Path -Path $logDirectory -ChildPath $dateFolder
        $fullLogDirectory = Join-Path -Path $fullLogDirectory -ChildPath $parentScriptName
        $logFileName = "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-activity-$timestamp.log"
        $logFilePath = Join-Path -Path $fullLogDirectory -ChildPath $logFileName
        $logDirectory = $fullLogDirectory
    }
    
    if (-not (Test-Path -Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction SilentlyContinue | Out-Null
    }
    
    if (Test-Path -Path $logDirectory) {
        Add-Content -Path $logFilePath -Value $fileLogMessage -ErrorAction SilentlyContinue
        
        # Log rotation for local files (keep max 7 files)
        try {
            $parentScriptForFilter = if ($script:SessionParentScript) { $script:SessionParentScript } else { "Discovery" }
            $logFiles = Get-ChildItem -Path $logDirectory -Filter "*-*-*-*-$parentScriptForFilter-activity*.log" | Sort-Object LastWriteTime -Descending
            if ($logFiles.Count -gt 7) {
                $filesToRemove = $logFiles | Select-Object -Skip 7
                foreach ($file in $filesToRemove) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            # Silent error handling for log rotation
        }
    }
    #endregion Local File Logging

    #region Network Share CSV Logging
    # Network logging: Only save CSV format logs under a parent job folder for better organization
    try {
        $hostname = $env:COMPUTERNAME
        $jobName = "CiscoSecureClient"  # Parent job folder name
        $networkBasePath = "\\AZR1PSCCM02\.logs\$jobName\$hostname"
        
        # Test network connectivity first
        $networkAvailable = Test-Path "\\AZR1PSCCM02\.logs" -ErrorAction SilentlyContinue
        
        if ($networkAvailable) {
            # Use session-based paths if available
            if ($script:SessionDateFolder -and $script:SessionParentScript -and $script:SessionCSVFileName) {
                $fullNetworkCSVPath = Join-Path -Path $networkBasePath -ChildPath $script:SessionDateFolder
                $fullNetworkCSVPath = Join-Path -Path $fullNetworkCSVPath -ChildPath $script:SessionParentScript
                $networkCSVFile = Join-Path -Path $fullNetworkCSVPath -ChildPath $script:SessionCSVFileName
            } else {
                # Fallback method
                $dateFolder = Get-Date -Format "yyyy-MM-dd"
                $parentScriptName = Get-ParentScriptName
                $userContext = Get-CurrentUser
                $callingScript = Get-CallingScriptName
                $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
                
                $fullNetworkCSVPath = Join-Path -Path $networkBasePath -ChildPath $dateFolder
                $fullNetworkCSVPath = Join-Path -Path $fullNetworkCSVPath -ChildPath $parentScriptName
                $networkCSVFileName = "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-activity-$timestamp.csv"
                $networkCSVFile = Join-Path -Path $fullNetworkCSVPath -ChildPath $networkCSVFileName
            }
            
            if (-not (Test-Path -Path $fullNetworkCSVPath)) {
                New-Item -ItemType Directory -Path $fullNetworkCSVPath -Force -ErrorAction SilentlyContinue | Out-Null
            }
            
            if (Test-Path -Path $fullNetworkCSVPath) {
                # Create CSV entry for network logging
                $userContext = if ($script:SessionUserContext) { $script:SessionUserContext } else { Get-CurrentUser }
                $callingScript = if ($script:SessionCallingScript) { $script:SessionCallingScript } else { Get-CallingScriptName }
                $parentScriptName = if ($script:SessionParentScript) { $script:SessionParentScript } else { Get-ParentScriptName }
                
                # Get caller information
                $callStack = Get-PSCallStack
                $callerFunction = '<Unknown>'
                if ($callStack.Count -ge 2) {
                    $caller = $callStack[1]
                    if ($caller.Command -and $caller.Command -notlike "*.ps1") {
                        $callerFunction = $caller.Command
                    } else {
                        $callerFunction = 'MainScript'
                    }
                }
                
                $lineNumber = if ($callStack.Count -ge 2) { $callStack[1].ScriptLineNumber } else { 0 }
                $scriptFileName = if ($callStack.Count -ge 2 -and $callStack[1].ScriptName) { 
                    Split-Path -Leaf $callStack[1].ScriptName 
                } else { 
                    $parentScriptName 
                }
                
                $enhancedCallerInfo = "[$parentScriptName.$callerFunction]"
                
                $networkCSVEntry = [PSCustomObject]@{
                    Timestamp       = $timeStamp
                    Level           = $Level
                    ParentScript    = $parentScriptName
                    CallingScript   = $callingScript
                    ScriptName      = $scriptFileName
                    FunctionName    = $callerFunction
                    LineNumber      = $lineNumber
                    Message         = $Message
                    Hostname        = $env:COMPUTERNAME
                    UserType        = $userContext.UserType
                    UserName        = $userContext.UserName
                    FullUserContext = $userContext.FullUserContext
                    CallerInfo      = $enhancedCallerInfo
                    JobName         = $jobName
                    LogType         = "NetworkCSV"
                }
                
                # Check if network CSV exists, if not create with headers
                if (-not (Test-Path -Path $networkCSVFile)) {
                    $networkCSVEntry | Export-Csv -Path $networkCSVFile -NoTypeInformation -ErrorAction SilentlyContinue
                } else {
                    $networkCSVEntry | Export-Csv -Path $networkCSVFile -NoTypeInformation -Append -ErrorAction SilentlyContinue
                }
                
                # Network CSV log rotation (keep max 5 files per machine per script)
                try {
                    $parentScriptForFilter = if ($script:SessionParentScript) { $script:SessionParentScript } else { "Discovery" }
                    $networkCSVFiles = Get-ChildItem -Path $fullNetworkCSVPath -Filter "*-*-*-*-$parentScriptForFilter-activity*.csv" | Sort-Object LastWriteTime -Descending
                    if ($networkCSVFiles.Count -gt 5) {
                        $filesToRemove = $networkCSVFiles | Select-Object -Skip 5
                        foreach ($file in $filesToRemove) {
                            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                catch {
                    # Silent error handling for network CSV log rotation
                }
            }
        }
    }
    catch {
        # Silent error handling for network CSV logging - don't interfere with main script
    }
    #endregion Network Share CSV Logging

    #region CSV Logging
    try {
        # Use session-based paths if available
        if ($script:SessionCSVFilePath -and $script:SessionFullCSVDirectory) {
            $csvLogPath = $script:SessionCSVFilePath
            $csvDirectory = $script:SessionFullCSVDirectory
        } else {
            # Fallback method
            $userContext = Get-CurrentUser
            $callingScript = Get-CallingScriptName
            $parentScriptName = Get-ParentScriptName
            $dateFolder = Get-Date -Format "yyyy-MM-dd"
            $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
            
            $csvLogDirectory = "C:\ProgramData\CiscoSecureClient\Logs\CSV"
            $fullCSVDirectory = Join-Path -Path $csvLogDirectory -ChildPath $dateFolder
            $fullCSVDirectory = Join-Path -Path $fullCSVDirectory -ChildPath $parentScriptName
            $csvFileName = "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-activity-$timestamp.csv"
            $csvLogPath = Join-Path -Path $fullCSVDirectory -ChildPath $csvFileName
            $csvDirectory = $fullCSVDirectory
        }
        
        if (-not (Test-Path -Path $csvDirectory)) {
            New-Item -ItemType Directory -Path $csvDirectory -Force -ErrorAction SilentlyContinue | Out-Null
        }
        
        # Use session context if available, otherwise get fresh context
        $userContext = if ($script:SessionUserContext) { $script:SessionUserContext } else { Get-CurrentUser }
        $callingScript = if ($script:SessionCallingScript) { $script:SessionCallingScript } else { Get-CallingScriptName }
        $parentScriptName = if ($script:SessionParentScript) { $script:SessionParentScript } else { Get-ParentScriptName }
        
        $csvEntry = [PSCustomObject]@{
            Timestamp       = $timeStamp
            Level           = $Level
            ParentScript    = $parentScriptName
            CallingScript   = $callingScript
            ScriptName      = $scriptFileName
            FunctionName    = $callerFunction
            LineNumber      = $lineNumber
            Message         = $Message
            Hostname        = $env:COMPUTERNAME
            UserType        = $userContext.UserType
            UserName        = $userContext.UserName
            FullUserContext = $userContext.FullUserContext
            CallerInfo      = $enhancedCallerInfo
        }
        
        # Check if CSV exists, if not create with headers
        if (-not (Test-Path -Path $csvLogPath)) {
            $csvEntry | Export-Csv -Path $csvLogPath -NoTypeInformation -ErrorAction SilentlyContinue
        } else {
            $csvEntry | Export-Csv -Path $csvLogPath -NoTypeInformation -Append -ErrorAction SilentlyContinue
        }
        
        # CSV log rotation
        try {
            $parentScriptForFilter = if ($script:SessionParentScript) { $script:SessionParentScript } else { "Discovery" }
            $csvFiles = Get-ChildItem -Path $csvDirectory -Filter "*-*-*-*-$parentScriptForFilter-activity*.csv" | Sort-Object LastWriteTime -Descending
            if ($csvFiles.Count -gt 7) {
                $filesToRemove = $csvFiles | Select-Object -Skip 7
                foreach ($file in $filesToRemove) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            # Silent error handling for CSV log rotation
        }
    }
    catch {
        # Silent error handling for CSV logging
    }
    #endregion CSV Logging

    #region Console Output (only in EnableDebug mode)
    if ($loggingMode -eq 'EnableDebug') {
        switch ($Level.ToUpper()) {
            'ERROR' { Write-Host $consoleLogMessage -ForegroundColor Red }
            'WARNING' { Write-Host $consoleLogMessage -ForegroundColor Yellow }
            'INFORMATION' { Write-Host $consoleLogMessage -ForegroundColor White }
            'DEBUG' { Write-Host $consoleLogMessage -ForegroundColor Gray }
        }
    }
    #endregion Console Output
}

function Write-EnhancedLog {
    [CmdletBinding()]
    param (
        [string]$Message,
        [string]$Level = 'INFO',
        [string]$LoggingMode = 'SilentMode'
    )

    # Get the PowerShell call stack to determine the actual calling function
    $callStack = Get-PSCallStack
    $callerFunction = if ($callStack.Count -ge 2) { $callStack[1].Command } else { '<Unknown>' }

    # Get the parent script name
    $parentScriptName = Get-ParentScriptName

    # Map enhanced log levels to CiscoApp log levels
    $mappedLevel = switch ($Level.ToUpper()) {
        'CRITICAL' { 'Error' }
        'ERROR'    { 'Error' }
        'WARNING'  { 'Warning' }
        'INFO'     { 'Information' }
        'DEBUG'    { 'Debug' }
        'NOTICE'   { 'Information' }
        'IMPORTANT' { 'Information' }
        'OUTPUT'   { 'Information' }
        'SIGNIFICANT' { 'Information' }
        'VERBOSE'  { 'Debug' }
        'VERYVERBOSE' { 'Debug' }
        'SOMEWHATVERBOSE' { 'Debug' }
        'SYSTEM'   { 'Information' }
        'INTERNALCOMMENT' { 'Debug' }
        default    { 'Information' }
    }

    # Format message with caller information
    $formattedMessage = "[$parentScriptName.$callerFunction] $Message"

    # Use the existing Write-AppDeploymentLog function
    Write-AppDeploymentLog -Message $formattedMessage -Level $mappedLevel -Mode $LoggingMode
}

#region Helper Functions


#region Error Handling
function Handle-Error {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$CustomMessage = "",
        [string]$LoggingMode = "SilentMode"
    )

    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $fullErrorDetails = Get-Error -InputObject $ErrorRecord | Out-String
        } else {
            $fullErrorDetails = $ErrorRecord.Exception | Format-List * -Force | Out-String
        }

        $errorMessage = if ($CustomMessage) {
            "$CustomMessage - Exception: $($ErrorRecord.Exception.Message)"
        } else {
            "Exception Message: $($ErrorRecord.Exception.Message)"
        }

        Write-AppDeploymentLog -Message $errorMessage -Level Error -Mode $LoggingMode
        Write-AppDeploymentLog -Message "Full Exception Details: $fullErrorDetails" -Level Debug -Mode $LoggingMode
        Write-AppDeploymentLog -Message "Script Line Number: $($ErrorRecord.InvocationInfo.ScriptLineNumber)" -Level Debug -Mode $LoggingMode
        Write-AppDeploymentLog -Message "Position Message: $($ErrorRecord.InvocationInfo.PositionMessage)" -Level Debug -Mode $LoggingMode
    } 
    catch {
        # Fallback error handling in case of an unexpected error in the try block
        Write-AppDeploymentLog -Message "An error occurred while handling another error. Original Exception: $($ErrorRecord.Exception.Message)" -Level Error -Mode $LoggingMode
        Write-AppDeploymentLog -Message "Handler Exception: $($_.Exception.Message)" -Level Error -Mode $LoggingMode
    }
}
#endregion Error Handling

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
                    # Write-EnhancedLog -Message "Found script in call stack: $parentScriptName" -Level "INFO"
                }
            }

            if (-not [string]::IsNullOrEmpty($parentScriptName)) {
                $parentScriptName = [System.IO.Path]::GetFileNameWithoutExtension($parentScriptName)
                return $parentScriptName
            }
        }

        # If no script name was found, return 'UnknownScript'
        Write-EnhancedLog -Message "No script name found in the call stack." -Level "WARNING"
        return "UnknownScript"
    }
    catch {
        Write-EnhancedLog -Message "An error occurred while retrieving the parent script name: $_" -Level "ERROR"
        return "UnknownScript"
    }
}

function Get-CurrentUser {
    [CmdletBinding()]
    param()
    
    try {
        # Get the current user context
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $computerName = $env:COMPUTERNAME
        
        # Check if running as SYSTEM
        if ($currentUser -like "*SYSTEM*" -or $currentUser -eq "NT AUTHORITY\SYSTEM") {
            return @{
                UserType = "SYSTEM"
                UserName = "LocalSystem"
                ComputerName = $computerName
                FullUserContext = "SYSTEM-LocalSystem"
            }
        }
        
        # Extract domain and username
        if ($currentUser.Contains('\')) {
            $domain = $currentUser.Split('\')[0]
            $userName = $currentUser.Split('\')[1]
        } else {
            $domain = $env:USERDOMAIN
            $userName = $currentUser
        }
        
        # Determine user type based on group membership
        $userType = "User"
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            if ($isAdmin) {
                $userType = "Admin"
            }
        }
        catch {
            # If we can't determine admin status, default to User
            $userType = "User"
        }
        
        # Sanitize names for file naming (remove invalid characters)
        $userName = $userName -replace '[<>:"/\\|?*]', '_'
        $userType = $userType -replace '[<>:"/\\|?*]', '_'
        
        return @{
            UserType = $userType
            UserName = $userName
            ComputerName = $computerName
            FullUserContext = "$userType-$userName"
        }
    }
    catch {
        Write-AppDeploymentLog -Message "Failed to get current user context: $($_.Exception.Message)" -Level Error -Mode SilentMode
        return @{
            UserType = "Unknown"
            UserName = "UnknownUser"
            ComputerName = $env:COMPUTERNAME
            FullUserContext = "Unknown-UnknownUser"
        }
    }
}

function Get-CallingScriptName {
    [CmdletBinding()]
    param()
    
    try {
        # Get the call stack
        $callStack = Get-PSCallStack
        
        # Look for the actual calling script (not this script or logging functions)
        $callingScript = "UnknownCaller"
        
        # Skip internal logging functions and Discovery script itself
        $skipFunctions = @('Write-AppDeploymentLog', 'Write-EnhancedLog', 'Handle-Error', 'Get-CallingScriptName', 'Get-CurrentUser')
        $skipScripts = @('Discovery', 'Discovery.ps1')
        
        # Start from index 1 to skip the current function
        for ($i = 1; $i -lt $callStack.Count; $i++) {
            $frame = $callStack[$i]
            
            # Check if this frame should be skipped
            $shouldSkip = $false
            
            # Skip if it's one of our internal functions
            if ($frame.Command -and $frame.Command -in $skipFunctions) {
                $shouldSkip = $true
            }
            
            # Skip if it's the Discovery script itself
            if ($frame.ScriptName) {
                $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($frame.ScriptName)
                if ($scriptName -in $skipScripts) {
                    $shouldSkip = $true
                }
            }
            
            # If we shouldn't skip this frame, use it
            if (-not $shouldSkip) {
                if ($frame.ScriptName) {
                    $callingScript = [System.IO.Path]::GetFileNameWithoutExtension($frame.ScriptName)
                    break
                }
                elseif ($frame.Command -and $frame.Command -ne "<ScriptBlock>") {
                    $callingScript = $frame.Command
                    break
                }
            }
        }
        
        # If we still haven't found a caller, determine the execution context
        if ($callingScript -eq "UnknownCaller") {
            # Check execution context
            if ($callStack.Count -le 3) {
                # Very short call stack suggests direct execution
                $callingScript = "DirectExecution"
            }
            elseif ($MyInvocation.InvocationName -and $MyInvocation.InvocationName -ne "Get-CallingScriptName") {
                # Use the invocation name if available
                $callingScript = $MyInvocation.InvocationName
            }
            elseif ($PSCommandPath) {
                # Check if we have a command path (script execution)
                $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
                if ($scriptName -and $scriptName -notin $skipScripts) {
                    $callingScript = $scriptName
                } else {
                    $callingScript = "PowerShellExecution"
                }
            }
            else {
                # Check the host name to determine execution context
                $hostName = $Host.Name
                switch ($hostName) {
                    "ConsoleHost" { $callingScript = "PowerShellConsole" }
                    "Windows PowerShell ISE Host" { $callingScript = "PowerShell_ISE" }
                    "ServerRemoteHost" { $callingScript = "RemoteExecution" }
                    "Visual Studio Code Host" { $callingScript = "VSCode" }
                    default { $callingScript = "PowerShellHost-$hostName" }
                }
            }
        }
        
        return $callingScript
    }
    catch {
        # In case of any error, provide a meaningful fallback
        try {
            $hostName = $Host.Name
            return "ErrorFallback-$hostName"
        }
        catch {
            return "ErrorFallback-Unknown"
        }
    }
}


#region Transcript Management Functions
function Start-CiscoAppTranscript {
    [CmdletBinding()]
    param(
        [string]$LogDirectory = "C:\ProgramData\CiscoSecureClient\Logs",
        [string]$LoggingMode = "SilentMode"
    )
    
    try {
        # Check if file logging is disabled
        if ($script:DisableFileLogging) {
            Write-AppDeploymentLog -Message "Transcript not started - file logging is disabled" -Level Debug -Mode $LoggingMode
            return $null
        }
        
        # Get current user context and calling script
        $userContext = Get-CurrentUser
        $callingScript = Get-CallingScriptName
        $parentScriptName = Get-ParentScriptName
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        
        # Create directory structure: Logs/Transcript/{Date}/{ParentScript}
        $transcriptDirectory = Join-Path -Path $LogDirectory -ChildPath "Transcript"
        $fullTranscriptDirectory = Join-Path -Path $transcriptDirectory -ChildPath $dateFolder
        $fullTranscriptDirectory = Join-Path -Path $fullTranscriptDirectory -ChildPath $parentScriptName
        
        if (-not (Test-Path -Path $fullTranscriptDirectory)) {
            New-Item -ItemType Directory -Path $fullTranscriptDirectory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        $transcriptFileName = "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-transcript-$timestamp.log"
        $transcriptPath = Join-Path -Path $fullTranscriptDirectory -ChildPath $transcriptFileName
        
        # Start transcript with error handling and suppress all console output
        try {
            Start-Transcript -Path $transcriptPath -ErrorAction Stop | Out-Null
            Write-AppDeploymentLog -Message "Transcript started successfully at: $transcriptPath" -Level Information -Mode $LoggingMode
        }
        catch {
            Handle-Error -ErrorRecord $_ -CustomMessage "Failed to start transcript at $transcriptPath" -LoggingMode $LoggingMode
            return $null
        }
        
        # Transcript rotation
        try {
            $transcriptFiles = Get-ChildItem -Path $fullTranscriptDirectory -Filter "*-*-*-*-$parentScriptName-transcript*.log" | Sort-Object LastWriteTime -Descending
            if ($transcriptFiles.Count -gt 7) {
                $filesToRemove = $transcriptFiles | Select-Object -Skip 7
                foreach ($file in $filesToRemove) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                    Write-AppDeploymentLog -Message "Removed old transcript file: $($file.FullName)" -Level Debug -Mode $LoggingMode
                }
            }
        }
        catch {
            Handle-Error -ErrorRecord $_ -CustomMessage "Error during transcript file rotation" -LoggingMode $LoggingMode
        }
        
        return $transcriptPath
    }
    catch {
        Handle-Error -ErrorRecord $_ -CustomMessage "Error in Start-CiscoAppTranscript function" -LoggingMode $LoggingMode
        return $null
    }
}

function Stop-CiscoAppTranscript {
    [CmdletBinding()]
    param(
        [string]$LoggingMode = "SilentMode"
    )
    
    try {
        # Check if file logging is disabled
        if ($script:DisableFileLogging) {
            Write-AppDeploymentLog -Message "Transcript not stopped - file logging is disabled" -Level Debug -Mode $LoggingMode
            return $false
        }
        
        # Check if transcript is running before attempting to stop
        $transcriptRunning = $false
        try {
            # Try to stop transcript and suppress all console output
            Stop-Transcript -ErrorAction Stop | Out-Null
            $transcriptRunning = $true
            Write-AppDeploymentLog -Message "Transcript stopped successfully." -Level Information -Mode $LoggingMode
        }
        catch [System.InvalidOperationException] {
            # This is expected if no transcript is running
            Write-AppDeploymentLog -Message "No active transcript to stop." -Level Debug -Mode $LoggingMode
        }
        catch {
            # Other transcript-related errors
            Handle-Error -ErrorRecord $_ -CustomMessage "Error stopping transcript" -LoggingMode $LoggingMode
        }
        
        return $transcriptRunning
    }
    catch {
        Handle-Error -ErrorRecord $_ -CustomMessage "Error in Stop-CiscoAppTranscript function" -LoggingMode $LoggingMode
        return $false
    }
}

function Get-TranscriptFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranscriptsPath,
        [Parameter(Mandatory = $true)]
        [string]$JobName,
        [Parameter(Mandatory = $true)]
        [string]$parentScriptName
    )
    
    try {
        # Get current user context and calling script
        $userContext = Get-CurrentUser
        $callingScript = Get-CallingScriptName
        
        # Generate date folder (YYYY-MM-DD format)
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        
        # Create the full directory path: Transcript/{Date}/{ParentScript}
        $fullDirectoryPath = Join-Path -Path $TranscriptsPath -ChildPath $dateFolder
        $fullDirectoryPath = Join-Path -Path $fullDirectoryPath -ChildPath $parentScriptName
        
        # Ensure the directory exists
        if (-not (Test-Path -Path $fullDirectoryPath)) {
            New-Item -ItemType Directory -Path $fullDirectoryPath -Force | Out-Null
        }
        
        # Generate timestamp for unique transcript file
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        
        # Create the transcript file name following the convention:
        # {ComputerName}-{CallingScript}-{UserType}-{UserName}-{ParentScript}-transcript-{Timestamp}.log
        $transcriptFileName = "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-transcript-$timestamp.log"
        
        # Combine the full path
        $transcriptFilePath = Join-Path -Path $fullDirectoryPath -ChildPath $transcriptFileName
        
        return $transcriptFilePath
    }
    catch {
        Write-AppDeploymentLog -Message "Failed to generate transcript file path: $($_.Exception.Message)" -Level Error -Mode SilentMode
        # Return a fallback path with user context
        $userContext = Get-CurrentUser
        $callingScript = Get-CallingScriptName
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $fallbackPath = Join-Path -Path $TranscriptsPath -ChildPath $dateFolder
        $fallbackPath = Join-Path -Path $fallbackPath -ChildPath $parentScriptName
        if (-not (Test-Path -Path $fallbackPath)) {
            New-Item -ItemType Directory -Path $fallbackPath -Force | Out-Null
        }
        return Join-Path -Path $fallbackPath -ChildPath "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-transcript-fallback-$timestamp.log"
    }
}
#endregion Transcript Management Functions
function Get-CSVLogFilePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogsPath,
        [Parameter(Mandatory = $true)]
        [string]$JobName,
        [Parameter(Mandatory = $true)]
        [string]$parentScriptName
    )

    try {
        # Get current user context and calling script
        $userContext = Get-CurrentUser
        $callingScript = Get-CallingScriptName
        
        # Generate date folder (YYYY-MM-DD format)
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        
        # Create the full directory path: PSF/{Date}/{ParentScript}
        $fullDirectoryPath = Join-Path -Path $LogsPath -ChildPath $dateFolder
        $fullDirectoryPath = Join-Path -Path $fullDirectoryPath -ChildPath $parentScriptName
        
        # Ensure the directory exists
        if (-not (Test-Path -Path $fullDirectoryPath)) {
            New-Item -ItemType Directory -Path $fullDirectoryPath -Force | Out-Null
        }

        # Generate timestamp for unique log file
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        
        # Create the log file name following the convention:
        # {ComputerName}-{CallingScript}-{UserType}-{UserName}-{ParentScript}-log-{Timestamp}.csv
        $logFileName = "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-log-$timestamp.csv"
        
        # Combine the full path
        $csvLogFilePath = Join-Path -Path $fullDirectoryPath -ChildPath $logFileName
        
        return $csvLogFilePath
    }
    catch {
        Write-AppDeploymentLog -Message "Failed to generate CSV log file path: $($_.Exception.Message)" -Level Error -Mode SilentMode
        # Return a fallback path with user context
        $userContext = Get-CurrentUser
        $callingScript = Get-CallingScriptName
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $fallbackPath = Join-Path -Path $LogsPath -ChildPath $dateFolder
        $fallbackPath = Join-Path -Path $fallbackPath -ChildPath $parentScriptName
        if (-not (Test-Path -Path $fallbackPath)) {
            New-Item -ItemType Directory -Path $fallbackPath -Force | Out-Null
        }
        return Join-Path -Path $fallbackPath -ChildPath "$($userContext.ComputerName)-$callingScript-$($userContext.UserType)-$($userContext.UserName)-$parentScriptName-log-fallback-$timestamp.csv"
    }
}




#endregion Helper Functions


#endregion Logging Function

#endregion

#region Detection Functions

#region Marker File Analysis
function Test-MarkerFile {
    <#
    .SYNOPSIS
        Checks for installation marker file from previous installations
    #>
    param(
        [string]$FilePath,
        [int]$MaxAgeHours = 168  # 7 days default
    )
    
    try {
        Write-AppDeploymentLog -Message "Checking marker file: $FilePath" -Level Debug -Mode $LoggingMode
        
        # Check if marker file exists
        if (-not (Test-Path -Path $FilePath)) {
            Write-AppDeploymentLog -Message "Marker file does not exist. Installation has never been run." -Level Information -Mode $LoggingMode
            return @{ IsValid = $false; InstallationFound = $false; Reason = "FileNotFound" }
        }
        
        # Check file age
        $fileInfo = Get-Item -Path $FilePath
        $fileAge = (Get-Date) - $fileInfo.LastWriteTime
        $fileAgeHours = $fileAge.TotalHours
        
        if ($fileAgeHours -gt $MaxAgeHours) {
            Write-AppDeploymentLog -Message "Marker file is stale (age: $([math]::Round($fileAgeHours, 2)) hours, max: $MaxAgeHours hours)." -Level Information -Mode $LoggingMode
            return @{ IsValid = $false; InstallationFound = $false; Reason = "FileStale"; FileAgeHours = $fileAgeHours }
        }
        
        Write-AppDeploymentLog -Message "Marker file exists and is current (age: $([math]::Round($fileAgeHours, 2)) hours). Analyzing content..." -Level Debug -Mode $LoggingMode
        
        # Read and parse JSON content
        $jsonContent = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        $markerData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # Validate required fields exist
        if (-not $markerData.InstallationTimestamp -or -not $markerData.InstallationStatus) {
            Write-AppDeploymentLog -Message "Marker file has invalid structure. Missing required fields." -Level Warning -Mode $LoggingMode
            return @{ IsValid = $false; InstallationFound = $false; Reason = "InvalidStructure" }
        }
        
        # Check installation status
        $status = $markerData.InstallationStatus
        Write-AppDeploymentLog -Message "Previous installation status: $status" -Level Debug -Mode $LoggingMode
        
        if ($status -eq "Success") {
            Write-AppDeploymentLog -Message "Marker file indicates successful installation." -Level Information -Mode $LoggingMode
            return @{ 
                IsValid = $true
                InstallationFound = $true
                Reason = "InstallationSuccess"
                InstallationStatus = $status
                InstalledVersion = $markerData.InstalledVersion
                ComponentsInstalled = $markerData.ComponentsInstalled
            }
        } else {
            Write-AppDeploymentLog -Message "Marker file indicates installation was not fully successful (status: $status)." -Level Warning -Mode $LoggingMode
            return @{ 
                IsValid = $true
                InstallationFound = $false
                Reason = "InstallationIncomplete"
                InstallationStatus = $status
            }
        }
    }
    catch {
        if ($null -ne (Get-Command Handle-Error -ErrorAction SilentlyContinue)) {
            Handle-Error -ErrorRecord $_ -CustomMessage "Failed to analyze marker file: $FilePath" -LoggingMode $LoggingMode
        }
        Write-AppDeploymentLog -Message "Error reading marker file. Treating as invalid." -Level Error -Mode $LoggingMode
        return @{ IsValid = $false; InstallationFound = $false; Reason = "FileReadError"; Error = $_.Exception.Message }
    }
}
#endregion Marker File Analysis

function Test-CiscoProcesses {
    <#
    .SYNOPSIS
        Checks for running Cisco processes to avoid disruption
    #>
    param()
    
    Write-AppDeploymentLog -Message "Checking for active Cisco processes..." -Level Debug -Mode $LoggingMode
    
    $ciscoProcesses = @(
        "vpnui",           # Cisco AnyConnect VPN UI
        "vpnagent",        # Cisco AnyConnect VPN Agent
        "csc_umbrellaagent", # Cisco Umbrella Agent
        "acwebsecagent"    # Cisco Web Security Agent
    )
    
    foreach ($processName in $ciscoProcesses) {
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($null -ne $process) {
            Write-AppDeploymentLog -Message "Active Cisco process found: $processName (PID: $($process.Id))" -Level Information -Mode $LoggingMode
            return $true
        }
    }
    
    Write-AppDeploymentLog -Message "No active Cisco processes found." -Level Debug -Mode $LoggingMode
    return $false
}

function Test-CiscoRegistry {
    <#
    .SYNOPSIS
        Checks registry for Cisco Secure Client installation
    #>
    param()
    
    Write-AppDeploymentLog -Message "Starting registry detection for Cisco Secure Client..." -Level Debug -Mode $LoggingMode
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $searchPatterns = @(
        "*Cisco Secure Client*",
        "*Cisco AnyConnect*",
        "*Cisco Umbrella*"
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Write-AppDeploymentLog -Message "Checking registry path: $path" -Level Debug -Mode $LoggingMode
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                if ($null -eq $item.DisplayName) { continue }
                
                foreach ($pattern in $searchPatterns) {
                    if ($item.DisplayName -like $pattern) {
                        Write-AppDeploymentLog -Message "Found matching registry entry: $($item.DisplayName)" -Level Information -Mode $LoggingMode
                        
                        # Version check if version info is available
                        if ($item.DisplayVersion) {
                            try {
                                $installedVersion = [version]$item.DisplayVersion
                                $requiredVersion = [version]$MinimumVersion
                                
                                if ($installedVersion -ge $requiredVersion) {
                                    Write-AppDeploymentLog -Message "Version check passed: $($item.DisplayVersion) >= $MinimumVersion" -Level Information -Mode $LoggingMode
                                    return $true
                                } else {
                                    Write-AppDeploymentLog -Message "Version check failed: $($item.DisplayVersion) < $MinimumVersion" -Level Warning -Mode $LoggingMode
                                }
                            }
                            catch {
                                # If version parsing fails, consider it installed
                                Write-AppDeploymentLog -Message "Version parsing failed for $($item.DisplayName), treating as installed" -Level Warning -Mode $LoggingMode
                                return $true
                            }
                        }
                        else {
                            # No version info, but product found
                            Write-AppDeploymentLog -Message "Found $($item.DisplayName) in registry (no version info available)" -Level Information -Mode $LoggingMode
                            return $true
                        }
                    }
                }
            }
        }
    }
    
    Write-AppDeploymentLog -Message "No Cisco Secure Client found in registry." -Level Debug -Mode $LoggingMode
    return $false
}

function Test-CiscoFiles {
    <#
    .SYNOPSIS
        Checks for Cisco Secure Client files in common installation paths
    #>
    param()
    
    $filePaths = @(
        "${env:ProgramFiles}\Cisco\Cisco Secure Client\vpnui.exe",
        "${env:ProgramFiles(x86)}\Cisco\Cisco Secure Client\vpnui.exe",
        "${env:ProgramFiles}\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe",
        "${env:ProgramFiles(x86)}\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"
    )
    
    foreach ($path in $filePaths) {
        if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
            # Check file version if possible
            try {
                $fileInfo = Get-Item -Path $path -ErrorAction Stop
                $fileVersion = $fileInfo.VersionInfo.ProductVersion
                
                if ($fileVersion) {
                    $installedVersion = [version]$fileVersion
                    $requiredVersion = [version]$MinimumVersion
                    
                    if ($installedVersion -ge $requiredVersion) {
                        if ($VerboseOutput) {
                            Write-Output "Found Cisco executable at: $path (version $fileVersion)"
                        }
                        return $true
                    }
                }
                else {
                    # File exists but no version info
                    if ($VerboseOutput) {
                        Write-Output "Found Cisco executable at: $path (no version info)"
                    }
                    return $true
                }
            }
            catch {
                # File exists but couldn't read version
                if ($VerboseOutput) {
                    Write-Output "Found Cisco executable at: $path (error reading version)"
                }
                return $true
            }
        }
    }
    
    return $false
}

function Test-CiscoServices {
    <#
    .SYNOPSIS
        Checks for Cisco services
    #>
    param()
    
    $serviceNames = @(
        "csc_umbrellaagent",  # Cisco Umbrella Roaming Client
        "vpnagent",           # Cisco AnyConnect Secure Mobility Agent
        "acwebsecagent"       # Cisco AnyConnect Web Security Agent
    )
    
    foreach ($serviceName in $serviceNames) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $service) {
            if ($VerboseOutput) {
                Write-Output "Found Cisco service: $serviceName (Status: $($service.Status))"
            }
            return $true
        }
    }
    
    return $false
}
#endregion

#region Main Detection Logic
# Start timing for diagnostics
$ScriptStartTime = Get-Date
$MaxRuntime = 300  # 5 minutes max (well within 30-minute limit)

try {
    Write-AppDeploymentLog -Message "Starting main detection logic..." -Level Information -Mode $LoggingMode
    
    #region Marker File Analysis
    $markerFilePath = "C:\ProgramData\CiscoSecureClient\installation-results.json"
    $markerFileMaxAgeHours = 168  # 7 days
    
    Write-AppDeploymentLog -Message "Checking installation marker file..." -Level Information -Mode $LoggingMode
    $markerResult = Test-MarkerFile -FilePath $markerFilePath -MaxAgeHours $markerFileMaxAgeHours
    
    if ($markerResult.IsValid -and $markerResult.InstallationFound) {
        Write-AppDeploymentLog -Message "Valid marker file found indicating successful installation." -Level Information -Mode $LoggingMode
        # Continue with other checks to verify installation is still intact
    }
    #endregion Marker File Analysis
    
    # Check if user is in active session first (least disruptive)
    if (Test-CiscoProcesses) {
        $RunTime = (Get-Date) - $ScriptStartTime
        Write-AppDeploymentLog -Message "Detection completed - active processes found. [Total Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]" -Level Information -Mode $LoggingMode
        Write-Output "$ApplicationName is installed (active processes detected) [Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]"
        exit 0
    }
    
    # Check runtime before registry scan
    if (((Get-Date) - $ScriptStartTime).TotalSeconds -gt $MaxRuntime) {
        Write-AppDeploymentLog -Message "Detection timeout reached." -Level Warning -Mode $LoggingMode
        Write-Output "Detection timeout reached. Assuming not installed. [Runtime: $MaxRuntime s]"
        exit 1
    }
    
    # Primary detection method: Registry
    if (Test-CiscoRegistry) {
        $RunTime = (Get-Date) - $ScriptStartTime
        Write-AppDeploymentLog -Message "Detection completed - found in registry. [Total Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]" -Level Information -Mode $LoggingMode
        Write-Output "$ApplicationName is installed (registry detection) [Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]"
        exit 0
    }
    
    # Check runtime before file system scan
    if (((Get-Date) - $ScriptStartTime).TotalSeconds -gt $MaxRuntime) {
        Write-AppDeploymentLog -Message "Detection timeout reached." -Level Warning -Mode $LoggingMode
        Write-Output "Detection timeout reached. Assuming not installed. [Runtime: $MaxRuntime s]"
        exit 1
    }
    
    # Secondary detection method: File system
    if (Test-CiscoFiles) {
        $RunTime = (Get-Date) - $ScriptStartTime
        Write-AppDeploymentLog -Message "Detection completed - found via file system. [Total Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]" -Level Information -Mode $LoggingMode
        Write-Output "$ApplicationName is installed (file detection) [Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]"
        exit 0
    }
    
    # Check runtime before service scan
    if (((Get-Date) - $ScriptStartTime).TotalSeconds -gt $MaxRuntime) {
        Write-AppDeploymentLog -Message "Detection timeout reached." -Level Warning -Mode $LoggingMode
        Write-Output "Detection timeout reached. Assuming not installed. [Runtime: $MaxRuntime s]"
        exit 1
    }
    
    # Tertiary detection method: Services
    if (Test-CiscoServices) {
        $RunTime = (Get-Date) - $ScriptStartTime
        Write-AppDeploymentLog -Message "Detection completed - found via services. [Total Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]" -Level Information -Mode $LoggingMode
        Write-Output "$ApplicationName is installed (service detection) [Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]"
        exit 0
    }
    
    # If we reach here, Cisco Secure Client is not detected
    $RunTime = (Get-Date) - $ScriptStartTime
    
    # Log why detection failed
    if (-not $markerResult.IsValid) {
        Write-AppDeploymentLog -Message "No valid installation marker found. Reason: $($markerResult.Reason)" -Level Information -Mode $LoggingMode
    }
    
    Write-AppDeploymentLog -Message "Detection completed - application not found. [Total Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]" -Level Information -Mode $LoggingMode
    Write-AppDeploymentLog -Message "=== Cisco Secure Client Detection Script Completed ===" -Level Information -Mode $LoggingMode
    Write-Output "$ApplicationName is not installed [Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]"
    exit 1
}
catch {
    # On any error, assume not installed to trigger installation
    $RunTime = (Get-Date) - $ScriptStartTime
    
    if ($null -ne (Get-Command Handle-Error -ErrorAction SilentlyContinue)) {
        Handle-Error -ErrorRecord $_ -CustomMessage "Detection script encountered an error" -LoggingMode $LoggingMode
    }
    
    Write-AppDeploymentLog -Message "=== Cisco Secure Client Detection Script Failed ===" -Level Error -Mode $LoggingMode
    Write-Output "Detection script error: $_ [Runtime: $($RunTime.TotalSeconds.ToString('F2'))s]"
    exit 1
}
#endregion