
function Log-Params {
    param (
        [hashtable]$Params
    )

    foreach ($key in $Params.Keys) {
        Write-EnhancedLog -message "$key $($Params[$key])" -level 'INFO'
    }
}
