# Refresh save cache, deploy mod, enable UE4SS + OverwriteOldestSave. Run OUTSIDE the game.
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $RepoRoot 'scripts\refresh-save-cache.ps1')
& (Join-Path $RepoRoot 'scripts\deploy.ps1') -EnableMod
& (Join-Path $RepoRoot 'scripts\tow2-ue4ss.ps1') -Action enable-ue4ss
& (Join-Path $RepoRoot 'scripts\tow2-ue4ss.ps1') -Action enable-overwrite

Write-Host ''
Write-Host 'In-game: Ctrl+Shift+O OR hold LB+RB and tap A (Xbox)' -ForegroundColor Green
Write-Host 'At 100/100: deletes oldest then Quicksave. Below cap: just Quicksave.'
Write-Host 'After session: .\scripts\refresh-save-cache.ps1 on host'
