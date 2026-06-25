# Export UE4SS + mod install fingerprint for comparing two PCs.
# Run on EACH machine (after one game launch on the working PC), then diff the output files.
param(
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

function Get-DefaultProfilePath {
    $candidates = @(
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'OneDrive\Desktop'),
        $env:TEMP,
        (Split-Path -Parent $PSScriptRoot)
    )
    foreach ($dir in $candidates) {
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            return Join-Path $dir 'tow2-machine-profile.txt'
        }
    }
    return Join-Path $env:TEMP 'tow2-machine-profile.txt'
}

if (-not $OutFile) {
    $OutFile = Get-DefaultProfilePath
}
$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

function Get-FileFingerprint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '(missing)' }
    $i = Get-Item -LiteralPath $Path -Force
    return "{0} | size={1} | modified={2}" -f $i.FullName, $i.Length, $i.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
}

function Get-HashOrMissing([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '(missing)' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.Substring(0, 16)
}

$WinGDK = Get-Tow2WinGDKRoot
$Ue4ss = if ($WinGDK) { Join-Path $WinGDK 'ue4ss' } else { $null }
$lines = @()
$lines += "=== TOW2 machine profile ==="
$lines += "generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "computer: $env:COMPUTERNAME"
$lines += "user: $env:USERNAME"
$lines += ""

if (-not $WinGDK) {
    $lines += "ERROR: WinGDK not found"
} else {
    $lines += "WinGDK: $WinGDK"
    $item = Get-Item -LiteralPath $WinGDK -Force
    if ($item.Target) { $lines += "WinGDK junction target: $($item.Target -join ', ')" }

    $lines += ""
    $lines += "--- core files ---"
    foreach ($rel in @('dwmapi.dll', 'override.txt', 'TheOuterWorlds2-WinGDK-Shipping.exe', 'ue4ss\UE4SS.dll', 'ue4ss\UE4SS-settings.ini', 'ue4ss\VTableLayout.ini', 'ue4ss\UE4SS.log', 'UE4SS.log')) {
        $p = Join-Path $WinGDK $rel
        $lines += Get-FileFingerprint $p
        if ($rel -match '\.dll$') { $lines += "  sha256-prefix: $(Get-HashOrMissing $p)" }
    }

    if (Test-Path (Join-Path $WinGDK 'override.txt')) {
        $lines += "override.txt content: $(Get-Content (Join-Path $WinGDK 'override.txt') -Raw)"
    }

    $settings = Join-Path $Ue4ss 'UE4SS-settings.ini'
    if (Test-Path $settings) {
        $lines += ""
        $lines += "--- UE4SS-settings (key lines) ---"
        Select-String -LiteralPath $settings -Pattern 'bUseUObjectArrayCache|MajorVersion|MinorVersion|HookProcessLocalScriptFunction|ConsoleEnabled|UseCache' |
            ForEach-Object { $lines += $_.Line.Trim() }
    }

    $modsTxt = Join-Path $Ue4ss 'Mods\mods.txt'
    if (Test-Path $modsTxt) {
        $lines += ""
        $lines += "--- mods.txt ---"
        Get-Content $modsTxt | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*;' } | ForEach-Object { $lines += $_.Trim() }
    }

    $modConfig = Join-Path $Ue4ss 'Mods\OverwriteOldestSave\scripts\config.lua'
    if (Test-Path $modConfig) {
        $lines += ""
        $lines += "--- deployed mod ---"
        Select-String -LiteralPath $modConfig -Pattern 'MOD_VERSION' | ForEach-Object { $lines += $_.Line.Trim() }
    }

    $lines += ""
    $lines += "--- enabled.txt stray files ---"
    Get-ChildItem (Join-Path $Ue4ss 'Mods') -Filter 'enabled.txt' -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { $lines += $_.FullName }
    if (-not (Get-ChildItem (Join-Path $Ue4ss 'Mods') -Filter 'enabled.txt' -Recurse -ErrorAction SilentlyContinue)) {
        $lines += '(none)'
    }
}

$lines += ""
$lines += "--- local mod state ---"
foreach ($p in @(
    "$env:LOCALAPPDATA\OverwriteOldestSave-save-cache.json",
    "$env:LOCALAPPDATA\OverwriteOldestSave-mod-active.txt",
    "$env:LOCALAPPDATA\OverwriteOldestSave-last-console.txt"
)) {
    $lines += Get-FileFingerprint $p
}

$lines += ""
$lines += "--- repo (if git) ---"
$repo = Split-Path -Parent $PSScriptRoot
if (Test-Path (Join-Path $repo '.git')) {
    $git = 'git'
    if (Test-Path 'C:\Program Files\Git\bin\git.exe') { $git = 'C:\Program Files\Git\bin\git.exe' }
    $lines += & $git -C $repo branch --show-current 2>$null
    $lines += & $git -C $repo log -1 --oneline 2>$null
} else {
    $lines += '(not a git repo)'
}

$lines += ""
$lines += "--- WindowsApps packages (OE-Arkansas) ---"
Get-ChildItem 'C:\Program Files\WindowsApps' -Filter 'Microsoft.OE-Arkansas*' -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { $lines += $_.Name }

$text = $lines -join "`r`n"
Set-Content -LiteralPath $OutFile -Value $text -Encoding UTF8
Write-Host "Wrote: $OutFile"
Write-Host ""
Write-Host $text
