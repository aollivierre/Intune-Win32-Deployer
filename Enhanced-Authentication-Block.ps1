# Enhanced Authentication Block for Intune-Win32-Deployer
# This replaces the existing authentication section in your main script

#region ENHANCED AUTHENTICATION
try {
    Write-EnhancedLog -Message "Starting enhanced authentication process..." -Level "INFO"
    
    # Clear any existing authentication state
    $Global:AccessToken = $null
    $Global:AuthenticationHeader = $null
    $Global:AccessTokenTenantID = $null
    
    # Load certificate
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $CertPassword)
    $certThumbprint = $cert.Thumbprint
    Write-EnhancedLog -Message "Certificate loaded. Thumbprint: $certThumbprint" -Level "INFO"
    
    # Store certificate globally
    $Global:CertObject = $cert
    
    # Method 1: Try using IntuneWin32App module's authentication
    $authSuccess = $false
    try {
        Write-EnhancedLog -Message "Attempting IntuneWin32App module authentication..." -Level "INFO"
        Connect-MSIntuneGraph -TenantID $tenantId -ClientID $clientId -ClientCert $cert -ErrorAction Stop
        
        # Verify authentication
        if ($Global:AuthenticationHeader) {
            Write-EnhancedLog -Message "IntuneWin32App authentication successful" -Level "INFO"
            $authSuccess = $true
        }
    }
    catch {
        Write-EnhancedLog -Message "IntuneWin32App authentication failed: $($_.Exception.Message)" -Level "WARNING"
    }
    
    # Method 2: If IntuneWin32App auth fails, try direct MSAL authentication
    if (-not $authSuccess) {
        Write-EnhancedLog -Message "Attempting direct MSAL authentication..." -Level "INFO"
        
        try {
            # Import MSAL.PS module
            Import-Module MSAL.PS -ErrorAction Stop
            
            # Create token request parameters
            $tokenParams = @{
                TenantId = $tenantId
                ClientId = $clientId
                ClientCertificate = $cert
            }
            
            # Get access token
            $token = Get-MsalToken @tokenParams
            
            if ($token) {
                # Manually set the global variables that IntuneWin32App expects
                $Global:AccessToken = $token
                $Global:AccessTokenTenantID = $tenantId
                
                # Create authentication header in the format IntuneWin32App expects
                $Global:AuthenticationHeader = @{
                    "Authorization" = "Bearer $($token.AccessToken)"
                    "Content-Type" = "application/json"
                    "ExpiresOn" = $token.ExpiresOn.DateTime
                }
                
                Write-EnhancedLog -Message "Direct MSAL authentication successful" -Level "INFO"
                $authSuccess = $true
            }
        }
        catch {
            Write-EnhancedLog -Message "Direct MSAL authentication failed: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    # Method 3: If all else fails, try interactive authentication
    if (-not $authSuccess) {
        Write-EnhancedLog -Message "Attempting interactive authentication as last resort..." -Level "WARNING"
        try {
            Connect-MSIntuneGraph -TenantID $tenantId -Interactive
            
            if ($Global:AuthenticationHeader) {
                Write-EnhancedLog -Message "Interactive authentication successful" -Level "INFO"
                $authSuccess = $true
            }
        }
        catch {
            Write-EnhancedLog -Message "Interactive authentication failed: $($_.Exception.Message)" -Level "ERROR"
            throw "All authentication methods failed. Cannot proceed."
        }
    }
    
    # Store authentication parameters globally for reconnection
    if ($authSuccess) {
        $Global:TenantId = $tenantId
        $Global:ClientId = $clientId
        $Global:CertPath = $certPath
        $Global:CertPassword = $CertPassword
        
        Write-EnhancedLog -Message "Authentication completed successfully" -Level "INFO"
        Write-EnhancedLog -Message "Access token expires at: $($Global:AccessToken.ExpiresOn)" -Level "INFO"
    }
}
catch {
    Write-EnhancedLog -Message "Critical authentication error: $($_.Exception.Message)" -Level "ERROR"
    throw
}
#endregion ENHANCED AUTHENTICATION