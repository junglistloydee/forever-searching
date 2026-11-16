local _, NS = ...
local jobs, threads = {}, {}
function NS.SetWorkStage(label)
    local job = threads[coroutine.running()]
    if job then job.stage = label end
end

function NS.SearchActivity()
    for _, entry in ipairs({{"catalogue", "Loading NPCs"}, {"itemIndex", "Loading items"},
        {"questIndex", "Loading quests"}, {"search", "Finding closest sources"}}) do
        local job = jobs[entry[1]]
        if job then return job.stage or entry[2] end
    end
end
local function Clock()
    return debugprofilestop and debugprofilestop() or os.clock() * 1000
end

function NS.WorkYield()
    local job = threads[coroutine.running()]
    if not job then return end
    job.steps = job.steps + 1
    if job.steps >= 128 or Clock() >= job.deadline then coroutine.yield() end
end

function NS.RunWork(key, work, complete, failed)
    local previous = jobs[key]
    if previous then threads[previous.thread] = nil end
    local job = {thread = coroutine.create(work)}
    jobs[key], threads[job.thread] = job, job
    local function Resume()
        if jobs[key] ~= job then return end
        if InCombatLockdown() then C_Timer.After(0.2, Resume); return end
        job.deadline, job.steps = Clock() + 3, 0
        local ok, result = coroutine.resume(job.thread)
        if not ok or coroutine.status(job.thread) == "dead" then
            jobs[key], threads[job.thread] = nil, nil
            if ok then complete(result) elseif failed then failed(result) end
        else C_Timer.After(0.01, Resume) end
    end
    -- Small searches still finish immediately; larger jobs yield before blocking a frame.
    Resume()
end

function NS.CancelWork(key)
    local job = jobs[key]
    if job then threads[job.thread], jobs[key] = nil, nil end
end

function NS.SortResults(items, less)
    -- Native table.sort cannot yield. Merge sort keeps large result lists inside
    -- the same cooperative frame budget as location indexing and filtering.
    local size, width, buffer = #items, 1, {}
    while width < size do
        for start = 1, size, width * 2 do
            local middle, finish = math.min(start + width - 1, size), math.min(start + width * 2 - 1, size)
            local left, right = start, middle + 1
            for index = start, finish do
                if left <= middle and (right > finish or not less(items[right], items[left])) then
                    buffer[index], left = items[left], left + 1
                else buffer[index], right = items[right], right + 1 end
                if index % 64 == 0 then NS.WorkYield() end
            end
        end
        items, buffer, width = buffer, items, width * 2
    end
    return items
end
