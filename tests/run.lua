-- Run with Lua 5.1+ from the project root, or the local Fengari runner.
unpack = unpack or table.unpack
local NS, timers, combat = {}, {}, false
local tests = 0
local runtimeRoot = ""
if loadfile("ForeverSearching/Work.lua") then runtimeRoot = "ForeverSearching/" end
local gameSettingsWrites = 0
local function forbiddenGameSettingsWrite()
    gameSettingsWrites = gameSettingsWrites + 1
    error("The addon must not change or reset global WoW settings")
end
SetCVar, SetCVarBool, ResetCVar, ResetCVars = forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite
ConsoleExec, RestartGx, SetScreenResolution, ResetChatWindows = forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite
C_CVar = setmetatable({}, {__index = function() return forbiddenGameSettingsWrite end})
C_EditMode = setmetatable({}, {__index = function() return forbiddenGameSettingsWrite end})
C_VideoOptions = setmetatable({}, {__index = function() return forbiddenGameSettingsWrite end})
C_Console = setmetatable({}, {__index = function() return forbiddenGameSettingsWrite end})
C_KeyBindings = setmetatable({}, {__index = function() return forbiddenGameSettingsWrite end})
FCF_ResetChatWindows, Sound_GameSystem_RestartSoundSystem = forbiddenGameSettingsWrite, forbiddenGameSettingsWrite
local bindingWrites = 0
local function forbiddenBindingWrite()
    bindingWrites = bindingWrites + 1
    error("The addon must never write, save, load or override keybinding profiles")
end
SetBinding, SaveBindings, LoadBindings = forbiddenBindingWrite, forbiddenBindingWrite, forbiddenBindingWrite
SetBindingClick, SetBindingMacro, SetBindingSpell, SetBindingItem = forbiddenBindingWrite, forbiddenBindingWrite, forbiddenBindingWrite, forbiddenBindingWrite
SetOverrideBinding, SetOverrideBindingClick, ClearOverrideBindings = forbiddenBindingWrite, forbiddenBindingWrite, forbiddenBindingWrite
ResetBindings, ResetToDefaultBindings, SetCurrentBindingSet = forbiddenBindingWrite, forbiddenBindingWrite, forbiddenBindingWrite
function debugprofilestop() return 0 end
local function check(value, message)
    assert(value, message)
    tests = tests + 1
end
local function drain()
    while #timers > 0 do table.remove(timers, 1)() end
end
function InCombatLockdown() return combat end
function issecretvalue(v) return type(v) == "table" and v.secret == true end
C_Timer = {After = function(_, f) timers[#timers + 1] = f end}
C_Map = {
    GetMapInfo = function(id) if id == 1453 then return {name = "Stormwind City"} end end,
    GetBestMapForUnit = function() return 1453 end,
    CanSetUserWaypointOnMap = function(id) return id == 1453 end,
    GetPlayerMapPosition = function() return {GetXY = function() return 0.51, 0.62 end} end,
}
local guid = "Creature-0-1-2-3-54-000000001"
local unitName = "Test Vendor"
function UnitGUID() return guid end
function UnitName() return unitName end
local clockTime = 100
function time() return clockTime end
function date() return "15 Nov 2026" end
SlashCmdList = {}
local eventFrame
function CreateFrame()
    eventFrame = {RegisterEvent = function() end, SetScript = function(self, _, f) self.handler = f end}
    return eventFrame
end
assert(loadfile(runtimeRoot .. "Work.lua"))("ForeverSearching", NS)
assert(loadfile(runtimeRoot .. "Data.lua"))("ForeverSearching", NS)
local parsedMap = NS.DecodeMap("return { -- map data\n [1519] = 1453, [215] = 1412; [0] = 0, }")
check(parsedMap[1519] == 1453 and parsedMap[215] == 1412 and parsedMap[0] == 0, "Parse provider numeric maps and comments without executing Lua")
check(next(NS.DecodeMap("return {[1] = SetCVar('volume', 0)}")) == nil, "Reject code embedded in provider map data")
check(next(NS.DecodeMap("SetCVar('volume', 0); return {[1] = 1453}")) == nil, "Reject executable provider map prefixes")
check(next(NS.DecodeMap("return {[1] = 1453}; SaveBindings(1)")) == nil, "Reject executable provider map suffixes")
local sourceMap = {[1519] = 1453}
local copiedMap = NS.DecodeMap(sourceMap); copiedMap[1519] = 999
check(sourceMap[1519] == 1453, "Copy provider tables instead of modifying third-party data")
assert(loadfile(runtimeRoot .. "Evidence.lua"))("ForeverSearching", NS)
assert(loadfile(runtimeRoot .. "Distance.lua"))("ForeverSearching", NS)
assert(loadfile(runtimeRoot .. "Settings.lua"))("ForeverSearching", NS)
assert(loadfile(runtimeRoot .. "ItemText.lua"))("ForeverSearching", NS)
assert(loadfile(runtimeRoot .. "Sources.lua"))("ForeverSearching", NS)
for _, file in ipairs({"Controls.lua", "Personal.lua", "Results.lua", "QuestDetails.lua", "Merchants.lua", "ToolsUI.lua", "Transmog.lua", "VendorProfiles.lua", "Links.lua", "Navigation.lua", "ShoppingRoute.lua", "TransmogUI.lua"}) do assert(loadfile(runtimeRoot .. file))("ForeverSearching", NS) end
assert(loadfile(runtimeRoot .. "Core.lua"))("ForeverSearching", NS)
eventFrame.handler(nil, "ADDON_LOADED", "ForeverSearching")
check(NS.db.marker == 8, "Default marker is skull")
check(NS.db.settings.searchMode == "all", "New settings default to All search")
check(NS.CleanName("  Test Vendor  ") == "Test Vendor", "Trim names")
for _, bad in ipairs({"", "A\n/tm 8", "A; B", "[@player]", "|Hitem:1|h", "/run bad()", string.rep("a", 101)}) do
    check(NS.TargetMacro(bad, 8) == nil, "Reject unsafe macro input: " .. bad)
end
check(NS.CleanName({secret = true}) == nil, "Do not inspect secret names")
local macro = NS.TargetMacro("Test Vendor", 8)
check(macro == "/cleartarget [nocombat]\n/targetexact [nocombat] Test Vendor\n/tm [nocombat,@target,exists] 8", "Clear previous target before exact search and mark")
check(not NS.TargetMacro("Test Vendor", 0):find("/tm", 1, true), "No marker option")
check(NS.TargetMacro("Test Vendor", 9) == nil, "Reject invalid marker")
check(NS.TargetMacro("Test Vendor", 1.5) == nil, "Reject fractional marker")
check(NS.Roles({"Test", nil, 2 ^ 35, {12}, {13}, 4}, {VENDOR = 2 ^ 35}):find("Vendor, Quest giver, Quest turn%-in, Rare"), "Roles support high flags, quest links and rare rank")

NS.Observe("target")
check(NS.db.sightings[54].x == 0.51, "Record observer position")
check(NS.db.sightings[54].purpose == "Purpose not recorded", "Do not invent roles")
NS.Observe("npc", "Vendor")
NS.Observe("npc", "Trainer")
check(NS.db.sightings[54].purpose == "Trainer, Vendor", "Accumulate observed services")
combat = true
unitName = "Changed name"
NS.Observe("target", "Flight master")
check(NS.db.sightings[54].name == "Test Vendor", "No observation in combat")
combat = false
guid = {secret = true}
NS.Observe("target")
guid = "Player-123-456"
NS.Observe("target")
check(NS.db.sightings[456] == nil, "Ignore player units")

-- Exercise the documented QuestieDB API using dot calls and packed nullable rows.
local spawns = {[1519] = {{-1, -1}, {10, 20, 2}, {40, 50}}}
LibQuestieDB = {
    RequireContract = function(v) return v == 4 end,
    -- Actual baked releases omit expansion from ModeIndicator.GetStatus().
    flavor = {expansion = "Forever", rules = "Classic"}, read = {},
    ModeIndicator = {GetStatus = function() return {mode = "baked", contractVersion = 4} end},
    Enum = {npcFlags = {VENDOR = 128}}, readMode = "baked",
    Support = {Get = function() return {private = {areaIdToUiMapId = {[1519] = 1453}}} end},
    Npc = {
        GetAllIds = function() return {54, 55, 56} end,
        GetAll = function(id)
            if id == 56 then return nil end
            return {[1] = id == 54 and "Test Vendor" or "Test Guard", [3] = id == 54 and 128 or 0, [7] = 1519, n = 7}
        end,
        Get = function(_, key) check(key == "spawns", "Request spawn field by name"); return spawns end,
    },
}
-- Optional upstream source check: pass QuestieDB's src/ui/modeIndicator.lua.
-- It is read locally for verification and is not included in NPC Search's package.
if arg and arg[1] then assert(loadfile(arg[1]))("QuestieDB", LibQuestieDB) end
check(LibQuestieDB.ModeIndicator.GetStatus().expansion == nil, "Reproduce packaged provider's missing indicator expansion")
NS.StartCatalogue()
drain()
check(NS.catalogueStarted and NS.records[54], "Load baked Forever catalogue despite nil mode-indicator expansion")
check(NS.records[54].purpose == "Vendor", "Import flags from active flavour")
check(NS.records[55].zone == "Stormwind City", "Resolve AreaID to UiMapID")
check(NS.Find("vendor")[1].id == 54, "Search purpose")
check(#NS.Find("stormwind") == 2, "Search zone and deduplicate sightings")
check(#NS.Find("55") == 1, "Search NPC ID")
check(#NS.Find("%") == 0, "Search treats patterns literally")
local loc, label = NS.Location(NS.records[54])
check(loc.x == 0.51 and label == "Last seen nearby", "Observer location labelled approximate")
loc, label = NS.Location(NS.records[55])
check(loc.x == 0.4 and loc.y == 0.5 and label == "Database spawn (may vary)", "Skip sentinel and phased spawns; normalize coordinates")
local pinned, supertracked
UiMapPoint = {CreateFromCoordinates = function(mapID, x, y) return {mapID = mapID, x = x, y = y} end}
C_Map.SetUserWaypoint = function(point) pinned = point end
C_SuperTrack = {SetSuperTrackedUserWaypoint = function(v) supertracked = v end}
NS.Pin(NS.records[55])
check(pinned.mapID == 1453 and pinned.x == 0.4 and supertracked, "Place native waypoint and enable navigation")
combat, pinned = true, nil
NS.Pin(NS.records[55])
check(pinned == nil, "No waypoint mutation in combat")
combat = false
local provider = LibQuestieDB
local function resetCatalogue()
    NS.catalogueStarted, NS.provider = nil, nil
    NS.records = {}
end
resetCatalogue()
provider.flavor.expansion = "Vanilla"
NS.StartCatalogue()
check(NS.provider == nil, "Reject wrong expansion data")
check(NS.catalogueStatus:find("Vanilla", 1, true), "Show the detected wrong flavour")
provider.flavor = nil
provider.ModeIndicator.GetStatus = function() return {mode = "source", expansion = "Forever"} end
NS.StartCatalogue()
drain()
check(NS.records[54] ~= nil, "Source-mode indicator fallback and retry after flavour rejection")
resetCatalogue()
LibQuestieDB = nil
NS.StartCatalogue()
check(not NS.catalogueStarted, "Missing provider does not latch initialization")
LibQuestieDB = provider
NS.StartCatalogue()
drain()
check(NS.records[54] ~= nil, "Retry when provider becomes available")
resetCatalogue()
provider.ModeIndicator.GetStatus = function() return {mode = "baked"} end
NS.StartCatalogue()
check(not NS.catalogueStarted and NS.provider == nil, "Unknown flavour remains unverified")
provider.flavor = {expansion = "Forever"}
NS.StartCatalogue()
drain()
check(NS.records[54] ~= nil, "Flavour descriptor verifies baked data without expansion in indicator")
resetCatalogue()
local getAllIds = provider.Npc.GetAllIds
provider.Npc.GetAllIds = function() error("provider not ready") end
local printMessage, originalPrint
originalPrint = NS.Print
NS.Print = function(message) printMessage = message end
NS.StartCatalogue()
check(not NS.catalogueStarted and printMessage:find("provider not ready", 1, true), "Report setup failure without a permanent initialization latch")
provider.Npc.GetAllIds = function() return {} end
NS.StartCatalogue()
check(not NS.catalogueStarted and NS.catalogueStatus:find("empty", 1, true), "Explain empty provider without latching")
provider.Npc.GetAllIds = getAllIds
NS.StartCatalogue()
drain()
NS.Print = originalPrint
check(NS.records[54] ~= nil and NS.catalogueStarted, "Successful retry after failed and empty setup")
check(NS.Roles({"Test", nil, 8192}, {STABLEMASTER = 8192}) == "Stable master", "Use provider's actual stable-master flag key")

-- Location provenance, migration, alternate navigation and uncertainty.
local evidence = NS.GetEvidence(NS.records[54])
check(#evidence == 4, "Keep sightings, interactions and both database spawns separate")
check(evidence[1].kind == "interaction" and evidence[1].source == "Interaction confirmed", "Prefer confirmed interaction on timestamp ties")
check(evidence[1].x == 0.51 and evidence[1].seen == 100, "Interaction evidence retains observer coordinates and time")
check(evidence[3].phase == 2 and not evidence[3].navigable, "Expose phase evidence without assuming access")
check(NS.EvidenceText(evidence[3]):find("visibility unknown", 1, true), "Explain phase uncertainty")
pinned = nil
NS.Pin(NS.records[54], evidence[3])
check(pinned == nil, "Cannot navigate to phase-tagged evidence")
NS.Pin(NS.records[54], evidence[4])
check(pinned.x == 0.4, "Navigate explicitly to database alternative despite personal sighting")
local originalSpawns = spawns
spawns = {[1519] = {{40, 50}, {40, 50}, {40, 50, 2}, {-1, -1}, {101, 50}}}
local alternatives = NS.GetEvidence(NS.records[55])
check(#alternatives == 2, "Deduplicate database coordinates but preserve different phases and reject invalid points")
spawns = originalSpawns
local legacy = {id = 99, name = "Legacy NPC", purpose = "Vendor", source = "Personal sighting", zone = "Stormwind City",
    roles = {Vendor = true}, seen = 1, mapID = 1453, x = 0.1, y = 0.2}
NS.db.sightings[99] = legacy
local legacyReports = NS.GetEvidence(legacy)
check(legacyReports[1].kind == "sighting" and legacyReports[1].detail == "Earlier sighting", "Never infer legacy interaction from service labels")
NS.SeedEvidence(legacy)
check(legacy.evidence[1].seen == 1, "Migrate legacy timestamp without refreshing it")
local history = {}
for i = 1, 10 do
    NS.RememberEvidence(history, {kind = "sighting", mapID = 1453, x = i / 100, y = 0.2, seen = i})
end
check(#history.evidence == 8 and history.evidence[1].seen == 10, "Bound saved evidence to eight recent reports")
NS.RememberEvidence(history, {kind = "sighting", mapID = 1453, x = 0.101, y = 0.2, seen = 11})
check(#history.evidence == 8 and history.evidence[1].seen == 11, "Coalesce nearby repeated sightings")
local originalGet = provider.Npc.Get
provider.Npc.Get = function() error("missing spawn column") end
local survivingReports, evidenceError = NS.GetEvidence(NS.records[54])
check(#survivingReports == 2 and evidenceError, "Preserve personal evidence when database lookup fails")
provider.Npc.Get = originalGet
local originalPosition = C_Map.GetPlayerMapPosition
local originalGUID, originalName = guid, unitName
clockTime, guid, unitName = 200000, "Creature-0-1-2-3-54-000000001", "Test Vendor"
C_Map.GetPlayerMapPosition = function() return nil end
NS.Observe("npc", "Vendor")
check(NS.db.sightings[54].evidence[1].mapID == nil, "Do not attach an old position to a new interaction")
local preserved = false
for _, report in ipairs(NS.db.sightings[54].evidence) do
    if report.seen == 100 and report.x == 0.51 then preserved = true end
end
check(preserved, "Unavailable position does not erase earlier location evidence")
local help = NS.Troubleshooting(legacy, legacyReports, legacyReports[1])
check(help:find("over a day old", 1, true) and help:find("position", 1, true), "Explain age and positional uncertainty")
check(help:find("requirements are unknown", 1, true), "Do not invent respawn or phase conditions")
local wrongMapReport = {kind = "database", mapID = 999, x = 0.4, y = 0.5, navigable = false}
help = NS.Troubleshooting(NS.records[55], {wrongMapReport}, wrongMapReport)
check(help:find("You are in Stormwind City", 1, true), "Explain different-map report")
help = NS.Troubleshooting({}, {}, nil)
check(help:find("No location evidence", 1, true), "Useful guidance when no evidence exists")
C_Map.GetPlayerMapPosition, guid, unitName, clockTime = originalPosition, originalGUID, originalName, 100
NS.db.sightings[54].evidence = {evidence[1], evidence[2]}
NS.db.sightings[99] = nil

-- Parse UI source as well; real secure frame behavior still requires the WoW client.
check(loadfile(runtimeRoot .. "UI.lua") ~= nil, "UI Lua syntax")

-- UI lifecycle smoke test. Reject protected mutations while combat is active.
local frames = {}
local methods = {}
function methods:SetScript(event, f) self.scripts[event] = f end
function methods:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text or "" end
function methods:GetScript(event) return self.scripts[event] end
function methods:SetAttribute(key, value)
    assert(not combat, "Protected attribute mutation in combat")
    self.attributes[key] = value
end
function methods:SetFrameRef(key, value)
    assert(not combat, "Secure frame references must be assigned before combat")
    self.frameRefs = self.frameRefs or {}; self.frameRefs[key] = value
end
function methods:Show() assert(not combat); self.shown = true end
function methods:Hide()
    assert(not combat); self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetShown(v) assert(not combat); self.shown = v end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function methods:CreateLine() return CreateFrame("Line", nil, self) end
function methods:SetPoint(...) self.point={...} end
function methods:SetStartPoint(_,_,x,y) self.startX,self.startY=x,y end
function methods:SetEndPoint(_,_,x,y) self.endX,self.endY=x,y end
function methods:SetRotation(value) self.rotation=value end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(value) self.level=value end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetAlpha(value) assert(not combat,"Opacity changes must not run in combat"); self.alpha=value end
function methods:GetFontString() return self.fontString end
function methods:SetPortraitToAsset(value) self.portraitAsset = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus() self.focused = false end
local objectMeta = {__index = function(_, key)
    if methods[key] then return methods[key] end
    if key:match("^[A-Z]") then return function() end end
end}
local stateDrivers = {}
function RegisterStateDriver(frame, state, condition)
    assert(not combat, "State driver registration must happen before combat")
    assert(frame.frameName == "ForeverSearchingCombatHider" and frame.frameRefs.window.frameName == "ForeverSearchingWindow"
        and state == "searchcombat" and condition == "[combat] 1; 0",
        "Only the addon window may receive the combat state driver")
    local compile = loadstring or load
    local snippet = frame.attributes["_onstate-" .. state]
    local handler = assert(compile("return function(self,newstate) " .. snippet .. " end"))()
    stateDrivers[frame] = {handler=handler,state="0"}
end
local originalEventHandler = eventFrame.handler
eventFrame.handler = function(self,event,...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        for frame,driver in pairs(stateDrivers) do
            local state = combat and "1" or "0"
            if driver.state ~= state then
                driver.state = state
                -- Simulate only Blizzard's secure frame reference. The regular
                -- Hide method above still throws if addon Lua calls it in combat.
                driver.handler({GetFrameRef=function(_,key)
                    local target=frame.frameRefs[key]
                    if not target then return nil end
                    return {Hide=function()
                        if target.shown then target.shown=false; if target.scripts.OnHide then target.scripts.OnHide(target) end end
                    end}
                end},state)
            end
        end
    end
    return originalEventHandler(self,event,...)
end
function CreateFrame(kind, name, parent, template)
    local f = setmetatable({kind = kind, frameName = name, parent = parent, template = template,
        scripts = {}, attributes = {}, shown = true}, objectMeta)
    frames[#frames + 1] = f
    if template and template:find("PortraitFrameTemplate", 1, true) then
        f.TitleContainer = {TitleText = CreateFrame("FontString", nil, f)}
        f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    elseif template and template:find("UIPanelButtonTemplate", 1, true) then
        f.fontString = CreateFrame("FontString", nil, f)
    end
    return f
end
UIParent, Minimap = {SetScale = forbiddenGameSettingsWrite, SetSize = forbiddenGameSettingsWrite, SetAlpha=forbiddenGameSettingsWrite},
    {SetScale = forbiddenGameSettingsWrite, SetSize = forbiddenGameSettingsWrite, SetAlpha=forbiddenGameSettingsWrite, Hide = forbiddenGameSettingsWrite}
assert(loadfile(runtimeRoot .. "UI.lua"))("ForeverSearching", NS)
NS.BuildUI()
check(NS.ui and not NS.ui:IsShown(), "Build dialog hidden")
check(NS.ui.title:GetText() == "Forever Searching", "Display the spaced addon title without renaming saved data")
check(NS.ui.template == "PortraitFrameTemplate,BackdropTemplate" and NS.ui.title == NS.ui.TitleContainer.TitleText,
    "Use the client's native portrait frame and title bar")
check(NS.ui.closeButton == NS.ui.CloseButton and NS.ui.closeButton.scripts.OnClick == NS.Close,
    "Reuse the native close button with our combat-safe close handler")
check(NS.ui.portraitAsset == "Interface\\Icons\\INV_Misc_Spyglass_03", "Use a spyglass portrait on the addon window")
check(NS.ui.settingsButton.template:find("UIPanelButtonTemplate",1,true) and NS.ui.target.template:find("SecureActionButtonTemplate",1,true),
    "Use native red buttons while preserving the secure targeting action")
check(NS.ui.listInset.template == "InsetFrameTemplate" and NS.ui.count.parent == NS.ui.listInset,
    "Use a native list inset with its count above the inset background")
check(NS.ui.rows[1].template == "BackdropTemplate", "Search results remain flat highlighted list rows rather than red action buttons")
check(NS.ui.combatHider.template == "SecureHandlerStateTemplate" and NS.ui.combatHider.frameRefs.window == NS.ui,
    "A separate secure controller references only our window and preserves native portrait scripts")
check(NS.ui.github:GetText() == "https://github.com/junglistloydee", "Display author GitHub URL inside addon")
NS.ui.github:SetText("edited")
check(NS.ui.github:GetText() == "https://github.com/junglistloydee", "Keep copyable GitHub link intact")
NS.Toggle()
check(NS.ui:IsShown(), "Open dialog")
check(NS.db.settings.searchMode == "all", "Opening the window defaults to All")
NS.db.settings.searchMode = "npc"
NS.RefreshSettings()
NS.ui.search:SetText("Test Vendor")
check(NS.ui.target.attributes.macrotext:find("Test Vendor", 1, true) ~= nil, "Prepare secure action from search")
NS.ui.search:SetText("A\n/run bad()")
check(NS.ui.target.attributes.type == nil and NS.ui.target.attributes.macrotext == nil, "Unsafe search removes old action")
NS.ui.search:SetText("vendor")
NS.ui.rows[1].scripts.OnClick(NS.ui.rows[1])
check(NS.selected.id == 54 and NS.ui.targetName == "Test Vendor", "Row selection prepares exact localized name")
NS.ShowInvestigation()
check(NS.ui.evidencePanel:IsShown() and #NS.ui.evidenceReports == 4, "Open evidence and troubleshooting view for selected NPC")
check(NS.ui.helpText:GetText():find("interaction confirmed", 1, true), "Explain confirmed interaction in help view")
NS.ui.evidenceNext.scripts.OnClick()
check(NS.ui.evidencePage == 2, "Page through alternate location reports")
pinned = nil
NS.ui.evidencePin.scripts.OnClick()
check(pinned and pinned.x == 0.4, "Use selected alternate report from investigation UI")
combat = true
eventFrame.handler(nil, "PLAYER_REGEN_DISABLED")
NS.Refresh()
NS.PrepareTarget()
NS.ui.rows[1].scripts.OnClick(NS.ui.rows[1])
NS.ui.evidenceBack.scripts.OnClick()
NS.RefreshEvidence()
NS.ui.evidenceNext.scripts.OnClick()
check(NS.ui.evidencePanel:IsShown() and NS.ui.evidencePage == 2, "Investigation controls pause during combat")
check(NS.ui.targetName == "Test Vendor", "Combat callbacks leave prepared action untouched")
combat = false
eventFrame.handler(nil, "PLAYER_REGEN_ENABLED")
check(not NS.ui:IsShown(), "The combat visibility driver does not reopen the window after combat")
NS.OpenSearch(); drain()
NS.ui.evidenceBack.scripts.OnClick()
check(not NS.ui.evidencePanel:IsShown(), "Return to catalogue after combat")
NS.ShowInvestigation()
NS.ui.search:SetText("Test Guard")
check(not NS.ui.evidencePanel:IsShown(), "Changing search dismisses previous NPC's evidence")
NS.Toggle()
check(not NS.ui:IsShown(), "Close after combat")

-- Nearest-first ranking uses physical map sizes and world coordinates, never
-- normalized coordinate differences between unrelated zone maps.
local savedRecords, savedSightings, savedMaps = NS.records, NS.db.sightings, NS.areaMaps
local savedMapAPI = C_Map
NS.records, NS.db.sightings = {}, {}
local function vector(x, y) return {GetXY = function() return x, y end} end
CreateVector2D = vector
local playerMap, playerX, playerY = 1453, 0.5, 0.5
C_Map = {
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return vector(playerX, playerY) end,
    GetMapInfo = function(id) return {name = "Zone " .. id} end,
    CanSetUserWaypointOnMap = function() return true end,
    GetMapWorldSize = function() return 1000, 2000 end,
    GetWorldPosFromMapPos = function(id, position)
        local x, y = position:GetXY()
        return id == 1455 and 2 or 1, vector(x * 1000 + (id == 1454 and 1000 or 0), y * 2000)
    end,
}
local function vendor(id, name, x, y, mapID)
    local r = {id = id, name = name, purpose = "Meat Vendor", zone = "Zone " .. (mapID or 1453),
        source = "Personal sighting", mapID = mapID or 1453, x = x, y = y, seen = 100}
    NS.records[id], NS.db.sightings[id] = r, r
    return r
end
vendor(201, "Zulu", 0.51, 0.5)
vendor(202, "Alpha", 0.9, 0.9)
vendor(203, "Across Border", 0, 0.5, 1454)
local multiple = vendor(204, "Several Locations", 0.9, 0.9)
multiple.evidence = {
    {kind = "sighting", mapID = 1453, x = 0.9, y = 0.9, seen = 200},
    {kind = "sighting", mapID = 1453, x = 0.8, y = 0.5, seen = 100},
    {kind = "sighting", mapID = 1453, x = 0.5, y = 0.5, seen = 99, phase = 2},
}
vendor(205, "No Position", nil, nil)
vendor(206, "Other Continent", 0.5, 0.5, 1455)
local nearestResults = NS.Find("Meat Vendor")
check(nearestResults[1].id == 201 and nearestResults[2].id == 204, "Service search lists nearest vendors before alphabetically earlier distant ones")
check(nearestResults[3].id == 203 and nearestResults[4].id == 202, "Compare locations across adjacent maps on the same continent")
check(nearestResults[5].id == 206 and nearestResults[6].id == 205, "Unmeasurable and unknown locations follow measured results")
check(math.abs(NS.searchResults[201].distance - 10) < 0.001, "Display distance in yards")
check(math.abs(NS.searchResults[202].distance - math.sqrt(800000)) < 0.001, "Respect different map width and height scales")
local nearestLocation = NS.Location(multiple)
check(nearestLocation.x == 0.8, "Default waypoint follows nearest eligible location, not newest or phase-specific report")
check(NS.ResultLocation(nearestResults[1], NS.searchResults[201]):find("51.0, 50.0", 1, true), "Result row identifies the ranked location")
check(NS.DistanceText(1234) == "~1.2k yd" and NS.DistanceText(nil) == "Unknown", "Label estimates and unavailable distances honestly")
NS.db.settings.sort = "name"
check(NS.Find("Meat Vendor")[1].name == "Across Border", "Optional name sorting")
NS.db.settings.sort, NS.db.settings.sameZone = "distance", true
check(#NS.Find("Meat Vendor") == 3, "Current-zone filter excludes other zones and positionless entries")
NS.db.settings.sameZone = false
playerX = 0.8
check(NS.Find("Meat Vendor")[1].id == 204, "Reorder when player moves")
local worldAPI = C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos = nil
local fallback = NS.PlayerOrigin()
check(NS.DistanceTo({mapID = 1453, x = 0.7, y = 0.5}, fallback) > 99, "Use same-map physical size if world conversion is unavailable")
check(NS.DistanceTo({mapID = 1454, x = 0.8, y = 0.5}, fallback) == nil, "Never compare unrelated normalized zone coordinates")
C_Map.GetWorldPosFromMapPos = worldAPI
C_Map.GetPlayerMapPosition = function() return {secret = true} end
check(NS.PlayerOrigin() == nil, "Do not inspect secret player map position")
check(NS.Find("Meat Vendor")[1].name == "Across Border", "Graceful name fallback without player position")
C_Map, NS.records, NS.db.sightings, NS.areaMaps = savedMapAPI, savedRecords, savedSightings, savedMaps
CreateVector2D = nil

-- Settings work through the visible UI, persist in SavedVariables, and pause in combat.
NS.Toggle()
NS.ui.settingsButton.scripts.OnClick()
check(NS.ui.settingsPanel:IsShown(), "Open in-addon settings")
NS.ui.settingButtons.showDistance.scripts.OnClick()
check(not NS.db.settings.showDistance and NS.ui.rows[1].distance:GetText() == "", "Distance display setting updates result rows")
NS.ui.settingButtons.minimap.scripts.OnClick()
check(not NS.db.settings.minimap and not NS.launcher:IsShown(), "Hide minimap launcher without losing slash access")
NS.ui.settingButtons.recordSightings.scripts.OnClick()
local previousSighting = NS.db.sightings[54].seen
guid, unitName, clockTime = "Creature-0-1-2-3-54-000000001", "Test Vendor", 999
NS.Observe("npc", "Vendor")
check(NS.db.sightings[54].seen == previousSighting, "Turning recording off preserves but does not update saved evidence")
combat = true
NS.ui.settingButtons.showDistance.scripts.OnClick()
NS.ui.scaleLarger.scripts.OnClick()
check(not NS.db.settings.showDistance and NS.db.settings.scale == 1, "No settings changes during combat")
combat = false
for _ = 1, 10 do NS.ui.scaleLarger.scripts.OnClick() end
check(NS.db.settings.scale == 1.2, "Clamp scale at upper limit")
NS.ui.resetSettings.scripts.OnClick()
check(NS.db.settings.showDistance and NS.db.settings.minimap and NS.db.settings.recordSightings
    and NS.db.settings.scale == 1 and NS.db.settings.sort == "distance", "Restore saved defaults")
NS.ui.settingsPanel:Hide()
local actualRefresh, refreshCalls = NS.Refresh, 0
NS.Refresh = function() refreshCalls = refreshCalls + 1 end
NS.ui.distanceOrigin = "changed"
NS.ui.scripts.OnUpdate(NS.ui, 2)
check(refreshCalls == 1, "Refresh distance order after movement")
NS.db.settings.liveRefresh = false
NS.ui.scripts.OnUpdate(NS.ui, 2)
check(refreshCalls == 1, "Allow movement refresh to be disabled")
NS.db.settings.liveRefresh, combat = true, true
NS.ui.scripts.OnUpdate(NS.ui, 2)
check(refreshCalls == 1, "No movement-driven refresh in combat")
combat, NS.Refresh, clockTime = false, actualRefresh, 100
NS.Toggle()

-- Cooperative scheduling and cancellation preserve responsiveness and snapshots.
local progress, completed = 0, false
NS.RunWork("test", function()
    for _ = 1, 500 do progress = progress + 1; NS.WorkYield() end
end, function() completed = true end)
check(progress <= 128 and not completed, "Large jobs yield before exhausting the operation budget")
drain()
check(progress == 500 and completed, "Yielded jobs finish across scheduled slices")
local obsolete, latest = false, false
NS.RunWork("test", function() for _ = 1, 1000 do NS.WorkYield() end end, function() obsolete = true end)
NS.RunWork("test", function() return "new" end, function(value) latest = value == "new" end)
drain()
check(latest and not obsolete, "Superseded searches cannot publish obsolete results")
local profileClock, workSteps, oldProfiler = 0, 0, debugprofilestop
debugprofilestop = function() profileClock = profileClock + 1; return profileClock end
NS.RunWork("test", function() for _ = 1, 10 do workSteps = workSteps + 1; NS.WorkYield() end end, function() end)
check(workSteps <= 3, "Elapsed-time budget also limits a slice")
debugprofilestop = oldProfiler
drain()
local afterCombat = false
combat = true
NS.RunWork("test", function() afterCombat = true end, function() end)
check(not afterCombat, "Background work pauses in combat")
combat = false
drain()
check(afterCombat, "Background work resumes after combat")
local resumedSteps = 0
NS.RunWork("test", function()
    for _ = 1, 500 do resumedSteps = resumedSteps + 1; NS.WorkYield() end
end, function() end)
local beforeCombat = resumedSteps
combat = true
table.remove(timers, 1)()
check(resumedSteps == beforeCombat, "An already running job also pauses between slices in combat")
combat = false
drain()
check(resumedSteps == 500, "Interrupted work resumes without losing progress")

-- Faction-aware NPC, item and quest sources, including nullable packed fields.
local originalDB, originalProvider, originalRecords = LibQuestieDB, NS.provider, NS.records
local originalItems, originalQuests, originalVendors = NS.items, NS.quests, NS.vendorItems
local playerFaction = "Horde"
function UnitFactionGroup() return playerFaction end
local npcData = {
    [701] = {name = "Horde Butcher", subName = "Meat Vendor", npcFlags = 4, zoneID = 1519, friendlyToFaction = "H"},
    [702] = {name = "Alliance Butcher", subName = "Meat Vendor", npcFlags = 4, zoneID = 1519, friendlyToFaction = "A"},
    [703] = {name = "Neutral Cook", npcFlags = 4, zoneID = 1519, friendlyToFaction = "AH"},
    [704] = {name = "Wild Boar", zoneID = 1519},
}
local itemData = {
    [1001] = {name = "Roasted Meat", vendors = {701, 702}, npcDrops = {704}, questRewards = {2001}},
    [1002] = {name = "Mysterious Token", npcDrops = {704}},
    [1003] = {name = "Unknown Item"},
}
local questData = {
    [2001] = {name = "Meat Delivery", startedBy = {{701}}, finishedBy = {{703}},
        objectives = {[1] = {{704}}, [3] = {{1002}}}, sourceItemId = 1001, requiredSourceItems = {1002}},
    [2002] = {name = "Hidden Reward"},
    [2003] = {name = "Alliance Errand", startedBy = {{702}}},
}
local function entity(data)
    return {
        GetAllIds = function() local ids = {}; for id in pairs(data) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
        Get = function(id, key) return data[id] and data[id][key] end,
        GetAll = function(id, keys)
            if not data[id] then return end
            local packed = {n = #keys}; for i, key in ipairs(keys) do packed[i] = data[id][key] end; return packed
        end,
    }
end
for _, npc in pairs(npcData) do npc.spawns = {[1519] = {{40, 50}}} end
LibQuestieDB = {Npc = entity(npcData), Item = entity(itemData), Quest = entity(questData), Enum = {npcFlags = {VENDOR = 4}}}
NS.provider, NS.records = LibQuestieDB.Npc, {}
NS.items, NS.quests, NS.vendorItems = {}, {}, {}
NS.itemReady, NS.questReady = nil, nil
for id, npc in pairs(npcData) do NS.records[id] = NS.NPCRecord(id, NS.provider.GetAll(id, NS.NPCFields)) end
check(NS.db.settings.factionOnly, "Faction filter is enabled by default after upgrade/reset")
local horde = NS.Find("Meat Vendor")
check(#horde == 1 and horde[1].id == 701, "Horde searches omit known Alliance-only NPCs")
playerFaction = "Alliance"
local alliance = NS.Find("Meat Vendor")
check(#alliance == 1 and alliance[1].id == 702, "Faction is read from the current character, not saved account-wide")
check(NS.FactionAllowed(NS.records[703], "A") and NS.FactionAllowed(NS.records[704], "A"), "Keep shared and unclassified creatures without assuming friendly reaction")
NS.db.settings.factionOnly = false
check(#NS.Find("Meat Vendor") == 2, "Unticking faction filter includes both factions")
NS.db.settings.factionOnly, playerFaction = true, "Horde"
NS.StartReference("item"); NS.StartReference("quest"); drain()
check(NS.itemReady and NS.questReady, "Load optional reference catalogues on demand")
check(NS.vendorItems[701][1001] and not NS.vendorItems[701][1002], "Build vendor inventory from item-to-vendor links")
local itemSources = NS.FindSources("Roasted Meat", "item")
check(#itemSources == 3, "Find eligible vendor, NPC drop and quest reward sources")
local sourceKinds = {}
for _, source in ipairs(itemSources) do
    sourceKinds[source.npcID] = true
    check(source.name ~= source.displayName, "Display the item but keep the actual NPC as target")
end
check(sourceKinds[701] and sourceKinds[703] and sourceKinds[704] and not sourceKinds[702], "Apply faction filter to linked item sources")
check(#NS.FindSources("1001", "item") == 3, "Search items by ID")
local questSources = NS.FindSources("Meat Delivery", "quest")
local giver, turnin, objective, required = false, false, false, false
for _, source in ipairs(questSources) do
    giver = giver or source.displayPurpose == "Quest giver · Horde Butcher"
    turnin = turnin or source.displayPurpose == "Quest turn-in · Neutral Cook"
    objective = objective or source.displayPurpose == "Quest objective NPC · Wild Boar"
    required = required or source.itemID == 1002
end
check(giver and turnin and objective and required, "Quest search connects giver, turn-in, objective NPC and required item sources")
local unknown = NS.FindSources("Unknown Item", "item")
check(#unknown == 1 and not unknown[1].npcID and unknown[1].source == "Reference", "Explain missing sources instead of inventing a vendor")
NS.db.settings.searchMode = "item"
-- Exercise the original flat-row targeting path separately from grouping below.
NS.db.settings.groupedResults = false
NS.RefreshSettings()
NS.ui:Show(); NS.ui.search:SetText("Roasted Meat"); drain()
check(#NS.ui.results == 3 and NS.ui.modeButton.label:GetText() == "Items", "Display item source results in Items mode")
local vendorRow
for i, source in ipairs(NS.ui.results) do if source.npcID == 701 then vendorRow = NS.ui.rows[i] end end
vendorRow.scripts.OnClick(vendorRow); drain()
check(NS.ui.targetName == "Horde Butcher", "Target the source NPC, never the item name")
NS.ui.vendorButton.scripts.OnClick(); drain()
check(NS.ui.vendorPanel:IsShown() and NS.ui.vendorItemCount == 1, "Show a selected vendor's known items")
NS.ui.vendorRows[1].scripts.OnClick(NS.ui.vendorRows[1]); drain()
check(NS.ui.search:GetText() == "1001" and #NS.ui.results == 3, "Vendor item selection opens its item sources")
NS.ui.factionToggle:SetChecked(false); NS.ui.factionToggle.scripts.OnClick(NS.ui.factionToggle); drain()
check(not NS.db.settings.factionOnly and #NS.ui.results == 4, "Main-window faction checkbox expands current item results to all factions")
NS.ui.factionToggle:SetChecked(true); NS.ui.factionToggle.scripts.OnClick(NS.ui.factionToggle); drain()
NS.ui.modeButton.scripts.OnClick()
NS.ui.choiceMenu.rows[4].scripts.OnClick()
NS.ui.search:SetText("Meat Delivery"); drain()
check(NS.db.settings.searchMode == "quest" and #NS.ui.results > 3, "Cycle to Quests and show NPC/item links")
NS.ui.search:SetText("Hidden Reward"); drain()
NS.ui.rows[1].scripts.OnClick(NS.ui.rows[1]); drain()
check(NS.ui.target.attributes.type == nil, "Reference-only quest rows never prepare an NPC targeting macro")
combat = true
NS.ui.factionToggle:SetChecked(false); NS.ui.factionToggle.scripts.OnClick(NS.ui.factionToggle)
check(NS.db.settings.factionOnly and NS.ui.factionToggle:GetChecked(), "Combat leaves faction filter unchanged and restores checkbox state")
combat = false
local cachedItems, tooltipReads = {[1001] = true}, {}
C_Item = {
    IsItemDataCachedByID = function(id) return cachedItems[id] == true end,
    GetItemInfoInstant = function(id) return id, id == 1001 and "Consumable" or "Miscellaneous", id == 1001 and "Food" or "Quest" end,
    GetItemInfo = function(id)
        local values = {[18] = id == 1001 and "Warm cooked meat that restores health." or "A mysterious token."}
        return unpack(values, 1, 18)
    end,
    RequestLoadItemDataByID = function() error("Search must not bulk-request uncached items") end,
}
C_TooltipInfo = {GetItemByID = function(id)
    check(cachedItems[id], "Never fetch a tooltip for an uncached item")
    tooltipReads[id] = (tooltipReads[id] or 0) + 1
    return {lines = {{leftText = id == 1001 and "|cffffffffUse: Restores 400 health over 20 sec.|r" or "Restores mana over time."},
        {leftText = {secret = true}}}}
end}
itemData[1001].relatedQuests, itemData[1001].startQuest = {2001}, 2002
NS.items[1001].loaded = false
local described = NS.FindSources("food that restores health", "item")
check(#described > 0 and described[1].itemID == 1001, "Match descriptive keywords and item types while retaining canonical item IDs")
local relatedQuest, startedQuest, seller = false, false, false
for _, result in ipairs(described) do
    seller = seller or result.displayPurpose:find("Vendor", 1, true) ~= nil
    relatedQuest = relatedQuest or result.displayPurpose:find("Related quest:", 1, true) ~= nil
    startedQuest = startedQuest or result.displayPurpose:find("Starts quest:", 1, true) ~= nil
end
check(seller and relatedQuest and startedQuest, "Description matches include vendors, related quests and item-started quests")
check(tooltipReads[1002] == nil and #NS.FindSources("restores mana", "item") == 0, "Do not claim description coverage for uncached items")
cachedItems[1002] = true
local newlyCached = NS.FindSources("restores mana", "item")
check(#newlyCached == 1 and newlyCached[1].itemID == 1002, "Pick up descriptions when the game later caches an item")
local readCount = tooltipReads[1001]
NS.FindSources("restores health", "item")
check(tooltipReads[1001] == readCount, "Reuse indexed tooltip text on later searches")
NS.db.settings.searchMode = "all"
NS.InitSettings()
check(NS.db.settings.searchMode == "all", "Persist the All mode preference")
local allResults = NS.FindAll("meat")
local kinds, keys = {}, {}
local previousRank, previousDistance = -1, -1
for _, result in ipairs(allResults) do
    kinds[result.contextType or "npc"] = true
    local key = NS.Key(result)
    check(not keys[key] and NS.searchResults[key] ~= nil, "Combined results retain unique identities and distance metrics")
    keys[key] = true
    check(result.id ~= 702 and result.npcID ~= 702, "All mode applies the faction filter across result types")
    local distance = NS.searchResults[key]
    check(distance.rank >= previousRank, "Globally sort merged result types by measurable distance")
    if distance.rank == previousRank and distance.distance then check(distance.distance >= previousDistance, "Distances remain ascending within a rank") end
    previousRank, previousDistance = distance.rank, distance.distance or -1
end
check(kinds.npc and kinds.item and kinds.quest, "One All query finds NPCs, items and quests")
local snapshot = NS.searchResults
NS.Find("meat", {origin = NS.PlayerOrigin()})
NS.FindSources("meat", "item", {origin = NS.PlayerOrigin()})
check(NS.searchResults == snapshot, "Intermediate combined-search stages do not publish partial snapshots")
local browseAll = NS.FindAll("")
local onlyNPCs = true
for _, result in ipairs(browseAll) do onlyNPCs = onlyNPCs and not result.contextType end
check(onlyNPCs, "Empty All browse does not expand every item/quest relationship")
NS.db.settings.searchMode = "quest"
NS.RefreshSettings()
NS.ui.modeButton.scripts.OnClick(); NS.ui.choiceMenu.rows[1].scripts.OnClick(); NS.ui.search:SetText("meat"); drain()
check(NS.ui.modeButton.label:GetText() == "All" and #NS.ui.results > 3, "Cycle to All and render combined results")
for _, row in ipairs(NS.ui.rows) do
    if row.record then check(row.role:GetText():match("^NPC ·") or row.role:GetText():match("^Item ·") or row.role:GetText():match("^Quest ·"), "Label result types in All mode") end
end
NS.ui.search:SetText("food that restores health"); drain()
check(NS.ui.results[1].itemID == 1001, "Description searches work through the All-mode UI")
C_Item, C_TooltipInfo = nil, nil

-- Slash-only activation. Binding mutation APIs throw throughout initialization
-- and the full UI suite; no native binding action is registered or exposed.
local printOriginal = NS.Print
NS.Print = function() end
eventFrame.handler(nil, "PLAYER_LOGIN"); drain()
eventFrame.handler(nil, "UPDATE_BINDINGS"); drain()
NS.Print = printOriginal
check(NS.InstallShortcut == nil and bindingWrites == 0, "Login and binding events never assign or save shortcuts")
check(SLASH_FOREVERSEARCHING1 == "/find" and SearchingForever_OpenSearch == nil
    and BINDING_HEADER_SEARCHINGFOREVER == nil and BINDING_NAME_SEARCHINGFOREVER_OPEN_SEARCH == nil,
    "Expose /find without any keybinding globals or callback")
NS.ui:Hide()
SlashCmdList.FOREVERSEARCHING(""); drain()
check(NS.ui:IsShown() and NS.ui.search.focused, "/find opens the search window and focuses the text box")
SlashCmdList.FOREVERSEARCHING(""); drain()
check(NS.ui:IsShown(), "Repeating /find focuses rather than closes the window")
SlashCmdList.FOREVERSEARCHING("meat"); drain()
check(NS.ui.search:GetText() == "meat" and #NS.ui.results > 3, "/find text searches across All results")
NS.ui:Hide(); combat = true
NS.Print = function() end
SlashCmdList.FOREVERSEARCHING("")
NS.Print = printOriginal
check(not NS.ui:IsShown(), "Search command respects combat restrictions")
combat = false
-- New personal tools, grouped results and source filters use only addon data.
NS.db.settings.groupedResults = true
NS.db.settings.sourceFilter, NS.db.settings.knownOnly = "all", false
NS.ui.search:SetText("Roasted Meat"); drain()
check(#NS.ui.displayRows == 1 and NS.ui.displayRows[1].isGroup, "Collapse one item into one result across all its sources")
local group = NS.ui.displayRows[1]
check(group.entityID == 1001 and group.sections.vendors and group.sections.drops and group.sections.quests,
    "Group vendors, drops and quests into labelled sections")
NS.ui.rows[1].scripts.OnClick(NS.ui.rows[1]); drain()
check(#NS.ui.displayRows > #NS.ui.results and not NS.ui.targetName, "Expanding shows section rows without preparing an ambiguous target")
local header = NS.ui.rows[2]
check(header.record.isSection, "Section headers are explanatory rows")
header.scripts.OnClick(header)
check(NS.selected == group, "Section headers cannot become target selections")
NS.ui.favourite.scripts.OnClick()
check(NS.db.favourites["item:1001"].id == 1001, "Save favourites using the matched entity ID")
NS.ui.shoppingAdd.scripts.OnClick(); NS.ui.shoppingAdd.scripts.OnClick()
check(NS.db.shopping[1001].quantity == 2 and not NS.db.shopping[1001].done, "Shopping quantities increment explicitly")
NS.ChangeShopping(1001, -100); check(NS.db.shopping[1001].quantity == 1, "Shopping quantities cannot fall below one")
NS.ChangeShopping(1001, 99999); check(NS.db.shopping[1001].quantity == 9999, "Bound shopping quantities")
NS.db.shopping[1001].done = true
NS.ShowTools("shopping"); check(NS.ui.toolsPanel:IsShown(), "Open shopping list within the addon")
local shoppingRow
for _, f in ipairs(frames) do if f.parent == NS.ui.toolsPanel and f.entry == NS.db.shopping[1001] then shoppingRow = f end end
check(shoppingRow ~= nil, "Shopping list renders saved quantities and completion")
shoppingRow.scripts.OnClick(shoppingRow)
for _, f in ipairs(frames) do
    if f.parent == NS.ui.toolsPanel and f.label and f.label:GetText() == "Done / undo" then f.scripts.OnClick() end
end
check(not NS.db.shopping[1001].done, "Shopping completion toggles only on the user's action")
NS.ShowTools("favourites"); check(NS.ui.toolsPanel:IsShown(), "Favourites panel opens")
local favouriteRow
for _, f in ipairs(frames) do if f.parent == NS.ui.toolsPanel and f.entry and f.entry.kind == "item" and f.entry.id == 1001 then favouriteRow = f end end
favouriteRow.scripts.OnClick(favouriteRow); drain()
check(NS.ui.search:GetText() == "1001" and NS.db.settings.searchMode == "item" and not NS.ui.toolsPanel:IsShown(), "Opening a favourite restores its type and exact ID")
NS.ToggleFavourite(group); check(not NS.db.favourites["item:1001"], "Remove a favourite by stable entity identity")
NS.db.recentSearches = {}
for i = 1, 25 do NS.RememberSearch("query " .. i, "all") end
check(#NS.db.recentSearches == 20 and NS.db.recentSearches[1].query == "query 25", "History is recent-first and bounded")
NS.RememberSearch(" QUERY 25 ", "all")
check(#NS.db.recentSearches == 20, "History deduplicates case and whitespace")
NS.ui.search:SetText("typing"); drain()
check(NS.db.recentSearches[1].query == "QUERY 25", "Live typing does not fill search history")
NS.ui.search.scripts.OnEnterPressed(NS.ui.search)
check(NS.db.recentSearches[1].query == "typing", "Enter commits a query to history")
NS.ShowTools("recent"); check(NS.ui.toolsPanel:IsShown(), "Recent searches panel opens")
local recentRow
for _, f in ipairs(frames) do if f.parent == NS.ui.toolsPanel and f.entry and f.entry.query == "typing" then recentRow = f end end
recentRow.scripts.OnClick(recentRow); drain()
check(NS.ui.search:GetText() == "typing" and not NS.ui.toolsPanel:IsShown(), "Recent entries rerun saved queries")
NS.db.settings.sourceFilter = "vendors"
NS.OpenSavedSearch("item", "1001"); drain()
check(#NS.ui.results == 1 and NS.SourceCategory(NS.ui.results[1]) == "vendors", "Vendor filter keeps the eligible seller only")
NS.db.settings.sourceFilter = "drops"; NS.Refresh(); drain()
check(#NS.ui.results == 1 and NS.ui.results[1].npcID == 704, "Drops filter keeps the drop source")
NS.db.settings.sourceFilter = "rewards"; NS.Refresh(); drain()
check(#NS.ui.results == 1 and NS.ui.results[1].questID == 2001, "Rewards filter keeps quest reward sources")
NS.db.settings.sourceFilter = "givers"; NS.Refresh(); drain()
check(#NS.ui.results >= 1 and NS.SourceCategory(NS.ui.results[1]) == "givers", "Giver filter finds related quest givers")
NS.db.settings.sourceFilter, NS.db.settings.knownOnly = "all", true
NS.ui.search:SetText("Unknown Item"); drain()
check(#NS.ui.results == 0 and NS.ui.empty:GetText():find("excluded", 1, true), "Known-location filter explains discarded reference-only matches")
NS.db.settings.knownOnly = false
local kept = NS.FilterResults({{id=1, purpose="Vendor, Quest giver"}}, {[1]={rank=3}})
check(#kept == 1, "All-sources filter preserves NPC roles")
NS.db.settings.sourceFilter = "givers"
check(#NS.FilterResults({{id=1, purpose="Vendor, Quest giver"}}, {[1]={rank=3}}) == 1, "NPCs with several roles match the requested service")
NS.db.settings.sourceFilter = "all"
-- A quest with item dependencies remains a single matched quest entity.
NS.OpenSavedSearch("quest", "2001"); drain()
check(#NS.ui.displayRows == 1 and NS.ui.displayRows[1].entityID == 2001, "Quest dependencies stay grouped under the searched quest")
questData[2001].requiredLevel, questData[2001].requiredClasses, questData[2001].requiredRaces = 30, 4, 2
questData[2001].preQuestSingle, questData[2001].preQuestGroup = {2002}, {-2003}
LibQuestieDB.Enum.classKeys = {HUNTER=4, WARRIOR=1, ALL=1503}
LibQuestieDB.Enum.raceMaskById = {[2]=2, [1]=1}
function UnitLevel() return 28 end
function UnitClass() return "Hunter", "HUNTER" end
function UnitRace() return "Orc", "Orc", 2 end
C_QuestLog = {IsQuestFlaggedCompleted=function(id) return id == 2002 end}
local requirementText = NS.QuestRequirements(2001)
check(requirementText:find("level too low",1,true) and requirementText:find("Your class: matches",1,true)
    and requirementText:find("Your race: matches",1,true), "Read quest level, class and race restrictions without altering them")
check(requirementText:find("completed",1,true) and requirementText:find("special condition; not evaluated",1,true)
    and requirementText:find("do not prove",1,true), "Explain prerequisite completion and unknown availability")
NS.ShowTools("requirements",2001); drain()
check(NS.ui.toolsPanel:IsShown(), "Requirements open in a scrollable addon panel")
-- Merchant visits only read stock/prices, and retain dated personal snapshots.
local oldGUID, oldName = guid, unitName
guid, unitName = "Creature-0-1-2-3-701-000000001", "Horde Butcher"
MerchantFrame = {selectedTab=1, IsShown=function() return true end}
GetMerchantNumItems = function() return 2 end
GetMerchantItemLink = function(i) return "item:" .. (i == 1 and 1001 or 9991) end
GetMerchantItemInfo = function(i) return i == 1 and "Roasted Meat" or "Observed Bread", 1, 1250, 5, i == 1 and -1 or 0, true, true, i == 2 end
BuyMerchantItem, BuybackItem, AcceptQuest, CompleteQuest, GetQuestReward = forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite, forbiddenGameSettingsWrite
eventFrame.handler(nil,"MERCHANT_SHOW"); drain()
check(NS.db.vendorStock[701] and NS.db.vendorStock[701].items[9991].extended, "Read legacy merchant API into dated snapshots including extended-cost flag")
check(NS.vendorItems[701][9991] and NS.items[9991].name == "Observed Bread", "Observed stock supplements database item listings")
local stockText = NS.StockText(701,1001)
check(stockText:find("Observed",1,true) and stockText:find("2s 50c per item",1,true) and stockText:find("unlimited",1,true), "Historical price divides bundle cost and labels unlimited stock")
check(NS.StockText(701,9991):find("sold out",1,true), "Historical zero stock is displayed as sold out")
NS.OpenSavedSearch("item","9991"); drain()
check(#NS.ui.results == 1 and NS.ui.results[1].npcID == 701, "Search an observed item absent from QuestieDB")
clockTime = clockTime + 10
C_MerchantFrame = {GetItemInfo=function() return {name="Roasted Meat", price=300, stackCount=1, numAvailable=4} end}
GetMerchantNumItems = function() return 1 end
eventFrame.handler(nil,"MERCHANT_UPDATE"); drain()
check(NS.db.vendorStock[701].items[1001].price == 300 and NS.db.vendorStock[701].seen == clockTime, "Read modern merchant info on stock update")
local snapshotStock = NS.db.vendorStock[701]
NS.db.settings.recordStock = false; eventFrame.handler(nil,"MERCHANT_UPDATE"); drain()
check(NS.db.vendorStock[701] == snapshotStock, "Disabling observations preserves the previous snapshot")
NS.db.settings.recordStock = true
GetMerchantNumItems = function() return 300 end
NS.ObserveMerchant(); eventFrame.handler(nil,"MERCHANT_CLOSED"); drain()
check(NS.db.vendorStock[701] == snapshotStock, "Closing the merchant cancels a partial snapshot")
NS.ObserveMerchant(); guid = "Creature-0-1-2-3-702-000000001"; drain()
check(NS.db.vendorStock[701] == snapshotStock, "A vendor change cannot commit mixed stock")
local previousDB, previousNPCProvider = LibQuestieDB, NS.provider
LibQuestieDB, NS.provider, NS.itemReady = nil, nil, false
NS.OpenSavedSearch("item", "9991"); drain()
check(NS.itemReady and NS.itemObservedOnly and NS.items[9991], "Saved stock indexes without an installed database")
LibQuestieDB, NS.provider = previousDB, previousNPCProvider
NS.StartReference("item"); drain()
check(NS.itemReady and not NS.itemObservedOnly, "Database availability upgrades the observations-only index without recursive refreshes")
guid = oldGUID
combat = true
local historyCount = #NS.db.recentSearches
NS.ObserveMerchant(); NS.AddShopping(group); NS.ToggleFavourite(group); NS.RememberSearch("combat"); NS.ShowTools("shopping")
check(#NS.db.recentSearches == historyCount and NS.db.vendorStock[701] == snapshotStock, "New tools and stock recording pause in combat")
combat = false
guid, unitName, MerchantFrame, C_MerchantFrame = oldGUID, oldName, nil, nil
GetMerchantNumItems, GetMerchantItemLink, GetMerchantItemInfo = nil, nil, nil
local savedShopping, savedStock = NS.db.shopping, NS.db.vendorStock
NS.ResetSettings()
check(NS.db.shopping == savedShopping and NS.db.vendorStock == savedStock and #NS.db.recentSearches > 0, "Reset defaults preserves personal tools data and touches only addon preferences")
check(NS.db.settings.groupedResults and NS.db.settings.sourceFilter == "all", "New installs default to grouped results and all sources")
check(bindingWrites == 0 and gameSettingsWrites == 0, "Every new feature avoids keybindings, game settings, purchases and quest actions")
do
    -- Regression cases found during the 0.7.1 feature/safety audit.
    NS.OpenSavedSearch("item", "1001"); drain()
    check(NS.ui.displayRows[1].matchReason == "Exact ID", "Grouped headers retain the reason that matched the entity")
    NS.db.settings.groupedResults = false; NS.Refresh(true)
    for _, row in ipairs(NS.ui.rows) do
        if row.record and row.record.npcID == 701 and NS.SourceCategory(row.record) == "vendors" then row.scripts.OnClick(row); break end
    end
    check(NS.ui.targetName == "Horde Butcher", "Select a concrete source before filtering")
    NS.db.settings.sourceFilter = "drops"; NS.Refresh(); drain()
    check(NS.selected == nil and NS.ui.targetName == nil, "Filtering out a selected source also clears its targeting action")
    NS.db.settings.sourceFilter, NS.db.settings.groupedResults = "all", true
    local oldQuestName = questData[2001].name
    questData[2001].name = "Vendor and NPC drop supplies"
    NS.quests[2001].loaded = false
    local rows = NS.FindSources("1001", "item")
    for _, row in ipairs(rows) do
        if row.questID == 2001 and row.displayPurpose:find("Turn-in",1,true) then
            check(NS.SourceCategory(row) == "other", "Quest-title keywords cannot turn a turn-in NPC into a vendor/drop source")
        elseif row.questID == 2001 and row.displayPurpose:find("Giver",1,true) then
            check(NS.SourceCategory(row) == "givers", "Quest-title keywords cannot override an explicit giver relationship")
        elseif row.questID == 2001 and row.displayPurpose:find("Quest reward:",1,true) then
            check(NS.SourceCategory(row) == "rewards", "Quest-title keywords cannot override a reward relationship")
        end
    end
    questData[2001].name = oldQuestName; NS.quests[2001].loaded = false
    local first = {id=701, contextType="item", itemID=1001, name="A", zone="Far", resultKey="far"}
    local second = {id=703, contextType="item", itemID=1001, name="A", zone="Near", resultKey="near"}
    local distances = {far={rank=0,distance=900}, near={rank=0,distance=12}}
    local groups = NS.MakeGroups({first,second}, distances)
    check(distances[NS.Key(groups[1])].distance == 12 and groups[1].zone == "Near", "Grouped previews choose the closest source even with name sorting")
    NS.RememberSearch(string.rep("long", 40), "all"); NS.RememberSearch(string.rep("long", 40), "all")
    check(NS.db.recentSearches[1].query ~= NS.db.recentSearches[2].query, "Long slash queries deduplicate after the saved length limit")
    local oldCompleted = C_QuestLog.IsQuestFlaggedCompleted
    C_QuestLog.IsQuestFlaggedCompleted = function() return nil end
    check(NS.QuestRequirements(2001):find("completion unknown",1,true), "Unavailable quest completion stays unknown instead of being called incomplete")
    C_QuestLog.IsQuestFlaggedCompleted = function() error("unavailable") end
    check(NS.QuestRequirements(2001):find("Minimum level",1,true), "A failed completion read does not discard other quest requirements")
    C_QuestLog.IsQuestFlaggedCompleted = oldCompleted
    local oldItemGetAll = LibQuestieDB.Item.GetAll
    LibQuestieDB.Item.GetAll = function(id, keys)
        if id == 9991 then return {n=#keys} end
        return oldItemGetAll(id, keys)
    end
    NS.items[9991] = {id=9991, name="Observed Bread", vendors={}}
    NS.db.vendorStock[701].items[9991] = {id=9991, name="Observed Bread", seen=time()}
    check(#NS.FindSources("9991", "item") == 1 and NS.items[9991].name == "Observed Bread",
        "A packed unknown database record cannot erase an observed item name")
    LibQuestieDB.Item.GetAll = oldItemGetAll
    local oldSighting, oldVendorRecord = NS.db.sightings[701], NS.records[701]
    NS.db.sightings[701], NS.records[701] = nil, nil
    local oldProvider = NS.provider
    NS.provider = nil
    local observedRows = NS.FindSources("9991", "item")
    check(#observedRows == 1 and observedRows[1].npcID == 701 and observedRows[1].name == "Horde Butcher",
        "Observed vendors remain identified when NPC sighting recording was disabled or expired")
    NS.provider = oldProvider
    NS.records[702] = nil
    local oldOpponent = NS.db.sightings[702]
    NS.db.sightings[702] = {id=702, name="Alliance Butcher", purpose="Vendor", zone="Unknown", source="Personal sighting"}
    observedRows = NS.FindSources("1001", "item")
    local opposing = false
    for _, row in ipairs(observedRows) do if row.npcID == 702 then opposing = true end end
    check(not opposing, "Personal sightings cannot bypass known database faction restrictions during catalogue loading")
    NS.db.sightings[701], NS.records[701], NS.db.sightings[702] = oldSighting, oldVendorRecord, oldOpponent
    local db = LibQuestieDB
    LibQuestieDB = {Quest={GetAllIds=function() error("Item mode must not read the quest catalogue") end}}
    NS.itemReady, NS.itemObservedOnly = false, nil
    NS.StartReference("item"); drain()
    check(NS.itemReady and NS.itemObservedOnly, "Missing item APIs fall back to observations rather than reading quest IDs as item IDs")
    LibQuestieDB = db
    NS.StartReference("item"); drain()
    guid, unitName = "Creature-0-1-2-3-701-000000001", "Horde Butcher"
    MerchantFrame = {selectedTab=1, IsShown=function() return true end}
    GetMerchantNumItems = function() return 300 end
    GetMerchantItemLink = function() return "item:1001" end
    GetMerchantItemInfo = function() return "Roasted Meat",1,500,1,8,true,true,false end
    local previous = NS.db.vendorStock[701]
    NS.ObserveMerchant()
    GetMerchantNumItems = function() return 0 end
    eventFrame.handler(nil,"MERCHANT_UPDATE"); drain()
    check(NS.db.vendorStock[701] == previous, "An empty merchant update cancels an older in-flight snapshot")
    GetMerchantNumItems = function() return 300 end
    NS.ObserveMerchant(); MerchantFrame.selectedTab = 2
    eventFrame.handler(nil,"MERCHANT_UPDATE"); drain()
    check(NS.db.vendorStock[701] == previous, "Changing to buyback cannot save a partial merchant listing")
    MerchantFrame.selectedTab = 1
    GetMerchantNumItems = function() return 1 end
    NS.ObserveMerchant(); drain()
    NS.ui.vendorNPCID, NS.ui.vendorPage = 701, 1
    NS.ui.vendorPanel:Show(); NS.RefreshVendor()
    local stale = false
    for _, item in ipairs(NS.ui.vendorItems) do if item.id == 9991 then stale = true end end
    check(not stale, "A replaced vendor snapshot cannot relabel vanished observed items as database listings")
    guid, unitName, MerchantFrame = oldGUID, oldName, nil
    GetMerchantNumItems, GetMerchantItemLink, GetMerchantItemInfo = nil,nil,nil
    check(bindingWrites == 0 and gameSettingsWrites == 0, "All audit regression scenarios leave game settings and binding APIs untouched")
end
LibQuestieDB, NS.provider, NS.records = originalDB, originalProvider, originalRecords
NS.items, NS.quests, NS.vendorItems = originalItems, originalQuests, originalVendors
NS.itemReady, NS.questReady, UnitFactionGroup = nil, nil, nil
NS.ResetSettings()
NS.ui:Hide()
NS.ui.search:SetText(""); drain()
NS.db.settings.searchMode = "npc"
NS.OpenSearch(); drain()
check(NS.db.settings.searchMode == "all", "Reopening resets previously saved NPC mode to All")
NS.db.settings.searchMode = "item"
NS.RefreshSettings()
SlashCmdList.FOREVERSEARCHING(""); drain()
check(NS.db.settings.searchMode == "item", "Using /find on an already-open window preserves the active mode")
NS.Close(); NS.OpenSearch(); drain()
check(NS.db.settings.searchMode == "all", "Closing and reopening restores All for the next session")
NS.ui.search:SetFocus()
NS.ui.search.scripts.OnEscapePressed(NS.ui.search)
check(not NS.ui:IsShown() and not NS.ui.search.focused, "Escape from the search box closes the window and releases focus")
NS.OpenSearch(); drain()
NS.ui.github:SetFocus()
NS.ui.github.scripts.OnEscapePressed(NS.ui.github)
check(not NS.ui:IsShown(), "Escape from the GitHub copy field also closes the window")
NS.OpenSearch(); drain()
local function escapeEntries()
    local count = 0
    for _, name in ipairs(UISpecialFrames) do if name == "ForeverSearchingWindow" then count = count + 1 end end
    return count
end
check(escapeEntries() == 1, "Register the dialog for native Escape when no edit box has focus")
combat = true
eventFrame.handler(nil, "PLAYER_REGEN_DISABLED")
check(escapeEntries() == 0, "Remove protected dialog from native Escape handling during combat")
NS.ui.search.scripts.OnEscapePressed(NS.ui.search)
check(not NS.ui:IsShown(), "The secure driver closes the protected dialog in combat; Escape does not reopen it")
combat = false
eventFrame.handler(nil, "PLAYER_REGEN_ENABLED")
NS.UpdateEscapeRegistration()
check(escapeEntries() == 1, "Restore native Escape after combat without duplicate registrations")
NS.Close()
local savedNewData, savedLegacyData = ForeverSearchingDB, NPCSearchDB
local migrated = {settings = {showDistance = false, sort = "name"}, sightings = {[999] = {name = "Earlier sighting"}}}
ForeverSearchingDB, NPCSearchDB = nil, migrated
eventFrame.handler(nil, "ADDON_LOADED", "ForeverSearching")
check(NS.db == migrated and ForeverSearchingDB == migrated, "Import a manually copied legacy addon SavedVariables table")
check(not NS.db.settings.showDistance and NS.db.sightings[999].name == "Earlier sighting", "Preserve migrated preferences and sightings")
local current = {settings = {showDistance = false, sort = "name", liveRefresh = false, factionOnly = false, fadeWhileMoving=false,
    sameZone = true, searchMode = "quest", sourceFilter = "rewards", knownOnly = true,
    groupedResults = false, recordStock = false, recordSightings = false, minimap = false, scale = 0.9},
    sightings = {}, marker = 3, favourites = {["npc:701"]={kind="npc",id=701,name="Saved vendor"}},
    shopping = {[1001]={id=1001,name="Saved item",quantity=7,done=true}},
    recentSearches = {{query="Saved search",mode="all",seen=1}}, vendorStock = {},
    transmogProfiles = {[7]={id=7,name="Previous outfit",slots={}}},transmogFavourites={[1003]=true}}
ForeverSearchingDB = current
eventFrame.handler(nil, "ADDON_LOADED", "ForeverSearching")
check(NS.db == current and NS.db ~= migrated, "Prefer current ForeverSearching data over legacy data")
eventFrame.handler(nil, "PLAYER_LOGIN"); drain()
check(not current.settings.showDistance and current.settings.sort == "name" and not current.settings.liveRefresh
    and not current.settings.factionOnly and current.settings.sameZone and current.settings.searchMode == "quest"
    and current.settings.sourceFilter == "rewards" and current.settings.knownOnly and not current.settings.groupedResults
    and not current.settings.recordStock and not current.settings.recordSightings and not current.settings.minimap
    and current.settings.scale == 0.9, "Installing and logging in preserves every valid existing addon preference")
check(current.marker == 3 and current.shopping[1001].quantity == 7 and current.shopping[1001].done
    and current.favourites["npc:701"].name == "Saved vendor" and current.recentSearches[1].query == "Saved search",
    "The display-name update preserves personal lists, history and the chosen marker")
check(current.transmogProfiles[7].name == "Previous outfit", "Addon initialization preserves existing saved transmog profiles")
check(current.transmogFavourites[1003] and not current.settings.fadeWhileMoving,"Initialization preserves appearance favourites and movement-fade preferences")
ForeverSearchingDB, NPCSearchDB, NS.db = savedNewData, savedLegacyData, savedNewData
do
    local originalCreate, previousUI, previousLauncher = CreateFrame, NS.ui, NS.launcher
    local previousShowSearch, previousShowTransmog = NS.ShowSearchPage, NS.ShowTransmogPage
    local previousRefreshTools,previousShowTools,previousPreview=NS.RefreshTools,NS.ShowTools,NS.ShowShoppingRoutePreview
    CreateFrame = function(kind, name, parent, template)
        if template and (template:find("PortraitFrameTemplate",1,true) or template == "InsetFrameTemplate") then error("Template unavailable") end
        return originalCreate(kind, name, parent, template)
    end
    NS.ui = nil
    NS.BuildUI(); drain()
check(NS.ui.template == "BasicFrameTemplateWithInset,BackdropTemplate", "A missing portrait template falls back to a native basic frame")
    check(NS.ui.listInset.template == "BackdropTemplate" and NS.ui.title:GetText() == "Forever Searching",
        "Fallback inset and title remain functional on clients missing the portrait/inset templates")
    NS.OpenSearch(); drain()
    NS.ui.closeButton.scripts.OnClick()
    check(not NS.ui:IsShown(), "The fallback native close button closes only the addon window")
    CreateFrame, NS.ui, NS.launcher = originalCreate, previousUI, previousLauncher
    NS.ShowSearchPage, NS.ShowTransmogPage = previousShowSearch, previousShowTransmog
    NS.RefreshTools,NS.ShowTools,NS.ShowShoppingRoutePreview=previousRefreshTools,previousShowTools,previousPreview
    NS.UpdateEscapeRegistration()
end
assert(loadfile(((arg and arg[0] or "tests/run.lua"):gsub("run.lua$", "transmog.lua"))))(NS,check,drain,function(value) combat=value end,function(event) eventFrame.handler(nil,event) end)
do
    local speed=7
    local oldSpeed,oldFade=GetUnitSpeed,NS.db.settings.fadeWhileMoving
    GetUnitSpeed=function() return speed end
    NS.db.settings.fadeWhileMoving=true
    NS.OpenSearch(); drain()
    check(NS.ui.alpha==0.35,"Opening the addon while walking uses translucent movement opacity")
    local oldFlying,oldTaxi=IsFlying,UnitOnTaxi
    IsFlying=function() return true end; UnitOnTaxi=function() return false end
    NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Flying at movement speed keeps the addon fully opaque")
    IsFlying=function() return false end; UnitOnTaxi=function() return true end
    NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Flight paths remain opaque even when IsFlying reports false")
    UnitOnTaxi=function() return false end; NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==0.35,"Ground movement resumes fading after landing")
    IsFlying=function() return true end
    for i=1,10 do NS.ui.scripts.OnUpdate(NS.ui,0.1) end
    check(NS.ui.alpha==1,"Taking off smoothly restores opacity without reopening the window")
    IsFlying=function() return {secret=true} end; NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Unreadable flight state keeps the window opaque")
    IsFlying=function() error("Unavailable flight state") end; NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Failed flight-state reads keep the window opaque without an error")
    IsFlying,UnitOnTaxi=oldFlying,oldTaxi
    speed=0
    for i=1,10 do NS.ui.scripts.OnUpdate(NS.ui,0.1) end
    check(NS.ui.alpha==1,"Stopping restores full opacity smoothly")
    NS.ShowTransmogPage(); drain(); speed=7
    for i=1,10 do NS.ui.scripts.OnUpdate(NS.ui,0.1) end
    check(NS.ui.alpha==0.35 and NS.ui.transmogPanel:IsShown(),"Movement fading also works on the wardrobe page")
    NS.db.settings.fadeWhileMoving=false; NS.ApplySettings()
    check(NS.ui.alpha==1,"Turning off movement fade immediately restores opacity")
    NS.db.settings.fadeWhileMoving=true; speed={secret=true}; NS.playerMoving=false; NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Unreadable speed data is skipped without treating it as movement")
    GetUnitSpeed=nil
    UnitOnTaxi=function() return true end
    eventFrame.handler(nil,"PLAYER_STARTED_MOVING"); NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Flight paths override movement-event fading when the speed API is absent")
    UnitOnTaxi=oldTaxi
    eventFrame.handler(nil,"PLAYER_STARTED_MOVING"); NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==0.35,"Native movement events support clients without GetUnitSpeed")
    eventFrame.handler(nil,"PLAYER_STOPPED_MOVING"); NS.UpdateMovementFade(0,true)
    check(NS.ui.alpha==1,"Stop events restore opacity without a speed getter")
    combat=true; eventFrame.handler(nil,"PLAYER_REGEN_DISABLED"); NS.UpdateMovementFade(1,true)
    check(not NS.ui:IsShown() and NS.ui.alpha==1,"Combat closes the window without performing protected opacity updates")
    combat=false; eventFrame.handler(nil,"PLAYER_REGEN_ENABLED")
    GetUnitSpeed,NS.db.settings.fadeWhileMoving=oldSpeed,oldFade
    NS.Close()
end
assert(loadfile(((arg and arg[0] or "tests/run.lua"):gsub("run.lua$", "links.lua"))))(NS,check,drain,function(value) combat=value end,function(event) eventFrame.handler(nil,event) end)
assert(loadfile(((arg and arg[0] or "tests/run.lua"):gsub("run.lua$", "navigation.lua"))))(NS,check,drain,function(value) combat=value end,function(event) eventFrame.handler(nil,event) end)
assert(loadfile(((arg and arg[0] or "tests/run.lua"):gsub("run.lua$", "shopping-route.lua"))))(NS,check,drain,function(value) combat=value end,function(event) eventFrame.handler(nil,event) end)
assert(loadfile(((arg and arg[0] or "tests/run.lua"):gsub("run.lua$", "search-optimizations.lua"))))(NS,check,drain)
assert(loadfile(((arg and arg[0] or "tests/run.lua"):gsub("run.lua$", "usability.lua"))))(NS,check,drain,function(value) combat=value end)
check(bindingWrites == 0, "All search, reset, combat, Escape and command paths leave binding profiles untouched")
check(gameSettingsWrites == 0, "All lifecycle, search, reset, settings and malformed-data paths leave global WoW settings untouched")
print(string.format("PASS: %d checks", tests))
