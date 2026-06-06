# Start the XInput bridge (run once per gaming session, outside the game).
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$bridge = Join-Path $scriptDir 'gamepad-bridge.ps1'
$marker = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-gamepad-bridge.pid'

$running = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*gamepad-bridge.ps1*' }
if ($running) {
    Write-Host 'Gamepad bridge already running.'
    exit 0
}

$proc = Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-File', $bridge) `
    -PassThru -WindowStyle Hidden
Set-Content -LiteralPath $marker -Value $proc.Id
Write-Host "Gamepad bridge started (pid $($proc.Id))."
Write-Host "LT+LB+X will work in-game after mod loads (~15s)."
Write-Host "State file: $env:LOCALAPPDATA\OverwriteOldestSave-gamepad.json"
