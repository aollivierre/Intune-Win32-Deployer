# Reload authentication token from saved file

$tokenFile = Join-Path $env:TEMP "intune_auth_token.json"

if (Test-Path $tokenFile) {
    Write-Host "Found saved token file. Reloading..." -ForegroundColor Yellow
    
    $tokenData = Get-Content $tokenFile -Raw | ConvertFrom-Json
    
    # Set up global variables
    $expiresOn = [DateTime]::Parse($tokenData.ExpiresOn).ToUniversalTime()
    
    $Global:AccessToken = [PSCustomObject]@{
        AccessToken = $tokenData.AccessToken
        ExpiresOn = $expiresOn
        TokenType = $tokenData.TokenType
    }
    
    $Global:AccessTokenTenantID = $tokenData.TenantId
    $Global:AuthenticationHeader = @{
        "Content-Type" = "application/json"
        "Authorization" = "$($tokenData.TokenType) $($tokenData.AccessToken)"
        "ExpiresOn" = $expiresOn.ToString()
    }
    
    # Store additional globals
    $Global:TenantId = $tokenData.TenantId
    $Global:ClientId = $tokenData.ClientId
    
    Write-Host "Token reloaded successfully!" -ForegroundColor Green
    Write-Host "Token expires at: $expiresOn" -ForegroundColor Cyan
    
    # Now check the types
    Write-Host "`nToken object details:" -ForegroundColor Yellow
    Write-Host "AccessToken type: $($Global:AccessToken.GetType().FullName)" -ForegroundColor Cyan
    Write-Host "ExpiresOn type: $($Global:AccessToken.ExpiresOn.GetType().FullName)" -ForegroundColor Cyan
    Write-Host "ExpiresOn value: $($Global:AccessToken.ExpiresOn)" -ForegroundColor Cyan
    
    # Test with IntuneWin32App module
    Write-Host "`nTesting IntuneWin32App module..." -ForegroundColor Yellow
    Import-Module IntuneWin32App -ErrorAction Stop
    
    try {
        $apps = Get-IntuneWin32App -ErrorAction Stop
        Write-Host "Successfully called Get-IntuneWin32App!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Full error:" -ForegroundColor Red
        $_ | Format-List -Force
    }
}
else {
    Write-Host "No saved token file found at: $tokenFile" -ForegroundColor Red
    Write-Host "Please run the main script first to authenticate." -ForegroundColor Yellow
}