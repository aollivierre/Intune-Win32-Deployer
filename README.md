# Accuro Prerequisites Installer

## Overview
This PowerShell script automates the installation of Accuro prerequisites in a parallel execution model. It handles the installation of three critical components:
- Citrix Workspace
- ScrewDrivers Client
- Cloudwerx Plugin

## Key Features
- Parallel installation of components
- Robust error handling and logging
- Thread-safe operations
- Smart timeout management
- Intelligent installation verification
- Automatic cleanup

## Technical Details

### Core Functions

#### 1. Write-AccuroPrerequisitesLog
- Thread-safe logging mechanism using mutex
- Supports multiple logging levels (Information, Warning, Error)
- Maintains consistent log format across parallel processes
- Uses CMTrace-compatible log format

#### 2. Installation Functions
- `Install-CitrixWorkspace`: Handles Citrix installation with special timeout handling
- `Install-ScrewDriversClient`: Manages ScrewDrivers MSI installation
- `Install-CloudwerxPlugin`: Handles Cloudwerx ZIP extraction and installation

### Parallel Processing Mechanism

The script implements parallel processing through PowerShell jobs:
```powershell
$jobs = @(
    @{
        Name = 'Citrix'
        Job = Start-Job
        Timeout = 60
        ForceStop = $true
    },
    # Similar structure for ScrewDrivers and Cloudwerx
)
```

### Download Management

#### Challenges Faced:
1. BITS transfer failures in certain environments
2. Network connectivity issues
3. Incomplete downloads

#### Solution Implemented:
- Two-tier download approach:
  1. WebClient as primary method
  2. BITS transfer as fallback
- Retry mechanism with configurable attempts
- File integrity verification after download

```powershell
function Start-FileDownloadWithRetry {
    # Primary: WebClient
    # Fallback: BITS
    # Verification: File size and existence
}
```

### Citrix Installation Challenges

#### Problems Encountered:
1. Installation process hanging indefinitely
2. False failure reports despite successful installation
3. Residual processes preventing completion

#### Solutions Implemented:
1. **Smart Timeout Management**:
   - 60-second timeout for main installation
   - Installation success verification before timeout
   - Process cleanup after timeout

2. **Installation Verification**:
   ```powershell
   - Check core files (wfica32.exe)
   - Verify registry entries
   - Validate service status
   ```

3. **Process Management**:
   - Thorough process cleanup
   - Force-stop capability for hung processes
   - Comprehensive process matching patterns

### Thread Safety

#### Implemented Mechanisms:
1. Mutex for log file access
2. Isolated process spaces through jobs
3. Atomic operations for critical sections

Example:
```powershell
$mutex = New-Object System.Threading.Mutex($false, "Global\AccuroPrerequisitesLogMutex")
try {
    $mutex.WaitOne()
    # Critical section
}
finally {
    $mutex.ReleaseMutex()
}
```

## Usage

### Prerequisites
- PowerShell 5.1 or higher
- Administrative privileges
- Network connectivity to download sources

### Execution
```powershell
.\Install-AccuroPrerequisites.ps1
```

### Exit Codes
- 0: Success
- 1: Failure (check logs for details)

## Logging

### Location
- Main log: `%TEMP%\AccuroPrerequisites_Install.log`
- Citrix specific: `%TEMP%\AccuroPrerequisites_Install.log.citrix.log`

### Format
```
<![LOG[Message]LOG]!><time="HH:mm:ss.ms" date="MM-dd-yyyy" component="Script" type="Level">
```

## Best Practices and Lessons Learned

1. **Parallel Installation**
   - Benefits: Reduced total installation time
   - Challenges: Resource contention, logging conflicts
   - Solution: Mutex-based synchronization

2. **Download Strategy**
   - Primary/Fallback approach more reliable than single method
   - Verify downloads before installation
   - Handle network interruptions gracefully

3. **Process Management**
   - Don't assume process completion means installation success
   - Implement thorough verification
   - Clean up residual processes

4. **Error Handling**
   - Verify installation success through multiple methods
   - Log all significant events
   - Provide clear status messages

## Troubleshooting

### Common Issues

1. **Citrix Installation Hanging**
   - Normal behavior - installation continues in background
   - 60-second timeout is sufficient
   - Verify installation through registry/files

2. **Download Failures**
   - Check network connectivity
   - Verify URL accessibility
   - Review logs for specific error messages

3. **Process Cleanup**
   - Manual cleanup might be needed in rare cases
   - Use Task Manager to verify process termination
   - Check logs for process IDs

## Future Improvements

1. **Installation Verification**
   - Add more verification methods
   - Implement version checking
   - Add rollback capability

2. **Download Management**
   - Add support for proxy configurations
   - Implement bandwidth throttling
   - Add checksum verification

3. **Logging**
   - Add log rotation
   - Implement log compression
   - Add telemetry options

## Contributing
Please submit issues and pull requests for any improvements. 