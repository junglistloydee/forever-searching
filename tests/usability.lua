local NS,check,drain,setCombat=...
NS.OpenSearch(); drain()
NS.selected=nil; NS.ui.search:SetText(""); drain()
check(not NS.ui.favourite:IsShown() and not NS.ui.navigate:IsShown() and not NS.ui.wowheadButton:IsShown(),"Empty selection hides contextual actions")
local mode=NS.db.settings.searchMode
NS.ui.modeButton.scripts.OnClick()
check(NS.db.settings.searchMode==mode and NS.ui.choiceMenu:IsShown(),"Mode button opens choices without changing the search")
NS.ui.choiceMenu.rows[2].scripts.OnClick(); drain()
check(NS.db.settings.searchMode=="npc" and not NS.ui.choiceMenu:IsShown(),"Choosing NPCs switches mode directly")
local menu=NS.ui.choiceMenu
NS.ui.sourceFilter.scripts.OnClick()
check(NS.ui.choiceMenu==menu,"Search controls reuse their menu instead of leaking frames")
NS.ui.choiceMenu.rows[2].scripts.OnClick(); drain()
check(NS.db.settings.sourceFilter=="vendors","Source dropdown directly selects vendors")
NS.ui.quickSort.scripts.OnClick(); NS.ui.choiceMenu.rows[2].scripts.OnClick(); drain()
check(NS.db.settings.sort=="name","Result-header sort directly selects names")
NS.ui.modeButton.scripts.OnClick(); setCombat(true)
NS.ui.choiceMenu.rows[4].scripts.OnClick()
check(NS.db.settings.searchMode=="npc","Menu selection cannot change search state in combat")
setCombat(false)
NS.db.settings.sort="distance"; NS.db.settings.sourceFilter="all"
NS.ui.search:SetText(""); drain()
NS.ui.page=1; NS.ui.listInset.scripts.OnMouseWheel(NS.ui.listInset,-1)
check(NS.ui.page==math.min(2,math.max(1,math.ceil(#NS.ui.displayRows/6))),"Mouse wheel advances result pages within bounds")
NS.Close()
check(not menu:IsShown(),"Closing search dismisses its dropdown")

local oldHook,oldModern,oldLegacy,oldShift=hooksecurefunc,ChatFrameUtil,ChatEdit_InsertLink,IsShiftKeyDown
local callback,hookCount,shift=nil,0,true
ChatFrameUtil={InsertLink=function() return false end}
local nativeInsert=ChatFrameUtil.InsertLink
hooksecurefunc=function(owner,key,fn)
    hookCount=hookCount+1
    if type(owner)=="table" then
        check(owner==ChatFrameUtil and key=="InsertLink","Modern chat link hook targets native insertion")
        callback=fn
    else
        check(owner=="ChatEdit_InsertLink","Legacy client uses chat insertion fallback")
        callback=key
    end
end
IsShiftKeyDown=function() return shift end
NS.InstallSearchLinkHook(); NS.InstallSearchLinkHook()
check(hookCount==1 and ChatFrameUtil.InsertLink==nativeInsert,"Link hook installs once without replacing native function")
NS.OpenSearch(); drain()
NS.db.settings.searchMode="quest"
callback("|cffffffff|Hitem:117:0:0:0|h[Tough Jerky]|h|r"); drain()
check(NS.ui.search:GetText()=="117" and NS.db.settings.searchMode=="item","Focused Shift-click searches exact item ID in Items mode")
local function ignored(link,label)
    NS.ui.search:SetText("unchanged"); drain()
    callback(link); drain()
    check(NS.ui.search:GetText()=="unchanged",label)
end
ignored("|Hquest:117:1|h[Quest]|h","Quest links do not trigger item search")
ignored("|Hitem:0:0|h[Invalid]|h","Invalid item IDs are ignored")
shift=false; ignored("item:118","Unmodified clicks do not trigger search"); shift=true
NS.ui.search:ClearFocus(); ignored("item:118","Unfocused search does not capture links")
NS.ui.search:SetFocus(); setCombat(true); callback("item:118")
check(NS.ui.search:GetText()=="unchanged","Item link searches are blocked during combat"); setCombat(false)
NS.ui.transmogPanel:Show(); ignored("item:118","Wardrobe does not capture main search links"); NS.ui.transmogPanel:Hide()
NS.Close(); NS.ui.search:SetFocus(); ignored("item:118","Hidden window does not capture links")
NS.searchLinkHookInstalled=nil; ChatFrameUtil=nil; ChatEdit_InsertLink=function() end
NS.InstallSearchLinkHook()
check(hookCount==2,"Legacy insertion API is supported")
hooksecurefunc,ChatFrameUtil,ChatEdit_InsertLink,IsShiftKeyDown=oldHook,oldModern,oldLegacy,oldShift

NS.OpenSearch(); drain()
NS.RunWork("search",function() NS.SetWorkStage("Sorting results"); coroutine.yield() end,function() end)
NS.UpdateSearchProgress(0.1)
check(NS.SearchActivity()=="Sorting results" and NS.ui.searchProgress:IsShown() and not NS.ui.status:IsShown(),"Active search displays stage and progress without overlapping status")
NS.CancelWork("search"); NS.UpdateSearchProgress(0.1)
check(not NS.SearchActivity() and not NS.ui.searchProgress:IsShown() and NS.ui.status:IsShown(),"Cancellation removes progress and restores status")
NS.RunWork("itemIndex",function() coroutine.yield() end,function() end)
NS.UpdateSearchProgress(0.1)
check(NS.SearchActivity()=="Loading items" and NS.ui.searchProgress:IsShown(),"Initial item indexing displays progress")
drain(); NS.UpdateSearchProgress(0.1)
check(not NS.ui.searchProgress:IsShown(),"Completed indexing clears progress")
local failed=false
NS.RunWork("search",function() coroutine.yield(); error("test failure") end,function() end,function() failed=true end)
drain(); NS.UpdateSearchProgress(0.1)
check(failed and not NS.ui.searchProgress:IsShown(),"Failed searches cannot leave a stuck progress bar")
setCombat(true); NS.UpdateSearchProgress(0.1); setCombat(false)
NS.Close()
