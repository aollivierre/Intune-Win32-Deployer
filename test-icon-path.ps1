# Test script to check icon path handling

$Repo_Path = "C:\Code\Intune-Win32-Deployer"
$imagePath = Join-Path -Path $Repo_Path -ChildPath "resources\template\winget\winget-managed.png"

Write-Host "Repo_Path: $Repo_Path"
Write-Host "imagePath: $imagePath"
Write-Host "Path exists: $(Test-Path -Path $imagePath)"