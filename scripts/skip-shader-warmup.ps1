# TOW2 shader warmup + fast boot (Game Pass WinGDK + Steam Windows).
#
#   .\scripts\skip-shader-warmup.ps1 -Action status
#   .\scripts\skip-shader-warmup.ps1 -Action build-cache   # run game once, full compile
#   .\scripts\skip-shader-warmup.ps1 -Action enable        # skip splash after cache exists
#   .\scripts\skip-shader-warmup.ps1 -Action fast-boot     # skip splash + intro logos
#   .\scripts\skip-shader-warmup.ps1 -Action disable
#   .\scripts\skip-shader-warmup.ps1 -Action unlock
#
# Skip-only hides the "Generating shaders" screen. If .upipelinecache stays tiny (~6 KB),
# shaders are still compiling every launch — run build-cache once first.

param(
    [ValidateSet('enable', 'disable', 'build-cache', 'fast-boot', 'status', 'unlock', 'bake')]
    [string]$Action = 'status',
    [switch]$LockIni
)

$ErrorActionPreference = 'Stop'

$ScriptMarker = '; TOW2 shader settings (overwrite-oldest-save script)'
$MinHealthyCacheBytes = 100 * 1024

$SkipSettings = [ordered]@{
    'r.PSOWarmup.WarmupMaterials' = '0'
    'r.PSOWarmup.WarmupTime' = '0'
    'r.ShaderPipelineCache.Enabled' = '1'
    'UI.ForceSkipShaderCompilation' = '1'
}

$BuildCacheSettings = [ordered]@{
    'r.PSOWarmup.WarmupMaterials' = '1'
    'r.PSOWarmup.WarmupTime' = '0'
    'r.ShaderPipelineCache.Enabled' = '1'
    'r.ShaderPipelineCache.SaveBoundPSOLog' = '1'
    'UI.ForceSkipShaderCompilation' = '0'
}

$DisableSettings = [ordered]@{
    'r.PSOWarmup.WarmupMaterials' = '1'
}

$ManagedEngineKeys = @(
    'r.PSOWarmup.WarmupMaterials'
    'r.PSOWarmup.WarmupTime'
    'r.ShaderPipelineCache.Enabled'
    'r.ShaderPipelineCache.SaveBoundPSOLog'
    'UI.ForceSkipShaderCompilation'
)

$GameIntroLines = @(
    $ScriptMarker
    '[/Script/MoviePlayer.MoviePlayerSettings]'
    'bWaitForMoviesToComplete=False'
    'bMoviesAreSkippable=True'
    'StartupMovies='
    ''
)

function Get-ConfigDirs {
    $base = Join-Path $env:LOCALAPPDATA 'Arkansas\Saved\Config'
    $names = @('WinGDK', 'Windows', 'WindowsNoEditor')
    $dirs = @()
    foreach ($name in $names) {
        $dir = Join-Path $base $name
        if (Test-Path -LiteralPath $dir) {
            $dirs += $dir
        }
    }
    if ($dirs.Count -eq 0) {
        $dir = Join-Path $base 'WinGDK'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $dirs += $dir
    }
    return $dirs | Select-Object -Unique
}

function Write-IniNoBom([string]$Path, [string[]]$Lines) {
    $text = ($Lines -join "`r`n").TrimEnd() + "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $text, $utf8NoBom)
}

function Set-ReadOnlyFlag([string]$Path, [bool]$ReadOnly) {
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path
        $item.IsReadOnly = $ReadOnly
    }
}

function Get-WarmupValue([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*r\.PSOWarmup\.WarmupMaterials\s*=\s*(\d+)\s*$') {
            return [int]$Matches[1]
        }
    }
    return $null
}

function Get-PipelineCacheInfo {
    $saved = Join-Path $env:LOCALAPPDATA 'Arkansas\Saved'
    $mainFiles = Get-ChildItem -LiteralPath $saved -Filter '*.upipelinecache' -ErrorAction SilentlyContinue
    $mainBytes = 0
    $parts = @()
    if ($mainFiles) {
        $mainBytes = ($mainFiles | Measure-Object -Property Length -Sum).Sum
        foreach ($f in $mainFiles) {
            $parts += '{0} ({1:N0} bytes, {2})' -f $f.Name, $f.Length, $f.LastWriteTime
        }
    } else {
        $parts += 'No .upipelinecache in Arkansas\Saved'
    }

    $collectedDir = Join-Path $saved 'CollectedPSOs'
    $collectedBytes = 0
    if (Test-Path -LiteralPath $collectedDir) {
        $rec = Get-ChildItem -LiteralPath $collectedDir -Filter '*.rec.upipelinecache' -ErrorAction SilentlyContinue
        if ($rec) {
            $collectedBytes = ($rec | Measure-Object -Property Length -Sum).Sum
            $parts += ('CollectedPSOs: {0:N0} bytes ({1} file(s))' -f $collectedBytes, $rec.Count)
        }
    }

    return @{
        Text = ($parts -join '; ')
        MainBytes = [int64]$mainBytes
        CollectedBytes = [int64]$collectedBytes
        Bytes = [int64]($mainBytes + $collectedBytes)
    }
}

function Test-CacheHealthy([hashtable]$CacheInfo) {
    if ($CacheInfo.MainBytes -ge $MinHealthyCacheBytes) {
        return $true
    }
    # Main cache often stays tiny on WinGDK; large CollectedPSOs means partial bake only.
    return $false
}

function Test-CachePartial([hashtable]$CacheInfo) {
    return $CacheInfo.CollectedBytes -ge (256 * 1024)
}

function Merge-EngineIni([string]$Path, [hashtable]$Settings, [switch]$ReplaceFile) {
    $lines = @()
    if ((Test-Path -LiteralPath $Path) -and -not $ReplaceFile) {
        $lines = @(Get-Content -LiteralPath $Path)
    }

    $output = New-Object System.Collections.Generic.List[string]
    $inSystemSettings = $false
    $seenKeys = @{}
    $insertedMarker = $false

    foreach ($line in $lines) {
        if ($line -eq $ScriptMarker) {
            $insertedMarker = $true
            continue
        }
        if ($line -match '^\s*\[SystemSettings\]\s*$') {
            $inSystemSettings = $true
            continue
        }
        if ($line -match '^\s*\[.+]\s*$') {
            $inSystemSettings = $false
        }
        $matchedKey = $false
        foreach ($key in $ManagedEngineKeys) {
            if ($line -match ('^\s*' + [regex]::Escape($key) + '\s*=')) {
                $matchedKey = $true
                break
            }
        }
        if (-not $matchedKey) {
            $output.Add($line)
        }
    }

    if (-not $insertedMarker) {
        if ($output.Count -gt 0 -and $output[$output.Count - 1] -ne '') {
            $output.Add('')
        }
        $output.Add($ScriptMarker)
    } else {
        if ($output.Count -gt 0 -and $output[$output.Count - 1] -ne '') {
            $output.Add('')
        }
        $output.Add($ScriptMarker)
    }

    $output.Add('[SystemSettings]')
    foreach ($entry in $Settings.GetEnumerator()) {
        $output.Add(('{0}={1}' -f $entry.Key, $entry.Value))
        $seenKeys[$entry.Key] = $true
    }
    if ($output[$output.Count - 1] -ne '') {
        $output.Add('')
    }

    Write-IniNoBom -Path $Path -Lines $output.ToArray()
}

function Merge-GameIniIntroSkip([string]$Path) {
    $lines = @()
    if (Test-Path -LiteralPath $Path) {
        $lines = @(Get-Content -LiteralPath $Path)
    }

    $output = New-Object System.Collections.Generic.List[string]
    $skipRest = $false
    foreach ($line in $lines) {
        if ($line -eq $ScriptMarker) {
            $skipRest = $true
            continue
        }
        if ($skipRest) {
            if ($line -match '^\s*\[.+]\s*$') {
                $skipRest = $false
            } else {
                continue
            }
        }
        if ($line -match '^\s*bWaitForMoviesToComplete\s*=') { continue }
        if ($line -match '^\s*bMoviesAreSkippable\s*=') { continue }
        if ($line -match '^\s*StartupMovies\s*=') { continue }
        if ($line -match '^\s*\[/Script/MoviePlayer\.MoviePlayerSettings\]\s*$') { continue }
        $output.Add($line)
    }

    foreach ($line in $GameIntroLines) {
        $output.Add($line)
    }

    Write-IniNoBom -Path $Path -Lines $output.ToArray()
}

function Write-CacheHealth([hashtable]$CacheInfo) {
    Write-Host "PSO cache: $($CacheInfo.Text)"
    if (Test-CacheHealthy $CacheInfo) {
        Write-Host "Cache health: OK (main cache >= $([int]($MinHealthyCacheBytes / 1024)) KB)"
        return $true
    }
    if (Test-CachePartial $CacheInfo) {
        Write-Host "Cache health: PARTIAL (main cache tiny, CollectedPSOs has data - short warmup each launch is expected)"
        Write-Host "  Run -Action bake once: full warmup + 10 min in-game, quit normally, then fast-boot."
        return $false
    }
    Write-Host "Cache health: BAD (no usable cache - run -Action bake)"
    return $false
}

$configDirs = Get-ConfigDirs
$cacheInfo = Get-PipelineCacheInfo

switch ($Action) {
    'status' {
        Write-Host "Arkansas Saved: $(Join-Path $env:LOCALAPPDATA 'Arkansas\Saved')"
        $healthy = Write-CacheHealth $cacheInfo
        foreach ($dir in $configDirs) {
            $engineIni = Join-Path $dir 'Engine.ini'
            $gameIni = Join-Path $dir 'Game.ini'
            Write-Host ""
            Write-Host "Config: $dir"
            if (-not (Test-Path -LiteralPath $engineIni)) {
                Write-Host '  Engine.ini: missing'
            } else {
                $ro = (Get-Item -LiteralPath $engineIni).IsReadOnly
                $val = Get-WarmupValue $engineIni
                Write-Host "  Engine.ini: present (read-only=$ro)"
                if ($null -eq $val) {
                    Write-Host '  WarmupMaterials: not set (game default - splash shown)'
                } elseif ($val -eq 0) {
                    Write-Host '  WarmupMaterials: 0 (splash skipped)'
                } else {
                    Write-Host "  WarmupMaterials: $val (full warmup allowed)"
                }
            }
            if (Test-Path -LiteralPath $gameIni) {
                $intro = Select-String -LiteralPath $gameIni -Pattern 'StartupMovies=' -SimpleMatch -Quiet
                Write-Host ("  Game.ini: present (intro skip={0})" -f $intro)
            } else {
                Write-Host '  Game.ini: missing (logo intros still play)'
            }
        }
        Write-Host ""
        if (-not $healthy) {
            Write-Host ""
            Write-Host "Why short 'Generating shaders' every launch?"
            Write-Host "  fast-boot hides the LONG compile, but your main cache is still ~6 KB."
            Write-Host "  TOW2 also writes CollectedPSOs/*.rec (you have ~$([int]($cacheInfo.CollectedBytes/1024)) KB there)."
            Write-Host ""
            Write-Host "Fix:  .\scripts\skip-shader-warmup.ps1 -Action bake"
            Write-Host "  Then one full play session (see bake instructions)."
        }
    }
    'bake' {
        foreach ($dir in $configDirs) {
            $engineIni = Join-Path $dir 'Engine.ini'
            $gameIni = Join-Path $dir 'Game.ini'
            Set-ReadOnlyFlag -Path $engineIni -ReadOnly $false
            Set-ReadOnlyFlag -Path $gameIni -ReadOnly $false
            Merge-EngineIni -Path $engineIni -Settings $BuildCacheSettings
            Write-Host "Bake mode (writable ini, full warmup ON): $engineIni"
        }
        Write-CacheHealth $cacheInfo | Out-Null
        Write-Host ""
        Write-Host "=== Bake the shader cache (one time) ==="
        Write-Host "  1. Do NOT change graphics settings during this session."
        Write-Host "  2. Launch TOW2 - wait through the FULL 'Generating shaders' (minutes, not seconds)."
        Write-Host "  3. Load a save and play at least 10 minutes (move between areas)."
        Write-Host "  4. Quit to desktop normally (Alt+F4 after pause menu is OK; do not kill from Task Manager)."
        Write-Host "  5. Run:  .\scripts\skip-shader-warmup.ps1 -Action status"
        Write-Host "     Goal: main .upipelinecache well over $([int]($MinHealthyCacheBytes / 1024)) KB."
        Write-Host "  6. Run:  .\scripts\skip-shader-warmup.ps1 -Action fast-boot"
        Write-Host ""
        Write-Host "If main cache stays ~6 KB but CollectedPSOs grows: WinGDK may not merge fully."
        Write-Host "  fast-boot still removes logos + long splash; short warmup may remain."
    }
    'unlock' {
        foreach ($dir in $configDirs) {
            foreach ($name in @('Engine.ini', 'Game.ini')) {
                $path = Join-Path $dir $name
                Set-ReadOnlyFlag -Path $path -ReadOnly $false
                if (Test-Path -LiteralPath $path) {
                    Write-Host "Unlocked: $path"
                }
            }
        }
    }
    'build-cache' {
        & $PSCommandPath -Action bake
    }
    'enable' {
        if (-not (Test-CacheHealthy $cacheInfo)) {
            Write-Host "WARNING: Main PSO cache still tiny - short warmup may continue each launch."
            Write-Host "         Run -Action bake first if you have not.`n"
        }
        foreach ($dir in $configDirs) {
            $engineIni = Join-Path $dir 'Engine.ini'
            Set-ReadOnlyFlag -Path $engineIni -ReadOnly $false
            Merge-EngineIni -Path $engineIni -Settings $SkipSettings
            if ($LockIni) {
                Set-ReadOnlyFlag -Path $engineIni -ReadOnly $true
                Write-Host "Wrote skip settings (read-only): $engineIni"
            } else {
                Write-Host "Wrote skip settings (writable - game can update cache): $engineIni"
            }
        }
        Write-CacheHealth $cacheInfo | Out-Null
    }
    'fast-boot' {
        if (-not (Test-CacheHealthy $cacheInfo)) {
            Write-Host "WARNING: Main cache still tiny. Short warmup each launch is expected until bake completes.`n"
        }
        foreach ($dir in $configDirs) {
            $engineIni = Join-Path $dir 'Engine.ini'
            $gameIni = Join-Path $dir 'Game.ini'
            Set-ReadOnlyFlag -Path $engineIni -ReadOnly $false
            Set-ReadOnlyFlag -Path $gameIni -ReadOnly $false
            Merge-EngineIni -Path $engineIni -Settings $SkipSettings
            Merge-GameIniIntroSkip -Path $gameIni
            if ($LockIni) {
                Set-ReadOnlyFlag -Path $engineIni -ReadOnly $true
                Set-ReadOnlyFlag -Path $gameIni -ReadOnly $true
                Write-Host "Fast boot (read-only ini): $dir"
            } else {
                Write-Host "Fast boot (writable ini - recommended): $dir"
            }
        }
        Write-CacheHealth $cacheInfo | Out-Null
    }
    'disable' {
        foreach ($dir in $configDirs) {
            $engineIni = Join-Path $dir 'Engine.ini'
            Set-ReadOnlyFlag -Path $engineIni -ReadOnly $false
            Merge-EngineIni -Path $engineIni -Settings $DisableSettings
            Write-Host "Warmup enabled (writable): $engineIni"
        }
        Write-Host "Launch once for a full shader compile, then: .\scripts\skip-shader-warmup.ps1 -Action enable"
    }
}
