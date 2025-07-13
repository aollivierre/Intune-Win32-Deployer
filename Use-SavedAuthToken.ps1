# Function to load authentication token saved by PowerShell 7
function Set-IntuneAuthFromSavedToken {
    param(
        [string]$TokenFile = (Join-Path $env:TEMP "intune_auth_token.json")
    )
    
    try {
        if (-not (Test-Path $TokenFile)) {
            throw "Token file not found. Please run Get-AuthTokenPS7.ps1 first."
        }
        
        # Load the token data
        $tokenData = Get-Content $TokenFile -Raw | ConvertFrom-Json
        
        # Check if token is still valid
        $expiresOn = [DateTime]::Parse($tokenData.ExpiresOn).ToUniversalTime()
        $now = [DateTime]::UtcNow
        
        Write-Host "Token expires at: $expiresOn UTC" -ForegroundColor Cyan
        Write-Host "Current time: $now UTC" -ForegroundColor Cyan
        
        if ($expiresOn -lt $now) {
            throw "Token has expired. Please run Get-AuthTokenPS7.ps1 again."
        }
        
        Write-Host "Token is valid until: $expiresOn UTC" -ForegroundColor Green
        
        # Set the global variables that IntuneWin32App module expects
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
        
        # Store for potential re-authentication
        $Global:TenantId = $tokenData.TenantId
        $Global:ClientId = $tokenData.ClientId
        
        Write-Host "Authentication loaded from saved token successfully!" -ForegroundColor Green
        
        # Test the authentication
        try {
            $testUri = "https://graph.microsoft.com/v1.0/organization"
            $testResult = Invoke-RestMethod -Uri $testUri -Headers $Global:AuthenticationHeader -Method Get -ErrorAction Stop
            Write-Host "Authentication verified - connected to: $($testResult.value[0].displayName)" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Warning "Authentication test failed: $_"
            return $false
        }
    }
    catch {
        Write-Host "Failed to load authentication from saved token: $_" -ForegroundColor Red
        return $false
    }
}

# Example usage in your main script:
# Just call this function instead of the authentication block
if (Set-IntuneAuthFromSavedToken) {
    Write-Host "Ready to use IntuneWin32App module functions!" -ForegroundColor Green
    
    # Test with IntuneWin32App module
    try {
        Import-Module IntuneWin32App -ErrorAction Stop
        $apps = Get-IntuneWin32App -ErrorAction Stop | Select-Object -First 5
        if ($apps) {
            Write-Host "Successfully retrieved $($apps.Count) Win32 apps" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "IntuneWin32App test: $_" -ForegroundColor Yellow
    }
}