--[=====[
[[SND Metadata]]
author: 'Developer'
version: 1.2.0
description: Smart teleportation mapping script with automatic file creation and intelligent skip logic for existing valid data
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

-- Version Fingerprint: v1.2.0-20240115-143022-ghi789
-- Generated: 2024-01-15 14:30:22
-- Hash: ghi789jkl012345

-- Version History
-- v1.0.0 - Initial version
-- v1.1.0 - Added comprehensive validation, error tracking, and intelligent data collection
-- v1.2.0 - Added automatic file creation and smart skip logic for existing valid data

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

-- Comprehensive list of all teleportable locations in FFXIV
local TeleportableLocations = {
    -- ARR Cities
    "Limsa Lominsa Lower Decks", "Limsa Lominsa Upper Decks",
    "Ul'dah - Steps of Nald", "Ul'dah - Steps of Thal",
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
    ready = Ready,
    validating = Validating,
    teleporting = Teleporting,
    collecting = Collecting,
    saving = Saving,
    complete = Complete
}

local State = MappingState.ready

function Ready()
    yield("/echo [TeleportMapper] Starting teleportation mapping process...")
    yield("/echo [TeleportMapper] Target locations: " .. #TeleportableLocations)
    yield("/echo [TeleportMapper] Output file: " .. OutputFile)
    
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
    
    -- Wait for teleportation to complete
    local startTime = os.clock()
    while IsLifestreamBusy() and (os.clock() - startTime) < 30 do
        yield("/wait 1")
    end
    
    if IsLifestreamBusy() then
        yield("/echo [TeleportMapper] WARNING: Teleportation timeout for " .. location)
        RecordFailedTeleport(location, "Teleportation timeout")
    end
    
    -- Wait for character to finish teleporting
    WaitForNotBusy(10)
    
    State = MappingState.collecting
end

function Collecting()
    local currentMapId = GetCurrentMapId()
    local locationName = GetCurrentLocationName()
    
    if currentMapId then
        local locationData = {
            name = locationName or "Unknown",
            mapId = currentMapId,
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            coordinates = GetCurrentCoordinates(),
            isValid = true
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
                yield("/echo [TeleportMapper] Collected: " .. locationName .. " (Map ID: " .. currentMapId .. ")")
            else
                yield("/echo [TeleportMapper] Skipping invalid data for " .. locationName)
            end
        end
    else
        yield("/echo [TeleportMapper] ERROR: Could not get map ID for current location")
        RecordFailedCollection(locationName or "Unknown", "No map ID available")
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
    
    -- Check if location name is valid
    if not locationData.name or locationData.name == "Unknown" or locationData.name == "" then
        result.isValid = false
        result.reason = "Invalid location name: " .. tostring(locationData.name)
        return result
    end
    
    -- Check if coordinates are reasonable (basic validation)
    local coords = locationData.coordinates
    if not coords or not coords.x or not coords.y or not coords.z then
        result.isValid = false
        result.reason = "Missing coordinates"
        return result
    end
    
    -- Check for obviously invalid coordinates (like 0,0,0 for most locations)
    if coords.x == 0 and coords.y == 0 and coords.z == 0 then
        result.isValid = false
        result.reason = "Suspicious coordinates (0,0,0)"
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
    
    -- Check if this location failed before and we should retry
    for _, failed in ipairs(FailedTeleports) do
        if failed.location == locationName then
            yield("/echo [TeleportMapper] RETRY: " .. locationName .. " failed before, retrying...")
            return true -- Retry failed locations
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
    if Svc and Svc.TerritoryInfo and Svc.TerritoryInfo.PlaceName then
        local success, placeName = pcall(function()
            return Svc.TerritoryInfo.PlaceName.Name
        end)
        if success and placeName then
            return placeName
        end
    end
    return "Unknown Location"
end

function GetCurrentCoordinates()
    if Player and Player.Position then
        return {
            x = Player.Position.x or 0,
            y = Player.Position.y or 0,
            z = Player.Position.z or 0
        }
    end
    return {x = 0, y = 0, z = 0}
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
    
    while IsCharacterBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 0.1")
    end
    
    return not IsCharacterBusy()
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

-- Main execution
yield("/echo [TeleportMapper] FFXIV Teleportation Mapper v1.0.0")
yield("/echo [TeleportMapper] This script will visit every teleportable location in FFXIV")
yield("/echo [TeleportMapper] and collect map IDs for comprehensive mapping data")

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
        State()
    end
    yield("/wait 0.1")
end

yield("/echo [TeleportMapper] Script execution completed")
