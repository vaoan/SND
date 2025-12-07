# SND Macro Development Guidelines

This project contains SND (Something Need Doing) Lua macros for FFXIV automation using Dalamud plugins.

## Skills Documentation

Detailed documentation is organized into modular skills in `.claude/skills/`:

### Core Skills
| Skill | Description |
|-------|-------------|
| **snd-core** | Metadata structure, state machines, character conditions (102 entries), configuration system, WaitUntil patterns, Excel data access, core utilities |
| **snd-addons** | Game UI addon interactions, node access, SafeCallback, common dialog patterns |

### Plugin Integrations
| Skill | Description |
|-------|-------------|
| **snd-vnavmesh** | Navigation and movement using vnavmesh plugin |
| **snd-lifestream** | Teleportation, world travel, instance management using Lifestream plugin |
| **snd-artisan** | Crafting automation using Artisan plugin |
| **snd-saucy** | Fishing automation using Saucy plugin |
| **snd-autoretainer** | Retainer management using AutoRetainer plugin |
| **snd-combat** | Combat/rotation plugin integration (BossMod, RSR, Wrath) |
| **snd-textadvance** | Automatic dialog/cutscene advancement using TextAdvance plugin |

### Content Automation
| Skill | Description |
|-------|-------------|
| **snd-fates** | FATE farming patterns, targeting, level sync, participation loops |

---

## Quick Reference

### Metadata Header (Required)
```lua
--[=====[
[[SND Metadata]]
author: 'Your Name'
version: 1.0.0
description: Brief description
plugin_dependencies:
- PluginName
configs:
  Setting:
    default: "value"
    description: What it does
[[End Metadata]]
--]=====]
```

### State Machine Pattern
```lua
CharacterState = {
    ready = Ready,
    working = Working,
    error = Error
}

State = CharacterState.ready
while not StopFlag do
    if not IsCharacterBusy() then
        State()
    end
    yield("/wait 0.1")
end
```

### Character Conditions
```lua
local CharacterCondition = {
    craftingMode = 5,
    casting = 27,
    occupiedInQuestEvent = 32,
    executingCraftingSkill = 40,
    betweenAreas = 45,
    occupiedSummoningBell = 50,
    beingMoved = 70
}
```

### Core Functions
```lua
-- Plugin check
function HasPlugin(pluginName)
    for plugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        if plugin.InternalName == pluginName and plugin.IsLoaded then
            return true
        end
    end
    return false
end

-- Busy check
function IsCharacterBusy()
    return Svc.Condition[CharacterCondition.casting] or
           Svc.Condition[CharacterCondition.betweenAreas] or
           Svc.Condition[CharacterCondition.beingMoved] or
           Player.IsBusy
end

-- Config access
local value = Config.Get("SettingName")
local num = tonumber(Config.Get("NumericSetting"))
local bool = Config.Get("BooleanSetting") == "true"
```

### Plugin APIs (Quick Reference)

**vnavmesh** (see `snd-vnavmesh` skill):
```lua
IPC.vnavmesh.IsReady()
IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), fly)
IPC.vnavmesh.IsRunning()
IPC.vnavmesh.Stop()
```

**Lifestream** (see `snd-lifestream` skill):
```lua
IPC.Lifestream.ExecuteCommand(location)
IPC.Lifestream.IsBusy()
IPC.Lifestream.AethernetTeleport(destination)
IPC.Lifestream.ChangeInstance(number)
```

**Artisan** (see `snd-artisan` skill):
```lua
IPC.Artisan.IsListRunning()
IPC.Artisan.IsListPaused()
IPC.Artisan.CraftItem(recipeId, quantity)
IPC.Artisan.StopList()
```

**Saucy** (see `snd-saucy` skill):
```lua
IPC.Saucy.IsRunning()
IPC.Saucy.StartFishing()
IPC.Saucy.StopFishing()
```

**AutoRetainer** (see `snd-autoretainer` skill):
```lua
-- CRITICAL: Always use Svc.ClientState.LocalContentId, NOT Player.CID
local charId = Svc.ClientState.LocalContentId
local data = IPC.AutoRetainer.GetOfflineCharacterData(charId)
```

**Combat Plugins** (see `snd-combat` skill):
```lua
-- BossMod
yield("/bmai on")   -- Enable AI
yield("/bmai off")  -- Disable AI

-- RSR (RotationSolver Reborn)
yield("/rotation auto")    -- Enable
yield("/rotation cancel")  -- Disable

-- Wrath
yield("/wrath on")   -- Enable
yield("/wrath off")  -- Disable
```

**TextAdvance** (see `snd-textadvance` skill):
```lua
yield("/at e")      -- Enable auto-advance
yield("/at d")      -- Disable
yield("/at cs on")  -- Enable cutscene skip
yield("/at qa on")  -- Enable auto-accept quests
```

### Best Practices

1. Always check `HasPlugin()` before using plugin APIs
2. Use timeouts for all waiting operations
3. Check `Player.Available` before player operations
4. Use `pcall()` for risky operations
5. Prefix error messages with `[Script]`
6. Use semantic versioning (MAJOR.MINOR.PATCH)

---

## Skill Locations

For complete documentation, see the individual skill files:

```
.claude/skills/
├── snd-core/SKILL.md         # Core patterns, conditions, utilities
├── snd-addons/SKILL.md       # UI addons, node access, dialogs
├── snd-vnavmesh/SKILL.md     # Navigation
├── snd-lifestream/SKILL.md   # Teleportation
├── snd-artisan/SKILL.md      # Crafting
├── snd-saucy/SKILL.md        # Fishing
├── snd-autoretainer/SKILL.md # Retainers
├── snd-combat/SKILL.md       # Combat plugins
├── snd-textadvance/SKILL.md  # Dialog automation
└── snd-fates/SKILL.md        # FATE farming
```
