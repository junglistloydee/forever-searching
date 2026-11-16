local _, NS = ...
NS.records = {}
NS.catalogueStatus = "Install QuestieDB for the full available catalogue."
NS.NPCFields = {"name", "subName", "npcFlags", "questStarts", "questEnds", "rank", "zoneID", "friendlyToFaction"}

function NS.Key(record) return record.resultKey or record.id end

function NS.PlayerFaction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if not NS.Readable(faction) then return nil end
    return faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
end

function NS.FactionAllowed(record, faction)
    if not NS.db.settings.factionOnly then return true end
    local group = record.friendlyToFaction
    -- Unclassified creatures remain searchable; no claim that they are friendly.
    return group ~= "A" and group ~= "H" or faction == nil or group == faction
end

function NS.NPCRecord(id, values)
    local name = values and NS.CleanName(values[1])
    if not name then return end
    local mapID = NS.areaMaps and NS.areaMaps[values[7]]
    return {id = id, name = name, purpose = NS.Roles(values, LibQuestieDB.Enum.npcFlags), mapID = mapID,
        zone = NS.MapName(mapID), source = "QuestieDB", friendlyToFaction = values[8]}
end

function NS.SearchStatus()
    local mode = NS.db and NS.db.settings.searchMode
    if mode == "all" then
        if not NS.provider then return "Enable Forever QuestieDB for item/quest sources; personal NPC sightings still work." end
        local function State(kind)
            return NS[kind .. "Loading"] and "loading" or NS[kind .. "Ready"] and "ready" or "not loaded"
        end
        return "All · NPCs " .. (NS.catalogueLoading and "loading" or NS.catalogueStarted and "ready" or "not loaded")
            .. " · Items " .. State("item") .. " · Quests " .. State("quest") .. " · cached descriptions"
    end
    return mode == "item" and (NS.itemStatus or "Item data loads when Items is selected.")
        or mode == "quest" and (NS.questStatus or "Quest data loads when Quests is selected.") or NS.catalogueStatus
end

function NS.Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

function NS.CleanName(value)
    if not NS.Readable(value) or type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    -- Never allow macro commands, conditionals, or UI escape sequences in names.
    if value == "" or #value > 100 or value:find("[%c%[%]/;|]") then return nil end
    return value
end

function NS.TargetMacro(name, marker)
    name = NS.CleanName(name)
    if not name then return nil end
    marker = tonumber(marker) or 0
    if marker < 0 or marker > 8 or marker ~= math.floor(marker) then return nil end
    -- Clearing first prevents a failed exact-name search marking the previous target.
    local body = "/cleartarget [nocombat]\n/targetexact [nocombat] " .. name
    if marker > 0 then body = body .. "\n/tm [nocombat,@target,exists] " .. marker end
    return body
end

local roleFlags = {
    {"VENDOR", "Vendor"}, {"TRAINER", "Trainer"}, {"FLIGHT_MASTER", "Flight master"},
    {"INNKEEPER", "Innkeeper"}, {"BANKER", "Banker"}, {"AUCTIONEER", "Auctioneer"},
    {"REPAIR", "Repair"}, {"BATTLEMASTER", "Battlemaster"}, {"STABLEMASTER", "Stable master"},
}

function NS.Roles(values, flags)
    local roles = {}
    if type(values[2]) == "string" and values[2] ~= "" then roles[#roles + 1] = values[2] end
    local mask = values[3]
    if type(mask) == "number" then
        for _, entry in ipairs(roleFlags) do
            local flag = flags[entry[1]]
            -- Arithmetic handles flags above the 32-bit bit library's range.
            if type(flag) == "number" and flag > 0 and math.floor(mask / flag) % 2 == 1 then
                roles[#roles + 1] = entry[2]
            end
        end
    end
    if type(values[4]) == "table" and next(values[4]) then roles[#roles + 1] = "Quest giver" end
    if type(values[5]) == "table" and next(values[5]) then roles[#roles + 1] = "Quest turn-in" end
    if values[6] == 2 or values[6] == 4 then roles[#roles + 1] = "Rare" end
    local unique, seen = {}, {}
    for _, role in ipairs(roles) do
        local key = string.lower(role)
        if not seen[key] then unique[#unique + 1], seen[key] = role, true end
    end
    return #unique > 0 and table.concat(unique, ", ") or "Purpose not recorded"
end

function NS.DecodeMap(value)
    local result = {}
    local function Add(key, mapID)
        if type(key) ~= "number" or type(mapID) ~= "number" or key < 0 or mapID < 0
            or key > 1000000000 or mapID > 1000000000 or key % 1 ~= 0 or mapID % 1 ~= 0 then return false end
        result[key] = mapID
        return true
    end
    if type(value) == "table" then
        for key, mapID in pairs(value) do if not Add(key, mapID) then return {} end end
        return result
    end
    if type(value) ~= "string" then return result end
    -- QuestieDB publishes numeric table literals, sometimes prefixed by return.
    -- Parse only that data grammar. Never execute strings supplied by a provider.
    local literal = value:gsub("%-%-[^\r\n]*", ""):gsub("^%s*return%s*", "")
    local body = literal:match("^%s*{(.-)}%s*$")
    if not body then return {} end
    local cursor = 1
    while body:find("%S", cursor) do
        local first, last, key, mapID = body:find("%s*%[%s*(%d+)%s*%]%s*=%s*(%d+)%s*[,;]?%s*", cursor)
        if first ~= cursor or not Add(tonumber(key), tonumber(mapID)) then return {} end
        cursor = last + 1
    end
    return result
end

function NS.MapName(mapID)
    NS.mapNames = NS.mapNames or {}
    if mapID and NS.mapNames[mapID] then return NS.mapNames[mapID] end
    local info = mapID and C_Map and C_Map.GetMapInfo(mapID)
    if info and info.name then NS.mapNames[mapID] = info.name end
    return info and info.name or "Unknown zone"
end

function NS.StartCatalogue()
    if NS.catalogueStarted then return end
    local db = LibQuestieDB
    if not db or type(db.RequireContract) ~= "function" then
        NS.catalogueStatus = "QuestieDB is not loaded. Enable it in the AddOns list, then /reload."
        return
    end
    local ok, supported = pcall(db.RequireContract, 4)
    if not ok or not supported or not db.Npc then
        NS.catalogueStatus = "QuestieDB needs a version supporting API contract 4."
        return
    end
    -- ModeIndicator.expansion is populated only by the SOURCE backend. Packaged
    -- (baked) releases report nil there, even with the correct Forever database.
    -- The selected flavor is shared by both backends; use the indicator only as
    -- a compatibility fallback for providers without that field.
    local expansion = db.flavor and db.flavor.expansion
    if not expansion and db.ModeIndicator and db.ModeIndicator.GetStatus then
        local statusOK, status = pcall(db.ModeIndicator.GetStatus)
        if statusOK and type(status) == "table" then expansion = status.expansion end
    end
    if not expansion then
        NS.catalogueStatus = "QuestieDB loaded, but its active database flavour could not be verified."
        return
    end
    if string.lower(tostring(expansion)) ~= "forever" then
        NS.catalogueStatus = "QuestieDB loaded " .. tostring(expansion) .. " data; install its Forever package."
        return
    end
    local setupOK, maps, ids = pcall(function()
        local zones = db.Support.Get("ZoneDB")
        local areaMaps = NS.DecodeMap(zones and zones.private and zones.private.areaIdToUiMapId)
        local npcIDs = db.Npc.GetAllIds()
        assert(type(npcIDs) == "table", "QuestieDB did not return an NPC ID list")
        return areaMaps, npcIDs
    end)
    if not setupOK then
        NS.catalogueStatus = "QuestieDB could not be read. Reopen this window to retry; see chat for details."
        NS.Print(NS.catalogueStatus .. " " .. tostring(maps))
        return
    end
    if #ids == 0 then
        NS.catalogueStatus = "QuestieDB's Forever NPC list is empty. Reopen to retry, or update QuestieDB."
        return
    end
    NS.catalogueStarted = true
    NS.areaMaps = maps
    NS.provider = db.Npc
    local count = 0
    NS.catalogueLoading = true
    NS.RunWork("catalogue", function()
            for i = 1, #ids do
                local id = ids[i]
                local v = db.Npc.GetAll(id, NS.NPCFields)
                local r = NS.NPCRecord(id, v)
                if r then
                    NS.records[id] = r
                    count = count + 1
                end
                if i % 50 == 0 then
                    NS.catalogueStatus = string.format("QuestieDB: %d / %d NPCs · loading…", i, #ids)
                    if NS.ui then NS.ui.provider:SetText(NS.SearchStatus()) end
                end
                NS.WorkYield()
            end
    end, function()
        NS.catalogueLoading = false
        NS.catalogueStatus = string.format("QuestieDB: %d NPCs · catalogue ready%s", count,
            db.readMode == "source" and " · SOURCE MODE" or "")
        if NS.Refresh and (not NS.ui or NS.ui:IsShown()) then NS.Refresh() end
    end, function(err)
            NS.catalogueLoading = false
            NS.catalogueStarted = nil
            NS.catalogueStatus = "QuestieDB import stopped. Reopen to retry; see chat for details."
            NS.Print(NS.catalogueStatus .. " " .. tostring(err))
            if NS.ui then NS.ui.provider:SetText(NS.SearchStatus()) end
    end)
end

local npcText=setmetatable({},{__mode="k"})
function NS.NPCSearchText(record)
    local cached=npcText[record]
    if not cached or cached.name~=record.name or cached.purpose~=record.purpose or cached.zone~=record.zone or cached.id~=record.id then
        cached={name=record.name,purpose=record.purpose,zone=record.zone,id=record.id,
            text=string.lower(record.name.." "..record.purpose.." "..record.zone.." "..record.id)}
        npcText[record]=cached
    end
    return cached.text
end

function NS.Find(query, context)
    query = string.lower((query or ""):match("^%s*(.-)%s*$"))
    local result, seen = {}, {}
    local origin
    if context then origin = context.origin else origin = NS.PlayerOrigin() end
    local metrics = {}
    local faction = NS.PlayerFaction()
    local function Add(record)
        local haystack = NS.NPCSearchText(record)
        if NS.FactionAllowed(record, faction) and (query == "" or haystack:find(query, 1, true)) then
            local nearest = NS.SearchNearest(record, origin, context)
            nearest.matchReason = tostring(record.id) == query and "Exact NPC ID" or (string.lower(record.name):find(query, 1, true) and "NPC name" or string.lower(record.purpose):find(query, 1, true) and "NPC service / purpose" or "Zone / recorded NPC details")
            metrics[record.id] = nearest
            if not NS.db.settings.sameZone or (origin and nearest.location and nearest.location.mapID == origin.mapID) then
                result[#result + 1] = record
            end
        end
        seen[record.id] = true
        NS.WorkYield()
    end
    for _, r in pairs(NS.records) do Add(r) end
    for id, r in pairs(NS.db.sightings) do if not seen[id] then Add(r) end end
    if context then return result, metrics, origin end
    result = NS.SortSearchResults(result, metrics)
    -- Publish as one snapshot so cancelled searches cannot corrupt visible rows.
    NS.searchResults, NS.searchOrigin = metrics, origin
    return result
end

function NS.SortSearchResults(result, metrics)
    return NS.SortResults(result, function(a, b)
        if NS.db.settings.sort == "distance" then
            local am, bm = metrics[NS.Key(a)], metrics[NS.Key(b)]
            if am.rank ~= bm.rank then return am.rank < bm.rank end
            if am.distance ~= bm.distance then return (am.distance or math.huge) < (bm.distance or math.huge) end
        end
        local aName, bName = a.displayName or a.name, b.displayName or b.name
        if aName == bName then return tostring(NS.Key(a)) < tostring(NS.Key(b)) end
        return aName < bName
    end)
end

function NS.RequestFind(query, complete, failed)
    NS.RunWork("search", function()
        local mode = NS.db.settings.searchMode
        local context = {origin = NS.PlayerOrigin()}
        local rows, metrics, origin
        if mode == "all" then rows, metrics, origin = NS.FindAll(query, context)
        elseif mode == "item" or mode == "quest" then rows, metrics, origin = NS.FindSources(query, mode, context)
        else rows, metrics, origin = NS.Find(query, context) end
        local stats
        rows, stats = NS.FilterResults(rows, metrics)
        rows = NS.SortSearchResults(rows, metrics)
        local groups = NS.MakeGroups(rows, metrics)
        NS.searchResults, NS.searchOrigin, NS.resultStats, NS.resultGroups = metrics, origin, stats, groups
        return rows
    end, complete, failed)
end

function NS.Location(record)
    if not record then return end
    local result = NS.Nearest(record, NS.PlayerOrigin())
    if result.location then return result.location, result.location.label end
end
