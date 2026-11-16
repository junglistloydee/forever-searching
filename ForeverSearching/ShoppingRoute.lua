local _,NS=...
local function Refresh()
    if NS.RefreshTools then NS.RefreshTools() end
end
local function Signature()
    local entries={}
    for id,item in pairs(NS.db.shopping) do
        entries[#entries+1]=tostring(id)..":"..tostring(item.quantity)..":"..tostring(item.done==true)
    end
    table.sort(entries)
    return table.concat(entries,";").."/"..tostring(NS.db.settings.factionOnly).."/"..tostring(NS.db.settings.sameZone).."/"..tostring(NS.PlayerFaction())
end
NS.ShoppingSignature=Signature

function NS.CancelRoutePlanning()
    NS.CancelWork("shoppingRoute")
    NS.routePlanning=false
end

function NS.StopShoppingRoute()
    if InCombatLockdown() then return end
    if NS.shoppingRoute then NS.StopNavigation() end
    NS.shoppingRoute=nil
    Refresh()
end

function NS.ShoppingListChanged()
    NS.CancelRoutePlanning()
    NS.StopShoppingRoute()
    NS.shoppingPlan=nil
end

function NS.ValidateShoppingRoute()
    if NS.shoppingRoute and NS.shoppingRoute.plan.signature~=Signature() then
        NS.StopShoppingRoute()
        NS.SetStatus("Shopping list or filters changed. Plan a fresh route.")
    end
end

function NS.ComputeShoppingRoute()
    local origin=NS.PlayerOrigin()
    if not origin then return {failure="Your position is unavailable. Try outside an instance or after loading."} end
    local plan={stops={},unresolved={},signature=Signature(),totalDistance=0}
    local pending,vendors,eligible={},{},{}
    local initialMap=origin.mapID
    for id,item in pairs(NS.db.shopping) do
        if not item.done then
            pending[id]={id=id,name=item.name or ("Item "..id),quantity=item.quantity}
            local sources=NS.ShoppingVendors(id)
            eligible[id]=#sources>0
            for _,record in ipairs(sources) do
                local vendor=vendors[record.id]
                if not vendor then
                    vendor={record=record,items={},points={}}
                    vendors[record.id]=vendor
                    for _,point in ipairs(NS.GetEvidence(record)) do
                        if NS.CanNavigate(point) and (not NS.db.settings.sameZone or point.mapID==initialMap) then
                            point.world=NS.WorldPosition(point)
                            vendor.points[#vendor.points+1]=point
                        end
                        NS.WorkYield()
                    end
                end
                vendor.items[id]=true
                NS.WorkYield()
            end
        end
        NS.WorkYield()
    end
    while next(pending) do
        local best
        for _,vendor in pairs(vendors) do
            local count=0
            for id in pairs(vendor.items) do if pending[id] then count=count+1 end; NS.WorkYield() end
            if count>0 then
                for _,point in ipairs(vendor.points) do
                    local distance=NS.DistanceTo(point,origin)
                    if distance and (not best or distance<best.distance or distance==best.distance and
                        (count>best.count or count==best.count and vendor.record.id<best.vendor.record.id)) then
                        best={vendor=vendor,location=point,distance=distance,count=count}
                    end
                    NS.WorkYield()
                end
            end
        end
        if not best then break end
        local stop={record=best.vendor.record,location=best.location,distance=best.distance,items={}}
        for id in pairs(best.vendor.items) do
            if pending[id] then stop.items[#stop.items+1]=pending[id]; pending[id]=nil end
            NS.WorkYield()
        end
        table.sort(stop.items,function(a,b) return a.id<b.id end)
        plan.stops[#plan.stops+1]=stop
        plan.totalDistance=plan.totalDistance+stop.distance
        origin={mapID=stop.location.mapID,x=stop.location.x,y=stop.location.y,world=stop.location.world,
            width=stop.location.mapID==origin.mapID and origin.width or nil,
            height=stop.location.mapID==origin.mapID and origin.height or nil}
        NS.WorkYield()
    end
    for id,item in pairs(pending) do
        item.reason=eligible[id] and "No comparable vendor location in the current zone/faction filters" or "No eligible vendor recorded; use Find sources"
        plan.unresolved[#plan.unresolved+1]=item
    end
    table.sort(plan.unresolved,function(a,b) return a.id<b.id end)
    return plan
end

function NS.PlanShoppingRoute()
    if InCombatLockdown() then return false end
    NS.CancelRoutePlanning()
    NS.StopShoppingRoute()
    if NS.catalogueLoading or NS.itemLoading then NS.SetStatus("Wait for the NPC/item data to finish loading, then plan again."); return false end
    NS.routePlanning=true
    NS.shoppingPlan=nil
    Refresh()
    NS.RunWork("shoppingRoute",NS.ComputeShoppingRoute,function(plan)
        NS.routePlanning=false
        if plan.failure then NS.SetStatus(plan.failure); Refresh(); return end
        if plan.signature~=Signature() then NS.SetStatus("Shopping list or filters changed. Plan the route again."); Refresh(); return end
        NS.shoppingPlan=plan
        if NS.ShowShoppingRoutePreview then NS.ShowShoppingRoutePreview() end
        NS.SetStatus(string.format("Vendor route: %d stops · %d items without a routable vendor.",#plan.stops,#plan.unresolved))
        Refresh()
    end,function(err)
        NS.routePlanning=false
        NS.routeError=tostring(err)
        NS.SetStatus("Could not build the vendor route. Check the available data and try again.")
        Refresh()
    end)
    return true
end

local function Guide(route)
    local stop=route.plan.stops[route.index]
    if not stop then
        NS.StopShoppingRoute()
        NS.SetStatus("Vendor route finished. Review any skipped or unresolved items in Shopping.")
        NS.Print("Vendor route finished. Review any skipped or unresolved items in Shopping.")
        return true
    end
    if not NS.Pin(stop.record,stop.location,route) then
        NS.StopShoppingRoute()
        NS.SetStatus("Could not place the next route waypoint. Plan again when it is available.")
        return false
    end
    NS.navigation.shoppingStop=stop
    NS.UpdateNavigation()
    Refresh()
    return true
end

function NS.StartShoppingRoute()
    if InCombatLockdown() then return false end
    local plan=NS.shoppingPlan
    if not plan or #plan.stops==0 then NS.SetStatus("Plan a route with at least one usable vendor first."); return false end
    if plan.used or plan.signature~=Signature() then NS.SetStatus("Plan a fresh route for the current shopping list and position."); return false end
    plan.used=true
    NS.shoppingRoute={plan=plan,index=1}
    return Guide(NS.shoppingRoute)
end

function NS.NextShoppingStop(bought)
    if InCombatLockdown() then return false end
    local route=NS.shoppingRoute
    if not route then return false end
    if route.plan.signature~=Signature() then
        NS.StopShoppingRoute()
        NS.SetStatus("Shopping list or filters changed. Plan a fresh route before continuing.")
        return false
    end
    local stop=route.plan.stops[route.index]
    if bought then
        for _,item in ipairs(stop.items) do
            local entry=NS.db.shopping[item.id]
            if entry then entry.done=true end
        end
    end
    stop.visited=true
    stop.bought=bought==true
    route.plan.signature=Signature()
    route.index=route.index+1
    return Guide(route)
end
