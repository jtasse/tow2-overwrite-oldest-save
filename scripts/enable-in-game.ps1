# Append OverwriteOldestSave to the game's ue4ss mods.txt / mods.json if missing.
$GameRoot = "C:\XboxGames\The Outer Worlds 2\Content\Arkansas\Binaries\WinGDK"
$ModsTxt = Join-Path $GameRoot "ue4ss\Mods\mods.txt"
$ModsJson = Join-Path $GameRoot "ue4ss\Mods\mods.json"

if (-not (Test-Path $ModsTxt)) {
    Write-Error "mods.txt not found at: $ModsTxt"
}

$content = Get-Content -LiteralPath $ModsTxt -Raw
if ($content -notmatch "OverwriteOldestSave\s*:\s*1") {
    $content = $content.TrimEnd() + "`r`nOverwriteOldestSave : 1`r`n"
    Set-Content -LiteralPath $ModsTxt -Value $content -NoNewline
    Write-Host "Added OverwriteOldestSave : 1 to mods.txt"
} else {
    Write-Host "mods.txt already enables OverwriteOldestSave"
}

if (Test-Path $ModsJson) {
    $json = Get-Content -LiteralPath $ModsJson -Raw | ConvertFrom-Json
    $found = $false
    foreach ($entry in $json) {
        if ($entry.mod_name -eq "OverwriteOldestSave") {
            $entry.mod_enabled = $true
            $found = $true
        }
    }
    if (-not $found) {
        $json += [PSCustomObject]@{ mod_name = "OverwriteOldestSave"; mod_enabled = $true }
    }
    $json | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $ModsJson
    Write-Host "Updated mods.json"
}

Write-Host "mods.txt location: $ModsTxt"
