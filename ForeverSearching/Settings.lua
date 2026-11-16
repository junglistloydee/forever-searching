local _, NS = ...
local defaults = {sort = "distance", showDistance = true, liveRefresh = true, fadeWhileMoving = true, showArrow = true, arrowLocked = false,
    sourceFilter = "all", knownOnly = false, groupedResults = true, recordStock = true, sameZone = false, factionOnly = true, searchMode = "all", recordSightings = true, minimap = true, scale = 1}

function NS.InitSettings()
    NS.db.settings = type(NS.db.settings) == "table" and NS.db.settings or {}
    for key, value in pairs(defaults) do
        if type(NS.db.settings[key]) ~= type(value) then NS.db.settings[key] = value end
    end
    if NS.db.settings.sort ~= "distance" and NS.db.settings.sort ~= "name" then NS.db.settings.sort = "distance" end
    if NS.db.settings.searchMode ~= "npc" and NS.db.settings.searchMode ~= "item" and NS.db.settings.searchMode ~= "quest" and NS.db.settings.searchMode ~= "all" then NS.db.settings.searchMode = "all" end
    if not ({all=true, vendors=true, drops=true, rewards=true, givers=true})[NS.db.settings.sourceFilter] then NS.db.settings.sourceFilter = "all" end
    if NS.db.settings.scale ~= NS.db.settings.scale or NS.db.settings.scale < 0.8 or NS.db.settings.scale > 1.2 then NS.db.settings.scale = 1 end
end

function NS.ApplySettings()
    if not NS.ui or InCombatLockdown() then return end
    NS.ui:SetScale(NS.db.settings.scale)
    if NS.launcher then NS.launcher:SetShown(NS.db.settings.minimap) end
    if NS.ValidateShoppingRoute then NS.ValidateShoppingRoute() end
    NS.UpdateMovementFade(0,true)
    if NS.UpdateNavigation then NS.UpdateNavigation() end
end

local function FlightFlag(func)
    if type(func)~="function" then return false end
    local ok,value=pcall(func,"player")
    if ok and NS.Readable(value) and type(value)=="boolean" then return value end
    -- If a present flight API cannot be read, keep the window opaque.
    return nil
end

function NS.UpdateMovementFade(elapsed, instant)
    local ui=NS.ui
    if not ui or InCombatLockdown() then return end
    local moving=NS.playerMoving==true
    if type(GetUnitSpeed)=="function" then
        local ok,speed=pcall(GetUnitSpeed,"player")
        if ok and NS.Readable(speed) and type(speed)=="number" and speed==speed then moving=speed>0 end
    end
    local grounded=FlightFlag(IsFlying)==false and FlightFlag(UnitOnTaxi)==false
    local target=NS.db.settings.fadeWhileMoving and moving and grounded and 0.35 or 1
    local current=ui.movementAlpha or 1
    local alpha=instant and target or current+(target-current)*math.min(1,(elapsed or 0.1)*8)
    if math.abs(alpha-target)<0.01 then alpha=target end
    if current~=alpha then ui:SetAlpha(alpha) end
    ui.movementAlpha=alpha
end

function NS.ResetSettings()
    NS.db.settings = {}
    NS.InitSettings()
end
