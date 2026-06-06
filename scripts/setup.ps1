# First-time (or full refresh) setup: UE4SS core if missing, then enable mod.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) {
    Write-Error 'TOW2 WinGDK folder not found. Install the game from Xbox app first.'
}

$needsCore = -not (Test-Path -LiteralPath (Join-Path $WinGDK 'dwmapi.dll')) -or
    -not (Test-Path -LiteralPath (Join-Path $WinGDK 'ue4ss\UE4SS.dll'))

if ($needsCore) {
    Write-Host 'UE4SS core not found — installing experimental build + OW2 config...'
    & (Join-Path $PSScriptRoot 'upgrade-ue4ss.ps1')
}

& (Join-Path $PSScriptRoot 'enable-mod.ps1')

Write-Host ''
Write-Host 'Controller: .\scripts\start-gamepad-bridge.ps1 (once per session, for LT+LB+X)' -ForegroundColor Cyan
Write-Host 'Next: fully quit + launch game, load a save, wait ~30s.' -ForegroundColor Cyan
Write-Host 'Verify: .\scripts\mod-status.ps1' -ForegroundColor Cyan
