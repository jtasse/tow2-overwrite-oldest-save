# Run OUTSIDE the game — writes save folder list for the mod (no subprocess in-game).
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:USERPROFILE 'Saved Games\TheOuterWorlds2'
$cacheFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-save-cache.json'
$pendingOrphan = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-pending-orphan.txt'
$backupRoot = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-backup'
$guidPattern = '^[0-9A-Fa-f]{32}$'

if (-not (Test-Path -LiteralPath $root)) {
    Write-Error "Save root not found: $root"
}

function Move-PendingOrphan {
    if (-not (Test-Path -LiteralPath $pendingOrphan)) { return }

    $map = @{}
    Get-Content -LiteralPath $pendingOrphan | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() }
    }
    $guid = $map.guid
    if (-not $guid) {
        Remove-Item -LiteralPath $pendingOrphan -Force -ErrorAction SilentlyContinue
        return
    }

    $orphanPath = Join-Path $root $guid
    if (-not (Test-Path -LiteralPath $orphanPath)) {
        Write-Host "Pending orphan already gone: $guid"
        Remove-Item -LiteralPath $pendingOrphan -Force
        return
    }

    $destRoot = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
    $dest = Join-Path $destRoot $guid
    Move-Item -LiteralPath $orphanPath -Destination $dest -Force
    Remove-Item -LiteralPath $pendingOrphan -Force
    Write-Host "Moved engine-deleted orphan to backup: $dest" -ForegroundColor Green
}

Move-PendingOrphan

$manual = Get-ChildItem -LiteralPath $root -Directory |
    Where-Object { $_.Name -match $guidPattern } |
    Sort-Object LastWriteTimeUtc

$entries = foreach ($dir in $manual) {
    @{
        name = $dir.Name
        path = $dir.FullName
        lastWriteUtc = $dir.LastWriteTimeUtc.ToString('o')
    }
}

$payload = @{
    version = 1
    scannedAt = (Get-Date).ToUniversalTime().ToString('o')
    saveRoot = $root
    count = $entries.Count
    cap = 100
    oldest = if ($entries.Count -gt 0) { $entries[0].name } else { $null }
    newest = if ($entries.Count -gt 0) { $entries[-1].name } else { $null }
    entries = $entries
}

$json = $payload | ConvertTo-Json -Depth 4 -Compress
Set-Content -LiteralPath $cacheFile -Value $json -Encoding UTF8
Write-Host "Wrote $($entries.Count) saves -> $cacheFile"
if ($entries.Count -gt 0) {
    Write-Host "Oldest: $($entries[0].name)"
    Write-Host "Newest: $($entries[-1].name)"
}
