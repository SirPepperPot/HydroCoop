# HydroCoop latest installer: UE4SS required, Hydroneer must be closed.
$ErrorActionPreference='Stop'
$base='https://raw.githubusercontent.com/SirPepperPot/HydroCoop/main'
$game='E:\Steam\steamapps\common\Hydroneer\Mining\Binaries\Win64'
$mod=Join-Path $game 'Mods\HydroneerMPProbe'
if (!(Test-Path (Join-Path $game 'Mining-Win64-Shipping.exe'))) { throw "Hydroneer not found: $game" }
if (!(Test-Path (Join-Path $game 'Mods'))) { throw 'UE4SS Mods folder missing.' }
if (Get-Process -Name 'Mining-Win64-Shipping' -ErrorAction SilentlyContinue) { throw 'Close Hydroneer before updating.' }
$work=Join-Path $env:TEMP ('HydroCoopUpdate-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $lua=Join-Path $work 'main.lua'
  $relay=Join-Path $work 'HydroCoop-Relay.ps1'
  $solo=Join-Path $work 'Test-HydroCoop-Local.ps1'
  $cacheBust=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Invoke-WebRequest -Uri "$base/Mods/HydroneerMPProbe/scripts/main.lua?v=$cacheBust" -OutFile $lua -UseBasicParsing
  Invoke-WebRequest -Uri "$base/HydroCoop-Relay.ps1?v=$cacheBust" -OutFile $relay -UseBasicParsing
  Invoke-WebRequest -Uri "$base/Test-HydroCoop-Local.ps1?v=$cacheBust" -OutFile $solo -UseBasicParsing
  if ((Get-Item $lua).Length -lt 100 -or (Get-Item $relay).Length -lt 100) { throw 'Download incomplete.' }
  $downloaded = Get-Content -LiteralPath $lua -Raw
  if ($downloaded -notmatch 'HydroCoop v0\.10' -or $downloaded -notmatch 'Key\.F8') { throw 'Downloaded Lua is not v0.11 or lacks movement hotkey. Existing installation unchanged.' }
  $scripts=Join-Path $mod 'scripts'
  New-Item -ItemType Directory -Force -Path $scripts | Out-Null
  $target=Join-Path $scripts 'main.lua'
  if (Test-Path $target) { Copy-Item $target "$target.bak" -Force }
  Copy-Item $lua $target -Force
  $installed = Get-Content -LiteralPath $target -Raw
  if ($installed -notmatch 'HydroCoop v0\.10' -or $installed -notmatch 'Key\.F8') { throw 'Installed mod is not v0.11: actor scan hotkey missing.' }
  Copy-Item $relay (Join-Path $game 'HydroCoop-Relay.ps1') -Force
  Copy-Item $solo (Join-Path $game 'Test-HydroCoop-Local.ps1') -Force
  New-Item -Path (Join-Path $mod 'enabled.txt') -ItemType File -Force | Out-Null
  Write-Host 'HydroCoop v0.11 installed and verified (actor scan hotkey present). UE4SS stays installed.' -ForegroundColor Green
  Write-Host 'Nearby actor scan: Ctrl+Alt+F8 (read-only).'
  Write-Host 'Experimental ghost: Ctrl+Alt+F10 to try spawning; Ctrl+Alt+F11 to remove. Disposable world ONLY.'
  Write-Host 'Solo test: powershell -ExecutionPolicy Bypass -File .\Test-HydroCoop-Local.ps1'
  Write-Host 'Host: powershell -ExecutionPolicy Bypass -File .\HydroCoop-Relay.ps1 -Mode Host'
  Write-Host 'Installed Lua:' $target
  Write-Host 'Client: powershell -ExecutionPolicy Bypass -File .\HydroCoop-Relay.ps1 -Mode Client -HostIP HOST_TAILSCALE_IP'
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
