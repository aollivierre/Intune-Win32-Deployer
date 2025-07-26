#region Script Information
<#
.SYNOPSIS
    Checks if the Cisco Umbrella Root CA certificate is installed

.DESCRIPTION
    This script verifies if the Cisco Umbrella Root CA certificate is present in the 
    LocalMachine\Root certificate store. Used by Microsoft Intune as a detection script
    for the Win32 app deployment.
    
    Exit codes:
    0 = Certificate found (app is installed)
    1 = Certificate not found (app is not installed)

.NOTES
    Version:        1.0
    Author:         Automated Script
    Creation Date:  2025-07-19
    Purpose:        Cisco Umbrella Root CA Detection for Intune
#>
#endregion

#region Initialize
$ErrorActionPreference = 'SilentlyContinue'

#region Certificate Information
$CertificateThumbprint = "C5091132E9ADF8AD3E33932AE60A5C8FA939E824"
$CertificateStore = "Root"
$StoreLocation = "LocalMachine"
#endregion

#region Detection Logic
try {
    # Build certificate path
    $CertificateStorePath = "Cert:\$StoreLocation\$CertificateStore\$CertificateThumbprint"
    
    # Check if certificate exists
    if (Test-Path -Path $CertificateStorePath) {
        # Certificate found - additional verification
        $Certificate = Get-Item -Path $CertificateStorePath
        
        if ($Certificate.Thumbprint -eq $CertificateThumbprint) {
            Write-Output "Cisco Umbrella Root CA certificate detected"
            Write-Output "Thumbprint: $($Certificate.Thumbprint)"
            Write-Output "Subject: $($Certificate.Subject)"
            Write-Output "Expiry: $($Certificate.NotAfter)"
            exit 0
        }
    }
    
    # Certificate not found
    Write-Output "Cisco Umbrella Root CA certificate not found"
    exit 1
}
catch {
    # Error during detection - assume not installed
    Write-Output "Detection error: $_"
    exit 1
}
#endregion