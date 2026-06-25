param(
    [Parameter(Mandatory = $true)]
    [string]$MessageFile
)

if (-not (Test-Path -LiteralPath $MessageFile)) {
    exit 1
}

$lines = Get-Content -LiteralPath $MessageFile -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $MessageFile -Force -ErrorAction SilentlyContinue

$title = 'Overwrite Oldest Save'
$message = 'Notification'
if ($lines -and $lines.Count -ge 1) { $title = [string]$lines[0] }
if ($lines -and $lines.Count -ge 2) { $message = ($lines[1..($lines.Count - 1)] -join "`n") }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.Visible = $true
$n.ShowBalloonTip(15000, $title, $message, [System.Windows.Forms.ToolTipIcon]::Info)
Start-Sleep -Seconds 5
$n.Dispose()
