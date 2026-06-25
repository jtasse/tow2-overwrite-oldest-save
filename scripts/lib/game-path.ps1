# Shared Game Pass WinGDK path resolver for repo scripts.
# WindowsApps\...\WinGDK is often a junction to XboxGames; prefer the real target when writable.

function Resolve-Tow2Path([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $Path
    }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Target -and $item.Target.Count -gt 0) {
        $target = $item.Target[0]
        if (Test-Path -LiteralPath $target) {
            return $target
        }
    }
    return $item.FullName
}

function Get-Tow2WinGDKRoot {
    $candidates = @()

    $xboxMirror = 'C:\XboxGames\The Outer Worlds 2\Content\Arkansas\Binaries\WinGDK'
    if (Test-Path -LiteralPath $xboxMirror) {
        $candidates += Resolve-Tow2Path $xboxMirror
    }

    $windowsApps = 'C:\Program Files\WindowsApps'
    if (Test-Path -LiteralPath $windowsApps) {
        Get-ChildItem -LiteralPath $windowsApps -Filter 'Microsoft.OE-Arkansas_*' -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                $candidates += Resolve-Tow2Path (Join-Path $_.FullName 'Arkansas\Binaries\WinGDK')
            }
    }

    $seen = @{}
    foreach ($root in $candidates) {
        if (-not $root -or $seen[$root]) { continue }
        $seen[$root] = $true
        $exe = Join-Path $root 'TheOuterWorlds2-WinGDK-Shipping.exe'
        $ue4ss = Join-Path $root 'ue4ss'
        if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $ue4ss)) {
            return $root
        }
    }

    foreach ($root in $candidates) {
        if ($root -and -not $seen[$root]) { return $root }
    }

    return $null
}
