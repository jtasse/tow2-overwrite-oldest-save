# Remove logon autostart and stop the gamepad bridge.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\gamepad-bridge-host.ps1')

Remove-GamepadBridgeAutostart
Write-Host 'Gamepad bridge autostart removed and bridge stopped.'
Write-Host 'Keyboard Ctrl+Shift+O still works. Re-enable with .\scripts\install-gamepad-bridge-autostart.ps1'
