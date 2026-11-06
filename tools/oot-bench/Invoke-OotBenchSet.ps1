# Runs the benchmark -Count times (each a fresh launch) with the same options, explains the drops
# of each run, and prints one comparable line per run.
param(
    [string]$Label = 'bench',
    [string]$Env = '',
    [string]$Set = '',
    [int]$Count = 1
)
$ErrorActionPreference = 'Stop'
for ($i = 1; $i -le $Count; $i++) {
    $name = if ($Count -gt 1) { "$Label-$i" } else { $Label }
    $out = & (Join-Path $PSScriptRoot 'Run-OotBench.ps1') -Launch -Label $name -Env $Env -Set $Set
    $dir = (($out | Where-Object { $_ -like 'Saved: *' }) -replace '^Saved: ', '') | Select-Object -Last 1
    & (Join-Path $PSScriptRoot 'Analyze-OotDrops.ps1') -Run $dir | Select-Object -First 1
    & (Join-Path $PSScriptRoot 'Analyze-OotDrops.ps1') -Run $dir | Select-Object -Last 1
}
Get-Process lichii -ErrorAction SilentlyContinue | Stop-Process -Force
