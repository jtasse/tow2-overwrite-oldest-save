# Install OW2-specific UE4SS-settings.ini (+ VTableLayout.ini) from UE4SS upstream.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) {
    Write-Error 'TOW2 WinGDK folder not found.'
}

$Ue4ss = Join-Path $WinGDK 'ue4ss'
# Use experimental zCustomGameConfigs (6852-byte OW2 settings) — matches working Game Pass installs.
$ZipUrl = 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental-latest/zCustomGameConfigs.zip'
$TempZip = Join-Path $env:TEMP 'zCustomGameConfigs.zip'
$TempExtract = Join-Path $env:TEMP 'zCustomGameConfigs-extract'
$Ow2Src = Join-Path $TempExtract 'The Outer Worlds 2'

Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
Expand-Archive -LiteralPath $TempZip -DestinationPath $TempExtract -Force

foreach ($name in @('UE4SS-settings.ini', 'VTableLayout.ini')) {
    $src = Join-Path $Ow2Src $name
    $dest = Join-Path $Ue4ss $name
    if (-not (Test-Path -LiteralPath $src)) { Write-Error "Missing in zip: $name" }
    if (Test-Path -LiteralPath $dest) {
        Copy-Item -LiteralPath $dest -Destination "$dest.bak" -Force
        Write-Host "Backed up $name -> $name.bak"
    }
    Copy-Item -LiteralPath $src -Destination $dest -Force
    Write-Host "Installed $dest ($((Get-Item $dest).Length) bytes)"
}

# Working PCs do not use override.txt.
$override = Join-Path $WinGDK 'override.txt'
if (Test-Path -LiteralPath $override) {
    Remove-Item -LiteralPath $override -Force
    Write-Host 'Removed override.txt'
}

$setting = Select-String -LiteralPath (Join-Path $Ue4ss 'UE4SS-settings.ini') -Pattern 'bUseUObjectArrayCache'
Write-Host $setting.Line
Write-Host 'Restart the game after installing UE4SS config.'
