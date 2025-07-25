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

# Export module members
Export-ModuleMember -Function @(
    'Write-AppDeploymentLog',
    'Write-EnhancedLog',
    'Handle-Error',
    'Get-ParentScriptName',
    'Get-CurrentUser',
    'Get-CallingScriptName',
    'Start-CiscoAppTranscript',
    'Stop-CiscoAppTranscript',
    'Get-TranscriptFilePath',
    'Get-CSVLogFilePath'
)