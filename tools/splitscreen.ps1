# splitscreen.ps1 - local Zombies coop on one monitor: one game window per player, tiled, each on its own input.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\splitscreen.ps1 [-Players 3] [-Map zombie_theater]
#                                                                           [-Layout auto|rows|columns|grid] [-NoKeyboard]
#
# Player 1 hosts the game (+devmap) and plays with keyboard and mouse; players 2.. join it over loopback and each reads
# one controller (player 2 controller 1, player 3 controller 2, ...). With -NoKeyboard every player is on a controller,
# player 1 included. Each player runs from its own folder build\Splitscreen\p<N> (its own players\ profile, config and
# main\console_mp.log); the game files are linked from build\Release, nothing is copied but the exe and its DLLs.
#
# Engine dvars this uses (src/win32/win_gamepad.cpp, win_input.cpp, gfx_d3d/r_init.cpp):
#   gpad_port N         the XInput controller this window reads (-1 none)
#   gpad_background 1   keep reading it while another player's window has the focus
#   in_keyboard 0       ignore the keyboard (in_mouse 0 ignores the mouse)
#   r_borderlessSize    a borderless window of WxH at vid_xpos/vid_ypos: the player's tile
#   bo1_join ip:port    join that server once the front end is up (a +connect on the command line is dropped)
param(
    [ValidateRange(1, 4)][int]$Players = 2,
    [string]$Map = 'zombie_theater',
    [ValidateSet('auto', 'rows', 'columns', 'grid')][string]$Layout = 'auto',
    [switch]$NoKeyboard,
    [int]$HostPort = 28960,
    [int]$JoinTimeoutSec = 120
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$R = Join-Path $repo 'build\Release'
if (-not (Test-Path (Join-Path $R 'BO1Zombies.exe'))) { throw "not built: $(Join-Path $R 'BO1Zombies.exe') (build, then run setup.ps1)" }
if (-not (Test-Path (Join-Path $R 'zone'))) { throw "no game files in $R (run setup.ps1)" }

# the primary monitor in physical pixels (the game window is DPI aware in borderless mode)
if (-not ('BO1Split' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BO1Split {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
}
'@
}
[BO1Split]::SetProcessDPIAware() | Out-Null
$screenW = [BO1Split]::GetSystemMetrics(0)
$screenH = [BO1Split]::GetSystemMetrics(1)

# tiles: 1 player the whole screen, 2 rows (top / bottom, like the consoles) unless -Layout columns, 3-4 a 2x2 grid
if ($Layout -eq 'auto') { $Layout = if ($Players -le 2) { 'rows' } else { 'grid' } }
$tiles = @()
for ($i = 0; $i -lt $Players; $i++) {
    if ($Players -eq 1) { $tiles += , @(0, 0, $screenW, $screenH); continue }
    switch ($Layout) {
        'rows'    { $h = [math]::Floor($screenH / $Players); $tiles += , @(0, ($i * $h), $screenW, $h) }
        'columns' { $w = [math]::Floor($screenW / $Players); $tiles += , @(($i * $w), 0, $w, $screenH) }
        'grid'    { $w = [math]::Floor($screenW / 2); $h = [math]::Floor($screenH / 2); $tiles += , @((($i % 2) * $w), ([math]::Floor($i / 2) * $h), $w, $h) }
    }
}

function New-RunFolder([string]$dir) {
    foreach ($d in 'main', 'players') { New-Item -ItemType Directory -Force (Join-Path $dir $d) | Out-Null }
    foreach ($j in 'zone', 'mods', 'main\video') {
        $t = Join-Path $R $j; $l = Join-Path $dir $j
        if ((Test-Path $t) -and -not (Test-Path $l)) { New-Item -ItemType Junction -Path $l -Target $t | Out-Null }
    }
    Get-ChildItem $R -File | Where-Object { $_.Name -in 'BO1Zombies.exe', 'BO1Zombies.pdb' -or $_.Extension -in '.dll', '.txt', '.bmp' } | ForEach-Object {
        $c = Join-Path $dir $_.Name
        $old = Get-Item $c -ErrorAction SilentlyContinue
        if (-not $old -or $old.Length -ne $_.Length -or $old.LastWriteTimeUtc -ne $_.LastWriteTimeUtc) { Copy-Item $_.FullName $c -Force }
    }
}

$running = @(Get-Process -Name BO1Zombies -ErrorAction SilentlyContinue)
if ($running.Count) { throw "BO1Zombies is already running (pid $($running[0].Id)); close it first" }

$procs = @()
try {
    for ($p = 1; $p -le $Players; $p++) {
        $dir = Join-Path $repo "build\Splitscreen\p$p"
        New-RunFolder $dir
        $log = Join-Path $dir 'main\console_mp.log'
        Remove-Item $log -ErrorAction SilentlyContinue
        $tile = $tiles[$p - 1]
        $gameArgs = "+set fs_b `"$R`" +set fs_h `"$dir`" +set bo1_zombies 1 +set logfile 2 +set name Player$p"
        $gameArgs += " +set r_fullscreen 0 +set r_borderless 1 +set r_borderlessSize $($tile[2])x$($tile[3]) +set vid_xpos $($tile[0]) +set vid_ypos $($tile[1])"
        $gameArgs += " +set net_port $($HostPort + $p - 1)"
        if ($p -eq 1 -and -not $NoKeyboard) {
            $gameArgs += ' +set gpad_port -1 +set gpad_enabled 0 +set gpad_background 0 +set in_keyboard 1 +set in_mouse 1'
        } else {
            $pad = if ($NoKeyboard) { $p - 1 } else { $p - 2 }
            $gameArgs += " +set gpad_port $pad +set gpad_enabled 1 +set gpad_background 1 +set in_keyboard 0 +set in_mouse 0"
        }
        if ($p -eq 1) {
            # the host: a listen server on loopback for the other players
            $gameArgs += " +set sv_maxclients 4 +devmap $Map"
        } else {
            $gameArgs += " +set bo1_join 127.0.0.1:$HostPort"
        }
        "player $p : tile $($tile -join ',') : $gameArgs"
        $procs += Start-Process -FilePath (Join-Path $dir 'BO1Zombies.exe') -WorkingDirectory $dir -ArgumentList $gameArgs -PassThru
        if ($p -eq 1 -and $Players -gt 1) {
            # the others join once the host's server is starting (they keep resending the connect while its map loads;
            # the server answers no getinfo probe, sv_main_mp.cpp SV_ConnectionlessPacket)
            $deadline = (Get-Date).AddSeconds($JoinTimeoutSec)
            while (-not ((Test-Path $log) -and (Select-String -Path $log -Pattern '------ Server Initialization ------' -SimpleMatch -Quiet))) {
                if ($procs[0].HasExited) { throw "the host (player 1) exited with code $($procs[0].ExitCode); see $log" }
                if ((Get-Date) -gt $deadline) { throw "the host did not start a server within $JoinTimeoutSec s; see $log" }
                Start-Sleep -Milliseconds 500
            }
            Start-Sleep -Seconds 3
        }
    }
    # the last window started has the focus; give it to player 1's (the keyboard and mouse, unless -NoKeyboard).
    # Windows may refuse and flash the taskbar instead: then click player 1's tile.
    try {
        $deadline = (Get-Date).AddSeconds(10)
        while ($procs[0].MainWindowHandle -eq 0 -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250; $procs[0].Refresh() }
        if (-not (New-Object -ComObject WScript.Shell).AppActivate($procs[0].Id)) { "could not focus player 1's window: click it" }
    } catch { "could not focus player 1's window: click it" }
    "started $Players player(s)"
} catch {
    # a failed start leaves no half session behind (the next run would refuse: 'already running')
    $procs | Where-Object { -not $_.HasExited } | Stop-Process -Force -ErrorAction SilentlyContinue
    throw
}
