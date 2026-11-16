local _, NS = ...
local T = {}
NS.Transmog = T
T.pendingItems={}

local function SafeTable(value) return NS.Readable(value) and type(value) == "table" end
local function Number(value) return NS.Readable(value) and type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0 end
local function Flag(value) return NS.Readable(value) and value == true end
T.ValidID = function(value) return Number(value) and value > 0 end
local function Read(func, ...)
    if type(func) ~= "function" then return end
    local ok, value = pcall(func, ...)
    if ok and NS.Readable(value) then return value end
end
T.Read, T.SafeTable = Read, SafeTable
local function API() return C_TransmogOutfitInfo or {} end
local function Collection() return C_TransmogCollection or {} end

function T.Init()
    if type(NS.db.transmogProfiles) ~= "table" then NS.db.transmogProfiles = {} end
    if type(NS.db.transmogFavourites) ~= "table" then NS.db.transmogFavourites = {} end
end

function T.Slots()
    local info = Read(API().GetAllSlotLocationInfo)
    local result = {}
    for _, slot in ipairs(SafeTable(info) and info or {}) do
        -- Primary appearance slots only. Illusions and independently split
        -- shoulders are left to Blizzard, never reset by a profile.
        if SafeTable(slot) and Number(slot.slot) and Number(slot.type) and slot.type == 0
            and NS.Readable(slot.isSecondary) and not slot.isSecondary and NS.Readable(slot.slotName) and type(slot.slotName) == "string" then
            local inventorySlot = Read(C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo, slot.slotName)
            if Number(inventorySlot) and inventorySlot > 0 then
                result[#result + 1] = {slot=slot.slot, type=slot.type, inventorySlot=inventorySlot,
                    category=slot.collectionType, name=_G[slot.slotName] or slot.slotName,
                    icon="Interface\\PaperDoll\\UI-PaperDoll-Slot-"..(({[1]="Head",[3]="Shoulder",[4]="Shirt",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",[9]="Wrists",[10]="Hands",[15]="Chest",[16]="MainHand",[17]="SecondaryHand",[18]="Ranged",[19]="Tabard"})[inventorySlot] or "Chest"),
                    location={slotID=inventorySlot, type=slot.type, modification=0}}
            end
        end
    end
    return result
end

function T.Options(slot, includeDisabled)
    local options, result = Read(API().GetOptionsForSlot, slot.slot), {}
    for _, option in ipairs(SafeTable(options) and options or {}) do
        if SafeTable(option) and Number(option.type) and NS.Readable(option.enabled) and (includeDisabled or option.enabled == true) then
            result[#result + 1] = {id=option.type, name=NS.CleanName(option.name) or ("Option " .. option.type)}
        end
    end
    return result
end

function T.DefaultOption(slot)
    local equipped = Read(API().GetEquippedSlotOptionFromTransmogSlot, slot.slot)
    local options = T.Options(slot)
    for _, option in ipairs(options) do if option.id == equipped then return option.id end end
    return options[1] and options[1].id
end

function T.Categories(slot)
    local weaponSlot=slot.inventorySlot==16 or slot.inventorySlot==17 or slot.inventorySlot==18
    if not weaponSlot and Number(slot.category) and slot.category > 0 then return {{id=slot.category,name=slot.name}} end
    local result, seen = {}, {}
    local options=T.Options(slot)
    for _, category in pairs(Enum and Enum.TransmogCollectionType or {}) do
        if Number(category) and category > 0 and not seen[category] then
            seen[category] = true
            -- The native wardrobe asks this table-returning API for each
            -- enabled outfit option. Collection.GetCategoryInfo instead returns
            -- several separate values; treating its first string as a table
            -- previously discarded every weapon category.
            for _,option in ipairs(options) do
                local info=Read(API().GetCollectionInfoForSlotAndOption,slot.slot,option.id,category)
                if SafeTable(info) and Flag(info.isWeapon) then
                    result[#result+1]={id=category,name=NS.CleanName(info.name) or ("Category "..category)}
                    break
                end
            end
        end
    end
    table.sort(result,function(a,b) return a.id < b.id end)
    return result
end

function T.Source(sourceID)
    if not Number(sourceID) or sourceID <= 0 then return end
    local info = Read(Collection().GetSourceInfo, sourceID)
    if not SafeTable(info) then return end
    local appearance = Read(Collection().GetAppearanceSourceInfo, sourceID)
    local link = SafeTable(appearance) and NS.Readable(appearance.itemLink) and type(appearance.itemLink) == "string" and appearance.itemLink or nil
    local name = NS.CleanName(info.name) or (link and NS.CleanName(link:match("|h%[(.-)%]|h")))
    if not name and Number(info.itemID) and Read(C_Item and C_Item.IsItemDataCachedByID,info.itemID)==true then
        name=NS.CleanName(Read(C_Item and C_Item.GetItemInfo,info.itemID))
    end
    if Number(info.itemID) then T.pendingItems[info.itemID]=not name or nil end
    local usable,reason = T.Usability(info)
    local icon = Read(Collection().GetSourceIcon,sourceID)
    if not NS.Readable(icon) or type(icon) ~= "number" and type(icon) ~= "string" then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end
    return {sourceID=sourceID,name=name or ("Appearance "..sourceID),namePending=not name,icon=icon,usable=usable,reason=reason,link=link,itemID=Number(info.itemID) and info.itemID or nil,
        visualID=Number(info.visualID) and info.visualID or nil,category=Number(info.categoryID) and info.categoryID or nil,
        collected=NS.Readable(info.isCollected) and info.isCollected == true,
        hidden=Read(Collection().IsAppearanceHiddenVisual,sourceID) == true}
end

function T.Usability(source)
    if not SafeTable(source) then return nil,"Source data unavailable" end
    for _,field in ipairs({"useErrorType","useError","isValidSourceForPlayer","canDisplayOnPlayer"}) do
        if not NS.Readable(source[field]) then return nil,"Usability data unreadable" end
    end
    if source.useErrorType ~= nil or source.useError and source.useError ~= "" then
        return false,NS.CleanName(source.useError) or "The client reports an appearance restriction"
    end
    if source.isValidSourceForPlayer == false or source.canDisplayOnPlayer == false then return false,"Unavailable for this character" end
    -- The native helper accepts a readable absent useErrorType. Additional
    -- optional flags need not be explicitly true; an explicit false still wins.
    return true
end

function T.ToggleFavourite(visualID)
    if InCombatLockdown() or not T.ValidID(visualID) then return end
    local favourites=NS.db.transmogFavourites
    if favourites[visualID] then favourites[visualID]=nil; return false end
    local count=0; for _ in pairs(favourites) do count=count+1 end
    if count>=500 then return nil,"Appearance favourites are full (500)." end
    favourites[visualID]=true; return true
end

function T.SupportsCategory(slot,option,category)
    if type(API().GetCollectionInfoForSlotAndOption)=="function" then
        return SafeTable(Read(API().GetCollectionInfoForSlotAndOption,slot.slot,option,category))
    end
    -- Older/missing APIs can still enumerate the fixed armour category
    -- declared by the slot descriptor. Never guess weapon/type combinations.
    return Number(slot.category) and slot.category>0 and slot.category==category
end

function T.Available(slot, option, category, query, usableOnly)
    local stats={returned=0,uncollected=0,restricted=0,unknown=0,queryHidden=0,apiFailures=0,unsupported=0,pendingItems={}}
    local function Finish(rows) rows.diagnostics=stats; return rows end
    if not Number(option) or not Number(category) or category <= 0 then return {} end
    if not T.SupportsCategory(slot,option,category) then stats.unsupported=1; return Finish({}) end
    -- Forever requires the complete inventory location even though the API
    -- declares it optional. Never change shared class/race/collection filters.
    local appearances = Read(Collection().GetCategoryAppearances,category,slot.location,option)
    if not SafeTable(appearances) then stats.apiFailures=1; return Finish({}) end
    local rows, seen = {}, {}
    query = string.lower(query or "")
    for _, appearance in ipairs(appearances) do
        stats.returned=stats.returned+1
        if SafeTable(appearance) and Number(appearance.visualID) and NS.Readable(appearance.isCollected)
            and appearance.isCollected == true then
            local sources = Read(Collection().GetAppearanceSources,appearance.visualID,category,slot.location)
            if not SafeTable(sources) then stats.unknown=stats.unknown+1 end
            for _, source in ipairs(SafeTable(sources) and sources or {}) do
                if SafeTable(source) and Number(source.sourceID) and NS.Readable(source.isCollected) and source.isCollected == true
                    and not seen[source.sourceID] then
                    local info = T.Source(source.sourceID)
                    if not info then stats.unknown=stats.unknown+1
                    elseif info.collected then
                        info.option,info.category=option,category
                        info.visualID=appearance.visualID
                        -- A visual-level explicit restriction also marks the
                        -- source as preview-only, never as collected-and-usable.
                        if not NS.Readable(appearance.isUsable) then info.usable,info.reason=nil,"Visual usability unreadable"
                        elseif appearance.isUsable == false then info.usable,info.reason=false,info.reason or "Unavailable for this type/character" end
                        if info.namePending and info.itemID then stats.pendingItems[info.itemID]=true end
                        if info.usable ~= true then stats.restricted=stats.restricted+1 end
                        if usableOnly ~= false and info.usable ~= true then
                            -- Counted above; default compatibility path is usable-only.
                        elseif query ~= "" and not (string.lower(info.name):find(query,1,true) or tostring(source.sourceID)==query or tostring(info.itemID)==query) then
                            stats.queryHidden=stats.queryHidden+1
                        else seen[source.sourceID],rows[#rows+1]=true,info end
                    end
                end
                NS.WorkYield()
            end
        elseif SafeTable(appearance) and NS.Readable(appearance.isCollected) and appearance.isCollected == false then
            stats.uncollected=stats.uncollected+1
        else stats.unknown=stats.unknown+1
        end
        NS.WorkYield()
    end
    return Finish(NS.SortResults(rows,function(a,b) return a.name == b.name and a.sourceID < b.sourceID or a.name < b.name end))
end

function T.Browse(slot, optionID, categoryID, query, preferences)
    preferences=preferences or {}
    local options=optionID and {{id=optionID}} or T.Options(slot)
    local categories=categoryID and {{id=categoryID}} or T.Categories(slot)
    local grouped,byVisual={},{}
    local stats={returned=0,uncollected=0,restricted=0,unknown=0,apiFailures=0,queryHidden=0,favouriteHidden=0,unique=0,pendingItems={}}
    for _,option in ipairs(options) do
        for _,category in ipairs(categories) do
            local rows=T.Available(slot,option.id,category.id,"",false)
            for key,value in pairs(rows.diagnostics or {}) do
                if type(value)=="number" then stats[key]=(stats[key] or 0)+value end
            end
            for id in pairs(rows.diagnostics and rows.diagnostics.pendingItems or {}) do stats.pendingItems[id]=true end
            for _,row in ipairs(rows) do
                local group=byVisual[row.visualID]
                if not group then group={visualID=row.visualID,alternatives={},seen={}}; byVisual[row.visualID]=group; grouped[#grouped+1]=group end
                local key=row.sourceID..":"..row.option
                if not group.seen[key] then group.seen[key]=true; group.alternatives[#group.alternatives+1]=row end
                NS.WorkYield()
            end
            NS.WorkYield()
        end
    end
    local result={}
    query=string.lower((query or ""):match("^%s*(.-)%s*$"))
    for _,group in ipairs(grouped) do
        stats.unique=stats.unique+1
        group.alternatives=NS.SortResults(group.alternatives,function(a,b)
            if (a.usable==true) ~= (b.usable==true) then return a.usable==true end
            if a.name~=b.name then return a.name<b.name end
            return a.sourceID==b.sourceID and a.option<b.option or a.sourceID<b.sourceID
        end)
        local chosen
        for _,row in ipairs(group.alternatives) do
            local text=string.lower(row.name.." "..tostring(row.sourceID).." "..tostring(row.itemID or "").." "..group.visualID)
            local matches=true
            for word in query:gmatch("%S+") do if not text:find(word,1,true) then matches=false; break end end
            if matches and (not preferences.usableOnly or row.usable==true) then chosen=chosen or row end
            NS.WorkYield()
        end
        if not chosen then stats.queryHidden=stats.queryHidden+1
        elseif preferences.favouritesOnly and not NS.db.transmogFavourites[group.visualID] then stats.favouriteHidden=stats.favouriteHidden+1
        else
            local entry={alternatives=group.alternatives}
            for key,value in pairs(chosen) do entry[key]=value end
            result[#result+1]=entry
        end
        NS.WorkYield()
    end
    result=NS.SortResults(result,function(a,b)
        if preferences.sort=="favourites" then
            local af,bf=not not NS.db.transmogFavourites[a.visualID],not not NS.db.transmogFavourites[b.visualID]
            if af~=bf then return af end
        end
        return a.name==b.name and a.visualID<b.visualID or a.name<b.name
    end)
    result.diagnostics=stats
    return result
end

function T.SameSlots(a,b)
    for key,value in pairs(a) do if not b[key] or value.sourceID~=b[key].sourceID or value.option~=b[key].option then return false end end
    for key in pairs(b) do if not a[key] then return false end end
    return true
end

function T.IsSlotAppearanceUsable(slot,option,category,visualID)
    if not T.SupportsCategory(slot,option,category) then return false end
    local entries=Read(Collection().GetCategoryAppearances,category,slot.location,option)
    if not SafeTable(entries) then return false end
    for _,entry in ipairs(entries) do
        if SafeTable(entry) and Number(entry.visualID) and entry.visualID==visualID
            and Flag(entry.isCollected) and Flag(entry.isUsable) then return true end
    end
    return false
end

function T.CopySlots(slots)
    local result = {}
    for slot, choice in pairs(type(slots) == "table" and slots or {}) do
        if Number(slot) and SafeTable(choice) and Number(choice.sourceID) and choice.sourceID > 0 and Number(choice.option) then
            result[slot] = {sourceID=choice.sourceID,option=choice.option}
        end
    end
    return result
end

function T.Save(id, name, slots)
    if InCombatLockdown() then return nil,"Save profiles after combat." end
    name = NS.CleanName(name)
    if not name or #name > 60 then return nil,"Enter a profile name of 1–60 characters." end
    local profiles, count, highest = NS.db.transmogProfiles,0,0
    for key, profile in pairs(profiles) do
        if Number(key) then highest=math.max(highest,key) end
        count=count+1
        if key ~= id and type(profile) == "table" and type(profile.name) == "string" and string.lower(profile.name) == string.lower(name) then
            return nil,"Another profile already has that name."
        end
    end
    if id ~= nil and (not T.ValidID(id) or not profiles[id]) then return nil,"This profile no longer exists." end
    if not id and count >= 50 then return nil,"Profiles are full (50). Delete one before saving another." end
    id = id or highest+1
    profiles[id] = {id=id,name=name,slots=T.CopySlots(slots),updated=time()}
    return id
end

function T.Delete(id)
    if not InCombatLockdown() and T.ValidID(id) then NS.db.transmogProfiles[id] = nil end
end

function T.Capture()
    if InCombatLockdown() then return nil,"Capture your look after combat." end
    local result = {}
    for _, slot in ipairs(T.Slots()) do
        local visual = Read(C_Transmog and C_Transmog.GetSlotVisualInfo,slot.location)
        local option = T.DefaultOption(slot)
        if SafeTable(visual) and option then
            local source = Number(visual.appliedSourceID) and visual.appliedSourceID > 0 and visual.appliedSourceID or visual.baseSourceID
            if Number(source) and source > 0 then result[slot.slot] = {sourceID=source,option=option} end
        end
    end
    if not next(result) then return nil,"No readable current appearances. Open Blizzard's transmog screen and retry." end
    return result
end

function T.Preview(model, slots, reuseUnit)
    if InCombatLockdown() or not model or not SafeTable(slots) then return false end
    local complete = true
    local ok = pcall(function()
        if not reuseUnit then model:SetUnit("player") end
        -- Dress the private preview from the real character each time so that
        -- removing an override restores the baseline instead of leaving a ghost.
        model:Dress()
        for _, slot in ipairs(T.Slots()) do
            local choice = slots[slot.slot]
            if choice then
                local info = T.Source(choice.sourceID)
                if info and info.hidden then model:UndressSlot(slot.inventorySlot)
                elseif info then
                    model:TryOn(choice.sourceID,slot.inventorySlot == 16 and "MAINHANDSLOT" or slot.inventorySlot == 17 and "SECONDARYHANDSLOT" or nil)
                else complete = false end
            end
        end
    end)
    return ok and complete
end

function T.VendorReady()
    if InCombatLockdown() then return false,"Transmog preparation is unavailable in combat." end
    local api = API()
    if not C_Transmog or Read(C_Transmog.IsAtTransmogNPC) ~= true then return false,"Talk to a transmogrifier first." end
    if not TransmogFrame or not TransmogFrame:IsShown() then return false,"Open Blizzard's transmogrifier screen first." end
    if Read(api.IsTransmogEnabled) ~= true then return false,"Transmog is disabled or unavailable; this addon will not enable it." end
    local outfitID = Read(api.GetCurrentlyViewedOutfitID)
    if not Number(outfitID) or outfitID <= 0 then return false,"Choose an editable outfit in Blizzard's transmog screen first." end
    if Read(api.IsLockedOutfit,outfitID) ~= false then return false,"The selected Blizzard outfit is locked or its state is unavailable." end
    if type(api.SetPendingTransmog) ~= "function" or (type(api.HasPendingOutfitTransmogs) ~= "function" and type(api.GetViewedOutfitSlotInfo) ~= "function") then
        return false,"This client's vendor preparation API is unavailable."
    end
    return true,"Ready to prepare appearances. Confirm and pay only in Blizzard's screen."
end

local function PendingEditsClear(api)
    if type(api.HasPendingOutfitSituations)=="function" then
        local pending=Read(api.HasPendingOutfitSituations)
        if type(pending)~="boolean" then return false,"Cannot verify pending outfit situations; nothing was loaded." end
        if pending then return false,"Save or discard your pending Blizzard situation edits before loading a profile." end
    end
    -- The outfit-wide flag includes unused/class-specific slots, secondary
    -- shoulders, disabled options, weapon illusions and artifact options.
    -- Such slots need not have selectable options on this character.
    if type(api.HasPendingOutfitTransmogs)=="function" then
        local pending=Read(api.HasPendingOutfitTransmogs)
        if type(pending)~="boolean" then return false,"Cannot verify existing vendor edits; nothing was loaded." end
        if pending then return false,"Save or discard your pending Blizzard edits before loading a profile." end
        return true
    end
    -- Older builds without the aggregate read retain the conservative scan.
    local ok, appearances, illusions = pcall(api.GetAllSlotLocationInfo)
    if not ok or not SafeTable(appearances) or not SafeTable(illusions) then return false,"Cannot verify pending slot edits; nothing was loaded." end
    for _, list in ipairs({appearances,illusions}) do
        for _, slot in ipairs(list) do
            if not SafeTable(slot) then return false,"Slot data is unavailable." end
            local optionsOK,regular,artifacts=pcall(api.GetOptionsForSlot,slot.slot)
            if not optionsOK or not SafeTable(regular) or (artifacts~=nil and not SafeTable(artifacts)) then
                return false,"Cannot verify pending options for this outfit; nothing was loaded."
            end
            local count=0
            for _,options in ipairs({regular,artifacts or {}}) do
              for _,option in ipairs(options) do
                if not SafeTable(option) or not Number(option.type) then return false,"Cannot verify pending options for this outfit; nothing was loaded." end
                count=count+1
                local existing = Read(api.GetViewedOutfitSlotInfo,slot.slot,slot.type,option.type)
                if not SafeTable(existing) or not NS.Readable(existing.hasPending) or type(existing.hasPending) ~= "boolean" then
                    return false,"Cannot verify existing vendor edits; nothing was loaded."
                end
                if existing.hasPending then return false,"Save or discard your pending Blizzard edits before loading a profile." end
              end
            end
            if count==0 then return false,"Cannot verify pending options for this outfit; nothing was loaded." end
        end
    end
    return true
end

function T.Stage(slots)
    if not SafeTable(slots) then return false,"The profile is invalid." end
    local ready, message = T.VendorReady()
    if not ready then return false,message end
    local api, plan, known = API(),{},{}
    local clear,why=PendingEditsClear(api)
    if not clear then return false,why end
    for _, slot in ipairs(T.Slots()) do
        known[slot.slot] = true
        local choice = slots[slot.slot]
        if choice then
            if not SafeTable(choice) or not Number(choice.sourceID) or not Number(choice.option) then return false,"The profile contains an invalid appearance." end
            local optionOK = false
            for _, option in ipairs(T.Options(slot)) do if choice.option == option.id then optionOK = true end end
            local info = T.Source(choice.sourceID)
            if not optionOK or not info or not info.collected then return false,slot.name..": appearance is unavailable or not collected." end
            local categoryOK, allowed = false,false
            for _, category in ipairs(T.Categories(slot)) do if category.id == info.category then categoryOK = true end end
            if categoryOK and Number(info.visualID) then
                local sources = Read(Collection().GetAppearanceSources,info.visualID,info.category,slot.location)
                for _, source in ipairs(SafeTable(sources) and sources or {}) do
                    if SafeTable(source) and NS.Readable(source.sourceID) and source.sourceID == choice.sourceID
                        and NS.Readable(source.isCollected) and source.isCollected == true
                        and T.Usability(source) == true
                        and NS.Readable(source.isValidForEquippedItem) and source.isValidForEquippedItem ~= false then allowed = true; break end
                end
            end
            if not allowed then return false,slot.name..": cannot verify this collected appearance is usable for this slot." end
            if not T.IsSlotAppearanceUsable(slot,choice.option,info.category,info.visualID) then
                return false,slot.name..": the native collection does not report this appearance usable for the chosen type."
            end
            if Read(api.CanPlayerTransmogSlot,slot.slot) ~= true then return false,slot.name..": this slot cannot currently be transmogrified." end
            plan[#plan+1] = {slot=slot.slot,type=slot.type,option=choice.option,sourceID=choice.sourceID,display=info.hidden and 3 or 1}
        end
    end
    for slot in pairs(slots) do if not known[slot] then return false,"The profile contains slots this client cannot prepare." end end
    if #plan == 0 then return false,"Choose at least one appearance before loading at the vendor." end
    -- This function is called directly by our button handler only. No event,
    -- timer, login callback or vendor-open callback calls a transmog writer.
    for _, change in ipairs(plan) do
        local ok = pcall(api.SetPendingTransmog,change.slot,change.type,change.option,change.sourceID,change.display)
        if not ok then return false,"The client refused a pending appearance. Review/discard any partial preview in Blizzard's screen; nothing was committed." end
    end
    return true,"Loaded into Blizzard's pending preview. Review its warnings and cost, then click Blizzard's Save Outfit to apply."
end
