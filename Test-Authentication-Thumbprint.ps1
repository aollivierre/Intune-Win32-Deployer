# Alternative test script that uses certificate from store
param(
    [string]$SecretsPath = "C:\Code\Intune-Win32-Deployer\secrets\Lion's Housing Centres\secrets.json"
)

# Import MSAL.PS
try {
    Import-Module MSAL.PS -ErrorAction Stop
    Write-Host "MSAL.PS module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to import MSAL.PS module: $_" -ForegroundColor Red
    exit 1
}

# Load secrets
try {
    $secrets = Get-Content $SecretsPath -Raw | ConvertFrom-Json
    $tenantId = $secrets.TenantID
    $clientId = $secrets.ClientId
    $thumbprint = $secrets.Thumbprint
    
    Write-Host "Secrets loaded successfully" -ForegroundColor Green
    Write-Host "TenantID: $tenantId" -ForegroundColor Cyan
    Write-Host "ClientID: $clientId" -ForegroundColor Cyan
    Write-Host "Thumbprint: $thumbprint" -ForegroundColor Cyan
}
catch {
    Write-Host "Failed to load secrets: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nSearching for certificate in certificate store..." -ForegroundColor Yellow

# Search for certificate in both user and machine stores
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $thumbprint }
if (-not $cert) {
    Write-Host "Certificate not found in CurrentUser store, checking LocalMachine..." -ForegroundColor Yellow
    $cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Thumbprint -eq $thumbprint }
}

if ($cert) {
    Write-Host "Certificate found in store!" -ForegroundColor Green
    Write-Host "Subject: $($cert.Subject)" -ForegroundColor Cyan
    Write-Host "Has Private Key: $($cert.HasPrivateKey)" -ForegroundColor Cyan
    
    if (-not $cert.HasPrivateKey) {
        Write-Host "WARNING: Certificate does not have a private key!" -ForegroundColor Red
        exit 1
    }
    
    # Try authentication with certificate from store
    try {
        Write-Host "`nAttempting authentication with certificate from store..." -ForegroundColor Yellow
        $msalToken = Get-MsalToken -TenantId $tenantId -ClientId $clientId -ClientCertificate $cert
        
        if ($msalToken) {
            Write-Host "Authentication successful!" -ForegroundColor Green
            Write-Host "Token expires at: $($msalToken.ExpiresOn)" -ForegroundColor Cyan
            
            # Test with Graph API
            $headers = @{
                "Authorization" = "Bearer $($msalToken.AccessToken)"
                "Content-Type" = "application/json"
            }
            
            $testUri = "https://graph.microsoft.com/v1.0/organization"
            $testResult = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get
            Write-Host "Connected to tenant: $($testResult.value[0].displayName)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Authentication failed: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "Certificate not found in any certificate store!" -ForegroundColor Red
    Write-Host "The certificate may need to be imported to the certificate store first." -ForegroundColor Yellow
    
    # Offer to import the certificate
    Write-Host "`nWould you like to import the certificate to the CurrentUser store? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        try {
            $certPassword = $secrets.CertPassword
            $outputPath = $secrets.OutputPath
            $certName = $secrets.CertName
            $certPath = Join-Path $outputPath "$certName-$clientId.pfx"
            
            Write-Host "Importing certificate from: $certPath" -ForegroundColor Yellow
            
            $securePassword = ConvertTo-SecureString -String $certPassword -AsPlainText -Force
            $importedCert = Import-PfxCertificate -FilePath $certPath -CertStoreLocation "Cert:\CurrentUser\My" -Password $securePassword
            
            Write-Host "Certificate imported successfully!" -ForegroundColor Green
            Write-Host "Thumbprint: $($importedCert.Thumbprint)" -ForegroundColor Cyan
            Write-Host "Please run this script again to test authentication." -ForegroundColor Yellow
        }
        catch {
            Write-Host "Failed to import certificate: $_" -ForegroundColor Red
        }
    }
}