# Start external Ctrl+Shift+O -> oow.s hotkey (WinGDK workaround).
# In-mod keyboard/gamepad chords crash TOW2; console commands are stable.
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$ahkScript = Join-Path $scriptDir 'oow-save-hotkey.ahk'

function Find-AutoHotkey {
    $cmd = Get-Command 'AutoHotkey64.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $paths = @(
        "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe"
        "${env:ProgramFiles}\AutoHotkey\AutoHotkey64.exe"
        "${env:LocalAppData}\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$ahk = Find-AutoHotkey
if (-not $ahk) {
    Write-Host 'AutoHotkey v2 not found.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Install: winget install AutoHotkey.AutoHotkey'
    Write-Host 'Then re-run: .\scripts\start-hotkey-binder.ps1'
    Write-Host ''
    Write-Host 'Until then, use oow.s in the in-game console (~).'
    exit 1
}

$running = Get-CimInstance Win32_Process -Filter "Name = 'AutoHotkey64.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*oow-save-hotkey.ahk*" }
if ($running) {
    Write-Host 'Hotkey binder already running (Ctrl+Shift+O when TOW2 is focused).'
    exit 0
}

Start-Process -FilePath $ahk -ArgumentList @('"' + $ahkScript + '"')
Write-Host 'Started oow-save-hotkey.ahk'
Write-Host '  Ctrl+Shift+O  ->  oow.s  (only while The Outer Worlds 2 is focused)'
Write-Host '  Tray icon stays in the notification area until you exit the script.'
Write-Host ''
Write-Host 'Controller: map LT+LB+X to Ctrl+Shift+O in reWASD / Xbox Accessories,'
Write-Host '  or keep using oow.s in the console.'
