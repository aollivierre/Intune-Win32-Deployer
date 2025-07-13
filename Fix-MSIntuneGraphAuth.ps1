function Connect-MSIntuneGraphFixed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantID,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientID,
        
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$ClientCert
    )
    
    try {
        Write-Host "Attempting fixed authentication with MSAL.PS..." -ForegroundColor Yellow
        
        # Import MSAL.PS module
        Import-Module MSAL.PS -ErrorAction Stop
        
        # Create parameters with exact casing that MSAL.PS expects
        $msalParams = @{
            TenantId         = $TenantID
            ClientId         = $ClientID
            ClientCertificate = $ClientCert
        }
        
        # Get the access token directly using MSAL.PS
        $token = Get-MsalToken @msalParams
        
        # Set global variables that IntuneWin32App module expects
        $Global:AccessToken = $token
        $Global:AccessTokenTenantID = $TenantID
        
        # Create authentication header
        $Global:AuthenticationHeader = @{
            "Authorization" = "Bearer $($token.AccessToken)"
            "Content-Type" = "application/json"
            "ExpiresOn" = $token.ExpiresOn.DateTime
        }
        
        Write-Host "Authentication successful!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Authentication failed: $_" -ForegroundColor Red
        return $false
    }
}

# Alternative: Direct MSAL authentication bypassing IntuneWin32App's Connect function
function Set-IntuneAuthenticationDirect {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantID,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientID,
        
        [Parameter(Mandatory = $true)]
        [string]$CertPath,
        
        [Parameter(Mandatory = $true)]
        [string]$CertPassword
    )
    
    try {
        # Load certificate
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
        Write-Host "Certificate loaded successfully. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
        
        # Import required module
        Import-Module MSAL.PS -ErrorAction Stop
        
        # Get token with explicit parameter construction
        $tokenParams = @{}
        $tokenParams['TenantId'] = $TenantID
        $tokenParams['ClientId'] = $ClientID
        $tokenParams['ClientCertificate'] = $cert
        
        Write-Host "Requesting token from Azure AD..." -ForegroundColor Yellow
        $token = Get-MsalToken @tokenParams
        
        if ($token) {
            # Set all the global variables that IntuneWin32App module expects
            $Global:AccessToken = $token
            $Global:AccessTokenTenantID = $TenantID
            $Global:AuthenticationHeader = @{
                "Authorization" = "Bearer $($token.AccessToken)"
                "Content-Type" = "application/json"
                "ExpiresOn" = $token.ExpiresOn.DateTime
            }
            
            Write-Host "Authentication successful! Token expires at: $($token.ExpiresOn)" -ForegroundColor Green
            
            # Store for reconnection
            $Global:TenantId = $TenantID
            $Global:ClientId = $ClientID
            $Global:CertPath = $CertPath
            $Global:CertPassword = $CertPassword
            $Global:CertObject = $cert
            
            return $true
        }
        else {
            throw "Failed to obtain access token"
        }
    }
    catch {
        Write-Host "Direct authentication failed: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}