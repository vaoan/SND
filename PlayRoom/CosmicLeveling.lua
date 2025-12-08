--[=====[
[[SND Metadata]]
author: 'Heiner'
version: 1.8.0
description: Auto-leveling for Cosmic Exploration - switches jobs at configurable breakpoints
plugin_dependencies:
- AutoDuty
- Ice
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
  Breakpoint1:
    description: First breakpoint level
    default: 50
    min: 1
    max: 100
  Breakpoint2:
    description: Second breakpoint level
    default: 63
    min: 1
    max: 100
  Breakpoint3:
    description: Third breakpoint level
    default: 71
    min: 1
    max: 100
  Breakpoint4:
    description: Fourth breakpoint level
    default: 81
    min: 1
    max: 100
  Breakpoint5:
    description: Fifth breakpoint level
    default: 91
    min: 1
    max: 100
[[End Metadata]]
--]=====]

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

-- Debug helper
local function DebugLog(msg)
    if DEBUG then
        yield("/echo [CosmicLeveling] [DEBUG] " .. msg)
    end
end

-- Get breakpoints from config (sorted ascending)
local BREAKPOINTS = {
    tonumber(Config.Get("Breakpoint1")) or 50,
    tonumber(Config.Get("Breakpoint2")) or 63,
    tonumber(Config.Get("Breakpoint3")) or 71,
    tonumber(Config.Get("Breakpoint4")) or 81,
    tonumber(Config.Get("Breakpoint5")) or 91,
}
table.sort(BREAKPOINTS)

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
    return 100  -- Max level if past all breakpoints
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
local function SwitchToJob(jobId)
    for idx = 1, 100 do
        local gs = Player.GetGearset(idx)
        if gs and gs.ClassJob == jobId then
            -- Stop Ice before switching (if enabled)
            if USE_ICE then
                yield("/echo [CosmicLeveling] Stopping Ice...")
                yield("/ice stop")
                yield("/wait 1")
            end

            -- Switch gearset
            yield("/echo [CosmicLeveling] Switching to gearset: " .. gs.Name)
            yield("/gearset change " .. idx)
            yield("/wait 1")

            -- Equip recommended gear using AutoDuty
            yield("/echo [CosmicLeveling] Equipping recommended gear...")
            yield("/ad equiprec")
            yield("/wait 2")

            -- Restart Ice (if enabled)
            if USE_ICE then
                yield("/echo [CosmicLeveling] Starting Ice...")
                yield("/ice start")
            end

            return true
        end
    end
    return false
end

-- Main Logic
yield("/echo [CosmicLeveling] === Cosmic Exploration Auto-Leveling ===")
yield("/echo [CosmicLeveling] Mode: " .. (CATCHUP_MODE and "Catch-up" or "Strict"))
yield("/echo [CosmicLeveling] Breakpoints: " .. table.concat(BREAKPOINTS, ", "))

-- Get current job info
local lp = Svc.ClientState.LocalPlayer
if not lp then
    yield("/echo [CosmicLeveling] ERROR: Player not available")
    return
end

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

-- MODE: STRICT - Only check when hitting exact breakpoint
if not CATCHUP_MODE then
    local isAtBP, exactBP = IsAtExactBreakpoint(currentLevel)

    if not isAtBP then
        local nextBP = GetNextBreakpoint(currentLevel)
        yield("/echo [CosmicLeveling] [Strict] Not at a breakpoint. Continue leveling to " .. nextBP .. "!")
        return
    end

    yield("/echo [CosmicLeveling] [Strict] Hit breakpoint " .. exactBP .. "! Checking other " .. currentCategory .. " jobs...")

    local nextJob = FindLowestJobBelowBreakpoint(jobList, exactBP)

    if nextJob then
        yield("/echo [CosmicLeveling] Found: " .. nextJob.abbr .. " at Lv." .. nextJob.level .. " (needs to reach " .. exactBP .. ")")
        if SwitchToJob(nextJob.id) then
            yield("/echo [CosmicLeveling] Switched to " .. nextJob.abbr .. "! Level to " .. exactBP)
        else
            yield("/echo [CosmicLeveling] ERROR: No gearset found for " .. nextJob.abbr)
        end
    else
        local nextBP = GetNextBreakpoint(currentLevel)
        yield("/echo [CosmicLeveling] All " .. currentCategory .. "s at " .. exactBP .. "+! Continue to next breakpoint: " .. nextBP)
    end

-- MODE: CATCH-UP - Always check all jobs for compliance
else
    yield("/echo [CosmicLeveling] [Catch-up] Checking all " .. currentCategory .. " jobs for breakpoint compliance...")

    local behindJob, targetBP = FindJobBehindBreakpoint(jobList, currentLevel)

    if behindJob then
        yield("/echo [CosmicLeveling] Found: " .. behindJob.abbr .. " at Lv." .. behindJob.level .. " (behind breakpoint " .. targetBP .. ")")
        if SwitchToJob(behindJob.id) then
            yield("/echo [CosmicLeveling] Switched to " .. behindJob.abbr .. "! Level to " .. targetBP)
        else
            yield("/echo [CosmicLeveling] ERROR: No gearset found for " .. behindJob.abbr)
        end
    else
        local nextBP = GetNextBreakpoint(currentLevel)
        yield("/echo [CosmicLeveling] All " .. currentCategory .. "s compliant with current progress!")
        yield("/echo [CosmicLeveling] Continue leveling to next breakpoint: " .. nextBP)
    end
end

yield("/echo [CosmicLeveling] === Done ===")
