# Show whether the mod loaded this session and what it last did.
param([switch]$Balloon, [switch]$Tail)

. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$Marker = Join-Path $env:LOCALAPPDATA "OverwriteOldestSave-mod-active.txt"
$EventLog = Join-Path $env:LOCALAPPDATA "OverwriteOldestSave-mod-log.txt"
$ConsoleOut = Join-Path $env:LOCALAPPDATA "OverwriteOldestSave-last-console.txt"
$GameRoot = Get-Tow2WinGDKRoot
if (-not $GameRoot) {
    Write-Error 'TOW2 WinGDK folder not found.'
}
$NotifyPs1 = Join-Path $GameRoot "ue4ss\Mods\OverwriteOldestSave\notify.ps1"
$Ue4ssLog = Join-Path $GameRoot "ue4ss\UE4SS.log"
$GamepadJson = Join-Path $env:LOCALAPPDATA "OverwriteOldestSave-gamepad.json"

function Show-Balloon([string]$Title, [string]$Message) {
    if (-not (Test-Path -LiteralPath $NotifyPs1)) {
        Write-Warning "notify.ps1 not found: $NotifyPs1"
        return
    }
    $tmp = Join-Path $env:TEMP "oow-notify-manual.txt"
    Set-Content -LiteralPath $tmp -Value @($Title, $Message)
    & $NotifyPs1 -MessageFile $tmp
}

if (-not (Test-Path -LiteralPath $Marker)) {
    Write-Host "Mod marker not found. Launch the game with UE4SS + OverwriteOldestSave enabled."
    Write-Host "Expected: $Marker"
    exit 1
}

Write-Host "=== Mod status (marker) ==="
Get-Content -LiteralPath $Marker
Write-Host ""
Write-Host "Marker file time:" (Get-Item -LiteralPath $Marker).LastWriteTime

if (Test-Path -LiteralPath $ConsoleOut) {
    Write-Host ""
    Write-Host "=== Last console command output ==="
    Get-Content -LiteralPath $ConsoleOut
}

if (Test-Path -LiteralPath $EventLog) {
    Write-Host ""
    Write-Host "=== Recent events ==="
    if ($Tail) {
        Get-Content -LiteralPath $EventLog -Tail 15
    } else {
        Get-Content -LiteralPath $EventLog -Tail 8
    }
}

if (Test-Path -LiteralPath $Ue4ssLog) {
    $startup = Select-String -LiteralPath $Ue4ssLog -Pattern 'STARTUP session=' | Select-Object -Last 1
    if ($startup) {
        Write-Host ""
        Write-Host "=== Latest UE4SS startup line ==="
        Write-Host $startup.Line
    }
}

if ($Balloon) {
    $lines = Get-Content -LiteralPath $Marker
    $map = @{}
    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') { $map[$Matches[1]] = $Matches[2] }
    }
    $title = if ($map.headline) { $map.headline } else { "Overwrite Oldest Save" }
    $msg = @(
        "v$($map.version) session $($map.session)"
        "Updated $($map.updated)"
        $(if ($map.detail) { $map.detail } else { $map.headline })
    ) -join "`n"
    Show-Balloon $title $msg
}

Write-Host ""
Write-Host "=== Gamepad bridge ==="
. (Join-Path $PSScriptRoot 'lib\gamepad-bridge-host.ps1')
$bridgeProc = Get-GamepadBridgeRunningProcess
if ($bridgeProc) {
    Write-Host "Running (pid $($bridgeProc.ProcessId))"
} else {
    Write-Host "Not running — run .\scripts\start-gamepad-bridge.ps1 or .\scripts\install-gamepad-bridge-autostart.ps1"
}
if (Test-GamepadBridgeAutostartInstalled) {
    Write-Host "Autostart: installed (runs at Windows logon)"
} else {
    Write-Host "Autostart: not installed — run .\scripts\install-gamepad-bridge-autostart.ps1"
}
if (Test-Path -LiteralPath $GamepadJson) {
    $ageSec = ((Get-Date) - (Get-Item -LiteralPath $GamepadJson).LastWriteTime).TotalSeconds
    Write-Host ("State file: fresh ({0:N0}s ago)" -f $ageSec)
} else {
    Write-Host "State file: missing"
}

Write-Host ""
Write-Host "Tip: run again with -Balloon for a tray popup, -Tail for more log lines."
