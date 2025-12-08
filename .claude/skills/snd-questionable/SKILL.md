---
name: SND Questionable
description: Use this skill when implementing quest automation in SND macros using the Questionable plugin. Covers quest status checking, quest priority management, and integration with leveling workflows.
---

# Questionable Plugin (Quest Automation)

Questionable is a small quest helper plugin designed to automatically do your quests where possible.
It utilizes navmesh to automatically travel to all quest waypoints and attempts to complete all steps
along the way (excluding dungeons, single-player duties and combat).

**Not all quests are supported.**

## Required Plugins

- vnavmesh
- TextAdvance
- Lifestream

## Commands

```lua
-- Open the Questing window
yield("/qst")

-- Display simplified commands
yield("/qst help")

-- Display all available commands
yield("/qst help-all")

-- Open the configuration window
yield("/qst config")

-- Start doing quests
yield("/qst start")

-- Stop doing quests
yield("/qst stop")
```

## IPC Methods

Access via `IPC.Questionable.*` in SND:

### Status Checks

```lua
-- Check if Questionable is currently running
local isRunning = IPC.Questionable.IsRunning()

-- Get current quest ID being worked on
local questId = IPC.Questionable.GetCurrentQuestId()

-- Get data about the current step
local stepData = IPC.Questionable.GetCurrentStepData()
```

### Quest State Checks

```lua
-- Check if a quest is completed
local isDone = IPC.Questionable.IsQuestComplete("questId")

-- Check if a quest is accepted (in journal)
local isAccepted = IPC.Questionable.IsQuestAccepted("questId")

-- Check if ready to accept a quest
local canAccept = IPC.Questionable.IsReadyToAcceptQuest("questId")

-- Check if a quest is locked (requirements not met)
local isLocked = IPC.Questionable.IsQuestLocked("questId")

-- Check if a quest is unobtainable
local isUnobtainable = IPC.Questionable.IsQuestUnobtainable("questId")
```

### Quest Priority Management

```lua
-- Add a quest to priority list
IPC.Questionable.AddQuestPriority("questId")

-- Insert quest at specific position in priority list
IPC.Questionable.InsertQuestPriority(1, "questId")  -- position, questId

-- Clear all quest priorities
IPC.Questionable.ClearQuestPriority()

-- Export quest priority as string
local priorityData = IPC.Questionable.ExportQuestPriority()

-- Import quest priority from string
IPC.Questionable.ImportQuestPriority(priorityData)
```

## Example: Check if Quest is Done

```lua
local function IsQuestDone(questId)
    if not HasPlugin("Questionable") then
        return nil  -- Can't check without plugin
    end
    return IPC.Questionable.IsQuestComplete(questId)
end

-- Usage
if IsQuestDone("inscrutable-tastes-quest-id") then
    yield("/echo Quest already completed!")
else
    yield("/echo Quest not done yet - please complete it!")
end
```

## Example: Wait for Questionable to Finish

```lua
local function WaitForQuestionable(maxWaitSeconds)
    maxWaitSeconds = maxWaitSeconds or 300  -- 5 min default
    local startTime = os.clock()

    while IPC.Questionable.IsRunning() do
        if os.clock() - startTime > maxWaitSeconds then
            yield("/echo Timeout waiting for Questionable")
            return false
        end
        yield("/wait 1")
    end
    return true
end
```

## Known Quest IDs

| Quest Name | Quest ID | Notes |
|------------|----------|-------|
| Inscrutable Tastes | 67631 | Required at level 50 for collectables |

## Notes

- Quest IDs are strings, not numbers
- Always check `HasPlugin("Questionable")` before using IPC methods
- `IsQuestComplete()` is useful for checking prerequisites
- Priority system allows you to queue up quests to complete in order
- Does NOT handle: dungeons, single-player duties, combat
- Requires: vnavmesh, TextAdvance, Lifestream plugins
