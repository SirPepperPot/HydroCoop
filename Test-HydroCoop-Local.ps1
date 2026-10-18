# HydroCoop v0.6 solo loopback simulation; no game writes.
param([int]$Seconds=15)
$ErrorActionPreference='Stop'
$game='E:\Steam\steamapps\common\Hydroneer\Mining\Binaries\Win64'
$folder=Join-Path $game 'Mods\HydroneerMPProbe'
$local=Join-Path $folder 'local_state.txt'
$remote=Join-Path $folder 'remote_state.txt'
if (!(Test-Path $folder)) { throw "Install HydroCoop first: $folder" }
$rx=[System.Net.Sockets.UdpClient]::new([System.Net.IPAddress]::Loopback,49221)
$tx=[System.Net.Sockets.UdpClient]::new()
$destination=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback,49221)
$sw=[System.Diagnostics.Stopwatch]::StartNew()
$next=0.0; $sent=0; $received=0
Write-Host "HydroCoop localhost simulation ($Seconds seconds). No friend or Tailscale needed."
try {
 while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
   $ms=$sw.Elapsed.TotalMilliseconds
   if ($ms -ge $next) {
     $next=$ms+250
     # Use current game position when available, or a safe synthetic movement sample.
     $phase=$ms/1000.0
     $x=20000+[Math]::Sin($phase)*250
     $y=5000+[Math]::Cos($phase)*250
     $yaw=($phase*30)%360
     $data=[string]::Format([System.Globalization.CultureInfo]::InvariantCulture,'HC1|{0:F3}|{1:F3}|450.000|0.000|{2:F3}|0.000',$x,$y,$yaw)
     $bytes=[System.Text.Encoding]::ASCII.GetBytes($data)
     [void]$tx.Send($bytes,$bytes.Length,$destination)
     $sent++
   }
   while ($rx.Available -gt 0) {
     $source=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)
     $packet=$rx.Receive([ref]$source)
     if (![System.Net.IPAddress]::IsLoopback($source.Address)) { continue }
     $text=[System.Text.Encoding]::ASCII.GetString($packet).Trim()
     if ($text -match '^HC1\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+$') {
       [System.IO.File]::WriteAllText($remote,$text+[Environment]::NewLine)
       $received++
     }
   }
   Start-Sleep -Milliseconds 20
 }
} finally { $tx.Close();$rx.Close() }
Write-Host "Loopback test finished: sent=$sent received=$received"
Write-Host "Simulated remote position written to $remote"
if (Test-Path $local) { Write-Host 'Hydroneer telemetry file exists.' } else { Write-Warning 'local_state.txt absent; check game and UE4SS log.' }
if ($received -lt 1) { throw 'No loopback packets received.' }
