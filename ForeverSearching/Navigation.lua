local _, NS = ...
local function Number(v)
    return NS.Readable(v) and type(v)=="number" and v==v and math.abs(v)<math.huge
end
local function Read(func,...)
    if type(func)~="function" then return end
    local ok,value=pcall(func,...)
    if ok and NS.Readable(value) then return value end
end
local function World(point)
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    local ok,id,x,y=pcall(function()
        local continent,pos=C_Map.GetWorldPosFromMapPos(point.mapID,CreateVector2D(point.x,point.y))
        if not NS.Readable(continent) or not NS.Readable(pos) or not pos then return end
        local px,py=pos:GetXY()
        return continent,px,py
    end)
    if ok and Number(id) and Number(x) and Number(y) then return {id=id,x=x,y=y} end
end
local function Atan2(y,x)
    -- Use radians on every supported Lua runtime, including Lua 5.1.
    if x>0 then return math.atan(y/x) end
    if x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi) end
    if y>0 then return math.pi/2 end
    if y<0 then return -math.pi/2 end
    return 0
end

function NS.NavigationVector(target,origin,facing)
    if not target or not origin or not Number(facing) then return end
    local north,west
    local world=target.world or World(target)
    if world and origin.world then
        if world.id~=origin.world.id then return end
        -- Blizzard world X increases north; world Y increases west.
        north,west=world.x-origin.world.x,world.y-origin.world.y
    elseif target.mapID==origin.mapID and Number(origin.width) and Number(origin.height) then
        north,west=(origin.y-target.y)*origin.height,(origin.x-target.x)*origin.width
    end
    if not Number(north) or not Number(west) then return end
    return Atan2(west,north)-facing,math.sqrt(north*north+west*west)
end

function NS.StopNavigation()
    if InCombatLockdown() then return end
    NS.navigation=nil
    NS.shoppingRoute=nil
    if NS.navigationFrame then NS.navigationFrame:Hide() end
    -- Dismissing our arrow deliberately leaves the shared map pin alone.
end

function NS.StartNavigation(location,record)
    if InCombatLockdown() or not NS.ValidPosition(location) then return end
    NS.navigation={mapID=location.mapID,x=location.x,y=location.y,
        name=NS.CleanName(record and record.name) or "Recorded location",world=World(location)}
    if NS.ui then NS.BuildNavigation(); NS.UpdateNavigation() end
end

function NS.UpdateNavigation()
    if InCombatLockdown() then return end
    local frame,target=NS.navigationFrame,NS.navigation
    if not frame then return end
    if not target or not NS.db.settings.showArrow then frame:Hide(); return end
    -- Do not continue pointing at an obsolete destination after another addon
    -- or the player replaces/removes the single shared Blizzard map pin.
    if C_Map and type(C_Map.GetUserWaypoint)=="function" then
        local ok,pin=pcall(C_Map.GetUserWaypoint)
        if ok and NS.Readable(pin) then
            if pin==nil then NS.StopNavigation(); return end
            local valid,same=pcall(function()
                if not NS.Readable(pin.uiMapID) or not NS.Readable(pin.position) or not pin.position then return end
                local x,y=pin.position:GetXY()
                if not Number(x) or not Number(y) then return end
                return pin.uiMapID==target.mapID and math.abs(x-target.x)<0.00001 and math.abs(y-target.y)<0.00001
            end)
            if valid and same==false then NS.StopNavigation(); return end
        end
    end
    local origin=NS.PlayerOrigin()
    local facing=Read(GetPlayerFacing)
    local angle,distance=NS.NavigationVector(target,origin,facing)
    frame.title:SetText(target.name)
    frame.lock.label:SetText(NS.db.settings.arrowLocked and "Move" or "Lock")
    local route=NS.shoppingRoute
    local stop=target.shoppingStop
    local shopping=route~=nil and stop~=nil
    frame.heading:SetText(shopping and string.format("SHOPPING · %d / %d",route.index,#route.plan.stops) or "FOREVER SEARCHING")
    if frame.routeLayout~=shopping then frame:SetHeight(shopping and 142 or 108); frame.routeLayout=shopping end
    frame.nextStop:SetShown(shopping); frame.skipStop:SetShown(shopping)
    local arrived=distance and distance<=10
    frame.arrow:SetShown(angle~=nil and not arrived)
    frame.arrivalIcon:SetShown(arrived==true)
    if angle and not arrived then frame.arrow:SetRotation(angle) end
    frame.distance:SetText(arrived and ("Nearby · "..NS.DistanceText(distance)) or (distance and NS.DistanceText(distance) or "Direction unavailable"))
    frame.distance:SetTextColor(arrived and 0.3 or 1,arrived and 1 or 0.82,arrived and 0.3 or 0)
    frame.hint:SetText(shopping and string.format("%d item%s at this stop",#stop.items,#stop.items==1 and "" or "s") or
        (arrived and "Look around here" or (angle and "Direct bearing" or NS.MapName(target.mapID))))
    frame:Show()
end

function NS.BuildNavigation()
    if NS.navigationFrame or InCombatLockdown() then return end
    local frame=CreateFrame("Frame","ForeverSearchingNavigation",UIParent,"BackdropTemplate")
    NS.navigationFrame=frame
    frame:SetSize(228,108); frame:SetFrameStrata("MEDIUM"); frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    frame:SetBackdropColor(0.035,0.028,0.018,0.72); frame:SetBackdropBorderColor(0.6,0.47,0.18,0.65)
    local saved=NS.db.navigationPosition
    if type(saved)=="table" and Number(saved.x) and Number(saved.y) and math.abs(saved.x)<10000 and math.abs(saved.y)<10000 then
        frame:SetPoint("CENTER",UIParent,"CENTER",saved.x,saved.y)
    elseif Minimap then frame:SetPoint("TOPRIGHT",Minimap,"BOTTOMLEFT",180,18)
    else frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-240,-220) end
    local function Text(font,x,y,width)
        local t=frame:CreateFontString(nil,"OVERLAY",font)
        t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetMaxLines(1); t:SetJustifyH("LEFT")
        return t
    end
    frame.heading=Text("GameFontNormalSmall",12,-9,146)
    frame.title=Text("GameFontHighlightSmall",82,-30,132); frame.title:SetMaxLines(2); frame.title:SetHeight(28)
    frame.canvas=CreateFrame("Frame",nil,frame); frame.canvas:SetPoint("TOPLEFT",8,-29); frame.canvas:SetSize(64,64)
    -- Use the client's outlined pointer artwork instead of thick line segments.
    frame.arrow=frame.canvas:CreateTexture(nil,"ARTWORK")
    frame.arrow:SetPoint("CENTER"); frame.arrow:SetSize(54,54); frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    frame.arrivalIcon=frame.canvas:CreateTexture(nil,"ARTWORK")
    frame.arrivalIcon:SetPoint("CENTER"); frame.arrivalIcon:SetSize(34,34); frame.arrivalIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    frame.arrivalIcon:Hide()
    frame.distance=Text("GameFontNormalLarge",82,-61,138)
    frame.hint=Text("GameFontHighlightSmall",82,-84,138); frame.hint:SetTextColor(0.65,0.65,0.65)
    local function Button(text,width,quiet)
        local b=CreateFrame("Button",nil,frame,not quiet and "UIPanelButtonTemplate" or nil)
        b:SetSize(width,20)
        b.label=not quiet and b:GetFontString() or b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        if quiet then b.label:SetPoint("CENTER"); b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD") end
        b.label:SetText(text)
        return b
    end
    frame.close=Button("×",18,true); frame.close:SetPoint("TOPRIGHT",-3,-3)
    frame.close:SetScript("OnClick",NS.StopNavigation)
    frame.lock=Button("Lock",36,true); frame.lock:SetPoint("TOPRIGHT",-23,-3)
    frame.lock:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        NS.db.settings.arrowLocked=not NS.db.settings.arrowLocked
        NS.UpdateNavigation()
    end)
    frame.nextStop=Button("Got items / next",132); frame.nextStop:SetPoint("BOTTOMLEFT",10,8)
    frame.nextStop:SetScript("OnClick",function() NS.NextShoppingStop(true) end)
    frame.skipStop=Button("Skip",62); frame.skipStop:SetPoint("BOTTOMRIGHT",-10,8)
    frame.skipStop:SetScript("OnClick",function() NS.NextShoppingStop(false) end)
    frame.nextStop:Hide(); frame.skipStop:Hide()
    frame:SetScript("OnEnter",function(self)
        if InCombatLockdown() or not NS.navigation then return end
        local target=NS.navigation
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine(target.name,1,0.82,0)
        GameTooltip:AddLine(string.format("%s · %.1f, %.1f",NS.MapName(target.mapID),target.x*100,target.y*100),1,1,1)
        GameTooltip:AddLine("Direct bearing to a recorded spot; terrain and stock may differ.",0.7,0.7,0.7,true)
        if target.shoppingStop then
            for _,item in ipairs(target.shoppingStop.items) do GameTooltip:AddLine(item.name.." × "..item.quantity,1,1,1) end
            GameTooltip:AddLine("Buy manually, then click Got items / next. Skip leaves items pending.",0.7,0.7,0.7,true)
        end
        GameTooltip:AddLine(NS.db.settings.arrowLocked and "Move unlocks the position." or "Drag to move; Lock fixes the position.",0.7,0.7,0.7,true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
    frame:SetScript("OnDragStart",function(self)
        if not InCombatLockdown() and not NS.db.settings.arrowLocked then self.dragging=true; self:StartMoving() end
    end)
    frame:SetScript("OnDragStop",function(self)
        if not self.dragging then return end
        self:StopMovingOrSizing(); self.dragging=false
        if InCombatLockdown() then return end
        local x,y=self:GetCenter()
        local w=Read(UIParent.GetWidth,UIParent); local h=Read(UIParent.GetHeight,UIParent)
        if Number(x) and Number(y) and Number(w) and Number(h) then
            NS.db.navigationPosition={x=x-w/2,y=y-h/2}
        end
    end)
    frame:SetScript("OnHide",function(self)
        if self.dragging then self:StopMovingOrSizing(); self.dragging=false end
    end)
    frame:SetScript("OnUpdate",function(self,elapsed)
        self.elapsed=(self.elapsed or 0)+elapsed
        if self.elapsed<0.1 then return end
        self.elapsed=0; NS.UpdateNavigation()
    end)
    frame:Hide()
end
