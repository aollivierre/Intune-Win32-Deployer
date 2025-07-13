function Initialize-IntuneWin32AppAuthentication {
    <#
    .SYNOPSIS
    Establishes authentication for IntuneWin32App module using certificate authentication
    
    .DESCRIPTION
    This function bypasses the IntuneWin32App module's Connect-MSIntuneGraph function
    and directly sets up the required global variables using MSAL.PS
    #>
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
        Write-Host "Initializing IntuneWin32App authentication..." -ForegroundColor Yellow
        
        # Clear any existing authentication
        $Global:AccessToken = $null
        $Global:AuthenticationHeader = $null
        $Global:AccessTokenTenantID = $null
        
        # Load certificate
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
        Write-Host "Certificate loaded. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
        
        # Import MSAL.PS module
        Import-Module MSAL.PS -ErrorAction Stop
        
        # Get token using MSAL.PS
        $msalToken = Get-MsalToken -TenantId $TenantID -ClientId $ClientID -ClientCertificate $cert
        
        if ($msalToken) {
            # The IntuneWin32App module expects these specific global variables
            # We need to create a compatible object structure
            
            # Store the raw MSAL token
            $Global:AccessToken = $msalToken
            $Global:AccessTokenTenantID = $TenantID
            
            # Create the authentication header that IntuneWin32App functions expect
            # This is the key - we create the header manually in the format expected
            $Global:AuthenticationHeader = @{
                "Content-Type" = "application/json"
                "Authorization" = "Bearer $($msalToken.AccessToken)"
                "ExpiresOn" = $msalToken.ExpiresOn.UtcDateTime
            }
            
            # Store certificate info for potential re-authentication
            $Global:TenantId = $TenantID
            $Global:ClientId = $ClientID
            $Global:CertPath = $CertPath
            $Global:CertPassword = $CertPassword
            $Global:CertObject = $cert
            
            Write-Host "Authentication successful!" -ForegroundColor Green
            Write-Host "Token expires at: $($msalToken.ExpiresOn)" -ForegroundColor Cyan
            
            # Test the authentication by making a simple Graph call
            try {
                $testUri = "https://graph.microsoft.com/v1.0/organization"
                $testResult = Invoke-RestMethod -Uri $testUri -Headers $Global:AuthenticationHeader -Method Get -ErrorAction Stop
                Write-Host "Authentication verified - successfully connected to tenant: $($testResult.value[0].displayName)" -ForegroundColor Green
            }
            catch {
                Write-Warning "Authentication test failed: $_"
            }
            
            return $true
        }
        else {
            throw "Failed to obtain access token from MSAL.PS"
        }
    }
    catch {
        Write-Host "Authentication initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Full error: $_" -ForegroundColor Red
        return $false
    }
}

# Updated version of your main script's authentication section
function Invoke-UpdatedAuthentication {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$CertPath,
        [string]$CertPassword
    )
    
    Write-EnhancedLog -Message "Starting updated authentication process..." -Level "INFO"
    
    # First, try the direct MSAL approach
    $authParams = @{
        TenantID = $TenantId
        ClientID = $ClientId
        CertPath = $CertPath
        CertPassword = $CertPassword
    }
    
    $authSuccess = Initialize-IntuneWin32AppAuthentication @authParams
    
    if (-not $authSuccess) {
        Write-EnhancedLog -Message "Primary authentication failed. Attempting fallback to interactive..." -Level "WARNING"
        
        # Try interactive as fallback
        try {
            # Load the IntuneWin32App module if not already loaded
            Import-Module IntuneWin32App -ErrorAction Stop
            
            # Use interactive authentication
            Connect-MSIntuneGraph -TenantID $TenantId -Interactive
            
            if ($Global:AuthenticationHeader) {
                Write-EnhancedLog -Message "Interactive authentication successful" -Level "INFO"
                $authSuccess = $true
            }
        }
        catch {
            Write-EnhancedLog -Message "All authentication methods failed: $_" -Level "ERROR"
            throw "Cannot establish authentication with Microsoft Graph"
        }
    }
    
    return $authSuccess
}