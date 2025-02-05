$msiPath = Resolve-Path ".\TV.msi"
$settingsFilePath = Resolve-Path ".\s.tvopt"
Start-Process -FilePath "MSIEXEC.EXE" -ArgumentList "/i", $msiPath, "/qn", "CUSTOMCONFIGID=he26pyq", "SETTINGSFILE=$settingsFilePath" -Wait
Start-Sleep -Seconds 30
Start-Process -FilePath "C:\Program Files (x86)\TeamViewer\TeamViewer.exe" -ArgumentList "assignment", "--id", "0001CoABChA0Wtyw41UR74SOzFGxK_rXEigIACAAAgAJACbSLLKpBBA6xZ-LyQnQTR-eZS-k2LbZwnYA3hzgn3SyGkDPy2YN1c_GAI_NPqig6Pj2KlsEx8tWXmtGjlI2edd2S45EsUzHcwJ7NxQ8FYG76qUp2Y4MyeLXBJ5zKbYzGP2uIAEQ9-LB8g0="