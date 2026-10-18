# HydroCoop v0.14 — private trusted-network HC1/HC2 relay, metadata only.
param([ValidateSet('Host','Client')][string]$Mode='Host',[string]$HostIP='',[int]$Port=49221)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$folder=Join-Path $root 'Mods\HydroneerMPProbe'
$local=Join-Path $folder 'local_state.txt'
$remote=Join-Path $folder 'remote_state.txt'
$localBucket=Join-Path $folder 'local_bucket_state.txt'
$remoteBucket=Join-Path $folder 'remote_bucket_state.txt'
$bucketPattern='^HC2\|(?<seq>[0-9]{1,10})\|(?<id>[A-Za-z0-9_-]{1,80})\|(?<state>GROUND|HELD|MESH|ATTACHED)\|(?<x>-?[0-9]+(?:\.[0-9]+)?)\|(?<y>-?[0-9]+(?:\.[0-9]+)?)\|(?<z>-?[0-9]+(?:\.[0-9]+)?)$'
$playerPattern='^HC1\|-?[0-9]+(?:\.[0-9]+)?\|-?[0-9]+(?:\.[0-9]+)?\|-?[0-9]+(?:\.[0-9]+)?\|-?[0-9]+(?:\.[0-9]+)?\|-?[0-9]+(?:\.[0-9]+)?\|-?[0-9]+(?:\.[0-9]+)?$'
function Test-HC2([string]$packet) {
  if ($packet.Length -gt 240 -or $packet -cnotmatch $bucketPattern) { return $null }
  $m=[regex]::Match($packet,$bucketPattern)
  $ci=[System.Globalization.CultureInfo]::InvariantCulture
  $pos=@()
  foreach ($k in @('x','y','z')) {
    $n=0.0
    if (![double]::TryParse($m.Groups[$k].Value,[System.Globalization.NumberStyles]::Float,$ci,[ref]$n)) { return $null }
    if ([double]::IsNaN($n) -or [double]::IsInfinity($n) -or [math]::Abs($n) -gt 10000000) { return $null }
    $pos+= $n
  }
  return @{ seq=[uint64]::Parse($m.Groups['seq'].Value); id=$m.Groups['id'].Value; state=$m.Groups['state'].Value; position=$pos }
}
if (!(Test-Path $folder)) { throw "Missing mod folder $folder. Run installer first." }
if ($Mode -eq 'Client' -and !$HostIP) { throw 'Client must specify -HostIP with host private IPv4 address.' }
$udp=[System.Net.Sockets.UdpClient]::new($Port)
$peer=$null
if ($Mode -eq 'Client') { $peer=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($HostIP),$Port) }
$lastBucketPacket=''
$lastSeq=@{}
$lastSend=[datetime]::MinValue
$lastReport=[datetime]::MinValue
$sent=0; $received=0; $bucketSent=0; $bucketReceived=0; $bucketRejected=0
Write-Host "HydroCoop v0.14 | $Mode | UDP $Port | Ctrl+C to stop"
Write-Host 'Trusted private peers only. Bucket packets update a file; they never modify game actors.'
try {
 while ($true) {
   while ($udp.Available -gt 0) {
     $source=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)
     $bytes=$udp.Receive([ref]$source)
     if ($bytes.Length -gt 240) { $bucketRejected++; continue }
     $data=[System.Text.Encoding]::ASCII.GetString($bytes).Trim()
     $bucket=Test-HC2 $data
     $playerValid=($data -cmatch $playerPattern)
     if (!$bucket -and !$playerValid) { $bucketRejected++; continue }
     if ($Mode -eq 'Host' -and !$peer) { $peer=$source;Write-Host "Peer: $($peer.Address):$($peer.Port)" }
     if (!$peer -or !$source.Address.Equals($peer.Address) -or $source.Port -ne $peer.Port) { $bucketRejected++; continue }
     if ($bucket) {
       $id=$bucket.id
       if ($lastSeq.ContainsKey($id) -and $bucket.seq -le $lastSeq[$id]) { $bucketRejected++;continue }
       $lastSeq[$id]=$bucket.seq
       [System.IO.File]::WriteAllText($remoteBucket,$data+[Environment]::NewLine)
       $bucketReceived++
       if ($bucketReceived -le 3 -or $bucketReceived%10 -eq 0) { Write-Host "HC2 RX seq=$($bucket.seq) id=$id state=$($bucket.state)" }
     } else {
       [System.IO.File]::WriteAllText($remote,$data+[Environment]::NewLine)
       $received++
     }
   }
   $now=Get-Date
   if ($peer -and ($now-$lastSend).TotalMilliseconds -ge 250) {
     $lastSend=$now
     if (Test-Path $local) {
       try {
         $data=[System.IO.File]::ReadAllText($local).Trim()
         if ($data -cmatch $playerPattern) {
           $bytes=[System.Text.Encoding]::ASCII.GetBytes($data)
           [void]$udp.Send($bytes,$bytes.Length,$peer)
           $sent++
         }
       } catch [System.IO.IOException] {}
     }
   }
   if ($peer -and (Test-Path $localBucket)) {
     try {
       $data=[System.IO.File]::ReadAllText($localBucket).Trim()
       if ($data -cne $lastBucketPacket -and (Test-HC2 $data)) {
         $bytes=[System.Text.Encoding]::ASCII.GetBytes($data)
         [void]$udp.Send($bytes,$bytes.Length,$peer)
         $lastBucketPacket=$data
         $bucketSent++
       }
     } catch [System.IO.IOException] {}
   }
   if (($now-$lastReport).TotalSeconds -ge 5) {
     $lastReport=$now
     Write-Host "HC1 sent=$sent received=$received HC2 sent=$bucketSent received=$bucketReceived rejected=$bucketRejected connected=$($null -ne $peer)"
   }
   Start-Sleep -Milliseconds 35
 }
} finally { $udp.Close() }
