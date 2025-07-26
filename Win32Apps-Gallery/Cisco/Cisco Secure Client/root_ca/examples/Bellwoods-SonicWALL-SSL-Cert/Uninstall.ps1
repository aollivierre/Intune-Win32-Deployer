#Unique Tracking ID: 50ed2b1e-b96b-437b-b3ac-d035dc575793, Timestamp: 2024-02-15 13:23:30
$d_1002 = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
# Start-Process -FilePath "$d_1002\ServiceUI.exe" -ArgumentList "$d_1002\Deploy-Application.exe -DeploymentType `"Uninstall`"" -Wait -WindowStyle Hidden


Start-Process -FilePath "$d_1002\Deploy-Application.exe" -ArgumentList "-DeploymentType `"Uninstall`"" -Wait -WindowStyle Hidden

# Start-Process -FilePath ".\sara\SaRAcmd.exe" -ArgumentList "-S OfficeScrubScenario -AcceptEula -OfficeVersion All" -wait -WindowStyle Hidden
# Start-Process -FilePath "C:\Users\AOllivierre_CloudAdm\Downloads\SaRACmd_17_01_0495_021\SaRACmd.exe" -ArgumentList "-S OfficeScrubScenario -AcceptEula -OfficeVersion All" -wait -WindowStyle Hidden
