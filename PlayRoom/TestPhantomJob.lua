--[=====[
[[SND Metadata]]
author: 'Vaoan'
version: 1.0.0
description: Test script to discover how to access phantom job data in SND/Dalamud API
[[End Metadata]]
--]=====]

--[[
HOW IT WORKS:
This test script explores various API locations to find where phantom job data is stored.
Run this while you have a phantom job equipped in Occult Crescent.

It will check:
1. LocalPlayer properties for phantom job data
2. Excel sheet data for PhantomJob-related sheets
3. Character conditions and status effects
4. Raw player state data

Results are logged to chat for analysis.
--]]

-- Logging helper
function Log(message)
    yield("/echo [PhantomTest] " .. message)
end

-- Safe property access
function TryGetProperty(obj, propName)
    local success, result = pcall(function()
        return obj[propName]
    end)
    if success then
        return result
    else
        return nil
    end
end

-- Check if player is available
if not Svc.ClientState.LocalPlayer then
    yield("/echo [PhantomTest] ERROR: Player not available")
    return
end

Log("=== Starting Phantom Job Detection Test ===")

-- Test 1: Check LocalPlayer properties
Log("--- Test 1: LocalPlayer Properties ---")
local player = Svc.ClientState.LocalPlayer

-- Main job info
Log(string.format("Main Job ID: %d", player.ClassJob.Id))
Log(string.format("Main Job: %s", player.ClassJob.GameData.Name))

-- Check for phantom-related properties
local phantomJobProp = TryGetProperty(player, "PhantomJob")
if phantomJobProp then
    Log("Found: LocalPlayer.PhantomJob = " .. tostring(phantomJobProp))
else
    Log("LocalPlayer.PhantomJob: Not found")
end

local phantomJobIdProp = TryGetProperty(player, "PhantomJobId")
if phantomJobIdProp then
    Log("Found: LocalPlayer.PhantomJobId = " .. tostring(phantomJobIdProp))
else
    Log("LocalPlayer.PhantomJobId: Not found")
end

local subJobProp = TryGetProperty(player, "SubJob")
if subJobProp then
    Log("Found: LocalPlayer.SubJob = " .. tostring(subJobProp))
else
    Log("LocalPlayer.SubJob: Not found")
end

-- Test 2: Check Excel sheets
Log("--- Test 2: Excel Sheet Data ---")
local success, phantomSheet = pcall(function()
    return Svc.Data:GetExcelSheet("PhantomJob")
end)
if success and phantomSheet then
    Log("Found PhantomJob sheet!")
    local rowCount = 0
    for row in luanet.each(phantomSheet) do
        rowCount = rowCount + 1
        if rowCount <= 5 then
            Log(string.format("  Row %d: RowId=%d", rowCount, row.RowId))
        end
    end
    Log(string.format("Total PhantomJob rows: %d", rowCount))
else
    Log("PhantomJob sheet: Not found or error")
end

-- Try alternate sheet names
local alternateNames = {
    "Phantom",
    "PhantomJobs",
    "SubJob",
    "OccultJob",
    "FieldOperationJob"
}

for _, sheetName in ipairs(alternateNames) do
    success, result = pcall(function()
        return Svc.Data:GetExcelSheet(sheetName)
    end)
    if success and result then
        Log(string.format("Found sheet: %s", sheetName))
    end
end

-- Test 3: Check raw player object properties
Log("--- Test 3: Raw Player Object Exploration ---")
local rawPlayer = Player
if rawPlayer then
    local props = {
        "Job",
        "ClassJob",
        "PhantomJob",
        "SubJob",
        "CurrentJob",
        "Level"
    }

    for _, prop in ipairs(props) do
        local val = TryGetProperty(rawPlayer, prop)
        if val ~= nil then
            Log(string.format("Player.%s = %s", prop, tostring(val)))
        end
    end
end

-- Test 4: Check status effects
Log("--- Test 4: Status Effects ---")
local statusCount = 0
for i = 0, 29 do
    local status = player.StatusList[i]
    if status and status.StatusId ~= 0 then
        statusCount = statusCount + 1
        Log(string.format("Status %d: ID=%d", i, status.StatusId))
    end
end
Log(string.format("Total active statuses: %d", statusCount))

-- Test 5: Territory and zone info
Log("--- Test 5: Territory Info ---")
local territoryId = Svc.ClientState.TerritoryType
Log(string.format("Territory ID: %d", territoryId))

-- Test 6: Character struct exploration (if accessible)
Log("--- Test 6: Character Struct ---")
local charBase = Svc.ClientState.LocalPlayer.Address
if charBase and charBase ~= 0 then
    Log(string.format("Character Address: 0x%X", charBase))
    -- Note: We can't safely read memory offsets without knowing the struct layout
    Log("(Memory reading requires known offsets - skipping)")
else
    Log("Character address not accessible")
end

Log("=== Phantom Job Detection Test Complete ===")
Log("Check the results above to identify phantom job data location")
Log("Expected: Look for PhantomJob-related properties or sheet data")
