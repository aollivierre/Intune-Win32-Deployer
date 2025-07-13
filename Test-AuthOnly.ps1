# Direct test of just the authentication part
# This extracts and tests only the authentication logic

Write-Host "Testing Authentication Logic Only" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow

# Load necessary functions
function Write-EnhancedLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

# Load secrets
$secretsJsonPath = "C:\Code\Intune-Win32-Deployer\secrets\Lion's Housing Centres\secrets.json"
Write-EnhancedLog -Message "Loading secrets from $secretsJsonPath" -Level "INFO"

$secrets = Get-Content $secretsJsonPath -Raw | ConvertFrom-Json
$tenantId = $secrets.TenantID
$clientId = $secrets.ClientId
$CertPassword = $secrets.CertPassword

# Find certificate
$baseOutputPath = $secrets.OutputPath
$pfxFiles = Get-ChildItem -Path $baseOutputPath -Filter *.pfx -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*$clientId*" }

if ($pfxFiles.Count -eq 0) {
    Write-EnhancedLog -Message "No PFX file found" -Level "ERROR"
    exit 1
}

$certPath = $pfxFiles[0].FullName
Write-EnhancedLog -Message "Certificate found: $certPath" -Level "INFO"

# Test the integrated authentication
Write-EnhancedLog -Message "Establishing authentication with IntuneWin32App module..." -Level "INFO"
try {
    # Clear any existing authentication state first
    Write-EnhancedLog -Message "Clearing any existing IntuneWin32App authentication state..." -Level "INFO"
    $Global:AccessToken = $null
    $Global:AuthenticationHeader = $null
    $Global:AccessTokenTenantID = $null
    
    # Extract certificate thumbprint
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $CertPassword)
    $certThumbprint = $cert.Thumbprint
    Write-EnhancedLog -Message "Certificate thumbprint: $certThumbprint" -Level "INFO"
    Write-EnhancedLog -Message "Certificate subject: $($cert.Subject)" -Level "INFO"
    
    # Store the certificate object globally for later use
    $Global:CertObject = $cert
    
    # Check if PowerShell 7 is available for CNG certificate handling
    $ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
    $usePS7Auth = Test-Path $ps7Path
    
    if ($usePS7Auth) {
        Write-EnhancedLog -Message "Using PowerShell 7 for certificate authentication (better CNG support)..." -Level "INFO"
        
        # Create a temporary script to run in PS7
        $ps7ScriptContent = @"
# PowerShell 7 Authentication Script
param(
    [string]`$TenantId,
    [string]`$ClientId,
    [string]`$CertPath,
    [string]`$CertPassword
)

try {
    Import-Module MSAL.PS -ErrorAction Stop
    
    # Load certificate - PS7 handles CNG certificates better
    `$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(`$CertPath, `$CertPassword)
    
    # Get token
    `$msalToken = Get-MsalToken -TenantId `$TenantId -ClientId `$ClientId -ClientCertificate `$cert
    
    if (`$msalToken) {
        # Create token data for PS5
        `$tokenData = @{
            AccessToken = `$msalToken.AccessToken
            ExpiresOn = `$msalToken.ExpiresOn.ToString("o")
            TenantId = `$TenantId
            ClientId = `$ClientId
            TokenType = "Bearer"
        }
        
        # Save to temp file
        `$tokenFile = Join-Path `$env:TEMP "intune_auth_token.json"
        `$tokenData | ConvertTo-Json | Set-Content `$tokenFile -Force
        
        Write-Host "SUCCESS"
        exit 0
    }
}
catch {
    Write-Host "ERROR: `$_"
    exit 1
}
"@
        
        # Save PS7 script temporarily
        $ps7ScriptPath = Join-Path $env:TEMP "Get-IntuneAuthPS7.ps1"
        $ps7ScriptContent | Set-Content $ps7ScriptPath -Force
        
        # Run PS7 to get the token
        $ps7Args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ps7ScriptPath`"", "-TenantId", $tenantId, "-ClientId", $clientId, "-CertPath", "`"$certPath`"", "-CertPassword", "`"$CertPassword`"")
        $ps7Process = Start-Process -FilePath $ps7Path -ArgumentList $ps7Args -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\ps7_auth_output.txt"
        
        # Check if PS7 authentication succeeded
        if ($ps7Process.ExitCode -eq 0) {
            # Load the token from PS7
            $tokenFile = Join-Path $env:TEMP "intune_auth_token.json"
            if (Test-Path $tokenFile) {
                $tokenData = Get-Content $tokenFile -Raw | ConvertFrom-Json
                
                # Set up global variables in the format IntuneWin32App expects
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
                
                Write-EnhancedLog -Message "PowerShell 7 authentication successful" -Level "INFO"
                Write-EnhancedLog -Message "Token expires at: $expiresOn" -Level "INFO"
                
                # Test authentication
                try {
                    $testUri = "https://graph.microsoft.com/v1.0/organization"
                    $testResult = Invoke-RestMethod -Uri $testUri -Headers $Global:AuthenticationHeader -Method Get -ErrorAction Stop
                    Write-EnhancedLog -Message "Authentication verified - connected to tenant: $($testResult.value[0].displayName)" -Level "INFO"
                }
                catch {
                    Write-EnhancedLog -Message "Authentication test warning: $($_.Exception.Message)" -Level "WARNING"
                }
                
                # Clean up temp files
                Remove-Item $ps7ScriptPath -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:TEMP\ps7_auth_output.txt" -Force -ErrorAction SilentlyContinue
            }
            else {
                throw "PowerShell 7 did not create token file"
            }
        }
        else {
            # PS7 auth failed, read the output for debugging
            $ps7Output = Get-Content "$env:TEMP\ps7_auth_output.txt" -Raw -ErrorAction SilentlyContinue
            Write-EnhancedLog -Message "PowerShell 7 authentication failed: $ps7Output" -Level "ERROR"
            throw "PowerShell 7 authentication failed"
        }
    }
    else {
        Write-EnhancedLog -Message "PowerShell 7 not found. Direct MSAL would be used (likely to fail with CNG certs)." -Level "WARNING"
    }
    
    # Final verification
    Write-Host "`n=== AUTHENTICATION TEST RESULTS ===" -ForegroundColor Green
    Write-Host "Global:AuthenticationHeader exists: $($null -ne $Global:AuthenticationHeader)" -ForegroundColor Cyan
    Write-Host "Global:AccessToken exists: $($null -ne $Global:AccessToken)" -ForegroundColor Cyan
    Write-Host "Global:AccessTokenTenantID: $Global:AccessTokenTenantID" -ForegroundColor Cyan
    
    if ($Global:AuthenticationHeader) {
        Write-Host "`nAuthentication successful! Ready to deploy Win32 apps." -ForegroundColor Green
        
        # Test IntuneWin32App module
        Write-Host "`nTesting IntuneWin32App module..." -ForegroundColor Yellow
        Import-Module IntuneWin32App -ErrorAction Stop
        
        try {
            $testApps = Get-IntuneWin32App -ErrorAction Stop | Select-Object -First 1
            Write-Host "IntuneWin32App module is working correctly!" -ForegroundColor Green
        }
        catch {
            Write-Host "IntuneWin32App module test: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "This is normal if no apps are deployed yet." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`nAuthentication FAILED!" -ForegroundColor Red
    }
}
catch {
    Write-EnhancedLog -Message "Failed to authenticate: $($_.Exception.Message)" -Level "ERROR"
    Write-Host "`nFull error details:" -ForegroundColor Red
    $_ | Format-List -Force
}