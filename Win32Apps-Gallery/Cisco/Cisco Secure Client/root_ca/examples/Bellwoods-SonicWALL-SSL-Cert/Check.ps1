#Unique Tracking ID: 50ed2b1e-b96b-437b-b3ac-d035dc575793, Timestamp: 2024-02-15 13:23:30

function AOCheckCertificateExistence {
    param(
        [Parameter(Mandatory)]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory)]
        [string]$StoreName = "Root" # Default store set to Trusted Root CA
    )

    $certificateExists = $false
    $certificateStorePath = "Cert:\LocalMachine\$StoreName\$CertificateThumbprint"

    # Check for Certificate existence
    if (Test-Path -Path $certificateStorePath) {
        $certificateExists = $true
        Write-Host "Certificate with thumbprint '$CertificateThumbprint' exists in $StoreName store."
        exit 0 # Certificate found
    }
    else {
        # Write-Host "Certificate with thumbprint '$CertificateThumbprint' does not exist in $StoreName store."
        exit 1 # Certificate not found
    }
}

# Usage
$CertificateThumbprint = 'c7a39354590a5f39cb445ecde64e670fa77ede36'
$StoreName = "Root" # Specify the store name here
AOCheckCertificateExistence -CertificateThumbprint $CertificateThumbprint -StoreName $StoreName