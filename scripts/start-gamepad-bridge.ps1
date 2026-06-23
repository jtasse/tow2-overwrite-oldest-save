# Start the XInput bridge (idempotent). Autostart is installed by enable-mod / setup.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\gamepad-bridge-host.ps1')

$state = Start-GamepadBridge
$json = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-gamepad.json'

if ($state.AlreadyRunning) {
    Write-Host "Gamepad bridge already running (pid $($state.ProcessId))."
} elseif ($state.Started) {
    Write-Host "Gamepad bridge started (pid $($state.ProcessId))."
} else {
    Write-Warning 'Gamepad bridge did not start — connect a controller and retry.'
}

Write-Host 'Hold LT + click L3 and R3 together in-game after mod loads (~15s).'
Write-Host "State file: $json"

if (-not (Test-GamepadBridgeAutostartInstalled)) {
    Write-Host 'Tip: run .\scripts\install-gamepad-bridge-autostart.ps1 so you never need this manually.' -ForegroundColor Cyan
}
