# Shared helpers: sync bridge to LOCALAPPDATA, start it, optional logon autostart.

$script:GamepadBridgeTaskName = 'OverwriteOldestSave-GamepadBridge'

function Get-GamepadBridgeHostDir {
    Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave'
}

function Get-GamepadBridgeRepoScript {
    Join-Path (Split-Path -Parent $PSScriptRoot) 'gamepad-bridge.ps1'
}

function Get-GamepadBridgeRunningProcess {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*gamepad-bridge.ps1*' } |
        Select-Object -First 1
}

function Sync-GamepadBridgeHost {
    $hostDir = Get-GamepadBridgeHostDir
    $repoBridge = Get-GamepadBridgeRepoScript
    if (-not (Test-Path -LiteralPath $repoBridge)) {
        Write-Error "Bridge source not found: $repoBridge"
    }

    New-Item -ItemType Directory -Path $hostDir -Force | Out-Null
    Copy-Item -LiteralPath $repoBridge -Destination (Join-Path $hostDir 'gamepad-bridge.ps1') -Force

    $ensure = @'
# Ensures the XInput bridge is running (installed by OverwriteOldestSave enable-mod / setup).
$ErrorActionPreference = 'SilentlyContinue'
$HostDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Bridge = Join-Path $HostDir 'gamepad-bridge.ps1'
if (-not (Test-Path -LiteralPath $Bridge)) { exit 1 }
$running = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*gamepad-bridge.ps1*' }
if ($running) { exit 0 }
Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $Bridge) `
    -WindowStyle Hidden | Out-Null
'@
    Set-Content -LiteralPath (Join-Path $hostDir 'ensure-gamepad-bridge.ps1') -Value $ensure -Encoding UTF8
    return $hostDir
}

function Start-GamepadBridge {
    $hostDir = Sync-GamepadBridgeHost
    $existing = Get-GamepadBridgeRunningProcess
    if ($existing) {
        return @{
            Started = $false
            AlreadyRunning = $true
            ProcessId = $existing.ProcessId
            HostDir = $hostDir
        }
    }

    $ensure = Join-Path $hostDir 'ensure-gamepad-bridge.ps1'
    & $ensure
    Start-Sleep -Milliseconds 200
    $proc = Get-GamepadBridgeRunningProcess
    return @{
        Started = [bool]$proc
        AlreadyRunning = $false
        ProcessId = if ($proc) { $proc.ProcessId } else { $null }
        HostDir = $hostDir
    }
}

function Test-GamepadBridgeAutostartInstalled {
    $task = Get-ScheduledTask -TaskName $script:GamepadBridgeTaskName -ErrorAction SilentlyContinue
    return [bool]$task
}

function Install-GamepadBridgeAutostart {
    $hostDir = Sync-GamepadBridgeHost
    $ensure = Join-Path $hostDir 'ensure-gamepad-bridge.ps1'
    $arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ensure`""

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask `
        -TaskName $script:GamepadBridgeTaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description 'XInput bridge for The Outer Worlds 2 OverwriteOldestSave mod (LT+L3+R3).' `
        -Force | Out-Null

    return $ensure
}

function Remove-GamepadBridgeAutostart {
    Unregister-ScheduledTask -TaskName $script:GamepadBridgeTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*gamepad-bridge.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
