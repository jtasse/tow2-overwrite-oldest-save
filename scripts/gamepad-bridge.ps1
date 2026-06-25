# Background XInput reader for OverwriteOldestSave (UE4SS Lua has no ffi on WinGDK).
# Writes controller state for the mod to read — no in-game subprocess.
$ErrorActionPreference = 'Stop'

$OutFile = Join-Path $env:LOCALAPPDATA 'OverwriteOldestSave-gamepad.json'
$PollMs = 50

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class OowXInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct Gamepad {
        public ushort wButtons;
        public byte bLeftTrigger;
        public byte bRightTrigger;
        public short sThumbLX;
        public short sThumbLY;
        public short sThumbRX;
        public short sThumbRY;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct State {
        public uint dwPacketNumber;
        public Gamepad Gamepad;
    }
    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
    public static extern int GetState4(uint idx, out State state);
    [DllImport("xinput1_3.dll", EntryPoint = "XInputGetState")]
    public static extern int GetState3(uint idx, out State state);
    public static int GetState(uint idx, out State state) {
        int r = GetState4(idx, out state);
        if (r == 0) return r;
        return GetState3(idx, out state);
    }
}
"@

function Write-State($idx, $gp, $connected) {
    $payload = [ordered]@{
        connected = $connected
        userIndex = $idx
        buttons   = [int]$gp.wButtons
        lt        = [int]$gp.bLeftTrigger
        rt        = [int]$gp.bRightTrigger
        ts        = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    }
    $json = ($payload | ConvertTo-Json -Compress)
    [System.IO.File]::WriteAllText($OutFile, $json)
}

while ($true) {
    $found = $false
    for ($i = 0; $i -lt 4; $i++) {
        $st = New-Object OowXInput+State
        if ([OowXInput]::GetState([uint32]$i, [ref]$st) -eq 0) {
            Write-State $i $st.Gamepad $true
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-State 0 ([OowXInput+Gamepad]::new()) $false
    }
    Start-Sleep -Milliseconds $PollMs
}
