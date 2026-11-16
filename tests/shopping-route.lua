local NS,check,drain,setCombat,dispatch=...
local saved={map=C_Map,vector=CreateVector2D,facing=GetPlayerFacing,faction=UnitFactionGroup,
    records=NS.records,items=NS.items,provider=NS.provider,shopping=NS.db.shopping,sightings=NS.db.sightings,
    stock=NS.db.vendorStock,plan=NS.shoppingPlan,route=NS.shoppingRoute,navigation=NS.navigation,
    factionOnly=NS.db.settings.factionOnly,sameZone=NS.db.settings.sameZone,
    sourceFilter=NS.db.settings.sourceFilter,showArrow=NS.db.settings.showArrow,
    catalogueLoading=NS.catalogueLoading,itemLoading=NS.itemLoading,buy=BuyMerchantItem}
local buys,pin,failPin=0,nil,false
BuyMerchantItem=function() buys=buys+1; error("Buying must remain manual") end
local function vector(x,y) return {GetXY=function() return x,y end} end
local px,py=0.5,0.5
CreateVector2D=vector
GetPlayerFacing=function() return 0 end
UnitFactionGroup=function() return "Horde" end
C_Map={
    GetBestMapForUnit=function() return 1 end,
    GetPlayerMapPosition=function() return vector(px,py) end,
    GetMapInfo=function(id) return {name="Zone "..id} end,
    GetMapWorldSize=function() return 1000,2000 end,
    GetWorldPosFromMapPos=function(id,pos)
        local x,y=pos:GetXY()
        return id==3 and 2 or 1,vector(-y*2000,-x*1000-(id==2 and 1000 or 0))
    end,
    CanSetUserWaypointOnMap=function() return true end,
    SetUserWaypoint=function(point)
        if failPin then error("Unavailable") end
        pin={uiMapID=point.mapID,position=vector(point.x,point.y)}
    end,
    GetUserWaypoint=function() return pin end,
}
NS.StopNavigation()
NS.db.settings.factionOnly,NS.db.settings.sameZone,NS.db.settings.showArrow=true,false,true
NS.db.settings.sourceFilter="drops" -- Route planning must not overwrite this or use it as a vendor filter.
NS.records,NS.items,NS.db.sightings,NS.db.vendorStock={},{},{},{}
NS.provider=nil
NS.catalogueLoading,NS.itemLoading=false,false
local function Vendor(id,name,x,mapID,faction,phase)
    NS.records[id]={id=id,name=name,purpose="Vendor",source="Personal sighting",zone="Zone "..(mapID or 1),friendlyToFaction=faction}
    if x then NS.db.sightings[id]={seen=100,evidence={{kind="sighting",seen=100,label="Last seen nearby",mapID=mapID or 1,x=x,y=0.5,phase=phase}}} end
end
Vendor(101,"Near shop",0.51)
Vendor(102,"Far alternative",0.9)
Vendor(103,"West shop",0.49)
Vendor(104,"Other continent",0.51,3)
Vendor(105,"Enemy shop",0.52,1,"A")
Vendor(106,"Unmapped shop")
Vendor(107,"Phased shop",0.5,1,nil,1)
Vendor(108,"East shop",0.52)
Vendor(109,"Across zone border",0.01,2)
local function Item(id,name,vendors,done)
    NS.items[id]={id=id,name=name,vendors=vendors,loaded=true}
    NS.db.shopping[id]={id=id,name=name,quantity=2,done=done==true}
end
NS.db.shopping={}
Item(1101,"Apples",{101,102})
Item(1102,"Bread",{101})
Item(1103,"Cloth",{103})
Item(1104,"Drop only",{})
Item(1105,"Distant item",{104})
Item(1106,"Enemy item",{105})
Item(1107,"Finished item",{102},true)
Item(1108,"East item",{108})
Item(1109,"Unknown location",{106})
Item(1110,"Phased item",{107})
local plan=NS.ComputeShoppingRoute()
check(#plan.stops==3 and #plan.unresolved==5,"Only pending items with eligible, comparable vendor spots are routed")
check(plan.stops[1].record.id==101 and #plan.stops[1].items==2,"Items sold at the nearest vendor share one stop")
check(plan.stops[2].record.id==108 and plan.stops[3].record.id==103,"Subsequent vendors are nearest to the previous stop rather than the original player position")
check(math.abs(plan.totalDistance-50)<0.001,"Route distance totals consecutive straight-line legs")
check(NS.db.settings.sourceFilter=="drops" and not NS.db.settings.sameZone,"Planning does not write search filters")
check(not NS.db.shopping[1101].done and NS.db.shopping[1107].done,"Planning preserves quantities and completion")
Item(1111,"Across-zone item",{109})
NS.db.settings.sameZone=true
local zoned=NS.ComputeShoppingRoute()
check(#zoned.stops==3 and #zoned.unresolved==6,"Current-zone preference excludes other-zone route destinations")
NS.db.settings.sameZone=false
local cross=NS.ComputeShoppingRoute()
check(#cross.stops==4,"Comparable nearby zones can be included when current-zone filtering is off")
NS.db.shopping[1111]=nil
NS.db.vendorStock[101]={name="Near shop",items={[1104]={name="Drop only"}}}
local observed=NS.ComputeShoppingRoute()
check(#observed.unresolved==4 and #observed.stops[1].items==3,"Personally observed vendor inventories supplement QuestieDB links")
NS.db.vendorStock={}
NS.ui:Show(); NS.ShowSearchPage(); NS.ShowTools("shopping")
NS.ui.planShoppingRoute.scripts.OnClick()
drain()
plan=NS.shoppingPlan
check(plan and #plan.stops==3 and NS.ui.startShoppingRoute:IsShown(),"Shopping UI builds and presents a route preview before navigation")
check(NS.ui.toolsRows[1].entry.stop.record.id==101 and NS.ui.toolsRows[4].entry.unresolved~=nil,"Preview lists ordered stops followed by unrouted items")
check(NS.navigation==nil and not NS.db.shopping[1101].done,"Preview neither places a waypoint nor completes items")
NS.ui.startShoppingRoute.scripts.OnClick()
check(NS.shoppingRoute and NS.shoppingRoute.index==1 and NS.navigation.name=="Near shop","Starting the route guides to its first vendor")
check(NS.navigationFrame.nextStop:IsShown() and NS.navigationFrame.heading:GetText()=="SHOPPING · 1 / 3","Arrow displays shopping progress and manual stop controls")
px=0.51; NS.UpdateNavigation()
check(not NS.db.shopping[1101].done and not NS.db.shopping[1102].done,"Reaching a vendor never assumes items were bought")
NS.navigationFrame.nextStop.scripts.OnClick()
check(NS.db.shopping[1101].done and NS.db.shopping[1102].done and NS.shoppingRoute.index==2,"Got items marks the grouped stop done and advances")
NS.navigationFrame.skipStop.scripts.OnClick()
check(not NS.db.shopping[1108].done and NS.shoppingRoute.index==3,"Skipping preserves pending items and advances")
NS.NextShoppingStop(true)
check(NS.db.shopping[1103].done and not NS.shoppingRoute and not NS.navigation,"Completing the final stop ends navigation without touching unresolved items")
check(not NS.db.shopping[1104].done and not NS.db.shopping[1108].done,"Unrouted and skipped items remain on the shopping list")
check(not NS.StartShoppingRoute(),"A used plan cannot restart with stale visited stops")
NS.db.shopping[1101].done=false; NS.db.shopping[1102].done=false
NS.PlanShoppingRoute(); drain(); NS.StartShoppingRoute()
local active=NS.shoppingRoute
check(active~=nil,"A new plan can route the remaining list")
setCombat(true); dispatch("PLAYER_REGEN_DISABLED")
local nav=NS.navigation
check(not NS.NextShoppingStop(true) and not NS.PlanShoppingRoute() and NS.navigation==nav,"Combat cannot advance, purchase or replan the shopping route")
setCombat(false); dispatch("PLAYER_REGEN_ENABLED")
check(NS.shoppingRoute==active,"Active route survives combat without completing a stop")
NS.db.shopping[1101].quantity=3
check(not NS.NextShoppingStop(true) and not NS.db.shopping[1101].done and not NS.shoppingRoute,"Changed quantities invalidate the route before marking anything done")
NS.PlanShoppingRoute(); drain(); NS.StartShoppingRoute()
NS.ChangeShopping(1101,1)
check(not NS.shoppingRoute and not NS.navigation and not NS.shoppingPlan,"Editing quantity through the shopping controls immediately invalidates guidance")
NS.PlanShoppingRoute(); drain(); NS.StartShoppingRoute()
NS.db.settings.sameZone=true; NS.ApplySettings()
check(not NS.shoppingRoute and not NS.navigation,"Applying changed route filters stops obsolete guidance")
NS.db.settings.sameZone=false
NS.PlanShoppingRoute(); drain(); NS.StartShoppingRoute()
NS.Pin(NS.records[103],{mapID=1,x=0.49,y=0.5,label="Manual waypoint"})
check(not NS.shoppingRoute and NS.navigation.name=="West shop","A manually chosen waypoint exits the shopping route")
NS.PlanShoppingRoute(); drain(); NS.StartShoppingRoute()
pin=nil; NS.UpdateNavigation()
check(not NS.shoppingRoute and not NS.navigation,"Removing the shared map pin stops the shopping route")
NS.PlanShoppingRoute(); drain()
failPin=true
check(not NS.StartShoppingRoute() and not NS.shoppingRoute,"Failed native waypoint requests stop the route safely")
failPin=false
NS.db.shopping={}
for i=1,100 do
    local id=2000+i
    NS.items[id]={id=id,name="Bulk item "..i,vendors={101},loaded=true}
    NS.db.shopping[id]={id=id,name="Bulk item "..i,quantity=1}
end
NS.PlanShoppingRoute()
check(NS.routePlanning,"Large route work yields instead of blocking the frame")
NS.db.shopping[2001].quantity=2
drain()
check(not NS.routePlanning and not NS.shoppingPlan,"A list edit during planning prevents stale route publication")
NS.PlanShoppingRoute(); NS.CancelRoutePlanning(); drain()
check(not NS.routePlanning and not NS.shoppingPlan,"Cancelled planning cannot publish later")
NS.PlanShoppingRoute(); NS.Close(); drain()
check(not NS.routePlanning and not NS.shoppingPlan,"Closing search cancels a pending plan")
NS.PlanShoppingRoute(); setCombat(true); dispatch("PLAYER_REGEN_DISABLED"); drain()
check(not NS.routePlanning and not NS.shoppingPlan,"Combat cancels route planning without deferred publication")
setCombat(false); dispatch("PLAYER_REGEN_ENABLED")
NS.db.shopping={}; NS.PlanShoppingRoute(); drain()
check(NS.shoppingPlan and #NS.shoppingPlan.stops==0 and not NS.StartShoppingRoute(),"Empty shopping lists never start navigation")
NS.db.shopping={[1101]={id=1101,name="Apples",quantity=1}}
local position=C_Map.GetPlayerMapPosition
C_Map.GetPlayerMapPosition=function() return nil end
NS.PlanShoppingRoute(); drain()
check(not NS.routePlanning and not NS.shoppingPlan,"Missing player position reports a planning failure safely")
C_Map.GetPlayerMapPosition=position
check(buys==0,"Shopping guidance never invokes a purchase API")
NS.StopNavigation(); NS.CancelRoutePlanning()
C_Map,CreateVector2D,GetPlayerFacing,UnitFactionGroup=saved.map,saved.vector,saved.facing,saved.faction
NS.records,NS.items,NS.provider=saved.records,saved.items,saved.provider
NS.db.shopping,NS.db.sightings,NS.db.vendorStock=saved.shopping,saved.sightings,saved.stock
NS.shoppingPlan,NS.shoppingRoute,NS.navigation=saved.plan,saved.route,saved.navigation
NS.db.settings.factionOnly,NS.db.settings.sameZone=saved.factionOnly,saved.sameZone
NS.db.settings.sourceFilter,NS.db.settings.showArrow=saved.sourceFilter,saved.showArrow
NS.catalogueLoading,NS.itemLoading=saved.catalogueLoading,saved.itemLoading
BuyMerchantItem=saved.buy
NS.UpdateNavigation()
