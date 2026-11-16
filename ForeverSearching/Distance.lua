local _, NS = ...

local function Number(value)
    return NS.Readable(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function World(point)
    if not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    local ok, continent, x, y = pcall(function()
        local id, position = C_Map.GetWorldPosFromMapPos(point.mapID, CreateVector2D(point.x, point.y))
        if not NS.Readable(id) or not NS.Readable(position) or not position then return end
        local px, py = position:GetXY()
        return id, px, py
    end)
    if ok and Number(continent) and Number(x) and Number(y) then return {id = continent, x = x, y = y} end
end
NS.WorldPosition = World

function NS.PlayerOrigin()
    local ok, origin = pcall(function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if not NS.Readable(position) or not position then return end
        local x, y = position:GetXY()
        if not Number(x) or not Number(y) then return end
        local point = {mapID = mapID, x = x, y = y}
        if not NS.ValidPosition(point) then return end
        point.world = World(point)
        if C_Map.GetMapWorldSize then
            local sizeOK, width, height = pcall(C_Map.GetMapWorldSize, mapID)
            if sizeOK and Number(width) and Number(height) and width > 0 and height > 0 then
                point.width, point.height = width, height
            end
        end
        return point
    end)
    return ok and origin or nil
end

function NS.DistanceTo(point, origin)
    if not origin or not NS.ValidPosition(point) then return end
    local world = point.world or World(point)
    local dx, dy
    if world and origin.world and world.id == origin.world.id then
        dx, dy = world.x - origin.world.x, world.y - origin.world.y
    elseif point.mapID == origin.mapID and origin.width then
        dx, dy = (point.x - origin.x) * origin.width, (point.y - origin.y) * origin.height
    end
    if dx then return math.sqrt(dx * dx + dy * dy) end
end

local function Candidates(record)
    record = record.locationRecord or record
    local points = {}
    local sighting = NS.db.sightings[record.id]
    if sighting then
        local history = sighting.evidence or {{mapID = sighting.mapID, x = sighting.x, y = sighting.y, seen = sighting.seen}}
        for _, report in ipairs(history) do
            if NS.CanNavigate(report) then
                points[#points + 1] = {mapID = report.mapID, x = report.x, y = report.y,
                    seen = report.seen, label = "Last seen nearby", kind = report.kind or "sighting"}
            end
        end
    end
    if record.source == "QuestieDB" and NS.provider then
        -- Cache only database positions on the in-memory catalogue record. Personal
        -- SavedVariables never receive this cache; new observations remain live.
        if record.searchProvider ~= NS.provider then
            record.searchProvider, record.searchPositions = NS.provider, nil
        end
        if not record.searchPositions then
            -- Sorting needs positions only, not formatted, sorted evidence reports
            -- and per-point map API checks for thousands of unrelated creatures.
            local ok, spawns = pcall(NS.provider.Get, record.id, "spawns")
            local database, seen = {}, {}
            NS.searchMapAvailability = NS.searchMapAvailability or {}
            if ok and type(spawns) == "table" then
                local areas = {}
                for area in pairs(spawns) do areas[#areas + 1] = area end
                table.sort(areas)
                for _, area in ipairs(areas) do
                    local mapID = NS.areaMaps and NS.areaMaps[area]
                    local usable = mapID and NS.searchMapAvailability[mapID]
                    if mapID and usable == nil then
                        usable = C_Map.GetMapInfo(mapID) ~= nil and C_Map.CanSetUserWaypointOnMap(mapID)
                        NS.searchMapAvailability[mapID] = not not usable
                    end
                    if usable then
                        for _, point in ipairs(spawns[area]) do
                            local report = {mapID = mapID, x = type(point[1]) == "number" and point[1] / 100 or nil,
                                y = type(point[2]) == "number" and point[2] / 100 or nil,
                                kind = "database", label = "Database spawn (may vary)"}
                            if NS.ValidPosition(report) and (point[3] == nil or point[3] == 0) then
                                local key = mapID .. ":" .. point[1] .. ":" .. point[2]
                                if not seen[key] then
                                    report.world = World(report)
                                    database[#database + 1] = report
                                    seen[key] = true
                                end
                            end
                            NS.WorkYield()
                        end
                    end
                    NS.WorkYield()
                end
            end
            if ok then record.searchPositions = database end
            for i, point in ipairs(database) do
                points[#points + 1] = point
                if i % 64 == 0 then NS.WorkYield() end
            end
        else
            for i, point in ipairs(record.searchPositions) do
                points[#points + 1] = point
                if i % 64 == 0 then NS.WorkYield() end
            end
        end
    end
    return points
end

function NS.Nearest(record, origin)
    local best, bestDistance, bestRank
    for _, point in ipairs(Candidates(record)) do
        if not NS.db.settings.sameZone or (origin and point.mapID == origin.mapID) then
            local distance = NS.DistanceTo(point, origin)
            local rank = distance and 0 or (origin and point.mapID == origin.mapID and 1 or 2)
            if not best or rank < bestRank or (rank == bestRank and distance and distance < (bestDistance or math.huge)) then
                best, bestDistance, bestRank = point, distance, rank
            end
        end
        NS.WorkYield()
    end
    return {location = best, distance = bestDistance, rank = bestRank or 3}
end

function NS.SearchNearest(record,origin,context)
    if not context then return NS.Nearest(record,origin) end
    local base=record.locationRecord or record
    if context.nearestOrigin~=origin or context.nearestZone~=NS.db.settings.sameZone or not context.nearestCache then
        context.nearestOrigin,context.nearestZone=origin,NS.db.settings.sameZone
        context.nearestCache={}
    end
    local found=context.nearestCache[base]
    if not found then found=NS.Nearest(record,origin); context.nearestCache[base]=found end
    -- Match explanations belong to individual result rows, not the memo entry.
    return {location=found.location,distance=found.distance,rank=found.rank}
end

function NS.DistanceText(distance)
    if not distance then return "Unknown" end
    if distance >= 1000 then return string.format("~%.1fk yd", distance / 1000) end
    return string.format("~%d yd", math.floor(distance + 0.5))
end

function NS.ResultLocation(record, result)
    local point = result and result.location
    if not point then return record.zone .. " · position unknown" end
    return string.format("%s · %.1f, %.1f", NS.MapName(point.mapID), point.x * 100, point.y * 100)
end
