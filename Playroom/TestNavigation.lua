--[=====[
[[SND Metadata]]
author: 'vaoan'
version: 1.0.0
description: Test vnavmesh navigation from Arcanist's Guild to Ocean Fishing NPC
plugin_dependencies:
- vnavmesh
[[End Metadata]]
--]=====]

local SCRIPT_VERSION = "1.0.0"

-------------------------------------------------------------------------------
-- LOCATIONS (Limsa Lower Decks - Zone 129)
-------------------------------------------------------------------------------
local LOCATIONS = {
    ArcanistGuild = { x = -335, y = 12, z = 53 },
    OceanFishingNPC = { x = -410, y = 4, z = 76 },
    MerchantMender = { x = -398, y = 3, z = 78 },
}

local ZONES = {
    LimsaLower = 129,
    LimsaUpper = 128,
    Inn = 177,
}

-------------------------------------------------------------------------------
-- UTILITIES
-------------------------------------------------------------------------------
local function Log(msg)
    yield("/echo [TestNav] " .. msg)
end

local function HasPlugin(name)
    for plugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        if plugin.InternalName == name and plugin.IsLoaded then
            return true
        end
    end
    return false
end

local function GetPlayerPos()
    if Player.Available then
        local pos = Player.Position
        return pos.X, pos.Y, pos.Z
    end
    return 0, 0, 0
end

local function GetDistanceTo(x, y, z)
    local px, py, pz = GetPlayerPos()
    local dx = x - px
    local dy = y - py
    local dz = z - pz
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function IsNear(location, tolerance)
    tolerance = tolerance or 5
    return GetDistanceTo(location.x, location.y, location.z) < tolerance
end

-------------------------------------------------------------------------------
-- VNAVMESH HELPERS
-------------------------------------------------------------------------------
local function IsVnavReady()
    if not HasPlugin("vnavmesh") then
        return false
    end
    local ok, result = pcall(function() return IPC.vnavmesh.IsReady() end)
    return ok and result
end

local function IsVnavRunning()
    local ok, result = pcall(function()
        return IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()
    end)
    return ok and result
end

local function StopVnav()
    pcall(function() IPC.vnavmesh.Stop() end)
end

local function MoveTo(x, y, z, fly)
    fly = fly or false
    local ok, result = pcall(function()
        return IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), fly)
    end)
    return ok and result
end

local function MoveToLocation(location, tolerance, timeout)
    tolerance = tolerance or 3
    timeout = timeout or 30

    if IsNear(location, tolerance) then
        Log("Already at destination")
        return true
    end

    Log(string.format("Moving to (%.1f, %.1f, %.1f)...", location.x, location.y, location.z))

    if not MoveTo(location.x, location.y, location.z, false) then
        Log("Failed to start movement")
        return false
    end

    -- Wait for movement to start
    local startWait = os.clock()
    while not IsVnavRunning() and (os.clock() - startWait) < 3 do
        yield("/wait 0.1")
    end

    -- Wait for movement to complete or timeout
    local startTime = os.clock()
    while IsVnavRunning() and (os.clock() - startTime) < timeout do
        local dist = GetDistanceTo(location.x, location.y, location.z)

        -- Stop early if close enough
        if dist < tolerance then
            StopVnav()
            Log(string.format("Arrived! Distance: %.1f", dist))
            return true
        end

        yield("/wait 0.5")
    end

    -- Check final position
    local finalDist = GetDistanceTo(location.x, location.y, location.z)
    if finalDist < tolerance then
        Log(string.format("Arrived! Distance: %.1f", finalDist))
        return true
    end

    if IsVnavRunning() then
        Log("Timeout - stopping movement")
        StopVnav()
    end

    Log(string.format("Movement ended. Distance: %.1f", finalDist))
    return finalDist < tolerance * 2  -- Allow some slack
end

-------------------------------------------------------------------------------
-- MAIN
-------------------------------------------------------------------------------
Log("=== Navigation Test v" .. SCRIPT_VERSION .. " ===")

-- Check prerequisites
if not HasPlugin("vnavmesh") then
    Log("ERROR: vnavmesh plugin not installed!")
    return
end

if not IsVnavReady() then
    Log("ERROR: vnavmesh not ready (navmesh may be building)")
    return
end

if not Player.Available then
    Log("ERROR: Player not available")
    return
end

-- Check zone
local currentZone = GetZoneID()
Log("Current zone: " .. currentZone)

if currentZone ~= ZONES.LimsaLower then
    Log("ERROR: Must be in Limsa Lower Decks (zone 129)")
    Log("You are in zone: " .. currentZone)
    return
end

-- Show current position
local px, py, pz = GetPlayerPos()
Log(string.format("Current pos: (%.1f, %.1f, %.1f)", px, py, pz))

-- Determine destination based on current position
local destination
local destName

if IsNear(LOCATIONS.ArcanistGuild, 15) then
    destination = LOCATIONS.OceanFishingNPC
    destName = "Ocean Fishing NPC"
elseif IsNear(LOCATIONS.OceanFishingNPC, 15) then
    destination = LOCATIONS.ArcanistGuild
    destName = "Arcanist's Guild"
else
    -- Default: go to Ocean Fishing NPC
    destination = LOCATIONS.OceanFishingNPC
    destName = "Ocean Fishing NPC"
end

Log("Destination: " .. destName)
Log(string.format("Target: (%.1f, %.1f, %.1f)", destination.x, destination.y, destination.z))
Log("Distance: " .. string.format("%.1f", GetDistanceTo(destination.x, destination.y, destination.z)))

-- Move!
local success = MoveToLocation(destination, 5, 60)

if success then
    Log("=== Navigation SUCCESS ===")
else
    Log("=== Navigation FAILED ===")
end

-- Final position
px, py, pz = GetPlayerPos()
Log(string.format("Final pos: (%.1f, %.1f, %.1f)", px, py, pz))
