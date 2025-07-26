#region Script Information
<#
.SYNOPSIS
    Uninstalls the Cisco Umbrella Root CA certificate from the Trusted Root Certificate store

.DESCRIPTION
    This script removes the Cisco Umbrella Root CA certificate from the LocalMachine\Root 
    certificate store. Designed for deployment via Microsoft Intune as a Win32 app uninstall action.

.NOTES
    Version:        1.0
    Author:         Automated Script
    Creation Date:  2025-07-19
    Purpose:        Cisco Umbrella Root CA Removal
#>
#endregion

#region Initialize
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

try {
    #region Certificate Information
    $CertificateThumbprint = "C5091132E9ADF8AD3E33932AE60A5C8FA939E824"
    $CertificateStore = "Root"
    $StoreLocation = "LocalMachine"
    $CertificateSubject = "CN=Cisco Umbrella Root CA, O=Cisco"
    #endregion

    #region Main Uninstallation Logic
    Write-Output "Starting Cisco Umbrella Root CA removal..."
    
    # Find certificate by thumbprint
    $CertPath = "Cert:\$StoreLocation\$CertificateStore"
    $ExistingCert = Get-ChildItem -Path $CertPath | 
                    Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    
    if (-not $ExistingCert) {
        Write-Output "Certificate not found with thumbprint: $CertificateThumbprint"
        exit 0
    }
    
    # Remove certificate
    Write-Output "Found certificate: $($ExistingCert.Subject)"
    Write-Output "Removing certificate with thumbprint: $CertificateThumbprint"
    
    Remove-Item -Path "$CertPath\$CertificateThumbprint" -Force
    
    # Verify removal
    $VerifyCert = Get-ChildItem -Path $CertPath | 
                  Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    
    if (-not $VerifyCert) {
        Write-Output "Successfully removed Cisco Umbrella Root CA certificate"
        exit 0
    } else {
        throw "Certificate removal verification failed"
    }
    #endregion
}
catch {
    Write-Error "Failed to remove certificate: $_"
    exit 1
}