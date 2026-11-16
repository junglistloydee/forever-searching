local _, NS = ...

function NS.ValidPosition(point)
    return type(point) == "table" and type(point.mapID) == "number" and point.mapID > 0
        and type(point.x) == "number" and point.x >= 0 and point.x <= 1
        and type(point.y) == "number" and point.y >= 0 and point.y <= 1
end

function NS.CanNavigate(point)
    return NS.ValidPosition(point) and not point.phase
        and C_Map and C_Map.GetMapInfo(point.mapID) ~= nil
        and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(point.mapID)
end

function NS.SeedEvidence(sighting)
    if sighting.evidence then return end
    sighting.evidence = {}
    if sighting.seen then
        -- Previous versions did not distinguish seeing from interacting. Never
        -- upgrade their service labels into evidence of a confirmed interaction.
        sighting.evidence[1] = {kind = "sighting", detail = "Earlier sighting",
            seen = sighting.seen, mapID = sighting.mapID, x = sighting.x, y = sighting.y}
    end
end

function NS.RememberEvidence(sighting, report)
    NS.SeedEvidence(sighting)
    local history = sighting.evidence
    for i = #history, 1, -1 do
        local old = history[i]
        if old.kind == report.kind and old.mapID == report.mapID
            and ((not old.x and not report.x) or (NS.ValidPosition(old) and NS.ValidPosition(report)
                and math.abs(old.x - report.x) < 0.005 and math.abs(old.y - report.y) < 0.005)) then
            table.remove(history, i)
        end
    end
    table.insert(history, 1, report)
    while #history > 8 do table.remove(history) end
end

function NS.GetEvidence(record)
    local reports = {}
    if not record then return reports end
    local sighting = NS.db.sightings[record.id]
    if sighting then
        local history = sighting.evidence or {{kind = "sighting", detail = "Earlier sighting",
            seen = sighting.seen, mapID = sighting.mapID, x = sighting.x, y = sighting.y}}
        for _, report in ipairs(history) do
            local copy = {}
            for k, v in pairs(report) do copy[k] = v end
            copy.source = copy.kind == "interaction" and "Interaction confirmed" or "Personal sighting"
            copy.label = "Last seen nearby"
            reports[#reports + 1] = copy
        end
    end
    local providerError
    if NS.provider and record.source == "QuestieDB" then
        local ok, spawns = pcall(NS.provider.Get, record.id, "spawns")
        if not ok or (spawns ~= nil and type(spawns) ~= "table") then
            providerError = "Database locations could not be read."
        else
            local areas, seen = {}, {}
            for area in pairs(spawns or {}) do areas[#areas + 1] = area end
            table.sort(areas)
            for _, area in ipairs(areas) do
                local mapID = NS.areaMaps and NS.areaMaps[area]
                for _, point in ipairs(spawns[area]) do
                    local x, y, phase = point[1], point[2], point[3]
                    if type(x) == "number" and x >= 0 and x <= 100 and type(y) == "number" and y >= 0 and y <= 100 then
                        phase = phase ~= nil and phase ~= 0 and phase or nil
                        local key = tostring(mapID or ("area:" .. area)) .. ":" .. x .. ":" .. y .. ":" .. tostring(phase)
                        if not seen[key] then
                            reports[#reports + 1] = {kind = "database", source = "QuestieDB spawn",
                                label = "Database spawn (may vary)", mapID = mapID, areaID = area,
                                x = x / 100, y = y / 100, phase = phase}
                            seen[key] = true
                        end
                    end
                end
            end
        end
    end
    local current = C_Map.GetBestMapForUnit("player")
    table.sort(reports, function(a, b)
        -- Keep personal evidence first, most recent first. Database spawns on the
        -- current map precede other database spawns, with stable coordinate order.
        if (a.kind == "database") ~= (b.kind == "database") then return a.kind ~= "database" end
        if a.kind ~= "database" and (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
        if a.kind ~= b.kind then return a.kind == "interaction" end
        if (a.mapID == current) ~= (b.mapID == current) then return a.mapID == current end
        if (a.areaID or a.mapID or 0) ~= (b.areaID or b.mapID or 0) then return (a.areaID or a.mapID or 0) < (b.areaID or b.mapID or 0) end
        if (a.x or -1) ~= (b.x or -1) then return (a.x or -1) < (b.x or -1) end
        if (a.y or -1) ~= (b.y or -1) then return (a.y or -1) < (b.y or -1) end
        return tostring(a.phase or "") < tostring(b.phase or "")
    end)
    for _, report in ipairs(reports) do report.navigable = not not NS.CanNavigate(report) end
    return reports, providerError
end

function NS.EvidenceText(report)
    local coordinates = NS.ValidPosition(report) and string.format("%s · %.1f, %.1f",
        NS.MapName(report.mapID), report.x * 100, report.y * 100) or "Location unavailable"
    if not report.mapID and report.areaID then coordinates = "Unmapped area " .. report.areaID end
    local detail
    if report.kind == "database" then
        detail = report.phase and ("Phase " .. tostring(report.phase) .. " · visibility unknown") or "Static spawn · not live tracking"
    else
        detail = (report.seen and date("%d %b %Y, %H:%M", report.seen) or "Time unknown")
            .. " · " .. (report.detail or "Seen nearby")
    end
    return report.source .. "\n" .. coordinates .. "\n" .. detail
end

function NS.Troubleshooting(record, reports, selected, providerError)
    local lines = {}
    if providerError then lines[#lines + 1] = providerError end
    if #reports == 0 then
        lines[#lines + 1] = "No location evidence is recorded yet. Seeing or speaking to this NPC can add a report."
    elseif selected then
        local current = C_Map.GetBestMapForUnit("player")
        if selected.mapID and current and selected.mapID ~= current then
            lines[#lines + 1] = "You are in " .. NS.MapName(current) .. "; this report is in " .. NS.MapName(selected.mapID) .. "."
        end
        if selected.kind == "database" then
            lines[#lines + 1] = "This is a database spawn, not a report that the NPC is here now."
        elseif selected.kind == "interaction" then
            lines[#lines + 1] = "An interaction confirmed this NPC was present then. Coordinates mark your character's position, not the NPC's exact spot."
        else
            lines[#lines + 1] = "A sighting marks your character's position when the NPC was seen. It may be some distance from the NPC."
        end
        if selected.phase then
            lines[#lines + 1] = "This spawn has a phase tag. Your access to that phase is unknown; no waypoint will be placed."
        elseif not selected.navigable then
            lines[#lines + 1] = "This report has no usable native waypoint on this client."
        end
        if selected.seen and time() - selected.seen >= 86400 then
            lines[#lines + 1] = "This personal report is over a day old. The NPC may have moved since then."
        end
        if #reports > 1 then
            lines[#lines + 1] = "Compare the other reports on the left and try another location. Different reports do not prove a location is wrong."
        end
    end
    lines[#lines + 1] = "Check nearby doors, caves, upstairs and downstairs. No entrance or floor directions are recorded for this NPC."
    lines[#lines + 1] = "Respawn, patrol, event and quest/phase requirements are unknown. A failed target search does not prove the NPC is absent."
    return table.concat(lines, "\n\n")
end
