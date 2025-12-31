# SND Stylist Plugin Skill

> **Source:** https://github.com/NightmareXIV/MyDalamudPlugins/raw/main/pluginmaster.json
> **Plugin Name:** Stylist by NightmareXIV
> **Purpose:** Automatic gear management and upgrades for gearsets

## Description

Use this skill when implementing automatic gear upgrades in SND macros using the Stylist plugin. Stylist watches your gearsets and automatically upgrades them with better gear from your inventory.

## Plugin Repository

```
https://github.com/NightmareXIV/MyDalamudPlugins/raw/main/pluginmaster.json
```

Add this URL to Dalamud Settings > Experimental > Custom Plugin Repositories, then install "Stylist" from the Plugin Installer.

## Chat Commands

### Gear Update Commands

```lua
-- Update all crafter (DoH) gearsets with best available gear
yield("/stylist crafter")

-- Update all gatherer (DoL) gearsets with best available gear
yield("/stylist gatherer")

-- Update ALL gearsets (combat jobs + crafters + gatherers)
yield("/stylist all")

-- Update specific role gearsets
yield("/stylist tank")      -- All tank jobs
yield("/stylist healer")    -- All healer jobs
yield("/stylist dps")       -- All DPS jobs
yield("/stylist melee")     -- Melee DPS only
yield("/stylist ranged")    -- Physical ranged DPS only
yield("/stylist caster")    -- Magical ranged DPS only
```

### UI Commands

```lua
-- Open Stylist UI (does NOT update gear, just opens the window)
yield("/stylist")
```

## Required Settings

For SND automation, configure these settings in Stylist UI (`/stylist` > Settings tab):

```
✓ Consider gear from inventory
✓ Move replaced items from armory chest to regular inventory
✓ Re-equip current gearset if it was updated
```

**Why these settings matter:**
- **Consider gear from inventory**: Allows Stylist to check your regular inventory for better gear, not just armory chest
- **Move replaced items to regular inventory**: Keeps armory chest clean by moving old gear out automatically
- **Re-equip current gearset if it was updated**: Automatically re-equips your gearset after upgrade (important for SND automation)

## Usage in SND Macros

### Basic Pattern - Update Current Job Category

```lua
-- Determine which command to use based on current job
local currentJobId = Svc.ClientState.LocalPlayer.ClassJob.RowId

-- Job IDs: 8-15 = Crafters (DoH), 16-18 = Gatherers (DoL)
local isCrafter = (currentJobId >= 8 and currentJobId <= 15)
local stylistCmd = isCrafter and "/stylist crafter" or "/stylist gatherer"

yield("/echo Updating gear...")
yield(stylistCmd)
yield("/wait 2")  -- Wait for Stylist to process
```

### Update Specific Role Based on Job Object

```lua
-- If you have a job object with an ID field
local function UpdateGearForJob(job)
    -- Determine command based on job.id
    local stylistCmd
    if job.id >= 8 and job.id <= 15 then
        stylistCmd = "/stylist crafter"
    elseif job.id >= 16 and job.id <= 18 then
        stylistCmd = "/stylist gatherer"
    else
        -- Combat job - could use specific role or just update all
        stylistCmd = "/stylist all"
    end

    yield("/echo [Script] Updating gear for " .. job.abbr .. "...")
    yield(stylistCmd)
    yield("/wait 2")
end
```

### Update All DoH/DoL Gear at Once

```lua
-- Update all crafter gearsets
yield("/echo Updating all crafter gearsets...")
yield("/stylist crafter")
yield("/wait 2")

-- Update all gatherer gearsets
yield("/echo Updating all gatherer gearsets...")
yield("/stylist gatherer")
yield("/wait 2")
```

## Common Patterns

### Job Switching with Gear Update

```lua
-- Switch to a job and update its gear
local function SwitchJobAndUpdateGear(jobId, gearsetSlot)
    -- Switch gearset
    yield("/gearset change " .. gearsetSlot)
    yield("/wait 1")

    -- Verify switch
    local lp = Svc.ClientState.LocalPlayer
    if lp and lp.ClassJob.RowId == jobId then
        -- Determine stylist command
        local stylistCmd
        if jobId >= 8 and jobId <= 15 then
            stylistCmd = "/stylist crafter"
        elseif jobId >= 16 and jobId <= 18 then
            stylistCmd = "/stylist gatherer"
        else
            stylistCmd = "/stylist all"
        end

        -- Update gear
        yield(stylistCmd)
        yield("/wait 2")
        return true
    end
    return false
end
```

### Conditional Gear Updates

```lua
-- Only update gear at specific level breakpoints
local function UpdateGearAtBreakpoint(currentLevel, breakpoints)
    for _, bp in ipairs(breakpoints) do
        if currentLevel == bp then
            yield("/echo Reached breakpoint level " .. currentLevel .. " - updating gear...")

            -- Determine command based on current job
            local jobId = Svc.ClientState.LocalPlayer.ClassJob.RowId
            local stylistCmd
            if jobId >= 8 and jobId <= 15 then
                stylistCmd = "/stylist crafter"
            elseif jobId >= 16 and jobId <= 18 then
                stylistCmd = "/stylist gatherer"
            else
                stylistCmd = "/stylist all"
            end

            yield(stylistCmd)
            yield("/wait 2")
            return true
        end
    end
    return false
end

-- Usage
local breakpoints = {50, 60, 70, 80, 90}
UpdateGearAtBreakpoint(currentLevel, breakpoints)
```

## Job ID Reference

For determining which Stylist command to use:

```lua
-- Disciples of War/Magic (Combat Jobs): 1-7, 19+
-- Disciples of Hand (Crafters): 8-15
-- Disciples of Land (Gatherers): 16-18

local function GetStylistCommand(jobId)
    if jobId >= 8 and jobId <= 15 then
        return "/stylist crafter"  -- DoH
    elseif jobId >= 16 and jobId <= 18 then
        return "/stylist gatherer"  -- DoL
    else
        return "/stylist all"  -- DoW/DoM or unknown
    end
end
```

## Important Notes

### Command Behavior
- **`/stylist` alone** only opens the UI - it does NOT update gear
- **`/stylist crafter/gatherer/all`** actually performs gear updates
- Always use the role-specific commands for automation

### Wait Times
- Always add a `yield("/wait 2")` after Stylist commands to allow processing
- Stylist updates multiple gearsets when using `/stylist crafter` or `/stylist gatherer`
- Longer wait times may be needed if updating many gearsets at once

### Settings Persistence
- Stylist settings are persistent across game sessions
- Set them up once, they apply to all characters on the account
- Check settings before running automation to ensure proper behavior

### Inventory Management
- With "Move replaced items to regular inventory" enabled, old gear automatically moves out of armory chest
- This prevents armory chest from filling up during extended automation
- Periodically clean out regular inventory to avoid it filling up

## Example: Complete Leveling Script Pattern

```lua
-- Example: Auto-update gear when switching jobs during leveling
local function CheckAndSwitchJob(targetJobId)
    local currentJobId = Svc.ClientState.LocalPlayer.ClassJob.RowId

    if currentJobId ~= targetJobId then
        -- Find and switch to target job's gearset
        local gearsetSlot = FindGearsetForJob(targetJobId)  -- Your implementation

        if gearsetSlot then
            yield("/echo Switching to job " .. targetJobId .. "...")
            yield("/gearset change " .. gearsetSlot)
            yield("/wait 1")

            -- Update gear for the new job
            local stylistCmd = GetStylistCommand(targetJobId)
            yield("/echo Updating gear...")
            yield(stylistCmd)
            yield("/wait 2")

            return true
        end
    else
        -- Already on target job, just update gear
        local stylistCmd = GetStylistCommand(currentJobId)
        yield("/echo Updating current job gear...")
        yield(stylistCmd)
        yield("/wait 2")
        return true
    end

    return false
end
```

## Troubleshooting

### Gear Not Updating
1. Check Stylist settings are enabled (see Required Settings above)
2. Ensure you're using `/stylist crafter` not just `/stylist`
3. Verify you have better gear in inventory
4. Check that gearsets are properly configured

### Armory Chest Filling Up
- Enable "Move replaced items from armory chest to regular inventory"
- Manually clean out regular inventory periodically
- Consider using a separate inventory management script

### Gear Not Re-equipping
- Enable "Re-equip current gearset if it was updated"
- This setting is crucial for automation to work seamlessly

## Migrating from AutoDuty

If you were previously using AutoDuty's `/ad equiprec`:

```lua
-- OLD (AutoDuty)
yield("/ad equiprec")

-- NEW (Stylist) - More specific
local jobId = Svc.ClientState.LocalPlayer.ClassJob.RowId
local stylistCmd = GetStylistCommand(jobId)
yield(stylistCmd)
```

**Advantages of Stylist:**
- More granular control (crafter vs gatherer vs combat)
- Better inventory management (automatic armory chest cleanup)
- More reliable gear detection from inventory
- Automatic re-equipping after updates
