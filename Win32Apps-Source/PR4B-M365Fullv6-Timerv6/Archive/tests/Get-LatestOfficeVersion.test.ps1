# function Get-LatestOfficeVersion {
#     <#
#     .SYNOPSIS
#     Fetches the latest version of Microsoft 365 Apps from Microsoft's Office CDN API.

#     .PARAMETER ChannelUrl
#     The URL of the Office CDN API file for the desired update channel.

#     .EXAMPLE
#     Get-LatestOfficeVersion -ChannelUrl "https://config.office.com/api/officeclient/versioninfo?channel=MonthlyEnterprise"
#     Fetches the latest version from the Monthly Enterprise Channel.
#     #>

#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$ChannelUrl
#     )

#     Begin {
#         Write-Host "Fetching the latest Microsoft 365 Apps version from $ChannelUrl..."
#     }

#     Process {
#         try {
#             # Fetch the version info from the Office CDN API
#             $response = Invoke-RestMethod -Uri $ChannelUrl -UseBasicParsing -ErrorAction Stop

#             # Extract the latest version number
#             $latestVersion = $response.version

#             if ($latestVersion) {
#                 Write-Host "Latest Microsoft 365 Apps version: $latestVersion"
#                 return $latestVersion
#             } else {
#                 Write-Error "Failed to retrieve the latest version from the Office CDN."
#                 return $null
#             }
#         }
#         catch {
#             Write-Error "An error occurred while fetching the Office version: $($_.Exception.Message)"
#             return $null
#         }
#     }
# }

# # Example usage:
# $channelUrl = "https://config.office.com/api/officeclient/versioninfo?channel=MonthlyEnterprise"
# $latestVersion = Get-LatestOfficeVersion -ChannelUrl $channelUrl





# # Define variables
# $channel = "Current"  # Change to the desired channel (e.g., "Current", "MonthlyEnterprise")
# $platform = "Windows"  # Set to "Windows" or "Mac"
# $product = "O365ProPlusRetail"  # Set the correct product identifier

# # Generate a random GUID for the client request
# $clientRequestId = [guid]::NewGuid()

# # Construct the URL
# $url = "https://config.office.com/api/versionhistory?channel=$channel&clientrequestid=$clientRequestId&platform=$platform&product=$product"

# # Fetch the version information
# $response = Invoke-RestMethod -Uri $url -Method Get

# # Extract the latest version from the response
# $latestVersion = $response.versionHistory[0].version

# Write-Host "Latest Version: $latestVersion"






# # Example: Change the channel or platform and test
# $channel = "MonthlyEnterprise"  # Try "Current", "MonthlyEnterprise", etc.
# $platform = "Windows"  # Ensure this matches your environment
# $product = "O365ProPlusRetail"  # This should be valid for Microsoft 365 Apps

# # Generate a random GUID
# $clientRequestId = [guid]::NewGuid()

# # Construct the URL
# $url = "https://config.office.com/api/versionhistory?channel=$channel&clientrequestid=$clientRequestId&platform=$platform&product=$product"

# # Test with Invoke-WebRequest to see if there's a response
# $response = Invoke-WebRequest -Uri $url -Method Get
# $response.Content  # Check the raw content if it succeeds




# # Define the URL for the Microsoft 365 Apps Release Notes page
# $url = "https://learn.microsoft.com/en-us/officeupdates/current-channel"

# # Fetch the HTML content from the Microsoft release notes page
# $response = Invoke-WebRequest -Uri $url

# # Use regex to find the latest version number from the HTML content
# $versionMatch = $response.Content -match 'Version (\d{4}): (\w+ \d+)'

# if ($versionMatch) {
#     $latestVersion = $matches[1]
#     Write-Host "Latest Microsoft 365 Apps Version: $latestVersion"
# } else {
#     Write-Host "Could not retrieve the latest version."
# }





# # Define the URL for the Microsoft 365 Apps Current Channel release notes
# $url = "https://learn.microsoft.com/en-us/officeupdates/current-channel"

# # Fetch the HTML content from the page
# $response = Invoke-WebRequest -Uri $url

# # Use regex to find both the latest version and build number from the HTML content
# $regex = [regex]'Version (\d{4}):\s.*?Build (\d{5}\.\d{5})'

# $matches = $regex.Match($response.Content)

# if ($matches.Success) {
#     $latestVersion = $matches.Groups[1].Value
#     $latestBuild = $matches.Groups[2].Value
#     Write-Host "Latest Microsoft 365 Apps Version: $latestVersion"
#     Write-Host "Latest Microsoft 365 Apps Build: $latestBuild"
# } else {
#     Write-Host "Could not retrieve the latest version and build number."
# }




# Define the URL of the release notes page
$releaseNotesUrl = "https://learn.microsoft.com/en-us/officeupdates/current-channel"

# Fetch the content of the page
$response = Invoke-WebRequest -Uri $releaseNotesUrl

# Convert the content to a string for regex processing
$pageContent = $response.Content

# Define the regex pattern for the version and build number
# Pattern for 'Version XXXX' (e.g., 'Version 2408')
$versionPattern = 'Version (\d{4})'
# Pattern for 'Build XXXXX.XXXXX' (e.g., 'Build 17928.20156')
$buildPattern = 'Build (\d{5}\.\d{5})'

# Use regex to find the first match for the version
$versionMatch = [regex]::Match($pageContent, $versionPattern)
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { 'Version not found' }

# Use regex to find the first match for the build number
$buildMatch = [regex]::Match($pageContent, $buildPattern)
$build = if ($buildMatch.Success) { $buildMatch.Groups[1].Value } else { 'Build not found' }

# Output the captured version and build number
Write-Host "Latest Microsoft 365 Apps Version: $version"
Write-Host "Latest Build Number: $build"
