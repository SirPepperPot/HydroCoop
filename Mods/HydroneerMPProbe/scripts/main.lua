-- HydroCoop v0.13: read-only movement telemetry, no gameplay hooks or actor writes.
local tag='[HydroCoop v0.13] '
local function log(s) print(tag..tostring(s)..'\n') end
local path='Mods/HydroneerMPProbe/local_state.txt'
local count=0
local errors=0
local function valid(v)
  if v==nil then return false end
  local ok,result=pcall(function() return v:IsValid() end)
  return ok and result==true
end
local function capture()
  local controllers=FindAllOf('BP_GameController_C')
  if not controllers then return end
  for _,c in ipairs(controllers) do
    if valid(c) then
      local pawn=c.Pawn
      if valid(pawn) then
        local p=pawn:K2_GetActorLocation()
        local r=pawn:K2_GetActorRotation()
        if p and r then
          local f,err=io.open(path,'w')
          if not f then error(tostring(err)) end
          f:write(string.format('HC1|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f\n',p.X,p.Y,p.Z,r.Pitch,r.Yaw,r.Roll))
          f:close()
          count=count+1
          if count%40==0 then log('Published '..count..' samples') end
          return
        end
      end
    end
  end
end
log('Loaded, sampling player transform every 250ms. No gameplay hooks.')
LoopAsync(250,function()
  ExecuteInGameThread(function()
    local ok,err=pcall(capture)
    if not ok then
      errors=errors+1
      if errors<=5 then log('ERROR '..tostring(err)) end
    end
  end)
  return false
end)

-- v0.7: read back network transport output in-game on Ctrl+Alt+F9.
-- No actor creation or changes; validate the data bridge before spawning a remote actor.
local remotePath='Mods/HydroneerMPProbe/remote_state.txt'
local function inspectRemote()
  local f,err=io.open(remotePath,'r')
  if not f then log('REMOTE unavailable: '..tostring(err)); return end
  local line=f:read('*l')
  f:close()
  if not line then log('REMOTE empty'); return end
  local nums={}
  for item in string.gmatch(line,'[^|]+') do nums[#nums+1]=item end
  if #nums~=7 or nums[1]~='HC1' then log('REMOTE invalid format');return end
  for i=2,7 do
    nums[i]=tonumber(nums[i])
    if nums[i]==nil or nums[i]~=nums[i] or math.abs(nums[i])>1e8 then
      log('REMOTE invalid numeric field '..i);return
    end
  end
  log(string.format('REMOTE BRIDGE OK X=%.3f Y=%.3f Z=%.3f Pitch=%.3f Yaw=%.3f Roll=%.3f',nums[2],nums[3],nums[4],nums[5],nums[6],nums[7]))
end
RegisterKeyBind(Key.F9,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  local ok,err=pcall(inspectRemote)
  if not ok then log('REMOTE BRIDGE ERROR '..tostring(err)) end
end)
log('v0.7 remote data readback: Ctrl+Alt+F9')

-- v0.8 isolated spawn experiment. This action is opt-in and always off by default.
-- Ctrl+Alt+F10: create one non-possessed actor using the player's character class,
-- at an offset from the local player. Ctrl+Alt+F11: destroy only that actor.
-- Do NOT use on valuable saves. Spawn may invoke Hydroneer's character BeginPlay.
local ghost=nil
local movementEnabled=false
local function spawnGhost()
  if ghost and valid(ghost) then log('GHOST already spawned; use Ctrl+Alt+F11 to remove');return end
  local controllers=FindAllOf('BP_GameController_C')
  if not controllers then log('GHOST no controllers');return end
  local ctrl=nil
  for _,c in ipairs(controllers) do if valid(c) and valid(c.Pawn) then ctrl=c;break end end
  if not ctrl then log('GHOST no valid player');return end
  local pawn=ctrl.Pawn
  local world=pawn:GetWorld()
  if not valid(world) then log('GHOST invalid world');return end
  local cls=pawn:GetClass()
  if not valid(cls) then log('GHOST invalid class');return end
  local p=pawn:K2_GetActorLocation()
  local r=pawn:K2_GetActorRotation()
  if not p or not r then log('GHOST missing transform');return end
  local location={X=p.X+250,Y=p.Y+250,Z=p.Z+50}
  local rotation={Pitch=0,Yaw=r.Yaw,Roll=0}
  local created=world:SpawnActor(cls,location,rotation)
  if valid(created) then
    ghost=created
    log('GHOST SPAWNED '..tostring(created:GetFullName()))
  else
    log('GHOST spawn returned invalid actor')
  end
end
local function removeGhost()
  if not ghost or not valid(ghost) then log('GHOST nothing to remove');ghost=nil;return end
  ghost:K2_DestroyActor()
  ghost=nil
  movementEnabled=false
  log('GHOST removed')
end
RegisterKeyBind(Key.F10,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    local ok,err=pcall(spawnGhost)
    if not ok then log('GHOST SPAWN ERROR '..tostring(err)) end
  end)
end)
RegisterKeyBind(Key.F11,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    local ok,err=pcall(removeGhost)
    if not ok then log('GHOST REMOVE ERROR '..tostring(err)) end
  end)
end)
log('v0.8 optional ghost spawn Ctrl+Alt+F10; remove Ctrl+Alt+F11. USE DISPOSABLE WORLD ONLY.')

-- v0.9: manually enable 20 seconds of ghost-only movement from received file.
-- Ctrl+Alt+F12, after spawning. Never touches the controlled player.
local moveTicks=0
local moveErrors=0
local function readRemoteTransform()
  local f=io.open(remotePath,'r')
  if not f then return nil end
  local line=f:read('*l');f:close()
  if not line then return nil end
  local t={}
  for v in string.gmatch(line,'[^|]+') do t[#t+1]=v end
  if #t~=7 or t[1]~='HC1' then return nil end
  for i=2,7 do
    t[i]=tonumber(t[i])
    if not t[i] or t[i]~=t[i] or math.abs(t[i])>1e7 then return nil end
  end
  return {X=t[2],Y=t[3],Z=t[4]},{Pitch=t[5],Yaw=t[6],Roll=t[7]}
end
-- v0.10: interpolate toward received transform at 20 Hz; 20-second manual test.
local targetPos=nil
local targetRot=nil
local moveSteps=0
local function lerpAngle(a,b,alpha)
  local d=(b-a+180)%360-180
  return a+d*alpha
end
RegisterKeyBind(Key.F12,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    if not valid(ghost) then log('GHOST MOVE: Spawn ghost first (Ctrl+Alt+F10)');return end
    if movementEnabled then movementEnabled=false;log('GHOST MOVE OFF');return end
    moveTicks=0;moveSteps=0;moveErrors=0;targetPos=nil;targetRot=nil
    movementEnabled=true
    log('GHOST SMOOTH MOVE ON: 20 seconds; Ctrl+Alt+F12 disables.')
  end)
end)
LoopAsync(50,function()
  if movementEnabled then
    ExecuteInGameThread(function()
      if not movementEnabled then return end
      if not valid(ghost) then movementEnabled=false;log('GHOST MOVE STOP: ghost invalid');return end
      moveSteps=moveSteps+1
      if moveSteps>400 then movementEnabled=false;log('GHOST MOVE STOP: 20-second limit');return end
      local ok,err=pcall(function()
        if moveSteps%5==1 then
          local p,r=readRemoteTransform()
          if p then targetPos=p;targetRot=r end
        end
        if not targetPos then
          if moveSteps%100==1 then log('GHOST MOVE: awaiting remote data') end
          return
        end
        local p=ghost:K2_GetActorLocation()
        local r=ghost:K2_GetActorRotation()
        if not p or not r then return end
        local dx=targetPos.X-p.X
        local dy=targetPos.Y-p.Y
        local dz=targetPos.Z-p.Z
        local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
        -- Never snap to a remote target. Cap each 50ms step to a plausible walking speed.
        local alpha=0.22
        local maxStep=25
        local factor=alpha
        if distance*factor>maxStep then factor=maxStep/distance end
        local nextPos={X=p.X+dx*factor,Y=p.Y+dy*factor,Z=p.Z+dz*factor}
        local nextRot={
          Pitch=lerpAngle(r.Pitch,targetRot.Pitch,alpha),
          Yaw=lerpAngle(r.Yaw,targetRot.Yaw,alpha),
          Roll=lerpAngle(r.Roll,targetRot.Roll,alpha)
        }
        ghost:K2_SetActorLocation(nextPos,false,{},true)
        ghost:K2_SetActorRotation(nextRot,true)
        if moveSteps%100==0 then
          local actual=ghost:K2_GetActorLocation()
          log(string.format('GHOST SMOOTH tick=%d remaining=%.1f actual=%.1f,%.1f,%.1f',
            moveSteps,distance,actual.X,actual.Y,actual.Z))
        end
      end)
      if not ok then
        moveErrors=moveErrors+1
        if moveErrors<=3 then log('GHOST SMOOTH ERROR: '..tostring(err)) end
        if moveErrors>=3 then movementEnabled=false;log('GHOST MOVE DISABLED after 3 errors') end
      end
    end)
  end
  return false
end)
log('v0.10 Ctrl+Alt+F12 smooth 20-second ghost movement from remote_state.txt.')

-- v0.11 read-only nearby actor discovery, manual Ctrl+Alt+F8.
-- No interaction hooks, actor mutations, or item replication yet.
local scanNumber=0
local previousNearby=nil
local function scanNearby()
  local controllers=FindAllOf('BP_GameController_C')
  local player=nil
  if controllers then
    for _,c in ipairs(controllers) do
      if valid(c) and valid(c.Pawn) then player=c.Pawn;break end
    end
  end
  if not player then log('SCAN: player not ready');return end
  local here=player:K2_GetActorLocation()
  local actors=FindAllOf('Actor')
  if not actors then log('SCAN: FindAllOf Actor returned nil');return end
  scanNumber=scanNumber+1
  local nearby={}
  local kinds={}
  local found=0
  local exceptions=0
  for _,a in ipairs(actors) do
    if valid(a) and a~=player and a~=ghost then
      local ok,p=pcall(function() return a:K2_GetActorLocation() end)
      if ok and p and p.X and p.Y and p.Z then
        local dx=p.X-here.X
        local dy=p.Y-here.Y
        local dz=p.Z-here.Z
        if dx*dx+dy*dy+dz*dz<=900*900 then
          local good,name=pcall(function() return a:GetFullName() end)
          if good and name then
            found=found+1
            local cls=name:match('^([^ ]+)') or 'Unknown'
            kinds[cls]=(kinds[cls] or 0)+1
            nearby[name]=string.format('(%.0f,%.0f,%.0f)',p.X,p.Y,p.Z)
          end
        end
      elseif not ok then exceptions=exceptions+1 end
    end
  end
  local sorted={}
  for name,n in pairs(kinds) do sorted[#sorted+1]={name=name,n=n} end
  table.sort(sorted,function(a,b) if a.n==b.n then return a.name<b.name end return a.n>b.n end)
  log(string.format('SCAN #%d within 900 units: %d actors, %d classes, %d unreadable',scanNumber,found,#sorted,exceptions))
  for i=1,math.min(#sorted,35) do
    log(string.format('SCAN CLASS %d %s count=%d',i,sorted[i].name,sorted[i].n))
  end
  if previousNearby then
    local added,removed=0,0
    for name,pos in pairs(nearby) do
      if not previousNearby[name] then
        added=added+1
        if added<=15 then log('SCAN NEW '..name..' '..pos) end
      end
    end
    for name,_ in pairs(previousNearby) do
      if not nearby[name] then
        removed=removed+1
        if removed<=15 then log('SCAN GONE '..name) end
      end
    end
    log(string.format('SCAN DELTA new=%d gone=%d (may include range transitions)',added,removed))
  end
  previousNearby=nearby
end
RegisterKeyBind(Key.F8,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    local ok,err=pcall(scanNearby)
    if not ok then log('SCAN ERROR '..tostring(err)) end
  end)
end)
log('v0.11 Ctrl+Alt+F8 scans nearby actor types; press before and after picking up/dropping an object.')

-- v0.12: bucket identity/transform tracker across the entire loaded world.
-- Use Ctrl+Alt+F7 before, during and after holding/dropping the same bucket.
-- This is a read-only census (no hooks, no writes).
local lastBucketScan=nil
local function inspectBuckets()
  local all=FindAllOf('BP_Bucket_C') or {}
  local current={}
  local n=0
  for _,a in ipairs(all) do
    if valid(a) then
      local ok,data=pcall(function()
        local name=a:GetFullName()
        local p=a:K2_GetActorLocation()
        if not p then return nil end
        local root=a.RootComponent
        local attached='unknown'
        if valid(root) then
          local parent=root.AttachParent
          if valid(parent) then attached=tostring(parent:GetFullName()) else attached='none' end
        end
        return {name=name,pos={X=p.X,Y=p.Y,Z=p.Z},parent=attached}
      end)
      if ok and data then current[data.name]=data;n=n+1 end
    end
  end
  log('BUCKET GLOBAL total='..n)
  local names={}
  for name,_ in pairs(current) do names[#names+1]=name end
  table.sort(names)
  for i,name in ipairs(names) do
    if i>30 then log('BUCKET output limited to 30 actors');break end
    local b=current[name]
    local prior=lastBucketScan and lastBucketScan[name]
    local label=prior and 'EXISTING' or 'PRESENT'
    if lastBucketScan and not prior then label='NEW' end
    local dist='-'
    if prior then
      local dx=b.pos.X-prior.pos.X
      local dy=b.pos.Y-prior.pos.Y
      local dz=b.pos.Z-prior.pos.Z
      dist=string.format('%.1f',math.sqrt(dx*dx+dy*dy+dz*dz))
    end
    log(string.format('BUCKET %s %s xyz=%.1f,%.1f,%.1f moved=%s attachedTo=%s',
      label,name,b.pos.X,b.pos.Y,b.pos.Z,dist,b.parent))
  end
  if lastBucketScan then
    for name,_ in pairs(lastBucketScan) do
      if not current[name] then log('BUCKET MISSING '..name..' (destroyed/unloaded/invalid)') end
    end
  end
  lastBucketScan=current
end
RegisterKeyBind(Key.F7,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    local ok,err=pcall(inspectBuckets)
    if not ok then log('BUCKET SCAN ERROR '..tostring(err)) end
  end)
end)
log('v0.12 Ctrl+Alt+F7 globally tracks bucket actors, positions and attachment.')

-- v0.13 experimental bucket state packet publisher (read-only).
-- Ctrl+Alt+F6 selects the nearest bucket within 300 units and watches 30s.
-- HC2 packets describe the same actor's observed transform and held state.
local bucketWatch=nil
local bucketWatchTick=0
local bucketWatchSeq=0
local bucketLastState=nil
local bucketLastPos=nil
local bucketPackets=0
local bucketPacketPath='Mods/HydroneerMPProbe/local_bucket_state.txt'
local function bucketState(a)
  local pos=a:K2_GetActorLocation()
  if not pos then return nil end
  local attachment='none'
  local parentComponent='none'
  local root=a.RootComponent
  if valid(root) and valid(root.AttachParent) then
    local parent=root.AttachParent
    local pname=tostring(parent:GetFullName())
    attachment=string.find(pname,'PlayerHand',1,true) and 'HELD' or
      (string.find(pname,'CharacterMesh',1,true) and 'MESH' or 'ATTACHED')
    parentComponent=pname
  else
    attachment='GROUND'
  end
  return {x=pos.X,y=pos.Y,z=pos.Z,state=attachment,parent=parentComponent}
end
local function findPlayer()
  local controllers=FindAllOf('BP_GameController_C') or {}
  for _,c in ipairs(controllers) do
    if valid(c) and valid(c.Pawn) then return c.Pawn end
  end
end
local function startBucketWatch()
  if bucketWatch then bucketWatch=nil;log('BUCKET WATCH STOPPED');return end
  local pawn=findPlayer()
  if not valid(pawn) then log('BUCKET WATCH: player not found');return end
  local pos=pawn:K2_GetActorLocation()
  local chosen=nil
  local best=300*300
  for _,a in ipairs(FindAllOf('BP_Bucket_C') or {}) do
    if valid(a) then
      local ok,p=pcall(function() return a:K2_GetActorLocation() end)
      if ok and p then
        local dx=p.X-pos.X
        local dy=p.Y-pos.Y
        local dz=p.Z-pos.Z
        local d=dx*dx+dy*dy+dz*dz
        if d<best then chosen=a;best=d end
      end
    end
  end
  if not chosen then log('BUCKET WATCH: no bucket within 300 units');return end
  bucketWatch=chosen
  bucketWatchTick=0
  bucketWatchSeq=0
  bucketLastState=nil
  bucketLastPos=nil
  bucketPackets=0
  log('BUCKET WATCH START 30s actor='..tostring(chosen:GetFullName()))
end
RegisterKeyBind(Key.F6,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    local ok,err=pcall(startBucketWatch)
    if not ok then log('BUCKET WATCH START ERROR '..tostring(err)) end
  end)
end)
LoopAsync(250,function()
  if bucketWatch then
    ExecuteInGameThread(function()
      if not bucketWatch then return end
      bucketWatchTick=bucketWatchTick+1
      if bucketWatchTick>120 then bucketWatch=nil;log('BUCKET WATCH STOP: 30s limit');return end
      if not valid(bucketWatch) then bucketWatch=nil;log('BUCKET WATCH STOP: actor invalid');return end
      local ok,err=pcall(function()
        local b=bucketState(bucketWatch)
        if not b then return end
        local changed=bucketLastState~=b.state
        local moved=not bucketLastPos or math.sqrt((b.x-bucketLastPos.x)^2+(b.y-bucketLastPos.y)^2+(b.z-bucketLastPos.z)^2)>35
        local heartbeat=bucketWatchTick%4==0
        if changed or moved or heartbeat then
          bucketWatchSeq=bucketWatchSeq+1
          local name=tostring(bucketWatch:GetFullName())
          local id=name:match('([^%.]+)$') or 'bucket'
          id=id:gsub('[^%w_%-]','_'):sub(1,80)
          local line=string.format('HC2|%d|%s|%s|%.2f|%.2f|%.2f',bucketWatchSeq,id,b.state,b.x,b.y,b.z)
          local file,e=io.open(bucketPacketPath,'w')
          if not file then error(tostring(e)) end
          file:write(line..'\n')
          file:close()
          bucketPackets=bucketPackets+1
          if changed or bucketPackets%5==0 then
            log(string.format('BUCKET EVENT seq=%d id=%s state=%s pos=%.1f,%.1f,%.1f parent=%s',
              bucketWatchSeq,id,b.state,b.x,b.y,b.z,b.parent))
          end
          bucketLastState=b.state
          bucketLastPos={x=b.x,y=b.y,z=b.z}
        end
      end)
      if not ok then log('BUCKET WATCH ERROR '..tostring(err));bucketWatch=nil end
    end)
  end
  return false
end)
log('v0.13 Ctrl+Alt+F6 watches nearest bucket for 30s and writes read-only HC2 packets.')
