---
name: SND Saucy Integration
description: Use this skill when implementing fishing automation in SND macros using the Saucy plugin. Covers fishing control, state management, and fishing patterns.
---

# Saucy Integration for SND

This skill covers integration with the Saucy plugin for fishing automation in SND macros.

## Prerequisites

```lua
-- Always check plugin availability first
if not HasPlugin("Saucy") then
    yield("/echo [Script] Saucy plugin not available")
    StopFlag = true
    return
end
```

## Complete API Reference

### Core Functions
```lua
-- Check if Saucy is running
IPC.Saucy.IsRunning() -> boolean

-- Start fishing
IPC.Saucy.StartFishing() -> nil

-- Stop fishing
IPC.Saucy.StopFishing() -> nil
```

## Helper Functions

### Saucy Status Checking
```lua
function IsSaucyRunning()
    return IPC.Saucy.IsRunning()
end

function GetSaucyStatus()
    if not HasPlugin("Saucy") then
        return "not_available"
    end

    if IPC.Saucy.IsRunning() then
        return "running"
    else
        return "idle"
    end
end
```

### Wait for Completion
```lua
function WaitForSaucyComplete(timeout)
    timeout = timeout or 300 -- 5 minutes default
    local startTime = os.clock()

    while IsSaucyRunning() and (os.clock() - startTime) < timeout do
        yield("/wait 1")
    end

    if IsSaucyRunning() then
        yield("/echo [Script] Saucy timeout, stopping")
        IPC.Saucy.StopFishing()
        return false
    end

    return true
end
```

## Fishing Patterns

### Basic Fishing
```lua
-- Check if Saucy is running
if IPC.Saucy.IsRunning() then
    yield("/echo [Script] Saucy is already running")
    -- Handle already running state
end

-- Start fishing
IPC.Saucy.StartFishing()

-- Wait for fishing to complete
while IPC.Saucy.IsRunning() do
    yield("/wait 1")
end
```

### Complete Fishing Workflow
```lua
function CompleteFishingWorkflow(timeout)
    timeout = timeout or 300

    -- Check prerequisites
    if not HasPlugin("Saucy") then
        yield("/echo [Script] ERROR: Saucy plugin not available")
        return false
    end

    if not Player.Available then
        yield("/echo [Script] ERROR: Player not available")
        return false
    end

    -- Check if already running
    if IsSaucyRunning() then
        yield("/echo [Script] Saucy is already running")
        return true
    end

    -- Start fishing
    yield("/echo [Script] Starting fishing")
    IPC.Saucy.StartFishing()

    -- Wait for completion
    if WaitForSaucyComplete(timeout) then
        yield("/echo [Script] Fishing completed successfully")
        return true
    else
        yield("/echo [Script] Fishing failed or timed out")
        return false
    end
end
```

### Fishing with Retry
```lua
function FishWithRetry(maxRetries, timeout)
    maxRetries = maxRetries or 3
    timeout = timeout or 300

    for attempt = 1, maxRetries do
        if CompleteFishingWorkflow(timeout) then
            return true
        end

        if attempt < maxRetries then
            yield("/echo [Script] Fishing attempt " .. attempt .. " failed, retrying")
            yield("/wait 5")
        end
    end

    yield("/echo [Script] Fishing failed after " .. maxRetries .. " attempts")
    return false
end
```

### Fishing with Inventory Check
```lua
function FishingWithInventoryCheck(timeout)
    -- Check inventory space before fishing
    if Inventory.GetFreeInventorySlots() <= 5 then
        yield("/echo [Script] Not enough inventory space for fishing")
        return false
    end

    -- Start fishing
    if not CompleteFishingWorkflow(timeout) then
        return false
    end

    -- Check inventory after fishing
    yield("/echo [Script] Fishing completed, inventory slots: " .. Inventory.GetFreeInventorySlots())
    return true
end
```

### Start and Stop Control
```lua
function StartFishing()
    if not HasPlugin("Saucy") then
        yield("/echo [Script] Saucy not available")
        return false
    end

    if not IsSaucyRunning() then
        IPC.Saucy.StartFishing()
        yield("/echo [Script] Fishing started")
        return true
    end

    yield("/echo [Script] Saucy is already running")
    return true
end

function StopFishing()
    if not HasPlugin("Saucy") then
        return false
    end

    if IsSaucyRunning() then
        IPC.Saucy.StopFishing()
        yield("/echo [Script] Fishing stopped")
        return true
    end

    return false
end
```

## Error Handling

### Safe Saucy Calls
```lua
function SafeSaucyCall(functionName, ...)
    if not HasPlugin("Saucy") then
        return nil, "Saucy plugin not available"
    end

    local success, result = pcall(function()
        return IPC.Saucy[functionName](...)
    end)

    if success then
        return result, nil
    else
        return nil, "Saucy call failed: " .. tostring(result)
    end
end
```

### Timeout Handling
```lua
local startTime = os.clock()
while IsSaucyRunning() and (os.clock() - startTime) < 300 do
    yield("/wait 1")
end

if IsSaucyRunning() then
    yield("/echo [Script] WARNING: Fishing taking too long, stopping...")
    IPC.Saucy.StopFishing()
end
```

## State Machine Integration

```lua
CharacterState = {
    ready = Ready,
    fishing = Fishing,
    -- ... other states
}

function Fishing()
    if CompleteFishingWorkflow(300) then
        yield("/echo [Script] Fishing completed")
        State = CharacterState.ready
    else
        yield("/echo [Script] Fishing failed")
        State = CharacterState.ready
    end
end
```

## Character Condition Integration

```lua
-- Check if character is busy (including Saucy)
function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Svc.Condition[CharacterCondition.beingMoved] or
           IsSaucyRunning() or
           Player.IsBusy
end
```

## Configuration Variables

```lua
configs:
  EnableSaucy:
    default: true
    description: Enable Saucy fishing
  FishingTimeout:
    default: 300
    description: Fishing timeout in seconds
  MaxFishingRetries:
    default: 3
    description: Maximum fishing retry attempts
  MinInventorySlots:
    default: 5
    description: Minimum free inventory slots required for fishing
```

## Best Practices

1. **Always check plugin availability** before using Saucy
2. **Use longer timeouts** for fishing operations (default: 300s / 5 minutes)
3. **Check fishing state** before starting new fishing
4. **Check inventory space** before starting fishing
5. **Use appropriate wait times**: 1s for fishing monitoring
6. **Stop fishing** on timeout to prevent stuck states
7. **Monitor inventory** during long fishing sessions
