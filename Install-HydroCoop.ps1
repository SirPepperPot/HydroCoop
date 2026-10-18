# HydroCoop latest installer: UE4SS required, Hydroneer must be closed.
$ErrorActionPreference='Stop'
$base='https://raw.githubusercontent.com/SirPepperPot/HydroCoop/ea22545fd065343e041b4ca98690b69c9d581a80'
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
  if ((Get-Content -LiteralPath $relay -Raw) -notmatch 'bucketPattern') { throw 'Downloaded relay missing HC2 support. Existing installation unchanged.' }
  # Verify the downloaded payload *before* overwriting the existing mod.
  $downloaded = Get-Content -LiteralPath $lua -Raw
  if ($downloaded -notmatch 'HydroCoop v0\.14' -or $downloaded -notmatch 'Key\.F5') { throw 'Downloaded Lua is not v0.14 or lacks receiver hotkey. Existing installation unchanged.' }
  $scripts=Join-Path $mod 'scripts'
  New-Item -ItemType Directory -Force -Path $scripts | Out-Null
  $target=Join-Path $scripts 'main.lua'
  if (Test-Path $target) { Copy-Item $target "$target.bak" -Force }
  Copy-Item $lua $target -Force
  $installed = Get-Content -LiteralPath $target -Raw
  if ($installed -notmatch 'HydroCoop v0\.14' -or $installed -notmatch 'Key\.F5') { throw 'Installed mod is not v0.14: bucket receiver hotkey missing.' }
  Copy-Item $relay (Join-Path $game 'HydroCoop-Relay.ps1') -Force
  Copy-Item $solo (Join-Path $game 'Test-HydroCoop-Local.ps1') -Force
  New-Item -Path (Join-Path $mod 'enabled.txt') -ItemType File -Force | Out-Null
  Write-Host 'HydroCoop v0.14 installed and verified (bucket event hotkey present). UE4SS stays installed.' -ForegroundColor Green
  Write-Host 'Bucket watcher: Ctrl+Alt+F6. Remote bucket receiver: Ctrl+Alt+F5 (read-only).'
  Write-Host 'Experimental ghost: Ctrl+Alt+F10 to try spawning; Ctrl+Alt+F11 to remove. Disposable world ONLY.'
  Write-Host 'Solo test: powershell -ExecutionPolicy Bypass -File .\Test-HydroCoop-Local.ps1'
  Write-Host 'Host: powershell -ExecutionPolicy Bypass -File .\HydroCoop-Relay.ps1 -Mode Host'
  Write-Host 'Installed Lua:' $target
  Write-Host 'Client: powershell -ExecutionPolicy Bypass -File .\HydroCoop-Relay.ps1 -Mode Client -HostIP HOST_TAILSCALE_IP'
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
