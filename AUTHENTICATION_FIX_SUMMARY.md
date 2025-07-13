# IntuneWin32App Authentication Fix Summary

## Problem
The IntuneWin32App module's `Connect-MSIntuneGraph` function was failing with the error:
"The property 'ClientId' cannot be found on this object"

This occurred because:
1. The IntuneWin32App module expects older MSAL library object types
2. MSAL.PS returns different object structures
3. The `New-AuthenticationHeader` function tries to call methods that don't exist on MSAL.PS tokens

## Solution Implemented

### 1. Main Script Update (Intune-Win32-Deployer-ALPHAv1.ps1)
- Replaced `Connect-MSIntuneGraph` calls with direct MSAL.PS authentication
- Manually creates the `$Global:AuthenticationHeader` in the format IntuneWin32App expects
- Sets all required global variables that IntuneWin32App module functions use

### 2. Module Update (Ensure-IntuneAuthentication.ps1)
- Updated to use direct MSAL.PS authentication
- Handles both certificate file and thumbprint scenarios
- Creates compatible authentication headers

## Changes Made

1. **Direct MSAL Authentication**: Instead of using `Connect-MSIntuneGraph`, we now:
   ```powershell
   # Get token directly from MSAL.PS
   $msalToken = Get-MsalToken -TenantId $tenantId -ClientId $clientId -ClientCertificate $cert
   
   # Manually set global variables
   $Global:AccessToken = $msalToken
   $Global:AccessTokenTenantID = $tenantId
   $Global:AuthenticationHeader = @{
       "Content-Type" = "application/json"
       "Authorization" = "Bearer $($msalToken.AccessToken)"
       "ExpiresOn" = $msalToken.ExpiresOn.UtcDateTime
   }
   ```

2. **Compatibility Layer**: The authentication header is created manually to match what IntuneWin32App functions expect

3. **Error Handling**: Added verification steps to test the authentication immediately

## Testing Instructions

1. **Run the test script first**:
   ```powershell
   # In PowerShell 5.1 (as admin)
   cd C:\Code\Intune-Win32-Deployer
   .\Test-Authentication.ps1
   ```

2. **If test passes, run the main script**:
   ```powershell
   .\Intune-Win32-Deployer-ALPHAv1.ps1
   ```

3. **Expected Output**:
   - Should see "Direct MSAL authentication successful"
   - Should see "Authentication verified - connected to tenant: [Your Tenant Name]"
   - Should NOT see "The property 'ClientId' cannot be found on this object" error

## Rollback Instructions

If needed, restore the original script:
```powershell
Copy-Item "Intune-Win32-Deployer-ALPHAv1.ps1.backup" "Intune-Win32-Deployer-ALPHAv1.ps1" -Force
```

## What This Fix Does

1. Bypasses the incompatible `Connect-MSIntuneGraph` function
2. Uses MSAL.PS directly to get authentication tokens
3. Manually creates the authentication header structure that IntuneWin32App expects
4. Maintains compatibility with all other IntuneWin32App module functions

## Verification

After authentication, the IntuneWin32App module functions like:
- `Get-IntuneWin32App`
- `Add-IntuneWin32App`
- `New-IntuneWin32AppDetectionRule`

Should all work correctly with the manually created authentication header.