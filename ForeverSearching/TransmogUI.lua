local _, NS = ...
local T=NS.Transmog

function NS.BuildTransmogUI(ui,Text,Button,Panel)
    local panel=CreateFrame("Frame",nil,ui,"BackdropTemplate")
    ui.transmogPanel=panel
    panel:SetPoint("TOPLEFT",24,-78); panel:SetSize(972,682); Panel(panel)
    local state={slots={},slotIndex=1,optionIndex=1,categoryIndex=1,profilePage=1,itemPage=1,rows={},draft={},dirty=false,
        options={},categories={},undo={},redo={},sort="favourites",usableOnly=false,favouritesOnly=false,facing=0,zoom=1}
    ui.transmog=state
    Text(panel,"FOREVER WARDROBE","GameFontNormalLarge",16,-18,310)
    Text(panel,"Choose a set, pick appearances, save, then load at the vendor","GameFontHighlightSmall",352,-22,600)
    Text(panel,"Set name","GameFontHighlightSmall",16,-54,180)
    local dirtyText=Text(panel,"","GameFontHighlightSmall",16,-38,180)
    local selectedSlotText=Text(panel,"","GameFontNormal",212,-60,310)
    local summary=Text(panel,"","GameFontHighlightSmall",16,-548,180)
    summary:SetHeight(24)
    local selectedText=Text(panel,"","GameFontHighlightSmall",540,-592,248)
    selectedText:SetMaxLines(1)
    local message=Text(panel,"","GameFontHighlightSmall",212,-656,742)
    message:SetMaxLines(1)
    local count=Text(panel,"","GameFontHighlightSmall",540,-198,414)
    state.countLabel=count
    local function Say(text) message:SetText(text or "") end
    state.say=Say
    local function Action(label,x,y,width,callback,height)
        local b=Button(panel,label,width,height or 28); b:SetPoint("TOPLEFT",x,y)
        b:SetScript("OnClick",function() if not InCombatLockdown() then callback() end end)
        state.actions=state.actions or {}; state.actions[label]=b
        return b
    end
    local function Input(x,y,width,maxLetters)
        local box=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        box:SetPoint("TOPLEFT",x,y); box:SetSize(width,28); box:SetFontObject("GameFontHighlightSmall")
        box:SetAutoFocus(false); box:SetMaxLetters(maxLetters or 60)
        box:SetScript("OnEscapePressed",function(self) self:ClearFocus(); NS.Close() end)
        box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
        return box
    end
    local name,query=Input(22,-72,168),Input(546,-148,402,80)
    state.nameBox,state.query=name,query
    Text(panel,"Search appearances by name or ID","GameFontHighlightSmall",540,-38,414)
    local function Dirty()
        local saved=state.profileID and NS.db.transmogProfiles[state.profileID]
        state.dirty=not (saved and saved.name==name:GetText() and T.SameSlots(state.draft,saved.slots))
        if not state.profileID and name:GetText()=="" and not next(state.draft) then state.dirty=false end
        state.deleteArmed=nil
        local changes=0
        for slot,choice in pairs(state.draft) do if not saved or not saved.slots[slot] or not T.SameSlots({[slot]=choice},{[slot]=saved.slots[slot]}) then changes=changes+1 end end
        for slot in pairs(saved and saved.slots or {}) do if not state.draft[slot] then changes=changes+1 end end
        dirtyText:SetText(state.dirty and ("|cffffb347"..changes.." slot changes · unsaved|r") or state.profileID and "Saved / ready" or "New set")
    end
    local function CanLeave()
        if state.dirty then Say("Save changes or Revert changes before switching sets."); return false end
        return true
    end
    local popup=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    popup:SetFrameLevel(panel:GetFrameLevel()+60); popup:EnableMouse(true); Panel(popup)
    local popupTitle=Text(popup,"","GameFontNormal",10,-10,390)
    local popupRows,popupEntries,popupCallback,popupPage={}, {},nil,1
    local popupPages=Text(popup,"","GameFontHighlightSmall",94,-327,210)
    local function ClosePopup() if not InCombatLockdown() then popup:Hide() end end
    local function PopupPage()
        local pages=math.max(1,math.ceil(#popupEntries/12)); popupPage=math.max(1,math.min(popupPage,pages))
        popupPages:SetText(popupPage.." / "..pages)
        for i,row in ipairs(popupRows) do
            row.entry=popupEntries[(popupPage-1)*12+i]; row:SetShown(row.entry~=nil)
            if row.entry then row.label:SetText(row.entry.name or tostring(row.entry.id)) end
        end
    end
    for i=1,12 do
        local row=Button(popup,"",390,23,"row"); row:SetPoint("TOPLEFT",8,-35-(i-1)*23)
        row:SetScript("OnClick",function(self)
            if InCombatLockdown() or not self.entry then return end
            local entry=self.entry; ClosePopup(); popupCallback(entry)
        end)
        popupRows[i]=row
    end
    local function PopupAction(label,x,fn)
        local b=Button(popup,label,54,24); b:SetPoint("TOPLEFT",x,-318)
        b:SetScript("OnClick",function() if not InCombatLockdown() then fn() end end)
    end
    PopupAction("<",8,function() popupPage=popupPage-1; PopupPage() end)
    PopupAction(">",340,function() popupPage=popupPage+1; PopupPage() end)
    local popupClose=Button(popup,"X",26,24); popupClose:SetPoint("TOPRIGHT",-6,-4)
    popupClose:SetScript("OnClick",ClosePopup)
    local function Choose(title,entries,callback)
        ClosePopup(); popupEntries,popupCallback,popupPage=entries,callback,1
        popup:ClearAllPoints(); popup:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-12,-45); popup:SetSize(410,350)
        popupTitle:SetText(title); PopupPage(); popup:Show()
    end
    state.choose=Choose
    state.pickerRows=popupRows
    local infoPanel=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    state.infoPanel=infoPanel
    infoPanel:SetPoint("TOPLEFT",208,-54); infoPanel:SetSize(748,548)
    infoPanel:SetFrameLevel(panel:GetFrameLevel()+50); infoPanel:EnableMouse(true); Panel(infoPanel)
    local infoTitle=Text(infoPanel,"","GameFontNormalLarge",16,-16,620)
    local infoScroll=CreateFrame("ScrollFrame",nil,infoPanel,"UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT",16,-52); infoScroll:SetSize(694,478)
    local infoBody=CreateFrame("Frame",nil,infoScroll); infoBody:SetSize(684,478)
    local infoText=Text(infoBody,"","GameFontHighlight",0,0,680); infoScroll:SetScrollChild(infoBody)
    local infoBack=Button(infoPanel,"Back",76,28); infoBack:SetPoint("TOPRIGHT",-12,-10)
    infoBack:SetScript("OnClick",function() if not InCombatLockdown() then infoPanel:Hide() end end)
    local function ShowInfo(title,text)
        ClosePopup(); infoTitle:SetText(title); infoText:SetText(text)
        infoBody:SetHeight(math.max(478,(infoText:GetStringHeight() or 478)+8)); infoScroll:SetVerticalScroll(0); infoPanel:Show()
    end
    infoPanel:Hide(); popup:Hide()
    local backdrop=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    backdrop:SetPoint("TOPLEFT",208,-88); backdrop:SetSize(324,344); Panel(backdrop)
    local ok,model=pcall(CreateFrame,"DressUpModel",nil,panel)
    if ok and model then
        state.model=model; model:SetPoint("TOPLEFT",246,-90); model:SetSize(248,390)
        model:SetPortraitZoom(0); model:SetCamDistanceScale(1)
    else model=nil; Text(panel,"3D preview unavailable","GameFontHighlight",250,-210,240) end
    local slotButtons={}
    local profilePages=Text(panel,"","GameFontHighlightSmall",82,-372,90)
    local itemPages=Text(panel,"","GameFontHighlightSmall",700,-532,120)
    local Browse,Profiles,RefreshPreview,RenderItems
    local function Current() return state.slots[state.slotIndex] end
    local function PushUndo()
        state.undo[#state.undo+1]=T.CopySlots(state.draft); if #state.undo>20 then table.remove(state.undo,1) end
        state.redo={}; state.compareWorn=false
    end
    local function Pick(row)
        local slot=Current(); if not slot then return end
        PushUndo(); state.draft[slot.slot]={sourceID=row.sourceID,option=row.option}; state.focus=row; Dirty(); RefreshPreview(); RenderItems()
    end
    local function UpdateSlots()
        local overrides=0; for _ in pairs(state.draft) do overrides=overrides+1 end
        summary:SetText(overrides.." appearance overrides")
        for i,b in ipairs(slotButtons) do
            local slot=state.slots[i]; b:SetShown(slot~=nil); b.slot=slot
            if slot then
                local choice=state.draft[slot.slot]; local source=choice and T.Source(choice.sourceID)
                b.icon:SetTexture(source and source.icon or slot.icon)
                b:SetBackdropColor(i==state.slotIndex and 0.35 or 0.10,i==state.slotIndex and 0.25 or 0.10,0.05,1)
                b.mark:SetText(choice and "+" or "")
                b:SetBackdropBorderColor(i==state.slotIndex and 1 or 0.3,i==state.slotIndex and 0.82 or 0.3,0.1,1)
            end
        end
    end
    RefreshPreview=function()
        if InCombatLockdown() then return end
        local draft=state.compareWorn and {} or state.draft
        state.previewFailed=not model or not T.Preview(model,draft,true)
        if model then model:SetFacing(state.facing); model:SetCamDistanceScale(state.zoom) end
        local slot=Current(); local choice=slot and state.draft[slot.slot]; local source=choice and T.Source(choice.sourceID)
        selectedSlotText:SetText((state.compareWorn and "Comparing worn look · " or "Preview · ")..(slot and slot.name or "Choose a slot"))
        selectedText:SetText(choice and ("Selected: "..(source and source.name or ("Appearance "..choice.sourceID))) or "Selected: keep current appearance")
        UpdateSlots()
        if state.compare then state.compare.label:SetText(state.compareWorn and "Showing: Worn" or "Showing: Edited") end
    end
    if model then
        model:SetScript("OnModelLoaded",function() if ui:IsShown() and panel:IsShown() then RefreshPreview() end end)
        model:EnableMouseWheel(true)
        model:EnableMouse(true)
        model:SetScript("OnMouseDown",function(_,button)
            if not InCombatLockdown() and button=="LeftButton" then state.dragX=GetCursorPosition() end
        end)
        model:SetScript("OnMouseUp",function() state.dragX=nil end)
        model:SetScript("OnHide",function() state.dragX=nil end)
        model:SetScript("OnUpdate",function()
            if not state.dragX then return end
            if InCombatLockdown() or not IsMouseButtonDown("LeftButton") then state.dragX=nil; return end
            local x=GetCursorPosition()
            state.facing=state.facing+(x-state.dragX)*0.015; state.dragX=x; model:SetFacing(state.facing)
        end)
        model:SetScript("OnMouseWheel",function(_,delta)
            if InCombatLockdown() then return end
            state.zoom=math.max(0.5,math.min(1.6,state.zoom-delta*0.1)); model:SetCamDistanceScale(state.zoom)
        end)
    end
    for i=1,16 do
        local b=Button(panel,"",32,32,"row")
        b:SetPoint("TOPLEFT",i<=8 and 212 or 494,-98-((i-1)%8)*40)
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(27,27); b.icon:SetPoint("CENTER")
        b.mark=Text(b,"","GameFontNormal",22,-18,10)
        local index=i
        b:SetScript("OnClick",function() if not InCombatLockdown() and state.slots[index] then state.slotIndex=index; state.focus=nil; Browse(true) end end)
        b:SetScript("OnEnter",function(self)
            if self.slot then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.slot.name)
                local choice=state.draft[self.slot.slot]; local source=choice and T.Source(choice.sourceID)
                GameTooltip:AddLine(source and source.name or "Keep current appearance",1,1,1); GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        slotButtons[i]=b
    end
    state.slotButtons=slotButtons
    local slotButton=Action("Slot",540,-54,202,function()
        local entries={}; for i,slot in ipairs(state.slots) do entries[#entries+1]={id=i,name=slot.name} end
        Choose("Select equipment slot",entries,function(entry) state.slotIndex=entry.id; state.focus=nil; Browse(true) end)
    end)
    local optionButton=Action("All available types",752,-54,202,function()
        local entries={{id=0,name="All available types"}}
        for i,option in ipairs(state.options) do entries[#entries+1]={id=i,name=option.name} end
        Choose("Select appearance type",entries,function(entry) state.optionIndex=entry.id; state.focus=nil; Browse() end)
    end)
    local categoryButton=Action("All categories",540,-92,188,function()
        local entries={{id=0,name="All available categories"}}
        for i,category in ipairs(state.categories) do entries[#entries+1]={id=i,name=category.name} end
        Choose("Select weapon category",entries,function(entry) state.categoryIndex=entry.id; state.focus=nil; Browse() end)
    end)
    local sortButton=Action("Favourites first",738,-92,104,function()
        state.sort=state.sort=="favourites" and "name" or "favourites"; Browse()
    end)
    state.favouritesFilter=Action("All favourites",850,-92,104,function() state.favouritesOnly=not state.favouritesOnly; Browse() end)
    local collectedButton=Action("All collected",850,-180,104,function() state.usableOnly=not state.usableOnly; Browse() end)
    count:SetWidth(300)
    state.slotButton,state.optionButton,state.categoryButton=slotButton,optionButton,categoryButton
    state.itemButtons={}
    RenderItems=function()
        local pages=math.max(1,math.ceil(#state.rows/6)); state.itemPage=math.max(1,math.min(state.itemPage,pages))
        itemPages:SetText(state.itemPage.." / "..pages)
        for i,b in ipairs(state.itemButtons) do
            local row=state.rows[(state.itemPage-1)*6+i]; b.item=row; b:SetShown(row~=nil)
            if row then
                b.icon:SetTexture(row.icon); b.label:SetText((NS.db.transmogFavourites[row.visualID] and "* " or "")..row.name)
                b.label:SetTextColor(row.usable==true and 1 or 0.65,row.usable==true and 0.82 or 0.65,row.usable==true and 0 or 0.65)
                b.detail:SetText((row.usable==true and "Collected" or "Collected · preview only")..(#row.alternatives>1 and (" · "..#row.alternatives.." variants") or ""))
                local chosen=Current() and state.draft[Current().slot]
                local selected=false
                for _,alternative in ipairs(row.alternatives) do
                    if chosen and chosen.sourceID==alternative.sourceID and chosen.option==alternative.option then selected=true; break end
                end
                b:SetBackdropColor(selected and 0.30 or 0.10,selected and 0.23 or 0.10,selected and 0.04 or 0.10,0.9)
                b.label:SetText((selected and "> " or "")..row.name)
                if b.star then
                    b.star.icon:SetDesaturated(not NS.db.transmogFavourites[row.visualID])
                    b.star.icon:SetAlpha(NS.db.transmogFavourites[row.visualID] and 1 or 0.4)
                end
            end
        end
        count:SetText(#state.rows.." appearances · "..(state.diagnostics and state.diagnostics.unique or 0).." owned before local filters")
        if state.favourite then state.favourite.label:SetText(state.focus and NS.db.transmogFavourites[state.focus.visualID] and "Unstar appearance" or "Star appearance") end
        if state.variants then state.variants:SetShown(state.focus~=nil and #state.focus.alternatives>1) end
        if state.sources then state.sources:SetShown(state.focus~=nil) end
        if state.wowhead then state.wowhead:SetShown(state.focus~=nil) end
    end
    for i=1,6 do
        local b=Button(panel,"",414,48,"row"); b:SetPoint("TOPLEFT",540,-220-(i-1)*50)
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(36,36); b.icon:SetPoint("LEFT",6,0)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel",function(_,delta) if not InCombatLockdown() then state.itemPage=state.itemPage-(delta>0 and 1 or -1); RenderItems() end end)
        b.star=CreateFrame("Button",nil,b,"UIPanelButtonTemplate"); b.star:SetSize(28,26); b.star:SetPoint("TOPRIGHT",-5,-5)
        b.star.icon=b.star:CreateTexture(nil,"ARTWORK"); b.star.icon:SetSize(16,16); b.star.icon:SetPoint("CENTER")
        b.star.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        b.star:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(b.item and NS.db.transmogFavourites[b.item.visualID] and "Remove favourite" or "Add favourite")
            GameTooltip:Show()
        end)
        b.star:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b.star:SetScript("OnClick",function() if not InCombatLockdown() and b.item then T.ToggleFavourite(b.item.visualID); state.pendingFocusID=b.item.visualID; Browse() end end)
        b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT",50,-7); b.label:SetWidth(318); b.label:SetJustifyH("LEFT")
        b.detail=Text(b,"","GameFontHighlightSmall",50,-28,354); b.detail:SetMaxLines(1)
        b:SetScript("OnClick",function(self) if not InCombatLockdown() and self.item then Pick(self.item) end end)
        b:SetScript("OnEnter",function(self)
            if not self.item then return end
            local row=self.item; GameTooltip:SetOwner(self,"ANCHOR_LEFT")
            if row.link or row.itemID then GameTooltip:SetHyperlink(row.link or ("item:"..row.itemID)) else GameTooltip:AddLine(row.name) end
            GameTooltip:AddLine(row.usable==true and "Collected · usable" or (row.reason or "Usability unknown"),1,0.82,0)
            GameTooltip:AddLine("Source "..row.sourceID.." · visual "..row.visualID.." · item "..tostring(row.itemID or "unknown"),0.7,0.7,0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        state.itemButtons[i]=b
    end
    local function ScheduleRefresh()
        if state.refreshQueued or not ui:IsShown() or not panel:IsShown() or InCombatLockdown() then return end
        state.refreshQueued=true
        C_Timer.After(0.25,function()
            state.refreshQueued=false
            if ui:IsShown() and panel:IsShown() and not InCombatLockdown() then
                if state.browsing then state.refreshAfter=true else Browse() end
            end
        end)
    end
    Browse=function(reset)
        if InCombatLockdown() then return end
        NS.CancelWork("transmogBrowser"); state.browsing=false
        state.options=Current() and T.Options(Current()) or {}; state.categories=Current() and T.Categories(Current()) or {}
        if reset then state.optionIndex,state.categoryIndex,state.itemPage=0,0,1 end
        local slot,option,category=Current(),state.options[state.optionIndex],state.categories[state.categoryIndex]
        slotButton.label:SetText(slot and slot.name.." v" or "Choose slot v")
        optionButton.label:SetText((option and option.name or "All available types").." v")
        categoryButton.label:SetText((category and category.name or "All categories").." v")
        categoryButton:SetShown(#state.categories>1)
        sortButton.label:SetText("Sort: "..(state.sort=="favourites" and "Favourites first" or "Name A–Z"))
        state.favouritesFilter.label:SetText((state.favouritesOnly and "[On] " or "[Off] ").."Favourites only")
        collectedButton.label:SetText((state.usableOnly and "[On] " or "[Off] ").."Usable only")
        state.focus=nil; state.rows={}; state.diagnostics=nil; RenderItems(); RefreshPreview()
        if not slot or #state.options==0 or #state.categories==0 then Say("Slot data unavailable. Open Blizzard's wardrobe, then Refresh collection."); return end
        state.browsing=true; Say("Loading collected appearances across available types…")
        local preferences={sort=state.sort,usableOnly=state.usableOnly,favouritesOnly=state.favouritesOnly}
        local search=query:GetText()
        NS.RunWork("transmogBrowser",function() return T.Browse(slot,option and option.id,category and category.id,search,preferences) end,function(rows)
            state.rows,state.diagnostics,state.browsing=rows,rows.diagnostics,false
            if state.pendingFocusID then
                for _,row in ipairs(rows) do if row.visualID==state.pendingFocusID then state.focus=row; break end end
                state.pendingFocusID=nil
            end
            RenderItems()
            Say(state.previewFailed and "Preview incomplete; selected IDs remain saved. Use Blizzard's preview to verify." or
                "Your collection filters are unchanged. Preview-only pieces cannot bypass vendor restrictions.")
            if state.refreshAfter then state.refreshAfter=false; ScheduleRefresh() end
        end,function() state.browsing=false; Say("Collection data unavailable. Refresh to retry; no native settings were changed.") end)
    end
    state.browse=Browse
    query:SetScript("OnTextChanged",function() if ui:IsShown() and panel:IsShown() and not InCombatLockdown() then state.itemPage=1; Browse() end end)
    name:SetScript("OnTextChanged",function() if not state.loading then Dirty() end end)
    Action("<",540,-524,32,function() state.itemPage=state.itemPage-1; RenderItems() end)
    Action(">",922,-524,32,function() state.itemPage=state.itemPage+1; RenderItems() end)
    state.favourite=Action("Star appearance",540,-558,126,function()
        local row=state.focus
        if not row then Say("Choose an appearance row first."); return end
        local _,err=T.ToggleFavourite(row.visualID); if err then Say(err) else state.pendingFocusID=row.visualID; Browse() end
    end)
    local function FindSources(row)
        if not row or not row.itemID then Say("No item ID is available for this appearance source."); return end
        NS.OpenSavedSearch("item",row.itemID)
    end
    state.sources=Action("Find sources",674,-558,126,function() FindSources(state.focus) end)
    state.wowhead=Action("Copy Wowhead link",800,-590,154,function()
        local ok,message=NS.ShowAppearanceWowhead(state.focus)
        if not ok then Say(message or "Select an appearance with a known item ID.") end
    end)
    state.variants=Action("Choose variant",808,-558,146,function()
        if not state.focus then Say("Choose an appearance row first."); return end
        local entries={}
        for _,row in ipairs(state.focus.alternatives) do
            local typeName="Type "..row.option
            for _,option in ipairs(state.options) do if option.id==row.option then typeName=option.name; break end end
            entries[#entries+1]={name=row.name.." · "..typeName..(row.usable==true and "" or " · preview only"),row=row}
        end
        local alternatives=state.focus.alternatives
        Choose("Alternate sources for this appearance",entries,function(entry)
            local row={alternatives=alternatives}; for key,value in pairs(entry.row) do row[key]=value end
            Pick(row)
        end)
    end)
    local function Load(profile)
        state.profileID=profile and profile.id or nil; state.draft=T.CopySlots(profile and profile.slots)
        state.loading=true; name:SetText(profile and profile.name or ""); state.loading=false
        state.undo,state.redo,state.dirty,state.deleteArmed={}, {},false,nil; dirtyText:SetText("Saved / ready")
        ClosePopup(); state.compareWorn=false; Browse(true)
    end
    Profiles=function()
        local rows={}
        for id,profile in pairs(NS.db.transmogProfiles) do
            if T.ValidID(id) and type(profile)=="table" and NS.CleanName(profile.name) and type(profile.slots)=="table" then rows[#rows+1]={id=id,name=profile.name,slots=profile.slots} end
        end
        table.sort(rows,function(a,b) return a.name==b.name and a.id<b.id or a.name<b.name end)
        local pages=math.max(1,math.ceil(#rows/6)); state.profilePage=math.max(1,math.min(state.profilePage,pages))
        profilePages:SetText(state.profilePage.." / "..pages)
        for i,b in ipairs(state.profileButtons) do
            b.profile=rows[(state.profilePage-1)*6+i]; b:SetShown(b.profile~=nil)
            if b.profile then b.label:SetText((b.profile.id==state.profileID and "> " or "")..b.profile.name) end
        end
    end
    state.profileButtons={}
    for i=1,6 do
        local b=Button(panel,"",180,38,"row"); b:SetPoint("TOPLEFT",16,-112-(i-1)*40)
        b:SetScript("OnClick",function(self) if not InCombatLockdown() and self.profile and CanLeave() then Load(self.profile); Profiles() end end)
        state.profileButtons[i]=b
    end
    Action("<",16,-364,32,function() state.profilePage=state.profilePage-1; Profiles() end)
    Action(">",164,-364,32,function() state.profilePage=state.profilePage+1; Profiles() end)
    state.capture=Action("Capture current look",16,-400,180,function()
        local slots,err=T.Capture(); if not slots then Say(err); return end
        PushUndo(); state.draft=slots; Dirty(); Browse(true)
    end)
    state.save=Action("Save profile",16,-436,180,function()
        local id,err=T.Save(state.profileID,name:GetText(),state.draft)
        if not id then Say(err); return end
        state.profileID,state.deleteArmed=id,nil; Dirty(); Profiles(); Say("Set saved. At the transmogrifier, open Forever sets to load it.")
    end)
    state.new=Action("New",16,-472,86,function() if CanLeave() then Load(nil); Profiles() end end)
    state.copy=Action("Copy",110,-472,86,function()
        if not CanLeave() then return end
        state.profileID=nil; state.loading=true; name:SetText(name:GetText():sub(1,53).." Copy"); state.loading=false
        Dirty(); Profiles(); Say("Name and Save the copied profile.")
    end)
    state.delete=Action("Delete",16,-508,86,function()
        if not state.profileID then Say("Select a saved profile first."); return end
        if state.deleteArmed~=state.profileID then state.deleteArmed=state.profileID; Say("Click Delete again to permanently remove this addon profile."); return end
        T.Delete(state.profileID); Load(nil); Profiles()
    end)
    state.discard=Action("Discard",110,-508,86,function() Load(state.profileID and NS.db.transmogProfiles[state.profileID]); Profiles() end)
    state.diagnosticsButton=Action("Collection diagnostics",16,-576,180,function()
        local d=state.diagnostics or {}
        ShowInfo("Collection diagnostics",string.format("Client entries returned: %d\nUnique owned visuals: %d\nPreview-only / unknown-usability source entries: %d\nUncollected entries excluded: %d\nUnreadable / unavailable data: %d\nUnavailable API queries: %d\nUnsupported type/category combinations skipped: %d\nHidden by search or Usable only: %d\nHidden by Starred only: %d\nVisible appearances: %d\n\nCounts combine the selected available types and categories; raw client entries can repeat across types.\n\nBlizzard's class/race/source/search filters can exclude appearances before the API returns them. These counts cannot measure entries the client did not expose. This addon never changes those filters.\n\nTry All available types, All collected, clearing the local search, and Refresh collection. Newly unlocked/cache-ready data refreshes automatically while this page is visible.\n\nCollected does not mean usable by every character. Vendor loading still validates every selected source and requires Blizzard's final confirmation.",d.returned or 0,d.unique or 0,d.restricted or 0,d.uncollected or 0,d.unknown or 0,d.apiFailures or 0,d.unsupported or 0,d.queryHidden or 0,d.favouriteHidden or 0,#state.rows))
    end)
    state.checklist=Action("Outfit checklist",16,-610,180,function()
        local lines={name:GetText()~="" and name:GetText() or "Unsaved outfit",""}
        for _,slot in ipairs(state.slots) do
            local choice=state.draft[slot.slot]; local source=choice and T.Source(choice.sourceID)
            lines[#lines+1]=slot.name..": "..(choice and (source and source.name or ("Appearance "..choice.sourceID)) or "Keep current")
            if choice then lines[#lines+1]="  "..(source and source.collected and "Collected" or "Ownership unknown/unavailable")..(source and source.usable==true and " · usable" or " · verify at vendor").." · source "..choice.sourceID end
        end
        ShowInfo("Outfit checklist",table.concat(lines,"\n"))
    end)
    Action("Rotate left",212,-444,100,function() state.facing=state.facing-0.4; RefreshPreview() end)
    Action("Reset view",320,-444,100,function() state.facing,state.zoom=0,1; RefreshPreview() end)
    Action("Rotate right",428,-444,100,function() state.facing=state.facing+0.4; RefreshPreview() end)
    Action("Zoom +",212,-480,66,function() state.zoom=math.max(0.5,state.zoom-0.1); RefreshPreview() end)
    Action("Zoom −",284,-480,66,function() state.zoom=math.min(1.6,state.zoom+0.1); RefreshPreview() end)
    state.compare=Action("Compare worn / draft",358,-480,170,function() state.compareWorn=not state.compareWorn; RefreshPreview() end)
    state.refresh=Action("Refresh collection",212,-516,150,function()
        local current=Current() and Current().slot; state.slots=T.Slots()
        for i,slot in ipairs(state.slots) do if slot.slot==current then state.slotIndex=i end end
        state.slotIndex=math.min(state.slotIndex,math.max(1,#state.slots)); Browse()
    end)
    state.undoButton=Action("Undo piece",370,-516,76,function()
        if #state.undo==0 then Say("No appearance edits to undo."); return end
        state.redo[#state.redo+1]=T.CopySlots(state.draft); state.draft=table.remove(state.undo); state.compareWorn=false; Dirty(); RefreshPreview(); RenderItems()
    end)
    state.redoButton=Action("Redo piece",454,-516,76,function()
        if #state.redo==0 then Say("No appearance edits to redo."); return end
        state.undo[#state.undo+1]=T.CopySlots(state.draft); state.draft=table.remove(state.redo); state.compareWorn=false; Dirty(); RefreshPreview(); RenderItems()
    end)
    state.stage=Action("Use in transmog screen",212,-552,318,function()
        if state.dirty then Say("Save your profile before preparing it at the vendor."); return end
        if not state.profileID then Say("Select a saved profile first."); return end
        NS.vendorProfileID=state.profileID
        NS.Close()
        local _,msg=NS.OpenVendorProfiles(state.profileID)
        NS.Print(msg)
    end,32)
    state.clearSlot=Action("Keep current for slot",212,-590,318,function()
        local slot=Current(); if slot then PushUndo(); state.draft[slot.slot]=nil; Dirty(); RefreshPreview(); RenderItems() end
    end)
    -- Keep the three daily tasks visible: build a set, compare it, save it.
    local function Place(button,x,y,width,label)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",x,y); button:SetWidth(width)
        button.label:SetWidth(width-14); if label then button.label:SetText(label) end
    end
    backdrop:SetHeight(396)
    for _,label in ipairs({"Rotate left","Rotate right","Zoom +","Zoom −"}) do state.actions[label]:Hide() end
    Place(state.actions["Reset view"],212,-490,108)
    Place(state.compare,330,-490,198,"Showing: Edited")
    Place(state.undoButton,212,-526,150,"Undo appearance")
    Place(state.redoButton,378,-526,150,"Redo appearance")
    Place(state.clearSlot,212,-562,318,"Use worn appearance for this slot")
    Place(state.new,16,-400,180,"New set")
    Place(state.save,790,-616,164,"Save changes")
    Place(state.discard,616,-616,164,"Revert changes")
    Place(state.stage,212,-616,394,"Load a saved set at the vendor")
    state.capture:Hide(); state.copy:Hide(); state.delete:Hide(); state.diagnosticsButton:Hide(); state.checklist:Hide(); state.refresh:Hide(); state.favourite:Hide()
    summary:ClearAllPoints(); summary:SetPoint("TOPLEFT",16,-522)
    selectedText:ClearAllPoints(); selectedText:SetPoint("TOPLEFT",540,-592); selectedText:SetWidth(414)
    Place(state.sources,540,-558,126)
    Place(state.variants,674,-558,126,"Variants")
    Place(state.wowhead,808,-558,146,"Wowhead link")
    local function Invoke(button) button:GetScript("OnClick")(button) end
    state.setMenu=Action("Set actions...",16,-436,180,function()
        Choose("Set actions",{{name="Rename set",rename=true},{name="Duplicate set",button=state.copy},
            {name="Capture current look",button=state.capture},{name="Delete set…",button=state.delete}},function(entry)
            if entry.rename then name:SetFocus(); name:HighlightText() else Invoke(entry.button) end
        end)
    end)
    state.helpMenu=Action("Help / More...",16,-472,180,function()
        Choose("Wardrobe tools",{{name="Outfit checklist",button=state.checklist},{name="Refresh collection",button=state.refresh},
            {name="Collection diagnostics",button=state.diagnosticsButton}},function(entry) Invoke(entry.button) end)
    end)
    Text(panel,"Drag model to rotate · scroll to zoom","GameFontHighlightSmall",212,-75,318)
    -- Search comes before slot/type filtering.
    query:ClearAllPoints(); query:SetPoint("TOPLEFT",546,-54)
    Place(slotButton,540,-96,202)
    Place(optionButton,752,-96,202)
    Place(categoryButton,540,-130,130)
    Place(sortButton,678,-130,276)
    sortButton:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        Choose("Sort appearances",{{id="favourites",name="Favourites first"},{id="name",name="Name A–Z"}},function(entry) state.sort=entry.id; Browse() end)
    end)
    Place(state.favouritesFilter,540,-164,202)
    Place(collectedButton,752,-164,202)
    local events=CreateFrame("Frame")
    for _,event in ipairs({"TRANSMOG_COLLECTION_UPDATED","TRANSMOG_COLLECTION_ITEM_UPDATE","TRANSMOG_COLLECTION_SOURCE_ADDED","TRANSMOG_COLLECTION_SOURCE_REMOVED","TRANSMOG_SEARCH_UPDATED","TRANSMOGRIFY_OPEN","GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP"}) do pcall(events.RegisterEvent,events,event) end
    events:SetScript("OnEvent",function(_,event,itemID)
        if event=="GET_ITEM_INFO_RECEIVED" and not (NS.Readable(itemID) and (T.pendingItems[itemID] or state.diagnostics and state.diagnostics.pendingItems[itemID])) then return end
        ScheduleRefresh()
    end)
    state.events=events
    function NS.ShowSearchPage()
        if InCombatLockdown() then return end
        if ui.choiceMenu then ui.choiceMenu:Hide() end
        if ui.wowhead then ui.wowhead.panel:Hide() end
        ClosePopup(); infoPanel:Hide(); panel:Hide(); ui.searchPage:Show(); ui:SetSize(780,710)
        NS.CancelWork("transmogBrowser"); state.browsing=false
        if state.searchTab then state.searchTab:SetChecked(true); state.transmogTab:SetChecked(false) end
    end
    function NS.ShowTransmogPage()
        if InCombatLockdown() then NS.SetStatus("Open transmog profiles after combat."); return end
        if ui.choiceMenu then ui.choiceMenu:Hide() end
        if ui.wowhead then ui.wowhead.panel:Hide() end
        ClosePopup(); infoPanel:Hide(); ui.search:ClearFocus(); ui.github:ClearFocus()
        ui.searchPage:Hide(); ui:SetSize(1020,792); panel:Show()
        if model then T.Preview(model,state.compareWorn and {} or state.draft) end
        state.slots=T.Slots(); state.slotIndex=math.min(state.slotIndex,math.max(1,#state.slots))
        Profiles(); Dirty(); Browse(true); state.searchTab:SetChecked(false); state.transmogTab:SetChecked(true)
    end
    for i,info in ipairs({{"Search","Interface\\Icons\\INV_Misc_Spyglass_03",NS.ShowSearchPage},{"Forever Wardrobe","Interface\\Icons\\INV_Chest_Cloth_17",NS.ShowTransmogPage}}) do
        local good,tab=pcall(CreateFrame,"CheckButton",nil,ui,"RightSideTabTemplate")
        if not good or not tab then tab=CreateFrame("CheckButton",nil,ui,"UICheckButtonTemplate") end
        tab:SetSize(36,42); tab:SetPoint("TOPLEFT",ui,"TOPRIGHT",-1,-90-(i-1)*48); tab:SetFrameLevel(ui:GetFrameLevel()+10)
        local icon=tab:CreateTexture(nil,"ARTWORK"); icon:SetSize(26,26); icon:SetPoint("CENTER"); icon:SetTexture(info[2])
        local label,callback,index=info[1],info[3],i
        tab:SetScript("OnClick",function() if InCombatLockdown() then tab:SetChecked(panel:IsShown() and index==2 or not panel:IsShown() and index==1); return end; callback() end)
        tab:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(label); GameTooltip:Show() end)
        tab:SetScript("OnLeave",function() GameTooltip:Hide() end)
        if i==1 then state.searchTab=tab else state.transmogTab=tab end
    end
    panel:SetScript("OnHide",function() name:ClearFocus(); query:ClearFocus(); state.dragX=nil; NS.CancelWork("transmogBrowser"); state.browsing=false end)
    panel:Hide(); state.searchTab:SetChecked(true); state.transmogTab:SetChecked(false)
end
