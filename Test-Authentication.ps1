# Test script for IntuneWin32App authentication fix
# This script tests the authentication separately before running the full deployer

param(
    [string]$SecretsPath = "C:\Code\Intune-Win32-Deployer\secrets\Lion's Housing Centres\secrets.json"
)

# Import only the required MSAL.PS module
try {
    Import-Module MSAL.PS -ErrorAction Stop
    Write-Host "MSAL.PS module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to import MSAL.PS module: $_" -ForegroundColor Red
    Write-Host "Please ensure MSAL.PS is installed: Install-Module -Name MSAL.PS" -ForegroundColor Yellow
    exit 1
}

# Load secrets
try {
    $secrets = Get-Content $SecretsPath -Raw | ConvertFrom-Json
    $tenantId = $secrets.TenantID
    $clientId = $secrets.ClientId
    $CertPassword = $secrets.CertPassword
    
    # Construct the certificate path from the output path
    $outputPath = $secrets.OutputPath
    $certName = $secrets.CertName
    $certPath = Join-Path $outputPath "$certName-$clientId.pfx"
    
    Write-Host "Secrets loaded successfully" -ForegroundColor Green
    Write-Host "TenantID: $tenantId" -ForegroundColor Cyan
    Write-Host "ClientID: $clientId" -ForegroundColor Cyan
    Write-Host "CertPath: $certPath" -ForegroundColor Cyan
    
    # Verify certificate exists
    if (-not (Test-Path $certPath)) {
        throw "Certificate file not found at: $certPath"
    }
}
catch {
    Write-Host "Failed to load secrets: $_" -ForegroundColor Red
    exit 1
}

# Test authentication
Write-Host "`nTesting direct MSAL authentication..." -ForegroundColor Yellow

try {
    # Clear any existing authentication
    $Global:AccessToken = $null
    $Global:AuthenticationHeader = $null
    $Global:AccessTokenTenantID = $null
    
    # Load certificate with specific flags to handle CNG certificates
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($certPath, $CertPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)
    Write-Host "Certificate loaded. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    
    # Check if certificate has private key
    if (-not $cert.HasPrivateKey) {
        throw "Certificate does not have a private key"
    }
    
    # Get token using MSAL.PS
    Write-Host "Requesting token from Azure AD..." -ForegroundColor Yellow
    $msalToken = Get-MsalToken -TenantId $tenantId -ClientId $clientId -ClientCertificate $cert
    
    if ($msalToken) {
        Write-Host "Token obtained successfully!" -ForegroundColor Green
        Write-Host "Access Token Type: $($msalToken.GetType().FullName)" -ForegroundColor Cyan
        Write-Host "Token expires at: $($msalToken.ExpiresOn)" -ForegroundColor Cyan
        
        # Set up global variables
        $Global:AccessToken = $msalToken
        $Global:AccessTokenTenantID = $tenantId
        $Global:AuthenticationHeader = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $($msalToken.AccessToken)"
            "ExpiresOn" = $msalToken.ExpiresOn.UtcDateTime
        }
        
        Write-Host "`nGlobal variables set successfully" -ForegroundColor Green
        Write-Host "Global:AccessToken exists: $($null -ne $Global:AccessToken)" -ForegroundColor Cyan
        Write-Host "Global:AuthenticationHeader exists: $($null -ne $Global:AuthenticationHeader)" -ForegroundColor Cyan
        
        # Test the authentication
        Write-Host "`nTesting authentication with Graph API..." -ForegroundColor Yellow
        $testUri = "https://graph.microsoft.com/v1.0/organization"
        $testResult = Invoke-RestMethod -Uri $testUri -Headers $Global:AuthenticationHeader -Method Get -ErrorAction Stop
        
        Write-Host "Authentication test successful!" -ForegroundColor Green
        Write-Host "Connected to tenant: $($testResult.value[0].displayName)" -ForegroundColor Cyan
        Write-Host "Tenant ID: $($testResult.value[0].id)" -ForegroundColor Cyan
        
        # Test IntuneWin32App module function compatibility
        Write-Host "`nTesting IntuneWin32App module compatibility..." -ForegroundColor Yellow
        try {
            Import-Module IntuneWin32App -ErrorAction Stop
            
            # Check if the module can use our authentication
            # This would normally fail with Connect-MSIntuneGraph, but should work with our setup
            Write-Host "IntuneWin32App module loaded" -ForegroundColor Green
            
            # Try a simple IntuneWin32App command
            Write-Host "Attempting to retrieve Win32 apps..." -ForegroundColor Yellow
            $apps = Get-IntuneWin32App -ErrorAction Stop | Select-Object -First 5
            
            if ($apps) {
                Write-Host "Successfully retrieved Win32 apps using our authentication!" -ForegroundColor Green
                Write-Host "Found $($apps.Count) apps (showing first 5)" -ForegroundColor Cyan
                $apps | ForEach-Object { Write-Host "  - $($_.displayName)" -ForegroundColor Gray }
            }
            else {
                Write-Host "No Win32 apps found, but authentication worked!" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "IntuneWin32App test failed: $_" -ForegroundColor Red
            Write-Host "This may be normal if no apps exist yet" -ForegroundColor Yellow
        }
        
        Write-Host "`nAuthentication setup completed successfully!" -ForegroundColor Green
        Write-Host "You can now run the main Intune-Win32-Deployer script." -ForegroundColor Cyan
    }
    else {
        throw "Failed to obtain access token"
    }
}
catch {
    Write-Host "`nAuthentication test failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Full error details:" -ForegroundColor Red
    $_ | Format-List -Force
}