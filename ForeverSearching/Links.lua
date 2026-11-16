local _, NS = ...
local kinds={npc="NPC",item="Item",quest="Quest"}
local function ValidID(id)
    return NS.Readable(id) and type(id)=="number" and id>0 and id<=2147483647 and id%1==0
end

function NS.WowheadURL(kind,id)
    if not NS.Readable(kind) or type(kind)~="string" or not kinds[kind] or not ValidID(id) then return end
    return "https://www.wowhead.com/forever/"..kind.."="..string.format("%.0f",id)
end

function NS.WowheadTargets(record)
    local targets,seen={},{}
    if type(record)~="table" or record.isSection then return targets end
    local function Add(kind,id,name)
        local url=NS.WowheadURL(kind,id)
        if not url or seen[url] then return end
        seen[url]=true
        targets[#targets+1]={kind=kind,id=id,url=url,label=kinds[kind].." "..id..(NS.CleanName(name) and (" · "..NS.CleanName(name)) or "")}
    end
    local entity=NS.EntityInfo(record)
    if entity then Add(entity.kind,entity.id,entity.name) end
    Add("item",record.itemID)
    Add("quest",record.questID)
    Add("npc",record.npcID,record.npcID and record.name)
    return targets
end

function NS.ShowWowheadLinks(record)
    if InCombatLockdown() then NS.SetStatus("Copy links after combat."); return false end
    local targets=NS.WowheadTargets(record)
    if #targets==0 then NS.SetStatus("Select an NPC, item or quest with a known ID first."); return false end
    if not NS.ui or not NS.ui:IsShown() or not NS.ui.wowhead then return false end
    NS.ui.wowhead.open(targets)
    return true
end

function NS.ShowAppearanceWowhead(row)
    if InCombatLockdown() then return false,"Copy links after combat." end
    if type(row)~="table" then return false,"Choose an appearance or variant first." end
    local itemID=row.itemID
    if not ValidID(itemID) and NS.Transmog and ValidID(row.sourceID) then
        local info=NS.Transmog.Source(row.sourceID)
        itemID=info and info.itemID
    end
    -- Wowhead item pages use item IDs. Appearance/source/visual IDs are never
    -- substituted when an appearance's originating item cannot be identified.
    if not ValidID(itemID) then return false,"No item ID is available. Choose another collected variant for its Wowhead link." end
    return NS.ShowWowheadLinks({entityType="item",entityID=itemID,name=row.name})
end

function NS.BuildWowheadUI(ui,Text,Button,Panel)
    local panel=CreateFrame("Frame",nil,ui,"BackdropTemplate")
    panel:SetPoint("CENTER"); panel:SetSize(480,250); panel:SetFrameLevel(ui:GetFrameLevel()+100)
    panel:EnableMouse(true); Panel(panel)
    local state={panel=panel,buttons={}}
    ui.wowhead=state
    Text(panel,"Copy Wowhead link","GameFontNormalLarge",22,-20,360)
    local close=Button(panel,"X",28,26); close:SetPoint("TOPRIGHT",-12,-12)
    close:SetScript("OnClick",function() if not InCombatLockdown() then panel:Hide() end end)
    local label=Text(panel,"","GameFontHighlightSmall",22,-58,436); label:SetMaxLines(2)
    local box=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
    state.box=box
    box:SetPoint("TOPLEFT",28,-120); box:SetSize(424,30); box:SetFontObject("GameFontHighlightSmall"); box:SetAutoFocus(false)
    Text(panel,"Press Ctrl+C, then paste into your browser.\nThe addon only generates the link; it does not load the website.","GameFontHighlightSmall",22,-170,436)
    box:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
    box:SetScript("OnTextChanged",function(self)
        if state.url and self:GetText()~=state.url then self:SetText(state.url); self:HighlightText() end
    end)
    box:SetScript("OnEscapePressed",NS.Close)
    box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    local function Select(entry)
        state.url=entry.url; label:SetText(entry.label)
        box:SetText(entry.url); box:SetFocus(); box:HighlightText()
    end
    for i=1,4 do
        local button=Button(panel,"",104,25); button:SetPoint("TOPLEFT",22+(i-1)*110,-88)
        button:SetScript("OnClick",function(self) if not InCombatLockdown() and self.entry then Select(self.entry) end end)
        state.buttons[i]=button
    end
    state.open=function(targets)
        if InCombatLockdown() then return end
        ui.search:ClearFocus(); ui.github:ClearFocus()
        if ui.transmog then ui.transmog.nameBox:ClearFocus(); ui.transmog.query:ClearFocus() end
        for i,button in ipairs(state.buttons) do
            button.entry=targets[i]; button:SetShown(button.entry~=nil)
            if button.entry then button.label:SetText(kinds[button.entry.kind].." "..button.entry.id) end
        end
        panel:Show(); Select(targets[1])
    end
    panel:SetScript("OnHide",function() box:ClearFocus() end)
    panel:Hide()
end
