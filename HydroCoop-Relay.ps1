# HydroCoop v0.5 private-network telemetry relay. Does not control Hydroneer.
param([ValidateSet('Host','Client')][string]$Mode='Host',[string]$HostIP='',[int]$Port=49221)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$folder=Join-Path $root 'Mods\HydroneerMPProbe'
$local=Join-Path $folder 'local_state.txt'
$remote=Join-Path $folder 'remote_state.txt'
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
