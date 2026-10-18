-- HydroCoop v0.7: read-only movement telemetry, no gameplay hooks or actor writes.
local tag='[HydroCoop v0.7] '
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
