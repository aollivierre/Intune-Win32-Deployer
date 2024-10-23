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
	[String]$appScriptDate = '09/06/2024'
	[String]$appScriptAuthor = 'AOllivierre'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = 'M365 Apps Update'
	[string]$installTitle = 'M365 Apps Update Utility'

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
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -AllowDefer -DeferDeadline $DeferDeadline -PersistPrompt -ForceCountdown 600

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>


		#Check OneDrive Sync Status prior to prompting user.
		# Start-Transcript -Path $MigrationPath\Logs\LaunchMigration.txt -Append -Force


		# Show-InstallationProgress -Status 'FIRING UP MODULE STARTER'

		# $mode = $env:EnvironmentMode

		#region FIRING UP MODULE STARTER
		#################################################################################################
		#                                                                                               #
		#                                 FIRING UP MODULE STARTER                                      #
		#                                                                                               #
		#################################################################################################
		
		# Define a hashtable for splatting
		# $moduleStarterParams = @{
		# 	Mode                   = $mode
		# 	SkipPSGalleryModules   = $true
		# 	SkipCheckandElevate    = $true
		# 	SkipPowerShell7Install = $true
		# 	SkipEnhancedModules    = $true
		# 	SkipGitRepos           = $true
		# }
		
		# Call the function using the splat
		# Invoke-ModuleStarter @moduleStarterParams
		
		#endregion FIRING UP MODULE STARTER


		Show-InstallationProgress -Status 'HANDLING PSF MODERN LOGGING'

		#region HANDLE PSF MODERN LOGGING
		#################################################################################################
		#                                                                                               #
		#                            HANDLE PSF MODERN LOGGING                                          #
		#                                                                                               #
		#################################################################################################
		Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

		# Define the base logs path and job name
		$JobName = "M365AppsUpdate"
		$parentScriptName = Get-ParentScriptName
		Write-EnhancedLog -Message "Parent Script Name: $parentScriptName"

		# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
		$paramGetPSFCSVLogFilePath = @{
			LogsPath         = 'C:\Logs\PSF'
			JobName          = $jobName
			parentScriptName = $parentScriptName
		}

		$csvLogFilePath = Get-PSFCSVLogFilePath @paramGetPSFCSVLogFilePath

		$instanceName = "$parentScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

		# Configure the PSFramework logging provider to use CSV format
		$paramSetPSFLoggingProvider = @{
			Name            = 'logfile'
			InstanceName    = $instanceName  # Use a unique instance name
			FilePath        = $csvLogFilePath  # Use the dynamically generated file path
			Enabled         = $true
			FileType        = 'CSV'
			EnableException = $true
		}
		Set-PSFLoggingProvider @paramSetPSFLoggingProvider
		#endregion HANDLE PSF MODERN LOGGING

		
		Show-InstallationProgress -Status 'HANDLING Transript LOGGING'

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
			Write-EnhancedLog -Message "Starting transcript at: $transcriptPath"
			Start-Transcript -Path $transcriptPath
		}
		catch {
			Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
			if ($transcriptPath) {
				Stop-Transcript
				Write-EnhancedLog -Message "Transcript stopped." -Level 'NOTICE'
				# Stop logging in the finally block
		
			}
			else {
				Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -Level 'ERROR'
			}

			# Stop PSF Logging

			# Ensure the log is written before proceeding
			Wait-PSFMessage

			# Stop logging in the finally block by disabling the provider
			Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

			Handle-Error -ErrorRecord $_
			throw $_  # Re-throw the error after logging it
		}
		#endregion HANDLE Transript LOGGING

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>


		Show-InstallationProgress -Status 'Calling M365 Updates '


		
		$pwshPath = Get-PowerShellPath

		# Define the path to the deploy-application.ps1 script
		$scriptPath = "$PSScriptRoot\remediation.ps1"
	
		# Ensure the script path is wrapped in quotes if it contains spaces
		$scriptPath = "`"$scriptPath`""
	
		# Define the arguments for the script in an array
		$arguments = @(
			# '-NoExit'
			'-ExecutionPolicy'
			'Bypass'
			'-File'
			$scriptPath  # Path is already enclosed in quotes
		)
	
		# Start the process with the arguments passed as an array
		Start-Process -FilePath $pwshPath -ArgumentList $arguments -Wait


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		# Show-InstallationProgress -Status 'Disabling Task PR4B-AADM Launch PSADT for Interactive Migration'

		# $DisableScheduledTaskByPath = @{
		# 	TaskName = "PR4B-AADM Launch PSADT for Interactive Migration"
		# 	TaskPath = "\AAD Migration\"
		# }
		# Disable-ScheduledTaskByPath @DisableScheduledTaskByPath

		Show-InstallationProgress -Status 'M365 Updates are now completed'

		# Restart-ComputerIfNeeded

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall') {
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair') {
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


	}
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	# Stop-Transcript
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode

	Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
	if ($transcriptPath) {
		Stop-Transcript
		Write-EnhancedLog -Message "Transcript stopped." -Level 'NOTICE'
		# Stop logging in the finally block

	}
	else {
		Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -Level 'ERROR'
	}

	# Stop PSF Logging

	# Ensure the log is written before proceeding
	Wait-PSFMessage

	# Stop logging in the catch block by disabling the provider
	Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

	Handle-Error -ErrorRecord $_
	throw $_  # Re-throw the error after logging it

}
finally {
	# Ensure that the transcript is stopped even if an error occurs
	if ($transcriptPath) {
		Stop-Transcript
		Write-EnhancedLog -Message "Transcript stopped." -Level 'NOTICE'
		# Stop logging in the finally block

	}
	else {
		Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -Level 'ERROR'
	}
    
	# Ensure the log is written before proceeding
	Wait-PSFMessage

	# Stop logging in the finally block by disabling the provider
	Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false
}