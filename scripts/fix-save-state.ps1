# Recover TOW2 manual save desync without in-game console. Run OUTSIDE the game.
param(
    [switch]$Apply,
    [switch]$Force,
    [string]$OrphanGuid = '',
    [string]$DeletedGuid = '81AB1E9A437BA1A2FB46F9BFAED76478'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Tow2Script = Join-Path $RepoRoot 'scripts\tow2-ue4ss.ps1'
$RefreshScript = Join-Path $RepoRoot 'scripts\refresh-save-cache.ps1'
$root = Join-Path $env:USERPROFILE 'Saved Games\TheOuterWorlds2'
$guidPattern = '^[0-9A-Fa-f]{32}$'
$RecoveryFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-recovery.txt'
$BackupRoot = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-backup'
$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) { Write-Error 'TOW2 WinGDK folder not found.' }
$Ue4ssLog = Join-Path $WinGDK 'ue4ss\UE4SS.log'
$ModLog = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-mod-log.txt'

function Write-Recovery([string[]]$Lines) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $body = @("updated=$stamp") + $Lines
    Set-Content -LiteralPath $RecoveryFile -Value $body -Encoding UTF8
    Write-Host ''
    Write-Host "Recovery status written: $RecoveryFile" -ForegroundColor Cyan
    $body | ForEach-Object { Write-Host $_ }
}

function Get-LastDeleteGameOkGuid {
    param([string[]]$LogPaths)
    foreach ($path in $LogPaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $matches = Select-String -LiteralPath $path -Pattern 'DeleteGame OK for ([0-9A-Fa-f]{32})' -AllMatches
        if ($matches) {
            return $matches[-1].Matches[0].Groups[1].Value.ToUpper()
        }
    }
    return $null
}

function Test-GameRunning {
    $names = @('Arkansas', 'Arkansas-WinGDK-Shipping', 'TheOuterWorlds2')
    foreach ($n in $names) {
        if (Get-Process -Name $n -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

Write-Host '=== TOW2 save recovery ===' -ForegroundColor Cyan

if ((Test-GameRunning) -and -not $Force) {
    Write-Host 'Game appears to be running. Quit The Outer Worlds 2 fully, then re-run with -Apply.' -ForegroundColor Red
    Write-Recovery @(
        'status=BLOCKED'
        'reason=Game is running. Quit completely (not pause menu), then run: .\scripts\fix-save-state.ps1 -Apply'
    )
    exit 2
}

if (-not (Test-Path -LiteralPath $root)) {
    Write-Error "Save folder missing: $root"
}

$manual = @(Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -match $guidPattern })
$sorted = $manual | Sort-Object LastWriteTimeUtc
$count = $sorted.Count
$oldest = if ($sorted.Count -gt 0) { $sorted[0].Name.ToUpper() } else { $null }
$newest = if ($sorted.Count -gt 0) { $sorted[-1].Name.ToUpper() } else { $null }

Write-Host "Manual save folders on disk: $count / 100"
Write-Host "Oldest: $oldest"
Write-Host "Newest: $newest"

$lastDeleteOk = Get-LastDeleteGameOkGuid @($Ue4ssLog, $ModLog)
if ($lastDeleteOk) {
    Write-Host "Last engine DeleteGame OK (from logs): $lastDeleteOk" -ForegroundColor Yellow
}

$missing81 = -not (Test-Path -LiteralPath (Join-Path $root $DeletedGuid))
if ($missing81) {
    Write-Host "Known missing folder (old mod filesystem delete): $DeletedGuid" -ForegroundColor Yellow
}

# Pick orphan folder to quarantine: explicit param > last DeleteGame OK > oldest on disk when at cap
$orphan = $OrphanGuid.ToUpper()
if (-not $orphan) { $orphan = $lastDeleteOk }
if (-not $orphan -and $count -ge 100 -and $oldest) { $orphan = $oldest }

$orphanPath = if ($orphan) { Join-Path $root $orphan } else { $null }
$orphanExists = $orphanPath -and (Test-Path -LiteralPath $orphanPath)

Write-Host ''
if (-not $Apply) {
    Write-Host 'DRY RUN (no changes). Re-run with -Apply to fix.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Planned actions with -Apply:'
    Write-Host '  1. Disable OverwriteOldestSave mod and UE4SS for next launch'
    if ($count -ge 100 -and $orphanExists) {
        Write-Host "  2. Move orphan folder to backup: $orphan"
        Write-Host '     (engine already dropped this slot; folder left on disk)'
    } elseif ($count -ge 100) {
        Write-Host '  2. Cannot pick orphan folder automatically - pass -OrphanGuid'
    } else {
        Write-Host '  2. No disk orphan removal needed (count < 100)'
    }
    Write-Host '  3. Refresh save cache'
    Write-Host ''
    Write-Host 'After -Apply, in-game (one step): pause menu -> Save Game once.'
    exit 0
}

# --- Apply ---
& $Tow2Script -Action disable-overwrite
& $Tow2Script -Action disable-ue4ss
Write-Host 'Mod and UE4SS disabled for next launch.' -ForegroundColor Green

$moved = $null
if ($count -ge 100 -and $orphanExists) {
    $destRoot = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
    $dest = Join-Path $destRoot $orphan
    Move-Item -LiteralPath $orphanPath -Destination $dest -Force
    $moved = $orphan
    Write-Host "Moved orphan to backup: $dest" -ForegroundColor Green
    $count -= 1
} elseif ($count -ge 100) {
    Write-Host 'At 100 on disk but no orphan folder to move. Manual Load Game delete may be needed.' -ForegroundColor Yellow
}

& $RefreshScript

$after = @(Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -match $guidPattern }).Count

$recovery = @(
    'status=FIXED'
    "disk_before=$($sorted.Count)"
    "disk_after=$after"
    'mod=DISABLED'
    'ue4ss=DISABLED'
)
if ($moved) { $recovery += "orphan_moved=$moved" }
if ($missing81) { $recovery += "ghost_hint=$DeletedGuid (folder missing on disk from old mod delete)" }

if ($after -eq 99) {
    $recovery += 'next_step=Launch game (mod off). Load your character. Pause menu -> Save Game once. You should reach 100/100.'
} elseif ($after -eq 100) {
    $recovery += 'next_step=Launch game (mod off). If Save Game fails, delete oldest save from Load Game menu once, then Save Game.'
} else {
    $recovery += "next_step=Launch game (mod off). You have $after saves on disk - save normally until 100/100."
}

$recovery += 'do_not_re_enable_mod_until_manual_save_works'
Write-Recovery $recovery

Write-Host ''
Write-Host '=== Done ===' -ForegroundColor Green
Write-Host "Disk now: $after / 100 manual save folders"
Write-Host 'Launch the game (UE4SS off). One pause-menu Save Game should finish recovery.'
