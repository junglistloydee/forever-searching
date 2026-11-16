local _,NS=...
local T=NS.Transmog
local function Stack(state)
    local native=state.native
    local strata=type(native.GetFrameStrata)=="function" and native:GetFrameStrata()
    local layer=NS.Readable(strata) and (strata=="FULLSCREEN" or strata=="FULLSCREEN_DIALOG") and "FULLSCREEN_DIALOG" or "DIALOG"
    local level=type(native.GetFrameLevel)=="function" and native:GetFrameLevel()
    level=NS.Readable(level) and type(level)=="number" and level>=0 and level<100000 and level+20 or 100
    if state.layer~=layer or state.level~=level then
        state.button:SetFrameStrata(layer); state.button:SetFrameLevel(level)
        state.panel:SetFrameStrata(layer); state.panel:SetFrameLevel(level+1)
        state.layer,state.level=layer,level
    end
end

function NS.AttachVendorProfiles()
    if InCombatLockdown() or not TransmogFrame then return false end
    if NS.vendorProfiles and NS.vendorProfiles.native==TransmogFrame then
        Stack(NS.vendorProfiles)
        NS.vendorProfiles.button:SetShown(TransmogFrame:IsShown())
        return true
    end
    if NS.vendorProfiles then NS.vendorProfiles.button:Hide(); NS.vendorProfiles.panel:Hide() end
    local native=TransmogFrame
    local state={native=native,rows={},page=1}
    NS.vendorProfiles=state
    -- Independent overlay: only our frames are positioned/styled. Never
    -- reparent, resize, hook, hide or replace scripts on Blizzard's window.
    local button=CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate")
    state.button=button
    button:SetPoint("TOPRIGHT",native,"TOPRIGHT",-24,-30); button:SetSize(154,24); button:SetText("Forever sets")
    button:SetFrameStrata("DIALOG"); button:SetFrameLevel(100); button:SetClampedToScreen(true)
    local panel=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    state.panel=panel
    panel:SetPoint("TOPRIGHT",button,"BOTTOMRIGHT",0,-5); panel:SetSize(334,360)
    panel:SetFrameStrata("DIALOG"); panel:SetFrameLevel(101); panel:SetClampedToScreen(true); panel:EnableMouse(true)
    panel:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    panel:SetBackdropColor(0.045,0.035,0.025,0.98); panel:SetBackdropBorderColor(0.6,0.47,0.18,1)
    local function Text(text,font,x,y,width)
        local t=panel:CreateFontString(nil,"OVERLAY",font)
        t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetText(text)
        return t
    end
    Text("Forever Searching · saved sets","GameFontNormal",14,-15,280)
    Text("Choose a saved profile. Load only previews it;\nconfirm cost and application with Save Outfit.","GameFontHighlightSmall",14,-41,306)
    state.status=Text("","GameFontHighlightSmall",14,-279,306); state.status:SetHeight(62)
    local pages=Text("","GameFontHighlightSmall",142,-255,80)
    local function Button(text,width,x,y)
        local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",x,y); b:SetSize(width,24); b:SetText(text)
        return b
    end
    state.close=Button("X",24,300,-8)
    state.close:SetScript("OnClick",function() if not InCombatLockdown() then panel:Hide() end end)
    state.prev=Button("<",30,14,-246)
    state.next=Button(">",30,288,-246)
    state.load=Button("Load into preview",174,14,-210)
    state.refreshButton=Button("Refresh",118,200,-210)
    local function Status(text) state.status:SetText(text) end
    state.refresh=function()
        if InCombatLockdown() then return end
        local entries={}
        for id,profile in pairs(NS.db.transmogProfiles) do
            if T.ValidID(id) and type(profile)=="table" and NS.CleanName(profile.name) and type(profile.slots)=="table" then
                entries[#entries+1]={id=id,name=profile.name,slots=profile.slots}
            end
        end
        table.sort(entries,function(a,b) return a.name==b.name and a.id<b.id or a.name<b.name end)
        if NS.vendorProfileID and not NS.db.transmogProfiles[NS.vendorProfileID] then NS.vendorProfileID=nil end
        state.page=math.max(1,math.min(state.page,math.max(1,math.ceil(#entries/5))))
        for i,row in ipairs(state.rows) do
            local entry=entries[(state.page-1)*5+i]
            row.entry=entry; row:SetShown(entry~=nil)
            if entry then
                local count=0; for _ in pairs(entry.slots) do count=count+1 end
                row:SetText((NS.vendorProfileID==entry.id and "> " or "")..entry.name.." · "..count.." slots")
            end
        end
        pages:SetText(string.format("%d / %d",state.page,math.max(1,math.ceil(#entries/5))))
        state.load:SetEnabled(NS.vendorProfileID~=nil)
        Status(#entries==0 and "No saved profiles. Create and save a set in /find > Transmog before visiting the vendor." or
            "Select an editable native outfit first. Existing pending edits must be saved or discarded before loading a set.")
    end
    for i=1,5 do
        local row=Button("",306,14,-74-(i-1)*26)
        row:GetFontString():SetWidth(286); row:GetFontString():SetMaxLines(1)
        row:SetScript("OnClick",function(self)
            if InCombatLockdown() or not self.entry then return end
            NS.vendorProfileID=self.entry.id
            state.refresh()
        end)
        state.rows[i]=row
    end
    state.prev:SetScript("OnClick",function() if not InCombatLockdown() then state.page=state.page-1; state.refresh() end end)
    state.next:SetScript("OnClick",function() if not InCombatLockdown() then state.page=state.page+1; state.refresh() end end)
    state.refreshButton:SetScript("OnClick",state.refresh)
    state.load:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        -- Re-read the saved profile at click time: never load an editor draft
        -- or stale copied profile after a deletion/rename.
        local profile=NS.vendorProfileID and NS.db.transmogProfiles[NS.vendorProfileID]
        if type(profile)~="table" or type(profile.slots)~="table" then Status("This saved profile is no longer available. Refresh the list."); return end
        local success,message=T.Stage(profile.slots)
        Status(message)
        if success then panel:Hide(); NS.Print(message) end
    end)
    button:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        if not native:IsShown() then panel:Hide(); return end
        if panel:IsShown() then panel:Hide() else state.refresh(); panel:Show() end
    end)
    panel:Hide()
    Stack(state)
    button:SetShown(native:IsShown())
    if NS.ui and NS.ui.combatHider then
        NS.ui.combatHider:SetFrameRef("vendorSets",panel)
        NS.ui.combatHider:SetFrameRef("vendorSetsButton",button)
    end
    return true
end

function NS.OpenVendorProfiles(profileID)
    if InCombatLockdown() then return false,"Open saved sets after combat." end
    if not TransmogFrame or not TransmogFrame:IsShown() then return false,"Open the transmogrifier, then click the Forever sets overlay near its upper-right corner." end
    if not NS.AttachVendorProfiles() then return false,"Saved sets are unavailable in this client." end
    if profileID then NS.vendorProfileID=profileID end
    NS.vendorProfiles.refresh(); NS.vendorProfiles.panel:Show()
    return true,"Select your set and click Load into preview. Confirm with the native Save Outfit button."
end

function NS.InitVendorProfiles()
    if NS.vendorProfileEvents then return end
    local events=CreateFrame("Frame")
    NS.vendorProfileEvents=events
    for _,event in ipairs({"ADDON_LOADED","TRANSMOGRIFY_OPEN","TRANSMOGRIFY_CLOSE","PLAYER_REGEN_ENABLED"}) do pcall(events.RegisterEvent,events,event) end
    events:SetScript("OnEvent",function(_,event,addon)
        if InCombatLockdown() then return end
        if event=="TRANSMOGRIFY_CLOSE" then
            if NS.vendorProfiles then NS.vendorProfiles.panel:Hide(); NS.vendorProfiles.button:Hide() end
        elseif event~="ADDON_LOADED" or addon=="Blizzard_Transmog" then NS.AttachVendorProfiles() end
    end)
    -- Some client builds load the vendor UI after the open event has already
    -- fired. A small read-only visibility check also covers those orders.
    events:SetScript("OnUpdate",function(self,elapsed)
        self.elapsed=(self.elapsed or 0)+elapsed
        if self.elapsed<0.25 then return end
        self.elapsed=0
        if InCombatLockdown() then return end
        if TransmogFrame then NS.AttachVendorProfiles() end
        local state=NS.vendorProfiles
        if state and (not TransmogFrame or not TransmogFrame:IsShown()) then
            state.button:Hide(); state.panel:Hide()
        end
    end)
    NS.AttachVendorProfiles()
end
