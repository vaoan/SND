---
name: SND Lifestream Integration
description: Use this skill when implementing teleportation, world travel, or instance management in SND macros using the Lifestream plugin. Covers aethernet teleportation, world changes, housing, and instance switching.
---

# Lifestream Integration for SND

This skill covers integration with the Lifestream plugin for teleportation and world travel in SND macros.

## Prerequisites

```lua
-- Always check plugin availability first
if not HasPlugin("Lifestream") then
    yield("/echo [Script] Lifestream plugin not available")
    StopFlag = true
    return
end
```

## Complete API Reference

### Core Functions
```lua
-- Execute a command
IPC.Lifestream.ExecuteCommand(string command) -> nil

-- Check if Lifestream is busy
IPC.Lifestream.IsBusy() -> boolean

-- Abort current operation
IPC.Lifestream.Abort() -> nil
```

### World Change Functions
```lua
-- Check if can visit same data center world
IPC.Lifestream.CanVisitSameDC(string world) -> boolean

-- Check if can visit cross data center world
IPC.Lifestream.CanVisitCrossDC(string world) -> boolean

-- Teleport and change world
IPC.Lifestream.TPAndChangeWorld() -> nil

-- Get world change aetheryte by territory type
IPC.Lifestream.GetWorldChangeAetheryteByTerritoryType() -> number?

-- Change world by name
IPC.Lifestream.ChangeWorld(string world) -> boolean

-- Change world by ID
IPC.Lifestream.ChangeWorldById(number worldId) -> boolean
```

### Aethernet Teleportation Functions
```lua
-- Teleport to aethernet destination
IPC.Lifestream.AethernetTeleport(string destination) -> boolean

-- Teleport by place name ID
IPC.Lifestream.AethernetTeleportByPlaceNameId(number placeNameId) -> boolean

-- Teleport by aethernet sheet row ID
IPC.Lifestream.AethernetTeleportById(number aethernetSheetRowId) -> boolean

-- Teleport to housing aethernet by sheet row ID
IPC.Lifestream.HousingAethernetTeleportById(number housingAethernetSheetRow) -> boolean

-- Teleport to the Firmament
IPC.Lifestream.AethernetTeleportToFirmament() -> boolean
```

### Active Aetheryte Information
```lua
-- Get active aetheryte ID
IPC.Lifestream.GetActiveAetheryte() -> number

-- Get active custom aetheryte ID
IPC.Lifestream.GetActiveCustomAetheryte() -> number

-- Get active residential aetheryte ID
IPC.Lifestream.GetActiveResidentialAetheryte() -> number
```

### General Teleportation Functions
```lua
-- Teleport to specific aetheryte with sub-index
IPC.Lifestream.Teleport(number aetheryteId, number subIndex) -> boolean

-- Teleport to Free Company house
IPC.Lifestream.TeleportToFC() -> boolean

-- Teleport to registered home point
IPC.Lifestream.TeleportToHome() -> boolean

-- Teleport to apartment
IPC.Lifestream.TeleportToApartment() -> boolean

-- Get plot entrance coordinates
IPC.Lifestream.GetPlotEntrance(number territory, number plot) -> Vector3?

-- Enter or exit apartment
IPC.Lifestream.EnterApartment(boolean enter) -> nil
```

### Shortcut and Instance Functions
```lua
-- Enqueue inn shortcut
IPC.Lifestream.EnqueueInnShortcut(number? innIndex) -> nil

-- Enqueue local inn shortcut
IPC.Lifestream.EnqueueLocalInnShortcut(number? innIndex) -> nil

-- Check if can change instance
IPC.Lifestream.CanChangeInstance() -> boolean

-- Get number of available instances
IPC.Lifestream.GetNumberOfInstances() -> number

-- Change to specified instance
IPC.Lifestream.ChangeInstance(number number) -> nil

-- Get current instance ID
IPC.Lifestream.GetCurrentInstance() -> number
```

### Housing and Workshop Functions
```lua
-- Check if player has apartment
IPC.Lifestream.HasApartment() -> boolean?

-- Check if player has private house
IPC.Lifestream.HasPrivateHouse() -> boolean?

-- Check if Free Company has house
IPC.Lifestream.HasFreeCompanyHouse() -> boolean?

-- Check if can move to workshop
IPC.Lifestream.CanMoveToWorkshop() -> boolean

-- Move to workshop
IPC.Lifestream.MoveToWorkshop() -> nil

-- Get real territory type ID
IPC.Lifestream.GetRealTerritoryType() -> number
```

## Helper Functions

### Lifestream Status
```lua
function IsLifestreamBusy()
    return IPC.Lifestream.IsBusy()
end

function WaitForLifestreamComplete(timeout)
    timeout = timeout or 30
    local startTime = os.clock()

    while IsLifestreamBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IsLifestreamBusy() then
        yield("/echo [Script] Lifestream timeout")
        return false
    end

    return true
end
```

## Teleportation Patterns

### Basic Teleportation
```lua
function TeleportToLocation(locationName, timeout)
    timeout = timeout or 30

    if not HasPlugin("Lifestream") then
        yield("/echo [Script] Lifestream not available")
        return false
    end

    if IPC.Lifestream.IsBusy() then
        yield("/echo [Script] Lifestream is busy, waiting...")
        local startTime = os.clock()
        while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < 10 do
            yield("/wait 1")
        end
    end

    IPC.Lifestream.ExecuteCommand(locationName)

    local startTime = os.clock()
    while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IPC.Lifestream.IsBusy() then
        yield("/echo [Script] Teleport timeout")
        return false
    end

    return true
end
```

### Aethernet Teleportation
```lua
function TeleportToAethernet(destination, timeout)
    timeout = timeout or 30

    if not HasPlugin("Lifestream") then
        yield("/echo [Script] Lifestream not available")
        return false
    end

    if IPC.Lifestream.IsBusy() then
        yield("/echo [Script] Lifestream is busy, waiting...")
        local startTime = os.clock()
        while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < 10 do
            yield("/wait 1")
        end
    end

    local success = IPC.Lifestream.AethernetTeleport(destination)
    if not success then
        yield("/echo [Script] Failed to teleport to: " .. destination)
        return false
    end

    local startTime = os.clock()
    while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IPC.Lifestream.IsBusy() then
        yield("/echo [Script] Aethernet teleport timeout")
        return false
    end

    yield("/echo [Script] Successfully teleported to: " .. destination)
    return true
end
```

### Teleportation with Retry
```lua
function TeleportWithRetry(locationName, maxRetries, timeout)
    maxRetries = maxRetries or 3
    timeout = timeout or 30

    for attempt = 1, maxRetries do
        if TeleportToLocation(locationName, timeout) then
            return true
        end

        if attempt < maxRetries then
            yield("/echo [Script] Teleportation attempt " .. attempt .. " failed, retrying")
            yield("/wait 2")
        end
    end

    yield("/echo [Script] Teleportation failed after " .. maxRetries .. " attempts")
    return false
end
```

## World Change Patterns

### Check World Availability
```lua
function CanVisitWorld(worldName)
    if not HasPlugin("Lifestream") then
        return false
    end

    return IPC.Lifestream.CanVisitSameDC(worldName) or IPC.Lifestream.CanVisitCrossDC(worldName)
end

function CanVisitSameDataCenter(worldName)
    if not HasPlugin("Lifestream") then
        return false
    end
    return IPC.Lifestream.CanVisitSameDC(worldName)
end

function CanVisitCrossDataCenter(worldName)
    if not HasPlugin("Lifestream") then
        return false
    end
    return IPC.Lifestream.CanVisitCrossDC(worldName)
end
```

### Change World
```lua
function ChangeWorldSafely(worldName, timeout)
    timeout = timeout or 30

    if not HasPlugin("Lifestream") then
        yield("/echo [Script] Lifestream not available")
        return false
    end

    if not CanVisitWorld(worldName) then
        yield("/echo [Script] Cannot visit world: " .. worldName)
        return false
    end

    local success = IPC.Lifestream.ChangeWorld(worldName)
    if not success then
        yield("/echo [Script] Failed to change world")
        return false
    end

    local startTime = os.clock()
    while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IPC.Lifestream.IsBusy() then
        yield("/echo [Script] World change timeout")
        return false
    end

    yield("/echo [Script] Successfully changed to world: " .. worldName)
    return true
end
```

## Instance Management

### Get Instance Info
```lua
function GetInstanceInfo()
    if not HasPlugin("Lifestream") then
        return nil
    end

    return {
        canChangeInstance = IPC.Lifestream.CanChangeInstance(),
        numberOfInstances = IPC.Lifestream.GetNumberOfInstances(),
        currentInstance = IPC.Lifestream.GetCurrentInstance()
    }
end
```

### Change Instance
```lua
function ChangeInstanceSafely(instanceNumber, timeout)
    timeout = timeout or 30

    if not HasPlugin("Lifestream") then
        yield("/echo [Script] Lifestream not available")
        return false
    end

    if not IPC.Lifestream.CanChangeInstance() then
        yield("/echo [Script] Cannot change instance")
        return false
    end

    local maxInstances = IPC.Lifestream.GetNumberOfInstances()
    if instanceNumber > maxInstances then
        yield("/echo [Script] Invalid instance number: " .. instanceNumber)
        return false
    end

    IPC.Lifestream.ChangeInstance(instanceNumber)

    local startTime = os.clock()
    while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    return not IPC.Lifestream.IsBusy()
end
```

## Housing Functions

### Get Housing Status
```lua
function GetHousingStatus()
    if not HasPlugin("Lifestream") then
        return nil
    end

    return {
        hasApartment = IPC.Lifestream.HasApartment(),
        hasPrivateHouse = IPC.Lifestream.HasPrivateHouse(),
        hasFreeCompanyHouse = IPC.Lifestream.HasFreeCompanyHouse()
    }
end
```

### Teleport to FC House
```lua
function TeleportToFreeCompanyHouse(timeout)
    timeout = timeout or 30

    if not HasPlugin("Lifestream") then
        yield("/echo [Script] Lifestream not available")
        return false
    end

    if not IPC.Lifestream.HasFreeCompanyHouse() then
        yield("/echo [Script] Free Company does not have a house")
        return false
    end

    local success = IPC.Lifestream.TeleportToFC()
    if not success then
        yield("/echo [Script] Failed to teleport to Free Company house")
        return false
    end

    local startTime = os.clock()
    while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    return not IPC.Lifestream.IsBusy()
end
```

### Move to Workshop
```lua
function MoveToWorkshopSafely(timeout)
    timeout = timeout or 30

    if not HasPlugin("Lifestream") then
        yield("/echo [Script] Lifestream not available")
        return false
    end

    if not IPC.Lifestream.CanMoveToWorkshop() then
        yield("/echo [Script] Cannot move to workshop")
        return false
    end

    IPC.Lifestream.MoveToWorkshop()

    local startTime = os.clock()
    while IPC.Lifestream.IsBusy() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    return not IPC.Lifestream.IsBusy()
end
```

## State Machine Integration

```lua
CharacterState = {
    ready = Ready,
    teleporting = Teleporting,
    -- ... other states
}

function Teleporting()
    if TeleportToLocation(targetLocation, 30) then
        yield("/echo [Script] Teleportation completed")
        State = CharacterState.ready
    else
        yield("/echo [Script] Teleportation failed")
        State = CharacterState.ready
    end
end
```

## Character Condition Integration

```lua
-- Check if character is busy (including Lifestream)
function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Svc.Condition[CharacterCondition.beingMoved] or
           IPC.Lifestream.IsBusy() or
           Player.IsBusy
end

-- Check between areas condition
if Svc.Condition[CharacterCondition.betweenAreas] then
    yield("/echo [Script] Character is teleporting")
    while Svc.Condition[CharacterCondition.betweenAreas] do
        yield("/wait 0.1")
    end
end
```

## Zone Verification

```lua
function TeleportWithZoneVerification(locationName, expectedZoneId, timeout)
    timeout = timeout or 30

    if not TeleportToLocation(locationName, timeout) then
        return false
    end

    local currentZoneId = Svc.ClientState.TerritoryType
    if currentZoneId == expectedZoneId then
        yield("/echo [Script] Successfully teleported to correct zone")
        return true
    else
        yield("/echo [Script] WARNING: Teleported to unexpected zone")
        return false
    end
end
```

## Configuration Variables

```lua
configs:
  EnableLifestream:
    default: true
    description: Enable Lifestream teleportation
  TeleportationTimeout:
    default: 30
    description: Teleportation timeout in seconds
  MaxTeleportationRetries:
    default: 3
    description: Maximum teleportation retry attempts
```

## Best Practices

1. **Always check plugin availability** before using Lifestream
2. **Use timeouts** for all teleportation operations (default: 30s)
3. **Check if Lifestream is busy** before starting new operations
4. **Verify zone changes** after teleportation when critical
5. **Use appropriate wait times**: 1s for teleportation monitoring
6. **Handle world visit restrictions** gracefully
7. **Check housing availability** before teleporting to housing
