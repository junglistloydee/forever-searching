local NS,check,drain,setCombat,dispatch=...
local oldMap,oldVector,oldFacing=C_Map,CreateVector2D,GetPlayerFacing
local oldNavigation,oldPosition=NS.navigation,NS.db.navigationPosition
local oldEnabled,oldLocked=NS.db.settings.showArrow,NS.db.settings.arrowLocked
local oldParentWidth,oldParentHeight=UIParent.GetWidth,UIParent.GetHeight
local frame=NS.navigationFrame
check(frame.point[2]==Minimap and frame.point[3]=="BOTTOMLEFT","Default navigation placement sits beside the minimap without moving it")
local function Near(a,b) return a and math.abs(a-b)<0.00001 end
local function vector(x,y) return {GetXY=function() return x,y end} end
local x,y,mapID,facing=0.5,0.5,1,0
local pin,pinWrites,faceReads=nil,0,0
CreateVector2D=vector
GetPlayerFacing=function() faceReads=faceReads+1; return facing end
C_Map={
    GetBestMapForUnit=function() return mapID end,
    GetPlayerMapPosition=function() return vector(x,y) end,
    GetMapInfo=function(id) return {name="Test zone "..id} end,
    GetMapWorldSize=function() return 1000,2000 end,
    GetWorldPosFromMapPos=function(id,pos)
        local px,py=pos:GetXY()
        return id==3 and 2 or 1,vector(-py*2000,-px*1000-(id==2 and 1000 or 0))
    end,
    CanSetUserWaypointOnMap=function() return true end,
    SetUserWaypoint=function(point)
        pinWrites=pinWrites+1
        pin={uiMapID=point.mapID,position=vector(point.x,point.y)}
    end,
    GetUserWaypoint=function() return pin end,
}
NS.db.settings.showArrow,NS.db.settings.arrowLocked=true,false
local origin=NS.PlayerOrigin()
local function Bearing(px,py)
    return NS.NavigationVector({mapID=1,x=px,y=py},origin,0)
end
local a,d=Bearing(0.5,0.4)
check(Near(a,0) and Near(d,200),"Northward destinations point up with scaled world distance")
a,d=Bearing(0.6,0.5)
check(Near(a,-math.pi/2) and Near(d,100),"Eastward destinations point right when facing north")
a,d=Bearing(0.5,0.6)
check(Near(math.abs(a),math.pi) and Near(d,200),"Southward destinations point behind the player")
a,d=Bearing(0.4,0.5)
check(Near(a,math.pi/2) and Near(d,100),"Westward destinations point left")
a=NS.NavigationVector({mapID=1,x=0.4,y=0.5},origin,math.pi/2)
check(Near(a,0),"Turning to face west rotates a western destination to straight ahead")
a,d=NS.NavigationVector({mapID=2,x=0,y=0.5},origin,0)
check(Near(a,-math.pi/2) and Near(d,500),"Cross-zone bearings use shared world coordinates")
check(NS.NavigationVector({mapID=3,x=0.5,y=0.5},origin,0)==nil,"Different continents never get a fabricated direct bearing")
local noWorld=C_Map.GetWorldPosFromMapPos; C_Map.GetWorldPosFromMapPos=nil
origin=NS.PlayerOrigin()
a,d=NS.NavigationVector({mapID=1,x=0.6,y=0.4},origin,0)
check(Near(a,-math.atan(0.5)) and Near(d,math.sqrt(50000)),"Same-map fallback respects rectangular map proportions")
check(NS.NavigationVector({mapID=2,x=0.6,y=0.4},origin,0)==nil,"Different zone coordinates are never compared without world positions")
C_Map.GetWorldPosFromMapPos=noWorld
local record={id=701,name="Test Vendor"}
local point={mapID=1,x=0.6,y=0.5,label="Recorded spot"}
NS.Pin(record,point)
check(frame:IsShown() and NS.navigation.name=="Test Vendor" and Near(NS.navigation.x,0.6),"Show waypoint starts the built-in arrow at the same destination")
check(frame.title:GetText()=="Test Vendor" and frame.distance:GetText()=="~100 yd","Arrow displays destination and estimated yards")
check(Near(frame.arrow.rotation,-math.pi/2),"Native pointer artwork rotates to the computed eastward bearing")
local active=NS.navigation
NS.Pin(record,{mapID=1,x=-1,y=0.5,label="Invalid"})
check(NS.navigation==active,"Invalid evidence cannot replace active navigation")
local setter=C_Map.SetUserWaypoint
C_Map.SetUserWaypoint=function() error("Waypoint unavailable") end
NS.Pin(record,{mapID=1,x=0.4,y=0.5,label="Failed pin"})
check(NS.navigation==active,"A failed map-pin request cannot retarget the arrow")
C_Map.SetUserWaypoint=setter
NS.Close()
check(frame:IsShown() and not NS.ui:IsShown(),"Closing search leaves navigation visible beside the minimap")
x=0.595
NS.UpdateNavigation()
check(frame.distance:GetText():find("Nearby",1,true) and not frame.arrow:IsShown() and frame.arrivalIcon:IsShown(),"Arrival shows proximity to the recorded spot without implying the NPC was found")
x=0.5; facing={secret=true}; NS.UpdateNavigation()
check(not frame.arrow:IsShown() and frame.distance:GetText()=="Direction unavailable","Unreadable facing data suppresses the pointer")
facing=0
local getPosition=C_Map.GetPlayerMapPosition
C_Map.GetPlayerMapPosition=function() return nil end
NS.UpdateNavigation()
check(not frame.arrow:IsShown(),"Missing player position does not leave a stale direction")
C_Map.GetPlayerMapPosition=getPosition
NS.UpdateNavigation()
check(frame.arrow:IsShown(),"Navigation recovers when public position data becomes available")
local before=faceReads
frame.elapsed=0; frame.scripts.OnUpdate(frame,0.05)
check(faceReads==before,"Navigation does no work before its 100ms update interval")
frame.scripts.OnUpdate(frame,0.05)
check(faceReads==before+1,"Navigation updates at most ten times per second")
local previousCenter=frame.GetCenter
frame.GetCenter=function() return 700,400 end
UIParent.GetWidth=function() return 1000 end
UIParent.GetHeight=function() return 800 end
frame.scripts.OnDragStart(frame)
check(frame.dragging,"Unlocked arrow can be dragged")
frame.scripts.OnDragStop(frame)
check(NS.db.navigationPosition.x==200 and NS.db.navigationPosition.y==0,"Dragging saves only addon-owned screen offsets")
frame.lock.scripts.OnClick()
frame.scripts.OnDragStart(frame)
check(NS.db.settings.arrowLocked and not frame.dragging,"Lock blocks dragging and persists only an addon preference")
frame.lock.scripts.OnClick()
check(not NS.db.settings.arrowLocked,"Arrow can be unlocked again")
NS.db.settings.showArrow=false; NS.ApplySettings()
check(not frame:IsShown() and NS.navigation==active,"Disabling the arrow hides it without deleting the destination")
NS.db.settings.showArrow=true; NS.ApplySettings()
check(frame:IsShown(),"Re-enabling the arrow restores the active destination")
setCombat(true); dispatch("PLAYER_REGEN_DISABLED")
before=faceReads
NS.UpdateNavigation(); NS.StopNavigation(); NS.StartNavigation(point,record)
check(not frame:IsShown() and NS.navigation==active and faceReads==before,"Combat securely hides navigation and blocks updates, dismissal and retargeting")
setCombat(false); dispatch("PLAYER_REGEN_ENABLED")
check(frame:IsShown() and not NS.ui:IsShown(),"Leaving combat resumes navigation while search stays closed")
local writes=pinWrites
frame.close.scripts.OnClick()
check(not frame:IsShown() and not NS.navigation and pinWrites==writes and pin~=nil,"Dismiss removes only our arrow, preserving the shared map pin")
NS.Pin(record,point); pin={uiMapID=1,position=vector(0.4,0.5)}; NS.UpdateNavigation()
check(not NS.navigation and not frame:IsShown(),"Replacing the shared map pin stops obsolete navigation")
NS.Pin(record,point); pin=nil; NS.UpdateNavigation()
check(not NS.navigation and not frame:IsShown(),"Removing the shared map pin stops the arrow")
NS.Pin(record,point); mapID=3; NS.UpdateNavigation()
check(not frame.arrow:IsShown() and frame.hint:GetText()=="Test zone 1","Different continents show the destination zone instead of an incorrect heading")
NS.StopNavigation()
local originalFrame=NS.navigationFrame
NS.navigationFrame=nil
NS.db.navigationPosition={x=145,y=-98}
NS.BuildNavigation()
check(NS.navigationFrame.point[1]=="CENTER" and NS.navigationFrame.point[4]==145 and NS.navigationFrame.point[5]==-98,"Saved arrow offsets are restored on a new frame")
NS.navigationFrame:Hide(); NS.navigationFrame=nil
NS.db.navigationPosition={x=0/0,y=math.huge}
NS.BuildNavigation()
check(NS.navigationFrame.point[2]==Minimap,"Malformed saved coordinates fall back to minimap placement")
NS.navigationFrame:Hide(); NS.navigationFrame=originalFrame
NS.db.settings.showArrow,NS.db.settings.arrowLocked=false,true
NS.InitSettings()
check(not NS.db.settings.showArrow and NS.db.settings.arrowLocked,"Initialization preserves existing navigation visibility and lock preferences")
frame.GetCenter=previousCenter
C_Map,CreateVector2D,GetPlayerFacing=oldMap,oldVector,oldFacing
UIParent.GetWidth,UIParent.GetHeight=oldParentWidth,oldParentHeight
NS.navigation,NS.db.navigationPosition=oldNavigation,oldPosition
NS.db.settings.showArrow,NS.db.settings.arrowLocked=oldEnabled,oldLocked
NS.UpdateNavigation()
