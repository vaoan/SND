--[=====[
[[SND Metadata]]
author: 'Heiner'
version: 2.6.0
description: Auto-leveling for Cosmic Exploration - switches jobs at breakpoints, auto-switches categories, persists completed characters
plugin_dependencies:
- AutoDuty
- ICE
configs:
  Debug:
    description: Show detailed debug information (true/false)
    default: true
  UseIce:
    description: Start/stop Ice plugin when switching jobs (true/false)
    default: true
  CatchupMode:
    description: true = always check all jobs for compliance. false = only check at exact breakpoints
    default: true
  Breakpoints:
    description: Comma-separated breakpoint levels (e.g., "63,71,81,91"). Level 50 is ALWAYS included because the quest "Inscrutable Tastes" unlocks at 50 and must be completed or leveling will be blocked.
    default: "63,71,81,91"
  MaxLevel:
    description: Target level cap for all jobs (default 100)
    default: 100
    min: 50
    max: 100
  CompletedCharacters:
    description: Comma-separated list of completed characters (Name@Server format). Auto-populated when a character finishes all jobs.
    default: ""
  AlwaysUpdateGear:
    description: Always update gear on every run, not just when switching jobs or at breakpoints (true/false)
    default: false
[[End Metadata]]
--]=====]

--[[
================================================================================
                        COSMIC EXPLORATION AUTO-LEVELING
                                  Version 2.6.0
================================================================================

This script automates job leveling rotation for Cosmic Exploration (Ice plugin).
It ensures all Crafter (DoH) and Gatherer (DoL) jobs are leveled evenly by
switching jobs at configurable breakpoints.

HOW IT WORKS:
-------------
1. On start, checks if current character is already marked as "completed"
   (all jobs at MaxLevel). If so, skips entirely and exits (does nothing).

2. Stops Ice, then checks all jobs in current category (Crafter or Gatherer)
   against breakpoints.

3. Two modes available:
   - CATCH-UP MODE (default): Always checks if any job is behind any breakpoint
     that the current job has passed. Switches to the lowest level job that
     needs to catch up.
   - STRICT MODE: Only checks when you hit an exact breakpoint level.
     Switches to jobs that haven't reached that specific breakpoint yet.

4. When switching jobs:
   - Stops Ice (multiple times to ensure it registers)
   - Waits for any ongoing craft or duty (Mech Ops, etc.) to complete
   - Switches gearset and equips recommended gear
   - Restarts Ice

5. When all jobs are compliant (at breakpoint level):
   - Stays on current job
   - Updates equipment via /ad equiprec (to keep gear current as you level)
   - Restarts Ice to continue leveling

6. When all jobs in current category reach MaxLevel, automatically switches to
   the other category (Crafter <-> Gatherer) and continues the process.

7. When ALL jobs (both categories) reach MaxLevel:
   - Marks the character as "completed" in config (persisted)
   - Stops Ice
   - Future runs will skip entirely (no Ice start/stop, just exits)

BREAKPOINTS:
------------
Configure via the "Breakpoints" setting as a comma-separated list.
Default: "63,71,81,91"

IMPORTANT: Level 50 is ALWAYS included automatically and cannot be removed.
At level 50, the quest "INSCRUTABLE TASTES" becomes available. This quest must
be completed or leveling will be blocked when all jobs reach 50.
The script displays a warning when switching to a job that needs to reach 50.

MAX LEVEL:
----------
Configure the target level cap via "MaxLevel" setting (default: 100).
Set to a lower value (e.g., 90) if you want to stop leveling earlier.

EQUIPMENT UPDATES:
------------------
Equipment is automatically updated (/ad equiprec) in two scenarios:
1. When switching to a different job
2. When all jobs are compliant at a breakpoint (staying on current job)

This ensures gear stays current as you level without updating on every run.

If you want equipment to update on EVERY run (regardless of job switch or
breakpoint status), enable the "AlwaysUpdateGear" option.

EXAMPLE FLOW (Catch-up Mode):
-----------------------------
- You're on CRP Lv.63, but BSM is Lv.45
- Script detects BSM is behind the 50 breakpoint
- Waits for current craft to finish
- Switches to BSM, equips recommended gear, starts Ice
- Next run: BSM is now 52, all crafters at 50+, updates equipment, continues

COMPLETED CHARACTERS:
---------------------
When a character finishes all jobs, they're saved to CompletedCharacters config
as "CharacterName@ServerName". On future runs, the script recognizes them and
skips entirely (does nothing).

JOB SWITCHING:
--------------
The script handles various blocking conditions:
- Waits for crafting to complete before switching
- Waits for duties (Mech Ops, etc.) to complete
- Retries up to 60 times if switch fails
- Uses correct gearset slot (API index + 1 for UI slot)

REQUIREMENTS:
-------------
- ICE plugin (for Cosmic Exploration automation)
- AutoDuty plugin (for /ad equiprec - equip recommended gear)
- Gearsets configured for all DoH/DoL jobs

================================================================================
]]

-- Job Categories
-- Crafters (DoH - Disciples of Hand): IDs 8-15
-- Gatherers (DoL - Disciples of Land): IDs 16-18

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

-- Get config
local DEBUG = Config.Get("Debug") == "true" or Config.Get("Debug") == true
local USE_ICE = Config.Get("UseIce") == "true" or Config.Get("UseIce") == true
local CATCHUP_MODE = Config.Get("CatchupMode") == "true" or Config.Get("CatchupMode") == true
local COMPLETED_CHARACTERS = Config.Get("CompletedCharacters") or ""
local ALWAYS_UPDATE_GEAR = Config.Get("AlwaysUpdateGear") == "true" or Config.Get("AlwaysUpdateGear") == true

-- Helper: Get current character identifier (Name@Server)
local function GetCharacterKey()
    local lp = Svc.ClientState.LocalPlayer
    if not lp then return nil end

    local name = lp.Name:ToString()
    local world = lp.HomeWorld.Value.Name:ToString()
    return name .. "@" .. world
end

-- Helper: Check if current character is marked as completed
local function IsCharacterCompleted(charKey)
    if COMPLETED_CHARACTERS == "" then return false end
    for completed in string.gmatch(COMPLETED_CHARACTERS, "([^,]+)") do
        -- Trim whitespace
        completed = completed:match("^%s*(.-)%s*$")
        if completed == charKey then
            return true
        end
    end
    return false
end

-- Helper: Mark current character as completed
local function MarkCharacterCompleted(charKey)
    if IsCharacterCompleted(charKey) then return end -- Already marked

    local newValue
    if COMPLETED_CHARACTERS == "" then
        newValue = charKey
    else
        newValue = COMPLETED_CHARACTERS .. "," .. charKey
    end

    Config.Set("CompletedCharacters", newValue)
    yield("/echo [CosmicLeveling] Character " .. charKey .. " marked as COMPLETED")
end

-- Debug helper
local function DebugLog(msg)
    if DEBUG then
        yield("/echo [CosmicLeveling] [DEBUG] " .. msg)
    end
end

-- Character conditions we need
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

-- Check if currently crafting
local function IsCrafting()
    return Svc.Condition[CharacterCondition.crafting] or
           Svc.Condition[CharacterCondition.executingCraftingSkill]
end

-- Check if in a duty/event that blocks job switching (like Mech Ops)
local function IsBoundByDutyOrEvent()
    return Svc.Condition[CharacterCondition.occupied] or
           Svc.Condition[CharacterCondition.occupiedInEvent] or
           Svc.Condition[CharacterCondition.occupiedInQuestEvent] or
           Svc.Condition[CharacterCondition.boundByDuty34] or
           Svc.Condition[CharacterCondition.boundByDuty56] or
           Svc.Condition[CharacterCondition.boundByDuty95]
end

-- Check if anything is blocking job switch
local function IsBlockedFromSwitching()
    return IsCrafting() or IsBoundByDutyOrEvent()
end

-- Wait for blocking conditions to clear (with timeout)
local function WaitUntilCanSwitch(maxWaitSeconds)
    maxWaitSeconds = maxWaitSeconds or 120
    local startTime = os.clock()

    while IsBlockedFromSwitching() do
        if os.clock() - startTime > maxWaitSeconds then
            yield("/echo [CosmicLeveling] WARNING: Timeout waiting to be able to switch jobs")
            return false
        end
        yield("/wait 1")
    end
    return true
end

-- Ice control helpers (respects USE_ICE flag)
local function StartIce()
    if USE_ICE then
        yield("/echo [CosmicLeveling] Starting Ice...")
        yield("/ice start")
    end
end

-- Aggressively stop Ice and wait for it to actually stop
local function StopIce()
    if USE_ICE then
        yield("/echo [CosmicLeveling] Stopping Ice...")
        -- Issue stop command multiple times to ensure it registers
        yield("/ice stop")
        yield("/wait 0.5")
        yield("/ice stop")
        yield("/wait 0.5")
        yield("/ice stop")
        yield("/wait 0.5")
    end
end

-- Get max level from config
local MAX_LEVEL = tonumber(Config.Get("MaxLevel")) or 100

-- Special handler for level 50 breakpoint
-- Called when a job reaches level 50 - warns user to do the collectable quest
-- This is NOT blocking - the script will continue, but the user should manually
-- stop and complete the quest soon or leveling will get stuck.
-- NOTE: We can't reliably check if the quest is already done (Questionable IPC
-- only tracks its internal state, not the game's actual quest completion).
local function OnLevel50Reached(jobAbbr, jobName)
    yield("/echo [CosmicLeveling] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    yield("/echo [CosmicLeveling] WARNING: " .. jobName .. " (" .. jobAbbr .. ") has reached level 50!")
    yield("/echo [CosmicLeveling] Please complete the quest: INSCRUTABLE TASTES")
    yield("/echo [CosmicLeveling] Leveling will get STUCK if you don't do this quest!")
    yield("/echo [CosmicLeveling] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
end

-- Parse breakpoints from comma-separated string
local function ParseBreakpoints(str)
    local breakpoints = {}
    local hasLevel50 = false

    for num in string.gmatch(str, "([^,]+)") do
        local level = tonumber(num:match("^%s*(.-)%s*$"))  -- Trim whitespace
        if level and level >= 1 and level <= MAX_LEVEL then
            table.insert(breakpoints, level)
            if level == 50 then hasLevel50 = true end
        end
    end

    -- Ensure level 50 is always present (required for job quest)
    if not hasLevel50 then
        table.insert(breakpoints, 50)
    end

    table.sort(breakpoints)
    return breakpoints
end

-- Get breakpoints from config (sorted ascending, level 50 always included)
local breakpointsStr = Config.Get("Breakpoints") or "63,71,81,91"
local BREAKPOINTS = ParseBreakpoints(breakpointsStr)

-- Helper: Check if job ID is a crafter
local function IsCrafter(jobId)
    return jobId >= 8 and jobId <= 15
end

-- Helper: Check if job ID is a gatherer
local function IsGatherer(jobId)
    return jobId >= 16 and jobId <= 18
end

-- Helper: Get job category name
local function GetJobCategory(jobId)
    if IsCrafter(jobId) then return "Crafter"
    elseif IsGatherer(jobId) then return "Gatherer"
    else return "Other"
    end
end

-- Helper: Get the breakpoint a level has reached (highest breakpoint <= level)
local function GetReachedBreakpoint(level)
    local reached = nil
    for _, bp in ipairs(BREAKPOINTS) do
        if level >= bp then
            reached = bp
        end
    end
    return reached
end

-- Helper: Get the next breakpoint target for a level
local function GetNextBreakpoint(level)
    for _, bp in ipairs(BREAKPOINTS) do
        if level < bp then
            return bp
        end
    end
    return MAX_LEVEL  -- Max level if past all breakpoints
end

-- Helper: Check if level is exactly at a breakpoint
local function IsAtExactBreakpoint(level)
    for _, bp in ipairs(BREAKPOINTS) do
        if level == bp then
            return true, bp
        end
    end
    return false, nil
end

-- Helper: Find a job that's behind based on current character's progress
-- Returns the job with lowest level that hasn't reached the breakpoint it should have
local function FindJobBehindBreakpoint(jobList, referenceLevel)
    local referenceBP = GetReachedBreakpoint(referenceLevel)
    DebugLog("Reference level: " .. referenceLevel .. " | Reached breakpoint: " .. tostring(referenceBP))

    if not referenceBP then
        DebugLog("No breakpoint reached yet")
        return nil, nil  -- Reference level hasn't reached any breakpoint
    end

    local behindJob = nil
    local behindLevel = referenceBP
    local targetBP = nil

    for _, job in ipairs(jobList) do
        local jobData = Player.GetJob(job.id)
        if jobData and jobData.Level then
            local level = jobData.Level
            DebugLog(job.abbr .. " is Lv." .. level)
            -- Check if this job is behind any breakpoint that the reference has passed
            for _, bp in ipairs(BREAKPOINTS) do
                if referenceLevel >= bp and level < bp then
                    -- This job hasn't reached a breakpoint that reference has passed
                    DebugLog(job.abbr .. " is BEHIND breakpoint " .. bp .. " (current: " .. level .. ")")
                    if level < behindLevel or (behindJob == nil) then
                        behindLevel = level
                        behindJob = job
                        behindJob.level = level
                        targetBP = bp
                    end
                    break  -- Found the first breakpoint this job is behind on
                end
            end
        end
    end

    return behindJob, targetBP
end

-- Helper: Check if all jobs in a list are at max level
local function AllJobsAtMax(jobList)
    for _, job in ipairs(jobList) do
        local jobData = Player.GetJob(job.id)
        if jobData and jobData.Level then
            if jobData.Level < MAX_LEVEL then
                return false
            end
        end
    end
    return true
end

-- Helper: Find the lowest level job in a list (for switching categories)
local function FindLowestLevelJob(jobList)
    local lowestJob = nil
    local lowestLevel = 101

    for _, job in ipairs(jobList) do
        local jobData = Player.GetJob(job.id)
        if jobData and jobData.Level then
            local level = jobData.Level
            if level < lowestLevel then
                lowestLevel = level
                lowestJob = job
                lowestJob.level = level
            end
        end
    end

    return lowestJob
end

-- Helper: Find lowest level job below a specific breakpoint
local function FindLowestJobBelowBreakpoint(jobList, breakpoint)
    local lowestJob = nil
    local lowestLevel = breakpoint

    for _, job in ipairs(jobList) do
        local jobData = Player.GetJob(job.id)
        if jobData and jobData.Level then
            local level = jobData.Level
            if level > 0 and level < lowestLevel then
                lowestLevel = level
                lowestJob = job
                lowestJob.level = level
            end
        end
    end

    return lowestJob
end

-- Helper: Switch to a job using gearset and equip recommended gear
-- restartIce: if false, Ice will NOT be restarted after switching (default: true)
local function SwitchToJob(jobId, restartIce)
    if restartIce == nil then restartIce = true end

    -- Debug: show all gearsets to understand the mapping
    if DEBUG then
        DebugLog("=== Scanning all gearsets ===")
        for i = 1, 20 do
            local g = Player.GetGearset(i)
            if g and g.ClassJob and g.ClassJob > 0 then
                DebugLog("Slot " .. i .. ": " .. (g.Name or "?") .. " | ClassJob: " .. g.ClassJob)
            end
        end
        DebugLog("=== Looking for JobId: " .. jobId .. " ===")
    end

    for idx = 1, 100 do
        local gs = Player.GetGearset(idx)
        if gs and gs.ClassJob == jobId then
            -- Stop Ice before switching
            StopIce()
            yield("/wait 1")

            -- IMPORTANT: The /gearset change command uses 1-based UI slot numbers
            -- Player.GetGearset() index is 0-based internally, so UI slot = idx + 1
            local uiSlot = idx + 1
            DebugLog("Found gearset at API index: " .. idx .. " | UI Slot: " .. uiSlot .. " | Name: " .. (gs.Name or "?") .. " | ClassJob: " .. gs.ClassJob)
            yield("/echo [CosmicLeveling] Switching to gearset: " .. (gs.Name or "?") .. " (slot " .. uiSlot .. ")")

            -- Keep trying until we successfully switch to the correct job
            local maxAttempts = 60  -- Max 60 attempts (about 2-3 minutes with waits)
            local attempt = 0

            while attempt < maxAttempts do
                attempt = attempt + 1

                -- Wait if blocked by crafting, duty, or event (like Mech Ops)
                if IsBlockedFromSwitching() then
                    if IsCrafting() then
                        yield("/echo [CosmicLeveling] Waiting for craft to finish... (attempt " .. attempt .. ")")
                    elseif IsBoundByDutyOrEvent() then
                        yield("/echo [CosmicLeveling] Waiting for duty/event to finish... (attempt " .. attempt .. ")")
                    end
                    WaitUntilCanSwitch(120)
                    yield("/wait 1")
                end

                -- Close any open windows that might block gearset change
                yield("/callback SelectYesno true -1")
                yield("/callback StellarMissionContent true -1")
                yield("/wait 0.3")

                -- Try to switch gearset (use uiSlot, not idx!)
                yield("/gearset change " .. uiSlot)
                yield("/wait 1")

                -- Check if switch worked
                local lp = Svc.ClientState.LocalPlayer
                if lp then
                    local currentJobId = lp.ClassJob.RowId
                    if currentJobId == jobId then
                        yield("/echo [CosmicLeveling] Job switch successful!")
                        break  -- Success!
                    else
                        DebugLog("Switch attempt " .. attempt .. " failed. Current: " .. currentJobId .. " Expected: " .. jobId)
                        yield("/wait 2")  -- Wait before retry
                    end
                end
            end

            -- Final verification
            local lp = Svc.ClientState.LocalPlayer
            if lp and lp.ClassJob.RowId ~= jobId then
                yield("/echo [CosmicLeveling] ERROR: Failed to switch job after " .. maxAttempts .. " attempts!")
                return false
            end

            -- Equip recommended gear using AutoDuty
            yield("/echo [CosmicLeveling] Equipping recommended gear...")
            yield("/ad equiprec")
            yield("/wait 2")

            -- Restart Ice if requested
            if restartIce then
                StartIce()
            end

            return true
        end
    end
    return false
end

-- Helper: Process a category and return status
-- Returns: "switched" if switched to a job, "complete" if all at 100, "continue" if should keep leveling
local function ProcessCategory(jobList, categoryName, currentLevel)
    -- First check if all jobs in this category are at 100
    if AllJobsAtMax(jobList) then
        yield("/echo [CosmicLeveling] All " .. categoryName .. "s are at level " .. MAX_LEVEL .. "!")
        return "complete"
    end

    -- MODE: STRICT - Only check when hitting exact breakpoint
    if not CATCHUP_MODE then
        local isAtBP, exactBP = IsAtExactBreakpoint(currentLevel)

        if not isAtBP then
            local nextBP = GetNextBreakpoint(currentLevel)
            yield("/echo [CosmicLeveling] [Strict] Not at a breakpoint. Continue leveling to " .. nextBP .. "!")
            return "continue"
        end

        yield("/echo [CosmicLeveling] [Strict] Hit breakpoint " .. exactBP .. "! Checking other " .. categoryName .. " jobs...")

        local nextJob = FindLowestJobBelowBreakpoint(jobList, exactBP)

        if nextJob then
            yield("/echo [CosmicLeveling] Found: " .. nextJob.abbr .. " at Lv." .. nextJob.level .. " (needs to reach " .. exactBP .. ")")
            if SwitchToJob(nextJob.id) then
                yield("/echo [CosmicLeveling] Switched to " .. nextJob.abbr .. "! Level to " .. exactBP)
                -- Warn user if leveling to 50 (collectable quest required)
                if exactBP == 50 then
                    OnLevel50Reached(nextJob.abbr, nextJob.name)
                end
                return "switched"
            else
                yield("/echo [CosmicLeveling] ERROR: No gearset found for " .. nextJob.abbr)
                return "continue"
            end
        else
            local nextBP = GetNextBreakpoint(currentLevel)
            yield("/echo [CosmicLeveling] All " .. categoryName .. "s at " .. exactBP .. "+! Continue to next breakpoint: " .. nextBP)
            return "compliant"  -- All jobs at breakpoint, trigger equipment update
        end

    -- MODE: CATCH-UP - Always check all jobs for compliance
    else
        yield("/echo [CosmicLeveling] [Catch-up] Checking all " .. categoryName .. " jobs for breakpoint compliance...")

        local behindJob, targetBP = FindJobBehindBreakpoint(jobList, currentLevel)

        if behindJob then
            yield("/echo [CosmicLeveling] Found: " .. behindJob.abbr .. " at Lv." .. behindJob.level .. " (behind breakpoint " .. targetBP .. ")")
            if SwitchToJob(behindJob.id) then
                yield("/echo [CosmicLeveling] Switched to " .. behindJob.abbr .. "! Level to " .. targetBP)
                -- Warn user if leveling to 50 (collectable quest required)
                if targetBP == 50 then
                    OnLevel50Reached(behindJob.abbr, behindJob.name)
                end
                return "switched"
            else
                yield("/echo [CosmicLeveling] ERROR: No gearset found for " .. behindJob.abbr)
                return "continue"
            end
        else
            local nextBP = GetNextBreakpoint(currentLevel)
            yield("/echo [CosmicLeveling] All " .. categoryName .. "s compliant with current progress!")
            yield("/echo [CosmicLeveling] Continue leveling to next breakpoint: " .. nextBP)
            return "compliant"  -- All jobs compliant, trigger equipment update
        end
    end
end

-- Main Logic
yield("/echo [CosmicLeveling] === Cosmic Exploration Auto-Leveling ===")

-- Check player availability
if not Player.Available then
    yield("/echo [CosmicLeveling] ERROR: Player not available")
    return
end

-- Get current job info
local lp = Svc.ClientState.LocalPlayer
if not lp then
    yield("/echo [CosmicLeveling] ERROR: LocalPlayer not available")
    return
end

-- Check if character is already marked as completed BEFORE stopping Ice
local charKey = GetCharacterKey()
DebugLog("Character key: " .. tostring(charKey))
if charKey and IsCharacterCompleted(charKey) then
    yield("/echo [CosmicLeveling] Character " .. charKey .. " already completed all jobs!")
    yield("/echo [CosmicLeveling] Skipping - nothing to do.")
    yield("/echo [CosmicLeveling] === Done ===")
    return
end

-- IMMEDIATELY stop Ice before job checks - this is critical!
-- Ice must be stopped so we can properly evaluate and switch jobs
-- (Only reached if character is NOT completed)
if USE_ICE then
    yield("/ice stop")
    yield("/wait 0.1")
end

yield("/echo [CosmicLeveling] Mode: " .. (CATCHUP_MODE and "Catch-up" or "Strict"))
yield("/echo [CosmicLeveling] Breakpoints: " .. table.concat(BREAKPOINTS, ", ") .. " | Max: " .. MAX_LEVEL)

local currentJobId = lp.ClassJob.RowId
local currentLevel = lp.Level
local currentCategory = GetJobCategory(currentJobId)

yield("/echo [CosmicLeveling] Current: " .. currentCategory .. " | Level: " .. currentLevel)

-- Check if we're on a crafter or gatherer
if currentCategory == "Other" then
    yield("/echo [CosmicLeveling] Not on a crafting or gathering job. Please switch to a DoH/DoL job.")
    return
end

local jobList = IsCrafter(currentJobId) and CrafterJobs or GathererJobs
local otherJobList = IsCrafter(currentJobId) and GathererJobs or CrafterJobs
local otherCategoryName = IsCrafter(currentJobId) and "Gatherer" or "Crafter"

-- Process current category
local result = ProcessCategory(jobList, currentCategory, currentLevel)

-- If result is "continue", we stay on current job
if result == "continue" then
    -- Update gear if AlwaysUpdateGear is enabled
    if ALWAYS_UPDATE_GEAR then
        yield("/echo [CosmicLeveling] Updating equipment (AlwaysUpdateGear enabled)...")
        yield("/ad equiprec")
        yield("/wait 2")
    end
    StartIce()
end

-- If result is "compliant", all jobs at breakpoint - update equipment and continue
if result == "compliant" then
    yield("/echo [CosmicLeveling] All jobs compliant - updating equipment...")
    yield("/ad equiprec")
    yield("/wait 2")
    StartIce()
end

-- If current category is complete (all at 100), check the other category
if result == "complete" then
    yield("/echo [CosmicLeveling] Checking " .. otherCategoryName .. " category...")

    -- Check if other category is also complete
    if AllJobsAtMax(otherJobList) then
        yield("/echo [CosmicLeveling] *** ALL JOBS COMPLETE! ***")
        yield("/echo [CosmicLeveling] Both Crafters and Gatherers are at level " .. MAX_LEVEL .. "!")
        MarkCharacterCompleted(charKey)
        StopIce()
        yield("/echo [CosmicLeveling] === Done ===")
        return
    end

    -- Find a job in the other category to switch to
    local otherJob = FindLowestLevelJob(otherJobList)
    if otherJob then
        yield("/echo [CosmicLeveling] Switching to " .. otherCategoryName .. ": " .. otherJob.abbr .. " at Lv." .. otherJob.level)
        -- Switch but don't restart Ice yet - we need to run the check again
        if SwitchToJob(otherJob.id, false) then
            yield("/echo [CosmicLeveling] Switched to " .. otherJob.abbr .. "!")

            -- Now process the new category
            yield("/echo [CosmicLeveling] Processing " .. otherCategoryName .. " category...")

            -- Get fresh level after switch
            lp = Svc.ClientState.LocalPlayer
            local newLevel = lp.Level

            local otherResult = ProcessCategory(otherJobList, otherCategoryName, newLevel)

            if otherResult == "complete" then
                -- This means BOTH categories are complete (we already checked current was complete)
                yield("/echo [CosmicLeveling] *** ALL JOBS COMPLETE! ***")
                yield("/echo [CosmicLeveling] Both Crafters and Gatherers are at level " .. MAX_LEVEL .. "!")
                MarkCharacterCompleted(charKey)
                -- Ice already stopped from SwitchToJob, keep it stopped
            else
                -- Other category needs work, start Ice
                StartIce()
            end
        else
            yield("/echo [CosmicLeveling] ERROR: No gearset found for " .. otherJob.abbr)
        end
    end
end

yield("/echo [CosmicLeveling] === Done ===")
