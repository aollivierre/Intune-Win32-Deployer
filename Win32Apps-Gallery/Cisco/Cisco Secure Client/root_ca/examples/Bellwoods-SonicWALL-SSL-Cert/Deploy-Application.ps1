#Unique Tracking ID: 50ed2b1e-b96b-437b-b3ac-d035dc575793, Timestamp: 2024-02-15 13:23:30
<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'silent',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = ''
    [String]$appName = ''
    [String]$appVersion = ''
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = 'XX/XX/20XX'
    [String]$appScriptAuthor = '<author name>'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy SonicWALL SSL Inspection Cert'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>

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


$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

function Import-CertificateOnly {
    param(
        [string]$CertificatePathRelativeToscriptDirectory
    )

    $CertPath = Join-Path -Path $scriptDirectory -ChildPath $CertificatePathRelativeToscriptDirectory

    # Write-Host "Certificate import script started."
    # Write-Host "Certificate Path: $CertPath"

    # Check if the certificate file exists
    if (Test-Path -Path $CertPath) {
        # Write-Host "Certificate file found. Proceeding with import..."
        Try {
            Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
            Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\CurrentUser\TrustedPublisher
            # Write-Host "Certificate imported successfully."
        }
        Catch {
            # Write-Host "Failed to import certificate. Error: $_"
        }
    }
    else {
        # Write-Host "Certificate file does not exist at the specified path: $CertPath"
    }
}

# Usage example



$CertificatePathRelativeToscriptDirectory = "sonicwall.cer"
Import-CertificateOnly -CertificatePathRelativeToscriptDirectory $CertificatePathRelativeToscriptDirectory




        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            # Show-InstallationPrompt -Message 'You should now see FortiClient VPN v7.2.3.0929 in your task bar' -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>

        

        function Remove-PrinterAndCleanup {
            param(
                [Parameter(Mandatory)]
                [string]$PrinterName,
                # [string]$DriverName,
                [string]$PortName
            )
        
            # Remove Printer
            if (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue) {
                Remove-Printer -Name $PrinterName -Confirm:$false
                # Write-Host "Printer '$PrinterName' removed."
                Start-Sleep -Seconds 120
            }
        
            # Remove Printer Port
            $portExists = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
            if ($portExists) {
                Remove-PrinterPort -Name $PortName -Confirm:$false
                # Write-Host "Printer port '$PortName' removed."
                Start-Sleep -Seconds 120
            }
        }
        
        # Set parameters here
        $PrinterName = "SHARP SHAW Staff"
        # $DriverName = "SHARP MX-3071 PCL6" # Adjust as necessary
        $PortName = "IP_192.168.41.20" # Adjust as necessary
        # $InfFileName = "su2emenu.inf" # Adjust as necessary
        
        # Call the function with specified parameters
        # Remove-PrinterAndCleanup -PrinterName $PrinterName -DriverName $DriverName -PortName $PortName -InfFileName $InfFileName
        # Remove-PrinterAndCleanup -PrinterName $PrinterName -DriverName $DriverName -PortName $PortName
        Remove-PrinterAndCleanup -PrinterName $PrinterName -PortName $PortName


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>

        # Restart-Computer -Force


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
