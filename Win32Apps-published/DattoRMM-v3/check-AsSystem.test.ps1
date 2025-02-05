# param (
#     [string]$Mode = "dev"
# )

# Set environment variable globally for all users



#region Animated logo with color and System info
#################################################################################################
#                                                                                               #
#                       Animated logo with color and System info                                #
#                                                                                               #
#################################################################################################

# Animated logo with color
$logo = @"


_____       _                       _____ _               _      _    _ _   _ _ _ _         
|_   _|     | |                     / ____| |             | |    | |  | | | (_) (_) |        
  | |  _ __ | |_ _   _ _ __   ___  | |    | |__   ___  ___| | __ | |  | | |_ _| |_| |_ _   _ 
  | | | '_ \| __| | | | '_ \ / _ \ | |    | '_ \ / _ \/ __| |/ / | |  | | __| | | | __| | | |
 _| |_| | | | |_| |_| | | | |  __/ | |____| | | |  __/ (__|   <  | |__| | |_| | | | |_| |_| |
|_____|_| |_|\__|\__,_|_| |_|\___|  \_____|_| |_|\___|\___|_|\_\  \____/ \__|_|_|_|\__|\__, |
                                                                                        __/ |
                                                                                       |___/ 

"@

# Display the logo in different colors
$colors = "Red", "Yellow", "Cyan", "Green", "Blue", "Magenta"


#colors like Black do not appear on a black background so avoid them

# # Add more colors
# $colors = "Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", `
#           "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White"

# Print the logo line by line with animation
$logo.Split("`n") | ForEach-Object {
    $color = Get-Random -InputObject $colors
    Write-Host $_ -ForegroundColor $color
    # Start-Sleep -Milliseconds 200  # Adjust sleep for speed
}

Write-Host "`nIntune Check Utility v1.0" -ForegroundColor Green
Write-Host "Created by AOllivierre's Script Lab" -ForegroundColor Yellow


# Display the system info after logo

# Get Operating System Info
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$osInfo = "$($os.Caption) $($os.Version) $($os.BuildNumber)"

# Get Hostname
$hostname = $env:COMPUTERNAME

# Get CPU Info
$cpu = Get-CimInstance -ClassName Win32_Processor
$cpuInfo = "$($cpu.Name) | $($cpu.NumberOfCores) cores"

# Get Memory Info (Total and Free)
$memory = Get-CimInstance -ClassName Win32_OperatingSystem
$totalMemory = "{0:N2}" -f ($memory.TotalVisibleMemorySize / 1MB)
$freeMemory = "{0:N2}" -f ($memory.FreePhysicalMemory / 1MB)

# Get Disk Usage Info
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
$diskInfo = @()
foreach ($d in $disk) {
    $totalSize = "{0:N2}" -f ($d.Size / 1GB)
    $freeSpace = "{0:N2}" -f ($d.FreeSpace / 1GB)
    $diskInfo += "Drive $($d.DeviceID): $totalSize GB total, $freeSpace GB free"
}

# Get IP Address
$ipAddress = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.PrefixOrigin -eq "Dhcp" }).IPAddress

# Display the gathered system info
Write-Host "`n--- System Information ---" -ForegroundColor Yellow
Write-Host "Operating System  : $osInfo" -ForegroundColor Cyan
Write-Host "Hostname          : $hostname" -ForegroundColor Cyan
Write-Host "CPU               : $cpuInfo" -ForegroundColor Cyan
Write-Host "Total Memory      : $totalMemory GB" -ForegroundColor Cyan
Write-Host "Free Memory       : $freeMemory GB" -ForegroundColor Cyan

# Disk information
Write-Host "`nDisk Usage:" -ForegroundColor Yellow
$diskInfo | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }

Write-Host "`nIP Address        : $ipAddress" -ForegroundColor Cyan

#endregion Animated logo with color and System info




# Check if running in PowerShell 5
if ($PSVersionTable.PSVersion.Major -ne 5) {
    # Log a message indicating the script is not running in PowerShell 5
    Write-Host "This script requires PowerShell 5. The current version is PowerShell $($PSVersionTable.PSVersion)." -ForegroundColor Red
    Write-Host "Please run this script using PowerShell 5." -ForegroundColor Red

    # Exit the script
    exit 1
}

# If running in PowerShell 5, continue with the script
Write-Host "Running in PowerShell 5. Continuing with the script..." -ForegroundColor Green


# if (-not (Test-Path Variable:SimulatingIntune)) {
#     New-Variable -Name 'SimulatingIntune' -Value $true -Option None
# }
# else {
#     Set-Variable -Name 'SimulatingIntune' -Value $true
# }


# Retrieve the environment mode (default to 'prod' if not set)

$global:mode = 'prod'
$global:SimulatingIntune = $true
# $ExitOnCondition = $false

[System.Environment]::SetEnvironmentVariable('EnvironmentMode', $global:mode, 'Machine')
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', $global:mode, 'process')

# Alternatively, use this PowerShell method (same effect)
# Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'EnvironmentMode' -Value 'dev'

$global:mode = $env:EnvironmentMode
$global:LOG_ASYNC = $false #Enable Async mode (all levels except Warnings, Errors and Criticals are treated as Debug which means they are written to the log file without showing on the console)
$global:LOG_SILENT = $false  # Enable silent mode (all levels are treated as Debug)




function Write-IntuneDetectionScriptLog {
    param (
        [string]$Message,
        [string]$Level = "INFO"
        # [switch]$Async = $false  # Control whether logging should be async or not
    )

    # Check if the Async switch is not set, then use the global variable if defined
    # if (-not $Async) {
    #     $Async = $global:LOG_ASYNC
    # }

    # Get the PowerShell call stack to determine the actual calling function
    $callStack = Get-PSCallStack
    $callerFunction = if ($callStack.Count -ge 2) { $callStack[1].Command } else { '<Unknown>' }

    # Prepare the formatted message with the actual calling function information
    $formattedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$callerFunction] $Message"

    # if ($Async) {
    #     # Enqueue the log message for async processing
    #     $logItem = [PSCustomObject]@{
    #         Level        = $Level
    #         Message      = $formattedMessage
    #         FunctionName = $callerFunction
    #     }
    #     $global:LogQueue.Enqueue($logItem)
    # }
    # else {
    # Display the log message based on the log level using Write-Host
    switch ($Level.ToUpper()) {
        "DEBUG" { Write-Host $formattedMessage -ForegroundColor DarkGray }
        "INFO" { Write-Host $formattedMessage -ForegroundColor Green }
        "NOTICE" { Write-Host $formattedMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $formattedMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $formattedMessage -ForegroundColor Red }
        "CRITICAL" { Write-Host $formattedMessage -ForegroundColor Magenta }
        default { Write-Host $formattedMessage -ForegroundColor White }
    }

    # Append to log file synchronously
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'setupAADMigration.log')
    $formattedMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
    # }
}

function Reset-ModulePaths {
    [CmdletBinding()]
    param ()

    begin {
        # Initialization block, typically used for setup tasks
        Write-IntuneDetectionScriptLog -Message "Initializing Reset-ModulePaths function..." -Level "DEBUG"
    }

    process {
        try {
            # Log the start of the process
            Write-IntuneDetectionScriptLog -Message "Resetting module paths to default values..." -Level "INFO"

            # Get the current user's Documents path
            $userModulesPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Documents\WindowsPowerShell\Modules')

            # Define the default module paths
            $defaultModulePaths = @(
                "C:\Program Files\WindowsPowerShell\Modules",
                $userModulesPath,
                "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
            )

            # Attempt to reset the PSModulePath environment variable
            $env:PSModulePath = [string]::Join(';', $defaultModulePaths)
            Write-IntuneDetectionScriptLog -Message "PSModulePath successfully set to: $($env:PSModulePath -split ';' | Out-String)" -Level "INFO"

            # Optionally persist the change for the current user
            [Environment]::SetEnvironmentVariable("PSModulePath", $env:PSModulePath, [EnvironmentVariableTarget]::User)
            Write-IntuneDetectionScriptLog -Message "PSModulePath environment variable set for the current user." -Level "INFO"
        }
        catch {
            # Capture and log any errors that occur during the process
            $errorMessage = $_.Exception.Message
            Write-IntuneDetectionScriptLog -Message "Error resetting module paths: $errorMessage" -Level "ERROR"

            # Optionally, you could throw the error to halt the script
            throw $_
        }
    }

    end {
        # Finalization block, typically used for cleanup tasks
        Write-IntuneDetectionScriptLog -Message "Reset-ModulePaths function completed." -Level "DEBUG"
    }
}


# Toggle based on the environment mode
switch ($global:mode) {
    'dev' {
        Write-IntuneDetectionScriptLog -Message "Running in development mode" -Level 'Warning'
        # Your development logic here
    }
    'prod' {
        Write-IntuneDetectionScriptLog -Message "Running in production mode" -Level 'INFO'
        # Your production logic here
    }
    default {
        Write-IntuneDetectionScriptLog -Message "Unknown mode. Defaulting to production." -Level 'ERROR'
        # Default to production
    }
}







#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################


# Wait-Debugger

# Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")

# Wait-Debugger

# Import-Module 'C:\code\ModulesV2\EnhancedModuleStarterAO\EnhancedModuleStarterAO.psm1'

# Define a hashtable for splatting
# $moduleStarterParams = @{
#     Mode                   = $global:mode
#     SkipPSGalleryModules   = $false
#     SkipCheckandElevate    = $false
#     SkipPowerShell7Install = $false
#     SkipEnhancedModules    = $false
#     SkipGitRepos           = $true
# }

# # Call the function using the splat
# Invoke-ModuleStarter @moduleStarterParams


# Define the mutex name (should be the same across all scripts needing synchronization)
$mutexName = "Global\MyCustomMutexForModuleInstallation"

# Create or open the mutex
$mutex = [System.Threading.Mutex]::new($false, $mutexName)

# Set initial back-off parameters
$initialWaitTime = 5       # Initial wait time in seconds
$maxAttempts = 10           # Maximum number of attempts
$backOffFactor = 2         # Factor to increase the wait time for each attempt

$attempt = 0
$acquiredLock = $false

# Try acquiring the mutex with dynamic back-off
while (-not $acquiredLock -and $attempt -lt $maxAttempts) {
    $attempt++
    Write-IntuneDetectionScriptLog -Message "Attempt $attempt to acquire the lock..."

    # Try to acquire the mutex with a timeout
    $acquiredLock = $mutex.WaitOne([TimeSpan]::FromSeconds($initialWaitTime))

    if (-not $acquiredLock) {
        # If lock wasn't acquired, wait for the back-off period before retrying
        Write-IntuneDetectionScriptLog "Failed to acquire the lock. Retrying in $initialWaitTime seconds..." -Level 'WARNING'
        Start-Sleep -Seconds $initialWaitTime

        # Increase the wait time using the back-off factor
        $initialWaitTime *= $backOffFactor
    }
}

try {
    if ($acquiredLock) {
        Write-IntuneDetectionScriptLog -Message "Acquired the lock. Proceeding with module installation and import."

        # Start timing the critical section
        $executionTime = [System.Diagnostics.Stopwatch]::StartNew()

        # Critical section starts here

        # Conditional check for dev and prod mode
        if ($global:mode -eq "dev") {
            # In dev mode, import the module from the local path
            Write-IntuneDetectionScriptLog -Message "Running in dev mode. Importing module from local path."
            Import-Module 'C:\code\ModulesV2\EnhancedModuleStarterAO\EnhancedModuleStarterAO.psm1'
        }
        elseif ($global:mode -eq "prod") {
            # In prod mode, execute the script from the URL
            Write-IntuneDetectionScriptLog -Message "Running in prod mode. Executing the script from the remote URL."
            # Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")


            # Check if running in PowerShell 5
            if ($PSVersionTable.PSVersion.Major -ne 5) {
                Write-IntuneDetectionScriptLog -Message "Not running in PowerShell 5. Relaunching the command with PowerShell 5."

                # Reset Module Paths when switching from PS7 to PS5 process
                Reset-ModulePaths

                # Get the path to PowerShell 5 executable
                $ps5Path = "$Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

                # Relaunch the Invoke-Expression command with PowerShell 5
                & $ps5Path -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1')"
            }
            else {
                # If running in PowerShell 5, execute the command directly
                Write-IntuneDetectionScriptLog -Message "Running in PowerShell 5. Executing the command."
                Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")
            }


        }
        else {
            Write-IntuneDetectionScriptLog -Message "Invalid mode specified. Please set the mode to either 'dev' or 'prod'." -Level 'WARNING'
            exit 1
        }

        # Optional: Wait for debugger if needed
        # Wait-Debugger


        # Define a hashtable for splatting
        $moduleStarterParams = @{
            Mode                   = $global:mode
            SkipPSGalleryModules   = $false
            SkipCheckandElevate    = $false
            SkipPowerShell7Install = $false
            SkipEnhancedModules    = $false
            SkipGitRepos           = $true
        }

        # Check if running in PowerShell 5
        if ($PSVersionTable.PSVersion.Major -ne 5) {
            Write-IntuneDetectionScriptLog -Message  "Not running in PowerShell 5. Relaunching the function call with PowerShell 5."

            # Get the path to PowerShell 5 executable
            $ps5Path = "$Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"


            Reset-ModulePaths

            # Relaunch the Invoke-ModuleStarter function call with PowerShell 5
            & $ps5Path -Command {
                # Recreate the hashtable within the script block for PowerShell 5
                $moduleStarterParams = @{
                    Mode                   = 'prod'
                    SkipPSGalleryModules   = $false
                    SkipCheckandElevate    = $false
                    SkipPowerShell7Install = $false
                    SkipEnhancedModules    = $false
                    SkipGitRepos           = $true
                }
                Invoke-ModuleStarter @moduleStarterParams
            }
        }
        else {
            # If running in PowerShell 5, execute the function directly
            Write-IntuneDetectionScriptLog -Message "Running in PowerShell 5. Executing Invoke-ModuleStarter."
            Invoke-ModuleStarter @moduleStarterParams
        }

        
        # Critical section ends here
        $executionTime.Stop()

        # Measure the time taken and log it
        $timeTaken = $executionTime.Elapsed.TotalSeconds
        Write-IntuneDetectionScriptLog -Message "Critical section execution time: $timeTaken seconds"

        # Optionally, log this to a file for further analysis
        # Add-Content -Path "C:\Temp\CriticalSectionTimes.log" -Value "Execution time: $timeTaken seconds - $(Get-Date)"

        Write-IntuneDetectionScriptLog -Message "Module installation and import completed."
    }
    else {
        Write-Warning "Failed to acquire the lock after $maxAttempts attempts. Exiting the script."
        exit 1
    }
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Release the mutex if it was acquired
    if ($acquiredLock) {
        $mutex.ReleaseMutex()
        Write-IntuneDetectionScriptLog -Message "Released the lock."
    }

    # Dispose of the mutex object
    $mutex.Dispose()
}

#endregion FIRING UP MODULE STARTER



# Wait-Debugger



#region HANDLE PSF MODERN LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE PSF MODERN LOGGING                                          #
#                                                                                               #
#################################################################################################
# Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

# Define the base logs path and job name
$JobName = "DattoRMM"
$parentScriptName = Get-ParentScriptName
Write-Host "Parent Script Name: $parentScriptName"

# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
# $paramGetPSFCSVLogFilePath = @{
#     LogsPath         = 'C:\Logs\PSF'
#     JobName          = $jobName
#     parentScriptName = $parentScriptName
# }

# $csvLogFilePath = Get-PSFCSVLogFilePath @paramGetPSFCSVLogFilePath

# $instanceName = "$parentScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Configure the PSFramework logging provider to use CSV format
# $paramSetPSFLoggingProvider = @{
#     Name            = 'logfile'
#     InstanceName    = $instanceName  # Use a unique instance name
#     FilePath        = $csvLogFilePath  # Use the dynamically generated file path
#     Enabled         = $true
#     FileType        = 'CSV'
#     EnableException = $true
# }
# Set-PSFLoggingProvider @paramSetPSFLoggingProvider

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
    Write-Host "Starting transcript at: $transcriptPath"
    Start-Transcript -Path $transcriptPath
}
catch {
    Write-Host "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-Host "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-Host "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    # Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    # Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

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

    # ################################################################################################################################
    # ############### CALLING AS SYSTEM to simulate Intune deployment as SYSTEM (Uncomment for debugging) ############################
    # ################################################################################################################################


    # Conditional check for SimulatingIntune switch
    if ($global:SimulatingIntune) {
        # If not running as a web script, run as SYSTEM using PsExec
        Write-EnhancedLog "Simulating Intune environment. Running script as SYSTEM..."

        Write-EnhancedLog "Running as SYSTEM..."

        $ensureRunningAsSystemParams = @{
            PsExec64Path = Join-Path -Path $PSScriptRoot -ChildPath "private\PsExec64.exe"
            ScriptPath   = $MyInvocation.MyCommand.Path
            TargetFolder = Join-Path -Path $PSScriptRoot -ChildPath "private"
        }
    
        Ensure-RunningAsSystem @ensureRunningAsSystemParams
    }
    else {
        Write-EnhancedLog "Not simulating Intune. Skipping SYSTEM execution."
    }


    # Define the parameters for the validation
    $params = @{
        SoftwareName  = "Datto RMM"
        MinVersion    = [version]"4.4.2230.2230"
        LatestVersion = [version]"4.4.2230.2230"
        RegistryPath  = "HKLM:\SOFTWARE\Datto RMM"
        ExePath       = "C:\Program Files (x86)\CentraStage\CagService.exe"
    }

    # Call Validate-SoftwareInstallation
    $validationResult = Validate-SoftwareInstallation @params

    # Logic based on the result of Validate-SoftwareInstallation
    if ($validationResult.IsInstalled) {
        if ($validationResult.MeetsMinRequirement) {
            if ($validationResult.IsUpToDate) {
                Write-Host "$($params.SoftwareName) is installed, meets the minimum requirement, and is up-to-date."
                exit 0  # Software is installed, meets the min version, and is up-to-date
            }
            else {
                Write-Host "$($params.SoftwareName) is installed, meets the minimum requirement, but is not up-to-date. Consider updating."
                exit 1  # Software is installed, meets min version, but is not the latest version
            }
        }
        else {
            Write-Host "$($params.SoftwareName) is installed, but does not meet the minimum version requirement."
            exit 1  # Software is installed but doesn't meet the minimum required version
        }
    }
    else {
        Write-Host "$($params.SoftwareName) is not installed."
        exit 1  # Software is not installed
    }






    
    #endregion Script Logic
}
catch {
    Write-IntuneDetectionScriptLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-Host "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-Host "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    # Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    # Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
} 
finally {
    # Ensure that the transcript is stopped even if an error occurs
    if ($transcriptPath) {
        Stop-Transcript
        Write-Host "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-Host "Transcript was not started due to an earlier error." -ForegroundColor Red
    }
    
    # Ensure the log is written before proceeding
    # Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    # Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false
}