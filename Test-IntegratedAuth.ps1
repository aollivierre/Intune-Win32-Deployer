# Test script to verify the integrated PS7/PS5 authentication
# This simulates just the authentication part of the main script

# Force PowerShell 5 as the main script does
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "Relaunching in PowerShell 5..."
    $ps5Path = "$($env:SystemRoot)\System32\WindowsPowerShell\v1.0\powershell.exe"
    $ps5Args = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath $ps5Path -ArgumentList $ps5Args
    exit
}

Write-Host "Running in PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Load secrets
$secretsJsonPath = "C:\Code\Intune-Win32-Deployer\secrets\Lion's Housing Centres\secrets.json"
$secrets = Get-Content $secretsJsonPath -Raw | ConvertFrom-Json

# Extract values
$tenantId = $secrets.TenantID
$clientId = $secrets.ClientId
$CertPassword = $secrets.CertPassword

# Find certificate path
$baseOutputPath = $secrets.OutputPath
$pfxFiles = Get-ChildItem -Path $baseOutputPath -Filter *.pfx -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*$clientId*" }

if ($pfxFiles.Count -eq 0) {
    Write-Host "ERROR: No PFX file found" -ForegroundColor Red
    exit 1
}

$certPath = $pfxFiles[0].FullName
Write-Host "Certificate found: $certPath" -ForegroundColor Green

# Test the authentication logic
try {
    Write-Host "`nTesting integrated authentication..." -ForegroundColor Yellow
    
    # Clear any existing authentication
    $Global:AccessToken = $null
    $Global:AuthenticationHeader = $null
    $Global:AccessTokenTenantID = $null
    
    # Load certificate for verification
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $CertPassword)
    Write-Host "Certificate loaded. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    
    # Check if PowerShell 7 is available
    $ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
    $usePS7Auth = Test-Path $ps7Path
    
    if ($usePS7Auth) {
        Write-Host "PowerShell 7 found. Using it for authentication..." -ForegroundColor Green
        
        # Create the PS7 script content (same as in main script)
        $ps7ScriptContent = @"
param(
    [string]`$TenantId,
    [string]`$ClientId,
    [string]`$CertPath,
    [string]`$CertPassword
)

try {
    Import-Module MSAL.PS -ErrorAction Stop
    `$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(`$CertPath, `$CertPassword)
    `$msalToken = Get-MsalToken -TenantId `$TenantId -ClientId `$ClientId -ClientCertificate `$cert
    
    if (`$msalToken) {
        `$tokenData = @{
            AccessToken = `$msalToken.AccessToken
            ExpiresOn = `$msalToken.ExpiresOn.ToString("o")
            TenantId = `$TenantId
            ClientId = `$ClientId
            TokenType = "Bearer"
        }
        
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
        
        # Save and run PS7 script
        $ps7ScriptPath = Join-Path $env:TEMP "Get-IntuneAuthPS7.ps1"
        $ps7ScriptContent | Set-Content $ps7ScriptPath -Force
        
        $ps7Args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ps7ScriptPath`"", 
                     "-TenantId", $tenantId, "-ClientId", $clientId, 
                     "-CertPath", "`"$certPath`"", "-CertPassword", "`"$CertPassword`"")
        
        Write-Host "Launching PowerShell 7 for authentication..." -ForegroundColor Yellow
        $ps7Process = Start-Process -FilePath $ps7Path -ArgumentList $ps7Args -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\ps7_auth_output.txt"
        
        if ($ps7Process.ExitCode -eq 0) {
            Write-Host "PowerShell 7 authentication completed successfully!" -ForegroundColor Green
            
            # Load the token
            $tokenFile = Join-Path $env:TEMP "intune_auth_token.json"
            if (Test-Path $tokenFile) {
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
                
                Write-Host "Token loaded successfully!" -ForegroundColor Green
                Write-Host "Token expires at: $expiresOn" -ForegroundColor Cyan
                
                # Test authentication
                Write-Host "`nTesting authentication with Graph API..." -ForegroundColor Yellow
                $testUri = "https://graph.microsoft.com/v1.0/organization"
                $testResult = Invoke-RestMethod -Uri $testUri -Headers $Global:AuthenticationHeader -Method Get
                Write-Host "SUCCESS: Connected to tenant: $($testResult.value[0].displayName)" -ForegroundColor Green
                
                # Test IntuneWin32App module
                Write-Host "`nTesting IntuneWin32App module compatibility..." -ForegroundColor Yellow
                Import-Module IntuneWin32App -ErrorAction Stop
                
                try {
                    $apps = Get-IntuneWin32App -ErrorAction Stop | Select-Object -First 5
                    Write-Host "IntuneWin32App module test passed!" -ForegroundColor Green
                    if ($apps) {
                        Write-Host "Found $($apps.Count) Win32 apps" -ForegroundColor Cyan
                    }
                }
                catch {
                    Write-Host "IntuneWin32App test: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                
                # Clean up
                Remove-Item $ps7ScriptPath -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:TEMP\ps7_auth_output.txt" -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            $ps7Output = Get-Content "$env:TEMP\ps7_auth_output.txt" -Raw -ErrorAction SilentlyContinue
            Write-Host "PowerShell 7 authentication failed!" -ForegroundColor Red
            Write-Host "Output: $ps7Output" -ForegroundColor Red
        }
    }
    else {
        Write-Host "PowerShell 7 not found. Would fall back to direct MSAL (likely to fail with CNG certs)." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error during authentication: $_" -ForegroundColor Red
    $_ | Format-List -Force
}