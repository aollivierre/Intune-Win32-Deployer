# Lexmark MX331adn Printer Deployment for Deauville

This repository contains an Intune Win32 app deployment solution for the Lexmark MX331adn printer, utilizing a two-package strategy with Intune's supersedence feature for clean deployment.

## Repository Structure

```
├── PRINT-012-LexmarkMX331adn-Deauville-withnoPSADT-v10/    # Main installation package
│   ├── Driver/                 # Printer driver files
│   ├── Private/               # Private PowerShell functions
│   ├── check-AsSystem.ps1     # System context detection script
│   ├── Check.ps1             # Detection script
│   ├── config.json           # Package configuration
│   ├── install.ps1           # Installation script
│   ├── printer.json          # Printer configuration
│   ├── Uninstall.ps1        # Uninstallation script
│   └── Invoke-InstallCMD.ps1 # Installation command wrapper
│
└── PRINT-012-LexmarkMX331adn-Deauville-withnoPSADT-v10 Uninstall/    # Cleanup package
    ├── Driver/               # Printer driver files
    ├── Private/             # Private PowerShell functions
    ├── Check.ps1           # Detection script
    ├── config.json         # Package configuration
    ├── install.ps1         # Installation script
    ├── printer.json        # Printer configuration
    ├── Uninstall.ps1      # Uninstallation script
    └── Invoke-InstallCMD.ps1 # Installation command wrapper
```

## Deployment Strategy

This solution uses a sophisticated two-package approach leveraging Intune's supersedence feature:

1. **Cleanup Package** (Uninstall directory):
   - Deployed first as an older version
   - Purpose: Remove existing printer configurations
   - Ensures clean slate before new installation
   - Prevents conflicts with existing printer setups

2. **Installation Package** (Main directory):
   - Deployed as newer version that supersedes the cleanup package
   - Installs printer with standardized configuration
   - Runs remediation checks every 60 minutes
   - Maintains desired printer state

## Required Customizations

When setting up a new printer deployment, the following files must be modified:

1. **printer.json**:
   ```json
   {
     "PrinterName": "Your Printer Name",
     "PrinterIPAddress": "Your.Printer.IP",
     "PortName": "IP_Your.Printer.IP",
     "DriverName": "Your Driver Name",
     "InfPathRelative": "Driver\\YourDriver.inf",
     "InfFileName": "YourDriver.inf",
     "DriverIdentifier": "your_driver_identifier"
   }
   ```

2. **config.json**:
   ```json
   {
     "PackageName": "Your-Package-Name",
     "PackageUniqueGUID": "your-unique-guid",
     "Version": 1,
     "PackageExecutionContext": "SYSTEM",
     "RepetitionInterval": "PT60M",
     "LoggingDeploymentName": "Your-Package-Name-Customlog",
     "ScriptMode": "Remediation"
   }
   ```

3. **Check.ps1**:
   - Contains embedded JSON configuration at the top
   - Must match printer.json configuration exactly
   - Update the JSON string in the `$json = @'...'@` block

4. **check-AsSystem.ps1**:
   - Also contains embedded JSON configuration
   - Must match printer.json configuration exactly
   - Update the JSON string in the `$json = @'...'@` block

5. **Driver/ Directory**:
   - Replace with appropriate printer driver files
   - Update INF file references in printer.json to match

## Key Scripts

- **Check.ps1**: Validates printer installation state
- **install.ps1**: Handles printer installation
- **Uninstall.ps1**: Manages printer removal
- **check-AsSystem.ps1**: System context validation
- **Invoke-InstallCMD.ps1**: Installation command wrapper

## Intune Setup Instructions

1. **Create Cleanup Package**:
   - Package source: `PRINT-012-LexmarkMX331adn-Deauville-withnoPSADT-v10 Uninstall`
   - Install command: Path to `install.ps1`
   - Uninstall command: Path to `Uninstall.ps1`
   - Detection rule: Using `Check.ps1`
   - Set as older version (e.g., 1.0.0)

2. **Create Installation Package**:
   - Package source: `PRINT-012-LexmarkMX331adn-Deauville-withnoPSADT-v10`
   - Install command: Path to `install.ps1`
   - Uninstall command: Path to `Uninstall.ps1`
   - Detection rule: Using `Check.ps1`
   - Set as newer version (e.g., 2.0.0)
   - Configure supersedence to replace cleanup package

## Benefits of This Approach

1. **Clean Installation**:
   - Removes existing configurations before new installation
   - Prevents conflicts with existing printer setups
   - Ensures consistent deployment state

2. **Maintenance**:
   - Regular remediation checks (every 60 minutes)
   - Automatic repair of printer configuration
   - System context execution

3. **Reliability**:
   - Two-phase deployment ensures thorough cleanup
   - Standardized configuration across deployments
   - Robust error handling

## Notes

- Both packages use SYSTEM context for execution
- Remediation runs every 60 minutes to maintain configuration
- Unique GUID ensures proper tracking and management
- No PSADT dependency for simpler deployment
- **Important**: Ensure all JSON configurations match across files (printer.json, Check.ps1, check-AsSystem.ps1)

## Requirements

- Windows 10 or later
- Intune access and configuration rights
- Network connectivity to printer
- Administrative privileges for installation 