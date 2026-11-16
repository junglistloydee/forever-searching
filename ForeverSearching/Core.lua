local addonName, NS = ...
function NS.OpenSearch()
    if InCombatLockdown() then NS.Print("Open the search window after combat."); return end
    if not NS.ui then NS.BuildUI() end
    if not NS.ui:IsShown() then
        NS.db.settings.searchMode = "all"
        NS.selected, NS.ui.page = nil, 1
        NS.RefreshSettings()
    end
    if NS.ui.wowhead then NS.ui.wowhead.panel:Hide() end
    NS.ui:Show()
    NS.UpdateMovementFade(0,true)
    if NS.ShowSearchPage then NS.ShowSearchPage() end
    NS.ui.evidencePanel:Hide(); NS.ui.settingsPanel:Hide(); NS.ui.vendorPanel:Hide()
    if NS.ui.toolsPanel then NS.ui.toolsPanel:Hide() end
    NS.StartCatalogue()
    NS.Refresh()
    NS.ui.search:SetFocus()
    NS.ui.search:HighlightText()
end

function NS.Close()
    if InCombatLockdown() then
        NS.SetStatus("The search window can be closed after combat.")
        return false
    end
    if NS.ui then NS.ui:Hide() end
    return true
end

function NS.UpdateEscapeRegistration()
    if not NS.ui then return end
    UISpecialFrames = UISpecialFrames or {}
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "ForeverSearchingWindow" then table.remove(UISpecialFrames, i) end
    end
    -- The dialog contains a secure target button, so native Escape must not
    -- attempt to hide its protected parent during combat lockdown.
    if not InCombatLockdown() then UISpecialFrames[#UISpecialFrames + 1] = "ForeverSearchingWindow" end
end

function NS.Print(message)
    print("|cffffce73Forever Searching:|r " .. message)
end

function NS.SetStatus(message)
    if NS.ui then NS.ui.status:SetText(message) end
end

function NS.Observe(unit, purpose)
    if not NS.db or not NS.db.settings.recordSightings or InCombatLockdown() then return end
    local guid = UnitGUID(unit)
    if not NS.Readable(guid) or type(guid) ~= "string" then return end
    local kind, id = guid:match("^(%a+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return end
    id = tonumber(id)
    local name = NS.CleanName(UnitName(unit))
    if not id or not name then return end
    local old = NS.db.sightings[id]
    local now = time()
    if old and now - old.seen < 15 and not purpose then return end
    local r = old or {id = id, purpose = "Purpose not recorded", source = "Personal sighting"}
    NS.SeedEvidence(r)
    r.name, r.seen = name, now
    if purpose then
        r.roles = r.roles or {}
        r.roles[purpose] = true
        local roles = {}
        for role in pairs(r.roles) do roles[#roles + 1] = role end
        table.sort(roles)
        r.purpose = table.concat(roles, ", ")
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local report = {kind = purpose and "interaction" or "sighting", seen = now,
        detail = purpose or (unit == "target" and "Targeted" or unit == "mouseover" and "Mouseover" or "Nameplate")}
    if position then
        local x, y = position:GetXY()
        if NS.Readable(x) and NS.Readable(y) and type(x) == "number" and type(y) == "number"
            and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            r.mapID, r.x, r.y = mapID, x, y
            report.mapID, report.x, report.y = mapID, x, y
        end
    end
    NS.RememberEvidence(r, report)
    r.zone = NS.MapName(r.mapID)
    NS.db.sightings[id] = r
    -- Bound SavedVariables growth without touching the external catalogue.
    local count, oldestID, oldestTime = 0, nil, math.huge
    for key, record in pairs(NS.db.sightings) do
        count = count + 1
        if record.seen < oldestTime then oldestID, oldestTime = key, record.seen end
    end
    if count > 2000 then NS.db.sightings[oldestID] = nil end
    if NS.Refresh and NS.ui and NS.ui:IsShown() then NS.Refresh() end
end

function NS.Pin(record, evidence, route)
    if InCombatLockdown() then NS.SetStatus("Waypoints can be changed after combat."); return end
    if not (C_Map and C_Map.SetUserWaypoint and C_Map.CanSetUserWaypointOnMap and UiMapPoint) then
        NS.SetStatus("This client does not expose native user waypoints."); return
    end
    local ok, location, label
    if evidence then
        ok, location, label = true, evidence, evidence.label
        if not NS.CanNavigate(evidence) then NS.SetStatus("This report cannot be used for a waypoint."); return end
    else ok, location, label = pcall(NS.Location, record) end
    if not ok or not location then NS.SetStatus("No usable location recorded for this NPC."); return end
    if not C_Map.CanSetUserWaypointOnMap(location.mapID) then
        NS.SetStatus("Waypoints are unavailable on this map."); return
    end
    local success = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(location.mapID, location.x, location.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    if success then
        if NS.shoppingRoute~=route then NS.shoppingRoute=nil end
        NS.StartNavigation(location,record)
    end
    NS.SetStatus(success and string.format("%s: %s (%.1f, %.1f).", label,
        NS.MapName(location.mapID), location.x * 100, location.y * 100) or "The client could not place this waypoint.")
    return success
end

function NS.Toggle()
    if InCombatLockdown() then NS.Print("Open or close the search window after combat."); return end
    if not NS.ui then NS.BuildUI() end
    if NS.ui:IsShown() then NS.Close() else NS.OpenSearch() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(events.RegisterEvent,events,"PLAYER_STARTED_MOVING")
pcall(events.RegisterEvent,events,"PLAYER_STOPPED_MOVING")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_PROGRESS")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == addonName then
        -- A manually copied old SavedVariables file can still define NPCSearchDB.
        -- Prefer current data; never edit any WoW configuration or binding files.
        if type(ForeverSearchingDB) ~= "table" then
            ForeverSearchingDB = type(NPCSearchDB) == "table" and NPCSearchDB or {}
        end
        NS.db = ForeverSearchingDB
        NS.db.sightings = type(NS.db.sightings) == "table" and NS.db.sightings or {}
        NS.InitSettings()
        NS.InitPersonal()
        NS.Transmog.Init()
        NS.db.marker = tonumber(NS.db.marker) or 8
        if NS.db.marker < 0 or NS.db.marker > 8 or NS.db.marker % 1 ~= 0 then NS.db.marker = 8 end
        NS.db.version = 2
    elseif event == "PLAYER_LOGIN" then
        if not InCombatLockdown() then NS.BuildUI() end
        NS.InitVendorProfiles()
        NS.Print("Ready. Type /find to search NPCs, items and quests.")
    elseif event == "PLAYER_REGEN_DISABLED" then
        NS.CancelRoutePlanning()
        NS.UpdateEscapeRegistration()
        if NS.ui then
            NS.CancelWork("transmogBrowser")
            NS.ui.search:ClearFocus()
            NS.ui.github:ClearFocus()
            if NS.ui.transmog then NS.ui.transmog.nameBox:ClearFocus(); NS.ui.transmog.query:ClearFocus() end
            NS.ui.search:Disable()
            NS.SetStatus("Closed for combat. Reopen with /find afterwards.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not NS.ui then NS.BuildUI() end
        NS.UpdateNavigation()
        NS.UpdateEscapeRegistration()
        NS.ui.search:Enable()
        NS.PrepareTarget()
        NS.SetStatus("Ready. Search by name, purpose, zone, or NPC ID.")
        NS.Observe("target")
    elseif event == "PLAYER_STARTED_MOVING" then NS.playerMoving=true
    elseif event == "PLAYER_STOPPED_MOVING" then NS.playerMoving=false
    elseif event == "PLAYER_TARGET_CHANGED" then NS.Observe("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then NS.Observe("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then NS.Observe(arg)
    elseif event == "MERCHANT_SHOW" then NS.Observe("npc", "Vendor"); NS.ObserveMerchant()
    elseif event == "MERCHANT_UPDATE" then NS.ObserveMerchant()
    elseif event == "MERCHANT_CLOSED" then NS.CancelWork("merchantObservation")
    elseif event == "TRAINER_SHOW" then NS.Observe("npc", "Trainer")
    elseif event == "TAXIMAP_OPENED" then NS.Observe("npc", "Flight master")
    elseif event == "QUEST_DETAIL" then NS.Observe("npc", "Quest giver")
    elseif event == "QUEST_PROGRESS" then NS.Observe("npc", "Quest turn-in")
    elseif event == "GOSSIP_SHOW" then
        NS.Observe("npc")
        if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
            local quests = C_GossipInfo.GetAvailableQuests()
            if NS.Readable(quests) and type(quests) == "table" and next(quests) then NS.Observe("npc", "Quest giver") end
        end
    end
end)

SLASH_FOREVERSEARCHING1, SLASH_FOREVERSEARCHING2, SLASH_FOREVERSEARCHING3 = "/find", "/fs", "/foreversearching"
SLASH_FOREVERSEARCHING4, SLASH_FOREVERSEARCHING5 = "/sf", "/searchingforever"
SLASH_FOREVERSEARCHING6, SLASH_FOREVERSEARCHING7 = "/npcs", "/npcsearch"
SlashCmdList.FOREVERSEARCHING = function(text)
    if InCombatLockdown() then NS.Print("Search is available after combat."); return end
    if not NS.ui then NS.BuildUI() end
    if text and text:match("%S") then
        NS.OpenSearch()
        NS.RememberSearch(text)
        NS.ui.search:SetText(text)
        NS.StartCatalogue()
        NS.Refresh()
    else NS.OpenSearch() end
end
