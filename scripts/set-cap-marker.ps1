# Run when pause menu shows 100/100 and engine count is unreadable in-game.
$ErrorActionPreference = 'Stop'
$marker = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-at-cap.json'
$payload = @{
    atCap = $true
    count = 100
    setAt = (Get-Date).ToUniversalTime().ToString('o')
    source = 'host'
} | ConvertTo-Json -Compress
Set-Content -LiteralPath $marker -Value $payload -Encoding UTF8
Write-Host "Cap marker set (100/100) -> $marker"
Write-Host "In-game: oow.save will DeleteGame oldest + Quicksave."
Write-Host "After deleting a save in pause menu, run: .\scripts\clear-cap-marker.ps1"
