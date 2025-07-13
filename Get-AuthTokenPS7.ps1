# This script runs in PowerShell 7 to get the authentication token
# It saves the token to a file that the main PS5 script can read

param(
    [string]$SecretsPath = "C:\Code\Intune-Win32-Deployer\secrets\Lion's Housing Centres\secrets.json"
)

# Ensure we're running in PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script must run in PowerShell 7 or higher" -ForegroundColor Red
    Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    exit 1
}

Write-Host "Running in PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

# Import MSAL.PS
Import-Module MSAL.PS -ErrorAction Stop

# Load secrets
$secrets = Get-Content $SecretsPath -Raw | ConvertFrom-Json
$tenantId = $secrets.TenantID
$clientId = $secrets.ClientId
$certPassword = $secrets.CertPassword

# Construct certificate path
$outputPath = $secrets.OutputPath
$certName = $secrets.CertName
$certPath = Join-Path $outputPath "$certName-$clientId.pfx"

Write-Host "Loading certificate from: $certPath" -ForegroundColor Cyan

# Load certificate - PS7 handles CNG certificates better
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath, $certPassword)
Write-Host "Certificate loaded. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

# Get token
Write-Host "Requesting token from Azure AD..." -ForegroundColor Yellow
$msalToken = Get-MsalToken -TenantId $tenantId -ClientId $clientId -ClientCertificate $cert

if ($msalToken) {
    Write-Host "Token obtained successfully!" -ForegroundColor Green
    
    # Create a simplified token object that PS5 can use
    $tokenData = @{
        AccessToken = $msalToken.AccessToken
        ExpiresOn = $msalToken.ExpiresOn.ToString("o")  # ISO 8601 format
        TenantId = $tenantId
        ClientId = $clientId
        TokenType = "Bearer"
    }
    
    # Save to a temporary file
    $tokenFile = Join-Path $env:TEMP "intune_auth_token.json"
    $tokenData | ConvertTo-Json | Set-Content $tokenFile -Force
    
    Write-Host "Token saved to: $tokenFile" -ForegroundColor Green
    Write-Host "Token expires at: $($msalToken.ExpiresOn)" -ForegroundColor Cyan
    
    # Test the token
    $headers = @{
        "Authorization" = "Bearer $($msalToken.AccessToken)"
        "Content-Type" = "application/json"
    }
    
    $testUri = "https://graph.microsoft.com/v1.0/organization"
    $testResult = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get
    Write-Host "Token verified - Connected to: $($testResult.value[0].displayName)" -ForegroundColor Green
}
else {
    Write-Host "Failed to obtain token!" -ForegroundColor Red
    exit 1
}