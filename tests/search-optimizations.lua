local NS,check,drain=...
local record={id=90001,name="Old name",purpose="Meat Vendor",zone="Old zone"}
check(NS.NPCSearchText(record):find("meat vendor",1,true)~=nil,"Cached NPC text includes service information")
record.name,record.purpose,record.zone="New name","Innkeeper","New zone"
local text=NS.NPCSearchText(record)
check(text:find("new name",1,true) and text:find("innkeeper",1,true) and not text:find("old zone",1,true),"NPC text caching follows edits to name, purpose and zone")
local fields=0; for _ in pairs(record) do fields=fields+1 end
check(fields==4,"Search text caches add no fields to personal SavedVariables records")
local oldItem,oldTip=C_Item,C_TooltipInfo
local calls=0
C_Item={GetItemInfoInstant=function(id) calls=calls+1; return id,"Armor","Leather" end,
    IsItemDataCachedByID=function() calls=calls+1; return false end}
C_TooltipInfo=nil
local item={id=90002,name="Fresh Apples"}
check(NS.ItemMatches(item,"fresh",NS.PrepareItemQuery("fresh")) and calls==0,"Literal item names avoid item metadata and tooltip API calls")
check(NS.ItemMatches(item,"leather",NS.PrepareItemQuery("leather")) and calls>0,"Description/type matching still reads available game metadata")
item.name="Renamed item"; item.tooltipText="Restores health"
check(NS.ItemSearchText(item):find("renamed item",1,true) and NS.ItemMatches(item,"health"),"Combined text cache follows name and description changes")
check(#NS.PrepareItemQuery("food that restores health")==3,"Description query preparation preserves meaningful tokens")
check(not NS.ItemMatches(item,"which") and NS.ItemMatches({id=90003,name="Which Sword"},"which"),"Stop words preserve literal matching without matching unrelated items")
C_Item,C_TooltipInfo=oldItem,oldTip
local oldNearest,zone=NS.Nearest,NS.db.settings.sameZone
calls=0
NS.Nearest=function(...) calls=calls+1; return oldNearest(...) end
local origin=NS.PlayerOrigin()
local context={origin=origin}
local first=NS.SearchNearest(record,origin,context)
first.matchReason="First result only"
local second=NS.SearchNearest({locationRecord=record},origin,context)
check(calls==1 and second.matchReason==nil and first~=second,"One-query location memo shares work without sharing mutable result explanations")
NS.db.settings.sameZone=not zone
NS.SearchNearest(record,origin,context)
check(calls==2,"Location memo is invalidated when zone filtering changes")
NS.SearchNearest(record,{mapID=1,x=0.2,y=0.2},context)
check(calls==3,"Moving to a new origin recomputes location distances")
NS.db.settings.sameZone=zone; NS.Nearest=oldNearest
NS.OpenSearch(); drain()
local oldMode=NS.db.settings.searchMode
NS.db.settings.searchMode="npc"
local oldRequest,requests,queries=NS.RequestFind,0,{}
NS.RequestFind=function(query,...)
    requests=requests+1; queries[#queries+1]=query
    return oldRequest(query,...)
end
local function Type(query)
    NS.ui.search.text=query -- Mock player input; SetText represents programmatic input in this suite.
    NS.ui.search.scripts.OnTextChanged(NS.ui.search,true)
end
Type("m"); Type("me"); Type("meat")
check(requests==0,"Typing waits briefly before starting a search")
drain()
check(requests==1 and queries[1]=="meat","A burst of keystrokes starts only the final query")
Type("inn")
NS.ui.search.scripts.OnEnterPressed(NS.ui.search)
check(requests==2 and queries[2]=="inn","Enter flushes the pending query immediately")
drain()
check(requests==2,"The old typing timer cannot repeat an Enter-submitted query")
Type("cancelled"); NS.Close(); drain()
check(requests==2,"Closing the window cancels pending typed searches")
NS.RequestFind=oldRequest
NS.db.settings.searchMode=oldMode
