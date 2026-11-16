local _, NS = ...
NS.items, NS.quests, NS.vendorItems = {}, {}, {}

local function RefreshStatus()
    if NS.ui then NS.ui.provider:SetText(NS.SearchStatus()) end
end

function NS.StartReference(kind)
    if NS[kind .. "ObservedOnly"] and NS.provider and LibQuestieDB and LibQuestieDB.Item then
        NS[kind .. "Ready"] = false
        NS[kind .. "ObservedOnly"] = nil
    end
    if NS[kind .. "Ready"] or NS[kind .. "Loading"] then return end
    local db = LibQuestieDB
    local entity = db and db[kind == "item" and "Item" or "Quest"]
    if not NS.provider or not entity then
        NS[kind .. "Status"] = "Enable the current Forever QuestieDB package to use this search."
        if kind == "item" then
            NS.itemObservedOnly = true
            NS.itemLoading = true
            NS.RunWork("itemIndex", NS.MergeObservedItems, function()
                NS.itemLoading, NS.itemReady = false, true
                if NS.ui and NS.ui:IsShown() then NS.Refresh() end
                if NS.RefreshVendor then NS.RefreshVendor() end
            end, function() NS.itemLoading = false end)
        end
        RefreshStatus(); return
    end
    NS[kind .. "Loading"] = true
    NS[kind .. "Status"] = "Loading " .. kind .. " names…"
    local itemFields = {"name", "vendors"}
    NS.RunWork(kind .. "Index", function()
        local ids = entity.GetAllIds()
        NS.SetWorkProgress(0,#ids,"Loading " .. (kind=="item" and "items" or "quests"))
        for i, id in ipairs(ids) do
            if kind == "item" then
                local values = entity.GetAll(id, itemFields)
                if values and type(values[1]) == "string" then
                    local entry = {id = id, name = values[1], vendors = values[2]}
                    NS.items[id] = entry
                    for _, npcID in ipairs(values[2] or {}) do
                        NS.vendorItems[npcID] = NS.vendorItems[npcID] or {}
                        NS.vendorItems[npcID][id] = true
                        NS.WorkYield()
                    end
                end
            else
                local name = entity.Get(id, "name")
                if type(name) == "string" then NS.quests[id] = {id = id, name = name} end
            end
            if i % 100 == 0 then
                NS[kind .. "Status"] = string.format("Loading %s catalogue: %d / %d", kind, i, #ids)
                RefreshStatus()
            end
            NS.SetWorkProgress(i,#ids)
            NS.WorkYield()
        end
        if kind == "item" then NS.MergeObservedItems() end
    end, function()
        NS[kind .. "Loading"], NS[kind .. "Ready"] = false, true
        NS[kind .. "Status"] = kind == "item" and "Items ready · cached descriptions · stock/prices not live" or "Quest catalogue ready · availability not verified"
        RefreshStatus()
        if NS.ui and NS.ui:IsShown() then NS.Refresh() end
        if NS.RefreshVendor then NS.RefreshVendor() end
    end, function(err)
        NS[kind .. "Loading"] = false
        NS[kind .. "Status"] = "Could not load " .. kind .. " data. Change search mode to retry."
        NS.Print(NS[kind .. "Status"] .. " " .. tostring(err)); RefreshStatus()
    end)
end

local function NPC(id)
    if NS.records[id] then return NS.records[id] end
    local record = NS.provider and NS.NPCRecord(id, NS.provider.GetAll(id, NS.NPCFields))
    if record then NS.records[id] = record end
    if record then return record end
    if NS.db.sightings[id] then return NS.db.sightings[id] end
    local vendor = NS.db.vendorStock[id]
    if vendor then return {id = id, name = vendor.name, purpose = "Vendor", zone = "Location unknown", source = "Personal vendor observation"} end
end

local function Item(id)
    local entry = NS.items[id]
    if entry and entry.loaded then return entry end
    local entity = LibQuestieDB and LibQuestieDB.Item
    if not entity then return entry end
    local values = entity.GetAll(id, {"name", "vendors", "npcDrops", "questRewards", "relatedQuests", "startQuest"})
    if not values or type(values[1]) ~= "string" then return entry end
    entry = entry or {id = id}
    entry.name, entry.vendors, entry.npcDrops, entry.questRewards = values[1], values[2], values[3], values[4]
    entry.relatedQuests, entry.startQuest = values[5], values[6]
    entry.loaded = true
    NS.items[id] = entry
    return entry
end

local function Quest(id)
    local entry = NS.quests[id]
    if entry and entry.loaded then return entry end
    local entity = LibQuestieDB and LibQuestieDB.Quest
    if not entity then return entry end
    local v = entity.GetAll(id, {"name", "startedBy", "finishedBy", "objectives", "sourceItemId", "requiredSourceItems"})
    if not v or type(v[1]) ~= "string" then return entry end
    entry = entry or {id = id}
    entry.name, entry.startedBy, entry.finishedBy, entry.objectives, entry.sourceItemId, entry.requiredSourceItems = v[1], v[2], v[3], v[4], v[5], v[6]
    entry.loaded = true
    NS.quests[id] = entry
    return entry
end

-- Direct item lookup for shopping routes: no catalogue scan or temporary
-- changes to the player's search mode/source filters are needed.
function NS.ShoppingVendors(itemID)
    local item=Item(itemID)
    local ids,records={},{}
    for _,id in ipairs(item and item.vendors or {}) do ids[id]=true end
    for id,vendor in pairs(NS.db.vendorStock) do
        if vendor.items and vendor.items[itemID] then ids[id]=true end
        NS.WorkYield()
    end
    local faction=NS.PlayerFaction()
    for id in pairs(ids) do
        local record=NPC(id)
        if record and NS.FactionAllowed(record,faction) then records[#records+1]=record end
        NS.WorkYield()
    end
    table.sort(records,function(a,b) return a.id<b.id end)
    return records
end

function NS.FindSources(query, kind, context)
    query = string.lower((query or ""):match("^%s*(.-)%s*$"))
    local results, metrics, added = {}, {}, {}
    local origin, faction
    if context then origin = context.origin else origin = NS.PlayerOrigin() end
    faction = NS.PlayerFaction()
    local memo=context or {}
    local words=kind=="item" and NS.PrepareItemQuery(query)
    local function ObservedVendors(itemID)
        memo.observedItems=memo.observedItems or {}
        if memo.observedItems[itemID] then return memo.observedItems[itemID] end
        memo.observedLookups=(memo.observedLookups or 0)+1
        -- Keep narrow searches cheap even with large saved merchant lists.
        -- Only broad queries pay to reverse-index all observed inventory.
        if not memo.observedVendors and memo.observedLookups<=32 then
            local found={}
            for npcID,snapshot in pairs(NS.db.vendorStock) do
                if snapshot.items and snapshot.items[itemID] then found[npcID]=true end
                NS.WorkYield()
            end
            memo.observedItems[itemID]=found
            return found
        end
        if not memo.observedVendors then
            local index={}
            for npcID,snapshot in pairs(NS.db.vendorStock) do
                for id,item in pairs(snapshot.items or {}) do
                    if item then index[id]=index[id] or {}; index[id][npcID]=true end
                    NS.WorkYield()
                end
                NS.WorkYield()
            end
            memo.observedVendors=index
        end
        return memo.observedVendors[itemID] or {}
    end
    local matchedID, matchedName, matchReason
    local function Add(npcID, title, role, itemID, questID, sourceKind)
        local npc = npcID and NPC(npcID)
        if npc and not NS.FactionAllowed(npc, faction) then return end
        local key = table.concat({kind, tostring(matchedID), tostring(itemID), tostring(questID), role, tostring(npcID)}, ":")
        if added[key] then return end
        added[key] = true
        local result = {id = npcID or -(itemID or questID or 1), npcID = npc and npcID or nil,
            name = npc and npc.name or title, purpose = npc and npc.purpose or role,
            displayName = title, displayPurpose = role .. (npc and (" · " .. npc.name) or ""),
            entityType = kind, entityID = matchedID, entityName = matchedName, matchReason = matchReason,
            contextType = kind, itemID = itemID, questID = questID, resultKey = key, sourceKind = sourceKind or "other",
            locationRecord = npc, friendlyToFaction = npc and npc.friendlyToFaction,
            zone = npc and npc.zone or "Location unknown", source = npc and npc.source or "Reference"}
        local nearest = npc and NS.SearchNearest(result, origin, memo) or {rank = 3}
        if NS.db.settings.sameZone and not (origin and nearest.location and nearest.location.mapID == origin.mapID) then return end
        results[#results + 1], metrics[key] = result, nearest
        NS.WorkYield()
    end
    local function RewardNPCs(questID, title, itemID)
        local quest = Quest(questID)
        if not quest then return end
        local npcs = quest.finishedBy and quest.finishedBy[1] or {}
        if #npcs == 0 then Add(nil, title, "Quest reward: " .. (quest.name or questID), itemID, questID, "rewards") end
        for _, npcID in ipairs(npcs) do Add(npcID, title, "Quest reward: " .. (quest.name or questID), itemID, questID, "rewards") end
    end
    local function ItemSources(itemID, questID, prefix)
        local item = Item(itemID)
        if not item or type(item.name) ~= "string" then return end
        local before = #results
        local vendors = {}
        for _, npcID in ipairs(item.vendors or {}) do vendors[npcID] = true end
        for npcID in pairs(ObservedVendors(itemID)) do vendors[npcID]=true end
        for npcID in pairs(vendors) do Add(npcID, item.name, prefix .. "Vendor", itemID, questID, "vendors") end
        for _, npcID in ipairs(item.npcDrops or {}) do Add(npcID, item.name, prefix .. "NPC drop", itemID, questID, "drops") end
        for _, rewardID in ipairs(item.questRewards or {}) do RewardNPCs(rewardID, item.name, itemID) end
        local related = {}
        for _, relatedID in ipairs(item.relatedQuests or {}) do related[relatedID] = "Related quest" end
        if item.startQuest and item.startQuest > 0 then related[item.startQuest] = "Starts quest" end
        for relatedID, relation in pairs(related) do
            local quest = Quest(relatedID)
            if quest then
                local title = relation .. ": " .. (quest.name or relatedID)
                local linked = false
                for _, npcID in ipairs(quest.startedBy and quest.startedBy[1] or {}) do
                    Add(npcID, item.name, title .. " · Giver", itemID, relatedID, "givers"); linked = true
                end
                for _, npcID in ipairs(quest.finishedBy and quest.finishedBy[1] or {}) do
                    Add(npcID, item.name, title .. " · Turn-in", itemID, relatedID); linked = true
                end
                if not linked then Add(nil, item.name, title, itemID, relatedID) end
            end
            NS.WorkYield()
        end
        if #results == before then Add(nil, item.name, "No NPC source matches the current data/filters", itemID, questID) end
    end
    if query ~= "" and NS[kind .. "Ready"] then
        NS.SetWorkStage("Preparing " .. kind .. " search")
        local entries=kind == "item" and NS.items or NS.quests
        local keys=NS.WorkKeys(entries)
        NS.SetWorkProgress(0,#keys,"Checking " .. (kind=="item" and "items" or "quests"))
        for position, id in ipairs(keys) do
            local indexed=entries[id]
            if (kind == "item" and NS.ItemMatches(indexed, query, words)) or
                (kind == "quest" and (string.lower(indexed.name or ""):find(query, 1, true) or tostring(id) == query)) then
                matchedID, matchedName = id, indexed.name
                matchReason = tostring(id) == query and "Exact ID" or (string.lower(indexed.name or ""):find(query, 1, true) and "Name" or "Cached item description / type")
                if kind == "item" then ItemSources(id, nil, "") else
                    local quest = Quest(id)
                    local before = #results
                    for _, npcID in ipairs(quest.startedBy and quest.startedBy[1] or {}) do Add(npcID, quest.name, "Quest giver", nil, id, "givers") end
                    for _, npcID in ipairs(quest.finishedBy and quest.finishedBy[1] or {}) do Add(npcID, quest.name, "Quest turn-in", nil, id) end
                    for _, objective in ipairs(quest.objectives and quest.objectives[1] or {}) do
                        Add(objective[1], quest.name, "Quest objective NPC", nil, id)
                    end
                    local required = {}
                    for _, objective in ipairs(quest.objectives and quest.objectives[3] or {}) do required[objective[1]] = "Required item · " end
                    for _, itemID in ipairs(quest.requiredSourceItems or {}) do required[itemID] = "Required item · " end
                    if quest.sourceItemId and quest.sourceItemId > 0 and not required[quest.sourceItemId] then required[quest.sourceItemId] = "Quest-provided item · " end
                    for _, itemID in ipairs(quest.startedBy and quest.startedBy[3] or {}) do required[itemID] = "Quest-starting item · " end
                    for itemID, prefix in pairs(required) do ItemSources(itemID, id, prefix) end
                    if #results == before then Add(nil, quest.name, "No NPC or item source matches the current data/filters", nil, id) end
                end
            end
            NS.SetWorkProgress(position,#keys)
            NS.WorkYield()
        end
    end
    if context then return results, metrics, origin end
    results = NS.SortSearchResults(results, metrics)
    NS.searchResults, NS.searchOrigin = metrics, origin
    return results
end

function NS.FindAll(query, deferred)
    local context = deferred or {origin = NS.PlayerOrigin()}
    local results, metrics = NS.Find(query, context)
    for _, kind in ipairs({"item", "quest"}) do
        local rows, distances = NS.FindSources(query, kind, context)
        for _, row in ipairs(rows) do
            results[#results + 1], metrics[NS.Key(row)] = row, distances[NS.Key(row)]
            NS.WorkYield()
        end
    end
    if deferred then return results, metrics, context.origin end
    results = NS.SortSearchResults(results, metrics)
    NS.searchResults, NS.searchOrigin = metrics, context.origin
    return results
end
