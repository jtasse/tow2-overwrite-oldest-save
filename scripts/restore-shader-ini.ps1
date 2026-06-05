# Write TOW2 Engine.ini / Game.ini before launch if the game stripped them.
# Usage:
#   .\scripts\restore-shader-ini.ps1 -Mode build-cache
#   .\scripts\restore-shader-ini.ps1 -Mode fast-boot
#
# Call before starting the game when Engine.ini keeps disappearing.

param(
    [ValidateSet('build-cache', 'enable', 'fast-boot')]
    [string]$Mode = 'fast-boot'
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot 'skip-shader-warmup.ps1') -Action $Mode
