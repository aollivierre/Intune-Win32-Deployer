function Get-LatestODTUrl {
    <#
    .SYNOPSIS
    Retrieves the latest Office Deployment Tool (ODT) download URL from the Microsoft website.

    .DESCRIPTION
    This function attempts to scrape the latest ODT download link from the Microsoft download page. It includes a retry mechanism and waits between attempts if the request fails.

    .PARAMETER MaxRetries
    The maximum number of retries if the web request fails.

    .PARAMETER RetryInterval
    The number of seconds to wait between retries.

    .EXAMPLE
    $odtUrl = Get-LatestODTUrl -MaxRetries 3 -RetryInterval 5
    if ($odtUrl) { Write-Host "ODT URL: $odtUrl" }
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Maximum number of retries.")]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false, HelpMessage = "Number of seconds to wait between retries.")]
        [int]$RetryInterval = 5
    )

    Begin {
        Write-EnhancedLog -Message "Starting Get-LatestODTUrl function" -Level "NOTICE"
        Write-EnhancedLog -Message "MaxRetries: $MaxRetries, RetryInterval: $RetryInterval seconds" -Level "INFO"

        $odtPageUrl = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $attempt = 0
        $odtDownloadLink = $null
    }

    Process {
        while ($attempt -lt $MaxRetries -and -not $odtDownloadLink) {
            try {
                $attempt++
                Write-EnhancedLog -Message "Attempt $attempt of $MaxRetries to retrieve ODT URL..." -Level "INFO"

                # Use Invoke-WebRequest to scrape the page
                $response = Invoke-WebRequest -Uri $odtPageUrl -ErrorAction Stop
                Write-EnhancedLog -Message "Successfully retrieved page content on attempt $attempt." -Level "INFO"

                # Search for the ODT download link in the page content
                $odtDownloadLink = $response.Links | Where-Object { $_.href -match "download.microsoft.com" } | Select-Object -First 1

                if ($odtDownloadLink) {
                    Write-EnhancedLog -Message "ODT download link found: $($odtDownloadLink.href)" -Level "INFO"
                    return $odtDownloadLink.href
                } else {
                    Write-EnhancedLog -Message "ODT download link not found on attempt $attempt." -Level "WARNING"
                }
            }
            catch {
                Write-EnhancedLog -Message "Failed to retrieve ODT download page on attempt $attempt $($_.Exception.Message)" -Level "ERROR"
            }

            # Wait before the next attempt
            if ($attempt -lt $MaxRetries) {
                Write-EnhancedLog -Message "Waiting $RetryInterval seconds before retrying..." -Level "INFO"
                Start-Sleep -Seconds $RetryInterval
            }
        }

        # If all attempts fail
        Write-EnhancedLog -Message "Exceeded maximum retry attempts. Failed to retrieve ODT download link." -Level "ERROR"
        return $null
    }

    End {
        Write-EnhancedLog -Message "Exiting Get-LatestODTUrl function" -Level "NOTICE"
    }
}

# # Example usage with retries
# $odtUrlParams = @{
#     MaxRetries    = 3
#     RetryInterval = 5
# }
# $latestODTUrl = Get-LatestODTUrl @odtUrlParams

# if ($latestODTUrl) {
#     Write-Host "Latest ODT URL: $latestODTUrl"
# } else {
#     Write-Host "Failed to get the latest ODT URL." -ForegroundColor Red
# }

# # Wait-Debugger


function Download-ODT {
    <#
    .SYNOPSIS
    Downloads the Office Deployment Tool (ODT) and extracts it into a timestamped temp folder.

    .DESCRIPTION
    This function dynamically retrieves the latest ODT download URL using the Get-LatestODTUrl function, downloads the Office Deployment Tool (ODT) from that URL, runs it to extract the contents, and returns the status and full path to the `setup.exe` file.

    .PARAMETER DestinationDirectory
    The directory where the ODT will be extracted (default is a timestamped folder in temp).

    .PARAMETER MaxRetries
    The maximum number of retries for downloading the ODT file.

    .EXAMPLE
    $params = @{
        DestinationDirectory = "C:\Temp"
        MaxRetries           = 3
    }
    $odtInfo = Download-ODT @params
    if ($odtInfo.Status -eq 'Success') {
        Write-Host "ODT setup.exe located at: $($odtInfo.FullPath)"
    }
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Provide the destination directory for extraction.")]
        [string]$DestinationDirectory = ([System.IO.Path]::GetTempPath()),

        [Parameter(Mandatory = $false, HelpMessage = "Maximum number of retries for downloading.")]
        [int]$MaxRetries = 3
    )

    Begin {
        Write-EnhancedLog -Message "Starting Download-ODT function" -Level "NOTICE"
        Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters

        # Generate a timestamped folder for extraction
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $tempFolder = Join-Path -Path $DestinationDirectory -ChildPath "ODT_$timestamp"
        $tempExePath = Join-Path -Path $tempFolder -ChildPath "ODT.exe"

        # Initialize result object
        $result = [pscustomobject]@{
            Status   = "Failure"
            FullPath = $null
        }

        # Ensure destination folder exists
        if (-not (Test-Path $tempFolder)) {
            New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
            Write-EnhancedLog -Message "Created temporary folder: $tempFolder" -Level "INFO"
        } else {
            Write-EnhancedLog -Message "Temporary folder already exists: $tempFolder" -Level "INFO"
        }
    }

    Process {
        try {
            # Fetch the latest ODT URL dynamically
            Write-EnhancedLog -Message "Fetching the latest ODT URL dynamically..." -Level "INFO"
            $odtDownloadUrlParams = @{
                MaxRetries    = $MaxRetries
                RetryInterval = 5
            }
            $ODTDownloadUrl = Get-LatestODTUrl @odtDownloadUrlParams

            if (-not $ODTDownloadUrl) {
                Write-EnhancedLog -Message "Failed to retrieve the latest ODT download URL." -Level "ERROR"
                throw "Failed to retrieve the latest ODT download URL."
            }

            # Splatting download parameters
            $downloadParams = @{
                Source      = $ODTDownloadUrl
                Destination = $tempExePath
                MaxRetries  = $MaxRetries
            }

            Write-EnhancedLog -Message "Downloading ODT from $ODTDownloadUrl to $tempExePath" -Level "INFO"
            Start-FileDownloadWithRetry @downloadParams

            # Unblock and verify the downloaded file
            Write-EnhancedLog -Message "Unblocking downloaded file: $tempExePath" -Level "INFO"
            Unblock-File -Path $tempExePath

            # Run the executable to extract files
            Write-EnhancedLog -Message "Extracting ODT using $tempExePath" -Level "INFO"
            $startProcessParams = @{
                FilePath     = $tempExePath
                ArgumentList = "/quiet /extract:$tempFolder"
                Wait         = $true
            }
            Start-Process @startProcessParams

            # Locate setup.exe in the extracted files
            $setupExePath = Get-ChildItem -Path $tempFolder -Recurse -Filter "setup.exe" | Select-Object -First 1

            if ($setupExePath) {
                Write-EnhancedLog -Message "ODT downloaded and extracted successfully. Found setup.exe at: $($setupExePath.FullName)" -Level "INFO"
                $result.Status = "Success"
                $result.FullPath = $setupExePath.FullName
            } else {
                Write-EnhancedLog -Message "Error: setup.exe not found in the extracted files." -Level "ERROR"
            }
        }
        catch {
            Write-EnhancedLog -Message "An error occurred during the download or extraction: $($_.Exception.Message)" -Level "ERROR"
            Handle-Error -ErrorRecord $_
            throw
        }
        finally {
            # Clean up the downloaded .exe file
            if (Test-Path $tempExePath) {
                Write-EnhancedLog -Message "Cleaning up temporary exe file: $tempExePath" -Level "INFO"
                Remove-Item -Path $tempExePath -Force
            }
        }
    }

    End {
        Write-EnhancedLog -Message "Exiting Download-ODT function" -Level "NOTICE"
        # Return the result object with status and full path of setup.exe
        return $result
    }
}

# Example usage:
$params = @{
    DestinationDirectory = "$env:TEMP"
    MaxRetries           = 3
}
$odtInfo = Download-ODT @params

if ($odtInfo.Status -eq 'Success') {
    Write-Host "ODT setup.exe located at: $($odtInfo.FullPath)"
} else {
    Write-Host "Failed to download or extract ODT." -ForegroundColor Red
}

