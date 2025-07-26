#Unique Tracking ID: 50ed2b1e-b96b-437b-b3ac-d035dc575793, Timestamp: 2024-02-15 13:23:30
# Start the process, wait for it to complete, and optionally hide the window

$d_1002 = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
# Start-Process -FilePath "$d_1002\ServiceUI.exe" -ArgumentList "$d_1002\Deploy-Application.exe" -Wait -WindowStyle Hidden
Start-Process -FilePath "$d_1002\Deploy-Application.exe" -Wait -WindowStyle Hidden
