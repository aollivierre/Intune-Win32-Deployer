# Test exact output
$output = & powershell -ExecutionPolicy Bypass -File check.ps1 2>&1
Write-Host "Output: [$output]"
Write-Host "Output length: $($output.Length)"
Write-Host "Exit code: $LASTEXITCODE"