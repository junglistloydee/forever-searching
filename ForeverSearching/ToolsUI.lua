local _, NS = ...

function NS.BuildTools(ui, Text, Button, Panel, parent)
    parent = parent or ui
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ui.toolsPanel = panel
    panel:SetPoint("TOPLEFT", 24, -171)
    panel:SetSize(732, 402)
    panel:SetFrameLevel(ui:GetFrameLevel() + 50)
    panel:EnableMouse(true)
    Panel(panel)
    local title = Text(panel, "", "GameFontNormalLarge", 18, -18, 590)
    local back = Button(panel, "Back", 76, 28)
    back:SetPoint("TOPRIGHT", -16, -12)
    back:SetScript("OnClick", function() if not InCombatLockdown() then panel:Hide() end end)
    local hint = Text(panel, "", "GameFontHighlightSmall", 18, -52, 690)
    local rows, entries, page, selected, mode = {}, {}, 1, nil, nil
    ui.toolsRows=rows
    local empty = Text(panel, "", "GameFontHighlight", 25, -100, 650)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -76); scroll:SetSize(670, 300)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(670, 300)
    local requirements = Text(body, "", "GameFontHighlight", 0, 0, 660)
    scroll:SetScrollChild(body)
    local pages = Text(panel, "", "GameFontHighlightSmall", 340, -370, 120)
    local prev, nextPage = Button(panel, "<", 32, 25), Button(panel, ">", 32, 25)
    prev:SetPoint("TOPLEFT", 18, -362); nextPage:SetPoint("TOPRIGHT", -18, -362)
    local controls = {}
    local function Control(label, width, x, callback, kind)
        local b = Button(panel, label, width, 26)
        b:SetPoint("TOPLEFT", x, -320)
        b:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            callback(); NS.RefreshTools()
        end)
        controls[#controls + 1] = b
        b.toolsMode=kind or "shopping"
        return b
    end
    Control("−", 38, 18, function() if selected then NS.ChangeShopping(selected.id, -1) end end)
    Control("+", 38, 62, function() if selected then NS.ChangeShopping(selected.id, 1) end end)
    Control("Done / undo", 114, 110, function() if selected then selected.done = not selected.done; NS.ShoppingListChanged() end end)
    Control("Find sources", 120, 234, function() if selected then NS.OpenSavedSearch("item", selected.id) end end)
    Control("Remove", 94, 364, function() if selected then NS.db.shopping[selected.id] = nil; selected = nil; NS.ShoppingListChanged() end end)
    ui.planShoppingRoute=Control("Plan vendor route",156,474,NS.PlanShoppingRoute)
    ui.startShoppingRoute=Control("Start route",126,18,NS.StartShoppingRoute,"route")
    ui.nextShoppingStop=Control("Got items / next",142,154,function() NS.NextShoppingStop(true) end,"route")
    ui.skipShoppingStop=Control("Skip stop",94,306,function() NS.NextShoppingStop(false) end,"route")
    ui.stopShoppingRoute=Control("Stop",80,410,NS.StopShoppingRoute,"route")
    ui.replanShoppingRoute=Control("Replan route",126,500,NS.PlanShoppingRoute,"route")
    for i = 1, 5 do
        local row = Button(panel, "", 652, 42, "row")
        row:SetPoint("TOPLEFT", 18, -76 - (i - 1) * 46)
        local remove = Button(panel, "×", 38, 42)
        remove:SetPoint("TOPRIGHT", -18, -76 - (i - 1) * 46)
        row.remove = remove
        row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT",8,-6)
        row.details=Text(row,"","GameFontHighlightSmall",8,-24,630)
        row:SetScript("OnClick", function(self)
            if InCombatLockdown() or not self.entry then return end
            if mode == "shopping" or mode == "route" then selected = self.entry; NS.RefreshTools()
            elseif mode == "recent" then NS.OpenSavedSearch(self.entry.mode, self.entry.query)
            else NS.OpenSavedSearch(self.entry.kind, self.entry.id) end
        end)
        row:SetScript("OnEnter",function(self)
            local stop=mode=="route" and self.entry and self.entry.stop
            if InCombatLockdown() or not stop then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(stop.record.name,1,0.82,0)
            GameTooltip:AddLine(NS.MapName(stop.location.mapID).." · "..NS.DistanceText(stop.distance).." from the previous stop",0.7,0.7,0.7)
            for _,item in ipairs(stop.items) do GameTooltip:AddLine(item.name.." × "..item.quantity,1,1,1) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        remove:SetScript("OnClick", function()
            if InCombatLockdown() or not row.entry then return end
            if mode == "favourites" then NS.db.favourites[row.entry.key] = nil
            elseif mode == "recent" then table.remove(NS.db.recentSearches, row.entry.index)
            else NS.db.shopping[row.entry.id] = nil; selected = nil; NS.ShoppingListChanged() end
            NS.RefreshTools()
        end)
        rows[i] = row
    end
    function NS.RefreshTools()
        if InCombatLockdown() or not mode then return end
        entries = {}
        if mode == "favourites" then
            for key, entry in pairs(NS.db.favourites) do entries[#entries + 1] = {key=key, kind=entry.kind, id=entry.id, name=entry.name} end
        elseif mode == "recent" then
            for i, entry in ipairs(NS.db.recentSearches) do entries[#entries + 1] = {index=i, query=entry.query, mode=entry.mode} end
        elseif mode == "shopping" then
            for _, entry in pairs(NS.db.shopping) do entries[#entries + 1] = entry end
        elseif mode == "route" and NS.shoppingPlan then
            for index,stop in ipairs(NS.shoppingPlan.stops) do entries[#entries+1]={stop=stop,index=index} end
            for _,item in ipairs(NS.shoppingPlan.unresolved) do entries[#entries+1]={unresolved=item} end
        end
        if mode ~= "recent" and mode~="route" then table.sort(entries, function(a,b) return (a.name or "") < (b.name or "") end) end
        page = math.max(1, math.min(page, math.max(1, math.ceil(#entries / 5))))
        title:SetText(({favourites="Favourites", recent="Recent searches", shopping="Shopping list", route="Shopping vendor route", requirements="Quest requirements"})[mode])
        local plan=NS.shoppingPlan
        hint:SetText(NS.routePlanning and "Planning vendor stops from your current position…" or mode=="route" and plan and
            string.format("%d stops · %s direct travel · %d unrouted items. Stock and prices are not verified.",#plan.stops,NS.DistanceText(plan.totalDistance),#plan.unresolved) or
            mode == "shopping" and "Set quantities, then plan a nearby-first vendor route. Completion is manual." or
            mode == "requirements" and "Recorded QuestieDB requirements · current availability may differ" or "Click an entry to search. × removes it from this list.")
        for i, row in ipairs(rows) do
            local entry = entries[(page - 1) * 5 + i]
            row.entry = entry; row:SetShown(entry ~= nil); row.remove:SetShown(entry ~= nil and mode~="route")
            if entry then
                local detail=""
                local label
                if mode=="route" then
                    if entry.stop then
                        local stop=entry.stop
                        label=string.format("%d. %s · %s%s",entry.index,stop.record.name,NS.DistanceText(stop.distance),stop.visited and (stop.bought and " · Done" or " · Skipped") or "")
                        local names={}
                        for _,item in ipairs(stop.items) do names[#names+1]=item.name.." × "..item.quantity end
                        detail=NS.MapName(stop.location.mapID).." · "..table.concat(names,", ")
                    else label="Unrouted: "..entry.unresolved.name; detail=entry.unresolved.reason end
                else label = mode == "recent" and (entry.mode .. " · " .. entry.query) or
                    mode == "shopping" and ((entry.done and "[Done] " or "") .. entry.name .. " × " .. entry.quantity) or (entry.kind .. " · " .. entry.name)
                end
                row.label:SetText((entry == selected and "> " or "") .. label)
                row.details:SetText(detail)
            end
        end
        for _, b in ipairs(controls) do b:SetShown(mode==b.toolsMode) end
        ui.planShoppingRoute.label:SetText(NS.routePlanning and "Planning…" or "Plan vendor route")
        ui.planShoppingRoute:SetEnabled(not NS.routePlanning)
        ui.startShoppingRoute:SetEnabled(plan~=nil and #plan.stops>0 and not plan.used and not NS.routePlanning and plan.signature==NS.ShoppingSignature())
        ui.nextShoppingStop:SetEnabled(NS.shoppingRoute~=nil)
        ui.skipShoppingStop:SetEnabled(NS.shoppingRoute~=nil)
        ui.stopShoppingRoute:SetEnabled(NS.shoppingRoute~=nil)
        empty:SetText(#entries == 0 and mode ~= "requirements" and "Nothing saved here yet." or "")
        scroll:SetShown(mode == "requirements")
        pages:SetText(string.format("%d / %d", page, math.max(1, math.ceil(#entries / 5))))
        pages:SetShown(mode ~= "requirements"); prev:SetShown(mode ~= "requirements"); nextPage:SetShown(mode ~= "requirements")
    end
    function NS.ShowTools(kind, questID)
        if InCombatLockdown() then return end
        mode, page, selected = kind, 1, nil
        ui.evidencePanel:Hide(); ui.vendorPanel:Hide(); ui.settingsPanel:Hide()
        if ui.wowhead then ui.wowhead.panel:Hide() end
        ui.search:ClearFocus(); panel:Show(); NS.RefreshTools()
        if kind == "requirements" then
            requirements:SetText("Loading requirements…")
            NS.RunWork("requirements", function() return NS.QuestRequirements(questID) end, function(text)
                requirements:SetText(text); body:SetHeight(math.max(300, (requirements:GetStringHeight() or 300) + 8)); scroll:SetVerticalScroll(0)
            end, function() requirements:SetText("Requirements could not be read from this database.") end)
        end
    end
    NS.ShowShoppingRoutePreview=function() if ui:IsShown() then NS.ShowTools("route") end end
    panel:SetScript("OnHide",function() NS.CancelRoutePlanning() end)
    prev:SetScript("OnClick", function() if not InCombatLockdown() then page = math.max(1,page-1); selected = nil; NS.RefreshTools() end end)
    nextPage:SetScript("OnClick", function() if not InCombatLockdown() then page = page+1; selected = nil; NS.RefreshTools() end end)
    panel:Hide()

    local filter = Button(parent, "", 144, 28)
    ui.sourceFilter = filter
    filter:SetPoint("TOPLEFT", 24, -124)
    filter:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local entries={}; for _,id in ipairs(NS.sourceFilters) do entries[#entries+1]={id=id,name=NS.sourceFilterLabels[id]} end
        NS.ChoiceMenu(ui,filter,entries,function(entry)
        NS.db.settings.sourceFilter = entry.id
        NS.RefreshSettings(); ui.page = 1; NS.Refresh()
        end)
    end)
    local known = CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    known:SetSize(24,24)
    known.label=Text(known,"Known location","GameFontHighlightSmall",26,-6,120)
    ui.knownFilter = known
    known:SetPoint("TOPLEFT", 176, -124)
    known:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        NS.db.settings.knownOnly = not NS.db.settings.knownOnly
        NS.RefreshSettings(); ui.page = 1; NS.Refresh()
    end)
    for i, option in ipairs({{"Favourites", "favourites"}, {"Recent", "recent"}, {"Shopping", "shopping"}}) do
        local b = Button(parent, option[1], 132, 28)
        b:SetPoint("TOPLEFT", 328 + (i - 1) * 144, -124)
        local kind = option[2]
        b:SetScript("OnClick", function() NS.ShowTools(kind) end)
    end
end
