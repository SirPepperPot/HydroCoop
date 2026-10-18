-- HydroCoop v0.9: read-only movement telemetry, no gameplay hooks or actor writes.
local tag='[HydroCoop v0.9] '
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
local movementEnabled=false
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
RegisterKeyBind(Key.F12,{ModifierKey.CONTROL,ModifierKey.ALT},function()
  ExecuteInGameThread(function()
    if not valid(ghost) then log('GHOST MOVE: Spawn ghost first (Ctrl+Alt+F10)');return end
    if movementEnabled then movementEnabled=false;log('GHOST MOVE OFF');return end
    moveTicks=0;moveErrors=0;movementEnabled=true
    log('GHOST MOVE ON: 20 seconds, received data only; Ctrl+Alt+F12 disables.')
  end)
end)
LoopAsync(250,function()
  if movementEnabled then
    ExecuteInGameThread(function()
      if not movementEnabled then return end
      if not valid(ghost) then movementEnabled=false;log('GHOST MOVE STOP: ghost invalid');return end
      moveTicks=moveTicks+1
      if moveTicks>80 then movementEnabled=false;log('GHOST MOVE STOP: 20-second limit');return end
      local ok,err=pcall(function()
        local p,r=readRemoteTransform()
        if not p then
          if moveTicks%20==1 then log('GHOST MOVE: remote data unavailable/invalid') end
          return
        end
        -- K2_SetActorLocation only targets the ghost owned by this mod.
        ghost:K2_SetActorLocation(p,false,{},true)
        ghost:K2_SetActorRotation(r,true)
        if moveTicks%20==0 then
          local actual=ghost:K2_GetActorLocation()
          log(string.format('GHOST MOVE tick=%d target=%.1f,%.1f,%.1f actual=%.1f,%.1f,%.1f',
            moveTicks,p.X,p.Y,p.Z,actual.X,actual.Y,actual.Z))
        end
      end)
      if not ok then
        moveErrors=moveErrors+1
        if moveErrors<=3 then log('GHOST MOVE ERROR: '..tostring(err)) end
        if moveErrors>=3 then movementEnabled=false;log('GHOST MOVE DISABLED after 3 errors') end
      end
    end)
  end
  return false
end)
log('v0.9 Ctrl+Alt+F12 toggles 20-second movement of ghost from remote_state.txt.')
