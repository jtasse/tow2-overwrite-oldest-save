# Quick UE4SS + mod health check (run after launching the game once).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) { Write-Error 'TOW2 WinGDK folder not found.' }

$Ue4ss = Join-Path $WinGDK 'ue4ss'
$logs = @(
    (Join-Path $WinGDK 'UE4SS.log'),
    (Join-Path $Ue4ss 'UE4SS.log')
)

Write-Host "WinGDK: $WinGDK"
Write-Host "dwmapi.dll:" (Test-Path (Join-Path $WinGDK 'dwmapi.dll'))
Write-Host "override.txt:" (Test-Path (Join-Path $WinGDK 'override.txt'))
if (Test-Path (Join-Path $WinGDK 'override.txt')) {
    Write-Host "  -> $(Get-Content (Join-Path $WinGDK 'override.txt') -Raw)"
}
Write-Host "UE4SS.dll:" (Test-Path (Join-Path $Ue4ss 'UE4SS.dll'))
Write-Host "bUseUObjectArrayCache:" (Select-String -LiteralPath (Join-Path $Ue4ss 'UE4SS-settings.ini') -Pattern 'bUseUObjectArrayCache').Line

$foundLog = $false
foreach ($log in $logs) {
    if (Test-Path -LiteralPath $log) {
        $foundLog = $true
        Write-Host "--- $log (last 20 lines) ---"
        Get-Content -LiteralPath $log -Tail 20
        Write-Host "--- OverwriteOldestSave in log ---"
        Select-String -LiteralPath $log -Pattern 'OverwriteOldestSave' | Select-Object -Last 8 | ForEach-Object { $_.Line }
    }
}
if (-not $foundLog) {
    Write-Host 'NO UE4SS.log — UE4SS did not inject. Full quit + relaunch game, then run this again.'
}

$marker = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-mod-active.txt'
if (Test-Path $marker) {
    Write-Host "--- mod marker ---"
    Get-Content $marker -Tail 5
} else {
    Write-Host 'No mod marker (mod main.lua did not run).'
}

$cache = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-save-cache.json'
Write-Host "Save cache:" (Test-Path $cache)
