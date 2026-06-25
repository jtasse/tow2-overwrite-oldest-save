# Upgrade UE4SS core (dwmapi + UE4SS.dll) to experimental-latest; keep Mods + OW2 config.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) { Write-Error 'TOW2 WinGDK folder not found.' }

$Ue4ssDir = Join-Path $WinGDK 'ue4ss'
$ZipUrl = 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental-latest/UE4SS_v3.0.1-953-gb872ad11.zip'
$TempZip = Join-Path $env:TEMP 'UE4SS-experimental.zip'
$TempExtract = Join-Path $env:TEMP 'UE4SS-experimental-extract'

Write-Host "WinGDK: $WinGDK"
Write-Host 'Downloading experimental UE4SS...'
Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing

if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
Expand-Archive -LiteralPath $TempZip -DestinationPath $TempExtract -Force

# Zip layout: dwmapi.dll + ue4ss\ at top level (or nested one folder).
$dwmapi = Get-ChildItem -Path $TempExtract -Filter 'dwmapi.dll' -Recurse | Select-Object -First 1
$ue4dll = Get-ChildItem -Path $TempExtract -Filter 'UE4SS.dll' -Recurse | Select-Object -First 1
if (-not $dwmapi -or -not $ue4dll) { Write-Error 'Downloaded zip missing dwmapi.dll or UE4SS.dll' }

Copy-Item -LiteralPath $dwmapi.FullName -Destination (Join-Path $WinGDK 'dwmapi.dll') -Force
Copy-Item -LiteralPath $ue4dll.FullName -Destination (Join-Path $Ue4ssDir 'UE4SS.dll') -Force

& (Join-Path $PSScriptRoot 'install-ue4ss-config.ps1')

Write-Host 'Experimental UE4SS installed. Restart the game fully, then run: .\scripts\diagnose-ue4ss.ps1'
