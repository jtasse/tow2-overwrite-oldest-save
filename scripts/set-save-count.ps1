# Set tracked save count when pause-menu UI sync fails in-game.
param(
    [Parameter(Mandatory = $true)]
    [int]$Count
)

$ErrorActionPreference = 'Stop'
$max = 100
if ($Count -lt 0 -or $Count -gt $max) {
    throw "Count must be 0..$max"
}

$countFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-save-count.json'
$capFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-at-cap.json'
$payload = @{
    count = $Count
    source = 'host'
    updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
} | ConvertTo-Json -Compress
Set-Content -LiteralPath $countFile -Value $payload -Encoding UTF8
Write-Host "Tracked save count set to $Count/$max -> $countFile"

if ($Count -ge $max) {
    $capPayload = @{
        atCap = $true
        count = $max
        setAt = (Get-Date).ToUniversalTime().ToString('o')
        source = 'host'
    } | ConvertTo-Json -Compress
    Set-Content -LiteralPath $capFile -Value $capPayload -Encoding UTF8
    Write-Host "Cap marker set ($max/$max) -> $capFile"
} elseif (Test-Path -LiteralPath $capFile) {
    Remove-Item -LiteralPath $capFile -Force
    Write-Host "Cap marker cleared (below cap)."
}

Write-Host "Restart not required - next oow.save uses $Count/$max for cap decisions."
