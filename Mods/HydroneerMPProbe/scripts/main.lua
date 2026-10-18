-- HydroCoop movement probe v0.4: read-only, manual 10-second capture
-- Ctrl+Alt+F8 starts ten samples; no player hooks or writes.
local PREFIX = '[HydroneerMPProbe v0.4] '
local function log(s) print(PREFIX .. tostring(s) .. '\n') end
local function valid(obj)
    if obj == nil then return false end
    local ok, yes = pcall(function() return obj:IsValid() end)
    return ok and yes == true
end
local active = false
local function sample(n)
    local ok, why = pcall(function()
        local controllers = FindAllOf('BP_GameController_C')
        if not controllers then log('SAMPLE '..n..' no controllers'); return end
        log('SAMPLE '..n..' controller_count='..tostring(#controllers))
        for i, c in ipairs(controllers) do
            if i > 2 then break end
            if valid(c) then
                local pawn = c.Pawn
                if valid(pawn) then
                    local pos = pawn:K2_GetActorLocation()
                    local rot = pawn:K2_GetActorRotation()
                    if pos and rot then
                        log(string.format('PLAYER %d X=%.3f Y=%.3f Z=%.3f Pitch=%.3f Yaw=%.3f Roll=%.3f',
                          i,pos.X,pos.Y,pos.Z,rot.Pitch,rot.Yaw,rot.Roll))
                    else log('PLAYER '..i..' transform unavailable') end
                else log('PLAYER '..i..' pawn invalid') end
            end
        end
    end)
    if not ok then log('SAMPLE '..n..' ERROR: '..tostring(why)) end
end
log('Loaded. No hooks, no property writes. In-world Ctrl+Alt+F8: 10 second capture. Stay in world while capturing.')
RegisterKeyBind(Key.F8, {ModifierKey.CONTROL, ModifierKey.ALT}, function()
    if active then log('Capture already active'); return end
    active = true
    log('CAPTURE START 10 samples; do not change levels or return to menu')
    local n = 0
    LoopAsync(1000, function()
        n = n + 1
        local ok, err = pcall(function()
            ExecuteInGameThread(function()
                sample(n)
                if n == 10 then
                    active = false
                    log('CAPTURE FINISHED')
                end
            end)
        end)
        if not ok then
            active = false
            log('Scheduling failed: '..tostring(err))
            return true
        end
        return n >= 10
    end)
end)
