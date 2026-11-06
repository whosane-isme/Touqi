# Turns a local build into a runnable install folder for benchmarking:
# copies bin\ (exe + DLLs), runs windeployqt for Qt, and gives it a copy of the owner's user data
# (config, saves, keys) and the shader cache of the official build-88 (same cache format).
#   .\Package-LocalBuild.ps1 -BuildDir D:\ns2\lichii-out\b88-base -Dest D:\ns2\lichii-local\base
param(
    [Parameter(Mandatory = $true)][string]$BuildDir,
    [Parameter(Mandatory = $true)][string]$Dest,
    [string]$UserFrom = 'D:\ns2\lichii-build88\user',
    [string]$QtBin = 'D:\BuildTools\Qt\6.8.3\msvc2022_64\bin'
)
$ErrorActionPreference = 'Stop'
$bin = Join-Path $BuildDir 'bin'
if (-not (Test-Path (Join-Path $bin 'lichii.exe'))) { throw "No lichii.exe in $bin" }
if (Get-Process lichii -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Dest*" }) { throw "$Dest is running" }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
robocopy $bin $Dest /E /NFL /NDL /NJH /NJS /NP /XF *.ilk | Out-Null
$ErrorActionPreference = 'Continue'
& (Join-Path $QtBin 'windeployqt.exe') --release --no-translations (Join-Path $Dest 'lichii.exe') 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
# Not in Qt: take the DirectX shader compiler DLLs from the official build.
foreach ($dll in Get-ChildItem (Split-Path $UserFrom) -Filter *.dll) {
    if (-not (Test-Path (Join-Path $Dest $dll.Name))) { Copy-Item $dll.FullName $Dest }
}
$user = Join-Path $Dest 'user'
foreach ($d in 'config', 'nand', 'keys', 'cache', 'load', 'sdmc', 'amiibo') {
    $src = Join-Path $UserFrom $d
    if (Test-Path $src) { robocopy $src (Join-Path $user $d) /E /NFL /NDL /NJH /NJS /NP | Out-Null }
}
Write-Output "Packaged: $Dest"
