local _, NS = ...
local function NPCID()
    local guid = UnitGUID("npc")
    if not NS.Readable(guid) or type(guid) ~= "string" then return end
    local kind, id = guid:match("^(%a+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id), guid end
end
local function Number(value)
    return NS.Readable(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

function NS.ObserveMerchant()
    -- Any new merchant update supersedes an unfinished observation, including
    -- an empty/unavailable page or a switch to buyback.
    NS.CancelWork("merchantObservation")
    -- Any new merchant update supersedes an unfinished observation, including
    -- an empty/unavailable page or a switch to buyback.
    NS.CancelWork("merchantObservation")
    if InCombatLockdown() or not NS.db.settings.recordStock or not MerchantFrame or not MerchantFrame:IsShown()
        or MerchantFrame.selectedTab == 2 then return end
    local npcID, guid = NPCID()
    if not npcID then return end
    local api = C_MerchantFrame or {}
    local countItems = api.GetNumItems or GetMerchantNumItems
    local itemLink = api.GetItemLink or GetMerchantItemLink
    if not countItems or not itemLink then return end
    local count = countItems()
    if not Number(count) or count <= 0 then return end
    local name = NS.CleanName(UnitName("npc")) or ("NPC " .. npcID)
    NS.RunWork("merchantObservation", function()
        local items = {}
        for index = 1, math.min(count, 300) do
            local currentID, currentGUID = NPCID()
            if not NS.db.settings.recordStock or not MerchantFrame:IsShown() or MerchantFrame.selectedTab == 2 or currentID ~= npcID or currentGUID ~= guid then return end
            local link = itemLink(index)
            local id = NS.Readable(link) and type(link) == "string" and tonumber(link:match("item:(%d+)"))
            local info
            if api.GetItemInfo then info = api.GetItemInfo(index)
            elseif GetMerchantItemInfo then
                local itemName, _, price, stack, available, _, _, extended = GetMerchantItemInfo(index)
                info = {name = itemName, price = price, stackCount = stack, numAvailable = available, hasExtendedCost = extended}
            end
            if id and NS.Readable(info) and type(info) == "table" and NS.Readable(info.name) and type(info.name) == "string" then
                items[id] = {id = id, name = info.name, seen = time(),
                    price = Number(info.price) and info.price or nil, stackCount = Number(info.stackCount) and info.stackCount or nil,
                    available = Number(info.numAvailable) and info.numAvailable or nil,
                    extended = NS.Readable(info.hasExtendedCost) and info.hasExtendedCost == true or false}
            end
            NS.WorkYield()
        end
        if next(items) then return {name = name, items = items, seen = time(), actor = NS.CleanName(UnitName("player")) or "Unknown character"} end
    end, function(snapshot)
        if not snapshot then return end
        NS.db.vendorStock[npcID] = snapshot
        local countVendors, oldestID, oldestTime = 0, nil, math.huge
        for id, vendor in pairs(NS.db.vendorStock) do
            countVendors = countVendors + 1
            if vendor.seen < oldestTime then oldestID, oldestTime = id, vendor.seen end
        end
        if countVendors > 200 then NS.db.vendorStock[oldestID] = nil end
        NS.RunWork("observedIndex", NS.MergeObservedItems, function()
            if NS.RefreshVendor then NS.RefreshVendor() end
            if NS.ui and NS.ui:IsShown() then NS.Refresh() end
        end)
    end, function(err) NS.Print("Could not record this vendor: " .. tostring(err)) end)
end

function NS.MergeObservedItems()
    for npcID, vendor in pairs(NS.db.vendorStock) do
        NS.vendorItems[npcID] = NS.vendorItems[npcID] or {}
        for itemID, item in pairs(vendor.items) do
            NS.vendorItems[npcID][itemID] = true
            if not NS.items[itemID] then NS.items[itemID] = {id = itemID, name = item.name, vendors = {}} end
            NS.WorkYield()
        end
    end
end

function NS.StockText(npcID, itemID)
    local vendor = NS.db.vendorStock[npcID]
    local item = vendor and vendor.items[itemID]
    if not item then return "Database listing · stock and price not observed" end
    local price = "price unknown"
    if item.price then
        local value = item.stackCount and item.stackCount > 0 and math.floor(item.price / item.stackCount + 0.5) or item.price
        price = string.format("%dg %ds %dc %s", math.floor(value / 10000), math.floor(value / 100) % 100, value % 100,
            item.stackCount and item.stackCount > 0 and "per item" or "per bundle")
    end
    local stock = item.available == -1 and "unlimited" or item.available == 0 and "sold out" or item.available and tostring(item.available) or "unknown"
    return string.format("Observed %s · %s · stock %s%s · %s", date("%d %b %H:%M", item.seen), price, stock,
        item.extended and " + other costs" or "", vendor.actor or "Unknown character")
end
