#region RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION
#################################################################################################
#                                                                                               #
#                           RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION                           #
#                                                                                               #
#################################################################################################

function Relaunch-InPowerShell5 {
    # Check the current version of PowerShell
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "Hello from PowerShell 7"

        # Get the script path (works inside a function as well)
        $scriptPath = $PSCommandPath

        # $scriptPath = $MyInvocation.MyCommand.Definition
        $ps5Path = "$($env:SystemRoot)\System32\WindowsPowerShell\v1.0\powershell.exe"

        # Build the argument to relaunch this script in PowerShell 5 with -NoExit
        $ps5Args = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        Write-Host "Relaunching in PowerShell 5..."
        Start-Process -FilePath $ps5Path -ArgumentList $ps5Args

        # Exit the current PowerShell 7 session to allow PowerShell 5 to take over
        exit
    }

    # If relaunching in PowerShell 5
    Write-Host "Hello from PowerShell 5"
}

Relaunch-InPowerShell5

#endregion RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION
#################################################################################################
#                                                                                               #
#                           END OF RE-LAUNCH SCRIPT IN POWERSHELL 5 FUNCTION                    #
#                                                                                               #
#################################################################################################
