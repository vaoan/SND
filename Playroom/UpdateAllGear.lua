--[=====[
[[SND Metadata]]
author: 'Heiner'
version: 1.0.0
description: Cycles through all Crafters and Gatherers and updates their gear with recommended equipment
plugin_dependencies:
- AutoDuty
[[End Metadata]]
--]=====]

--[[
================================================================================
                            UPDATE ALL GEAR
                              Version 1.0.0
================================================================================

Simple utility script that cycles through all Crafter (DoH) and Gatherer (DoL)
jobs and equips recommended gear for each one.

HOW IT WORKS:
-------------
1. Loops through all 8 Crafters and 3 Gatherers
2. For each job, switches gearset and runs /ad equiprec
3. Returns to the original job when done

REQUIREMENTS:
-------------
- AutoDuty plugin (for /ad equiprec - equip recommended gear)
- Gearsets configured for all DoH/DoL jobs

================================================================================
]]

-- Job Categories
local CrafterJobs = {
    { id = 8,  abbr = "CRP", name = "Carpenter" },
    { id = 9,  abbr = "BSM", name = "Blacksmith" },
    { id = 10, abbr = "ARM", name = "Armorer" },
    { id = 11, abbr = "GSM", name = "Goldsmith" },
    { id = 12, abbr = "LTW", name = "Leatherworker" },
    { id = 13, abbr = "WVR", name = "Weaver" },
    { id = 14, abbr = "ALC", name = "Alchemist" },
    { id = 15, abbr = "CUL", name = "Culinarian" },
}

local GathererJobs = {
    { id = 16, abbr = "MIN", name = "Miner" },
    { id = 17, abbr = "BTN", name = "Botanist" },
    { id = 18, abbr = "FSH", name = "Fisher" },
}

-- Find gearset for a job and return the UI slot number
local function FindGearsetSlot(jobId)
    for idx = 1, 100 do
        local gs = Player.GetGearset(idx)
        if gs and gs.ClassJob == jobId then
            -- IMPORTANT: UI slot = API index + 1
            return idx + 1, gs.Name
        end
    end
    return nil, nil
end

-- Character conditions that block job switching
local CharacterCondition = {
    crafting = 5,
    occupied = 25,
    occupiedInEvent = 31,
    occupiedInQuestEvent = 32,
    boundByDuty34 = 34,
    executingCraftingSkill = 40,
    boundByDuty56 = 56,
    boundByDuty95 = 95,
}

-- Check if anything is blocking job switch
local function IsBlockedFromSwitching()
    return Svc.Condition[CharacterCondition.crafting] or
           Svc.Condition[CharacterCondition.executingCraftingSkill] or
           Svc.Condition[CharacterCondition.occupied] or
           Svc.Condition[CharacterCondition.occupiedInEvent] or
           Svc.Condition[CharacterCondition.occupiedInQuestEvent] or
           Svc.Condition[CharacterCondition.boundByDuty34] or
           Svc.Condition[CharacterCondition.boundByDuty56] or
           Svc.Condition[CharacterCondition.boundByDuty95]
end

-- Switch to a job and update gear (retries until successful)
local function UpdateJobGear(job)
    local uiSlot, gsName = FindGearsetSlot(job.id)

    if not uiSlot then
        yield("/echo [UpdateAllGear] WARNING: No gearset found for " .. job.name .. " (" .. job.abbr .. ")")
        return false
    end

    yield("/echo [UpdateAllGear] Switching to " .. job.abbr .. " (" .. gsName .. ")...")

    -- Keep trying until we successfully switch
    while true do
        -- Wait if blocked
        if IsBlockedFromSwitching() then
            yield("/echo [UpdateAllGear] Waiting for blocking condition to clear...")
            yield("/wait 1")
        else
            -- Try to switch
            yield("/gearset change " .. uiSlot)
            yield("/wait 1")

            -- Check if switch worked
            local lp = Svc.ClientState.LocalPlayer
            if lp and lp.ClassJob.RowId == job.id then
                -- Success! Update gear
                yield("/echo [UpdateAllGear] Updating gear for " .. job.abbr .. "...")
                yield("/ad equiprec")
                yield("/wait 2")
                return true
            else
                yield("/echo [UpdateAllGear] Switch failed, retrying...")
                yield("/wait 1")
            end
        end
    end
end

-- Main Logic
yield("/echo [UpdateAllGear] === Updating All Crafter/Gatherer Gear ===")

-- Check player availability
if not Player.Available then
    yield("/echo [UpdateAllGear] ERROR: Player not available")
    return
end

-- Save original job to return to it later
local lp = Svc.ClientState.LocalPlayer
if not lp then
    yield("/echo [UpdateAllGear] ERROR: LocalPlayer not available")
    return
end

local originalJobId = lp.ClassJob.RowId
yield("/echo [UpdateAllGear] Starting job: " .. originalJobId)

-- Process all Crafters
yield("/echo [UpdateAllGear] --- Processing Crafters ---")
local craftersUpdated = 0
for _, job in ipairs(CrafterJobs) do
    if UpdateJobGear(job) then
        craftersUpdated = craftersUpdated + 1
    end
end

-- Process all Gatherers
yield("/echo [UpdateAllGear] --- Processing Gatherers ---")
local gatherersUpdated = 0
for _, job in ipairs(GathererJobs) do
    if UpdateJobGear(job) then
        gatherersUpdated = gatherersUpdated + 1
    end
end

-- Return to original job
yield("/echo [UpdateAllGear] --- Returning to original job ---")
local originalSlot, originalName = FindGearsetSlot(originalJobId)
if originalSlot then
    yield("/gearset change " .. originalSlot)
    yield("/wait 1")
    yield("/echo [UpdateAllGear] Returned to " .. (originalName or "original job"))
else
    yield("/echo [UpdateAllGear] Could not find original gearset, staying on current job")
end

yield("/echo [UpdateAllGear] === Complete ===")
yield("/echo [UpdateAllGear] Updated: " .. craftersUpdated .. " Crafters, " .. gatherersUpdated .. " Gatherers")
