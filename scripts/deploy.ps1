# Copy UE4SS mod into the Game Pass WinGDK install.
param(
    [string]$GameRoot,
    [switch]$EnableMod
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\game-path.ps1")

if (-not $GameRoot) {
    $GameRoot = Get-Tow2WinGDKRoot
}
if (-not $GameRoot) {
    Write-Error "Could not find TOW2 WinGDK folder. Install UE4SS first (see README.md)."
}
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

$RefreshScript = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\refresh-save-cache.ps1"
if (Test-Path -LiteralPath $RefreshScript) {
    & $RefreshScript
}

$Tow2Script = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\tow2-ue4ss.ps1"
if (Test-Path -LiteralPath $Tow2Script) {
    if ($EnableMod) {
        & $Tow2Script -Action enable-overwrite
        Write-Host "Mod deployed and ENABLED."
    } else {
        & $Tow2Script -Action disable-overwrite
        Write-Host "Mod deployed but DISABLED - run enable-mod.ps1 when ready."
    }
} else {
    Write-Host "Ensure ue4ss\Mods\mods.txt contains: OverwriteOldestSave : 1 and ConsoleCommandsMod : 1"
}
