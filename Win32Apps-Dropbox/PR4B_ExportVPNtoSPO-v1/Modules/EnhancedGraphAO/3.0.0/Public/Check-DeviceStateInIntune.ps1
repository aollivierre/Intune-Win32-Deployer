# function Get-DeviceStateInIntune {
#     param (
#         [string]$entraDeviceId,
#         [hashtable]$headers,
#         [string]$intuneUrlBase = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
#     )

#     if (-not [string]::IsNullOrWhiteSpace($entraDeviceId)) {
#         Write-EnhancedLog -Message "Converting Entra Device ID to Intune Device ID: $entraDeviceId" -Level "INFO" -ForegroundColor ([ConsoleColor]::Cyan)

#         # Convert Entra Device ID to Intune Device ID
#         $intuneDeviceId = Convert-EntraDeviceIdToIntuneDeviceId -entraDeviceId $entraDeviceId -Headers $headers
#         if (-not $intuneDeviceId) {
#             Write-EnhancedLog -Message "Intune Device ID not found for Entra Device ID: $entraDeviceId" -Level "WARN" -ForegroundColor ([ConsoleColor]::Yellow)
#             return "Absent"
#         }

#         Write-EnhancedLog -Message "Checking device state in Intune for Device ID: $intuneDeviceId" -Level "INFO" -ForegroundColor ([ConsoleColor]::Cyan)

#         # Construct the Intune URL
#         $intuneUrl = "$intuneUrlBase/$intuneDeviceId"
#         Write-Output "Constructed Intune URL: $intuneUrl"

#         # Send the request
#         try {
#             $response = Invoke-WebRequest -Uri $intuneUrl -Headers $headers -Method Get
#             $data = ($response.Content | ConvertFrom-Json)

#             if ($data) {
#                 return "Present"
#             } else {
#                 return "Absent"
#             }
#         } catch {
#             Write-EnhancedLog -Message "Error querying Intune: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
#             return "Error"
#         }
#     } else {
#         Write-EnhancedLog -Message "Device ID is empty, skipping Intune check" -Level "WARN" -ForegroundColor ([ConsoleColor]::Yellow)
#         return "Absent"
#     }
# }

# # # Example usage
# # $json = @(
# #     [PSCustomObject]@{ deviceDetail = [PSCustomObject]@{ deviceId = "73e94a92-fc5a-45b6-bf6c-90ce8a353c44"; displayName = "ICTC-570"; operatingSystem = "Windows10"; isCompliant = $false; trustType = "Hybrid Azure AD joined" }; userDisplayName = "Manisha Exavier"; userId = "053d1dfc-778b-4692-a15d-51a3ebd62014" },
# #     [PSCustomObject]@{ deviceDetail = [PSCustomObject]@{ deviceId = $null; displayName = "ICTC-570"; operatingSystem = "Windows10"; isCompliant = $false; trustType = "Hybrid Azure AD joined" }; userDisplayName = "Manisha Exavier"; userId = "053d1dfc-778b-4692-a15d-51a3ebd62014" },
# #     [PSCustomObject]@{ deviceDetail = [PSCustomObject]@{ deviceId = ""; displayName = "ICTC-570"; operatingSystem = "Windows10"; isCompliant = $false; trustType = "Hybrid Azure AD joined" }; userDisplayName = "Manisha Exavier"; userId = "053d1dfc-778b-4692-a15d-51a3ebd62014" }
# # )
# # $headers = @{ Authorization = "Bearer your-access-token" }

# # # Process the logs and filter details
# # $results = foreach ($item in $json) {
# #     $deviceState = Get-DeviceStateInIntune -entraDeviceId $item.deviceDetail.deviceId -Headers $headers

# #     [PSCustomObject]@{
# #         'DeviceName'             = $item.deviceDetail.displayName
# #         'UserName'               = $item.userDisplayName
# #         'DeviceEntraID'          = $item.deviceDetail.deviceId
# #         'UserEntraID'            = $item.userId
# #         'DeviceOS'               = $item.deviceDetail.operatingSystem
# #         'DeviceComplianceStatus' = if ($item.deviceDetail.isCompliant) { "Compliant" } else { "Non-Compliant" }
# #         'DeviceStateInIntune'    = $deviceState
# #         'TrustType'              = $item.deviceDetail.trustType
# #     }
# # }

# # # Output results
# # $results | Format-Table -AutoSize





# function Check-DeviceStateInIntune {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$entraDeviceId,
#         [Parameter(Mandatory = $true)]
#         [hashtable]$headers
#     )

#     Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

#     # Construct the Graph API URL to retrieve device details
#     $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
#     Write-Host "Constructed Graph API URL: $graphApiUrl"

#     # Send the request
#     try {
#         $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
#         $data = ($response.Content | ConvertFrom-Json).value

#         if ($data -and $data.Count -gt 0) {
#             Write-Host "Device is present in Intune." -ForegroundColor Green
#             return "Present"
#         } else {
#             Write-Host "Device is absent in Intune." -ForegroundColor Yellow
#             return "Absent"
#         }
#     } catch {
#         Write-Host "Error querying Intune: $_" -ForegroundColor Red
#         return "Error"
#     }
# }

# Example usage
# $headers = @{ Authorization = "Bearer your-access-token" }
# $entraDeviceId = "9e6d73cb-97ad-4383-bd96-e8a86ab14627"

# $deviceState = Check-DeviceStateInIntune -entraDeviceId $entraDeviceId -Headers $headers
# Write-Output "Device State: $deviceState"








# function Check-DeviceStateInIntune {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$entraDeviceId,
#         [Parameter(Mandatory = $true)]
#         [hashtable]$headers
#     )

#     Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

#     # Construct the Graph API URL to retrieve device details
#     $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
#     Write-Host "Constructed Graph API URL: $graphApiUrl"

#     # Send the request
#     try {
#         $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
#         $data = ($response.Content | ConvertFrom-Json).value

#         if ($data -and $data.Count -gt 0) {
#             Write-Host "Device is present in Intune." -ForegroundColor Green
#             return "Present"
#         } else {
#             Write-Host "Device is absent in Intune." -ForegroundColor Yellow
#             return "Absent"
#         }
#     } catch {
#         Write-Host "Error querying Intune: $_" -ForegroundColor Red
#         return "Error"
#     }
# }




# function Check-DeviceStateInIntune {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$entraDeviceId,
#         [Parameter(Mandatory = $true)]
#         [hashtable]$headers
#     )

#     if (-not [string]::IsNullOrWhiteSpace($entraDeviceId)) {
#         Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

#         # Construct the Graph API URL to retrieve device details
#         $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
#         Write-Host "Constructed Graph API URL: $graphApiUrl"

#         # Send the request
#         try {
#             $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
#             $data = ($response.Content | ConvertFrom-Json).value

#             if ($data -and $data.Count -gt 0) {
#                 Write-Host "Device is present in Intune." -ForegroundColor Green
#                 return "Present"
#             } else {
#                 Write-Host "Device is absent in Intune." -ForegroundColor Yellow
#                 return "Absent"
#             }
#         } catch {
#             Write-Host "Error querying Intune: $_" -ForegroundColor Red
#             return "Error"
#         }
#     } else {
#         Write-Host "Device ID is empty, considered as BYOD." -ForegroundColor Yellow
#         return "BYOD"
#     }
# }






# function Check-DeviceStateInIntune {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$entraDeviceId,
#         [Parameter(Mandatory = $true)]
#         [hashtable]$headers
#     )

#     if (-not [string]::IsNullOrWhiteSpace($entraDeviceId)) {
#         Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

#         # Construct the Graph API URL to retrieve device details
#         $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
#         Write-Host "Constructed Graph API URL: $graphApiUrl"

#         # Send the request
#         try {
#             $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
#             $data = ($response.Content | ConvertFrom-Json).value

#             if ($data -and $data.Count -gt 0) {
#                 Write-Host "Device is present in Intune." -ForegroundColor Green
#                 return "Present"
#             } else {
#                 Write-Host "Device is absent in Intune." -ForegroundColor Yellow
#                 return "Absent"
#             }
#         } catch {
#             Write-Host "Error querying Intune: $_" -ForegroundColor Red
#             return "Error"
#         }
#     } else {
#         Write-Host "Device ID is empty, considered as BYOD." -ForegroundColor Yellow
#         return "BYOD"
#     }
# }









# function Check-DeviceStateInIntune {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$entraDeviceId,
#         [Parameter(Mandatory = $true)]
#         [hashtable]$headers
#     )

#     if (-not [string]::IsNullOrWhiteSpace($entraDeviceId)) {
#         Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

#         # Construct the Graph API URL to retrieve device details
#         $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
#         Write-Host "Constructed Graph API URL: $graphApiUrl"

#         # Send the request
#         try {
#             $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
#             $data = ($response.Content | ConvertFrom-Json).value

#             if ($data -and $data.Count -gt 0) {
#                 Write-Host "Device is present in Intune." -ForegroundColor Green
#                 return "Present"
#             } else {
#                 Write-Host "Device is absent in Intune." -ForegroundColor Yellow
#                 return "Absent"
#             }
#         } catch {
#             Write-Host "Error querying Intune: $_" -ForegroundColor Red
#             return "Error"
#         }
#     } else {
#         Write-Host "Device ID is empty, considered as BYOD." -ForegroundColor Yellow
#         return "BYOD"
#     }
# }









# function Check-DeviceStateInIntune {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$entraDeviceId,
#         [Parameter(Mandatory = $true)]
#         [hashtable]$headers
#     )

#     if (-not [string]::IsNullOrWhiteSpace($entraDeviceId)) {
#         Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

#         # Construct the Graph API URL to retrieve device details
#         $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
#         Write-Host "Constructed Graph API URL: $graphApiUrl"

#         # Send the request
#         try {
#             $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
#             $data = ($response.Content | ConvertFrom-Json).value

#             if ($data -and $data.Count -gt 0) {
#                 Write-Host "Device is present in Intune." -ForegroundColor Green
#                 return "Present"
#             } else {
#                 Write-Host "Device is absent in Intune." -ForegroundColor Yellow
#                 return "Absent"
#             }
#         } catch {
#             Write-Host "Error querying Intune: $_" -ForegroundColor Red
#             return "Error"
#         }
#     } else {
#         Write-Host "Device ID is empty, considered as BYOD." -ForegroundColor Yellow
#         return "BYOD"
#     }
# }





function Check-DeviceStateInIntune {
    param (
        [Parameter(Mandatory = $true)]
        [string]$entraDeviceId,
        [Parameter(Mandatory = $true)]
        [hashtable]$headers
    )

    if (-not [string]::IsNullOrWhiteSpace($entraDeviceId)) {
        Write-Host "Checking device state in Intune for Entra Device ID: $entraDeviceId" -ForegroundColor Cyan

        # Construct the Graph API URL to retrieve device details
        $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$entraDeviceId'"
        Write-Host "Constructed Graph API URL: $graphApiUrl"

        # Send the request
        try {
            $response = Invoke-WebRequest -Uri $graphApiUrl -Headers $headers -Method Get
            $data = ($response.Content | ConvertFrom-Json).value

            if ($data -and $data.Count -gt 0) {
                Write-Host "Device is present in Intune." -ForegroundColor Green
                return "Present"
            } else {
                Write-Host "Device is absent in Intune." -ForegroundColor Yellow
                return "Absent"
            }
        } catch {
            Write-Host "Error querying Intune: $_" -ForegroundColor Red
            return "Error"
        }
    } else {
        # Write-Host "Device ID is empty, considered as BYOD." -ForegroundColor Yellow #uncomment if verbose output is desired
        return "BYOD"
    }
}



