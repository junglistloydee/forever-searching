-- Deterministic work counters, not a measurement of live-client FPS.
unpack=unpack or table.unpack
local root=(arg[1] or "ForeverSearching").."/"
local NS={}
for _,file in ipairs({"Work.lua","Data.lua","Evidence.lua","Distance.lua","Settings.lua","ItemText.lua","Sources.lua","Personal.lua","Results.lua"}) do
    assert(loadfile(root..file))("ForeverSearching",NS)
end
local nearest,stockLookups,itemCalls=0,0,0
function InCombatLockdown() return false end
local function vector(x,y) return {GetXY=function() return x,y end} end
CreateVector2D=vector
C_Map={GetBestMapForUnit=function() return 1 end,GetPlayerMapPosition=function() return vector(0.5,0.5) end,
    GetMapInfo=function() return {name="Benchmark zone"} end,CanSetUserWaypointOnMap=function() return true end,
    GetMapWorldSize=function() return 1000,1000 end,
    GetWorldPosFromMapPos=function(_,pos) local x,y=pos:GetXY(); return 1,vector(-y*1000,-x*1000) end}
C_Item={IsItemDataCachedByID=function() itemCalls=itemCalls+1; return false end,
    GetItemInfoInstant=function(id) itemCalls=itemCalls+1; return id,"Trade Goods","Supplies" end}
NS.db={sightings={},vendorStock={}}
NS.InitSettings()
for id=1,100 do
    local record={id=id,name="Supply vendor "..id,purpose="Vendor",zone="Benchmark zone",source="Personal sighting",mapID=1,x=id/110,y=0.5,seen=100}
    NS.records[id],NS.db.sightings[id]=record,record
    NS.db.vendorStock[id]={name=record.name,items=setmetatable({[1000+id]={name="Supply item "..(1000+id)}},
        {__index=function() stockLookups=stockLookups+1 end})}
end
for id=1,2000 do NS.items[id]={id=id,name="Supply item "..id,vendors={id%25+1},loaded=true} end
NS.itemReady,NS.questReady=true,true
local oldNearest=NS.Nearest
NS.Nearest=function(...) nearest=nearest+1; return oldNearest(...) end
local rows=NS.FindAll("supply")
local hash=0.0
for _,row in ipairs(rows) do
    local key=tostring(NS.Key(row))..";"
    for i=1,#key do hash=(hash*33.0+key:byte(i))%1000000007 end
end
print(string.format("rows=%d checksum=%.0f nearest=%d missing-stock-lookups=%d item-API-calls=%d",#rows,hash,nearest,stockLookups,itemCalls))
if not arg[1] then
    assert(#rows==2200,"Preserve every NPC/item/vendor result")
    assert(nearest<=100,"Evaluate each vendor location once per combined query")
    assert(stockLookups<5000,"Do not scan every merchant for every matched item")
    assert(itemCalls==0,"Literal name matches need no tooltip or item metadata calls")
    print("PASS: broad combined-search work counters")
end
