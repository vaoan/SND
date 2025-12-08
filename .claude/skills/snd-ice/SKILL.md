---
name: SND Ice
description: Use this skill when implementing Cosmic Exploration automation in SND macros using the Ice plugin. Covers starting/stopping Ice, and integration with leveling workflows.
---

# Ice Plugin (Cosmic Exploration)

Ice is a plugin for automating Cosmic Exploration content in FFXIV. It handles the actual leveling/grinding process.

## Basic Commands

```lua
-- Start Ice automation
yield("/ice start")

-- Stop Ice automation
yield("/ice stop")
```

## Integration Pattern

Ice is typically used in combination with job switching and gear equipping:

```lua
-- Stop Ice before switching jobs (use multiple stops to ensure it registers)
yield("/ice stop")
yield("/wait 0.5")
yield("/ice stop")
yield("/wait 0.5")
yield("/ice stop")
yield("/wait 1")

-- Switch job (uiSlot = API index + 1!)
yield("/gearset change " .. uiSlot)
yield("/wait 1")

-- Equip recommended gear (AutoDuty)
yield("/ad equiprec")
yield("/wait 2")

-- Resume Ice automation
yield("/ice start")
```

## Typical Workflow

1. Stop Ice
2. Check job levels against breakpoints
3. Switch to job that needs leveling (if any)
4. Equip recommended gear
5. Start Ice again

## Plugin Dependencies

When using Ice, you typically also need:
- **AutoDuty** - For `/ad equiprec` (equip recommended gear)
- **ICE** - The internal plugin name is `ICE` (all caps) for plugin_dependencies

## Example: Job Switch with Ice

```lua
local function SwitchJobAndRestartIce(jobId)
    -- Stop current automation (multiple times to ensure it registers)
    yield("/ice stop")
    yield("/wait 0.5")
    yield("/ice stop")
    yield("/wait 0.5")
    yield("/ice stop")
    yield("/wait 1")

    -- Find and switch gearset
    for idx = 1, 100 do
        local gs = Player.GetGearset(idx)
        if gs and gs.ClassJob == jobId then
            -- IMPORTANT: UI slot = API index + 1!
            local uiSlot = idx + 1
            yield("/gearset change " .. uiSlot)
            yield("/wait 1")

            -- Equip recommended gear
            yield("/ad equiprec")
            yield("/wait 2")

            -- Resume automation
            yield("/ice start")
            return true
        end
    end
    return false
end
```

## Notes

- Always stop Ice before switching jobs to avoid issues
- **Use multiple `/ice stop` commands** to ensure Ice actually stops before switching
- **CRITICAL:** `Player.GetGearset(idx)` returns API index, but `/gearset change` uses UI slot numbers. Always use `idx + 1` for the gearset change command!
- Give adequate wait time between commands (1-2 seconds)
- Ice handles the actual Cosmic Exploration content automatically
- Use in combination with breakpoint-based leveling scripts
- Can't switch jobs during crafting, Mech Ops, or other duties - wait for them to complete first
