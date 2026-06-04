# Copy UE4SS mod into the Game Pass WinGDK install.
param(
    [string]$GameRoot = "C:\Program Files\WindowsApps\Microsoft.OE-Arkansas_1.256.9237.0_x64__8wekyb3d8bbwe\Arkansas\Binaries\WinGDK"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $RepoRoot "src\ue4ss-mod"
$Dest = Join-Path $GameRoot "ue4ss\Mods\OverwriteOldestSave"
$ModsDir = Join-Path $GameRoot "ue4ss\Mods"

if (-not (Test-Path $Src)) {
    Write-Error "Source not found: $Src"
}

if (-not (Test-Path $ModsDir)) {
    Write-Error "UE4SS Mods folder not found: $ModsDir`nExtract UE4SS into WinGDK first (see docs/INSTALL-DEV.md)."
}

if (Test-Path $Dest) {
    Remove-Item -LiteralPath $Dest -Recurse -Force
}

Copy-Item -LiteralPath $Src -Destination $Dest -Recurse -Force
Write-Host "Deployed to $Dest"
Write-Host "Ensure ue4ss\Mods\mods.txt contains: OverwriteOldestSave : 1"
