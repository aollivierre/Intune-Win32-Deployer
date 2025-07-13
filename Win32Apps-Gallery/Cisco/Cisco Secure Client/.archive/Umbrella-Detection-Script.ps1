$UmbrellaService = Get-Service -Name "csc_umbrellaagent" -ErrorAction SilentlyContinue
if ($UmbrellaService -and $UmbrellaService.Status -eq "Running") {
    Write-Host "Umbrella service is installed and running"
    Exit 0
} else {
    Write-Host "Umbrella service is not installed or not running"
    Exit 1
}