local _,NS=...
-- Menus belong only to this addon; selecting an entry uses the existing
-- guarded action handlers and never installs a keyboard shortcut.
function NS.ChoiceMenu(owner,anchor,entries,choose)
    if InCombatLockdown() then return end
    local menu=owner.choiceMenu or CreateFrame("Frame",nil,owner,"BackdropTemplate")
    owner.choiceMenu=menu
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-3); menu:SetSize(230,#entries*28+12)
    menu:SetFrameLevel(owner:GetFrameLevel()+100); menu:EnableMouse(true)
    menu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
    menu:SetBackdropColor(0.04,0.03,0.02,1)
    menu.rows=menu.rows or {}
    for _,button in ipairs(menu.rows) do button:Hide() end
    for i,entry in ipairs(entries) do
        local button=menu.rows[i] or CreateFrame("Button",nil,menu,"UIPanelButtonTemplate")
        button:ClearAllPoints(); button:Show()
        button:SetPoint("TOPLEFT",6,-6-(i-1)*28); button:SetSize(218,26); button:SetText(entry.name)
        button:SetScript("OnClick",function()
            if InCombatLockdown() then return end
            menu:Hide(); choose(entry)
        end)
        menu.rows[i]=button
    end
    menu:SetScript("OnLeave",function(self) if not InCombatLockdown() and not self:IsMouseOver() then self:Hide() end end)
    menu:Show()
    return menu
end
