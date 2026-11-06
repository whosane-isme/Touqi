# One line per benchmark run, newest last: label, options, avg FPS, ~1% low, spikes, worst chunk.
param([string]$OutDir = 'D:\ns2\oot-lab\bench\runs', [int]$Last = 30)
Get-ChildItem -LiteralPath $OutDir -Directory | Sort-Object Name | Select-Object -Last $Last | ForEach-Object {
    $f = Join-Path $_.FullName 'summary.json'
    if (Test-Path $f) {
        $s = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
        [pscustomobject]@{
            Run = $_.Name.Substring(0, 15); Label = $s.label
            Build = if ($s.emulator) { Split-Path (Split-Path $s.emulator) -Leaf } else { 'lichii-build88' }
            Options = (@($s.env, $s.set) | Where-Object { $_ }) -join ' '
            AvgFps = $s.avg_fps; P95ms = $s.frame_times.p95_ms; P99ms = $s.frame_times.p99_ms; Over33 = $s.frame_times.over_33ms; Low1 = $s.low1pct_fps; Spikes = $s.hitch_chunks; WorstMs = $s.worst_chunk_ms
        }
    }
} | Format-Table -AutoSize | Out-String -Width 200
