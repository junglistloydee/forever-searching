local _, NS = ...
local function Bit(mask, flag)
    return type(mask) == "number" and type(flag) == "number" and flag > 0 and math.floor(mask / flag) % 2 == 1
end
local function SingleBit(number)
    if type(number) ~= "number" or number <= 0 then return false end
    while number > 1 and number % 2 == 0 do number = number / 2 end
    return number == 1
end
local function PlayerValue(func, index)
    if not func then return end
    local values = {pcall(func, "player")}
    if values[1] and NS.Readable(values[index + 1]) then return values[index + 1] end
end

function NS.QuestRequirements(questID)
    local db = LibQuestieDB
    if not db or not db.Quest then return "QuestieDB quest requirements are unavailable." end
    local keys = {"name", "requiredLevel", "requiredRaces", "requiredClasses", "preQuestSingle", "preQuestGroup", "requiredSkill", "requiredMinRep", "requiredMaxRep"}
    local values = db.Quest.GetAll(questID, keys)
    if not values then return "No requirements are recorded for this quest." end
    local lines = {values[1] or ("Quest " .. questID), ""}
    local level = PlayerValue(UnitLevel, 1)
    if type(values[2]) == "number" and values[2] > 0 then
        local status = type(level) == "number" and (level >= values[2] and " · level met" or " · level too low") or " · your level unknown"
        lines[#lines + 1] = "Minimum level: " .. values[2] .. status
    else lines[#lines + 1] = "Minimum level: no minimum recorded" end
    local classKeys = db.Enum and db.Enum.classKeys or {}
    local classNames = {}
    if type(values[4]) == "number" and values[4] > 0 then
        for name, mask in pairs(classKeys) do
            if SingleBit(mask) and Bit(values[4], mask) and not name:find("ALL", 1, true) then
                classNames[#classNames + 1] = name:gsub("_", " ")
            end
        end
        table.sort(classNames)
        local playerClass = PlayerValue(UnitClass, 2)
        local playerBit = playerClass and classKeys[playerClass]
        lines[#lines + 1] = "Allowed classes: " .. (#classNames > 0 and table.concat(classNames, ", ") or "restriction recorded; names unavailable")
        lines[#lines + 1] = "Your class: " .. (playerBit and (Bit(values[4], playerBit) and "matches" or "does not match") or "unknown")
    else lines[#lines + 1] = "Class: no restriction recorded" end
    local raceMasks = db.Enum and db.Enum.raceMaskById or {}
    local races = {}
    if type(values[3]) == "number" and values[3] > 0 then
        for raceID, mask in pairs(raceMasks) do
            if Bit(values[3], mask) then
                local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(raceID)
                races[#races + 1] = info and info.raceName or ("Race #" .. raceID)
            end
        end
        table.sort(races)
        local raceID = PlayerValue(UnitRace, 3)
        local playerBit = raceID and raceMasks[raceID]
        lines[#lines + 1] = "Allowed races: " .. (#races > 0 and table.concat(races, ", ") or "restriction recorded; names unavailable")
        lines[#lines + 1] = "Your race: " .. (playerBit and (Bit(values[3], playerBit) and "matches" or "does not match") or "unknown")
    else lines[#lines + 1] = "Race: no restriction recorded" end
    for _, section in ipairs({{5, "Prerequisites (one of)"}, {6, "Prerequisites (all of)"}}) do
        local list = values[section[1]]
        lines[#lines + 1] = ""
        lines[#lines + 1] = section[2] .. ":"
        if type(list) ~= "table" or #list == 0 then lines[#lines + 1] = "None recorded" else
            for _, id in ipairs(list) do
                local name = db.Quest.Get(math.abs(id), "name") or ("Quest " .. math.abs(id))
                local status = "completion unknown"
                if id < 0 then status = "special condition; not evaluated"
                elseif C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
                    if ok and NS.Readable(completed) and type(completed) == "boolean" then
                        status = completed and "completed" or "not completed"
                    end
                end
                lines[#lines + 1] = name .. " · " .. status
                NS.WorkYield()
            end
        end
    end
    for _, pair in ipairs({{7, "Profession requirement"}, {8, "Minimum reputation"}, {9, "Maximum reputation"}}) do
        local requirement = values[pair[1]]
        if type(requirement) == "table" and next(requirement) then
            lines[#lines + 1] = pair[2] .. ": recorded ID " .. tostring(requirement[1]) .. ", value " .. tostring(requirement[2]) .. " (not evaluated)"
        end
    end
    lines[#lines + 1] = "\nRecorded requirements do not prove that you can accept this quest now. Event, phase, chain exceptions and other conditions may be unknown."
    return table.concat(lines, "\n")
end
