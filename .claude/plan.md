# Plan: Parallel Agent Documentation Verification and Update

## Overview

Create multiple parallel agents, each responsible for verifying and updating documentation for a single plugin repository. Each agent will:
1. Fetch the official IPC/API source from the GitHub repository
2. Compare against our current skill documentation
3. Update the skill documentation with any missing or corrected APIs

## Repositories to Process

Based on the skill files, here are the 12 repositories and their corresponding skills:

| # | Skill | Repository | IPC Source Path |
|---|-------|------------|-----------------|
| 1 | snd-artisan | PunishXIV/Artisan | Artisan/IPC/IPC.cs |
| 2 | snd-autoretainer | PunishXIV/AutoRetainerAPI | AutoRetainerAPI/AutoRetainerApi.cs |
| 3 | snd-bossmod | awgil/ffxiv_bossmod | (needs discovery) |
| 4 | snd-ice | ffxivcode/Ice | (needs discovery) |
| 5 | snd-lifestream | NightmareXIV/Lifestream | Lifestream/IPC/IPCProvider.cs |
| 6 | snd-glamourer | Ottermandias/Glamourer | (needs discovery) |
| 7 | snd-deliveroo | PunishXIV/Deliveroo | (needs discovery) |
| 8 | snd-vnavmesh | awgil/ffxiv_navmesh | vnavmesh/IPCProvider.cs |
| 9 | snd-saucy | PunishXIV/Saucy | (needs discovery) |
| 10 | snd-questionable | pot0to/Questionable | (needs discovery) |
| 11 | snd-textadvance | NightmareXIV/TextAdvance | (needs discovery) |
| 12 | snd-yesalready | PunishXIV/YesAlready | (needs discovery) |
| 13 | snd-wrath | PunishXIV/WrathCombo | WrathCombo/Services/IPC/* |

## Agent Design

### Each Agent Will:
1. **Discover IPC files** - Search the repo for IPC-related files (IPC.cs, IPCProvider.cs, etc.)
2. **Read the IPC source** - Fetch the actual API definitions from GitHub
3. **Read current skill** - Load the corresponding SKILL.md file
4. **Compare and analyze** - Identify missing APIs, incorrect signatures, or outdated info
5. **Update documentation** - Write updated SKILL.md with:
   - Verified source URL
   - Complete API reference from the actual source
   - Corrected function signatures
   - Any new APIs not previously documented

### Agent Prompt Template:
```
You are a documentation verification agent for the {skill_name} skill.

TASK:
1. Search the {owner}/{repo} repository for IPC-related files
2. Read the IPC source code to extract all public API methods
3. Read the current skill documentation at .claude/skills/{skill_name}/SKILL.md
4. Update the skill documentation with:
   - Correct "Source:" link to the actual IPC file
   - All API methods with correct signatures
   - Remove any APIs that don't exist in the source
   - Add any new APIs from the source
   - Keep the existing helper patterns and usage examples

Return a summary of changes made.
```

## Execution Plan

### Step 1: Launch 13 Parallel Agents
Launch all agents simultaneously, one per repository:
- Agent 1: snd-artisan (PunishXIV/Artisan)
- Agent 2: snd-autoretainer (PunishXIV/AutoRetainerAPI)
- Agent 3: snd-bossmod (awgil/ffxiv_bossmod)
- Agent 4: snd-ice (ffxivcode/Ice)
- Agent 5: snd-lifestream (NightmareXIV/Lifestream)
- Agent 6: snd-glamourer (Ottermandias/Glamourer)
- Agent 7: snd-deliveroo (PunishXIV/Deliveroo)
- Agent 8: snd-vnavmesh (awgil/ffxiv_navmesh)
- Agent 9: snd-saucy (PunishXIV/Saucy)
- Agent 10: snd-questionable (pot0to/Questionable)
- Agent 11: snd-textadvance (NightmareXIV/TextAdvance)
- Agent 12: snd-yesalready (PunishXIV/YesAlready)
- Agent 13: snd-wrath (PunishXIV/WrathCombo)

### Step 2: Collect Results
Wait for all agents to complete and collect their reports.

### Step 3: Summary Report
Generate a summary of all changes made across all skills.

## Expected Outcomes

Each skill will have:
- ✅ Verified source URL pointing to actual IPC file
- ✅ Complete API reference matching the source code
- ✅ Correct function signatures with types
- ✅ Updated from "Unverified" to verified status where applicable

## Notes

- Some repos may have IPC in different locations - agents should search for common patterns (IPC.cs, IPCProvider.cs, API.cs, etc.)
- If a repo doesn't have IPC endpoints (chat commands only), document that finding
- Preserve existing helper functions and usage patterns - only update the API reference section
