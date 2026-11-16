local _, NS = ...
local stopWords = {a = true, an = true, the = true, that = true, which = true,
    with = true, ["for"] = true, of = true, to = true, ["and"] = true}
local textCache=setmetatable({},{__mode="k"})

local function Text(value)
    if not NS.Readable(value) or type(value) ~= "string" then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("%s+", " ")
end

function NS.ItemSearchText(item)
    if not item.typeText then
        local types = {}
        if C_Item and C_Item.GetItemInfoInstant then
            local ok, _, itemType, subType = pcall(C_Item.GetItemInfoInstant, item.id)
            if ok then types = {Text(itemType), Text(subType)} end
        end
        local typeText = table.concat(types, " ")
        if typeText:match("%S") then item.typeText = typeText end
    end
    if not item.tooltipIndexed and C_Item and C_Item.IsItemDataCachedByID then
        local ok, cached = pcall(C_Item.IsItemDataCachedByID, item.id)
        if ok and NS.Readable(cached) and cached then
            local lines = {}
            local readOK = pcall(function()
                if C_Item.GetItemInfo then
                    local info = {C_Item.GetItemInfo(item.id)}
                    lines[#lines + 1] = Text(info[18]) -- modern itemDescription, if provided
                end
                if C_TooltipInfo and C_TooltipInfo.GetItemByID then
                    local tip = C_TooltipInfo.GetItemByID(item.id)
                    if NS.Readable(tip) and type(tip) == "table" and NS.Readable(tip.lines) then
                        for _, line in ipairs(tip.lines or {}) do
                            if NS.Readable(line) and type(line) == "table" then
                                lines[#lines + 1] = Text(line.leftText)
                                lines[#lines + 1] = Text(line.rightText)
                            end
                        end
                    end
                end
            end)
            if readOK then
                item.tooltipText = table.concat(lines, " ")
                item.tooltipIndexed = item.tooltipText:match("%S") ~= nil
            end
        end
    end
    local cached=textCache[item]
    if not cached or cached.name~=item.name or cached.kind~=item.typeText or cached.tip~=item.tooltipText then
        cached={name=item.name,kind=item.typeText,tip=item.tooltipText,
            text=string.lower(Text(item.name).." "..(item.typeText or "").." "..(item.tooltipText or ""))}
        textCache[item]=cached
    end
    return cached.text
end

function NS.PrepareItemQuery(query)
    local words={}
    for word in query:gmatch("%S+") do if not stopWords[word] then words[#words+1]=word end end
    return words
end

function NS.ItemMatches(item, query, words)
    if tostring(item.id) == query then return true end
    -- A literal name match needs no tooltip/type calls. Description queries
    -- still inspect cached game data and can discover newly cached items.
    if string.lower(Text(item.name)):find(query,1,true) then return true end
    local text = NS.ItemSearchText(item)
    if text:find(query, 1, true) then return true end
    local count = 0
    for _,word in ipairs(words or NS.PrepareItemQuery(query)) do
            if not text:find(word, 1, true) then return false end
            count = count + 1
    end
    return count > 0
end
