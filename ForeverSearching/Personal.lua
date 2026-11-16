local _, NS = ...

function NS.InitPersonal()
    for _, key in ipairs({"favourites", "recentSearches", "shopping", "vendorStock"}) do
        if type(NS.db[key]) ~= "table" then NS.db[key] = {} end
    end
end

function NS.EntityInfo(record)
    if not record then return end
    local kind = record.entityType or record.contextType or "npc"
    local id = record.entityID or (kind == "item" and record.itemID or kind == "quest" and record.questID or record.id)
    if type(id) ~= "number" or id <= 0 then return end
    return {kind = kind, id = id, name = record.entityName or record.displayName or record.name}
end

function NS.FavouriteKey(record)
    local entity = NS.EntityInfo(record)
    return entity and (entity.kind .. ":" .. entity.id) or nil
end

function NS.ToggleFavourite(record)
    if InCombatLockdown() then return end
    local entity, key = NS.EntityInfo(record), NS.FavouriteKey(record)
    if not key then return end
    if NS.db.favourites[key] then NS.db.favourites[key] = nil; return false end
    local count = 0
    for _ in pairs(NS.db.favourites) do count = count + 1 end
    if count >= 200 then NS.SetStatus("Favourites is full. Remove an entry before adding another."); return end
    NS.db.favourites[key] = entity
    return true
end

function NS.RememberSearch(query, mode)
    if InCombatLockdown() or type(query) ~= "string" then return end
    query = query:match("^%s*(.-)%s*$"):sub(1, 100)
    if query == "" then return end
    mode = mode or NS.db.settings.searchMode
    local history = NS.db.recentSearches
    for i = #history, 1, -1 do
        if history[i].mode == mode and string.lower(history[i].query) == string.lower(query) then table.remove(history, i) end
    end
    table.insert(history, 1, {query = query:sub(1, 100), mode = mode, seen = time()})
    while #history > 20 do table.remove(history) end
end

function NS.AddShopping(record)
    if InCombatLockdown() or not record then return end
    local entity = NS.EntityInfo(record)
    local id = entity and entity.kind == "item" and entity.id or record.itemID
    if type(id) ~= "number" or id <= 0 then NS.SetStatus("Select an item to add to the shopping list."); return end
    local entry = NS.db.shopping[id]
    if not entry then
        local count = 0
        for _ in pairs(NS.db.shopping) do count = count + 1 end
        if count >= 100 then NS.SetStatus("Shopping list is full. Remove an entry before adding another."); return end
        entry = {id = id, name = NS.items[id] and NS.items[id].name or record.displayName or ("Item " .. id), quantity = 0}
        NS.db.shopping[id] = entry
    end
    entry.quantity, entry.done = math.min(9999, entry.quantity + 1), false
    NS.ShoppingListChanged()
    NS.SetStatus(string.format("Shopping list: %s × %d", entry.name, entry.quantity))
    return entry
end

function NS.ChangeShopping(id, delta)
    if InCombatLockdown() then return end
    local item = NS.db.shopping[id]
    if item then
        local quantity=math.max(1, math.min(9999, item.quantity + delta))
        if quantity~=item.quantity then item.quantity=quantity; NS.ShoppingListChanged() end
    end
end

function NS.OpenSavedSearch(mode, query)
    if InCombatLockdown() then return end
    NS.OpenSearch()
    NS.db.settings.searchMode = mode
    NS.selected, NS.ui.page = nil, 1
    NS.RefreshSettings()
    if NS.ui.toolsPanel then NS.ui.toolsPanel:Hide() end
    NS.ui.search:SetText(tostring(query))
    NS.RememberSearch(tostring(query), mode)
    NS.Refresh()
end
