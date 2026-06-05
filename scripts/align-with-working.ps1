# Align broken PC with known-good NZXUS profile (same repo scripts).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) { Write-Error 'WinGDK not found.' }

# Working PC has no override.txt.
$override = Join-Path $WinGDK 'override.txt'
if (Test-Path -LiteralPath $override) {
    Remove-Item -LiteralPath $override -Force
    Write-Host 'Removed override.txt (not used on working PC).'
}

& (Join-Path $PSScriptRoot 'install-ue4ss-config.ps1')
& (Join-Path $PSScriptRoot 'enable-mod.ps1')

Write-Host ''
Write-Host '=== After align ===' 
$exe = Join-Path $WinGDK 'TheOuterWorlds2-WinGDK-Shipping.exe'
Write-Host "Game exe modified: $((Get-Item -LiteralPath $exe).LastWriteTime)"
Write-Host 'If Xbox says "Something went wrong launching": Verify and repair in Xbox app (do not copy exe from another PC).'
Write-Host 'Then fully quit + relaunch, run: .\scripts\mod-status.ps1'
