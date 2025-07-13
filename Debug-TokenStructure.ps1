# Debug script to understand what token structure IntuneWin32App expects

Write-Host "Analyzing IntuneWin32App module expectations..." -ForegroundColor Yellow

# First, let's see what a real MSAL token looks like when obtained directly
Write-Host "`nGetting a fresh MSAL token to examine its structure..." -ForegroundColor Cyan

# Load secrets
$secretsPath = "C:\Code\Intune-Win32-Deployer\secrets\Lion's Housing Centres\secrets.json"
$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json

# Try to get a token using MSAL.PS directly in PS5
try {
    Import-Module MSAL.PS -ErrorAction Stop
    
    # This will fail with CNG cert, but we want to see the error
    $certPath = "C:\Code\GraphAppwithCert\Graph\Lion's Housing Centres\GraphCert-Lion's Housing Centres-$($secrets.ClientId).pfx"
    
    Write-Host "Attempting direct MSAL in PS5 (expected to fail with CNG)..." -ForegroundColor Yellow
    
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $secrets.CertPassword)
        $token = Get-MsalToken -TenantId $secrets.TenantID -ClientId $secrets.ClientId -ClientCertificate $cert
    }
    catch {
        Write-Host "Expected CNG error: $_" -ForegroundColor Gray
    }
}
catch {
    Write-Host "MSAL.PS error: $_" -ForegroundColor Red
}

# Now let's create what we think the module expects
Write-Host "`n`nCreating mock token structure that IntuneWin32App might expect..." -ForegroundColor Yellow

# The module's Test-AccessToken tries to access:
# $Global:AccessToken.ExpiresOn.ToUniversalTime().UtcDateTime

# This suggests ExpiresOn should be a DateTimeOffset that has these methods
$now = Get-Date
$expiresIn1Hour = $now.AddHours(1)

# Create different variations to test
Write-Host "`nVariation 1: ExpiresOn as DateTime" -ForegroundColor Cyan
$token1 = [PSCustomObject]@{
    AccessToken = "dummy-token"
    ExpiresOn = $expiresIn1Hour
    TokenType = "Bearer"
}
Write-Host "ExpiresOn type: $($token1.ExpiresOn.GetType().FullName)" -ForegroundColor Gray
try {
    $test = $token1.ExpiresOn.ToUniversalTime().UtcDateTime
    Write-Host "Can call .ToUniversalTime().UtcDateTime: NO (DateTime doesn't have UtcDateTime property)" -ForegroundColor Red
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`nVariation 2: ExpiresOn as DateTimeOffset" -ForegroundColor Cyan
$token2 = [PSCustomObject]@{
    AccessToken = "dummy-token"
    ExpiresOn = [DateTimeOffset]::new($expiresIn1Hour)
    TokenType = "Bearer"
}
Write-Host "ExpiresOn type: $($token2.ExpiresOn.GetType().FullName)" -ForegroundColor Gray
try {
    $test = $token2.ExpiresOn.ToUniversalTime().UtcDateTime
    Write-Host "Can call .ToUniversalTime().UtcDateTime: YES" -ForegroundColor Green
    Write-Host "Result: $test" -ForegroundColor Gray
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`nVariation 3: What MSAL.PS actually returns" -ForegroundColor Cyan
# MSAL.PS returns a Microsoft.Identity.Client.AuthenticationResult
# which has ExpiresOn as DateTimeOffset

# Let's see what properties the module actually needs
Write-Host "`nChecking IntuneWin32App module's Test-AccessToken function..." -ForegroundColor Yellow
$testAccessTokenPath = "C:\Program Files\WindowsPowerShell\Modules\IntuneWin32App\1.4.4\Public\Test-AccessToken.ps1"
$content = Get-Content $testAccessTokenPath -Raw
if ($content -match 'ExpiresOn\.(\w+)\.(\w+)') {
    Write-Host "Found: Module expects ExpiresOn.$($Matches[1]).$($Matches[2])" -ForegroundColor Cyan
}

Write-Host "`n`nRECOMMENDATION:" -ForegroundColor Green
Write-Host "The Global:AccessToken.ExpiresOn must be a DateTimeOffset object" -ForegroundColor Yellow
Write-Host "because the module calls: .ToUniversalTime().UtcDateTime on it" -ForegroundColor Yellow