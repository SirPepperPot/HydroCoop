# HydroCoop v0.13 private-network telemetry relay. Does not control Hydroneer.
param([ValidateSet('Host','Client')][string]$Mode='Host',[string]$HostIP='',[int]$Port=49221)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$folder=Join-Path $root 'Mods\HydroneerMPProbe'
$local=Join-Path $folder 'local_state.txt'
$remote=Join-Path $folder 'remote_state.txt'
$localBucket=Join-Path $folder 'local_bucket_state.txt'
$remoteBucket=Join-Path $folder 'remote_bucket_state.txt'
$bucketPattern='^HC2\|[0-9]{1,10}\|[A-Za-z0-9_-]{1,80}\|(GROUND|HELD|MESH|ATTACHED)\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+
if (!(Test-Path $folder)) { throw "Missing mod folder $folder. Run installer first." }
if ($Mode -eq 'Client' -and !$HostIP) { throw 'Client must specify -HostIP with host Tailscale IPv4 address.' }
$udp=[System.Net.Sockets.UdpClient]::new($Port)
$peer=$null
if ($Mode -eq 'Client') { $peer=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($HostIP),$Port) }
$lastSend=[datetime]::MinValue; $lastReport=[datetime]::MinValue
$sent=0; $received=0; $bucketSent=0; $bucketReceived=0
Write-Host "HydroCoop v0.13 | $Mode | UDP $Port | Ctrl+C to stop"
Write-Host 'Trusted peers / Tailscale only; movement and bucket metadata only; received packets never mutate game objects.'
try {
 while ($true) {
   while ($udp.Available -gt 0) {
     $source=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)
     $bytes=$udp.Receive([ref]$source)
     $data=[System.Text.Encoding]::ASCII.GetString($bytes).Trim()
     if ($data -match '^HC1\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+$') {
       if ($Mode -eq 'Host' -and !$peer) { $peer=$source; Write-Host "Peer: $($peer.Address):$($peer.Port)" }
       if ($peer -and $source.Address.Equals($peer.Address) -and $source.Port -eq $peer.Port) {
         [System.IO.File]::WriteAllText($remote,$data+[Environment]::NewLine)
         $received++
       }
     }
     elseif ($data.Length -le 240 -and $data -match $bucketPattern) {
       if ($Mode -eq 'Host' -and !$peer) { $peer=$source; Write-Host "Peer: $($peer.Address):$($peer.Port)" }
       if ($peer -and $source.Address.Equals($peer.Address) -and $source.Port -eq $peer.Port) {
         [System.IO.File]::WriteAllText($remoteBucket,$data+[Environment]::NewLine)
         $bucketReceived++
       }
     }
   }
   $now=Get-Date
   if ($peer -and ($now-$lastSend).TotalMilliseconds -ge 250) {
     $lastSend=$now
     if (Test-Path $local) {
       try {
         $data=[System.IO.File]::ReadAllText($local).Trim()
         if ($data -match '^HC1\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+$') {
           $bytes=[System.Text.Encoding]::ASCII.GetBytes($data)
           [void]$udp.Send($bytes,$bytes.Length,$peer)
           $sent++
         }
       } catch [System.IO.IOException] {}
     }
   }
   if ($peer -and (Test-Path $localBucket)) {
     try {
       $bucketData=[System.IO.File]::ReadAllText($localBucket).Trim()
       if ($bucketData -ne $lastBucketPacket -and $bucketData.Length -le 240 -and $bucketData -match $bucketPattern) {
         $payload=[System.Text.Encoding]::ASCII.GetBytes($bucketData)
         [void]$udp.Send($payload,$payload.Length,$peer)
         $bucketSent++
         $lastBucketPacket=$bucketData
       }
     } catch [System.IO.IOException] {}
   }
   if (($now-$lastReport).TotalSeconds -ge 5) {
     $lastReport=$now
     Write-Host "Sent=$sent Received=$received LocalFile=$(Test-Path $local) Connected=$($null -ne $peer) BucketSent=$bucketSent BucketReceived=$bucketReceived"
   }
   Start-Sleep -Milliseconds 35
 }
} finally { $udp.Close() }

$lastBucketPacket=''
if (!(Test-Path $folder)) { throw "Missing mod folder $folder. Run installer first." }
if ($Mode -eq 'Client' -and !$HostIP) { throw 'Client must specify -HostIP with host Tailscale IPv4 address.' }
$udp=[System.Net.Sockets.UdpClient]::new($Port)
$peer=$null
if ($Mode -eq 'Client') { $peer=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($HostIP),$Port) }
$lastSend=[datetime]::MinValue; $lastReport=[datetime]::MinValue
$sent=0; $received=0
Write-Host "HydroCoop v0.5 | $Mode | UDP $Port | Ctrl+C to stop"
Write-Host 'Trusted peers / Tailscale only; movement telemetry only, no remote player in game.'
try {
 while ($true) {
   while ($udp.Available -gt 0) {
     $source=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)
     $bytes=$udp.Receive([ref]$source)
     $data=[System.Text.Encoding]::ASCII.GetString($bytes).Trim()
     if ($data -match '^HC1\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+$') {
       if ($Mode -eq 'Host' -and !$peer) { $peer=$source; Write-Host "Peer: $($peer.Address):$($peer.Port)" }
       if ($peer -and $source.Address.Equals($peer.Address) -and $source.Port -eq $peer.Port) {
         [System.IO.File]::WriteAllText($remote,$data+[Environment]::NewLine)
         $received++
       }
     }
   }
   $now=Get-Date
   if ($peer -and ($now-$lastSend).TotalMilliseconds -ge 250) {
     $lastSend=$now
     if (Test-Path $local) {
       try {
         $data=[System.IO.File]::ReadAllText($local).Trim()
         if ($data -match '^HC1\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+\|[-0-9.]+$') {
           $bytes=[System.Text.Encoding]::ASCII.GetBytes($data)
           [void]$udp.Send($bytes,$bytes.Length,$peer)
           $sent++
         }
       } catch [System.IO.IOException] {}
     }
   }
   if (($now-$lastReport).TotalSeconds -ge 5) {
     $lastReport=$now
     Write-Host "Sent=$sent Received=$received LocalFile=$(Test-Path $local) Connected=$($null -ne $peer)"
   }
   Start-Sleep -Milliseconds 35
 }
} finally { $udp.Close() }
