﻿<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

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
    [String]$DeployMode = 'Interactive',
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
    #region VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = ''
    [String]$appName = ''
    [String]$appVersion = ''
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '10/16/2024'
    [String]$appScriptAuthor = 'AOllivierre'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = 'Datto RMM'
    [string]$installTitle = 'Datto RMM Install Utility'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.2'
    [String]$deployAppScriptDate = '08/13/2024'
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
    #endregion END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* MARK: PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>


        ##*===============================================
        ##* MARK: INSTALLATION
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






        # C:\code\AdobePro-v1\Files\setup.exe /sAll /rs /rps /msi /norestart /quiet EULA_ACCEPT=YES

        # C:\code\AdobePro-v1\Files\setup.exe /sAll /rs /rps /msi /norestart /quiet EULA_ACCEPT=YES

        # # Define the setup file relative to this script's location
        # $setupExePath = Join-Path -Path $PSScriptRoot -ChildPath "Files\setup.exe"

        # # Define the arguments for the setup
        # $setupArgs = "/sAll /rs /rps /msi /norestart /quiet EULA_ACCEPT=YES"

        # # Start the setup process
        # Start-Process -FilePath $setupExePath -ArgumentList $setupArgs -NoNewWindow -Wait



        # Execute-Process -Path "d.exe" -Parameters "--key 667ui7yht7 --url https://rmmvid81500001.infocyte.com" -WindowStyle 'Hidden'
        # Execute-Process -Path "setup.exe" -Parameters "/sAll /rs /rps /msi /norestart /quiet EULA_ACCEPT=YES" -WindowStyle 'Hidden'



        (New-Object System.Net.WebClient).DownloadFile("https://vidal.centrastage.net/csm/profile/downloadAgent/577b2e35-7123-4816-8f71-ebcd7ff6d186", "$env:TEMP/AgentInstall.exe"); start-process "$env:TEMP/AgentInstall.exe"


        function WaitForRegistryKey {
            param (
                [string[]]$RegistryPaths,
                [string]$SoftwareName,
                [version]$MinimumVersion,
                [int]$TimeoutSeconds = 120
            )
        
            $elapsedSeconds = 0
        
            while ($elapsedSeconds -lt $TimeoutSeconds) {
                # Write-Output "Checking registry for $SoftwareName version $MinimumVersion or later... (Elapsed time: $elapsedSeconds seconds)"
        
                foreach ($path in $RegistryPaths) {
                    $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        
                    foreach ($item in $items) {
                        $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
                        if ($app.DisplayName -like "*$SoftwareName*") {
                            $installedVersion = New-Object Version $app.DisplayVersion
                            if ($installedVersion -ge $MinimumVersion) {
                                Write-Output "Found $SoftwareName version $installedVersion at $item.PsPath."
                                return @{
                                    IsInstalled = $true
                                    Version     = $app.DisplayVersion
                                    ProductCode = $app.PSChildName
                                }
                            }
                        }
                    }
                }
        
                Start-Sleep -Seconds 1
                $elapsedSeconds++
            }
        
            Write-Output "Timeout reached. $SoftwareName version $MinimumVersion or later not found."
            return @{IsInstalled = $false }
        }
        
        



        # Define constants for registry paths and minimum required version
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        $targetSoftwareName = "*Datto RMM*"
        $minimumVersion = New-Object Version "4.4.2230.2230"

        # Main script execution block
        $installationCheck = WaitForRegistryKey -RegistryPaths $registryPaths -SoftwareName $targetSoftwareName -MinimumVersion $minimumVersion -TimeoutSeconds 120

        if ($installationCheck.IsInstalled) {
            # Write-Output "DattoRMM version $($installationCheck.Version) or later is installed."
            # exit 0
        }
        else {
            # Write-Output "DattoRMM version $minimumVersion or later is not installed."
            # exit 1
        }






        ##*===============================================
        ##* MARK: POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* MARK: PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* MARK: UNINSTALLATION
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




        # Execute-Process -Path "C:\Program Files\infocyte\agent\agent.exe" -Parameters  "--uninstall" -WindowStyle 'Hidden'
        # Execute-Process -Path "C:\Program Files (x86)\CentraStage\uninst.exe" -Parameters  "--uninstall" -WindowStyle 'Hidden'
        # Execute-Process -Path "C:\Program Files (x86)\CentraStage\uninst.exe" -Parameters  "/s" -WindowStyle 'Hidden'
        # Execute-Process -Path "C:\Program Files\CentraStage\uninst.exe" -Parameters  "/s" -WindowStyle 'Hidden'



        # Define the paths
        $path1 = "C:\Program Files (x86)\CentraStage\uninst.exe"
        $path2 = "C:\Program Files\CentraStage\uninst.exe"

        # Check if the first path exists before executing
        if (Test-Path -Path $path1) {
            Write-EnhancedLog -Message "Executing process at $path1" -Level "INFO"
            Execute-Process -Path $path1 -Parameters "/s" -WindowStyle 'Hidden'
        }
        else {
            Write-EnhancedLog -Message "Path $path1 does not exist. Skipping execution." -Level "WARNING"
        }

        # Check if the second path exists before executing
        if (Test-Path -Path $path2) {
            Write-EnhancedLog -Message "Executing process at $path2" -Level "INFO"
            Execute-Process -Path $path2 -Parameters "/s" -WindowStyle 'Hidden'
        }
        else {
            Write-EnhancedLog -Message "Path $path2 does not exist. Skipping execution." -Level "WARNING"
        }



        ##*===============================================
        ##* MARK: POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* MARK: PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* MARK: REPAIR
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
        ##* MARK: POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }

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
