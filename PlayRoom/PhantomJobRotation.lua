--[=====[
[[SND Metadata]]
author: 'Vaoan'
version: 1.0.0
description: Automates phantom job buff rotation in Occult Crescent
plugin_dependencies:
- SimpleTweaksPlugin
- vnavmesh
configs:
  EnableMovement:
    default: "true"
    description: Enable movement to start/end positions
  StartPosX:
    default: "0"
    description: X coordinate for starting position
  StartPosY:
    default: "0"
    description: Y coordinate for starting position
  StartPosZ:
    default: "0"
    description: Z coordinate for starting position
  EndPosX:
    default: "0"
    description: X coordinate for ending position
  EndPosY:
    default: "0"
    description: Y coordinate for ending position
  EndPosZ:
    default: "0"
    description: Z coordinate for ending position
  PositionTolerance:
    default: "3"
    description: Distance tolerance for position checking (yalms)
  FreelancerActions:
    default: "3"
    description: Comma-separated list of Phantom Action IDs to use with Freelancer (e.g., "3" or "2,3,5")
[[End Metadata]]
--]=====]

--[[
HOW IT WORKS:
1. Checks if player is at starting position (if movement enabled)
2. Checks Phantom Mastery stacks:
   - If 15 stacks: Switch to Freelancer and use configured actions
   - If < 15 stacks: Cycle through PJ list to apply buffs
3. Each PJ has level requirement and specific action to use
4. After rotation, moves to ending position (if movement enabled)

PHANTOM JOB STRUCTURE:
- Name: Display name for SimpleTweaks command
- MinLevel: Minimum PJ level required to use
- Action: Phantom Action ID to use (1-5)

TODO: After running TestPhantomJob.lua, we may need to update:
- How we detect current PJ
- How we get PJ levels
- How we check Phantom Mastery stacks
--]]

-------------------------------------------------
-- CONFIGURATION
-------------------------------------------------

-- Phantom Job rotation list (order matters)
local PhantomJobs = {
    {
        Name = "Bard",
        MinLevel = 2,
        Action = 2  -- Phantom Action II
    },
    {
        Name = "Monk",
        MinLevel = 3,
        Action = 3  -- Phantom Action III
    },
    {
        Name = "Knight",
        MinLevel = 2,
        Action = 2  -- Phantom Action II
    },
    {
        Name = "Dancer",
        MinLevel = 2,
        Action = 2  -- Phantom Action II
    }
}

-- Character Conditions (from snd-core skill)
local CharacterCondition = {
    casting = 27,
    betweenAreas = 45,
    beingMoved = 70,
    inCombat = 26
}

-------------------------------------------------
-- UTILITY FUNCTIONS
-------------------------------------------------

function Log(message)
    yield("/echo [PJ Rotation] " .. message)
end

function LogError(message)
    yield("/echo [PJ Rotation] ERROR: " .. message)
end

-- Check if plugin is available
function HasPlugin(pluginName)
    for plugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        if plugin.InternalName == pluginName and plugin.IsLoaded then
            return true
        end
    end
    return false
end

-- Check if character is busy
function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Svc.Condition[CharacterCondition.beingMoved] or
           (Player and Player.IsBusy)
end

-- Check if in combat
function IsInCombat()
    return Svc.Condition[CharacterCondition.inCombat]
end

-- Get distance to coordinates
function GetDistanceTo(x, y, z)
    local player = Svc.ClientState.LocalPlayer
    if not player then return 999999 end

    local dx = player.Position.X - x
    local dy = player.Position.Y - y
    local dz = player.Position.Z - z

    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Check if near position
function IsNearPosition(x, y, z, tolerance)
    return GetDistanceTo(x, y, z) <= tolerance
end

-- Wait with timeout
function WaitUntil(condition, timeout, checkInterval)
    timeout = timeout or 30
    checkInterval = checkInterval or 0.5
    local startTime = os.clock()

    while not condition() and (os.clock() - startTime) < timeout do
        if not IsCharacterBusy() then
            -- Only check when not busy
            if condition() then
                return true
            end
        end
        yield(string.format("/wait %.1f", checkInterval))
    end

    return condition()
end

-------------------------------------------------
-- NAVIGATION FUNCTIONS
-------------------------------------------------

function IsVnavReady()
    if not HasPlugin("vnavmesh") then
        return false
    end

    local ok, result = pcall(function()
        return IPC.vnavmesh.IsReady()
    end)

    return ok and result
end

function IsVnavRunning()
    if not HasPlugin("vnavmesh") then
        return false
    end

    local ok, result = pcall(function()
        return IPC.vnavmesh.IsRunning()
    end)

    return ok and result
end

function StopVnav()
    if not HasPlugin("vnavmesh") then
        return
    end

    pcall(function()
        IPC.vnavmesh.Stop()
    end)
end

function MoveTo(x, y, z, fly)
    fly = fly or false

    if not IsVnavReady() then
        LogError("vnavmesh not ready")
        return false
    end

    local success, result = pcall(function()
        IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), fly)
    end)

    return success
end

function MoveToPosition(x, y, z, tolerance, timeout)
    tolerance = tolerance or 3
    timeout = timeout or 60

    if IsNearPosition(x, y, z, tolerance) then
        Log("Already at position")
        return true
    end

    Log(string.format("Moving to (%.1f, %.1f, %.1f)...", x, y, z))

    if not MoveTo(x, y, z, false) then
        LogError("Failed to start movement")
        return false
    end

    local startTime = os.clock()
    while IsVnavRunning() and (os.clock() - startTime) < timeout do
        local dist = GetDistanceTo(x, y, z)

        if dist < tolerance then
            StopVnav()
            Log("Arrived at position")
            return true
        end

        yield("/wait 0.5")
    end

    -- Check if we made it even if vnav stopped
    if IsNearPosition(x, y, z, tolerance) then
        Log("Arrived at position")
        return true
    end

    LogError("Movement timed out or failed")
    return false
end

-------------------------------------------------
-- PHANTOM JOB FUNCTIONS
-------------------------------------------------

-- Get Phantom Mastery stack count
function GetPhantomMasteryStacks()
    local player = Svc.ClientState.LocalPlayer
    if not player then return 0 end

    -- Search for Phantom Mastery status effect
    -- Note: This may need adjustment based on actual status ID
    for i = 0, 29 do
        local status = player.StatusList[i]
        if status and status.StatusId ~= 0 then
            -- Try to get status name from game data
            local statusSheet = Svc.Data:GetExcelSheet("Status")
            if statusSheet then
                local statusData = statusSheet:GetRow(status.StatusId)
                if statusData and statusData.Name and statusData.Name:ToString():lower():find("phantom mastery") then
                    return status.StackCount
                end
            end
        end
    end

    return 0
end

-- Switch phantom job using SimpleTweaksPlugin
function SwitchPhantomJob(jobName)
    if not HasPlugin("SimpleTweaksPlugin") then
        LogError("SimpleTweaksPlugin not available")
        return false
    end

    Log(string.format("Switching to PJ: %s", jobName))
    yield(string.format("/phantomjob %s", jobName))
    yield("/wait 0.5")  -- Small delay for job switch

    return true
end

-- Get phantom job level
-- TODO: Update this after TestPhantomJob.lua reveals the API
function GetPhantomJobLevel(jobName)
    -- Placeholder: This needs to be implemented based on actual API
    -- For now, return a high level so we always pass the check during testing
    Log(string.format("TODO: Get level for PJ %s (returning 99 for testing)", jobName))
    return 99
end

-- Use Phantom Action
function UsePhantomAction(actionId)
    local actionName = string.format("Phantom Action %s",
        actionId == 1 and "I" or
        actionId == 2 and "II" or
        actionId == 3 and "III" or
        actionId == 4 and "IV" or
        actionId == 5 and "V" or tostring(actionId))

    Log(string.format("Using %s", actionName))
    yield(string.format("/ac \"%s\"", actionName))
    yield("/wait 1")  -- Wait for action to execute

    return true
end

-- Check if action is ready (not on cooldown)
function IsActionReady(actionId)
    -- TODO: Implement proper cooldown checking
    -- For now, assume always ready
    return true
end

-------------------------------------------------
-- MAIN ROTATION LOGIC
-------------------------------------------------

function PerformFreelancerRotation()
    Log("=== Phantom Mastery at 15 stacks! ===")

    if not SwitchPhantomJob("Freelancer") then
        return false
    end

    -- Get configured Freelancer actions (comma-separated)
    local actionsStr = Config.Get("FreelancerActions")
    local actions = {}

    for actionId in string.gmatch(actionsStr, "([^,]+)") do
        local id = tonumber(actionId)
        if id then
            table.insert(actions, id)
        end
    end

    -- Use each configured action
    for _, actionId in ipairs(actions) do
        if not IsActionReady(actionId) then
            Log(string.format("Waiting for Phantom Action %d to be ready...", actionId))
            -- TODO: Add proper cooldown wait
        end

        UsePhantomAction(actionId)
    end

    return true
end

function PerformBuffRotation()
    Log("=== Starting Buff Rotation ===")

    for i, pj in ipairs(PhantomJobs) do
        Log(string.format("[%d/%d] Checking PJ: %s", i, #PhantomJobs, pj.Name))

        -- Check level requirement
        local currentLevel = GetPhantomJobLevel(pj.Name)
        if currentLevel < pj.MinLevel then
            Log(string.format("  Skipped: Level %d < %d required", currentLevel, pj.MinLevel))
            goto continue
        end

        Log(string.format("  Level %d >= %d required - proceeding", currentLevel, pj.MinLevel))

        -- Switch to PJ
        if not SwitchPhantomJob(pj.Name) then
            LogError(string.format("  Failed to switch to %s", pj.Name))
            goto continue
        end

        -- Wait for not busy
        yield("/wait 0.5")

        -- Use action
        if not IsActionReady(pj.Action) then
            Log("  Waiting for action to be ready...")
            -- TODO: Add proper cooldown wait
        end

        UsePhantomAction(pj.Action)

        ::continue::
    end

    Log("=== Buff Rotation Complete ===")
    return true
end

function MainRotation()
    -- Check for required plugins
    if not HasPlugin("SimpleTweaksPlugin") then
        LogError("SimpleTweaksPlugin plugin not found")
        LogError("Please install SimpleTweaksPlugin and enable 'Phantom Job Command'")
        return false
    end

    local enableMovement = Config.Get("EnableMovement") == "true"

    -- Check if in combat
    if IsInCombat() then
        LogError("Cannot run while in combat")
        return false
    end

    -- Step 1: Move to starting position (if enabled)
    if enableMovement then
        if not HasPlugin("vnavmesh") then
            LogError("vnavmesh plugin not found (required for movement)")
            return false
        end

        local startX = tonumber(Config.Get("StartPosX"))
        local startY = tonumber(Config.Get("StartPosY"))
        local startZ = tonumber(Config.Get("StartPosZ"))
        local tolerance = tonumber(Config.Get("PositionTolerance"))

        if not MoveToPosition(startX, startY, startZ, tolerance, 60) then
            LogError("Failed to reach starting position")
            return false
        end
    end

    -- Step 2: Check Phantom Mastery stacks
    local masteryStacks = GetPhantomMasteryStacks()
    Log(string.format("Phantom Mastery: %d/15 stacks", masteryStacks))

    if masteryStacks >= 15 then
        -- Use Freelancer rotation
        PerformFreelancerRotation()
    else
        -- Use buff rotation
        PerformBuffRotation()
    end

    -- Step 3: Move to ending position (if enabled)
    if enableMovement then
        local endX = tonumber(Config.Get("EndPosX"))
        local endY = tonumber(Config.Get("EndPosY"))
        local endZ = tonumber(Config.Get("EndPosZ"))
        local tolerance = tonumber(Config.Get("PositionTolerance"))

        if not MoveToPosition(endX, endY, endZ, tolerance, 60) then
            LogError("Failed to reach ending position")
            return false
        end
    end

    Log("=== Phantom Job Rotation Complete ===")
    return true
end

-------------------------------------------------
-- SCRIPT EXECUTION
-------------------------------------------------

-- Check player availability
if not Svc.ClientState.LocalPlayer then
    LogError("Player not available")
    return
end

Log("Starting Phantom Job Rotation Script v1.0.0")
Log("Dependencies: SimpleTweaksPlugin, vnavmesh")

-- Run main rotation with error handling
local success, err = pcall(function()
    MainRotation()
end)

if not success then
    LogError("Script error: " .. tostring(err))
else
    Log("Script finished successfully")
end
