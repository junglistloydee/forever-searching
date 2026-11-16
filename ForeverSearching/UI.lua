local _, NS = ...
local gold = {1, 0.82, 0}
local muted = {0.70, 0.70, 0.70}
local pageSize = 6
function NS.InstallSearchLinkHook()
    if NS.searchLinkHookInstalled or type(hooksecurefunc) ~= "function" then return end
    local function InsertItemLink(link)
        local ui = NS.ui
        if InCombatLockdown() or not ui or not ui:IsShown() or not ui.search:HasFocus()
            or (ui.transmogPanel and ui.transmogPanel:IsShown())
            or type(IsShiftKeyDown) ~= "function" or not IsShiftKeyDown() or type(link) ~= "string" then return end
        local id = tonumber(link:match("|Hitem:(%d+)[:|]") or link:match("^item:(%d+)[:|]") or link:match("^item:(%d+)$"))
        if not id or id <= 0 then return end
        NS.db.settings.searchMode = "item"
        NS.RefreshSettings()
        ui.search:SetText(tostring(id))
        ui.search:HighlightText()
        NS.SetStatus("Searching linked item ID " .. id .. ".")
    end
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        hooksecurefunc(ChatFrameUtil, "InsertLink", InsertItemLink)
    elseif type(ChatEdit_InsertLink) == "function" then
        hooksecurefunc("ChatEdit_InsertLink", InsertItemLink)
    else return end
    NS.searchLinkHookInstalled = true
end
local function OriginKey(origin)
    return origin and string.format("%d:%.4f:%.4f", origin.mapID, origin.x, origin.y) or "unknown"
end
local markerNames = {[0] = "No marker", "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull"}

local function Text(parent, text, font, x, y, width, color)
    local f = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    f:SetPoint("TOPLEFT", x, y)
    if width then f:SetWidth(width) end
    f:SetJustifyH("LEFT")
    f:SetText(text)
    if color then f:SetTextColor(unpack(color)) end
    return f
end

local function Panel(frame)
    frame:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 32,
        edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
    frame:SetBackdropColor(0.035, 0.035, 0.035, 0.98)
    frame:SetBackdropBorderColor(0.42, 0.42, 0.42, 1)
end

local function Button(parent, text, width, height, template)
    local row = template == "row"
    local templates = row and "BackdropTemplate" or "UIPanelButtonTemplate,BackdropTemplate"
    if template and not row then templates = templates .. "," .. template end
    local b = CreateFrame("Button", nil, parent, templates)
    b:SetSize(width, height or 30)
    if row then
        b:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
        b:SetBackdropColor(0.10, 0.10, 0.10, 0.55)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    end
    local t = not row and b:GetFontString() or nil
    if not t then
        t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER")
    end
    t:SetWidth(math.max(1, width - 14))
    t:SetMaxLines(1)
    t:SetText(text)
    t:SetTextColor(unpack(gold))
    b.label = t
    return b
end

local function Inset(parent, x, y, width, height)
    local ok, frame = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if not ok or not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        Panel(frame)
    end
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    return frame
end

function NS.PrepareTarget()
    local ui = NS.ui
    if not ui or InCombatLockdown() then return end
    local name = NS.selected and NS.selected.name or ui.search:GetText()
    if (NS.selected and NS.selected.contextType and not NS.selected.npcID)
        or (not NS.selected and NS.db.settings.searchMode ~= "npc") then name = nil end
    local macro = NS.TargetMacro(name, NS.db.marker)
    ui.target:SetAttribute("type", macro and "macro" or nil)
    ui.target:SetAttribute("macrotext", macro)
    ui.target:SetAlpha(macro and 1 or 0.4)
    ui.targetName = macro and NS.CleanName(name) or nil
end

local function UpdateDetails()
    local ui, r = NS.ui, NS.selected
    local actionable=r~=nil and not r.isSection
    local located=actionable and not r.isGroup and NS.searchResults[NS.Key(r)] and NS.searchResults[NS.Key(r)].location~=nil
    ui.favourite:SetShown(actionable)
    ui.wowheadButton:SetShown(actionable)
    ui.investigate:SetShown(not not located)
    ui.navigate:SetShown(not not located)
    ui.marker:SetShown(actionable and (not r.contextType or r.npcID~=nil))
    ui.target:SetShown((actionable and (not r.contextType or r.npcID~=nil)) or (not r and NS.db.settings.searchMode=="npc" and ui.search:GetText()~=""))
    if not r then
        ui.detailName:SetText("Find something in Azeroth")
        ui.detailRole:SetText("Choose All, NPCs, Items or Quests beside the search box.")
        ui.detailMeta:SetText("Browse by name, service, zone, or NPC ID.\n\nNo QuestieDB? NPCs you target, mouse over, or see on nameplates are remembered here.")
        ui.detailLocation:SetText("Select an NPC to view its recorded location.")
    else
        ui.detailName:SetText(r.displayName or r.name)
        ui.detailRole:SetText(r.displayPurpose or r.purpose)
        local sighting = NS.db.sightings[r.id]
        local nearest = NS.searchResults[NS.Key(r)] or NS.Nearest(r, NS.PlayerOrigin())
        local zone = nearest.location and NS.MapName(nearest.location.mapID) or r.zone
        local distance = NS.db.settings.showDistance and ("\nDistance  " .. NS.DistanceText(nearest.distance)) or ""
        local ids = r.contextType and ((r.npcID and ("NPC ID  " .. r.npcID .. "\n") or "")
            .. (r.itemID and ("Item ID  " .. r.itemID .. "\n") or "") .. (r.questID and ("Quest ID  " .. r.questID .. "\n") or "")) or ("NPC ID  " .. r.id .. "\n")
        ui.detailMeta:SetText(ids .. "Zone  " .. zone .. distance
            .. (sighting and ("\nLast seen  " .. date("%d %b %Y, %H:%M", sighting.seen)) or ""))
        local ok, location, label = pcall(NS.Location, r)
        local reports = NS.GetEvidence(r)
        ui.detailLocation:SetText(r.isGroup and "Expand this result and select a source to target or navigate." or ok and location and string.format("%s · %.1f, %.1f\n%d evidence reports · compare below",
            NS.MapName(location.mapID), location.x * 100, location.y * 100, #reports) or
            string.format("No usable waypoint · %d evidence reports", #reports))
    end
    if ui.detailReason then
        local metric = r and NS.searchResults[NS.Key(r)]
        ui.detailReason:SetText(r and ("Matched: " .. (r.matchReason or metric and metric.matchReason or "Linked sources")) or "")
        ui.favourite.label:SetText(r and NS.db.favourites[NS.FavouriteKey(r)] and "Unfavourite" or "Favourite")
        ui.requirements:SetShown(r ~= nil and r.questID ~= nil)
        ui.shoppingAdd:SetShown(r ~= nil and r.itemID ~= nil)
    end
    if ui.vendorButton then
        local npc = r and (r.locationRecord or r)
        local vendor = npc and (string.lower(npc.purpose or ""):find("vendor", 1, true) or NS.vendorItems[npc.id] ~= nil)
        ui.vendorButton:SetShown(not not vendor and (not r.contextType or r.npcID ~= nil))
    end
    NS.PrepareTarget()
end

local function RenderSearch(results)
    local ui = NS.ui
    if not ui or InCombatLockdown() then return end
    ui.results = results
    -- A new filter or provider update must not leave an invisible source targeted.
    if NS.selected then
        local key, replacement = NS.Key(NS.selected), nil
        for _, row in ipairs(NS.selected.isGroup and (NS.resultGroups or results) or results) do
            if NS.Key(row) == key then replacement = row; break end
        end
        NS.selected = replacement
    end
    ui.displayRows = NS.DisplayRows(results)
    ui.distanceOrigin = OriginKey(NS.searchOrigin)
    local pages = math.max(1, math.ceil(#(ui.displayRows or ui.results) / pageSize))
    ui.page = math.min(ui.page or 1, pages)
    ui.pageLabel:SetText(string.format("%d / %d", ui.page, pages))
    ui.count:SetText(string.format("%d matches · %s%s", NS.db.settings.groupedResults and #(NS.resultGroups or ui.results) or #ui.results,
        NS.db.settings.sort == "distance" and "nearest first" or "name order", NS.db.settings.sameZone and " · this zone" or ""))
    if ui.quickSort then
        ui.count:SetText((NS.db.settings.groupedResults and #(NS.resultGroups or ui.results) or #ui.results).." matches")
        ui.quickSort.label:SetText("Sort: "..(NS.db.settings.sort=="distance" and "Nearest" or "Name"))
    end
    ui.provider:SetText("Ready · "..#ui.results.." results · hover for data status")
    local mode = NS.db.settings.searchMode
    ui.empty:SetText(#ui.results == 0 and NS.EmptyReason(ui.search:GetText()) or "")
    for i, row in ipairs(ui.rows) do
        local r = ui.displayRows[(ui.page - 1) * pageSize + i]
        row.record = r
        row:SetShown(r ~= nil)
        if r then
            row.name:SetText((r.isGroup and (ui.expanded and ui.expanded[NS.Key(r)] and "− " or "+ ") or "") .. (r.displayName or r.name))
            local prefix = mode == "all" and (({item = "Item", quest = "Quest"})[r.contextType] or "NPC") .. " · " or ""
            local purpose=r.displayPurpose or r.purpose or ""
            if purpose=="Purpose not recorded" then purpose="" end
            row.role:SetText(r.isSection and "Select a source below" or prefix .. purpose)
            if row.kindIcon then row.kindIcon:SetTexture(r.contextType=="item" and "Interface\\Icons\\INV_Misc_Bag_08" or r.contextType=="quest" and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\Icons\\INV_Misc_GroupLooking") end
            local nearest = NS.searchResults[NS.Key(r)]
            row.location:SetText(r.isSection and "" or NS.ResultLocation(r, nearest))
            row.distance:SetText(not r.isSection and NS.db.settings.showDistance and NS.DistanceText(nearest and nearest.distance) or "")
            local selected = NS.selected and NS.Key(NS.selected) == NS.Key(r)
            row:SetBackdropColor(selected and 0.28 or 0.10, selected and 0.22 or 0.10, selected and 0.04 or 0.10, selected and 0.9 or 0.55)
        end
    end
    UpdateDetails()
    if ui.evidencePanel and ui.evidencePanel:IsShown() then NS.RefreshEvidence() end
end

function NS.Refresh(renderOnly)
    local ui = NS.ui
    if not ui or InCombatLockdown() then return end
    ui.typingTicket=(ui.typingTicket or 0)+1
    NS.PrepareTarget()
    local query = ui.search:GetText()
    if NS.db.settings.searchMode ~= "npc" and query:match("%S") then
        if NS.db.settings.searchMode == "all" then NS.StartReference("item"); NS.StartReference("quest")
        else NS.StartReference(NS.db.settings.searchMode) end
    end
    local key = query .. ":" .. NS.db.settings.sort .. ":" .. tostring(NS.db.settings.sameZone)
        .. ":" .. tostring(NS.db.settings.factionOnly) .. ":" .. tostring(NS.PlayerFaction()) .. ":" .. NS.db.settings.searchMode .. ":" .. NS.db.settings.sourceFilter .. ":" .. tostring(NS.db.settings.knownOnly)
    if renderOnly == true and ui.results and ui.completedSearchKey == key then RenderSearch(ui.results); return end
    if ui.searchPending and ui.pendingSearchKey == key then ui.refreshAgain = true; return end
    ui.pendingSearchKey, ui.searchPending, ui.refreshAgain = key, true, false
    ui.count:SetText("Finding closest sources…")
    if ui.completedSearchKey ~= key then
        for _, row in ipairs(ui.rows) do row:Hide() end
        ui.empty:SetText("Searching the NPC catalogue…")
    end
    NS.RequestFind(query, function(results)
        ui.searchPending, ui.completedSearchKey = false, key
        RenderSearch(results)
        if ui.refreshAgain then ui.refreshAgain = false; NS.Refresh() end
    end, function(err)
        ui.searchPending = false
        ui.count:SetText("Search stopped; reopen to retry.")
        NS.Print("Search could not finish: " .. tostring(err))
    end)
end

local function ReportKey(report)
    return table.concat({report.kind, tostring(report.mapID), tostring(report.areaID),
        tostring(report.x), tostring(report.y), tostring(report.phase)}, ":")
end

function NS.RefreshEvidence()
    local ui, r = NS.ui, NS.selected
    if not ui or not ui.evidencePanel or InCombatLockdown() then return end
    if not r then ui.evidencePanel:Hide(); return end
    local reports, err = NS.GetEvidence(r)
    ui.evidenceReports = reports
    if ui.evidenceNPCID ~= r.id then
        ui.evidenceNPCID, ui.evidencePage, ui.evidenceKey = r.id, 1, nil
    end
    local selectedIndex = 1
    for i, report in ipairs(reports) do
        if ReportKey(report) == ui.evidenceKey then selectedIndex = i; break end
    end
    local selected = reports[selectedIndex]
    ui.evidenceKey = selected and ReportKey(selected) or nil
    local pages = math.max(1, math.ceil(#reports / 3))
    ui.evidencePage = math.min(ui.evidencePage or 1, pages)
    ui.evidenceTitle:SetText(r.name .. " · Location evidence")
    ui.evidenceCount:SetText(string.format("%d reports · select one to inspect", #reports))
    ui.evidencePageLabel:SetText(string.format("%d / %d", ui.evidencePage, pages))
    ui.evidenceEmpty:SetText(#reports == 0 and "No evidence recorded for this NPC yet." or "")
    for i, row in ipairs(ui.evidenceRows) do
        local report = reports[(ui.evidencePage - 1) * 3 + i]
        row.report = report
        row:SetShown(report ~= nil)
        if report then
            row.text:SetText(NS.EvidenceText(report))
            local selectedReport = ReportKey(report) == ui.evidenceKey
            row:SetBackdropColor(selectedReport and 0.28 or 0.10, selectedReport and 0.22 or 0.10, selectedReport and 0.04 or 0.10, 0.85)
        end
    end
    ui.evidencePin:SetAlpha(selected and selected.navigable and 1 or 0.4)
    ui.helpText:SetText(NS.Troubleshooting(r, reports, selected, err))
    ui.helpBody:SetHeight(math.max(296, (ui.helpText:GetStringHeight() or 296) + 8))
    ui.helpScroll:SetVerticalScroll(0)
end

function NS.ShowInvestigation()
    if InCombatLockdown() then return end
    if not NS.selected then NS.SetStatus("Select an NPC to inspect its location evidence first."); return end
    NS.ui.search:ClearFocus()
    if NS.ui.toolsPanel then NS.ui.toolsPanel:Hide() end
    NS.ui.evidencePanel:Show()
    NS.RefreshEvidence()
end

function NS.RefreshSettings()
    local ui = NS.ui
    if not ui or not ui.settingButtons or InCombatLockdown() then return end
    for key, button in pairs(ui.settingButtons) do
        button.label:SetText((NS.db.settings[key] and "[On] " or "[Off] ") .. button.settingLabel)
    end
    if ui.sourceFilter then ui.sourceFilter.label:SetText(NS.sourceFilterLabels[NS.db.settings.sourceFilter]) end
    if ui.knownFilter then ui.knownFilter:SetChecked(NS.db.settings.knownOnly) end
    ui.sortSetting.label:SetText("Sort: " .. (NS.db.settings.sort == "distance" and "Closest to furthest" or "NPC name"))
    ui.scaleSetting:SetText(string.format("Window scale: %d%%", math.floor(NS.db.settings.scale * 100 + 0.5)))
    if ui.factionToggle then ui.factionToggle:SetChecked(NS.db.settings.factionOnly) end
    if ui.modeButton then ui.modeButton.label:SetText(({npc = "NPCs", item = "Items", quest = "Quests", all = "All"})[NS.db.settings.searchMode]) end
end

function NS.RefreshVendor()
    local ui = NS.ui
    if not ui or not ui.vendorPanel or not ui.vendorPanel:IsShown() or InCombatLockdown() then return end
    local list = {}
    for id in pairs(NS.vendorItems[ui.vendorNPCID] or {}) do
        local item = NS.items[id]
        local snapshot = NS.db.vendorStock[ui.vendorNPCID]
        local listed = snapshot and snapshot.items[id] ~= nil
        for _, npcID in ipairs(item and item.vendors or {}) do if npcID == ui.vendorNPCID then listed = true; break end end
        if item and listed then list[#list + 1] = item end
    end
    table.sort(list, function(a, b) return a.name == b.name and a.id < b.id or a.name ~= b.name and a.name < b.name end)
    local pages = math.max(1, math.ceil(#list / 6))
    ui.vendorPage = math.max(1, math.min(ui.vendorPage or 1, pages))
    ui.vendorPages:SetText(string.format("%d / %d", ui.vendorPage, pages))
    ui.vendorEmpty:SetText(#list == 0 and (NS.itemLoading and "Loading known vendor items…" or "No vendor items recorded in the available database.") or "")
    for i, row in ipairs(ui.vendorRows) do
        local item = list[(ui.vendorPage - 1) * 6 + i]
        row.item = item
        row:SetShown(item ~= nil)
        if item then row.label:SetText(item.name .. "  ·  Item " .. item.id); row.stock:SetText(NS.StockText(ui.vendorNPCID, item.id)) end
    end
    ui.vendorItemCount, ui.vendorItems = #list, list
end

function NS.BuildUI()
    if NS.ui or InCombatLockdown() then return end
    local ok, ui = pcall(CreateFrame, "Frame", "ForeverSearchingWindow", UIParent, "PortraitFrameTemplate,BackdropTemplate")
    if not ok or not ui then
        ui = CreateFrame("Frame", "ForeverSearchingWindow", UIParent, "BasicFrameTemplateWithInset,BackdropTemplate")
    end
    NS.ui = ui
    ui:SetSize(780, 710)
    ui:SetPoint("CENTER")
    ui:SetFrameStrata("DIALOG")
    ui:SetClampedToScreen(true)
    ui:SetMovable(true)
    ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    ui:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    -- These templates belong to this addon frame only. Let the client provide
    -- Forever's title bar, portrait ring and window chrome; never skin Blizzard frames.
    local nativeTitle = type(ui.TitleText) == "table" and ui.TitleText or nil
    if not nativeTitle and type(ui.TitleContainer) == "table" then nativeTitle = ui.TitleContainer.TitleText end
    ui.title = nativeTitle or Text(ui, "", "GameFontNormal", 66, -7, 600, gold)
    ui.title:SetText("Forever Searching")
    local portraitAsset = "Interface\\Icons\\INV_Misc_Spyglass_03"
    if ui.SetPortraitToAsset then ui:SetPortraitToAsset(portraitAsset)
    else
        local portrait = ui.portrait or ui.Portrait
        if type(ui.PortraitContainer) == "table" then portrait = portrait or ui.PortraitContainer.portrait end
        if type(portrait) == "table" and portrait.SetTexture then portrait:SetTexture(portraitAsset) end
    end
    Text(ui, "An explorer's field guide · WoW Forever", "GameFontHighlightSmall", 66, -48, 350, muted)
    local close = type(ui.CloseButton) == "table" and ui.CloseButton or CreateFrame("Button", nil, ui, "UIPanelCloseButton")
    ui.closeButton = close
    if close ~= ui.CloseButton then close:SetSize(32, 32); close:SetPoint("TOPRIGHT", -2, -2) end
    close:SetScript("OnClick", NS.Close)
    local content = CreateFrame("Frame", nil, ui)
    content:SetAllPoints(ui)
    ui.searchPage = content
    local settingsButton = Button(content, "Settings", 86, 28)
    ui.settingsButton = settingsButton
    settingsButton:SetPoint("TOPRIGHT", -24, -40)
    settingsButton:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        ui.evidencePanel:Hide()
        ui.vendorPanel:Hide()
        if ui.toolsPanel then ui.toolsPanel:Hide() end
        ui.search:ClearFocus()
        ui.settingsPanel:SetShown(not ui.settingsPanel:IsShown())
        NS.RefreshSettings()
    end)
    local factionToggle = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    ui.factionToggle = factionToggle
    factionToggle:SetSize(24, 24)
    factionToggle:SetPoint("TOPLEFT", 435, -41)
    Text(content, "My faction + neutral", "GameFontHighlightSmall", 461, -48, 172, muted)
    factionToggle:SetScript("OnClick", function(self)
        if InCombatLockdown() then self:SetChecked(NS.db.settings.factionOnly); return end
        NS.db.settings.factionOnly = not not self:GetChecked()
        ui.page, NS.selected = 1, nil
        NS.RefreshSettings(); NS.Refresh()
    end)

    local searchPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    searchPanel:SetPoint("TOPLEFT", 24, -78)
    searchPanel:SetSize(732, 38)
    Panel(searchPanel)
    local search = CreateFrame("EditBox", nil, searchPanel)
    ui.search = search
    NS.InstallSearchLinkHook()
    search:SetPoint("TOPLEFT", 12, -1)
    search:SetPoint("BOTTOMRIGHT", -112, 1)
    search:SetFontObject("GameFontHighlight")
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    local hint = Text(searchPanel, "Search by name, ID or item description…", "GameFontHighlight", 12, -12, 590, muted)
    local modeNames = {npc = "NPCs", item = "Items", quest = "Quests", all = "All"}
    local modeButton = Button(searchPanel, modeNames[NS.db.settings.searchMode], 94, 28)
    ui.modeButton = modeButton
    modeButton:SetPoint("RIGHT", -6, 0)
    modeButton:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        NS.ChoiceMenu(ui,modeButton,{{id="all",name="All"},{id="npc",name="NPCs"},{id="item",name="Items"},{id="quest",name="Quests"}},function(entry)
        NS.db.settings.searchMode = entry.id
        modeButton.label:SetText(modeNames[NS.db.settings.searchMode])
        NS.selected, ui.page = nil, 1
        ui.evidencePanel:Hide(); ui.vendorPanel:Hide()
        if ui.toolsPanel then ui.toolsPanel:Hide() end
        NS.Refresh()
        end)
    end)
    search:SetScript("OnTextChanged", function(self,userInput)
        hint:SetShown(self:GetText() == "")
        if InCombatLockdown() then return end
        if ui.settingsPanel then ui.settingsPanel:Hide() end
        if ui.vendorPanel then ui.vendorPanel:Hide() end
        if ui.toolsPanel then ui.toolsPanel:Hide() end
        NS.selected, ui.page = nil, 1
        if userInput then
            NS.CancelWork("search")
            ui.searchPending,ui.refreshAgain=false,false
            ui.typingTicket=(ui.typingTicket or 0)+1
            local ticket=ui.typingTicket
            NS.PrepareTarget()
            ui.count:SetText("Waiting for typing…")
            for _,row in ipairs(ui.rows) do row:Hide() end
            C_Timer.After(0.12,function()
                if ui.typingTicket==ticket and ui:IsShown() and not InCombatLockdown() then NS.Refresh() end
            end)
        else NS.Refresh() end
        NS.SetStatus("Click Target & mark to search nearby. This clears your previous target.")
    end)
    search:SetScript("OnEnterPressed", function(self)
        NS.Refresh()
        self:ClearFocus()
        NS.RememberSearch(self:GetText())
        NS.SetStatus("Click Target & mark to run the prepared search.")
    end)
    search:SetScript("OnEscapePressed", NS.Close)
    ui.listInset = Inset(content, 20, -167, 326, 408)
    ui.listInset:SetFrameLevel(ui:GetFrameLevel())
    local function ScrollResults(_,delta)
        if InCombatLockdown() then return end
        ui.page=math.max(1,math.min(ui.page-(delta>0 and 1 or -1),math.max(1,math.ceil(#(ui.displayRows or {})/pageSize))))
        NS.Refresh(true)
    end
    ui.listInset:EnableMouseWheel(true); ui.listInset:SetScript("OnMouseWheel",ScrollResults)
    ui.count = Text(ui.listInset, "", "GameFontHighlightSmall", 4, -4, 318, muted)
    ui.count:SetWidth(160)
    ui.quickSort=Button(ui.listInset,"Sort: Nearest",138,22)
    ui.quickSort:SetPoint("TOPRIGHT",-3,0)
    ui.quickSort:SetScript("OnClick",function()
        NS.ChoiceMenu(ui,ui.quickSort,{{id="distance",name="Nearest first"},{id="name",name="Name A–Z"}},function(entry)
            NS.db.settings.sort=entry.id; ui.page=1; NS.RefreshSettings(); NS.Refresh()
        end)
    end)
    ui.rows = {}
    for i = 1, pageSize do
        local row = Button(content, "", 318, 55, "row")
        row.kindIcon=row:CreateTexture(nil,"ARTWORK"); row.kindIcon:SetSize(12,12); row.kindIcon:SetPoint("TOPRIGHT",-6,-23)
        row:EnableMouseWheel(true); row:SetScript("OnMouseWheel",ScrollResults)
        row:SetPoint("TOPLEFT", 24, -191 - (i - 1) * 58)
        row.name = Text(row, "", "GameFontHighlight", 10, -6, 213)
        row.name:SetMaxLines(1)
        row.distance = Text(row, "", "GameFontHighlightSmall", 231, -8, 76, gold)
        row.distance:SetJustifyH("RIGHT")
        row.role = Text(row, "", "GameFontHighlightSmall", 10, -23, 297, muted)
        row.role:SetMaxLines(1)
        row.location = Text(row, "", "GameFontHighlightSmall", 10, -39, 297, muted)
        row.location:SetMaxLines(1)
        row:SetScript("OnEnter", function(self)
            if self.record and self.record.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.record.itemID)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            if InCombatLockdown() then return end
            if not self.record or self.record.isSection then return end
            NS.RememberSearch(search:GetText())
            if self.record.isGroup then
                ui.expanded = ui.expanded or {}
                local key = NS.Key(self.record)
                ui.expanded[key] = not ui.expanded[key]
            end
            NS.selected = self.record
            search:ClearFocus()
            NS.Refresh(true)
        end)
        ui.rows[i] = row
    end
    ui.empty = Text(content, "", "GameFontHighlight", 36, -210, 292, muted)
    local prev, nextPage = Button(content, "<", 32, 25), Button(content, ">", 32, 25)
    prev:SetPoint("TOPLEFT", 24, -548)
    nextPage:SetPoint("TOPLEFT", 310, -548)
    ui.pageLabel = Text(content, "1 / 1", "GameFontHighlightSmall", 139, -556, 130, muted)
    prev:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        ui.page = math.max(1, ui.page - 1); NS.Refresh(true)
    end)
    nextPage:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        ui.page = math.min(math.max(1, math.ceil(#(ui.displayRows or ui.results) / pageSize)), ui.page + 1); NS.Refresh(true)
    end)

    local detail = Inset(content, 358, -171, 398, 402)
    ui.detailName = Text(detail, "", "GameFontNormalLarge", 18, -19, 362, gold)
    ui.detailName:SetMaxLines(2)
    ui.detailRole = Text(detail, "", "GameFontHighlight", 18, -67, 362)
    ui.detailRole:SetHeight(36)
    ui.detailRole:SetJustifyV("TOP")
    ui.detailReason = Text(detail, "", "GameFontHighlightSmall", 18, -110, 362, muted)
    ui.detailReason:SetMaxLines(1)
    ui.detailMeta = Text(detail, "", "GameFontHighlightSmall", 18, -132, 362, muted)
    ui.detailMeta:SetHeight(100)
    ui.detailMeta:SetJustifyV("TOP")
    ui.detailLocation = Text(detail, "", "GameFontHighlightSmall", 18, -242, 362, muted)
    ui.detailLocation:SetHeight(40)
    ui.detailLocation:SetJustifyV("TOP")
    local vendorButton = Button(detail, "Vendor items", 114, 25)
    ui.vendorButton = vendorButton
    vendorButton:SetPoint("TOPLEFT", 18, -210)
    vendorButton:SetScript("OnClick", function()
        if InCombatLockdown() or not NS.selected then return end
        ui.vendorNPCID, ui.vendorPage = NS.selected.id, 1
        ui.vendorTitle:SetText(NS.selected.name .. " · Known vendor items")
        ui.vendorPanel:Show()
        NS.StartReference("item")
        NS.RefreshVendor()
    end)

    ui.favourite = Button(detail, "Favourite", 112, 25)
    ui.favourite:SetPoint("TOPLEFT", 140, -210)
    ui.favourite:SetScript("OnClick", function()
        if InCombatLockdown() or not NS.selected then return end
        NS.ToggleFavourite(NS.selected); UpdateDetails()
    end)
    ui.requirements = Button(detail, "Requirements", 116, 25)
    ui.requirements:SetPoint("TOPLEFT", 264, -210)
    ui.requirements:SetScript("OnClick", function()
        if NS.selected and NS.selected.questID then NS.ShowTools("requirements", NS.selected.questID) end
    end)
    local investigate = Button(detail, "I'm here, where are they?", 194, 25)
    ui.investigate = investigate
    investigate:SetPoint("TOPLEFT", 18, -284)
    investigate:SetScript("OnClick", NS.ShowInvestigation)
    ui.wowheadButton=Button(detail,"Copy Wowhead link",160,25)
    ui.wowheadButton:SetPoint("TOPLEFT",220,-284)
    ui.wowheadButton:SetScript("OnClick",function() NS.ShowWowheadLinks(NS.selected) end)

    local marker = Button(detail, "", 174, 29)
    ui.marker=marker
    marker:SetPoint("BOTTOMLEFT", 18, 61)
    local function UpdateMarker()
        local n = NS.db.marker
        marker.label:SetText(n == 0 and "No marker" or ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. n .. ":16|t " .. markerNames[n]))
    end
    marker:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        NS.db.marker = (NS.db.marker + 1) % 9
        UpdateMarker(); NS.PrepareTarget()
    end)
    UpdateMarker()
    ui.shoppingAdd = Button(detail, "Shopping +1", 174, 29)
    ui.shoppingAdd:SetPoint("BOTTOMRIGHT", -18, 61)
    ui.shoppingAdd:SetScript("OnClick", function() NS.AddShopping(NS.selected) end)
    local target = Button(detail, "Target & mark", 174, 34, "SecureActionButtonTemplate")
    ui.target = target
    target:SetPoint("BOTTOMLEFT", 18, 21)
    target:RegisterForClicks("AnyUp", "AnyDown")
    target:SetScript("PostClick", function(_, _, down)
        if down or InCombatLockdown() or not ui.targetName then return end
        local wanted = ui.targetName
        C_Timer.After(0.15, function()
            if InCombatLockdown() then return end
            local name = NS.CleanName(UnitName("target"))
            if name and string.lower(name) == string.lower(wanted) then
                NS.Observe("target")
                NS.SetStatus("Target found. Group permissions control whether raid markers can be applied.")
            else NS.SetStatus("Not found in targeting range. Try 'I'm here, where are they?' for location evidence.") end
        end)
    end)
    local pin = Button(detail, "Navigate here", 174, 34)
    ui.navigate=pin
    pin:SetPoint("BOTTOMRIGHT", -18, 21)
    pin:SetScript("OnClick", function()
        if NS.selected then NS.Pin(NS.selected) else NS.SetStatus("Select an NPC with a recorded location first.") end
    end)

    -- Overlays share the catalogue area below the search tools.
    local evidence = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ui.evidencePanel = evidence
    evidence:SetPoint("TOPLEFT", 24, -171)
    evidence:SetSize(732, 402)
    evidence:SetFrameLevel(ui:GetFrameLevel() + 20)
    evidence:EnableMouse(true)
    Panel(evidence)
    ui.evidenceTitle = Text(evidence, "Location evidence", "GameFontNormalLarge", 16, -17, 514, gold)
    ui.evidenceTitle:SetMaxLines(1)
    local back = Button(evidence, "Back", 76, 28)
    ui.evidenceBack = back
    back:SetPoint("TOPRIGHT", -16, -12)
    back:SetScript("OnClick", function() if not InCombatLockdown() then evidence:Hide() end end)
    local refreshEvidence = Button(evidence, "Refresh", 76, 28)
    refreshEvidence:SetPoint("TOPRIGHT", -100, -12)
    refreshEvidence:SetScript("OnClick", function() NS.RefreshEvidence() end)
    ui.evidenceCount = Text(evidence, "", "GameFontHighlightSmall", 16, -52, 330, muted)
    ui.evidenceRows = {}
    for i = 1, 3 do
        local row = Button(evidence, "", 338, 75, "row")
        row:SetPoint("TOPLEFT", 16, -76 - (i - 1) * 80)
        row.text = Text(row, "", "GameFontHighlightSmall", 9, -8, 320)
        row.text:SetHeight(60)
        row.text:SetJustifyV("TOP")
        row:SetScript("OnClick", function(self)
            if InCombatLockdown() or not self.report then return end
            ui.evidenceKey = ReportKey(self.report)
            NS.RefreshEvidence()
        end)
        ui.evidenceRows[i] = row
    end
    ui.evidenceEmpty = Text(evidence, "", "GameFontHighlight", 25, -90, 314, muted)
    local ePrev, eNext = Button(evidence, "<", 32, 25), Button(evidence, ">", 32, 25)
    ePrev:SetPoint("TOPLEFT", 16, -321)
    eNext:SetPoint("TOPLEFT", 322, -321)
    ui.evidenceNext = eNext
    ui.evidencePageLabel = Text(evidence, "1 / 1", "GameFontHighlightSmall", 150, -328, 120, muted)
    local function PageEvidence(delta)
        if InCombatLockdown() then return end
        local pages = math.max(1, math.ceil(#ui.evidenceReports / 3))
        ui.evidencePage = math.max(1, math.min(pages, ui.evidencePage + delta))
        local first = ui.evidenceReports[(ui.evidencePage - 1) * 3 + 1]
        ui.evidenceKey = first and ReportKey(first) or nil
        NS.RefreshEvidence()
    end
    ePrev:SetScript("OnClick", function() PageEvidence(-1) end)
    eNext:SetScript("OnClick", function() PageEvidence(1) end)
    ui.evidencePin = Button(evidence, "Waypoint to selected report", 338, 29)
    ui.evidencePin:SetPoint("TOPLEFT", 16, -357)
    ui.evidencePin:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        for _, report in ipairs(ui.evidenceReports or {}) do
            if ReportKey(report) == ui.evidenceKey then NS.Pin(NS.selected, report); return end
        end
        NS.SetStatus("No location report is selected.")
    end)
    Text(evidence, "I'm here, where are they?", "GameFontNormal", 374, -52, 338, gold)
    local scroll = CreateFrame("ScrollFrame", nil, evidence, "UIPanelScrollFrameTemplate")
    ui.helpScroll = scroll
    scroll:SetPoint("TOPLEFT", 374, -77)
    scroll:SetSize(312, 309)
    local body = CreateFrame("Frame", nil, scroll)
    ui.helpBody = body
    body:SetSize(312, 309)
    ui.helpText = Text(body, "", "GameFontHighlightSmall", 0, 0, 306)
    scroll:SetScrollChild(body)
    evidence:Hide()

    local settings = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ui.settingsPanel = settings
    settings:SetPoint("TOPLEFT", 24, -171)
    settings:SetSize(732, 436)
    settings:SetFrameLevel(ui:GetFrameLevel() + 30)
    settings:EnableMouse(true)
    Panel(settings)
    Text(settings, "Forever Searching · Settings", "GameFontNormalLarge", 18, -18, 600, gold)
    local settingsBack = Button(settings, "Back", 76, 28)
    settingsBack:SetPoint("TOPRIGHT", -16, -12)
    settingsBack:SetScript("OnClick", function() if not InCombatLockdown() then settings:Hide() end end)
    local function Changed()
        ui.page = 1
        NS.ApplySettings()
        NS.RefreshSettings()
        NS.Refresh()
    end
    ui.sortSetting = Button(settings, "", 338, 32)
    ui.sortSetting:SetPoint("TOPLEFT", 16, -70)
    ui.sortSetting:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        NS.db.settings.sort = NS.db.settings.sort == "distance" and "name" or "distance"
        Changed()
    end)
    ui.settingButtons = {}
    local function ToggleSetting(key, label, x, y)
        local option = Button(settings, "", 338, 32)
        option:SetPoint("TOPLEFT", x, y)
        option.settingLabel = label
        ui.settingButtons[key] = option
        option:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            NS.db.settings[key] = not NS.db.settings[key]
            Changed()
        end)
    end
    ToggleSetting("showDistance", "Show estimated distances", 16, -119)
    ToggleSetting("liveRefresh", "Refresh order while moving", 16, -168)
    ToggleSetting("sameZone", "Current zone only", 16, -217)
    ToggleSetting("factionOnly", "My faction + neutral", 16, -260)
    ToggleSetting("fadeWhileMoving", "Fade while moving (35% opacity)", 16, -303)
    ToggleSetting("recordSightings", "Remember NPC sightings", 378, -70)
    ToggleSetting("minimap", "Show minimap button", 378, -119)
    ToggleSetting("recordStock", "Remember visited vendor stock", 378, -168)
    ToggleSetting("groupedResults", "Group item / quest sources", 378, -217)
    ToggleSetting("showArrow", "Show navigation arrow", 378, -350)
    ui.scaleSetting = Text(settings, "", "GameFontHighlight", 388, -268, 302, gold)
    local smaller, larger = Button(settings, "−", 56, 30), Button(settings, "+", 56, 30)
    ui.scaleSmaller, ui.scaleLarger = smaller, larger
    smaller:SetPoint("TOPLEFT", 378, -291)
    larger:SetPoint("TOPLEFT", 660, -291)
    Text(settings, "80% – 120%", "GameFontHighlightSmall", 487, -301, 170, muted)
    local function Scale(delta)
        if InCombatLockdown() then return end
        NS.db.settings.scale = math.max(0.8, math.min(1.2, math.floor((NS.db.settings.scale + delta) * 100 + 0.5) / 100))
        Changed()
    end
    smaller:SetScript("OnClick", function() Scale(-0.05) end)
    larger:SetScript("OnClick", function() Scale(0.05) end)
    Text(settings, "These preferences affect this addon only.",
        "GameFontHighlightSmall", 388, -328, 320, muted)
    local reset = Button(settings, "Reset defaults", 152, 30)
    ui.resetSettings = reset
    reset:SetPoint("TOPLEFT", 16, -350)
    reset:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        NS.ResetSettings()
        Changed()
    end)
    Text(settings, "Changes save automatically. Use /find if the minimap button is hidden.", "GameFontHighlightSmall", 18, -404, 696, muted)
    settings:Hide()

    local vendorPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ui.vendorPanel = vendorPanel
    vendorPanel:SetPoint("TOPLEFT", 24, -171)
    vendorPanel:SetSize(732, 402)
    vendorPanel:SetFrameLevel(ui:GetFrameLevel() + 40)
    vendorPanel:EnableMouse(true)
    Panel(vendorPanel)
    ui.vendorTitle = Text(vendorPanel, "Known vendor items", "GameFontNormalLarge", 18, -18, 590, gold)
    ui.vendorTitle:SetMaxLines(1)
    Text(vendorPanel, "Database listings + dated personal observations. Prices and stock may have changed.", "GameFontHighlightSmall", 18, -52, 690, muted)
    local vendorBack = Button(vendorPanel, "Back", 76, 28)
    vendorBack:SetPoint("TOPRIGHT", -16, -12)
    vendorBack:SetScript("OnClick", function() if not InCombatLockdown() then vendorPanel:Hide() end end)
    ui.vendorRows = {}
    for i = 1, 6 do
        local row = Button(vendorPanel, "", 696, 42, "row")
        row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", 10, -5)
        row.stock = Text(row, "", "GameFontHighlightSmall", 10, -24, 675, muted)
        row.stock:SetMaxLines(1)
        row:SetPoint("TOPLEFT", 18, -76 - (i - 1) * 46)
        row:SetScript("OnClick", function(self)
            if InCombatLockdown() or not self.item then return end
            NS.db.settings.searchMode = "item"
            NS.RefreshSettings()
            vendorPanel:Hide()
            ui.search:SetText(tostring(self.item.id))
        end)
        row:SetScript("OnEnter", function(self)
            if self.item then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.item.id)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ui.vendorRows[i] = row
    end
    ui.vendorEmpty = Text(vendorPanel, "", "GameFontHighlight", 30, -98, 650, muted)
    local vendorPrev, vendorNext = Button(vendorPanel, "<", 32, 25), Button(vendorPanel, ">", 32, 25)
    vendorPrev:SetPoint("TOPLEFT", 18, -362)
    vendorNext:SetPoint("TOPRIGHT", -18, -362)
    ui.vendorPages = Text(vendorPanel, "1 / 1", "GameFontHighlightSmall", 340, -370, 130, muted)
    vendorPrev:SetScript("OnClick", function() if not InCombatLockdown() then ui.vendorPage = math.max(1, ui.vendorPage - 1); NS.RefreshVendor() end end)
    vendorNext:SetScript("OnClick", function() if not InCombatLockdown() then ui.vendorPage = ui.vendorPage + 1; NS.RefreshVendor() end end)
    vendorPanel:Hide()

    NS.BuildTools(ui, Text, Button, Panel, content)

    ui.status = Text(content, "Ready. Search by name, purpose, zone, or NPC ID.", "GameFontHighlightSmall", 24, -590, 732)
    ui.status:SetHeight(23)
    ui.status:SetJustifyV("TOP")
    ui.provider = Text(content, NS.catalogueStatus, "GameFontHighlightSmall", 24, -622, 732, muted)
    local dataHelp=Button(content,"About / Data",136,25)
    dataHelp:SetPoint("TOPRIGHT",-24,-615)
    dataHelp:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        GameTooltip:SetOwner(dataHelp,"ANCHOR_TOP")
        GameTooltip:AddLine("Forever Searching",1,0.82,0)
        GameTooltip:AddLine("By junglistloydee",1,1,1,true)
        for line in NS.SearchStatus():gsub(" · ", "\n"):gmatch("[^\n]+") do
            GameTooltip:AddLine(line:match("^%s*(.-)%s*$"),1,1,1,true)
        end
        GameTooltip:AddLine("Data: QuestieDB",0.8,0.8,0.8,true)
        GameTooltip:AddLine("Questie team and contributors",0.8,0.8,0.8,true)
        GameTooltip:AddLine("Separate optional dependency",0.8,0.8,0.8,true)
        GameTooltip:Show()
    end)
    dataHelp:SetScript("OnLeave",function() GameTooltip:Hide() end)
    ui.provider:SetWidth(560)

    Text(content, "By junglistloydee", "GameFontHighlightSmall", 24, -657, 154, gold)
    local githubURL = "https://github.com/junglistloydee"
    local github = CreateFrame("EditBox", nil, content)
    ui.github = github
    github:SetPoint("TOPLEFT", 184, -647)
    github:SetSize(572, 28)
    github:SetFontObject("GameFontHighlightSmall")
    github:SetTextColor(unpack(muted))
    github:SetAutoFocus(false)
    github:SetText(githubURL)
    github:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    github:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= githubURL then self:SetText(githubURL); self:HighlightText() end
    end)
    github:SetScript("OnEscapePressed", NS.Close)
    github:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    github:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("junglistloydee on GitHub", unpack(gold))
        GameTooltip:AddLine("Click the link, then press Ctrl+C to copy.", 1, 1, 1)
        GameTooltip:Show()
    end)
    github:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ui.dependencyCredit = Text(content,
        "Data: QuestieDB · Questie team and contributors · separately installed dependency",
        "GameFontHighlightSmall", 24, -680, 732, muted)

    -- This launcher is independent of the protected window, so minimap changes remain safe.
    local launcher = CreateFrame("Button", "ForeverSearchingMinimapButton", Minimap, "BackdropTemplate")
    NS.launcher = launcher
    launcher:SetSize(28, 28)
    launcher:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -6, 6)
    launcher:SetFrameStrata("MEDIUM")
    Panel(launcher)
    local icon = launcher:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(21, 21)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    launcher:SetScript("OnClick", NS.Toggle)
    launcher:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Searching", unpack(gold))
        GameTooltip:AddLine("Click to search and browse NPCs.", 1, 1, 1)
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)
    NS.BuildTransmogUI(ui, Text, Button, Panel, Inset)
    NS.BuildWowheadUI(ui, Text, Button, Panel)
    ui:SetScript("OnHide", function()
        if ui.choiceMenu and not InCombatLockdown() then ui.choiceMenu:Hide() end
        ui.typingTicket=(ui.typingTicket or 0)+1
        search:ClearFocus(); github:ClearFocus()
        ui.wowhead.box:ClearFocus()
        NS.CancelWork("transmogBrowser")
        if ui.transmog then ui.transmog.nameBox:ClearFocus(); ui.transmog.query:ClearFocus() end
        NS.CancelWork("search")
        NS.CancelRoutePlanning()
        ui.searchPending, ui.refreshAgain = false, false
    end)
    ui:SetScript("OnUpdate", function(self, elapsed)
        self.fadeElapsed=(self.fadeElapsed or 0)+elapsed
        if self.fadeElapsed>=0.1 then NS.UpdateMovementFade(self.fadeElapsed); self.fadeElapsed=0 end
        if not NS.db.settings.liveRefresh or InCombatLockdown() or not self:IsShown() or self.searchPending
            or ui.transmogPanel:IsShown() or settings:IsShown() or evidence:IsShown() or vendorPanel:IsShown() or ui.toolsPanel:IsShown() then return end
        self.distanceElapsed = (self.distanceElapsed or 0) + elapsed
        if self.distanceElapsed < 2 then return end
        self.distanceElapsed = 0
        if OriginKey(NS.PlayerOrigin()) ~= self.distanceOrigin then NS.Refresh() end
    end)
    ui:Hide()
    -- Registered outside combat. The native secure handler may hide the
    -- protected window at combat entry; ordinary event callbacks must not.
    -- Leaving combat deliberately does nothing, keeping the window closed.
    -- Keep secure-handler scripts off the portrait frame so its native
    -- OnLoad/OnAttributeChanged scripts are not replaced by another template.
    local combatHider = CreateFrame("Frame", "ForeverSearchingCombatHider", UIParent, "SecureHandlerStateTemplate")
    ui.combatHider = combatHider
    combatHider:Hide()
    NS.BuildNavigation()
    combatHider:SetFrameRef("window", ui)
    combatHider:SetFrameRef("navigation", NS.navigationFrame)
    if NS.vendorProfiles then
        combatHider:SetFrameRef("vendorSets",NS.vendorProfiles.panel)
        combatHider:SetFrameRef("vendorSetsButton",NS.vendorProfiles.button)
    end
    combatHider:SetAttribute("_onstate-searchcombat", "if newstate == '1' then self:GetFrameRef('window'):Hide(); self:GetFrameRef('navigation'):Hide(); local sets=self:GetFrameRef('vendorSets'); if sets then sets:Hide() end; local button=self:GetFrameRef('vendorSetsButton'); if button then button:Hide() end end")
    RegisterStateDriver(combatHider, "searchcombat", "[combat] 1; 0")
    NS.UpdateEscapeRegistration()
    NS.ApplySettings()
    NS.RefreshSettings()
    NS.Refresh()
end
