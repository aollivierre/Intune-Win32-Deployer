# Fix for the DateTime conversion error in Add-IntuneWin32App

Write-Host "Checking current authentication state..." -ForegroundColor Yellow

# Check the current global variables
Write-Host "`nGlobal:AccessToken type: $($Global:AccessToken.GetType().FullName)" -ForegroundColor Cyan
Write-Host "Global:AccessToken properties:" -ForegroundColor Cyan
$Global:AccessToken | Get-Member -MemberType Properties | Format-Table

Write-Host "`nGlobal:AuthenticationHeader:" -ForegroundColor Cyan
$Global:AuthenticationHeader | Format-Table

# The issue is that the IntuneWin32App module might be expecting additional properties
# Let's check what Add-IntuneWin32App is actually receiving

# Test creating a minimal app to see what fails
Write-Host "`nTesting minimal Add-IntuneWin32App call..." -ForegroundColor Yellow

try {
    # First, let's see if we can query existing apps
    $existingApps = Get-IntuneWin32App -ErrorAction SilentlyContinue
    if ($existingApps) {
        Write-Host "Found $($existingApps.Count) existing apps" -ForegroundColor Green
    }
    else {
        Write-Host "No existing apps found or unable to query" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error querying apps: $_" -ForegroundColor Red
}

# The real issue might be that we need to ensure the module has the correct internal state
# Let's check the module's internal variables
Write-Host "`nChecking IntuneWin32App module internal state..." -ForegroundColor Yellow

# Get the module
$module = Get-Module IntuneWin32App
if ($module) {
    Write-Host "Module version: $($module.Version)" -ForegroundColor Cyan
    
    # Check if there are any internal functions we can use
    $commands = Get-Command -Module IntuneWin32App
    Write-Host "Available commands: $($commands.Count)" -ForegroundColor Cyan
}

# Potential fix: Ensure the AccessToken has all required properties
Write-Host "`nApplying DateTime fix..." -ForegroundColor Yellow

# The issue might be that ExpiresOn needs to be a specific type
if ($Global:AccessToken.ExpiresOn -is [string]) {
    Write-Host "Converting ExpiresOn from string to DateTime..." -ForegroundColor Yellow
    
    # Create a new token object with proper DateTime
    $fixedToken = [PSCustomObject]@{
        AccessToken = $Global:AccessToken.AccessToken
        TokenType = $Global:AccessToken.TokenType
        ExpiresOn = [DateTime]::Parse($Global:AccessToken.ExpiresOn)
        TenantId = $Global:AccessTokenTenantID
    }
    
    # Replace the global token
    $Global:AccessToken = $fixedToken
    Write-Host "AccessToken fixed with proper DateTime" -ForegroundColor Green
}

# Also ensure the authentication header has proper format
if ($Global:AuthenticationHeader.ExpiresOn -is [string]) {
    $Global:AuthenticationHeader.ExpiresOn = [DateTime]::Parse($Global:AuthenticationHeader.ExpiresOn).ToString()
}

Write-Host "`nAuthentication state after fix:" -ForegroundColor Green
Write-Host "AccessToken.ExpiresOn type: $($Global:AccessToken.ExpiresOn.GetType().FullName)" -ForegroundColor Cyan
Write-Host "AccessToken.ExpiresOn value: $($Global:AccessToken.ExpiresOn)" -ForegroundColor Cyan