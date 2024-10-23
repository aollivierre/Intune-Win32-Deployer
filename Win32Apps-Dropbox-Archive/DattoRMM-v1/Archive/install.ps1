#Unique Tracking ID: 3ae26ce2-f482-479a-aa07-9783af19f127, Timestamp: 2024-04-04 18:30:46
# Start the process, wait for it to complete, and optionally hide the window


# Start-Process -FilePath "$d_1002\ServiceUI.exe" -ArgumentList "$d_1002\Deploy-Application.exe" -Wait -WindowStyle Hidden



$d_1002 = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Start-Process -FilePath "$d_1002\Deploy-Application.exe" -Wait -WindowStyle Hidden
