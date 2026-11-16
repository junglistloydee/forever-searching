-- Synthetic operation/scheduling benchmark; not an in-game FPS measurement.
-- Optional argument: directory containing an earlier version's Lua modules.
unpack = unpack or table.unpack
local NS, queue, elapsed = {}, {}, 0
local counters = {maps = 0, waypoints = 0, spawns = 0, rows = 0, worlds = 0}
local function cost(key, ms) counters[key] = counters[key] + 1; elapsed = elapsed + ms end
function debugprofilestop() return elapsed end
function InCombatLockdown() return false end
C_Timer = {After = function(_, callback) queue[#queue + 1] = callback end}
local function vector(x, y) return {GetXY = function() return x, y end} end
CreateVector2D = vector
C_Map = {
    GetMapInfo = function() cost("maps", 0.01); return {name = "Benchmark Zone"} end,
    CanSetUserWaypointOnMap = function() cost("waypoints", 0.01); return true end,
    GetBestMapForUnit = function() return 1 end,
    GetPlayerMapPosition = function() return vector(0.5, 0.5) end,
    GetWorldPosFromMapPos = function(_, point)
        cost("worlds", 0.005)
        local x, y = point:GetXY(); return 1, vector(x * 1000, y * 1000)
    end,
}
local defaultRoot = ""
if loadfile("ForeverSearching/Work.lua") then defaultRoot = "ForeverSearching/" end
local currentRelease = arg[1] == nil
local root = arg[1] and (arg[1] .. "/") or defaultRoot
if currentRelease then assert(loadfile(root .. "Work.lua"))("ForeverSearching", NS) end
for _, file in ipairs({"Data.lua", "Evidence.lua", "Distance.lua", "Settings.lua"}) do
    assert(loadfile(root .. file))("ForeverSearching", NS)
end
if currentRelease then
    assert(loadfile(root .. "ItemText.lua"))("ForeverSearching", NS)
    assert(loadfile(root .. "Sources.lua"))("ForeverSearching", NS)
end
if currentRelease then
    for _, file in ipairs({"Personal.lua", "Results.lua"}) do assert(loadfile(root .. file))("ForeverSearching", NS) end
end
NS.db = {sightings = {}}
NS.InitSettings()
NS.Print = function(message) error(message) end
local ids, spawns = {}, {[1] = {}}
for id = 1, 3000 do ids[id] = id end
for i = 1, 12 do spawns[1][i] = {i * 7, i * 6} end
LibQuestieDB = {
    RequireContract = function() return true end, flavor = {expansion = "Forever"}, readMode = "baked",
    Enum = {npcFlags = {}}, ModeIndicator = {GetStatus = function() return {} end},
    Support = {Get = function() return {private = {areaIdToUiMapId = {[1] = 1}}} end},
    Npc = {
        GetAllIds = function() return ids end,
        GetAll = function(id) cost("rows", 0.1); return {[1] = "NPC " .. id, [7] = 1} end,
        Get = function() cost("spawns", 0.1); return spawns end,
    },
}
local results, refreshes = nil, 0
NS.Refresh = function()
    refreshes = refreshes + 1
    if NS.RequestFind then NS.RequestFind("", function(found) results = found end)
    else results = NS.Find("") end
end
local maxSlice, slices = 0, 0
local function run(callback)
    local before = elapsed
    callback()
    maxSlice, slices = math.max(maxSlice, elapsed - before), slices + 1
end
run(NS.StartCatalogue)
while #queue > 0 do run(table.remove(queue, 1)) end
assert(results and #results == 3000, "All NPCs must remain searchable")
print(string.format("%s: rows=%d, spawn reads=%d, map checks=%d, waypoint checks=%d, ranking passes=%d, slices=%d, max simulated slice=%.2fms",
    currentRelease and "Optimized" or "Baseline", counters.rows, counters.spawns, counters.maps,
    counters.waypoints, refreshes, slices, maxSlice))
if currentRelease then
    assert(refreshes == 1, "Do not repeatedly rank incomplete catalogue imports")
    assert(maxSlice < 4, "Synthetic provider workload must yield inside the frame budget")
    assert(counters.maps < 10 and counters.waypoints < 10, "Cache map capability queries across NPCs")
    local published, obsolete, latest = NS.searchResults, false, nil
    NS.RequestFind("NPC 2", function() obsolete = true end)
    assert(NS.searchResults == published, "Incomplete work must not replace the published snapshot")
    NS.RequestFind("NPC 30", function(found) latest = found end)
    while #queue > 0 do run(table.remove(queue, 1)) end
    assert(not obsolete and latest and #latest == 12, "Only the latest complete query can be published")
    for _, npc in ipairs(latest) do assert(npc.name:find("NPC 30", 1, true), "No stale result rows") end
    print("PASS: large-query cancellation and atomic result publication")
end
