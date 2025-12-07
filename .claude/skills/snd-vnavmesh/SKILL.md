---
name: SND vnavmesh Integration
description: Use this skill when implementing navigation or movement in SND macros using the vnavmesh plugin. Covers pathfinding, movement control, navmesh utilities, and movement patterns.
---

# vnavmesh Integration for SND

This skill covers integration with the vnavmesh plugin for navigation and movement in SND macros.

## Prerequisites

```lua
-- Always check plugin availability first
if not HasPlugin("vnavmesh") then
    yield("/echo [Script] vnavmesh plugin not available")
    StopFlag = true
    return
end

-- Check if vnavmesh is ready
if not IPC.vnavmesh.IsReady() then
    yield("/echo [Script] vnavmesh is not ready")
    StopFlag = true
    return
end
```

## Complete API Reference

### Status and Management Functions
```lua
-- Check if vnavmesh is ready
IPC.vnavmesh.IsReady()

-- Get build progress (0.0 to 1.0)
IPC.vnavmesh.BuildProgress()

-- Reload vnavmesh
IPC.vnavmesh.Reload()

-- Rebuild vnavmesh
IPC.vnavmesh.Rebuild()
```

### Pathfinding Functions
```lua
-- Pathfind from one point to another
IPC.vnavmesh.Pathfind(from, to, fly)

-- Pathfind and move to destination
IPC.vnavmesh.PathfindAndMoveTo(dest, fly)

-- Check if pathfinding is in progress
IPC.vnavmesh.PathfindInProgress()
```

### Movement Functions
```lua
-- Move to position with waypoints
IPC.vnavmesh.MoveTo(waypoints, fly)

-- Stop current movement
IPC.vnavmesh.Stop()

-- Check if movement is running
IPC.vnavmesh.IsRunning()
```

### Utility Functions
```lua
-- Get nearest point on navmesh
IPC.vnavmesh.NearestPoint(p, halfExtentXZ, halfExtentY)

-- Get point on floor
IPC.vnavmesh.PointOnFloor(p, allowUnlandable, halfExtentXZ)
```

## Helper Functions

### vnavmesh Status Checking
```lua
function IsVnavmeshReady()
    return HasPlugin("vnavmesh") and IPC.vnavmesh.IsReady()
end

function IsVnavmeshRunning()
    return IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()
end

function GetVnavmeshBuildProgress()
    if not IsVnavmeshReady() then
        return 0.0
    end
    return IPC.vnavmesh.BuildProgress()
end
```

### Reload and Rebuild
```lua
function ReloadVnavmesh()
    if not HasPlugin("vnavmesh") then
        yield("/echo [Script] vnavmesh plugin not available")
        return false
    end

    IPC.vnavmesh.Reload()
    yield("/echo [Script] vnavmesh reloaded")
    return true
end

function RebuildVnavmesh()
    if not HasPlugin("vnavmesh") then
        yield("/echo [Script] vnavmesh plugin not available")
        return false
    end

    IPC.vnavmesh.Rebuild()
    yield("/echo [Script] vnavmesh rebuild started")
    return true
end
```

### Safe VNAV Calls (with pcall)

```lua
--- Safely call vnavmesh methods with error handling
-- @param method function - The vnavmesh method to call
-- @param ... any - Arguments to pass
-- @return boolean, any - Success status and result/nil
local function _safe_vnav(method, ...)
    local ok, res = pcall(method, ...)
    if not ok then
        Log("VNAV error: %s", tostring(res))
        return false, nil
    end
    return true, res
end

--- Wait for vnavmesh to be ready with timeout
-- @param timeout number - Maximum wait time (default: TIME.TIMEOUT)
-- @return boolean - True if ready
function WaitVnavReady(timeout)
    return WaitUntil(function()
        local ok, res = _safe_vnav(IPC.vnavmesh.IsReady)
        return ok and res
    end, timeout or TIME.TIMEOUT, TIME.POLL, 0.0)
end

--- Start pathfinding with safety checks
-- @param dest Vector3 - Destination position
-- @param fly boolean - Whether to fly (default: false)
-- @return boolean - True if pathfinding started
function PathandMoveVnav(dest, fly)
    fly = (fly == true)

    if not WaitVnavReady(TIME.TIMEOUT) then
        Log("VNAV not ready (timeout)")
        return false
    end

    local okMove, moveRes = _safe_vnav(IPC.vnavmesh.PathfindAndMoveTo, dest, fly)
    if not okMove or not moveRes then
        Log("VNAV pathfind failed")
        return false
    end
    return true
end

--- Stop when close to destination
-- @param dest Vector3 - Destination position
-- @param stopDistance number - Distance to stop at (default: 3.0)
-- @return boolean - True if stopped successfully
function StopCloseVnav(dest, stopDistance)
    if not (dest and dest.X and dest.Y and dest.Z) then
        Log("StopCloseVnav: invalid destination")
        return false
    end
    stopDistance = toNumberSafe(stopDistance, 3.0, 0.01)

    -- Wait for movement to start
    local okRun = WaitUntil(function()
        local ok, res = _safe_vnav(IPC.vnavmesh.IsRunning)
        return ok and res
    end, TIME.TIMEOUT, TIME.POLL, 0.0)

    if not okRun then
        Log("VNAV not running (timeout)")
        return false
    end

    -- Monitor until close enough or stopped
    while true do
        local okRunLoop, running = _safe_vnav(IPC.vnavmesh.IsRunning)
        if not okRunLoop then return false end
        if not running then return true end

        local pos = Entity and Entity.Player and Entity.Player.Position
        if pos and IsWithinDistance(pos, dest, stopDistance) then
            _safe_vnav(IPC.vnavmesh.Stop)
            return true
        end
        Sleep(TIME.POLL)
    end
end

--- Move near a destination and stop at specified distance
-- @param dest Vector3 - Destination position
-- @param stopDistance number - Distance to stop at (default: 3.0)
-- @param fly boolean - Whether to fly (default: false)
-- @return boolean - True if successfully reached near destination
function MoveNearVnav(dest, stopDistance, fly)
    stopDistance = toNumberSafe(stopDistance, 3.0, 0.01)
    if not PathandMoveVnav(dest, fly) then return false end
    return StopCloseVnav(dest, stopDistance) == true
end
```

## Movement Patterns

### Basic Movement
```lua
-- Move to position
if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
    IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), false)
end

-- Wait for movement completion
while IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress() do
    yield("/wait 1")
end

-- Stop movement if needed
IPC.vnavmesh.Stop()
```

### Movement with Timeout
```lua
function MoveToPositionWithTimeout(x, y, z, timeout)
    timeout = timeout or 30

    if not HasPlugin("vnavmesh") then
        yield("/echo [Script] vnavmesh not available")
        return false
    end

    if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
        IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), false)
    end

    local startTime = os.clock()
    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) and
          (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IPC.vnavmesh.IsRunning() then
        yield("/echo [Script] Movement timeout, stopping")
        IPC.vnavmesh.Stop()
        return false
    end

    return true
end
```

### Movement Near Position (With Tolerance)
```lua
function MoveNearPosition(x, y, z, tolerance, timeout)
    tolerance = tolerance or 3.0
    timeout = timeout or 30

    if IsAtPosition(x, y, z, tolerance) then
        return true
    end

    return MoveToPositionWithTimeout(x, y, z, timeout)
end

function IsAtPosition(targetX, targetY, targetZ, tolerance)
    tolerance = tolerance or 2.0
    local playerPos = Player.Position
    local dx = targetX - playerPos.X
    local dy = targetY - playerPos.Y
    local dz = targetZ - playerPos.Z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return distance <= tolerance
end
```

### Movement with Retry
```lua
function MoveWithRetry(x, y, z, maxRetries)
    maxRetries = maxRetries or 3

    for attempt = 1, maxRetries do
        if MoveToPositionWithTimeout(x, y, z, 30) then
            return true
        end

        if attempt < maxRetries then
            yield("/echo [Script] Movement attempt " .. attempt .. " failed, retrying")
            yield("/wait 2")
        end
    end

    yield("/echo [Script] Movement failed after " .. maxRetries .. " attempts")
    return false
end
```

### Wait for vnavmesh Stop
```lua
function WaitForVnavmeshStop(timeout)
    timeout = timeout or 30
    local startTime = os.clock()

    while IsVnavmeshRunning() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IsVnavmeshRunning() then
        yield("/echo [Script] vnavmesh timeout, forcing stop")
        IPC.vnavmesh.Stop()
        return false
    end

    return true
end
```

## Advanced Patterns

### Safe Movement Function
```lua
function SafeMoveToPosition(x, y, z, timeout)
    timeout = timeout or 30

    -- Check prerequisites
    if not HasPlugin("vnavmesh") then
        yield("/echo [Script] ERROR: vnavmesh plugin not available")
        return false
    end

    if not Player.Available then
        yield("/echo [Script] ERROR: Player not available")
        return false
    end

    -- Check if already at destination
    if IsAtPosition(x, y, z, 2.0) then
        yield("/echo [Script] Already at destination")
        return true
    end

    -- Start movement
    if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
        IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), false)
    end

    -- Wait for completion with timeout
    local startTime = os.clock()
    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) and
          (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    -- Handle timeout
    if IPC.vnavmesh.IsRunning() then
        yield("/echo [Script] WARNING: Movement timeout, stopping")
        IPC.vnavmesh.Stop()
        return false
    end

    -- Verify arrival
    if IsAtPosition(x, y, z, 3.0) then
        yield("/echo [Script] Movement completed successfully")
        return true
    else
        yield("/echo [Script] WARNING: Movement completed but not at exact destination")
        return true -- Still consider success if close enough
    end
end
```

### Smart Movement with Navmesh Validation
```lua
function SmartMoveToPosition(x, y, z, fly)
    fly = fly or false

    if not IsVnavmeshReady() then
        yield("/echo [Script] vnavmesh not ready")
        return false
    end

    -- Get nearest point on navmesh
    local nearestPoint = IPC.vnavmesh.NearestPoint(Vector3(x, y, z), 2.0, 2.0)
    if nearestPoint then
        yield("/echo [Script] Moving to nearest navmesh point")
        IPC.vnavmesh.PathfindAndMoveTo(nearestPoint, fly)
    else
        yield("/echo [Script] No navmesh point found, trying direct movement")
        IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), fly)
    end

    return true
end
```

### Floor-based Movement
```lua
function MoveToFloorPosition(x, y, z, fly)
    fly = fly or false

    if not IsVnavmeshReady() then
        yield("/echo [Script] vnavmesh not ready")
        return false
    end

    local floorPoint = IPC.vnavmesh.PointOnFloor(Vector3(x, y, z), false, 1.0)
    if floorPoint then
        yield("/echo [Script] Moving to floor position")
        IPC.vnavmesh.PathfindAndMoveTo(floorPoint, fly)
        return true
    else
        yield("/echo [Script] No floor point found")
        return false
    end
end
```

### Build Progress Monitoring
```lua
function MonitorVnavmeshBuild()
    if not HasPlugin("vnavmesh") then
        yield("/echo [Script] vnavmesh plugin not available")
        return false
    end

    if not IPC.vnavmesh.IsReady() then
        local progress = GetVnavmeshBuildProgress()
        yield("/echo [Script] vnavmesh building... " .. math.floor(progress * 100) .. "%")

        while not IPC.vnavmesh.IsReady() do
            progress = GetVnavmeshBuildProgress()
            yield("/echo [Script] Build progress: " .. math.floor(progress * 100) .. "%")
            yield("/wait 2")
        end

        yield("/echo [Script] vnavmesh build completed")
    end

    return true
end
```

## State Machine Integration

```lua
CharacterState = {
    ready = Ready,
    moving = Moving,
    -- ... other states
}

function Moving()
    if MoveToPositionWithTimeout(targetX, targetY, targetZ, 30) then
        yield("/echo [Script] Movement completed")
        State = CharacterState.ready
    else
        yield("/echo [Script] Movement failed")
        State = CharacterState.ready
    end
end
```

## Character Condition Integration

```lua
-- Check if character is busy (including vnavmesh)
function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Svc.Condition[CharacterCondition.beingMoved] or
           IPC.vnavmesh.IsRunning() or
           Player.IsBusy
end
```

## Configuration Variables

```lua
configs:
  EnableVnavmesh:
    default: true
    description: Enable vnavmesh navigation
  MovementTimeout:
    default: 30
    description: Movement timeout in seconds
  MovementTolerance:
    default: 3.0
    description: Movement tolerance distance
```

## Best Practices

1. **Always check plugin availability** before using vnavmesh
2. **Use timeouts** for all movement operations (default: 30s)
3. **Check movement state** before starting new movement
4. **Verify arrival** at destination after movement completes
5. **Use appropriate wait times**: 1s for movement checking
6. **Handle vnavmesh not ready** state gracefully
7. **Stop movement** on timeout to prevent stuck states
