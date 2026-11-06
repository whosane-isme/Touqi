# Repeatable Ocarina of Time walk benchmark through the emulator's local debug server.
#
#   -Launch    close any running emulator, start Lichii 88 with the debug server, press A until
#              the save has loaded into gameplay, then run the route.
#   (no flag)  run the route from wherever Link is standing now.
#
# The route is the owner's recorded input split into 10-frame chunks; each chunk's wall time gives
# the frame time at ~0.17 s resolution, so a single long frame shows up as a slow chunk.
#
#   -Env 'A=1;B=0'                         environment variables for the emulator (with -Launch)
#   -Set 'use_reactive_flushing=true'      per-game ini values for this run (with -Launch); the
#                                          original ini is restored afterwards
param(
    [string]$Label = 'bench',
    [switch]$Launch,
    [string]$Env = '',
    [string]$Set = '',
    [string]$Emulator = 'D:\ns2\lichii-build88\lichii.exe',
    [string]$Game = 'D:\ns2\game\The Legend of Zelda Ocarina of Time Switch 2 NUP Base Game\The Legend of Zelda Ocarina of Time [0400486024DEC000][v131072].nup',
    [string]$GameIni = 'D:\ns2\lichii-build88\user\config\custom\0400486024DEC000.ini',
    [string]$EmulatorLog = 'D:\ns2\lichii-build88\user\log\eden_log.txt',
    [string]$OutDir = 'D:\ns2\oot-lab\bench\runs',
    [string]$Route = (Join-Path $PSScriptRoot 'routes\kokiri-walk-raw.txt'),
    [int]$FromFrame = 1000,
    [int]$ChunkFrames = 10,
    [double]$HitchMs = 50
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OotBench.psm1') -Force

$runDir = Join-Path $OutDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $Label)
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
@{ label = $Label; env = $Env; set = $Set; route = $Route; from_frame = $FromFrame } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir 'config.json') -Encoding utf8

function Set-GameIni([string]$Pairs) {
    # key=value pairs for the [Renderer]/[Cpu]/... keys already present as "key\use_global=...".
    $text = [IO.File]::ReadAllText($GameIni)
    foreach ($pair in ($Pairs -split ';' | Where-Object { $_ })) {
        $k, $v = $pair -split '=', 2
        $text = [regex]::Replace($text, "(?m)^$([regex]::Escape($k))(\\default)?=.*\r?\n", '')
        $text = [regex]::Replace($text, "(?m)^$([regex]::Escape($k))\\use_global=\w+",
            "$k\use_global=false`n$k\default=false`n$k=$v")
    }
    [IO.File]::WriteAllText($GameIni, $text, [Text.UTF8Encoding]::new($false))
}

function Wait-Gameplay {
    # Title -> file select -> loading -> gameplay. Once the title runs (600 presents), press A
    # every second until the save starts loading (fps < 30), then wait for 3 s at 25+ FPS (the spawn view runs ~37).
    $sawLoad = $false; $steady = 0
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        $st = Invoke-Oot status @{ fps_window_ms = 1000 }
        $pressing = $st.presents -gt 600
        if ($pressing -and $st.fps -lt 30) { $sawLoad = $true }
        if ($sawLoad -and $st.fps -ge 25) { $steady++ } else { $steady = 0 }
        if ($steady -ge 3) { return $st }
        if ($pressing -and -not $sawLoad) { Send-OotInput -Buttons @('A') -Frames 4 | Out-Null }
        Start-Sleep -Milliseconds 1000
    }
    throw 'Did not reach gameplay within 180 s'
}

$iniBackup = $null
if ($Launch) {
    Get-Process lichii, selevet, eglantine -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 3
    if ($Set) {
        $iniBackup = [IO.File]::ReadAllText($GameIni)
        Set-GameIni $Set
    }
    $psi = [Diagnostics.ProcessStartInfo]::new($Emulator, ('"{0}"' -f $Game))
    $psi.WorkingDirectory = Split-Path $Emulator
    $psi.UseShellExecute = $false
    $psi.EnvironmentVariables['EDEN_NX2_DEBUG_SERVER'] = '127.0.0.1:6545'
    foreach ($pair in ($Env -split ';' | Where-Object { $_ })) {
        $k, $v = $pair -split '=', 2
        $psi.EnvironmentVariables[$k] = $v
    }
    [Diagnostics.Process]::Start($psi) | Out-Null
    try {
        Connect-Oot -TimeoutSeconds 120
        Wait-Gameplay | Out-Null
    } finally {
        # The emulator read its config at boot; put the owner's ini back right away.
        if ($null -ne $iniBackup) { [IO.File]::WriteAllText($GameIni, $iniBackup, [Text.UTF8Encoding]::new($false)) }
    }
    Start-Sleep 3
} else {
    Connect-Oot -TimeoutSeconds 10
}

Save-OotScreenshot -Destination (Join-Path $runDir 'start.png') | Out-Null

# Route: the owner's TAS recording (one line per presented frame: frame buttons lx;ly rx;ry),
# replayed from -FromFrame in chunks of -ChunkFrames through input_sequence.
$map = @{ KEY_A='A'; KEY_B='B'; KEY_X='X'; KEY_Y='Y'; KEY_L='L'; KEY_R='R'; KEY_ZL='ZL'; KEY_ZR='ZR'
          KEY_PLUS='Plus'; KEY_MINUS='Minus'; KEY_DUP='Up'; KEY_DDOWN='Down'; KEY_DLEFT='Left'
          KEY_DRIGHT='Right'; KEY_LSTICK='StickL'; KEY_RSTICK='StickR' }
$frameInputs = foreach ($line in Get-Content -LiteralPath $Route) {
    $f = $line.Trim() -split '\s+'
    if ($f.Count -lt 4 -or [int]$f[0] -lt $FromFrame) { continue }
    $btn = @(($f[1] -split ';') | Where-Object { $map.ContainsKey($_) } | ForEach-Object { $map[$_] })
    $l = $f[2] -split ';'; $r = $f[3] -split ';'
    [pscustomobject]@{
        Buttons = $btn
        Left  = @([Math]::Round([int]$l[0] / 32767, 2), [Math]::Round([int]$l[1] / 32767, 2))
        Right = @([Math]::Round([int]$r[0] / 32767, 2), [Math]::Round([int]$r[1] / 32767, 2))
    }
}
$frameInputs = @($frameInputs)
if (-not $frameInputs.Count) { throw "No route frames in $Route from frame $FromFrame" }

$startStatus = Invoke-Oot status @{ fps_window_ms = 1000 }
# Log timestamps run on a different clock than status uptime; note both now so spikes can be
# matched against log lines.
$logOffset = 0
try {
    $tail = Get-Content -LiteralPath $EmulatorLog -Tail 50 | Where-Object { $_ -match '^\[\s*([0-9.]+)\]' } | Select-Object -Last 1
    if ($tail -match '^\[\s*([0-9.]+)\]') { $logOffset = [double]$Matches[1] - [double]$startStatus.uptime_s }
} catch {}
$clock = [Diagnostics.Stopwatch]::StartNew()
$rows = [Collections.Generic.List[object]]::new()
for ($i = 0; $i -lt $frameInputs.Count; $i += $ChunkFrames) {
    $chunk = $frameInputs[$i..([Math]::Min($i + $ChunkFrames, $frameInputs.Count) - 1)]
    $steps = [Collections.Generic.List[object]]::new(); $prevKey = $null
    foreach ($fi in $chunk) {
        $key = ($fi.Buttons -join ',') + '|' + ($fi.Left -join ',') + '|' + ($fi.Right -join ',')
        if ($key -eq $prevKey) { $steps[$steps.Count - 1].frames++; continue }
        $step = @{ frames = 1; left_stick = $fi.Left; right_stick = $fi.Right }
        if ($fi.Buttons.Count) { $step.buttons = $fi.Buttons }
        $steps.Add($step); $prevKey = $key
    }
    $t = $clock.Elapsed.TotalSeconds
    $res = Invoke-Oot input_sequence @{ steps = $steps.ToArray(); timeout_s = 30 }
    $n = $chunk.Count; $ms = [double]$res.elapsed_s * 1000
    $rows.Add([pscustomobject]@{
        Segment = 'f' + ($FromFrame + $i); Uptime = [Math]::Round($startStatus.uptime_s + $t, 2)
        Frames = $n; ChunkMs = [Math]::Round($ms, 1); MsPerFrame = [Math]::Round($ms / $n, 2)
    })
}
$total = $clock.Elapsed.TotalSeconds
Save-OotScreenshot -Destination (Join-Path $runDir 'end.png') | Out-Null
Disconnect-Oot

$rows | Export-Csv -LiteralPath (Join-Path $runDir 'chunks.csv') -NoTypeInformation
Copy-Item -LiteralPath $EmulatorLog -Destination (Join-Path $runDir 'emulator.log')

$frames = ($rows | Measure-Object Frames -Sum).Sum
$sorted = @($rows | Sort-Object MsPerFrame -Descending)
$worst1pct = $sorted[0..([Math]::Max(0, [int]($sorted.Count * 0.01) - 1))]
# A hitch (spike): a chunk at least $HitchMs slower than the run's median chunk and 1.6x it,
# i.e. a sudden drop rather than the scene's steady frame rate.
$median = ($rows | Sort-Object ChunkMs)[[int]($rows.Count / 2)].ChunkMs
$hitches = @($rows | Where-Object { $_.ChunkMs -gt [Math]::Max($median + $HitchMs, $median * 1.6) })
$summary = [ordered]@{
    label = $Label; env = $Env; set = $Set; when = (Get-Date -Format s)
    uptime_start = $startStatus.uptime_s; log_offset_s = [Math]::Round($logOffset, 2)
    frames = $frames; seconds = [Math]::Round($total, 2)
    avg_fps = [Math]::Round($frames / $total, 1)
    low1pct_fps = [Math]::Round(1000 / (($worst1pct | Measure-Object MsPerFrame -Average).Average), 1)
    median_chunk_ms = $median
    worst_chunk_ms = ($sorted[0]).ChunkMs
    hitch_chunks = $hitches.Count
    hitches = @($hitches | Sort-Object ChunkMs -Descending | Select-Object -First 12 |
        ForEach-Object { '{0} @ uptime {1}s: {2} ms for {3} frames' -f $_.Segment, $_.Uptime, $_.ChunkMs, $_.Frames })
    # FPS per 100 route frames, in route order.
    per_100_frames = (@(for ($b = 0; $b -lt $rows.Count; $b += [Math]::Max(1, [int](100 / $ChunkFrames))) {
        $g = $rows[$b..([Math]::Min($b + [int](100 / $ChunkFrames), $rows.Count) - 1)]
        $f = ($g | Measure-Object Frames -Sum).Sum; $ms = ($g | Measure-Object ChunkMs -Sum).Sum
        '{0:N0}' -f ($f / ($ms / 1000)) }) -join ' ')
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runDir 'summary.json') -Encoding utf8
$summary | ConvertTo-Json -Depth 4 -Compress
Write-Output ('Saved: ' + $runDir)
