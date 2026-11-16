local NS,check,drain,setCombat,dispatch = ...
local T=NS.Transmog
local saved={Enum=Enum,collection=C_TransmogCollection,outfits=C_TransmogOutfitInfo,transmog=C_Transmog,paper=C_PaperDollInfo,frame=TransmogFrame}
local savedProfiles,savedFavourites=NS.db.transmogProfiles,NS.db.transmogFavourites
NS.db.transmogProfiles={}
NS.db.transmogFavourites={}
local atNPC,shown,enabled,locked=true,true,true,false
local calls,forbidden,pending,missingState={},0,{},false
local function Never() forbidden=forbidden+1; error("No game settings, gear, collection filters or final transmog commits may be changed") end
Enum={TransmogCollectionType={None=0,Head=1,Chest=4,OneHSword=14}}
local slots={
    {slot=0,type=0,collectionType=1,slotName="HEADSLOT",isSecondary=false},
    {slot=4,type=0,collectionType=4,slotName="CHESTSLOT",isSecondary=false},
    {slot=12,type=0,collectionType=0,slotName="MAINHANDSLOT",isSecondary=false},
    {slot=2,type=0,collectionType=2,slotName="SHOULDERSLOT",isSecondary=true},
}
local illusions={{slot=12,type=1,collectionType=14,slotName="MAINHANDSLOT",isSecondary=false}}
C_PaperDollInfo={GetInventorySlotInfo=function(name) return ({HEADSLOT=1,CHESTSLOT=5,MAINHANDSLOT=16,SHOULDERSLOT=3})[name] end}
local data={
    [101]={sourceID=101,visualID=1001,name="Collected Hood",categoryID=1,itemID=5001,isCollected=true,isValidSourceForPlayer=true,canDisplayOnPlayer=true,isValidForEquippedItem=true},
    [102]={sourceID=102,visualID=1002,name="Uncollected Hood",categoryID=1,itemID=5002,isCollected=false,isValidSourceForPlayer=true,canDisplayOnPlayer=true},
    [103]={sourceID=103,visualID=1003,name="Collected Robe",categoryID=4,itemID=5003,isCollected=true,isValidSourceForPlayer=true,canDisplayOnPlayer=true,isValidForEquippedItem=true},
    [104]={sourceID=104,visualID=1004,name="Collected Sword",categoryID=14,itemID=5004,isCollected=true,isValidSourceForPlayer=true,canDisplayOnPlayer=true,isValidForEquippedItem=true},
    [105]={sourceID=105,visualID=1005,name="Wrong Class Hood",categoryID=1,itemID=5005,isCollected=true,isValidSourceForPlayer=false,canDisplayOnPlayer=true},
}
local function Key(slot,kind,option) return slot..":"..kind..":"..option end
C_TransmogOutfitInfo={
    GetAllSlotLocationInfo=function() return slots,illusions end,
    GetOptionsForSlot=function(slot) return {{type=slot==12 and 1 or 12,name="Current type",enabled=true},{type=99,name="Disabled",enabled=false}} end,
    GetEquippedSlotOptionFromTransmogSlot=function(slot) return slot==12 and 1 or 12 end,
    GetCollectionInfoForSlotAndOption=function(_,_,category) return {name="Available",isWeapon=category==14} end,
    IsTransmogEnabled=function() return enabled end,
    IsLockedOutfit=function() return locked end,
    GetCurrentlyViewedOutfitID=function() return 777 end,
    GetViewedOutfitSlotInfo=function(slot,kind,option)
        if missingState then return nil end
        return {hasPending=pending[Key(slot,kind,option)] or false}
    end,
    CanPlayerTransmogSlot=function() return true end,
    SetPendingTransmog=function(slot,kind,option,id,display)
        calls[#calls+1]={slot=slot,kind=kind,option=option,id=id,display=display}
        pending[Key(slot,kind,option)]=true
    end,
    CommitAndApplyAllPending=Never,ChangeDisplayedOutfit=Never,SetOutfitSituationsEnabled=Never,SetViewedOutfit=Never,
}
C_Transmog={IsAtTransmogNPC=function() return atNPC end,GetSlotVisualInfo=function(location)
    return {appliedSourceID=({[1]=101,[5]=103,[16]=104})[location.slotID] or 0,baseSourceID=0}
end}
C_TransmogCollection={
    GetSourceInfo=function(id) return data[id] end,
    GetAppearanceSourceInfo=function(id) if data[id] then return {itemLink="|Hitem:"..data[id].itemID.."|h["..data[id].name.."]|h"} end end,
    IsAppearanceHiddenVisual=function() return false end,
    GetCategoryInfo=function(id) return "Swords",id==14,true,true,true,false end,
    GetCategoryAppearances=function(category,location,option)
        assert(type(location)=="table" and type(location.slotID)=="number" and location.type==0 and location.modification==0,"Forever calls must include a full TransmogLocation")
        assert(option==1 or option==12,"Never guess a slot option")
        local rows={}
        for _,item in pairs(data) do
            if item.categoryID==category then rows[#rows+1]={visualID=item.visualID,isCollected=item.isCollected,isUsable=true} end
        end
        rows[#rows+1]={secret=true}
        return rows
    end,
    GetAppearanceSources=function(visual,category,location)
        assert(location.slotID,"Source queries need an inventory location")
        local rows={}
        for _,item in pairs(data) do if item.visualID==visual then rows[#rows+1]=item end end
        return rows
    end,
    SetClassFilter=Never,SetCollectedShown=Never,SetUncollectedShown=Never,SetSearch=Never,SetDefaultFilters=Never,
    SetAllFactionsShown=Never,SetAllRacesShown=Never,SetSourceTypeFilter=Never,SaveCustomSet=Never,
}
TransmogFrame={IsShown=function() return shown end}
local defined=T.Slots()
check(#defined==3 and defined[1].slot==0 and defined[1].location.slotID==1,"Use API outfit slots with separate inventory locations; omit split shoulders")
check(#T.Options(defined[1])==1 and T.DefaultOption(defined[1])==12,"Use enabled native slot options, including armor options")
check(#T.Categories(defined[3])==1 and T.Categories(defined[3])[1].id==14,"Weapon categories respect the chosen hand")
local available=T.Available(defined[1],12,1,"")
check(#available==1 and available[1].sourceID==101,"Show collected usable sources, excluding uncollected and wrong-class appearances")
do
    data[106]={sourceID=106,visualID=1006,name="Unlocked with optional flags absent",categoryID=1,itemID=5006,isCollected=true}
    local found=T.Available(defined[1],12,1,"")
    check(#found==2,"Readable missing optional flags no longer hide a collected source with no native use error")
    local all=T.Browse(defined[1],nil,nil,"",{})
    check(#all==3 and all.diagnostics.unique==3 and all.diagnostics.restricted>0,"All collected includes preview-only appearances and reports diagnostics")
    check(#T.Browse(defined[1],nil,nil,"",{usableOnly=true})==2,"Usable only is an explicit addon-local filter")
    data[107]={sourceID=107,visualID=1001,name="Alternate Hood",categoryID=1,itemID=5007,isCollected=true}
    all=T.Browse(defined[1],nil,nil,"alternate",{})
    check(#all==1 and all[1].sourceID==107 and #all[1].alternatives==2,"Group identical visuals and allow matching any collected source name")
    T.ToggleFavourite(1001)
    check(NS.db.transmogFavourites[1001] and #T.Browse(defined[1],nil,nil,"",{favouritesOnly=true})==1,"Appearance favourites live only in the addon and filter grouped visuals")
    T.ToggleFavourite(1001)
    local originalOptions,originalAppearances=C_TransmogOutfitInfo.GetOptionsForSlot,C_TransmogCollection.GetCategoryAppearances
    C_TransmogOutfitInfo.GetOptionsForSlot=function() return {{type=12,name="Cloth",enabled=true},{type=13,name="Leather",enabled=true}} end
    data[108]={sourceID=108,visualID=1008,name="Leather-only Hood",categoryID=1,itemID=5008,isCollected=true}
    C_TransmogCollection.GetCategoryAppearances=function(category,location,option)
        local entries=originalAppearances(category,location,12); local result={}
        for _,entry in ipairs(entries) do
            if entry.visualID and ((option==13 and entry.visualID==1008) or (option==12 and entry.visualID~=1008)) then result[#result+1]=entry end
        end
        return result
    end
    all=T.Browse(defined[1],nil,nil,"leather-only",{})
    check(#all==1 and all[1].option==13,"All available types preserves the correct native option for each appearance")
    check(#T.Browse(defined[1],12,nil,"leather-only",{})==0,"Choosing a specific armour type narrows the union locally")
    local originalSupport=C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption
    local invalidQueries=0
    C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption=function() return nil end
    C_TransmogCollection.GetCategoryAppearances=function() invalidQueries=invalidQueries+1; error("Invalid native category/type combination") end
    local invalid=T.Available(defined[3],1,14,"",false)
    check(#invalid==0 and invalid.diagnostics.unsupported==1 and invalidQueries==0,"Reject unsupported native type/category combinations before the crash-sensitive enumeration API")
    C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption=originalSupport
    C_TransmogOutfitInfo.GetOptionsForSlot,C_TransmogCollection.GetCategoryAppearances=originalOptions,originalAppearances
    data[106],data[107],data[108]=nil,nil,nil
end
do
    for n=200,500 do data[n]={sourceID=n,visualID=n+1000,name="Uncollected "..n,categoryID=1,isCollected=false} end
    local finished=false
    NS.RunWork("transmogBrowser",function() return T.Available(defined[1],12,1,"") end,function() finished=true end)
    check(not finished,"Large appearance lists yield to the cooperative frame budget")
    NS.CancelWork("transmogBrowser"); drain()
    check(not finished,"Cancelled appearance requests never publish stale results")
    for n=200,500 do data[n]=nil end
end
check(#T.Available(defined[1],12,1,"hood")==1 and #T.Available(defined[1],12,1,"robe")==0,"Filter appearance names locally without changing game filters")
local empty,err=T.Available(defined[1],nil,1,"")
check(#empty==0,"Missing options do not call wardrobe enumeration")
local id=T.Save(nil,"Travel",{[0]={sourceID=101,option=12}})
check(id==1 and NS.db.transmogProfiles[id].slots[0].sourceID==101,"Create named profiles in addon SavedVariables")
check(T.Save(nil,"travel",{})==nil and T.Save(nil,"bad\nname",{})==nil,"Reject duplicate or invalid profile names")
check(T.Save(0/0,"Invalid ID",{})==nil,"Reject invalid numeric profile IDs without indexing a table with NaN")
T.Delete(nil); T.Delete(0/0)
check(NS.db.transmogProfiles[id]~=nil,"Invalid deletion IDs cannot affect valid profiles")
local edit=T.CopySlots(NS.db.transmogProfiles[id].slots); edit[0].sourceID=103
check(NS.db.transmogProfiles[id].slots[0].sourceID==101,"Draft profile edits never mutate the saved profile")
check(T.Save(id,"Travel renamed",{[0]={sourceID=101,option=12}})==id,"Renaming a profile retains its stable ID")
local captured=T.Capture()
check(captured[0].sourceID==101 and captured[4].sourceID==103 and captured[12].sourceID==104,"Capture current readable transmog appearances without equipping gear")
local previewCalls={}
local model={SetUnit=function(_,unit) previewCalls[#previewCalls+1]="unit:"..unit end,
    Dress=function() previewCalls[#previewCalls+1]="dress" end,TryOn=function(_,source,hand) previewCalls[#previewCalls+1]=source; previewCalls.hand=hand end,
    UndressSlot=function(_,slot) previewCalls.hidden=slot end}
check(T.Preview(model,{[0]={sourceID=101,option=12}}) and previewCalls[1]=="unit:player" and previewCalls[3]==101,"Only the private model is dressed for a preview")
T.Preview(model,{})
check(previewCalls[#previewCalls]=="dress","Clearing preview overrides restores the character baseline")
local profile=NS.db.transmogProfiles[id]
atNPC=false
check(not T.Stage(profile.slots) and #calls==0,"Do not stage appearances away from a vendor")
atNPC=true; shown=false
check(not T.Stage(profile.slots) and #calls==0,"Require Blizzard's transmog screen to be open")
shown=true; enabled=false
check(not T.Stage(profile.slots) and #calls==0,"Never enable transmog or stage while it is disabled")
enabled=true; locked=true
check(not T.Stage(profile.slots) and #calls==0,"Do not change a locked native outfit")
locked=false; missingState=true
check(not T.Stage(profile.slots) and #calls==0,"Fail closed when pending edits cannot be read")
missingState=false; pending[Key(12,1,1)]=true
check(not T.Stage(profile.slots) and #calls==0,"Preserve pending weapon illusion edits")
pending={}; pending[Key(2,0,12)]=true
check(not T.Stage(profile.slots) and #calls==0,"Preserve pending edits in independently split shoulder slots")
pending={}; pending[Key(0,0,99)]=true
check(not T.Stage(profile.slots) and #calls==0,"Preserve pending edits even on currently disabled options")
pending={}
do
    local api=C_TransmogOutfitInfo
    local oldOptions,oldViewed=api.GetOptionsForSlot,api.GetViewedOutfitSlotInfo
    api.GetOptionsForSlot=function(slot) return oldOptions(slot),{{type=77,name="Artifact option",enabled=false}} end
    pending[Key(0,0,77)]=true
    check(not T.Stage(profile.slots) and #calls==0,"Legacy pending scan also preserves edits on separately returned artifact options")
    pending={}
    api.GetOptionsForSlot=function(slot) return oldOptions(slot),{secret=true} end
    check(not T.Stage(profile.slots) and #calls==0,"Unreadable legacy artifact options cannot be treated as an empty list")
    api.GetOptionsForSlot=oldOptions
    local appearanceCount,illusionCount=#slots,#illusions
    slots[appearanceCount+1]={slot=55,type=0,slotName="MAINHANDSLOT",isSecondary=false,collectionType=14}
    illusions[illusionCount+1]={slot=999,type=1,slotName="SECONDARYHANDSLOT",isSecondary=false,collectionType=0}
    api.GetOptionsForSlot=function(slot) if slot==55 or slot==999 then return nil end; return oldOptions(slot) end
    local ok,message=T.Stage(profile.slots)
    check(not ok and message:find("pending options",1,true) and #calls==0,"Reproduce loading blocked by an unrelated slot with no options")
    api.HasPendingOutfitTransmogs=function() return next(pending)~=nil end
    api.HasPendingOutfitSituations=function() return false end
    api.GetViewedOutfitSlotInfo=nil
    check(T.Stage(profile.slots) and #calls==1,"Native outfit-wide pending check permits a clean outfit with unused optionless slots")
    check(not T.Stage(profile.slots) and #calls==1,"Outfit-wide pending flag protects the edits just staged, even without per-slot reads")
    pending={}; calls={}
    pending[Key(999,1,123)]=true
    check(not T.Stage(profile.slots) and #calls==0,"Aggregate protection includes pending illusion edits on slots with no selectable options")
    pending={}; pending[Key(2,0,99)]=true
    check(not T.Stage(profile.slots) and #calls==0,"Aggregate protection preserves secondary/disabled-option edits")
    pending={}
    for _,read in ipairs({function() return nil end,function() return {secret=true} end,function() return 0 end,function() error("Unavailable") end}) do
        api.HasPendingOutfitTransmogs=read
        check(not T.Stage(profile.slots) and #calls==0,"Unreadable or failed outfit-wide pending reads never permit loading")
    end
    api.HasPendingOutfitTransmogs=function() return false end
    api.HasPendingOutfitSituations=function() return true end
    check(not T.Stage(profile.slots) and #calls==0,"Pending native situation edits are preserved")
    api.HasPendingOutfitSituations=function() return {secret=true} end
    check(not T.Stage(profile.slots) and #calls==0,"Unreadable native situation state blocks loading")
    api.HasPendingOutfitSituations=function() return false end
    check(not T.Stage({[0]={sourceID=102,option=12}}) and #calls==0,"Aggregate pending checks do not bypass ownership and slot validation")
    api.GetOptionsForSlot=function(slot) if slot==0 then return nil end; return oldOptions(slot) end
    check(not T.Stage(profile.slots) and #calls==0,"Selected profile slots still require a usable native slot option")
    api.HasPendingOutfitTransmogs,api.HasPendingOutfitSituations=nil,nil
    api.GetOptionsForSlot,api.GetViewedOutfitSlotInfo=oldOptions,oldViewed
    slots[appearanceCount+1],illusions[illusionCount+1]=nil,nil
end
check(not T.Stage({[0]={sourceID=102,option=12}}) and #calls==0,"Reject uncollected saved appearances")
check(not T.Stage({[0]={sourceID=103,option=12}}) and #calls==0,"Reject an appearance for a different slot")
check(not T.Stage({[0]={sourceID=105,option=12}}) and #calls==0,"Reject a saved appearance unusable by the current character")
do
    local original=C_TransmogCollection.GetCategoryAppearances
    C_TransmogCollection.GetCategoryAppearances=function(...) local entries=original(...); for _,entry in ipairs(entries) do if entry.visualID==1001 then entry.isUsable=false end end; return entries end
    check(not T.Stage(profile.slots) and #calls==0,"Preview-only visual restrictions are rechecked at vendor preflight, even when source flags look usable")
    C_TransmogCollection.GetCategoryAppearances=original
end
check(not T.Stage({[0]={sourceID=101,option=99}}) and #calls==0,"Reject disabled slot options")
check(not T.Stage({[900]={sourceID=101,option=12}}) and #calls==0,"Reject unknown profile slots without partial preparation")
check(not T.Stage({}) and #calls==0,"An empty profile cannot trigger vendor writes")
check(not T.Stage({[0]={sourceID=101,option=12},[4]={sourceID=102,option=12}}) and #calls==0,"Validate the whole profile before any pending writes")
check(T.Stage(profile.slots) and #calls==1 and calls[1].slot==0 and calls[1].id==101 and calls[1].display==1,
    "The explicit vendor action stages only selected primary appearances using verified native parameters")
check(forbidden==0,"Vendor preparation never commits, pays, changes native collection filters or equips gear")
pending={}; calls={}
do
    local original=C_TransmogOutfitInfo.SetPendingTransmog
    C_TransmogOutfitInfo.SetPendingTransmog=function(slot,...)
        if slot==4 then error("Client refused this appearance") end
        original(slot,...)
    end
    local success,message=T.Stage({[0]={sourceID=101,option=12},[4]={sourceID=103,option=12}})
    check(not success and #calls==1 and message:find("partial preview",1,true),"A refused pending write reports a partial preview without committing or bypassing restrictions")
    C_TransmogOutfitInfo.SetPendingTransmog=original
    pending={}; calls={}
    local originalSources=C_TransmogCollection.GetSourceInfo
    C_TransmogCollection.GetSourceInfo=function() return {secret=true} end
    check(#T.Available(defined[1],12,1,"")==0 and not T.Stage(profile.slots),"Unreadable appearance data is skipped and cannot be staged")
    C_TransmogCollection.GetSourceInfo=originalSources
    local originalAPI=C_TransmogOutfitInfo
    C_TransmogOutfitInfo=nil
    check(#T.Slots()==0 and not T.Stage(profile.slots),"Missing Forever outfit APIs leave profiles intact and disable integration")
    C_TransmogOutfitInfo=originalAPI
    local originalProfiles=NS.db.transmogProfiles
    NS.db.transmogProfiles={}
    for n=1,50 do T.Save(nil,"Profile "..n,{}) end
    check(T.Save(nil,"Overflow",{})==nil and T.Save(1,"Renamed",{})==1,"Profile limits prevent growth while allowing existing profiles to be edited")
    NS.db.transmogProfiles=originalProfiles
end
setCombat(true)
check(not T.Stage(profile.slots) and not T.Save(nil,"Combat",{}) and not T.Capture() and not T.Preview(model,{}),"All transmog writes and previews pause in combat")
T.Delete(id); check(NS.db.transmogProfiles[id]~=nil,"Profile deletion is blocked during combat")
setCombat(false)
NS.ui:Show(); NS.ShowTransmogPage(); drain()
check(NS.ui.transmogPanel:IsShown() and not NS.ui.searchPage:IsShown(),"The right-hand Transmog tab opens its own panel")
local ui=NS.ui.transmog
check(ui.setMenu:IsShown() and ui.helpMenu:IsShown() and not ui.diagnosticsButton:IsShown() and not ui.copy:IsShown(),"Set/help menus reduce visible secondary controls")
ui.helpMenu.scripts.OnClick()
ui.pickerRows[1].scripts.OnClick(ui.pickerRows[1])
check(ui.infoPanel:IsShown(),"Wardrobe checklist opens through the Help / More menu")
ui.infoPanel:Hide()
local oldCursor,oldDown=GetCursorPosition,IsMouseButtonDown
local cursor=100
GetCursorPosition=function() return cursor,100 end; IsMouseButtonDown=function() return true end
local oldFacing=ui.facing
ui.model.scripts.OnMouseDown(ui.model,"LeftButton"); cursor=120; ui.model.scripts.OnUpdate(ui.model)
check(ui.facing>oldFacing,"Dragging the private model rotates its preview")
ui.model.scripts.OnMouseUp(ui.model)
check(ui.dragX==nil,"Releasing the mouse stops preview rotation")
GetCursorPosition,IsMouseButtonDown=oldCursor,oldDown
check(#ui.slots==3 and ui.model~=nil and #ui.rows==2,"Build a private 3D preview and browse all collected appearances, including preview-only pieces")
ui.profileButtons[1].scripts.OnClick(ui.profileButtons[1]); drain()
ui.nameBox:SetText("Edited profile"); ui.save.scripts.OnClick()
check(NS.db.transmogProfiles[id].name=="Edited profile","Rename and save a selected profile from the UI")
ui.itemButtons[1].scripts.OnClick(ui.itemButtons[1]); ui.nameBox:SetText("Unsaved rename"); ui.new.scripts.OnClick()
check(ui.dirty and ui.profileID==id,"Do not discard unsaved edits when New or another profile is selected")
ui.discard.scripts.OnClick(); drain()
check(not ui.dirty and ui.draft[0].sourceID==101,"Discard restores the saved profile draft")
ui.copy.scripts.OnClick(); ui.save.scripts.OnClick(); drain()
check(ui.profileID~=id and NS.db.transmogProfiles[ui.profileID].slots[0].sourceID==101,"Copy a profile without overwriting the original")
ui.delete.scripts.OnClick()
check(NS.db.transmogProfiles[ui.profileID]~=nil,"Profile deletion requires a second explicit click")
ui.nameBox:SetText("Changed since confirmation")
check(ui.deleteArmed==nil,"Editing a profile disarms an earlier delete confirmation")
ui.delete.scripts.OnClick()
check(NS.db.transmogProfiles[ui.profileID]~=nil,"Delete after an edit requires a fresh confirmation")
ui.delete.scripts.OnClick(); drain()
check(ui.profileID==nil and NS.db.transmogProfiles[id]~=nil,"Confirmed deletion removes only the selected addon profile")
ui.profileButtons[1].scripts.OnClick(ui.profileButtons[1]); drain()
check(#calls==0,"Opening profiles and browsing appearances do not stage any transmog")
ui.stage.scripts.OnClick()
check(#calls==0 and not NS.ui:IsShown() and shown and NS.vendorProfiles.panel:IsShown(),"The editor hands off to the native saved-set picker without staging or closing the native screen")
NS.vendorProfiles.load.scripts.OnClick()
check(#calls==1 and not NS.ui:IsShown() and shown and not NS.vendorProfiles.panel:IsShown(),"Loading a saved set from the native screen stages on click and keeps the native screen open")
pending={}; calls={}
NS.OpenSearch(); drain()
check(NS.ui.searchPage:IsShown() and not NS.ui.transmogPanel:IsShown(),"The slash command still opens the Search page")
NS.ShowTransmogPage(); drain(); setCombat(true)
ui.stage.scripts.OnClick(); ui.save.scripts.OnClick(); ui.searchTab.scripts.OnClick()
check(#calls==0 and NS.ui.transmogPanel:IsShown(),"Vendor staging, profile save and page changes stay blocked in combat")
setCombat(false)
do
    ui.nameBox:SetText("Unsaved combat draft")
    ui.nameBox:SetFocus(); ui.query:SetFocus()
    local draft,selected,savedProfile,pendingBefore=ui.draft,ui.profileID,NS.db.transmogProfiles[ui.profileID],pending
    for n=200,500 do data[n]={sourceID=n,visualID=n+1000,name="Uncollected "..n,categoryID=1,isCollected=false} end
    local delivered=false
    NS.RunWork("transmogBrowser",function() return T.Available(defined[1],12,1,"") end,function() delivered=true end)
    check(not delivered,"A browser request is pending when combat begins")
    setCombat(true); dispatch("PLAYER_REGEN_DISABLED")
    check(not NS.ui:IsShown(),"Blizzard's secure state handler hides the entire addon on combat entry")
    check(not ui.nameBox.focused and not ui.query.focused,"Combat closing releases both transmog text inputs")
    check(ui.draft==draft and ui.profileID==selected and ui.dirty and ui.nameBox:GetText()=="Unsaved combat draft",
        "Automatic combat closing preserves the unsaved draft, name and selected profile")
    check(NS.db.transmogProfiles[selected]==savedProfile and pending==pendingBefore and #calls==0,
        "Combat closing neither saves/deletes profiles nor changes native pending appearances")
    setCombat(false); dispatch("PLAYER_REGEN_ENABLED"); drain()
    check(not NS.ui:IsShown() and not delivered,"The addon stays closed after combat and cancelled results are never delivered")
    NS.OpenSearch(); drain(); NS.ShowTransmogPage(); drain()
    check(NS.ui:IsShown() and ui.draft==draft and ui.nameBox:GetText()=="Unsaved combat draft" and ui.dirty,
        "Reopening manually restores the transmog draft without automatic profile writes")
    ui.discard.scripts.OnClick(); drain()
    for n=200,500 do data[n]=nil end
end
do
    NS.db.transmogProfiles.invalid={name="Malformed",slots={}}
    NS.db.transmogProfiles[55]={id=55,name={},slots={}}
    NS.ShowTransmogPage(); drain()
    check(NS.ui:IsShown() and NS.db.transmogProfiles.invalid~=nil,"Malformed profile rows are skipped without erasing saved data or breaking the tab")
    NS.db.transmogProfiles.invalid,NS.db.transmogProfiles[55]=nil,nil
    local old=C_TransmogCollection.GetSourceInfo
    C_TransmogCollection.GetSourceInfo=function() return nil end
    check(not T.Preview(model,{[0]={sourceID=101,option=12}}),"Missing appearance data produces an incomplete-preview result instead of silent success")
    C_TransmogCollection.GetSourceInfo=old
end
local preserved=NS.db.transmogProfiles
do
    NS.ShowTransmogPage(); drain()
    check(ui.optionIndex==0 and ui.optionButton.label:GetText():find("All available types",1,true),"The redesigned picker defaults to all exposed character types")
    ui.optionButton.scripts.OnClick()
    check(ui.pickerRows[1].entry.name=="All available types" and ui.pickerRows[2].entry.name=="Current type","Native-styled dropdowns present choices rather than requiring cycling")
    ui.pickerRows[2].scripts.OnClick(ui.pickerRows[2]); drain()
    check(ui.optionIndex==1,"Choosing a dropdown entry updates the local type filter")
    ui.slotButtons[2].scripts.OnClick(); drain()
    check(ui.slotIndex==2 and ui.rows[1].sourceID==103,"Paper-doll slot icons browse the selected equipment slot")
    ui.itemButtons[1].scripts.OnClick(ui.itemButtons[1])
    check(ui.draft[4].sourceID==103 and #ui.undo>0,"Selecting an appearance records a reversible draft change")
    ui.undoButton.scripts.OnClick()
    check(ui.draft[4]==nil and #ui.redo>0,"Undo restores the previous slot override")
    ui.redoButton.scripts.OnClick()
    check(ui.draft[4].sourceID==103,"Redo restores the selected piece")
    local originalDraft=ui.draft
    ui.compare.scripts.OnClick(); check(ui.compareWorn and ui.draft==originalDraft,"Compare changes only the private preview, preserving the draft")
    ui.compare.scripts.OnClick(); check(not ui.compareWorn,"Compare switches back to the draft")
    ui.favourite.scripts.OnClick(); drain()
    check(NS.db.transmogFavourites[1003] and ui.focus and ui.focus.sourceID==103,"Starring preserves the focused appearance for subsequent source lookup")
    ui.favouritesFilter.scripts.OnClick(); drain()
    check(#ui.rows==1,"Starred-only view filters without a native collection setter")
    ui.favouritesFilter.scripts.OnClick(); drain()
    ui.itemButtons[1].scripts.OnClick(ui.itemButtons[1])
    ui.variants.scripts.OnClick(); ui.pickerRows[1].scripts.OnClick(ui.pickerRows[1])
    check(ui.focus.alternatives and ui.focus.option==12,"Alternate-source selection retains its source/type choices")
    ui.diagnosticsButton.scripts.OnClick(); ui.checklist.scripts.OnClick()
    check(ui.diagnostics.returned>0 and ui.diagnostics.unique>0,"Collection diagnostics expose measured API coverage")
    local beforeRows=ui.rows
    ui.events.scripts.OnEvent(nil,"GET_ITEM_INFO_RECEIVED",999999); drain()
    check(ui.rows==beforeRows,"Unrelated item-cache events do not restart browsing")
    data[109]={sourceID=109,visualID=1009,name="Newly unlocked Robe",categoryID=4,itemID=5009,isCollected=true}
    ui.events.scripts.OnEvent(nil,"TRANSMOG_COLLECTION_SOURCE_ADDED",109); drain()
    check(#ui.rows==2,"Newly unlocked appearances refresh automatically while the wardrobe is open")
    data[109]=nil
    ui.events.scripts.OnEvent(nil,"TRANSMOG_COLLECTION_SOURCE_REMOVED",109); drain()
    check(#ui.rows==1,"Removed appearance data refreshes without stale collection rows")
    local oldItemAPI=C_Item
    data[110]={sourceID=110,visualID=1010,categoryID=4,itemID=5010,isCollected=true}
    ui.events.scripts.OnEvent(nil,"TRANSMOG_COLLECTION_SOURCE_ADDED",110); drain()
    check(T.pendingItems[5010],"Missing source names track their relevant item-cache completion")
    C_Item={IsItemDataCachedByID=function(id) return id==5010 end,GetItemInfo=function() return "Late-loaded Robe" end,RequestLoadItemDataByID=Never}
    ui.events.scripts.OnEvent(nil,"GET_ITEM_INFO_RECEIVED",5010); drain()
    local resolved=false
    for _,row in ipairs(ui.rows) do if row.sourceID==110 and row.name=="Late-loaded Robe" then resolved=true end end
    check(resolved and not T.pendingItems[5010],"Relevant cache events resolve readable names without bulk-requesting item data")
    data[110],C_Item=nil,oldItemAPI
    ui.events.scripts.OnEvent(nil,"TRANSMOG_COLLECTION_SOURCE_REMOVED",110); drain()
    ui.itemButtons[1].scripts.OnClick(ui.itemButtons[1]); ui.sources.scripts.OnClick(); drain()
    check(NS.ui.searchPage:IsShown() and not NS.ui.transmogPanel:IsShown() and NS.ui.search:GetText()=="5003", "Find sources searches the canonical item ID in the existing item/NPC/quest search")
    NS.ShowTransmogPage(); drain()
    check(ui.draft[4].sourceID==103,"Switching to source search does not erase the wardrobe draft")
    ui.discard.scripts.OnClick(); drain()
    local priorFavourites=NS.db.transmogFavourites
    NS.db.transmogFavourites={}; for id=1,500 do NS.db.transmogFavourites[id]=true end
    check(T.ToggleFavourite(501)==nil and NS.db.transmogFavourites[501]==nil,"Appearance favourites are bounded without deleting existing entries")
    NS.db.transmogFavourites=priorFavourites
end
do
    local oldOptions,oldSupport,oldCategory=C_TransmogOutfitInfo.GetOptionsForSlot,C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption,C_TransmogCollection.GetCategoryInfo
    local oldAppearances,oldInventory=C_TransmogCollection.GetCategoryAppearances,C_PaperDollInfo.GetInventorySlotInfo
    local oldEnum=Enum.TransmogCollectionType
    Enum.TransmogCollectionType={None=0,Head=1,Chest=4,OneHSword=14,Shield=18,Holdable=19,Bow=25,Gun=26,Crossbow=27}
    local length=#slots
    slots[length+1]={slot=14,type=0,collectionType=0,slotName="RANGEDSLOT",isSecondary=false}
    slots[length+2]={slot=13,type=0,collectionType=0,slotName="SECONDARYHANDSLOT",isSecondary=false}
    C_PaperDollInfo.GetInventorySlotInfo=function(name) return name=="RANGEDSLOT" and 18 or name=="SECONDARYHANDSLOT" and 17 or oldInventory(name) end
    C_TransmogOutfitInfo.GetOptionsForSlot=function(slot)
        if slot==14 then return {{type=3,name="Ranged weapon",enabled=true}} end
        if slot==13 then return {{type=4,name="Off hand",enabled=true}} end
        return oldOptions(slot)
    end
    local names={[14]="Swords",[18]="Shields",[19]="Off-hand items",[25]="Bows",[26]="Guns",[27]="Crossbows"}
    C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption=function(slot,option,category)
        local valid=slot==14 and option==3 and (category==25 or category==26 or category==27)
            or slot==13 and option==4 and (category==18 or category==19)
            or slot==12 and option==1 and category==14
        if valid then return {name=names[category],isWeapon=true} end
        if slot~=12 and slot~=13 and slot~=14 then return oldSupport(slot,option,category) end
    end
    -- Match the actual API shape: six return values, not a fabricated table.
    C_TransmogCollection.GetCategoryInfo=function(category) return names[category],true,false,false,false,false end
    C_TransmogCollection.GetCategoryAppearances=function(category,location,option)
        if location.slotID==18 then assert(option==3 and category>=25 and category<=27) end
        if location.slotID==17 then assert(option==4 and (category==18 or category==19)) end
        return oldAppearances(category,location,(option==3 or option==4) and 1 or option)
    end
    for i,category in ipairs({25,26,27,18,19}) do
        local id=200+i
        data[id]={sourceID=id,visualID=2000+i,name=names[category].." appearance",categoryID=category,itemID=6000+i,isCollected=true,isValidSourceForPlayer=true,canDisplayOnPlayer=true,isValidForEquippedItem=true}
    end
    local ranged,offhand,mainhand
    for _,slot in ipairs(T.Slots()) do if slot.inventorySlot==18 then ranged=slot elseif slot.inventorySlot==17 then offhand=slot elseif slot.inventorySlot==16 then mainhand=slot end end
    check(#T.Categories(ranged)==3,"Ranged weapons discover bows, guns and crossbows from the native slot/option API despite tuple-returning category metadata")
    check(#T.Categories(mainhand)==1 and #T.Categories(offhand)==2,"Main-hand and off-hand categories use their own supported options")
    ranged.category=25
    check(#T.Categories(ranged)==3,"A weapon descriptor's default category does not hide other supported weapon categories")
    local looks=T.Browse(ranged,nil,nil,"",{usableOnly=true})
    check(#looks==3 and looks[1].option==3,"All available types actually loads collected ranged appearances")
    check(#T.Browse(offhand,nil,nil,"",{usableOnly=true})==2,"Collected shields and off-hand items load for the off-hand slot")
    check(#T.Browse(mainhand,nil,nil,"",{usableOnly=true})==1,"Collected melee weapons continue to load")
    NS.ShowTransmogPage(); drain()
    for i,slot in ipairs(ui.slots) do if slot.inventorySlot==18 then ui.slotButtons[i].scripts.OnClick(); break end end
    drain()
    check(#ui.rows==3 and #ui.categories==3,"The real Ranged UI selection shows its discovered weapon categories and appearances")
    ui.itemButtons[1].scripts.OnClick(ui.itemButtons[1])
    check(ui.draft[14] and ui.draft[14].option==3,"Selecting a ranged look stores the actual ranged slot and option")
    pending={}; calls={}
    check(T.Stage({[14]={sourceID=201,option=3}}) and #calls==1 and calls[1].slot==14 and calls[1].option==3,
        "Explicit vendor staging uses the ranged outfit slot rather than treating it as a hand weapon")
    pending={}; calls={}
    for i=1,5 do data[200+i]=nil end
    slots[length+1],slots[length+2]=nil,nil
    C_TransmogOutfitInfo.GetOptionsForSlot,C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption,C_TransmogCollection.GetCategoryInfo=oldOptions,oldSupport,oldCategory
    C_TransmogCollection.GetCategoryAppearances,C_PaperDollInfo.GetInventorySlotInfo,Enum.TransmogCollectionType=oldAppearances,oldInventory,oldEnum
    ui.discard.scripts.OnClick(); drain()
end
do
    NS.Close()
    pending={}; calls={}
    local events=NS.vendorProfileEvents
    events.scripts.OnEvent(nil,"TRANSMOGRIFY_OPEN")
    local picker=NS.vendorProfiles
    picker.panel:Hide()
    picker.button.scripts.OnClick()
    check(picker.panel:IsShown() and #calls==0 and not NS.ui:IsShown() and shown,"Native Forever sets opens without the full addon window or any transmog writes")
    check(picker.button.parent==UIParent and picker.panel.parent==UIParent,"Saved-set controls are independent overlays, with no native reparenting or script replacement")
    NS.OpenVendorProfiles(id)
    check(NS.vendorProfileID==id and #calls==0,"Choosing a saved set only selects a profile")
    pending[Key(4,0,12)]=true
    picker.load.scripts.OnClick()
    check(#calls==0 and picker.panel:IsShown() and pending[Key(4,0,12)],"Native picker preserves existing vendor edits instead of replacing them")
    pending={}
    local profile=NS.db.transmogProfiles[id]
    local originalSlots=profile.slots
    profile.slots={[0]={sourceID=102,option=12}}
    picker.load.scripts.OnClick()
    check(#calls==0 and picker.panel:IsShown(),"Loading re-reads the latest saved slots and rejects an unavailable appearance")
    profile.slots=originalSlots
    NS.db.transmogProfiles[id]=nil
    picker.load.scripts.OnClick()
    check(#calls==0 and picker.status:GetText():find("no longer available",1,true),"A deleted saved set cannot load a stale copied profile")
    picker.refresh()
    check(NS.vendorProfileID==nil,"Refreshing a deleted selection clears the picker selection")
    NS.db.transmogProfiles[id]=profile
    NS.OpenVendorProfiles(id)
    shown=false
    check(not NS.OpenVendorProfiles(id),"The picker cannot open a native window that is closed")
    picker.load.scripts.OnClick()
    check(#calls==0,"A stale load click after vendor closure performs no pending writes")
    shown=true
    NS.OpenVendorProfiles(id)
    setCombat(true); dispatch("PLAYER_REGEN_DISABLED")
    check(not picker.panel:IsShown() and shown,"Combat securely closes only the addon picker without hiding the native vendor frame")
    picker.button.scripts.OnClick(); picker.load.scripts.OnClick()
    check(#calls==0 and not NS.OpenVendorProfiles(id),"Picker opening and loading remain blocked in combat")
    setCombat(false); dispatch("PLAYER_REGEN_ENABLED")
    events.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
    check(not picker.panel:IsShown(),"Leaving combat does not reopen the saved-set picker")
    NS.OpenVendorProfiles(id)
    picker.load.scripts.OnClick()
    check(#calls==1 and shown and not picker.panel:IsShown() and not NS.ui:IsShown(),"Explicit native picker load stages a saved set while leaving final confirmation in the native window")
    local existingPending=pending
    events.scripts.OnEvent(nil,"TRANSMOGRIFY_CLOSE")
    check(pending==existingPending and #calls==1,"Vendor-close handling never clears or commits native pending appearances")
    pending={}; calls={}
    for i=1,7 do T.Save(nil,"Vendor picker "..i,{[0]={sourceID=101,option=12}}) end
    NS.OpenVendorProfiles()
    picker.next.scripts.OnClick()
    check(picker.page==2 and picker.rows[1].entry~=nil and #calls==0,"Saved sets paginate without changing native outfits or appearances")
    picker.prev.scripts.OnClick()
    check(picker.page==1,"Saved-set navigation can return to the first page")
    picker.close.scripts.OnClick()
    check(not picker.panel:IsShown() and shown,"Closing the picker leaves the native transmog window open")
    local originalNative=TransmogFrame
    TransmogFrame=nil
    events.scripts.OnUpdate(events,0.25)
    check(not picker.button:IsShown() and not picker.panel:IsShown(),"Independent overlays hide when the native window is unavailable")
    local visible=true
    local lateNative=setmetatable({IsShown=function() return visible end,GetFrameStrata=function() return "FULLSCREEN" end,
        GetFrameLevel=function() return 200 end,SetScript=Never,HookScript=Never,SetParent=Never,SetSize=Never,
        SetPoint=Never,Show=Never,Hide=Never},{__newindex=Never})
    TransmogFrame=lateNative
    events.scripts.OnUpdate(events,0.1)
    check(NS.vendorProfiles==picker,"Visibility discovery is throttled instead of rebuilding on every frame")
    events.scripts.OnUpdate(events,0.15)
    local overlay=NS.vendorProfiles
    check(overlay.native==lateNative and overlay.button:IsShown() and #calls==0,"Late native UI creation is discovered even when its load/open events were missed")
    check(overlay.button.parent==UIParent and overlay.panel.parent==UIParent and overlay.button.strata=="FULLSCREEN_DIALOG"
        and overlay.button:GetFrameLevel()>200,"Independent controls stay above fullscreen native artwork without modifying the native frame")
    overlay.button.scripts.OnClick()
    visible=false; events.scripts.OnUpdate(events,0.25)
    check(not overlay.button:IsShown() and not overlay.panel:IsShown(),"Visibility checks hide both independent controls when the native screen closes")
    visible=true; events.scripts.OnUpdate(events,0.25)
    check(overlay.button:IsShown() and not overlay.panel:IsShown(),"Reopening the native screen restores the launcher without reopening the picker")
    overlay.button.scripts.OnClick()
    setCombat(true); dispatch("PLAYER_REGEN_DISABLED")
    events.scripts.OnUpdate(events,0.25)
    check(not overlay.button:IsShown() and not overlay.panel:IsShown(),"Combat securely hides both overlay frames and suppresses visibility updates")
    setCombat(false); dispatch("PLAYER_REGEN_ENABLED")
    events.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
    check(overlay.button:IsShown() and not overlay.panel:IsShown() and forbidden==0,"After combat only the launcher returns, without native frame writes or staging")
    events.scripts.OnEvent(nil,"TRANSMOGRIFY_CLOSE")
    TransmogFrame=originalNative
end
NS.ResetSettings(); check(NS.db.transmogProfiles==preserved,"Reset defaults does not erase transmog profiles")
check(NS.db.transmogFavourites[1003],"Reset defaults preserves appearance favourites")
check(forbidden==0,"All transmog UI paths avoid commits, global settings, filter writes and gear changes")
NS.ShowSearchPage(); NS.Close()
NS.db.transmogProfiles=savedProfiles
NS.db.transmogFavourites=savedFavourites
Enum,C_TransmogCollection,C_TransmogOutfitInfo,C_Transmog,C_PaperDollInfo,TransmogFrame=saved.Enum,saved.collection,saved.outfits,saved.transmog,saved.paper,saved.frame
