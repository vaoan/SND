--[=====[
[[SND Metadata]]
author: 'Developer'
version: 1.0.0
description: Teleportation and navigation script with flight detection and walking fallback
plugin_dependencies:
- Lifestream
- vnavmesh
configs:
  TargetMapId:
    default: 144
    description: Map ID to teleport to
  TargetX:
    default: 100.0
    description: X coordinate of target location
  TargetY:
    default: 0.0
    description: Y coordinate of target location
  TargetZ:
    default: 100.0
    description: Z coordinate of target location
  FlightTimeout:
    default: 30
    description: Timeout in seconds for flight navigation
  WalkingTimeout:
    default: 60
    description: Timeout in seconds for walking navigation
  MaxRetries:
    default: 3
    description: Maximum number of retry attempts
[[End Metadata]]
--]=====]

-- Character condition constants
local CharacterCondition = {
    casting = 27,
    betweenAreas = 45,
    beingMoved = 70,
    occupiedInQuestEvent = 32,
    occupiedMateriaExtractionAndRepair = 39,
    occupiedSummoningBell = 50
}

-- Script state machine (will be defined after functions)
local ScriptState = {}

-- Configuration values
local TargetMapId = tonumber(Config.Get("TargetMapId")) or 144
local TargetX = tonumber(Config.Get("TargetX")) or 100.0
local TargetY = tonumber(Config.Get("TargetY")) or 0.0
local TargetZ = tonumber(Config.Get("TargetZ")) or 100.0
local FlightTimeout = tonumber(Config.Get("FlightTimeout")) or 30
local WalkingTimeout = tonumber(Config.Get("WalkingTimeout")) or 60
local MaxRetries = tonumber(Config.Get("MaxRetries")) or 3

-- Script variables
local State = nil
local StopFlag = false
local RetryCount = 0
local TargetPosition = {x = TargetX, y = TargetY, z = TargetZ}
local CurrentMapId = nil
local FlightAttempted = false
local WalkingAttempted = false

-- Utility functions
function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Svc.Condition[CharacterCondition.beingMoved] or
           Svc.Condition[CharacterCondition.occupiedInQuestEvent] or
           Svc.Condition[CharacterCondition.occupiedMateriaExtractionAndRepair] or
           Svc.Condition[CharacterCondition.occupiedSummoningBell] or
           Player.IsBusy
end

function HasPlugin(pluginName)
    return IPC[pluginName] ~= nil
end

function WaitForNotBusy(timeout)
    timeout = timeout or 30
    local startTime = os.clock()
    
    while IsCharacterBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 0.1")
    end
    
    return not IsCharacterBusy()
end

function WaitWithTimeout(condition, timeout, interval)
    timeout = timeout or 30
    interval = interval or 0.1
    local startTime = os.clock()
    
    while not condition() and (os.clock() - startTime) < timeout do
        yield("/wait " .. interval)
    end
    
    return condition()
end

function GetDistanceToTarget()
    if not Player.Available then
        return math.huge
    end
    
    local playerPos = Player.Position
    local dx = playerPos.x - TargetPosition.x
    local dy = playerPos.y - TargetPosition.y
    local dz = playerPos.z - TargetPosition.z
    
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function IsAtTarget(distanceThreshold)
    distanceThreshold = distanceThreshold or 3.0
    return GetDistanceToTarget() <= distanceThreshold
end

function CanFly()
    -- Check if player can fly in current area
    -- This is a simplified check - in practice you might need more sophisticated detection
    return Player.Level >= 50 and not Svc.Condition[CharacterCondition.occupiedInQuestEvent]
end

function ValidateConfiguration()
    if not TargetMapId or TargetMapId <= 0 then
        yield("/echo [TeleportNav] ERROR: Invalid TargetMapId configuration")
        return false
    end
    
    if not TargetX or not TargetY or not TargetZ then
        yield("/echo [TeleportNav] ERROR: Invalid target coordinates configuration")
        return false
    end
    
    if FlightTimeout <= 0 or WalkingTimeout <= 0 then
        yield("/echo [TeleportNav] ERROR: Invalid timeout configuration")
        return false
    end
    
    if MaxRetries < 0 then
        yield("/echo [TeleportNav] ERROR: Invalid MaxRetries configuration")
        return false
    end
    
    return true
end

-- State functions
function Ready()
    yield("/echo [TeleportNav] Starting teleportation and navigation script")
    
    -- Validate configuration
    if not ValidateConfiguration() then
        State = ScriptState.error
        return
    end
    
    -- Check plugin availability
    if not HasPlugin("Lifestream") then
        yield("/echo [TeleportNav] ERROR: Lifestream plugin not found!")
        yield("/echo [TeleportNav] Please install and enable the Lifestream plugin")
        State = ScriptState.error
        return
    end
    
    if not HasPlugin("vnavmesh") then
        yield("/echo [TeleportNav] ERROR: vnavmesh plugin not found!")
        yield("/echo [TeleportNav] Please install and enable the vnavmesh plugin")
        State = ScriptState.error
        return
    end
    
    -- Check player availability
    if not Player.Available then
        yield("/echo [TeleportNav] ERROR: Player not available!")
        State = ScriptState.error
        return
    end
    
    CurrentMapId = Player.MapId
    yield("/echo [TeleportNav] Current map: " .. CurrentMapId .. ", Target map: " .. TargetMapId)
    yield("/echo [TeleportNav] Target position: X=" .. TargetX .. ", Y=" .. TargetY .. ", Z=" .. TargetZ)
    
    State = ScriptState.teleporting
end

function Teleporting()
    yield("/echo [TeleportNav] Teleporting to map " .. TargetMapId)
    
    -- Use Lifestream to teleport
    local success, error = pcall(function()
        IPC.Lifestream.TeleportToMap(TargetMapId)
    end)
    
    if not success then
        yield("/echo [TeleportNav] ERROR: Teleportation failed - " .. tostring(error))
        State = ScriptState.error
        return
    end
    
    -- Wait for teleportation to complete
    if not WaitWithTimeout(function()
        return not Svc.Condition[CharacterCondition.betweenAreas] and Player.MapId == TargetMapId
    end, 30) then
        yield("/echo [TeleportNav] ERROR: Teleportation timeout")
        State = ScriptState.error
        return
    end
    
    yield("/echo [TeleportNav] Successfully teleported to map " .. TargetMapId)
    State = ScriptState.checkingFlight
end

function CheckingFlight()
    yield("/echo [TeleportNav] Checking flight capabilities")
    
    -- Wait for player to be ready
    if not WaitForNotBusy(10) then
        yield("/echo [TeleportNav] ERROR: Player still busy after teleportation")
        State = ScriptState.error
        return
    end
    
    -- Check if we can fly
    if CanFly() then
        yield("/echo [TeleportNav] Flight is available, attempting to fly to target")
        State = ScriptState.flying
    else
        yield("/echo [TeleportNav] Flight not available, will walk to target")
        State = ScriptState.walking
    end
end

function Flying()
    if not FlightAttempted then
        FlightAttempted = true
        yield("/echo [TeleportNav] Attempting to fly to target position")
        
        -- Use vnavmesh to fly to target
        local success, error = pcall(function()
            IPC.vnavmesh.MoveTo(TargetPosition.x, TargetPosition.y, TargetPosition.z, true) -- true for flying
        end)
        
        if not success then
            yield("/echo [TeleportNav] WARNING: Flight navigation failed - " .. tostring(error))
            yield("/echo [TeleportNav] Falling back to walking")
            State = ScriptState.walking
            return
        end
    end
    
    -- Monitor flight progress
    if IPC.vnavmesh.IsRunning() then
        local distance = GetDistanceToTarget()
        yield("/echo [TeleportNav] Flying to target... Distance: " .. string.format("%.2f", distance))
        
        -- Check for timeout
        if not WaitWithTimeout(function()
            return not IPC.vnavmesh.IsRunning() or IsAtTarget(5.0)
        end, FlightTimeout) then
            yield("/echo [TeleportNav] WARNING: Flight navigation timeout, stopping and trying walking")
            IPC.vnavmesh.Stop()
            State = ScriptState.walking
            return
        end
    end
    
    -- Check if we arrived
    if IsAtTarget(5.0) then
        yield("/echo [TeleportNav] Successfully arrived at target via flight!")
        State = ScriptState.arrived
    else
        yield("/echo [TeleportNav] Flight did not reach target, trying walking")
        State = ScriptState.walking
    end
end

function Walking()
    if not WalkingAttempted then
        WalkingAttempted = true
        yield("/echo [TeleportNav] Walking to target position")
        
        -- Use vnavmesh to walk to target
        local success, error = pcall(function()
            IPC.vnavmesh.MoveTo(TargetPosition.x, TargetPosition.y, TargetPosition.z, false) -- false for walking
        end)
        
        if not success then
            yield("/echo [TeleportNav] ERROR: Walking navigation failed - " .. tostring(error))
            State = ScriptState.error
            return
        end
    end
    
    -- Monitor walking progress
    if IPC.vnavmesh.IsRunning() then
        local distance = GetDistanceToTarget()
        yield("/echo [TeleportNav] Walking to target... Distance: " .. string.format("%.2f", distance))
        
        -- Check for timeout
        if not WaitWithTimeout(function()
            return not IPC.vnavmesh.IsRunning() or IsAtTarget(3.0)
        end, WalkingTimeout) then
            yield("/echo [TeleportNav] ERROR: Walking navigation timeout")
            IPC.vnavmesh.Stop()
            State = ScriptState.error
            return
        end
    end
    
    -- Check if we arrived
    if IsAtTarget(3.0) then
        yield("/echo [TeleportNav] Successfully arrived at target via walking!")
        State = ScriptState.arrived
    else
        yield("/echo [TeleportNav] ERROR: Failed to reach target via walking")
        State = ScriptState.error
    end
end

function Arrived()
    local distance = GetDistanceToTarget()
    yield("/echo [TeleportNav] SUCCESS: Arrived at target location!")
    yield("/echo [TeleportNav] Final distance: " .. string.format("%.2f", distance))
    yield("/echo [TeleportNav] Script completed successfully")
    StopFlag = true
end

function Error()
    yield("/echo [TeleportNav] ERROR: Script encountered an error")
    
    -- Stop any running navigation
    if IPC.vnavmesh.IsRunning() then
        IPC.vnavmesh.Stop()
    end
    
    -- Check if we should retry
    if RetryCount < MaxRetries then
        RetryCount = RetryCount + 1
        yield("/echo [TeleportNav] Retrying... Attempt " .. RetryCount .. "/" .. MaxRetries)
        State = ScriptState.recovery
    else
        yield("/echo [TeleportNav] ERROR: Maximum retry attempts reached, stopping script")
        StopFlag = true
    end
end

function Recovery()
    yield("/echo [TeleportNav] Attempting recovery...")
    
    -- Reset flags
    FlightAttempted = false
    WalkingAttempted = false
    
    -- Wait a moment before retrying
    yield("/wait 2")
    
    -- Go back to ready state
    State = ScriptState.ready
end

-- Initialize state machine after all functions are defined
ScriptState = {
    ready = Ready,
    teleporting = Teleporting,
    checkingFlight = CheckingFlight,
    flying = Flying,
    walking = Walking,
    arrived = Arrived,
    error = Error,
    recovery = Recovery
}

-- Main execution loop
yield("/echo [TeleportNav] Teleportation and Navigation Script v1.0.0")
yield("/echo [TeleportNav] Target: Map " .. TargetMapId .. " at (" .. TargetX .. ", " .. TargetY .. ", " .. TargetZ .. ")")

State = ScriptState.ready
while not StopFlag do
    if not IsCharacterBusy() and not IPC.Lifestream.IsBusy() then
        State()
    end
    yield("/wait 0.1")
end

yield("/echo [TeleportNav] Script execution completed")
