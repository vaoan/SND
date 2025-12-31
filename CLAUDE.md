# SND Macro Development Guidelines

This project contains SND (Something Need Doing) Lua macros for FFXIV automation using Dalamud plugins.

## Development Rules

### Rule #1: Update Skills on Discovery
**Whenever we discover something new about the SND API, fix a bug, or learn the correct way to do something, IMMEDIATELY update the relevant skill documentation in `.claude/skills/`.**

This includes:
- API corrections (e.g., `Player.Level` returns nil, use `Svc.ClientState.LocalPlayer.Level`)
- New patterns that work
- Gotchas and pitfalls to avoid
- Working code examples from testing

The skills are our living documentation - keep them accurate!

### Rule #2: Update Documentation Before Push
**Whenever you change functionality in a script, you MUST update the script's documentation (the comment block at the top) before pushing to SND.**

This includes:
- Version number bump (MAJOR.MINOR.PATCH)
- Description updates if behavior changed
- HOW IT WORKS section if flow changed
- Any new features or changed behavior documented

Never push functional changes without updating the docs first!

### Rule #3: Verify Config Flags Affect All Relevant Code Paths
**When adding or modifying config flags/options, verify they affect ALL places in the code where they should apply.**

Before pushing:
1. Search for all usages of the feature the flag controls
2. Ensure every code path respects the flag
3. Check edge cases (e.g., nested function calls, early returns)
4. If a function returns a value that signals special behavior (like "custom macro ran"), ensure all callers handle it

Example: If adding `CustomEndMacro` that runs instead of `/ice start`:
- Find ALL places that call `StartIce()`
- Make sure each call handles the case where custom macro was run
- Return appropriate signals so the script exits cleanly

### Rule #4: Generate Discord Questions for Unknown Issues
**When debugging fails repeatedly and you identify something you don't know about the SND API, generate a copy/paste ready question for Discord.**

Format the question like this:
```
📋 **SND API Question**

**What I'm trying to do:**
[Brief description]

**Code that's failing:**
```lua
[relevant code snippet]
```

**Error message:**
[exact error if available]

**What I've tried:**
- [attempt 1]
- [attempt 2]

**Question:**
[Specific question about the API]
```

This helps get accurate answers from the SND community when documentation is unclear.

### Rule #5: "push snd" or "snd push" Command
**When the user says "push snd" or "snd push", sync ALL local scripts to SND using the node sync tool.**

Run:
```bash
node sync.js push
```

This pushes all Lua scripts from the local Playroom folder to SND's internal storage (the "Synced" folder in SND).

### Rule #6: Always Push to SND After Script Changes
**After making any changes to Lua scripts, ALWAYS run `node sync.js push` to sync to SND without asking.**

Don't ask "Want me to push?" - just push automatically after any script modification.

### Rule #7: Use GitHub MCP for Git Operations
**Use the GitHub MCP tools instead of bash git commands whenever possible.**

Available MCP tools:
- `mcp__github__push_files` - Push multiple files in one commit
- `mcp__github__create_or_update_file` - Create/update a single file
- `mcp__github__list_commits` - View commit history
- `mcp__github__get_file_contents` - Read files from repo
- `mcp__github__create_pull_request` - Create PRs
- `mcp__github__create_branch` - Create branches

Use these instead of `git add`, `git commit`, `git push`, etc.

### Rule #8: Skills Are Plugin-Centric, Not Macro-Centric
**Skills should be organized by PLUGIN, not by macro or content type.**

When discovering new APIs:
- Create/update skills named after the **plugin** (e.g., `snd-autohook`, `snd-visland`, `snd-simpletweaks`)
- Do NOT create skills for specific macros or content (e.g., ~~`snd-ocean-fishing`~~)
- This allows skills to be reused across multiple macros that use the same plugin

Example - From FishingRaid.lua we discovered:
- AutoHook APIs → add to `snd-autohook` skill
- Visland APIs → add to `snd-visland` skill
- SimpleTweaks commands → add to `snd-simpletweaks` skill
- SND built-in ocean fishing functions → add to `snd-core` skill

This modular approach means any future macro can leverage the same plugin documentation.

### Rule #9: Include Source Repository in Skills
**When creating or updating skills from official plugin repositories, ALWAYS include the source repo URL in the skill documentation.**

Add a "Source Status" note near the top of the skill file:
```markdown
> **Source:** https://github.com/Owner/RepoName/path/to/IPC.cs
```

Or if unverified (from screenshots/testing):
```markdown
> **Source Status:** Unverified - documented from screenshots and testing. Official repo: https://github.com/Owner/RepoName
```

This allows us to:
- Easily find the official source for updates
- Verify documentation accuracy
- Track which skills need official verification

---

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
| **snd-stylist** | Automatic gear management and upgrades using Stylist plugin |
| **snd-saucy** | Gold Saucer mini-game automation (Cuff-a-cur, Triple Triad) - NO IPC API |
| **snd-autoretainer** | Retainer management using AutoRetainer plugin |
| **snd-combat** | Combat/rotation plugin integration (BossMod, RSR, Wrath) |
| **snd-wrath** | WrathCombo IPC for auto-rotation, combo states, job config, leasing |
| **snd-bossmod** | BossModReborn IPC for AI movement and combat control |
| **snd-textadvance** | Automatic dialog/cutscene advancement using TextAdvance plugin |
| **snd-questionable** | Quest automation using Questionable plugin |
| **snd-glamourer** | Glamour/appearance automation using Glamourer plugin |
| **snd-yesalready** | Auto-confirm dialogs, number entry, list selection using YesAlready plugin |
| **snd-inventory** | Inventory management, item counts, container operations |
| **snd-deliveroo** | Grand Company delivery automation, expert delivery, seals management |

### Content Automation
| Skill | Description |
|-------|-------------|
| **snd-fates** | FATE farming patterns, targeting, level sync, participation loops |
| **snd-ice** | Cosmic Exploration automation using Ice plugin |

### Maintenance & Debugging
| Skill | Description |
|-------|-------------|
| **audit** | Codebase audit procedures for consistency, bugs, and documentation |
| **chattwo-debug** | Reading ChatTwo chat logs as a debug console for bug analysis |
| **screenshots** | Reading ShareX screenshots for visual game information and UI state |

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

**Stylist** (see `snd-stylist` skill):
```lua
yield("/stylist crafter")   -- Update all crafter gearsets
yield("/stylist gatherer")  -- Update all gatherer gearsets
yield("/stylist all")       -- Update all gearsets
-- Note: /stylist alone only opens UI, does NOT update gear
```

**Saucy** (see `snd-saucy` skill):
```lua
-- Saucy has NO IPC API - Gold Saucer mini-games only, manual control
yield("/saucy")  -- Opens Saucy UI (manual configuration only)
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

To run remotely, use `script -c "tmux attach -t snd" /dev/null` |

---

## Skill Locations

For complete documentation, see the individual skill files:

```
.claude/skills/
├── snd-core/SKILL.md         # Core patterns, conditions, utilities
├── snd-addons/SKILL.md       # UI addons, node access, dialogs
├── snd-inventory/SKILL.md    # Inventory management, item counts
├── snd-vnavmesh/SKILL.md     # Navigation
├── snd-lifestream/SKILL.md   # Teleportation
├── snd-artisan/SKILL.md      # Crafting
├── snd-stylist/SKILL.md      # Gear management and upgrades
├── snd-saucy/SKILL.md        # Fishing
├── snd-autoretainer/SKILL.md # Retainers
├── snd-combat/SKILL.md       # Combat plugins
├── snd-wrath/SKILL.md        # WrathCombo IPC (official)
├── snd-bossmod/SKILL.md      # BossModReborn IPC
├── snd-textadvance/SKILL.md  # Dialog automation
├── snd-yesalready/SKILL.md   # Auto-confirm dialogs
├── snd-glamourer/SKILL.md    # Glamour/appearance
├── snd-deliveroo/SKILL.md    # GC delivery automation
├── snd-fates/SKILL.md        # FATE farming
├── snd-ice/SKILL.md          # Cosmic Exploration (Ice plugin)
├── snd-questionable/SKILL.md # Quest automation (Questionable plugin)
├── audit/SKILL.md            # Codebase audit procedures
├── chattwo-debug/SKILL.md    # ChatTwo debug console
└── screenshots/SKILL.md      # ShareX screenshots for visual info
```
