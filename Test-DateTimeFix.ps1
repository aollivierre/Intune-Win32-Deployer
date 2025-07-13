# Test if the DateTime fix works

Write-Host "Testing DateTime fix for IntuneWin32App module..." -ForegroundColor Yellow

# First delete the old token to force re-authentication
$tokenFile = Join-Path $env:TEMP "intune_auth_token.json"
if (Test-Path $tokenFile) {
    Remove-Item $tokenFile -Force
    Write-Host "Removed old token file" -ForegroundColor Yellow
}

# Load the authentication function
. .\Test-AuthOnly.ps1

# The script above should have created new authentication with proper DateTimeOffset
# Now test if it works

Write-Host "`n`nChecking fixed authentication state..." -ForegroundColor Yellow
Write-Host "AccessToken type: $($Global:AccessToken.GetType().FullName)" -ForegroundColor Cyan
Write-Host "ExpiresOn type: $($Global:AccessToken.ExpiresOn.GetType().FullName)" -ForegroundColor Cyan
Write-Host "ExpiresOn value: $($Global:AccessToken.ExpiresOn)" -ForegroundColor Cyan

# Test with IntuneWin32App module
Write-Host "`nTesting IntuneWin32App module with fixed DateTime..." -ForegroundColor Yellow
Import-Module IntuneWin32App -ErrorAction Stop

try {
    $apps = Get-IntuneWin32App -ErrorAction Stop | Select-Object -First 5
    Write-Host "SUCCESS! Get-IntuneWin32App works with the DateTime fix!" -ForegroundColor Green
    
    if ($apps) {
        Write-Host "Found $($apps.Count) apps" -ForegroundColor Cyan
        $apps | ForEach-Object { Write-Host "  - $($_.displayName)" -ForegroundColor Gray }
    }
    else {
        Write-Host "No apps found, but the command executed successfully!" -ForegroundColor Green
    }
}
catch {
    Write-Host "Still getting error: $_" -ForegroundColor Red
    Write-Host "`nFull error details:" -ForegroundColor Red
    $_ | Format-List -Force
}