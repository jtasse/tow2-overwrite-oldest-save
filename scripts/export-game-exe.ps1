# Export TOW2 shipping exe via VSS (Game Pass blocks normal copy even as admin).
# WARNING: Do NOT copy this exe back into a Game Pass install on another PC.
# Manual exe replacement triggers "Something went wrong launching your game"
# (package integrity check). Use Xbox Repair on the target PC instead.
# MUST run in elevated PowerShell: right-click Terminal -> Run as administrator.
param(
    [string]$OutDir = (Join-Path $env:USERPROFILE 'Desktop\tow2-exe-export')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\game-path.ps1')

$WinGDK = Get-Tow2WinGDKRoot
if (-not $WinGDK) { Write-Error 'TOW2 WinGDK folder not found.' }

$ExeName = 'TheOuterWorlds2-WinGDK-Shipping.exe'
$SrcExe = Join-Path $WinGDK $ExeName
$DstExe = Join-Path $OutDir $ExeName

# WinGDK is on C: for Game Pass; shadow copy is per-volume.
$Volume = 'C:\'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error @"
Not running as Administrator.
Right-click PowerShell or Terminal -> Run as administrator, then run this script again.
"@
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
if (Test-Path -LiteralPath $DstExe) { Remove-Item -LiteralPath $DstExe -Force }

Write-Host "Source: $SrcExe"
Write-Host "Dest:   $DstExe"
Write-Host 'Creating volume shadow copy (may take 10-30s)...'

$shadowClass = [WmiClass]'Win32_ShadowCopy'
$result = $shadowClass.Create($Volume, 'ClientAccessible')
if ($result.ReturnValue -ne 0) {
    Write-Error "Shadow copy create failed. ReturnValue=$($result.ReturnValue). Is VSS enabled?"
}

$shadow = Get-CimInstance Win32_ShadowCopy |
    Where-Object { $_.ID -eq $result.ShadowID } |
    Select-Object -First 1
if (-not $shadow) {
    Write-Error 'Could not find new shadow copy.'
}

$device = $shadow.DeviceObject.TrimEnd('\')
# Path under C:\ -> append after shadow device (no drive letter).
$relative = $SrcExe.Substring(3)  # drop "C:\"
$ShadowSrc = $device + '\' + $relative

Write-Host "Shadow source: $ShadowSrc"

if (-not (Test-Path -LiteralPath $ShadowSrc)) {
    Write-Error "Shadow path not found: $ShadowSrc"
}

# Plain copy from shadow usually works; robocopy /B as fallback.
try {
    Copy-Item -LiteralPath $ShadowSrc -Destination $DstExe -Force
} catch {
    Write-Host "Copy-Item failed ($($_.Exception.Message)); trying robocopy /B from shadow..."
    $shadowDir = Split-Path -Parent $ShadowSrc
    $null = robocopy $shadowDir $OutDir $ExeName /B /COPY:DAT /R:0 /W:0
    if (-not (Test-Path -LiteralPath $DstExe)) { throw }
}

$out = Get-Item -LiteralPath $DstExe
Write-Host "OK: $($out.FullName) ($($out.Length) bytes, modified $($out.LastWriteTime))"

$zip = Join-Path $OutDir 'tow2-shipping-exe.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -LiteralPath $DstExe -DestinationPath $zip -Force
Write-Host "ZIP for Google Drive: $zip"
Write-Host 'Upload the .zip (Drive blocks raw .exe files).'
