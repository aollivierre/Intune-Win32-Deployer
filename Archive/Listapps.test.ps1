# Install-Module Microsoft.Graph.Intune -Scope AllUsers -Force
Install-Module Microsoft.Graph.Devices.CorporateManagement -Scope AllUsers -Force


Connect-MgGraph -Scopes "DeviceManagementApps.Read.All"

$apps = Get-MgDeviceAppManagementMobileApp
$apps | ForEach-Object { $_.DisplayName }