# Manage TOW2 UE4SS without opening WindowsApps in Explorer.
# Run: Right-click -> Run with PowerShell (or: powershell -ExecutionPolicy Bypass -File .\scripts\tow2-ue4ss.ps1)

param(
    [ValidateSet('status', 'disable-overwrite', 'enable-overwrite', 'disable-all-mods', 'minimal-ue4ss', 'enable-ue4ss-only-overwrite', 'disable-ue4ss', 'enable-ue4ss', 'open-log')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$WinGDK = 'C:\Program Files\WindowsApps\Microsoft.OE-Arkansas_1.256.9237.0_x64__8wekyb3d8bbwe\Arkansas\Binaries\WinGDK'
$Ue4ss = Join-Path $WinGDK 'ue4ss'
$ModsTxt = Join-Path $Ue4ss 'Mods\mods.txt'
$EnabledTxt = Join-Path $Ue4ss 'Mods\OverwriteOldestSave\enabled.txt'
$DwmApi = Join-Path $WinGDK 'dwmapi.dll'
$DwmApiOff = Join-Path $WinGDK 'dwmapi.dll.off'
$LogFile = Join-Path $Ue4ss 'UE4SS.log'

if (-not (Test-Path -LiteralPath $Ue4ss)) {
    Write-Error "UE4SS folder not found: $Ue4ss"
}

function Set-ModLine([string]$Name, [int]$Value) {
    $lines = Get-Content -LiteralPath $ModsTxt
    $out = foreach ($line in $lines) {
        if ($line -match "^\s*$([regex]::Escape($Name))\s*:") {
            "$Name : $Value"
        } else { $line }
    }
    Set-Content -LiteralPath $ModsTxt -Value $out
}

function Set-AllMods([int]$Value) {
    $lines = Get-Content -LiteralPath $ModsTxt
    $out = foreach ($line in $lines) {
        if ($line -match '^\s*([^;\s]+)\s*:\s*\d+\s*$' -and $Matches[1] -ne 'Keybinds') {
            "$($Matches[1]) : $Value"
        } else { $line }
    }
    Set-Content -LiteralPath $ModsTxt -Value $out
}

switch ($Action) {
    'status' {
        Write-Host "UE4SS: $Ue4ss"
        Write-Host "enabled.txt present:" (Test-Path -LiteralPath $EnabledTxt)
        Write-Host "dwmapi.dll (UE4SS injector):" (Test-Path -LiteralPath $DwmApi)
        Write-Host "--- mods.txt ---"
        Get-Content -LiteralPath $ModsTxt | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*;' }
        if (Test-Path -LiteralPath $LogFile) {
            Write-Host "--- last 5 log lines ---"
            Get-Content -LiteralPath $LogFile -Tail 5
        }
    }
    'disable-overwrite' {
        if (Test-Path -LiteralPath $EnabledTxt) { Remove-Item -LiteralPath $EnabledTxt -Force }
        Set-ModLine 'OverwriteOldestSave' 0
        Write-Host "OverwriteOldestSave disabled (removed enabled.txt if present)."
    }
    'enable-overwrite' {
        if (Test-Path -LiteralPath $EnabledTxt) { Remove-Item -LiteralPath $EnabledTxt -Force }
        Set-ModLine 'OverwriteOldestSave' 1
        Write-Host "OverwriteOldestSave enabled in mods.txt only."
    }
    'disable-all-mods' {
        if (Test-Path -LiteralPath $EnabledTxt) { Remove-Item -LiteralPath $EnabledTxt -Force }
        Set-AllMods 0
        Write-Host "All mods in mods.txt set to 0 (except Keybinds line untouched)."
    }
    'minimal-ue4ss' {
        if (Test-Path -LiteralPath $EnabledTxt) { Remove-Item -LiteralPath $EnabledTxt -Force }
        Set-ModLine 'CheatManagerEnablerMod' 0
        Set-ModLine 'ConsoleCommandsMod' 0
        Set-ModLine 'ConsoleEnablerMod' 0
        Set-ModLine 'BPML_GenericFunctions' 0
        Set-ModLine 'BPModLoaderMod' 0
        Set-ModLine 'OverwriteOldestSave' 0
        Set-ModLine 'Keybinds' 0
        if (Test-Path -LiteralPath $DwmApiOff) {
            Rename-Item -LiteralPath $DwmApiOff -NewName 'dwmapi.dll' -Force
        }
        Write-Host "UE4SS ON with zero Lua mods (bisect crash). Use Vortex Console Enabler for ~ if needed."
        Write-Host "If this still crashes, UE4SS core/config is incompatible — try a newer UE4SS experimental build."
    }
    'enable-ue4ss-only-overwrite' {
        if (Test-Path -LiteralPath $EnabledTxt) { Remove-Item -LiteralPath $EnabledTxt -Force }
        Set-ModLine 'CheatManagerEnablerMod' 0
        Set-ModLine 'ConsoleCommandsMod' 1
        Set-ModLine 'ConsoleEnablerMod' 0
        Set-ModLine 'BPML_GenericFunctions' 0
        Set-ModLine 'BPModLoaderMod' 0
        Set-ModLine 'OverwriteOldestSave' 1
        Set-ModLine 'Keybinds' 0
        if (Test-Path -LiteralPath $DwmApiOff) {
            Rename-Item -LiteralPath $DwmApiOff -NewName 'dwmapi.dll' -Force
        }
        Write-Host "UE4SS ON: OverwriteOldestSave + ConsoleCommandsMod (Vortex supplies ~)."
        Write-Host "Test in game: ~ then oow.discover_save"
    }
    'disable-ue4ss' {
        if (Test-Path -LiteralPath $DwmApi) {
            Rename-Item -LiteralPath $DwmApi -NewName 'dwmapi.dll.off' -Force
            Write-Host "Renamed dwmapi.dll -> dwmapi.dll.off (UE4SS off for next launch)."
        } else { Write-Host "dwmapi.dll already absent or renamed." }
    }
    'enable-ue4ss' {
        if (Test-Path -LiteralPath $DwmApiOff) {
            Rename-Item -LiteralPath $DwmApiOff -NewName 'dwmapi.dll' -Force
            Write-Host "Restored dwmapi.dll (UE4SS on for next launch)."
        } else { Write-Host "dwmapi.dll.off not found." }
    }
    'open-log' {
        if (Test-Path -LiteralPath $LogFile) { notepad $LogFile } else { Write-Host "No log: $LogFile" }
    }
}
