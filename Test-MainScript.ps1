# Test runner for the main script
# This will test if the authentication works in the actual script

Write-Host "Starting main script test..." -ForegroundColor Yellow
Write-Host "This will test the authentication portion only" -ForegroundColor Cyan

# Set environment variable for dev mode
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'dev', 'Machine')

# Run the main script but exit after authentication
$scriptPath = "C:\Code\Intune-Win32-Deployer\Intune-Win32-Deployer-ALPHAv1.ps1"

# We'll modify the command to exit after auth test
$testScript = @'
# Load the main script content
$mainScript = Get-Content "C:\Code\Intune-Win32-Deployer\Intune-Win32-Deployer-ALPHAv1.ps1" -Raw

# Add an exit after authentication verification
$modifiedScript = $mainScript -replace '(\$Global:AuthenticationHeader\) \{[\s\S]*?Write-EnhancedLog[^\n]*"IntuneWin32App module authentication verified successfully"[^\n]*\n', @'
$Global:AuthenticationHeader) {
            Write-EnhancedLog -Message "IntuneWin32App module authentication verified successfully" -Level "INFO"
            
            # TEST MODE: Exit after successful authentication
            Write-Host "`n`nTEST SUCCESSFUL: Authentication completed!" -ForegroundColor Green
            Write-Host "Global:AuthenticationHeader exists: $($null -ne $Global:AuthenticationHeader)" -ForegroundColor Cyan
            Write-Host "Global:AccessToken exists: $($null -ne $Global:AccessToken)" -ForegroundColor Cyan
            Write-Host "Ready to process Win32 apps!" -ForegroundColor Green
            exit 0
'@

# Save modified script
$tempScript = "$env:TEMP\Test-MainScript-Temp.ps1"
$modifiedScript | Set-Content $tempScript -Force

# Run it
& $tempScript
'@

# Execute the test
$testScript | Set-Content "$env:TEMP\RunMainScriptTest.ps1" -Force

Write-Host "`nLaunching main script in test mode..." -ForegroundColor Yellow
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\RunMainScriptTest.ps1"