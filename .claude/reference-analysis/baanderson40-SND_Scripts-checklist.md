# Reference Analysis: baanderson40/SND_Scripts

**Source:** https://github.com/baanderson40/SND_Scripts
**Started:** 2025-12-07
**Last Updated:** 2025-12-07

## Progress Summary
- Total Files: 21 (Lua scripts only, excluding readmes)
- Analyzed: 11 (2 skipped as too specific)
- Remaining: 10

## Skills Updated
- **snd-core**: Added Logging System, Advanced Distance Helpers, InteractByName, Character Info Helpers, GetPlugins, Advanced IPC Subscriber Access (reflection-based), Svc.Targets system, Svc.ClientState access, Debug/Reflection utilities, NPC Name Resolution (Multi-Sheet Chain Lookup)
- **snd-vnavmesh**: Added Safe VNAV Calls section with PathandMoveVnav, StopCloseVnav, MoveNearVnav
- **snd-addons**: Added safe addon access with `_get_addon`, updated `IsAddonVisible` to use `addon.Exists`, improved node access with `addon:GetNode()`
- **snd-fates**: Added FATE API Reference (Fates.GetActiveFates, Fates.GetNearestFate), EntityWrapper for FateId access, combat plugin integration (RSR, BMR, VBM, Wrath), zone/aetheryte management, instance management, chocobo companion, multi-zone farming pattern, chat message triggers

## Skills Created
_(none yet)_

## File Checklist

### Useful Scripts (Priority: HIGH - Core patterns and utilities)
- [x] `SND base script.lua` (27KB) - Comprehensive base script with helpers
  - Status: complete
  - Priority: HIGH - Core patterns, likely has many reusable functions
  - Findings: Logging system (Log/Echo/Logf/Echof), safe addon access with pcall, IsAddonVisible uses addon.Exists, WaitUntil patterns, node access via addon:GetNode(), distance helpers (Vector3.Distance, IsWithinDistance), InteractByName, SafeCallback, VNAV safe wrappers (PathandMoveVnav, StopCloseVnav, MoveNearVnav), Excel lookups
  - Actions: Updated snd-core (logging, distance, interact), snd-vnavmesh (safe calls), snd-addons (safe access, node methods)

- [x] `Character Condition Testing.lua` (5KB) - Character condition reference
  - Status: complete
  - Priority: HIGH - May have condition testing patterns
  - Findings: Same 102 CharacterConditions as base script, no new patterns beyond what's already documented
  - Actions: None needed - conditions already in snd-core

- [x] `IPCs Subscribers.lua` (6KB) - IPC subscriber patterns
  - Status: complete
  - Priority: HIGH - Plugin IPC patterns
  - Findings: Advanced reflection-based IPC subscriber access using System.Reflection, generic method construction, Action vs Function IPC distinction, caching pattern
  - Actions: Added Advanced IPC Subscriber Access section to snd-core

- [x] `Big Dump.lua` (6KB) - Data dumping utility
  - Status: complete
  - Priority: MEDIUM - Debug/utility patterns
  - Findings: DumpInstance (reflection), DumpPropertyTypes, DumpPropertyType, DescribeIGameObject, Svc.Targets slots (Target, FocusTarget, etc.), Svc.ClientState properties (TerritoryType, MapId, IsLoggedIn), LocalPlayer world/job access
  - Actions: Added Svc.Targets system, Svc.ClientState access, Debug/Reflection utilities to snd-core

- [x] `Installed Dalamud Plugins.lua` (1KB) - Plugin enumeration
  - Status: complete
  - Priority: MEDIUM - Plugin detection patterns
  - Findings: Same HasPlugin() pattern as base script, alphabetical sorting with table.sort()
  - Actions: None needed - patterns already in snd-core

- [x] `Job Name&Abbr from excel sheet.lua` (1KB) - Excel job data access
  - Status: complete
  - Priority: MEDIUM - Excel data patterns
  - Findings: Excel.GetSheet("ClassJob"), row.Name, row.Abbreviation - Job IDs 1-45
  - Actions: None needed - BuildJobTable already in snd-core

- [x] `NPC name by id and excel sheet.lua` (3KB) - NPC data lookup
  - Status: complete
  - Priority: MEDIUM - Excel NPC data patterns
  - Findings: Multi-sheet chain lookups (ENpcResident, EventNpc→ENpcResident, BNpcBase→BNpcName), caching pattern, row.Singular/Name/RowId
  - Actions: Added NPC Name Resolution (Multi-Sheet Chain Lookup) section to snd-core

- [x] `PlaceName by TerritoryTypeID.lua` (2KB) - Territory/place lookup
  - Status: complete
  - Priority: MEDIUM - Excel territory data patterns
  - Findings: TerritoryType→PlaceName chain, handles userdata/number/string types, .Value/.RowId access
  - Actions: None needed - PlaceNameByTerritory already in snd-core (verified same approach)

- [x] `Player Current Status IDs.lua` (1KB) - Status effect IDs
  - Status: complete
  - Priority: MEDIUM - Status checking patterns
  - Findings: Player.Status list, .Count, zero-based indexing with list[i] or list:get_Item(i), status.StatusId
  - Actions: None needed - HasStatusId already in snd-core

### Fates (Priority: HIGH - FATE farming patterns)
- [x] `Fate Farming.lua` (136KB) - Main FATE farming script
  - Status: complete
  - Priority: HIGH - Comprehensive FATE automation, very large
  - Findings: Fates.GetActiveFates(), Fates.GetNearestFate(), fate properties (Id, Name, State, Progress, IsBonus, Duration, StartTimeEpoch, Location, IconId, InFate, EventItem), EntityWrapper for FateId access, combat plugin integration (RSR, BMR, VBM, Wrath), Svc.AetheryteList, Instances.Telepo:GetAetherytePosition(), InstancedContent.PublicInstance.InstanceId, Instances.Buddy.CompanionInfo.TimeLeft, comprehensive FATE data structures per zone
  - Actions: Updated snd-fates with FATE API reference, EntityWrapper access, combat plugin integration, zone/aetheryte management, instance management, chocobo companion

- [x] `Multi Zone Farming.lua` (4KB) - Multi-zone FATE rotation
  - Status: complete
  - Priority: MEDIUM - Zone switching patterns
  - Findings: OnChatMessage() with TriggerData.message for chat triggers, Excel.GetRow("TerritoryType", zoneId).Aetheryte.PlaceName.Name for aetheryte lookup, /snd run command for running other macros, zone rotation pattern
  - Actions: Added multi-zone farming pattern and chat message triggers to snd-fates

- [ ] `Occult Demiatma Farming.lua` (5KB) - Specific FATE farming
  - Status: skipped
  - Priority: LOW - Specific content, may have useful patterns
  - Findings: Specific content for Dawntrail Occult demiatma farming, no new general patterns
  - Actions: None - too specific

- [ ] `Zodiac Atma Farming.lua` (5KB) - Zodiac weapon FATE farming
  - Status: skipped
  - Priority: LOW - Specific content
  - Findings: Specific content for legacy Zodiac weapon farming, no new general patterns
  - Actions: None - too specific

### Cosmic Exploration (Priority: MEDIUM - Gathering/exploration patterns)
- [ ] `Cosmic Helper.lua` (46KB) - Main cosmic exploration helper
  - Status: pending
  - Priority: MEDIUM - Large script, gathering patterns
  - Findings:
  - Actions:

- [ ] `Cosmic Botanist.lua` (20KB) - Botany automation
  - Status: pending
  - Priority: MEDIUM - Gathering patterns
  - Findings:
  - Actions:

- [ ] `Cosmic Miner.lua` (20KB) - Mining automation
  - Status: pending
  - Priority: MEDIUM - Gathering patterns
  - Findings:
  - Actions:

- [ ] `Cosmic Fisher.lua` (17KB) - Fishing automation
  - Status: pending
  - Priority: MEDIUM - Fishing patterns
  - Findings:
  - Actions:

### AutoRetainer (Priority: MEDIUM - Retainer management)
- [ ] `Auto Repricer.lua` (35KB) - Market board repricing
  - Status: pending
  - Priority: MEDIUM - Market board patterns
  - Findings:
  - Actions:

- [ ] `Repricer.lua` (35KB) - Alternative repricer
  - Status: pending
  - Priority: LOW - Likely similar to Auto Repricer
  - Findings:
  - Actions:

- [ ] `Process AutoRetainer.lua` (4KB) - AutoRetainer processing
  - Status: pending
  - Priority: MEDIUM - AutoRetainer patterns
  - Findings:
  - Actions:

### Dungeons (Priority: LOW - Dungeon automation)
- [ ] `Helio Farm.lua` (12KB) - Dungeon farming
  - Status: pending
  - Priority: LOW - Specific dungeon content
  - Findings:
  - Actions:

### GC Trade Scripts (Priority: LOW - Grand Company)
- [ ] `Sigmascape (O5N) Parts Trade.lua` (17KB) - GC trading
  - Status: pending
  - Priority: LOW - Specific content, may have GC patterns
  - Findings:
  - Actions:

### MGP (Priority: LOW - Gold Saucer)
- [ ] `Triple Triad Farm.lua` (16KB) - Triple Triad automation
  - Status: pending
  - Priority: LOW - Specific content
  - Findings:
  - Actions:

- [ ] `Sell TT Cards.lua` (2KB) - Card selling
  - Status: pending
  - Priority: LOW - Small utility
  - Findings:
  - Actions:

### Old (Priority: SKIP - Deprecated)
- [ ] `Cosmic Helper WIP.lua` (32KB) - Work in progress
  - Status: skipped
  - Priority: SKIP - Deprecated WIP version
  - Findings: Skip - superseded by Cosmic Helper.lua
  - Actions: None

- [ ] `Unstick Fate.lua` (6KB) - FATE unsticking utility
  - Status: pending
  - Priority: LOW - May have useful recovery patterns
  - Findings:
  - Actions:

---

## Analysis Order (Recommended)

1. **First Session:** Useful Scripts (HIGH priority files)
   - SND base script.lua
   - Character Condition Testing.lua
   - IPCs Subscribers.lua

2. **Second Session:** Useful Scripts (MEDIUM priority) + Fates
   - Remaining Useful Scripts
   - Fate Farming.lua (large file, may need dedicated session)

3. **Third Session:** Cosmic Exploration
   - All Cosmic files

4. **Fourth Session:** AutoRetainer + remaining
   - AutoRetainer files
   - GC Trade, MGP, Dungeons

---

## Resume Instructions

To continue analysis, say: "continue reference analysis"

The assistant should:
1. Read this checklist
2. Find the first file with `Status: pending`
3. Analyze that file
4. Update findings and actions
5. Make any necessary skill updates
6. Mark as complete and save checklist
