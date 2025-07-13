# IntuneWin32App Authentication Fix - COMPLETE ✅

## Summary
Successfully implemented a hybrid PowerShell 7/5 authentication solution that resolves the CNG certificate compatibility issue with the IntuneWin32App module.

## What Was Fixed

### Original Problem
- Error: "The property 'ClientId' cannot be found on this object"
- Root cause: CNG certificates don't work properly with .NET Framework 4.6 (used by PowerShell 5.1)
- The IntuneWin32App module's `Connect-MSIntuneGraph` function failed with certificate authentication

### Solution Implemented
1. **Automatic PowerShell 7 Detection**: The script now checks if PS7 is available
2. **Hybrid Authentication**: Uses PS7 for token acquisition (handles CNG certs), then passes token to PS5
3. **Seamless Integration**: No changes needed to the rest of your script
4. **Fallback Support**: If PS7 isn't available, falls back to direct MSAL (with warning about CNG)

## Test Results ✅

### Authentication Test Results:
- PowerShell 7 authentication: **SUCCESS**
- Token acquisition: **SUCCESS**
- Token loading in PS5: **SUCCESS**
- Graph API connection: **SUCCESS** (Connected to: Lion's Housing Centres)
- IntuneWin32App module compatibility: **SUCCESS**

### Key Success Indicators:
```
Global:AuthenticationHeader exists: True
Global:AccessToken exists: True
Global:AccessTokenTenantID: f8e714f5-f15a-435d-b51e-9c93d637a9c4
```

## Files Modified

1. **Intune-Win32-Deployer-ALPHAv1.ps1**
   - Updated authentication block to use PS7 when available
   - Added automatic token handoff between PS7 and PS5
   - Maintains backward compatibility

2. **Ensure-IntuneAuthentication.ps1**
   - Updated to use the same PS7 authentication approach
   - Handles both certificate file and thumbprint scenarios

## How It Works

1. Script detects PowerShell 7 is available
2. Creates a temporary PS7 script with authentication logic
3. PS7 loads the CNG certificate without issues
4. PS7 gets token from Azure AD using MSAL.PS
5. Token is saved to a temporary JSON file
6. PS5 loads the token from the file
7. Global variables are set in the format IntuneWin32App expects
8. All IntuneWin32App functions work normally

## Usage

No changes required! Just run your script as normal:
```powershell
.\Intune-Win32-Deployer-ALPHAv1.ps1
```

The script will automatically:
- Detect PS7 and use it for authentication
- Handle the token handoff transparently
- Continue with all Win32 app deployment operations

## Prerequisites

- PowerShell 7 installed (for CNG certificate support)
- MSAL.PS module installed
- IntuneWin32App module installed
- Valid certificate and secrets.json file

## Troubleshooting

If authentication fails:
1. Ensure PowerShell 7 is installed: `winget install Microsoft.PowerShell`
2. Check certificate has private key
3. Verify secrets.json has correct values
4. Check temp token file: `$env:TEMP\intune_auth_token.json`

## Backup

Original script backed up to: `Intune-Win32-Deployer-ALPHAv1.ps1.backup`

---

**Status: RESOLVED** 🎉

The CNG certificate authentication issue has been successfully resolved using a PowerShell 7 hybrid approach.