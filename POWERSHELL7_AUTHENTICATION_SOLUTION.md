# PowerShell 7 Authentication Solution for IntuneWin32App

## Problem Summary
The IntuneWin32App module has issues with CNG certificates in PowerShell 5.1, causing the error:
- "The property 'ClientId' cannot be found on this object" (actually a certificate compatibility issue)
- "Could not use the certificate for signing" with CNG certificates

## Solution Overview
Use PowerShell 7 for authentication (which handles CNG certificates properly), then pass the token to PowerShell 5.1 for the IntuneWin32App operations.

## Implementation Steps

### Step 1: Get Token with PowerShell 7
Run this in PowerShell 7 to authenticate and save the token:
```powershell
pwsh.exe -File "C:\Code\Intune-Win32-Deployer\Get-AuthTokenPS7.ps1"
```

This script:
- Loads the certificate without CNG issues
- Gets an access token from Azure AD
- Saves the token to a temporary file
- Validates the token with a test API call

### Step 2: Use Token in PowerShell 5.1
In your main script, replace the authentication block with:

```powershell
# Function to load authentication from PS7 token
function Set-IntuneAuthFromPS7Token {
    param(
        [string]$TokenFile = (Join-Path $env:TEMP "intune_auth_token.json")
    )
    
    try {
        if (-not (Test-Path $TokenFile)) {
            # Token file doesn't exist, need to run PS7 to get it
            Write-EnhancedLog -Message "No saved token found. Launching PowerShell 7 to authenticate..." -Level "INFO"
            
            $ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
            $authScriptPath = "C:\Code\Intune-Win32-Deployer\Get-AuthTokenPS7.ps1"
            
            # Run PS7 to get the token
            $process = Start-Process -FilePath $ps7Path -ArgumentList "-File", "`"$authScriptPath`"" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -ne 0) {
                throw "PowerShell 7 authentication failed"
            }
        }
        
        # Load the token
        $tokenData = Get-Content $TokenFile -Raw | ConvertFrom-Json
        
        # Check validity
        $expiresOn = [DateTime]::Parse($tokenData.ExpiresOn).ToUniversalTime()
        $now = [DateTime]::UtcNow
        
        if ($expiresOn -lt $now.AddMinutes(5)) {
            # Token expires in less than 5 minutes, refresh it
            Write-EnhancedLog -Message "Token expires soon. Refreshing..." -Level "INFO"
            Remove-Item $TokenFile -Force
            return Set-IntuneAuthFromPS7Token  # Recursive call to get new token
        }
        
        # Set global variables for IntuneWin32App
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
        
        # Store for re-authentication
        $Global:TenantId = $tokenData.TenantId
        $Global:ClientId = $tokenData.ClientId
        
        Write-EnhancedLog -Message "Authentication successful (token valid until $expiresOn UTC)" -Level "INFO"
        return $true
    }
    catch {
        Write-EnhancedLog -Message "Failed to authenticate: $_" -Level "ERROR"
        return $false
    }
}

# Replace your existing authentication block with:
if (-not (Set-IntuneAuthFromPS7Token)) {
    throw "Failed to establish authentication"
}
```

### Step 3: Update Ensure-IntuneAuthentication Function
Update the module function to use the same approach:

```powershell
# In Ensure-IntuneAuthentication.ps1, add this option:
if ($PSVersionTable.PSVersion.Major -eq 5 -and $CertPath) {
    # Use PS7 for authentication if we're in PS5 with a certificate
    Write-EnhancedLog -Message "Using PowerShell 7 for certificate authentication..." -Level "INFO"
    
    $tokenFile = Join-Path $env:TEMP "intune_auth_token.json"
    # Check if we need a new token...
    # (similar logic as above)
}
```

## Benefits
1. **No more CNG certificate errors**
2. **Maintains compatibility with IntuneWin32App module**
3. **Automatic token refresh when needed**
4. **Seamless integration with existing code**

## Testing
1. Delete any existing token: `Remove-Item "$env:TEMP\intune_auth_token.json" -ErrorAction SilentlyContinue`
2. Run your main script - it should automatically use PS7 for auth
3. Subsequent runs will reuse the token until it expires

## Troubleshooting
- If PS7 is not installed: `winget install Microsoft.PowerShell`
- If the certificate still fails: Check if it's properly exported with private key
- Token file location: `$env:TEMP\intune_auth_token.json`