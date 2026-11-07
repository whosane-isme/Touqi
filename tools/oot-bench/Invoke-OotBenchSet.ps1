# Runs the benchmark -Count times (each a fresh launch) with the same options, explains the drops
# of each run, and prints one comparable line per run.
param(
    [string]$Label = 'bench',
    [string]$Env = '',
    [string]$Set = '',
    [int]$Count = 1,
    [string]$Install = '',
    [int]$IdleFrames = 0
)
$ErrorActionPreference = 'Stop'
for ($i = 1; $i -le $Count; $i++) {
    $name = if ($Count -gt 1) { "$Label-$i" } else { $Label }
    $out = & (Join-Path $PSScriptRoot 'Run-OotBench.ps1') -Launch -Label $name -Env $Env -Set $Set -Install $Install -IdleFrames $IdleFrames
    $dir = (($out | Where-Object { $_ -like 'Saved: *' }) -replace '^Saved: ', '') | Select-Object -Last 1
    & (Join-Path $PSScriptRoot 'Analyze-OotDrops.ps1') -Run $dir | Select-Object -First 1
    & (Join-Path $PSScriptRoot 'Analyze-OotDrops.ps1') -Run $dir | Select-Object -Last 1
    $ft = (Get-Content -LiteralPath (Join-Path $dir 'summary.json') -Raw | ConvertFrom-Json).frame_times
    if ($ft) {
        '  frame times: p50 {0} ms, p95 {1} ms, p99 {2} ms, max {3} ms, {4} over 33 ms, fence wait {5} ms' -f
            $ft.p50_ms, $ft.p95_ms, $ft.p99_ms, $ft.max_ms, $ft.over_33ms, $ft.fence_wait_mean_ms
    }
}
Get-Process lichii, selevet, eglantine -ErrorAction SilentlyContinue | Stop-Process -Force
