# Run after deleting manual saves so the mod stops using the cap (delete) path.
param(
    [int]$Count = 0
)

$marker = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-at-cap.json'
$countFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-save-count.json'

if (Test-Path -LiteralPath $marker) {
    Remove-Item -LiteralPath $marker -Force
    Write-Host "Cap marker cleared."
} else {
    Write-Host "Cap marker was not set."
}

if ($Count -gt 0) {
    & (Join-Path $PSScriptRoot 'set-save-count.ps1') -Count $Count
} elseif (Test-Path -LiteralPath $countFile) {
    Remove-Item -LiteralPath $countFile -Force
    Write-Host "Tracked save count cleared -> $countFile"
}

Write-Host "In-game: oow.set_count <n> or oow.clear_cap"
