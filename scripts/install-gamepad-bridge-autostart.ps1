# Install logon autostart for the gamepad bridge and start it now.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\gamepad-bridge-host.ps1')

$state = Start-GamepadBridge
Install-GamepadBridgeAutostart | Out-Null

if ($state.AlreadyRunning) {
    Write-Host "Gamepad bridge already running (pid $($state.ProcessId))."
} elseif ($state.Started) {
    Write-Host "Gamepad bridge started (pid $($state.ProcessId))."
} else {
    Write-Warning 'Gamepad bridge did not start — check controller is connected.'
}

Write-Host 'Autostart installed: bridge runs at Windows logon (LT+L3+R3 ready before you launch the game).'
Write-Host "Host copy: $($state.HostDir)"
Write-Host 'To disable: .\scripts\remove-gamepad-bridge-autostart.ps1'
