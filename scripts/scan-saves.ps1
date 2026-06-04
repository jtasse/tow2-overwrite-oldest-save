# Run OUTSIDE the game — lists manual save slots (GUID folders).
$root = Join-Path $env:USERPROFILE "Saved Games\TheOuterWorlds2"
$guidPattern = '^[0-9A-F]{32}$'

if (-not (Test-Path -LiteralPath $root)) {
    Write-Host "Folder not found: $root"
    exit 1
}

$manual = Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -match $guidPattern }
$sorted = $manual | Sort-Object LastWriteTimeUtc

Write-Host "Root: $root"
Write-Host "Manual save folders: $($manual.Count)"
if ($sorted.Count -gt 0) {
    Write-Host "Oldest slot folder: $($sorted[0].Name)"
    Write-Host "  Path: $($sorted[0].FullName)"
    Write-Host "  Time: $($sorted[0].LastWriteTime)"
    Write-Host "Newest slot folder: $($sorted[-1].Name)"
}

Write-Host ""
Write-Host "Autosaves at root:"
Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^Autosave' } |
    ForEach-Object { Write-Host "  $($_.Name)" }
