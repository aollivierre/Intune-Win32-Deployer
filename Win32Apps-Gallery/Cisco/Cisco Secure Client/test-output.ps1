# Test output length
$output = & powershell -ExecutionPolicy Bypass -File check.ps1 2>&1
Write-Host "Output length: $($output.Length)"
Write-Host "Output empty: $($null -eq $output -or $output.Length -eq 0)"
Write-Host "Exit code: $LASTEXITCODE"