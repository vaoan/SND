--[=====[
[[SND Metadata]]
author: 'Developer'
version: 1.4.1
description: Enhanced teleportation mapping script with comprehensive zone loading and character state validation
plugin_dependencies:
- Lifestream
- vnavmesh
configs:
  OutputFile:
    default: "teleportation_map_data.txt"
    description: File to save collected map ID data
  DelayBetweenTeleports:
    default: 3
    description: Delay in seconds between teleportations
  MaxTeleportsPerSession:
    default: 50
    description: Maximum teleportations per session (0 = unlimited)
  ResumeFromFile:
    default: false
    description: Resume mapping from previously saved progress
[[End Metadata]]
--]=====]

-- Script Version (keep in sync with metadata!)
local SCRIPT_VERSION = "1.4.1"

-- Version Fingerprint: v1.4.1-20240115-143022-hij456
-- Generated: 2024-01-15 14:30:22
-- Hash: hij456klm789012

-- Version History
-- v1.0.0 - Initial version
-- v1.1.0 - Added comprehensive validation, error tracking, and intelligent data collection
-- v1.2.0 - Added automatic file creation and smart skip logic for existing valid data
-- v1.2.1 - Fixed state machine initialization bug that caused "attempt to call a nil value" error
-- v1.2.2 - Enhanced location detection, improved coordinate gathering, and relaxed validation for (0,0,0) coordinates
-- v1.2.3 - Improved duplicate detection by map ID and added handling for teleportation location mismatches
-- v1.2.4 - Added teleportation failure detection, intelligent retry logic, and enhanced Lifestream debugging
-- v1.2.5 - Added enhanced debugging for teleportation success detection to identify loop issues
-- v1.3.0 - MAJOR: Simplified logic - marks failed teleports and moves on, no retries, starts with Ul'dah
-- v1.3.1 - Enhanced teleportation state tracking - ensures teleportation actually starts and completes before validation
-- v1.3.2 - Enhanced Lifestream completion tracking - handles complex routing elements and extended timeouts
-- v1.3.3 - Enhanced zone loading validation - waits for multiple zone loads and comprehensive character state checking
-- v1.4.0 - Collect map data even for failed teleports - gather all available location information regardless of teleport success
-- v1.4.1 - Added file path display and incremental data saving after each collection

-- Character condition constants
local CharacterCondition = {
    casting = 27,
    betweenAreas = 45,
    beingMoved = 70,
    occupiedInQuestEvent = 32,
    occupiedMateriaExtractionAndRepair = 39,
    occupiedSummoningBell = 50
}

-- Configuration values
local OutputFile = Config.Get("OutputFile") or "teleportation_map_data.txt"
local DelayBetweenTeleports = tonumber(Config.Get("DelayBetweenTeleports")) or 3
local MaxTeleportsPerSession = tonumber(Config.Get("MaxTeleportsPerSession")) or 50
local ResumeFromFile = Config.Get("ResumeFromFile") == "true"

-- Script variables
local StopFlag = false
local TeleportCount = 0
local CollectedLocations = {}
local VisitedMapIds = {}
local FailedTeleports = {}
local DuplicateMapIds = {}
local InvalidData = {}
local StartTime = os.clock()
local DataValidationComplete = false

-- Comprehensive list of all teleportable locations in FFXIV (starting with Ul'dah for less crowded areas)
local TeleportableLocations = {
    -- ARR Cities (starting with Ul'dah for less crowded areas)
    "Ul'dah - Steps of Nald", "Ul'dah - Steps of Thal",
    "Limsa Lominsa Lower Decks", "Limsa Lominsa Upper Decks",
    "New Gridania", "Old Gridania",
    
    -- ARR Areas
    "Middle La Noscea", "Lower La Noscea", "Eastern La Noscea", "Western La Noscea", "Upper La Noscea", "Outer La Noscea",
    "Central Shroud", "East Shroud", "South Shroud", "North Shroud",
    "Central Thanalan", "Eastern Thanalan", "Western Thanalan", "Southern Thanalan", "Northern Thanalan",
    "Coerthas Central Highlands", "Mor Dhona",
    
    -- Heavensward
    "Foundation", "The Pillars", "The Sea of Clouds", "Azys Lla",
    "The Dravanian Forelands", "The Dravanian Hinterlands", "The Churning Mists",
    
    -- Stormblood
    "Kugane", "The Ruby Sea", "Yanxia", "The Azim Steppe", "The Fringes", "The Peaks", "The Lochs",
    
    -- Shadowbringers
    "The Crystarium", "Eulmore", "Lakeland", "Kholusia", "Amh Araeng", "Il Mheg", "The Rak'tika Greatwood", "The Tempest",
    
    -- Endwalker
    "Old Sharlayan", "Labyrinthos", "Thavnair", "Garlemald", "Mare Lamentorum", "Ultima Thule", "Elpis",
    
    -- Special Areas
    "Revenant's Toll", "Idyllshire", "Rhalgr's Reach", "The Rising Stones",
    
    -- Housing Areas
    "Mist", "The Lavender Beds", "The Goblet", "Shirogane", "Empyreum",
    
    -- Deep Dungeons
    "Palace of the Dead", "Heaven-on-High", "Eureka Orthos",
    
    -- PvP Areas
    "The Wolves' Den Pier", "The Feast",
    
    -- Other Notable Locations
    "Gold Saucer", "Ishgard", "Ala Mhigo", "Doma", "The First"
}

-- State machine for mapping process
local MappingState = {
    ready = nil,  -- Will be assigned after function definitions
    validating = nil,
    teleporting = nil,
    collecting = nil,
    saving = nil,
    complete = nil
}

local State = nil  -- Will be initialized after function definitions

function Ready()
    yield("/echo [TeleportMapper] Starting teleportation mapping process...")
    yield("/echo [TeleportMapper] Target locations: " .. #TeleportableLocations)
    yield("/echo [TeleportMapper] Output file: " .. OutputFile)
    yield("/echo [TeleportMapper] Full file path: " .. io.popen("cd"):read("*l") .. "\\" .. OutputFile)
    
    if ResumeFromFile then
        LoadProgress()
    end
    
    State = MappingState.validating
end

function Validating()
    if DataValidationComplete then
        State = MappingState.teleporting
        return
    end
    
    yield("/echo [TeleportMapper] === DATA VALIDATION PHASE ===")
    
    -- Check if output file exists, create if it doesn't
    local fileExists = CheckFileExists(OutputFile)
    if fileExists then
        yield("/echo [TeleportMapper] Output file exists, validating existing data...")
        ValidateExistingData()
    else
        yield("/echo [TeleportMapper] Output file does not exist, creating new file...")
        CreateInitialFile()
    end
    
    -- Check for duplicates in current session data
    CheckForDuplicates()
    
    -- Display validation results
    DisplayValidationResults()
    
    DataValidationComplete = true
    State = MappingState.teleporting
end

function Teleporting()
    if TeleportCount >= MaxTeleportsPerSession and MaxTeleportsPerSession > 0 then
        yield("/echo [TeleportMapper] Reached maximum teleports per session: " .. MaxTeleportsPerSession)
        State = MappingState.saving
        return
    end
    
    local location = GetNextLocation()
    if not location then
        yield("/echo [TeleportMapper] All locations processed!")
        State = MappingState.saving
        return
    end
    
    yield("/echo [TeleportMapper] Teleporting to: " .. location .. " (" .. (TeleportCount + 1) .. "/" .. #TeleportableLocations .. ")")
    
    if not HasPlugin("Lifestream") then
        yield("/echo [TeleportMapper] ERROR: Lifestream plugin not available!")
        StopFlag = true
        return
    end
    
    -- Store the requested location for comparison
    local requestedLocation = location
    
    -- Execute teleportation
    local success, error = pcall(function()
        IPC.Lifestream.ExecuteCommand(location)
    end)
    
    if not success then
        yield("/echo [TeleportMapper] WARNING: Failed to teleport to " .. location .. " - " .. tostring(error))
        RecordFailedTeleport(location, tostring(error))
        TeleportCount = TeleportCount + 1
        yield("/wait " .. DelayBetweenTeleports)
        return
    end
    
    -- Debug: Check Lifestream status and response
    yield("/echo [TeleportMapper] DEBUG: Lifestream command executed successfully")
    if HasPlugin("Lifestream") then
        local success2, isBusy = pcall(function()
            return IPC.Lifestream.IsBusy()
        end)
        if success2 then
            yield("/echo [TeleportMapper] DEBUG: Lifestream IsBusy = " .. tostring(isBusy))
        end
        
        -- Try to get more information from Lifestream if available
        local success3, lastCommand = pcall(function()
            return IPC.Lifestream.LastCommand or "Unknown"
        end)
        if success3 then
            yield("/echo [TeleportMapper] DEBUG: Lifestream LastCommand = " .. tostring(lastCommand))
        end
    end
    
    -- Store initial location to detect if teleportation actually happened
    local initialLocation = GetCurrentLocationName()
    yield("/echo [TeleportMapper] DEBUG: Initial location: " .. initialLocation)
    
    -- Wait for teleportation to start (Lifestream becomes busy)
    local teleportStartTime = os.clock()
    local teleportStarted = false
    while not teleportStarted and (os.clock() - teleportStartTime) < 5 do
        if IsLifestreamBusy() then
            teleportStarted = true
            yield("/echo [TeleportMapper] DEBUG: Teleportation started")
        else
            yield("/wait 0.1")
        end
    end
    
    if not teleportStarted then
        yield("/echo [TeleportMapper] FAILED: Teleportation did not start for " .. requestedLocation)
        RecordFailedTeleport(requestedLocation, "Teleportation did not start")
        -- Still collect data for current location even if teleport didn't start
        yield("/echo [TeleportMapper] NOTE: Collecting data for current location despite failed teleport start")
        TeleportCount = TeleportCount + 1
        yield("/wait " .. DelayBetweenTeleports)
        State = MappingState.collecting
        return
    end
    
    -- Wait for Lifestream to complete all its work (teleportation + routing)
    local startTime = os.clock()
    local lastBusyCheck = os.clock()
    local consecutiveBusyChecks = 0
    
    while IsLifestreamBusy() and (os.clock() - startTime) < 60 do
        yield("/wait 1")
        
        -- Check if Lifestream has been busy for a while (might be doing complex routing)
        if IsLifestreamBusy() then
            consecutiveBusyChecks = consecutiveBusyChecks + 1
            if consecutiveBusyChecks % 10 == 0 then
                yield("/echo [TeleportMapper] DEBUG: Lifestream still busy after " .. consecutiveBusyChecks .. " seconds (complex routing?)")
            end
        else
            consecutiveBusyChecks = 0
        end
    end
    
    if IsLifestreamBusy() then
        yield("/echo [TeleportMapper] WARNING: Lifestream timeout after 60 seconds for " .. location)
        RecordFailedTeleport(location, "Lifestream timeout - complex routing may be required")
        -- Still collect data for current location even if Lifestream timed out
        yield("/echo [TeleportMapper] NOTE: Collecting data for current location despite Lifestream timeout")
        TeleportCount = TeleportCount + 1
        yield("/wait " .. DelayBetweenTeleports)
        State = MappingState.collecting
        return
    end
    
    yield("/echo [TeleportMapper] DEBUG: Lifestream completed all work")
    
    -- Wait for character to finish teleporting and any additional movement
    WaitForNotBusy(15)
    
    -- Wait for zone loading to complete (can happen multiple times)
    local zoneLoadStartTime = os.clock()
    local lastZoneCheck = os.clock()
    local zoneLoadCount = 0
    
    while IsCharacterBusy() and (os.clock() - zoneLoadStartTime) < 30 do
        yield("/wait 0.5")
        
        -- Check for zone loading indicators
        if IsZoneLoading() then
            zoneLoadCount = zoneLoadCount + 1
            yield("/echo [TeleportMapper] DEBUG: Zone loading detected (load #" .. zoneLoadCount .. ")")
            
            -- Wait for zone loading to complete
            while IsZoneLoading() and (os.clock() - zoneLoadStartTime) < 30 do
                yield("/wait 0.5")
            end
            
            if not IsZoneLoading() then
                yield("/echo [TeleportMapper] DEBUG: Zone loading completed")
            end
        end
        
        -- Check for teleportation/casting states
        if IsTeleportingOrCasting() then
            yield("/echo [TeleportMapper] DEBUG: Character still teleporting/casting")
        end
        
        -- Log progress every 5 seconds
        if (os.clock() - lastZoneCheck) >= 5 then
            yield("/echo [TeleportMapper] DEBUG: Still waiting for zone/character ready after " .. math.floor(os.clock() - zoneLoadStartTime) .. " seconds")
            lastZoneCheck = os.clock()
        end
    end
    
    if IsCharacterBusy() then
        yield("/echo [TeleportMapper] WARNING: Character still busy after zone loading timeout")
    else
        yield("/echo [TeleportMapper] DEBUG: Character and zone fully ready")
    end
    
    -- Final wait to ensure everything is stable
    yield("/wait 3")
    
    -- Get final location after teleportation
    local currentLocation = GetCurrentLocationName()
    yield("/echo [TeleportMapper] DEBUG: Requested: " .. requestedLocation .. " | Actual: " .. currentLocation)
    yield("/echo [TeleportMapper] DEBUG: Initial: " .. initialLocation .. " | Final: " .. currentLocation)
    
    -- Check if we're still in the same location (teleportation failed)
    if currentLocation == "Unknown Location" or currentLocation == "" then
        yield("/echo [TeleportMapper] ERROR: Could not determine current location after teleportation")
        RecordFailedTeleport(requestedLocation, "Could not determine location after teleportation")
        -- Still try to collect data even if location is unknown
        yield("/echo [TeleportMapper] NOTE: Attempting to collect data despite unknown location")
        TeleportCount = TeleportCount + 1
        yield("/wait " .. DelayBetweenTeleports)
        State = MappingState.collecting
        return
    end
    
    -- Check if teleportation actually happened (location changed from initial)
    if initialLocation == currentLocation then
        yield("/echo [TeleportMapper] FAILED: Teleportation did not change location - still in " .. currentLocation)
        RecordFailedTeleport(requestedLocation, "Teleportation did not change location")
        -- Still collect data for current location even if teleport didn't change location
        yield("/echo [TeleportMapper] NOTE: Collecting data for current location despite no location change")
        TeleportCount = TeleportCount + 1
        yield("/wait " .. DelayBetweenTeleports)
        State = MappingState.collecting
        return
    end
    
    -- Check if we ended up in the requested location
    if requestedLocation ~= currentLocation then
        yield("/echo [TeleportMapper] FAILED: Requested '" .. requestedLocation .. "' but ended up in '" .. currentLocation .. "'")
        RecordFailedTeleport(requestedLocation, "Teleported to different location: " .. currentLocation)
        -- Still collect data for the location we ended up in
        yield("/echo [TeleportMapper] NOTE: Collecting data for failed teleport destination: " .. currentLocation)
        TeleportCount = TeleportCount + 1
        yield("/wait " .. DelayBetweenTeleports)
        State = MappingState.collecting
        return
    end
    
    State = MappingState.collecting
end

function Collecting()
    local currentMapId = GetCurrentMapId()
    local locationName = GetCurrentLocationName()
    local coordinates = GetCurrentCoordinates()
    
    -- Debug information
    yield("/echo [TeleportMapper] DEBUG: Map ID = " .. tostring(currentMapId))
    yield("/echo [TeleportMapper] DEBUG: Location Name = " .. tostring(locationName))
    yield("/echo [TeleportMapper] DEBUG: Coordinates = X:" .. tostring(coordinates.x) .. " Y:" .. tostring(coordinates.y) .. " Z:" .. tostring(coordinates.z))
    
    -- Check if this is a failed teleport (we're collecting data despite failure)
    local isFailedTeleport = false
    for _, failed in ipairs(FailedTeleports) do
        if failed.location and (failed.location == locationName or failed.location:find(locationName) or locationName:find(failed.location)) then
            isFailedTeleport = true
            break
        end
    end
    
    if currentMapId then
        local locationData = {
            name = locationName or "Unknown",
            mapId = currentMapId,
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            coordinates = coordinates,
            isValid = true,
            isFailedTeleport = isFailedTeleport
        }
        
        -- Validate the collected data
        local validationResult = ValidateLocationData(locationData)
        if not validationResult.isValid then
            yield("/echo [TeleportMapper] WARNING: Invalid data collected for " .. locationName)
            yield("/echo [TeleportMapper] Reason: " .. validationResult.reason)
            RecordInvalidData(locationData, validationResult.reason)
        end
        
        -- Check for duplicates
        if VisitedMapIds[currentMapId] then
            yield("/echo [TeleportMapper] DUPLICATE: Map ID " .. currentMapId .. " already collected (" .. locationName .. ")")
            RecordDuplicateMapId(currentMapId, locationName)
        else
            if validationResult.isValid then
                table.insert(CollectedLocations, locationData)
                VisitedMapIds[currentMapId] = true
                if isFailedTeleport then
                    yield("/echo [TeleportMapper] SUCCESS: Collected data for failed teleport location " .. locationName .. " (Map ID: " .. currentMapId .. ")")
                else
                    yield("/echo [TeleportMapper] SUCCESS: Collected " .. locationName .. " (Map ID: " .. currentMapId .. ")")
                end
                
                -- Save data immediately after collection
                SaveIncrementalData(locationData)
            else
                yield("/echo [TeleportMapper] Skipping invalid data for " .. locationName)
            end
        end
        
    else
        yield("/echo [TeleportMapper] ERROR: Could not get map ID for current location")
        RecordFailedCollection(locationName or "Unknown", "No map ID available")
        
        -- Still try to save what we can for failed teleports
        if isFailedTeleport then
            local failedLocationData = {
                name = locationName or "Unknown",
                mapId = nil,
                timestamp = os.date("%Y-%m-%d %H:%M:%S"),
                coordinates = coordinates,
                isValid = false,
                isFailedTeleport = true
            }
            
            local file = io.open(OutputFile, "a")
            if file then
                file:write("# FAILED_TELEPORT_NO_MAP_ID: " .. locationName .. " | NO_MAP_ID | " .. tostring(coordinates.x) .. " | " .. tostring(coordinates.y) .. " | " .. tostring(coordinates.z) .. " | " .. failedLocationData.timestamp .. "\n")
                file:close()
                yield("/echo [TeleportMapper] Saved failed teleport data (no map ID) to file")
            end
        end
    end
    
    TeleportCount = TeleportCount + 1
    
    -- Save progress every 10 teleports
    if TeleportCount % 10 == 0 then
        SaveProgress()
    end
    
    yield("/wait " .. DelayBetweenTeleports)
    State = MappingState.teleporting
end

function Saving()
    yield("/echo [TeleportMapper] Saving collected data to file...")
    
    local success, error = pcall(function()
        local file = io.open(OutputFile, "w")
        if not file then
            error("Could not open file for writing: " .. OutputFile)
        end
        
        file:write("FFXIV Teleportation Map Data\n")
        file:write("Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        file:write("Total Valid Locations: " .. #CollectedLocations .. "\n")
        file:write("Total Teleports: " .. TeleportCount .. "\n")
        file:write("Failed Teleports: " .. #FailedTeleports .. "\n")
        file:write("Duplicate Map IDs: " .. #DuplicateMapIds .. "\n")
        file:write("Invalid Data Entries: " .. #InvalidData .. "\n")
        file:write("Session Duration: " .. string.format("%.2f", os.clock() - StartTime) .. " seconds\n")
        file:write("=" .. string.rep("=", 50) .. "\n\n")
        
        -- Write valid locations
        file:write("=== VALID LOCATIONS ===\n")
        for i, location in ipairs(CollectedLocations) do
            file:write(string.format("%d. %s\n", i, location.name))
            file:write(string.format("   Map ID: %d\n", location.mapId))
            file:write(string.format("   Coordinates: X=%.2f, Y=%.2f, Z=%.2f\n", 
                location.coordinates.x or 0, location.coordinates.y or 0, location.coordinates.z or 0))
            file:write(string.format("   Timestamp: %s\n", location.timestamp))
            file:write("\n")
        end
        
        -- Write failed teleports
        if #FailedTeleports > 0 then
            file:write("=== FAILED TELEPORTS ===\n")
            for i, failed in ipairs(FailedTeleports) do
                file:write(string.format("%d. %s - %s\n", i, failed.location, failed.error))
            end
            file:write("\n")
        end
        
        -- Write duplicate map IDs
        if #DuplicateMapIds > 0 then
            file:write("=== DUPLICATE MAP IDs ===\n")
            for i, duplicate in ipairs(DuplicateMapIds) do
                file:write(string.format("%d. Map ID %d - %s\n", i, duplicate.mapId, duplicate.location))
            end
            file:write("\n")
        end
        
        -- Write invalid data
        if #InvalidData > 0 then
            file:write("=== INVALID DATA ===\n")
            for i, invalid in ipairs(InvalidData) do
                file:write(string.format("%d. %s (Map ID: %d) - %s\n", i, invalid.name, invalid.mapId, invalid.reason))
            end
            file:write("\n")
        end
        
        file:close()
    end)
    
    if success then
        yield("/echo [TeleportMapper] SUCCESS: Data saved to " .. OutputFile)
        yield("/echo [TeleportMapper] Valid locations: " .. #CollectedLocations)
        yield("/echo [TeleportMapper] Failed teleports: " .. #FailedTeleports)
        yield("/echo [TeleportMapper] Duplicate map IDs: " .. #DuplicateMapIds)
        yield("/echo [TeleportMapper] Invalid data entries: " .. #InvalidData)
        yield("/echo [TeleportMapper] Total teleports: " .. TeleportCount)
    else
        yield("/echo [TeleportMapper] ERROR: Failed to save data - " .. tostring(error))
    end
    
    State = MappingState.complete
end

function Complete()
    yield("/echo [TeleportMapper] Mapping process completed!")
    yield("/echo [TeleportMapper] Check " .. OutputFile .. " for results")
    StopFlag = true
end

-- Validation and tracking functions
function CheckFileExists(filename)
    local file = io.open(filename, "r")
    if file then
        file:close()
        return true
    end
    return false
end

function ValidateExistingData()
    local success, error = pcall(function()
        local file = io.open(OutputFile, "r")
        if not file then
            return
        end
        
        local lineCount = 0
        local validLocations = 0
        local existingMapIds = {}
        
        for line in file:lines() do
            lineCount = lineCount + 1
            
            -- Look for map ID lines
            local mapId = line:match("Map ID: (%d+)")
            if mapId then
                local id = tonumber(mapId)
                if existingMapIds[id] then
                    yield("/echo [TeleportMapper] WARNING: Duplicate map ID found in existing file: " .. id)
                    RecordDuplicateMapId(id, "Found in existing file")
                else
                    existingMapIds[id] = true
                    validLocations = validLocations + 1
                end
            end
        end
        
        file:close()
        
        yield("/echo [TeleportMapper] Existing file analysis:")
        yield("/echo [TeleportMapper] - Total lines: " .. lineCount)
        yield("/echo [TeleportMapper] - Valid locations found: " .. validLocations)
        yield("/echo [TeleportMapper] - Unique map IDs: " .. GetTableSize(existingMapIds))
        
        -- Load existing data into our tracking
        for mapId, _ in pairs(existingMapIds) do
            VisitedMapIds[mapId] = true
        end
        
    end)
    
    if not success then
        yield("/echo [TeleportMapper] WARNING: Failed to validate existing data - " .. tostring(error))
    end
end

function CheckForDuplicates()
    local mapIdCounts = {}
    local duplicates = 0
    
    for _, location in ipairs(CollectedLocations) do
        local mapId = location.mapId
        if mapIdCounts[mapId] then
            mapIdCounts[mapId] = mapIdCounts[mapId] + 1
            duplicates = duplicates + 1
            yield("/echo [TeleportMapper] DUPLICATE: Map ID " .. mapId .. " appears " .. mapIdCounts[mapId] .. " times")
        else
            mapIdCounts[mapId] = 1
        end
    end
    
    if duplicates > 0 then
        yield("/echo [TeleportMapper] WARNING: Found " .. duplicates .. " duplicate map IDs in current session")
    else
        yield("/echo [TeleportMapper] No duplicates found in current session data")
    end
end

function DisplayValidationResults()
    yield("/echo [TeleportMapper] === VALIDATION RESULTS ===")
    yield("/echo [TeleportMapper] File exists: " .. tostring(CheckFileExists(OutputFile)))
    yield("/echo [TeleportMapper] Current session locations: " .. #CollectedLocations)
    yield("/echo [TeleportMapper] Visited map IDs: " .. GetTableSize(VisitedMapIds))
    yield("/echo [TeleportMapper] Failed teleports: " .. #FailedTeleports)
    yield("/echo [TeleportMapper] Duplicate map IDs: " .. #DuplicateMapIds)
    yield("/echo [TeleportMapper] Invalid data entries: " .. #InvalidData)
    yield("/echo [TeleportMapper] ==========================")
end

function ValidateLocationData(locationData)
    local result = {isValid = true, reason = ""}
    
    -- Check if map ID is valid
    if not locationData.mapId or locationData.mapId <= 0 then
        result.isValid = false
        result.reason = "Invalid map ID: " .. tostring(locationData.mapId)
        return result
    end
    
    -- Check if location name is valid (be more lenient)
    if not locationData.name or locationData.name == "" then
        result.isValid = false
        result.reason = "Invalid location name: " .. tostring(locationData.name)
        return result
    end
    
    -- Check if coordinates exist (but don't reject 0,0,0 as it might be valid)
    local coords = locationData.coordinates
    if not coords or coords.x == nil or coords.y == nil or coords.z == nil then
        result.isValid = false
        result.reason = "Missing coordinates"
        return result
    end
    
    -- Only reject coordinates if they're completely invalid (like NaN or extremely large values)
    if not (type(coords.x) == "number" and type(coords.y) == "number" and type(coords.z) == "number") then
        result.isValid = false
        result.reason = "Invalid coordinate types"
        return result
    end
    
    -- Accept (0,0,0) as valid since some locations might actually be at origin
    -- Only reject if coordinates are NaN or infinity
    if coords.x ~= coords.x or coords.y ~= coords.y or coords.z ~= coords.z then
        result.isValid = false
        result.reason = "NaN coordinates detected"
        return result
    end
    
    return result
end

function RecordFailedTeleport(location, error)
    table.insert(FailedTeleports, {
        location = location,
        error = error,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })
end

function RecordDuplicateMapId(mapId, location)
    table.insert(DuplicateMapIds, {
        mapId = mapId,
        location = location,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })
end

function RecordInvalidData(locationData, reason)
    table.insert(InvalidData, {
        name = locationData.name,
        mapId = locationData.mapId,
        reason = reason,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })
end

function RecordFailedCollection(location, reason)
    table.insert(InvalidData, {
        name = location,
        mapId = 0,
        reason = reason,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })
end

function GetTableSize(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function CreateInitialFile()
    local success, error = pcall(function()
        local file = io.open(OutputFile, "w")
        if not file then
            error("Could not create initial file: " .. OutputFile)
        end
        
        file:write("FFXIV Teleportation Map Data\n")
        file:write("Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        file:write("Total Valid Locations: 0\n")
        file:write("Total Teleports: 0\n")
        file:write("Failed Teleports: 0\n")
        file:write("Duplicate Map IDs: 0\n")
        file:write("Invalid Data Entries: 0\n")
        file:write("Session Duration: 0.00 seconds\n")
        file:write("=" .. string.rep("=", 50) .. "\n\n")
        file:write("=== VALID LOCATIONS ===\n")
        file:write("(No data collected yet)\n\n")
        file:write("=== FAILED TELEPORTS ===\n")
        file:write("(No failures yet)\n\n")
        file:write("=== DUPLICATE MAP IDs ===\n")
        file:write("(No duplicates yet)\n\n")
        file:write("=== INVALID DATA ===\n")
        file:write("(No invalid data yet)\n\n")
        
        file:close()
    end)
    
    if success then
        yield("/echo [TeleportMapper] SUCCESS: Created initial file: " .. OutputFile)
    else
        yield("/echo [TeleportMapper] ERROR: Failed to create initial file - " .. tostring(error))
    end
end

function ShouldTeleportToLocation(locationName)
    -- Check if we already have valid, non-duplicate data for this location
    if HasValidDataForLocation(locationName) then
        yield("/echo [TeleportMapper] SKIP: " .. locationName .. " already has valid data")
        return false
    end
    
    -- Check if this location failed teleportation before (can't be teleported to)
    for _, failed in ipairs(FailedTeleports) do
        if failed.location == locationName then
            yield("/echo [TeleportMapper] SKIP: " .. locationName .. " cannot be teleported to (failed before)")
            return false
        end
    end
    
    -- Check if this location had invalid data before
    for _, invalid in ipairs(InvalidData) do
        if invalid.name == locationName then
            yield("/echo [TeleportMapper] RETRY: " .. locationName .. " had invalid data before, retrying...")
            return true -- Retry locations with invalid data
        end
    end
    
    -- Check if this location is a duplicate
    if IsDuplicateLocation(locationName) then
        yield("/echo [TeleportMapper] SKIP: " .. locationName .. " is a duplicate")
        return false
    end
    
    -- Check if we've already collected this map ID (even if location name is different)
    local expectedMapId = GetExpectedMapIdForLocation(locationName)
    if expectedMapId and VisitedMapIds[expectedMapId] then
        yield("/echo [TeleportMapper] SKIP: " .. locationName .. " (Map ID " .. expectedMapId .. ") already collected")
        return false
    end
    
    -- If we get here, we need to collect data for this location
    yield("/echo [TeleportMapper] COLLECT: " .. locationName .. " needs data collection")
    return true
end

function HasValidDataForLocation(locationName)
    -- Check if we have valid data for this location in current session
    for _, location in ipairs(CollectedLocations) do
        if location.name == locationName and location.isValid then
            return true
        end
    end
    
    -- Check if this location exists in the file with valid data
    return HasValidDataInFile(locationName)
end

function HasValidDataInFile(locationName)
    local success, result = pcall(function()
        local file = io.open(OutputFile, "r")
        if not file then
            return false
        end
        
        local foundLocation = false
        local foundMapId = false
        local foundCoordinates = false
        
        for line in file:lines() do
            -- Look for the location name
            if line:match("^%d+%. " .. locationName .. "$") then
                foundLocation = true
            end
            
            -- Look for map ID after finding the location
            if foundLocation and line:match("Map ID: (%d+)") then
                local mapId = tonumber(line:match("Map ID: (%d+)"))
                if mapId and mapId > 0 then
                    foundMapId = true
                end
            end
            
            -- Look for coordinates after finding the location
            if foundLocation and line:match("Coordinates: X=([%d%.%-]+), Y=([%d%.%-]+), Z=([%d%.%-]+)") then
                local x, y, z = line:match("Coordinates: X=([%d%.%-]+), Y=([%d%.%-]+), Z=([%d%.%-]+)")
                if x and y and z and not (x == "0" and y == "0" and z == "0") then
                    foundCoordinates = true
                end
            end
            
            -- If we found a new location entry, reset our search
            if line:match("^%d+%. ") and not line:match("^%d+%. " .. locationName .. "$") then
                if foundLocation then
                    break -- We've moved past our location
                end
            end
        end
        
        file:close()
        return foundLocation and foundMapId and foundCoordinates
    end)
    
    return success and result
end

function IsDuplicateLocation(locationName)
    -- Check if this location name appears multiple times in our data
    local count = 0
    for _, location in ipairs(CollectedLocations) do
        if location.name == locationName then
            count = count + 1
        end
    end
    
    -- Also check in the file
    local fileCount = CountLocationInFile(locationName)
    
    return (count + fileCount) > 1
end

function CountLocationInFile(locationName)
    local success, count = pcall(function()
        local file = io.open(OutputFile, "r")
        if not file then
            return 0
        end
        
        local locationCount = 0
        for line in file:lines() do
            if line:match("^%d+%. " .. locationName .. "$") then
                locationCount = locationCount + 1
            end
        end
        
        file:close()
        return locationCount
    end)
    
    return success and count or 0
end

-- Utility functions
function GetNextLocation()
    for i = 1, #TeleportableLocations do
        local location = TeleportableLocations[i]
        if ShouldTeleportToLocation(location) then
            return location
        end
    end
    return nil
end

function IsLocationVisited(locationName)
    -- Check if we have valid data for this location
    for _, location in ipairs(CollectedLocations) do
        if location.name == locationName and location.isValid then
            return true
        end
    end
    
    -- Check if this location failed before and we should retry
    for _, failed in ipairs(FailedTeleports) do
        if failed.location == locationName then
            yield("/echo [TeleportMapper] Location " .. locationName .. " failed before, retrying...")
            return false -- Retry failed locations
        end
    end
    
    -- Check if this location had invalid data before
    for _, invalid in ipairs(InvalidData) do
        if invalid.name == locationName then
            yield("/echo [TeleportMapper] Location " .. locationName .. " had invalid data before, retrying...")
            return false -- Retry locations with invalid data
        end
    end
    
    return false
end

function GetCurrentMapId()
    if Svc and Svc.ClientState and Svc.ClientState.TerritoryType then
        return Svc.ClientState.TerritoryType
    elseif Player and Player.MapId then
        return Player.MapId
    elseif Player and Player.TerritoryType then
        return Player.TerritoryType
    end
    return nil
end

function GetCurrentLocationName()
    -- Try multiple methods to get the current location name
    local locationName = nil
    
    -- Method 1: Try Svc.TerritoryInfo.PlaceName
    if Svc and Svc.TerritoryInfo and Svc.TerritoryInfo.PlaceName then
        local success, placeName = pcall(function()
            return Svc.TerritoryInfo.PlaceName.Name
        end)
        if success and placeName and placeName ~= "" then
            locationName = placeName
        end
    end
    
    -- Method 2: Try Svc.ClientState.LocalPlayer and TerritoryType
    if not locationName and Svc and Svc.ClientState then
        local success, player = pcall(function()
            return Svc.ClientState.LocalPlayer
        end)
        if success and player and player.CurrentWorld and player.CurrentWorld.GameData then
            local success2, worldName = pcall(function()
                return player.CurrentWorld.GameData.Name
            end)
            if success2 and worldName and worldName ~= "" then
                locationName = worldName
            end
        end
    end
    
    -- Method 3: Try to get territory name from current map ID
    if not locationName then
        local currentMapId = GetCurrentMapId()
        if currentMapId then
            locationName = GetLocationNameFromMapId(currentMapId)
        end
    end
    
    -- Method 4: Fallback to a generic name based on map ID
    if not locationName then
        local currentMapId = GetCurrentMapId()
        if currentMapId then
            locationName = "Map ID " .. currentMapId
        end
    end
    
    return locationName or "Unknown Location"
end

function GetLocationNameFromMapId(mapId)
    -- Hardcoded mapping for common locations (same as in TeleportNavigationScript)
    local commonLocations = {
        [130] = "Limsa Lominsa Lower Decks",
        [129] = "Limsa Lominsa Upper Decks", 
        [35] = "Ul'dah - Steps of Nald",
        [36] = "Ul'dah - Steps of Thal",
        [2] = "New Gridania",
        [1] = "Old Gridania",
        [419] = "Foundation (Ishgard)",
        [420] = "The Pillars (Ishgard)",
        [628] = "Kugane",
        [819] = "The Crystarium",
        [820] = "Eulmore",
        [1055] = "Radz-at-Han",
        [1056] = "Solution Nine",
        [1057] = "Old Sharlayan",
        [1058] = "Labyrinthos",
        [1059] = "Thavnair",
        [1060] = "Garlemald",
        [1061] = "Mare Lamentorum",
        [1062] = "Ultima Thule",
        [1063] = "Elpis",
        [156] = "Revenant's Toll (Mor Dhona)",
        [478] = "Idyllshire",
        [635] = "Rhalgr's Reach"
    }
    
    return commonLocations[mapId]
end

function GetExpectedMapIdForLocation(locationName)
    -- Reverse mapping: location name -> map ID
    local locationToMapId = {
        ["Limsa Lominsa Lower Decks"] = 130,
        ["Limsa Lominsa Upper Decks"] = 129,
        ["Ul'dah - Steps of Nald"] = 35,
        ["Ul'dah - Steps of Thal"] = 36,
        ["New Gridania"] = 2,
        ["Old Gridania"] = 1,
        ["Foundation (Ishgard)"] = 419,
        ["The Pillars (Ishgard)"] = 420,
        ["Kugane"] = 628,
        ["The Crystarium"] = 819,
        ["Eulmore"] = 820,
        ["Radz-at-Han"] = 1055,
        ["Solution Nine"] = 1056,
        ["Old Sharlayan"] = 1057,
        ["Labyrinthos"] = 1058,
        ["Thavnair"] = 1059,
        ["Garlemald"] = 1060,
        ["Mare Lamentorum"] = 1061,
        ["Ultima Thule"] = 1062,
        ["Elpis"] = 1063,
        ["Revenant's Toll (Mor Dhona)"] = 156,
        ["Idyllshire"] = 478,
        ["Rhalgr's Reach"] = 635
    }
    
    return locationToMapId[locationName]
end


function GetCurrentCoordinates()
    local coords = {x = 0, y = 0, z = 0}
    
    -- Try multiple methods to get coordinates
    if Player and Player.Position then
        coords.x = Player.Position.x or 0
        coords.y = Player.Position.y or 0
        coords.z = Player.Position.z or 0
    end
    
    -- If we got (0,0,0), try alternative methods
    if coords.x == 0 and coords.y == 0 and coords.z == 0 then
        -- Try Svc.ClientState.LocalPlayer
        if Svc and Svc.ClientState and Svc.ClientState.LocalPlayer then
            local success, player = pcall(function()
                return Svc.ClientState.LocalPlayer
            end)
            if success and player and player.Position then
                coords.x = player.Position.X or 0
                coords.y = player.Position.Y or 0
                coords.z = player.Position.Z or 0
            end
        end
    end
    
    return coords
end

function IsCharacterBusy()
    if not Player or not Player.Available then
        return false
    end
    
    return (Svc.Condition[CharacterCondition.casting] == true) or
           (Svc.Condition[CharacterCondition.betweenAreas] == true) or
           (Svc.Condition[CharacterCondition.beingMoved] == true) or
           (Svc.Condition[CharacterCondition.occupiedInQuestEvent] == true) or
           (Svc.Condition[CharacterCondition.occupiedMateriaExtractionAndRepair] == true) or
           (Svc.Condition[CharacterCondition.occupiedSummoningBell] == true) or
           (Player.IsBusy == true)
end

function IsZoneLoading()
    -- Check if character is between areas (zone loading)
    return Svc.Condition[CharacterCondition.betweenAreas] == true
end

function IsTeleportingOrCasting()
    -- Check if character is teleporting or casting
    return (Svc.Condition[CharacterCondition.casting] == true) or
           (Svc.Condition[CharacterCondition.beingMoved] == true)
end

function HasPlugin(pluginName)
    return IPC and IPC[pluginName] ~= nil
end

function IsLifestreamBusy()
    if not HasPlugin("Lifestream") then
        return false
    end
    
    local success, result = pcall(function()
        return IPC.Lifestream.IsBusy()
    end)
    
    return success and result == true
end

function WaitForNotBusy(timeout)
    timeout = timeout or 30
    local startTime = os.clock()
    local lastStatusCheck = os.clock()
    
    while IsCharacterBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 0.1")
        
        -- Log status every 5 seconds for debugging
        if (os.clock() - lastStatusCheck) >= 5 then
            yield("/echo [TeleportMapper] DEBUG: Character still busy after " .. math.floor(os.clock() - startTime) .. " seconds")
            lastStatusCheck = os.clock()
        end
    end
    
    local finalStatus = not IsCharacterBusy()
    if finalStatus then
        yield("/echo [TeleportMapper] DEBUG: Character ready after " .. math.floor(os.clock() - startTime) .. " seconds")
    else
        yield("/echo [TeleportMapper] DEBUG: Character still busy after timeout")
    end
    
    return finalStatus
end

function SaveProgress()
    local progressFile = OutputFile .. ".progress"
    local success, error = pcall(function()
        local file = io.open(progressFile, "w")
        if not file then
            error("Could not open progress file for writing")
        end
        
        file:write("TeleportCount=" .. TeleportCount .. "\n")
        file:write("VisitedMapIds=" .. table.concat(GetVisitedMapIds(), ",") .. "\n")
        
        file:close()
    end)
    
    if not success then
        yield("/echo [TeleportMapper] WARNING: Failed to save progress - " .. tostring(error))
    end
end

function SaveIncrementalData(locationData)
    local success, error = pcall(function()
        local file = io.open(OutputFile, "a")
        if not file then
            error("Could not open file for writing: " .. OutputFile)
        end
        
        if locationData.isFailedTeleport then
            -- Save failed teleport data with special marker
            file:write("# FAILED_TELEPORT_DATA: " .. locationData.name .. " | " .. tostring(locationData.mapId) .. " | " .. tostring(locationData.coordinates.x) .. " | " .. tostring(locationData.coordinates.y) .. " | " .. tostring(locationData.coordinates.z) .. " | " .. locationData.timestamp .. "\n")
        else
            -- Save successful teleport data
            file:write("SUCCESS: " .. locationData.name .. " | " .. tostring(locationData.mapId) .. " | " .. tostring(locationData.coordinates.x) .. " | " .. tostring(locationData.coordinates.y) .. " | " .. tostring(locationData.coordinates.z) .. " | " .. locationData.timestamp .. "\n")
        end
        
        file:close()
    end)
    
    if success then
        yield("/echo [TeleportMapper] Saved incremental data to file")
    else
        yield("/echo [TeleportMapper] WARNING: Failed to save incremental data - " .. tostring(error))
    end
end

function LoadProgress()
    local progressFile = OutputFile .. ".progress"
    local success, error = pcall(function()
        local file = io.open(progressFile, "r")
        if not file then
            return -- No progress file exists
        end
        
        for line in file:lines() do
            local key, value = line:match("([^=]+)=(.*)")
            if key == "TeleportCount" then
                TeleportCount = tonumber(value) or 0
            elseif key == "VisitedMapIds" then
                for mapId in value:gmatch("([^,]+)") do
                    VisitedMapIds[tonumber(mapId)] = true
                end
            end
        end
        
        file:close()
        yield("/echo [TeleportMapper] Loaded progress: " .. TeleportCount .. " teleports completed")
    end)
    
    if not success then
        yield("/echo [TeleportMapper] WARNING: Failed to load progress - " .. tostring(error))
    end
end

function GetVisitedMapIds()
    local mapIds = {}
    for mapId, _ in pairs(VisitedMapIds) do
        table.insert(mapIds, tostring(mapId))
    end
    return mapIds
end

-- Initialize state machine after all functions are defined
MappingState.ready = Ready
MappingState.validating = Validating
MappingState.teleporting = Teleporting
MappingState.collecting = Collecting
MappingState.saving = Saving
MappingState.complete = Complete

State = MappingState.ready

-- Main execution
yield("/echo [TeleportMapper] === FFXIV Teleportation Mapper v" .. SCRIPT_VERSION .. " ===")
yield("/echo [TeleportMapper] This script will visit every teleportable location in FFXIV")
yield("/echo [TeleportMapper] and collect map IDs for comprehensive mapping data")
yield("/echo [TeleportMapper] Data will be saved to: " .. OutputFile)
yield("/echo [TeleportMapper] Full file path: " .. io.popen("cd"):read("*l") .. "\\" .. OutputFile)

-- Check prerequisites
if not HasPlugin("Lifestream") then
    yield("/echo [TeleportMapper] ERROR: Lifestream plugin not found!")
    yield("/echo [TeleportMapper] Please install and enable the Lifestream plugin")
    return
end

if not Player or not Player.Available then
    yield("/echo [TeleportMapper] ERROR: Player not available!")
    return
end

-- Main execution loop
while not StopFlag do
    if not IsCharacterBusy() then
        if State and type(State) == "function" then
            State()
        else
            yield("/echo [TeleportMapper] ERROR: State function not properly initialized!")
            yield("/echo [TeleportMapper] Current State: " .. tostring(State))
            StopFlag = true
        end
    end
    yield("/wait 0.1")
end

yield("/echo [TeleportMapper] Script execution completed")
