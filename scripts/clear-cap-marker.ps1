# Run after deleting a manual save so the mod stops using the cap (delete) path.
$marker = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-at-cap.json'
if (Test-Path -LiteralPath $marker) {
    Remove-Item -LiteralPath $marker -Force
    Write-Host "Cap marker cleared."
} else {
    Write-Host "Cap marker was not set."
}
Write-Host "Or in-game: oow.clear_cap"
