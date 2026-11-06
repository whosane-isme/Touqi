# Explains each frame-time spike of a benchmark run from the emulator log around it.
#   .\Analyze-OotDrops.ps1                 latest run
#   .\Analyze-OotDrops.ps1 -Run <dir>      a given run directory
param(
    [string]$Run = '',
    [string]$OutDir = 'D:\ns2\oot-lab\bench\runs',
    [double]$HitchMs = 50,
    [double]$PadS = 0.4
)
$ErrorActionPreference = 'Stop'
if (-not $Run) { $Run = (Get-ChildItem -LiteralPath $OutDir -Directory | Sort-Object Name | Select-Object -Last 1).FullName }
$summary = Get-Content -LiteralPath (Join-Path $Run 'summary.json') -Raw | ConvertFrom-Json
$rows = Import-Csv -LiteralPath (Join-Path $Run 'chunks.csv')
$offset = if ($summary.log_offset_s) { [double]$summary.log_offset_s } else { 0 }

# Parse the log once: time and text.
$events = foreach ($line in [IO.File]::ReadLines((Join-Path $Run 'emulator.log'))) {
    if ($line -match '^\[\s*([0-9.]+)\]\s+(.*)$') { [pscustomobject]@{ T = [double]$Matches[1]; Text = $Matches[2] } }
}
$events = @($events)

$ms = @($rows | ForEach-Object { [double]$_.ChunkMs } | Sort-Object)
$median = $ms[[int]($ms.Count / 2)]
$spikes = @($rows | Where-Object { [double]$_.ChunkMs -gt [Math]::Max($median + $HitchMs, $median * 1.6) })

$noise = 'texture_cache.h|PresentClientBuffer|WaitForFrame|ResolveCallerProgramId|TickFrame'
$tally = @{}
$report = foreach ($s in $spikes) {
    $t0 = [double]$s.Uptime + $offset - $PadS
    $t1 = [double]$s.Uptime + $offset + [double]$s.ChunkMs / 1000 + $PadS
    $win = @($events | Where-Object { $_.T -ge $t0 -and $_.T -le $t1 })

    $gfx = @($win | Where-Object { $_.Text -match 'Graphics pipeline built on the GPU thread in ([0-9.]+) ms' } |
        ForEach-Object { [double]([regex]::Match($_.Text, 'in ([0-9.]+) ms').Groups[1].Value) })
    $cmp = @($win | Where-Object { $_.Text -match 'Compute pipeline built on the GPU thread in ([0-9.]+) ms' } |
        ForEach-Object { [double]([regex]::Match($_.Text, 'in ([0-9.]+) ms').Groups[1].Value) })
    $slowWorker = @($win | Where-Object { $_.Text -match 'worker emission and driver build ([0-9.]+) ms' } |
        ForEach-Object { [double]([regex]::Match($_.Text, 'build ([0-9.]+) ms').Groups[1].Value) } | Where-Object { $_ -ge 30 })
    $reads = @($win | Where-Object { $_.Text -match '\((\d+) so far\)' -and $_.Text -match 'OnCPURead' } |
        ForEach-Object { [long]([regex]::Match($_.Text, '\((\d+) so far\)').Groups[1].Value) })
    $readCount = if ($reads.Count -ge 2) { ($reads | Measure-Object -Maximum).Maximum - ($reads | Measure-Object -Minimum).Minimum + 64 } elseif ($reads.Count) { 64 } else { 0 }
    $astc = @($win | Where-Object { $_.Text -match 'ASTC GPU decodes' })
    $other = @($win | Where-Object { $_.Text -match '<(Warning|Error|Critical)>' -and $_.Text -notmatch $noise } |
        ForEach-Object { ($_.Text -replace '^\S+ <\w+> \S+:\d+:', '').Substring(0, [Math]::Min(90, ($_.Text -replace '^\S+ <\w+> \S+:\d+:', '').Length)) } |
        Select-Object -Unique -First 2)

    $pipeMs = ($gfx + $cmp | Measure-Object -Sum).Sum
    $excess = [double]$s.ChunkMs - $median
    $causes = @()
    if ($pipeMs -ge 0.25 * $excess -or $slowWorker.Count) { $causes += 'pipeline-build' }
    if ($readCount -ge 0.2 * ($t1 - $t0) * 200) { $causes += 'cpu-reads-gpu-memory' }
    if ($astc.Count) { $causes += 'astc-decode' }
    if (-not $causes.Count) { $causes += 'unexplained-by-log' }
    foreach ($c in $causes) { $tally[$c] = 1 + [int]$tally[$c] }

    '{0,-6} {1,6:N0} ms | pipelines {2} gfx + {3} compute = {4:N0} ms GPU-thread{5} | cpu-reads ~{6} | {7}{8}' -f `
        $s.Segment, [double]$s.ChunkMs, $gfx.Count, $cmp.Count, $pipeMs,
        $(if ($slowWorker.Count) { ', slow worker ' + (($slowWorker | ForEach-Object { '{0:N0}' -f $_ }) -join '/') + ' ms' } else { '' }),
        $readCount, ($causes -join '+'), $(if ($other.Count) { ' | ' + ($other -join ' ; ') } else { '' })
}

'{0}: {1} spikes over median {2} ms per {3}-frame chunk, avg {4} fps' -f (Split-Path $Run -Leaf), $spikes.Count, $median, $rows[0].Frames, $summary.avg_fps
$report
'causes: ' + (($tally.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')
$report | Set-Content -LiteralPath (Join-Path $Run 'drops.txt') -Encoding utf8
