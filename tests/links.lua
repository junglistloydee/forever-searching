local NS,check,drain,setCombat,dispatch=...
local base="https://www.wowhead.com/forever/"
for _,kind in ipairs({"npc","item","quest"}) do
    check(NS.WowheadURL(kind,123)==base..kind.."=123","Use Forever "..kind.." pages")
end
for _,id in ipairs({0,-1,1.5,math.huge,0/0,"123","1/../quest=2",{}, {secret=true},2147483648}) do
    check(NS.WowheadURL("item",id)==nil,"Reject invalid or unreadable link IDs")
end
check(NS.WowheadURL(nil,1)==nil and NS.WowheadURL({},1)==nil and NS.WowheadURL("appearance",1)==nil,"Only supported link kinds are allowed")
local npc={id=701,name="Test Vendor"}
local targets=NS.WowheadTargets(npc)
check(#targets==1 and targets[1].url==base.."npc=701","Plain NPC results link to their NPC ID")
targets=NS.WowheadTargets({id=-1001,entityType="item",entityID=1001,itemID=1001,isGroup=true})
check(#targets==1 and targets[1].url==base.."item=1001","Grouped item rows use entity IDs and deduplicate links")
local linked={id=701,npcID=701,name="Test Vendor",entityType="quest",entityID=2001,questID=2002,itemID=1001}
targets=NS.WowheadTargets(linked)
check(#targets==4 and targets[1].url==base.."quest=2001" and targets[3].url==base.."quest=2002" and targets[4].url==base.."npc=701","Related quest/item/NPC sources retain distinct identities")
check(#NS.WowheadTargets({isSection=true,id=701})==0 and #NS.WowheadTargets(nil)==0,"Section headings and empty selections do not generate links")
local oldSelected,oldSource=NS.selected,NS.Transmog.Source
NS.OpenSearch(); drain()
NS.selected=linked
NS.ui.wowheadButton.scripts.OnClick()
local state=NS.ui.wowhead
check(state.panel:IsShown() and state.box:GetText()==base.."quest=2001" and state.box.focused,"Search button opens and focuses the copy URL")
state.buttons[4].scripts.OnClick(state.buttons[4])
check(state.box:GetText()==base.."npc=701","Copy dialog can switch to the related NPC")
state.box:SetText("edited text")
check(state.box:GetText()==base.."npc=701","Manual editing cannot replace the generated URL")
state.box.scripts.OnEnterPressed(state.box)
check(not state.box.focused,"Enter releases copy field focus")
check(NS.ShowAppearanceWowhead({itemID=5004,sourceID=104,visualID=1004,name="Sword"}) and state.box:GetText()==base.."item=5004","Appearance links use actual item IDs instead of source or visual IDs")
local reads=0
NS.Transmog.Source=function(id) reads=reads+1; return id==105 and {itemID=5005} or {} end
check(NS.ShowAppearanceWowhead({sourceID=105}) and state.box:GetText()==base.."item=5005","Missing appearance item IDs can resolve through a read-only source lookup")
local ok,message=NS.ShowAppearanceWowhead({sourceID=106,visualID=1006})
check(not ok and message:find("No item ID",1,true) and state.box:GetText()==base.."item=5005","Unknown appearances never substitute source IDs into item URLs")
NS.ui.transmog.focus={itemID=5006,sourceID=106}
NS.ui.transmog.wowhead.scripts.OnClick()
check(state.box:GetText()==base.."item=5006","Wardrobe copy button uses its focused appearance variant")
NS.ShowTransmogPage(); drain()
check(not state.panel:IsShown() and not state.box.focused,"Changing pages dismisses the copy dialog and focus")
NS.ShowSearchPage(); drain()
NS.ShowWowheadLinks(npc)
setCombat(true); dispatch("PLAYER_REGEN_DISABLED")
local previousReads=reads
check(not NS.ui:IsShown() and not state.box.focused,"Entering combat closes the addon and clears copy field focus")
check(not NS.ShowWowheadLinks(npc) and not NS.ShowAppearanceWowhead({sourceID=105}) and reads==previousReads,"Combat blocks link dialogs and appearance lookups")
setCombat(false); dispatch("PLAYER_REGEN_ENABLED")
NS.OpenSearch(); drain()
check(not state.panel:IsShown(),"Reopening after combat does not restore a stale link dialog")
NS.ShowWowheadLinks(npc)
state.box.scripts.OnEscapePressed()
check(not NS.ui:IsShown() and not state.box.focused,"Escape in the copy field closes the addon and releases focus")
NS.selected,NS.Transmog.Source=oldSelected,oldSource
