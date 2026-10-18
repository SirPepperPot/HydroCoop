# HydroCoop v0.9 solo loopback simulation; no game writes.
param([int]$Seconds=30)
$ErrorActionPreference='Stop'
$game='E:\Steam\steamapps\common\Hydroneer\Mining\Binaries\Win64'
$folder=Join-Path $game 'Mods\HydroneerMPProbe'
$local=Join-Path $folder 'local_state.txt'
$remote=Join-Path $folder 'remote_state.txt'
if (!(Test-Path $folder)) { throw "Install HydroCoop first: $folder" }
$listen=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback,49221)
$rx=[System.Net.Sockets.UdpClient]::new($listen)
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
     # Orbit close to the real player, so the ghost stays visible.
     $originX=20000.0; $originY=5000.0; $originZ=450.0
     if (Test-Path $local) {
       try {
         $parts=([System.IO.File]::ReadAllText($local).Trim()).Split('|')
         if ($parts.Length -eq 7 -and $parts[0] -eq 'HC1') {
           $ci=[System.Globalization.CultureInfo]::InvariantCulture
           $originX=[double]::Parse($parts[1],$ci)
           $originY=[double]::Parse($parts[2],$ci)
           $originZ=[double]::Parse($parts[3],$ci)
         }
       } catch { }
     }
     $phase=$ms/1000.0
     $x=$originX+300+[Math]::Sin($phase)*150
     $y=$originY+300+[Math]::Cos($phase)*150
     $z=$originZ+20
     $yaw=($phase*30)%360
     $data=[string]::Format([System.Globalization.CultureInfo]::InvariantCulture,'HC1|{0:F3}|{1:F3}|{2:F3}|0.000|{3:F3}|0.000',$x,$y,$z,$yaw)
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
