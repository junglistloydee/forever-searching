local _, NS = ...
NS.sourceFilters = {"all", "vendors", "drops", "rewards", "givers"}
NS.sourceFilterLabels = {all = "All sources", vendors = "Vendors", drops = "NPC drops", rewards = "Quest rewards", givers = "Quest givers"}

function NS.SourceCategory(record)
    if record.sourceKind then return record.sourceKind end
    local role = string.lower(record.displayPurpose or record.purpose or "")
    if role:find("npc drop", 1, true) then return "drops" end
    if role:find("quest reward", 1, true) then return "rewards" end
    if role:find("quest giver", 1, true) or role:find("· giver", 1, true) then return "givers" end
    if role:find("vendor", 1, true) then return "vendors" end
    return "other"
end

function NS.FilterResults(rows, metrics)
    local kept = {}
    local stats = {matched = #rows, sourceExcluded = 0, locationExcluded = 0}
    NS.SetWorkProgress(0,#rows,"Filtering results")
    for position, row in ipairs(rows) do
        local sourceMatches = NS.db.settings.sourceFilter == "all" or NS.SourceCategory(row) == NS.db.settings.sourceFilter
        if not row.contextType then
            local token = ({vendors = "vendor", givers = "quest giver"})[NS.db.settings.sourceFilter]
            if token then sourceMatches = string.lower(row.purpose or ""):find(token, 1, true) ~= nil end
        end
        local located = metrics[NS.Key(row)] and metrics[NS.Key(row)].location ~= nil
        if not sourceMatches then stats.sourceExcluded = stats.sourceExcluded + 1
        elseif NS.db.settings.knownOnly and not located then stats.locationExcluded = stats.locationExcluded + 1
        else kept[#kept + 1] = row end
        NS.SetWorkProgress(position,#rows)
        NS.WorkYield()
    end
    return kept, stats
end

function NS.MakeGroups(rows, metrics)
    local result, byKey = {}, {}
    NS.SetWorkProgress(0,#rows,"Grouping sources")
    for position, row in ipairs(rows) do
        local entity = NS.EntityInfo(row)
        if row.contextType and entity then
            local key = "group:" .. entity.kind .. ":" .. entity.id
            local group = byKey[key]
            if not group then
                group = {id = -entity.id, resultKey = key, name = entity.name, displayName = entity.name,
                    entityType = entity.kind, entityID = entity.id, entityName = entity.name,
                    contextType = entity.kind, itemID = entity.kind == "item" and entity.id or nil,
                    questID = entity.kind == "quest" and entity.id or nil, source = "Reference", zone = row.zone,
                    purpose = "Sources", matchReason = row.matchReason, isGroup = true, members = {}, sections = {}}
                byKey[key], result[#result + 1] = group, group
                metrics[key] = metrics[NS.Key(row)]
            end
            local candidate, current = metrics[NS.Key(row)], metrics[key]
            if candidate and (not current or candidate.rank < current.rank or candidate.rank == current.rank
                and (candidate.distance or math.huge) < (current.distance or math.huge)) then
                metrics[key], group.zone = candidate, row.zone
            end
            group.members[#group.members + 1] = row
        else result[#result + 1] = row end
        NS.SetWorkProgress(position,#rows)
        NS.WorkYield()
    end
    local labels = {vendors = "Vendors", drops = "NPC drops", quests = "Quests", other = "Other / unavailable sources"}
    NS.SetWorkStage("Preparing source sections")
    local groupKeys=NS.WorkKeys(byKey)
    NS.SetWorkProgress(0,#groupKeys,"Building source sections")
    for position, key in ipairs(groupKeys) do
        local group=byKey[key]
        for _, row in ipairs(group.members) do
            local category = NS.SourceCategory(row)
            if category == "rewards" or category == "givers" or row.questID and category == "other" then category = "quests" end
            if not labels[category] then category = "other" end
            group.sections[category] = group.sections[category] or {}
            group.sections[category][#group.sections[category] + 1] = row
            NS.WorkYield()
        end
        group.displayPurpose = #group.members .. " sources · click to expand"
        group.expandedRows = {}
        for _, category in ipairs({"vendors", "drops", "quests", "other"}) do
            local members = group.sections[category]
            if members then
                group.expandedRows[#group.expandedRows + 1] = {isSection = true, name = labels[category], displayName = labels[category] .. " (" .. #members .. ")"}
                for _, row in ipairs(members) do group.expandedRows[#group.expandedRows + 1] = row; NS.WorkYield() end
            end
        end
        NS.SetWorkProgress(position,#groupKeys)
    end
    return result
end

function NS.DisplayRows(rows)
    if not NS.db.settings.groupedResults then return rows end
    local displayed = {}
    for _, row in ipairs(NS.resultGroups or rows) do
        displayed[#displayed + 1] = row
        if row.isGroup and NS.ui.expanded and NS.ui.expanded[NS.Key(row)] then
            for _, member in ipairs(row.expandedRows) do displayed[#displayed + 1] = member end
        end
    end
    return displayed
end

function NS.EmptyReason(query)
    if NS.catalogueLoading or NS.itemLoading or NS.questLoading then return "Data is still loading. Results will refresh when it finishes." end
    if not NS.provider then return "QuestieDB is not loaded. Only personal sightings and observations can be searched." end
    local stats = NS.resultStats or {}
    if (stats.sourceExcluded or 0) + (stats.locationExcluded or 0) > 0 then
        return "Matches were excluded by the source or known-location filters. Try All sources or turn Known spots off."
    end
    if NS.db.settings.sameZone or NS.db.settings.factionOnly then
        return "No matches in the available data for these faction/zone filters. Try clearing the filters; this does not prove a source is absent."
    end
    if query == "" then return "Type a name, ID or item description." end
    return "No match in the available data. Item descriptions cover cached game data only; inspect the item and search again."
end
