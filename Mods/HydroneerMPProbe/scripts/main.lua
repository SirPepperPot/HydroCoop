-- HydroCoop v0.5: read-only movement telemetry, no gameplay hooks or actor writes.
local tag='[HydroCoop v0.5] '
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
