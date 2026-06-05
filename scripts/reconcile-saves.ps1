# Compare disk manual save folders vs cache; report orphans and desync hints. Run OUTSIDE the game.
param(
    [switch]$RefreshCache
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SaveRoot = Join-Path $env:USERPROFILE 'Saved Games\TheOuterWorlds2'
$CacheFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-save-cache.json'
$GuidPattern = '^[0-9A-F]{32}$'

if ($RefreshCache) {
    & (Join-Path $RepoRoot 'scripts\refresh-save-cache.ps1')
}

if (-not (Test-Path -LiteralPath $SaveRoot)) {
    Write-Host "Save root not found: $SaveRoot"
    exit 1
}

$diskFolders = Get-ChildItem -LiteralPath $SaveRoot -Directory |
    Where-Object { $_.Name -match $GuidPattern } |
    Sort-Object LastWriteTimeUtc

Write-Host "=== Save reconcile ==="
Write-Host "Disk GUID folders: $($diskFolders.Count) / 100"
Write-Host "Save root: $SaveRoot"

$cachedNames = @()
if (Test-Path -LiteralPath $CacheFile) {
    try {
        $cache = Get-Content -LiteralPath $CacheFile -Raw | ConvertFrom-Json
        if ($cache.entries) {
            $cachedNames = @($cache.entries | ForEach-Object { $_.name.ToUpper() })
        }
        Write-Host "Cache file: $CacheFile ($($cachedNames.Count) entries, scanned $($cache.scannedAt))"
    } catch {
        Write-Warning "Could not read cache: $_"
    }
} else {
    Write-Host "Cache missing. Run: .\scripts\refresh-save-cache.ps1"
}

if ($diskFolders.Count -ge 100) {
    Write-Host ""
    Write-Host "At or over cap on disk." -ForegroundColor Yellow
    Write-Host "If in-game UI shows 99/100 and Save Game fails, run oow.delete_oldest in console,"
    Write-Host "then Save Game from pause menu (do NOT use console SaveGame)."
}

if ($diskFolders.Count -eq 99) {
    Write-Host ""
    Write-Host "One slot free on disk - pause menu Save Game should reach 100/100." -ForegroundColor Green
    Write-Host "If Save Game says unsuccessful, engine may think it is full (ghost slot)."
    Write-Host "Try oow.save_health and oow.delete_oldest in console."
}

if ($diskFolders.Count -gt 0) {
    Write-Host ""
    Write-Host "Oldest: $($diskFolders[0].Name) ($($diskFolders[0].LastWriteTime))"
    Write-Host "Newest: $($diskFolders[-1].Name) ($($diskFolders[-1].LastWriteTime))"
}

$onlyPng = @()
foreach ($folder in $diskFolders) {
    $files = Get-ChildItem -LiteralPath $folder.FullName -File -ErrorAction SilentlyContinue
    if ($files.Count -eq 1 -and $files[0].Name -eq 'SaveGameScreenshot.png') {
        $onlyPng += $folder
    }
}

if ($onlyPng.Count -gt 0) {
    Write-Host ""
    Write-Host "Folders with only SaveGameScreenshot.png: $($onlyPng.Count) (may be stale/orphan)" -ForegroundColor Yellow
    $onlyPng | Select-Object -First 5 | ForEach-Object { Write-Host "  $($_.Name)" }
}

Write-Host ""
Write-Host "Do NOT delete save folders manually unless fix-save-state.ps1 instructs you to."
