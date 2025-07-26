#region Script Information
<#
.SYNOPSIS
    Installs the Cisco Umbrella Root CA certificate to the Trusted Root Certificate store

.DESCRIPTION
    This script installs the Cisco Umbrella Root CA certificate into the LocalMachine\Root 
    certificate store to enable SSL inspection for Cisco Umbrella DNS protection.
    Designed for deployment via Microsoft Intune as a Win32 app.

.NOTES
    Version:        1.0
    Author:         Automated Script
    Creation Date:  2025-07-19
    Purpose:        Cisco Umbrella Root CA Installation for SSL Inspection
#>
#endregion

#region Initialize
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

try {
    #region Certificate Information
    $CertificateFileName = "Cisco_Umbrella_Root_CA.cer"
    $CertificateThumbprint = "C5091132E9ADF8AD3E33932AE60A5C8FA939E824"
    $CertificateStore = "Root"
    $StoreLocation = "LocalMachine"
    #endregion

    #region Main Installation Logic
    Write-Output "Starting Cisco Umbrella Root CA installation..."
    
    # Get script directory
    $ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    $CertificatePath = Join-Path -Path $ScriptDirectory -ChildPath $CertificateFileName
    
    # Verify certificate file exists
    if (-not (Test-Path -Path $CertificatePath -PathType Leaf)) {
        throw "Certificate file not found at: $CertificatePath"
    }
    
    # Check if certificate already exists
    $ExistingCert = Get-ChildItem -Path "Cert:\$StoreLocation\$CertificateStore" | 
                    Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    
    if ($ExistingCert) {
        Write-Output "Certificate already installed with thumbprint: $CertificateThumbprint"
        exit 0
    }
    
    # Import certificate
    Write-Output "Importing certificate from: $CertificatePath"
    $Certificate = Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\$StoreLocation\$CertificateStore"
    
    if ($Certificate.Thumbprint -eq $CertificateThumbprint) {
        Write-Output "Successfully installed Cisco Umbrella Root CA certificate"
        Write-Output "Thumbprint: $($Certificate.Thumbprint)"
        Write-Output "Subject: $($Certificate.Subject)"
        exit 0
    } else {
        throw "Certificate was imported but thumbprint mismatch detected"
    }
    #endregion
}
catch {
    Write-Error "Failed to install certificate: $_"
    exit 1
}