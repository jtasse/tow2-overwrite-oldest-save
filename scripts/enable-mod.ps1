# Refresh save cache, deploy mod, enable UE4SS + OverwriteOldestSave. Run OUTSIDE the game.
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $RepoRoot 'scripts\install-ue4ss-config.ps1')
& (Join-Path $RepoRoot 'scripts\refresh-save-cache.ps1')
& (Join-Path $RepoRoot 'scripts\deploy.ps1') -EnableMod
& (Join-Path $RepoRoot 'scripts\tow2-ue4ss.ps1') -Action enable-ue4ss
& (Join-Path $RepoRoot 'scripts\tow2-ue4ss.ps1') -Action enable-overwrite

Write-Host ''
Write-Host 'In-game or pause: Ctrl+Shift+O OR (hold LT+LB) + tap X (Xbox)' -ForegroundColor Green
Write-Host 'At 100/100: deletes oldest then Quicksave (manual slot). Below cap: SaveGame.'
Write-Host 'After launch: .\scripts\mod-status.ps1   After session: .\scripts\refresh-save-cache.ps1'
