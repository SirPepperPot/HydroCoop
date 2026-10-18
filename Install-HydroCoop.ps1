# HydroCoop UE4SS installer. Run after closing Hydroneer.
$ErrorActionPreference = 'Stop'
$repo = 'https://raw.githubusercontent.com/SirPepperPot/HydroCoop/main'
$root = 'E:\Steam\steamapps\common\Hydroneer\Mining\Binaries\Win64'
$mods = Join-Path $root 'Mods'
$dest = Join-Path $mods 'HydroneerMPProbe'
$exe = Join-Path $root 'Mining-Win64-Shipping.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Hydroneer was not found at $root. Edit the root path in this script." }
if (-not (Test-Path -LiteralPath $mods)) { throw "UE4SS Mods directory was not found at $mods" }
if (Get-Process 'Mining-Win64-Shipping' -ErrorAction SilentlyContinue) { throw 'Close Hydroneer before updating.' }
$source = "$repo/Mods/HydroneerMPProbe/scripts/main.lua"
$temp = Join-Path $env:TEMP 'HydroCoop-main.lua'
try {
    Invoke-WebRequest -Uri $source -OutFile $temp -UseBasicParsing
    if ((Get-Item $temp).Length -lt 100) { throw 'Downloaded Lua file appears incomplete.' }
    $targetScripts = Join-Path $dest 'scripts'
    New-Item -ItemType Directory -Force -Path $targetScripts | Out-Null
    $target = Join-Path $targetScripts 'main.lua'
    if (Test-Path -LiteralPath $target) {
        Copy-Item -LiteralPath $target -Destination "$target.bak" -Force
    }
    Copy-Item -LiteralPath $temp -Destination $target -Force
    New-Item -ItemType File -Force -Path (Join-Path $dest 'enabled.txt') | Out-Null
    Write-Host "HydroCoop installed and enabled: $target" -ForegroundColor Green
    Write-Host "Expected version: v0.4 read-only probe. Restart Hydroneer and press Ctrl+Alt+F8."
} finally { Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue }
