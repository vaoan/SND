# SND Script Architecture Rules

These rules define the mandatory architecture and design patterns for all SND Lua macros.

## Rule 1: State Machine Architecture (MANDATORY)

Every script MUST use a state machine pattern for control flow. No exceptions.

### Required Structure

```lua
-- Define all states upfront
CharacterState = {
    ready = Ready,
    working = Working,
    error = Error,
    -- ... other states as needed
}

-- State functions
function Ready()
    -- State logic here
    if shouldWork then
        State = CharacterState.working
    end
end

function Working()
    -- State logic here
    if workDone then
        State = CharacterState.ready
    elseif errorOccurred then
        State = CharacterState.error
    end
end

function Error()
    yield("/echo [Script] ERROR: " .. errorMessage)
    -- Recovery or stop
    StopFlag = true
end

-- Main execution loop (REQUIRED)
State = CharacterState.ready
while not StopFlag do
    if not IsCharacterBusy() then
        State()
    end
    yield("/wait 0.1")
end
```

### State Machine Requirements

1. **All states must be functions** - No inline logic in the main loop
2. **State transitions are explicit** - Always assign `State = CharacterState.newState`
3. **One state active at a time** - Never call multiple state functions
4. **Main loop only calls State()** - Logic lives in state functions
5. **Include error/recovery states** - Handle failures gracefully

### Prohibited Patterns

```lua
-- ❌ BAD: Linear/procedural flow
function Main()
    DoStep1()
    DoStep2()
    DoStep3()
end

-- ❌ BAD: Complex conditionals in main loop
while not StopFlag do
    if condition1 then
        -- lots of code
    elseif condition2 then
        -- lots of code
    end
end

-- ❌ BAD: Nested state management
if state == "working" then
    if substate == "substep1" then
        -- ...
    end
end
```

### Correct Patterns

```lua
-- ✓ GOOD: Clear state machine
CharacterState = {
    init = Init,
    step1 = Step1,
    step2 = Step2,
    step3 = Step3,
    done = Done,
}

function Init()
    -- Setup
    State = CharacterState.step1
end

function Step1()
    -- Do step 1
    if step1Complete then
        State = CharacterState.step2
    end
end

-- ... etc
```

---

## Rule 2: DRY (Don't Repeat Yourself)

Every script must maximize code reuse and minimize duplication.

### Requirements

1. **Extract repeated logic into functions** - If code appears twice, make it a function
2. **Use configuration tables** - Don't hardcode values that vary
3. **Create helper functions** - For common operations (distance, targeting, waiting)
4. **Use loops for similar operations** - Don't copy-paste with minor variations

### Examples

```lua
-- ❌ BAD: Repeated code
if Svc.ClientState.TerritoryType == 129 then
    TeleportTo("Limsa Lominsa")
end
if Svc.ClientState.TerritoryType == 130 then
    TeleportTo("Ul'dah")
end
if Svc.ClientState.TerritoryType == 132 then
    TeleportTo("Gridania")
end

-- ✓ GOOD: Data-driven approach
local CityAetherytes = {
    [129] = "Limsa Lominsa",
    [130] = "Ul'dah",
    [132] = "Gridania",
}

local aetheryte = CityAetherytes[Svc.ClientState.TerritoryType]
if aetheryte then
    TeleportTo(aetheryte)
end
```

```lua
-- ❌ BAD: Repeated wait patterns
while Svc.Condition[CharacterCondition.casting] do
    yield("/wait 0.5")
end
-- ... later in code ...
while Svc.Condition[CharacterCondition.casting] do
    yield("/wait 0.5")
end

-- ✓ GOOD: Reusable function
function WaitForNotCasting(timeout)
    timeout = timeout or 30
    local start = os.clock()
    while Svc.Condition[CharacterCondition.casting] and (os.clock() - start) < timeout do
        yield("/wait 0.5")
    end
    return not Svc.Condition[CharacterCondition.casting]
end
```

### Helper Function Categories

Every script should define these categories of helpers as needed:

1. **Condition Helpers** - `IsCharacterBusy()`, `IsMounted()`, `IsInCombat()`
2. **Wait Helpers** - `WaitUntil()`, `WaitForAddon()`, `WaitForCondition()`
3. **Distance Helpers** - `GetDistanceToPoint()`, `IsWithinDistance()`
4. **Targeting Helpers** - `TargetByName()`, `InteractWithTarget()`
5. **Movement Helpers** - `MoveToPosition()`, `StopMovement()`

---

## Rule 3: Self-Contained Scripts

Every script file MUST be completely self-contained. No external dependencies on other script files.

### Requirements

1. **No imports from other scripts** - Each file stands alone
2. **No `/snd run` to helper scripts** - All logic in one file
3. **Include all needed helper functions** - Copy them into the script
4. **No shared global state** - Scripts don't communicate with each other

### What This Means

```lua
-- ❌ BAD: Referencing external scripts
yield("/snd run HelperFunctions")
yield("/snd run CommonUtilities")
require("shared/utils")  -- Not supported anyway

-- ❌ BAD: Assuming globals from other scripts
if SharedConfig.setting then  -- Where did this come from?
    -- ...
end

-- ✓ GOOD: Everything defined in this file
-- All helper functions defined here
function HasPlugin(name)
    for plugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        if plugin.InternalName == name and plugin.IsLoaded then
            return true
        end
    end
    return false
end

function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Player.IsBusy
end

-- Script-specific logic uses these local functions
```

### Script Structure Template

Every script should follow this structure:

```lua
--[=====[
[[SND Metadata]]
author: 'Name'
version: 1.0.0
description: What this script does
plugin_dependencies:
- RequiredPlugin
configs:
  Setting:
    default: "value"
    description: What it does
[[End Metadata]]
--]=====]

-------------------------------------------------
-- CONSTANTS
-------------------------------------------------
local CharacterCondition = {
    casting = 27,
    betweenAreas = 45,
    -- ... needed conditions
}

-------------------------------------------------
-- HELPER FUNCTIONS (self-contained)
-------------------------------------------------
function HasPlugin(name)
    -- implementation
end

function IsCharacterBusy()
    -- implementation
end

function WaitUntil(condition, timeout)
    -- implementation
end

-- ... other helpers this script needs

-------------------------------------------------
-- STATE MACHINE
-------------------------------------------------
CharacterState = {
    ready = Ready,
    -- ... states
}

function Ready()
    -- implementation
end

-- ... state functions

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------
State = CharacterState.ready
while not StopFlag do
    if not IsCharacterBusy() then
        State()
    end
    yield("/wait 0.1")
end
```

---

## Summary Checklist

Before finalizing any script, verify:

- [ ] Uses state machine architecture with explicit state functions
- [ ] Main loop only calls `State()` function
- [ ] All repeated code extracted into helper functions
- [ ] Configuration values in tables, not hardcoded
- [ ] All helper functions defined within the file
- [ ] No references to external scripts
- [ ] No assumptions about global state from other sources
- [ ] Error/recovery states included
- [ ] Timeouts on all waiting operations
