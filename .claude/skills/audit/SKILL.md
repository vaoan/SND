---
name: Audit
description: Use this skill when auditing the SND codebase for consistency, bugs, and documentation issues. Covers comprehensive audit procedures for scripts, skills, rules, and documentation.
---

# Codebase Audit

This skill defines the comprehensive audit process for maintaining consistency across the SND macro codebase.

**IMPORTANT:** All issues found during audit MUST be fixed, regardless of severity or priority. The audit is not complete until all issues are resolved.

## Audit Scope

A full audit covers:

1. **CLAUDE.md** - Main documentation and rules
2. **Lua Scripts** - All scripts in `Playroom/`
3. **Skill Documentation** - All files in `.claude/skills/*/SKILL.md`
4. **Rules Files** - All files in `.claude/rules/*.md`
5. **Commands** - All files in `.claude/commands/*.md`
6. **Code Compliance** - Verify code follows all rules in CLAUDE.md
7. **Code Review** - Check for bugs, logic errors, and documentation accuracy
8. **Architecture Compliance** - Verify scripts follow `.claude/rules/script-architecture.md`

## Audit Checklist

### CLAUDE.md Checks

- [ ] Rule numbering is sequential (1, 2, 3, 4, 5, 6, 7...)
- [ ] All skills listed in tables match actual skill directories
- [ ] All skills listed in "Skill Locations" tree match actual files
- [ ] Quick Reference examples are accurate and up-to-date
- [ ] No duplicate or conflicting rules
- [ ] All rules are current and applicable

### Lua Script Checks

For each script in `Playroom/` (excluding templates and test files):

**Version Consistency (REQUIRED for all scripts):**
- [ ] Has `SCRIPT_VERSION` constant at top of script
- [ ] Metadata version matches `SCRIPT_VERSION`
- [ ] Comment block version (if present) matches `SCRIPT_VERSION`
- [ ] Header output includes version: `[ScriptName] === Title vX.Y.Z ===`

**Documentation:**
- [ ] Description accurately describes current functionality
- [ ] plugin_dependencies list is complete and accurate
- [ ] All config options documented and have defaults

**Code Quality:**
- [ ] No hardcoded values that should be configurable
- [ ] Error messages prefixed with `[ScriptName]`
- [ ] All functions have appropriate error handling
- [ ] No unreachable code or dead code paths
- [ ] Logic is consistent (e.g., max level handling)

**Rule Compliance:**
- [ ] Rule #1: Skills updated when new API patterns discovered
- [ ] Rule #2: Documentation updated before push
- [ ] Rule #3: Config flags affect all relevant code paths
- [ ] Rule #6: Changes pushed to SND after modifications
- [ ] Rule #7: Git operations use GitHub MCP

### Skill Documentation Checks

For each skill in `.claude/skills/`:

- [ ] SKILL.md frontmatter has correct name and description
- [ ] Code examples are syntactically correct
- [ ] API patterns match actual SND/plugin behavior
- [ ] No outdated or deprecated patterns
- [ ] Critical warnings are highlighted (e.g., CRITICAL, IMPORTANT)
- [ ] Cross-references to other skills are accurate

### Rules File Checks

For each rule in `.claude/rules/`:

- [ ] Rule is clear and actionable
- [ ] Examples are correct and follow the rule
- [ ] No conflicts with other rules or CLAUDE.md

### Commands Checks

For each command in `.claude/commands/`:

- [ ] Command file exists and is valid markdown
- [ ] Description is clear and actionable
- [ ] References to skills use correct skill names (not old/renamed names)
- [ ] Instructions are accurate and up-to-date
- [ ] No references to non-existent files, skills, or rules

### Code Compliance Checks

Verify all code follows CLAUDE.md rules:

- [ ] All scripts have version in header output (for debug correlation per chattwo-debug)
- [ ] All plugin usage checks `HasPlugin()` first
- [ ] All waiting operations have timeouts
- [ ] `Player.Available` checked before player operations
- [ ] Semantic versioning used (MAJOR.MINOR.PATCH)

### Code Review Checks (NEW)

For each script, perform a detailed code review:

**Bug Detection:**
- [ ] No infinite loops without exit conditions
- [ ] All loops have proper termination (StopFlag, timeout, or condition)
- [ ] No nil access errors (check variables before use)
- [ ] Proper handling of edge cases (empty lists, nil values, boundary conditions)
- [ ] Return values handled correctly (check function return paths)
- [ ] No logic errors in conditionals (correct operators, boundary checks)
- [ ] State transitions are complete (no orphan states, all paths lead somewhere)

**Documentation vs Code Accuracy:**
- [ ] Comment block description matches actual script behavior
- [ ] "HOW IT WORKS" section accurately describes the flow
- [ ] Config option descriptions match their actual effect in code
- [ ] All documented features are actually implemented
- [ ] No undocumented features or behaviors
- [ ] Version history (if present) reflects actual changes

**Logic Consistency:**
- [ ] Messages match actual conditions (e.g., "leveling to X" when level < X)
- [ ] Error messages accurately describe the error
- [ ] Success/failure states are correctly reported
- [ ] Edge cases handled consistently (max level, empty config, disabled options)

### Architecture Compliance Checks (from script-architecture.md)

**Rule 1: State Machine Architecture:**
- [ ] Uses CharacterState table with function references
- [ ] State functions defined (not inline logic in main loop)
- [ ] Main loop only calls `State()` function
- [ ] State transitions are explicit (`State = CharacterState.newState`)
- [ ] Error/recovery states included
- [ ] No prohibited patterns:
  - [ ] No linear/procedural flow without state machine
  - [ ] No complex conditionals in main loop
  - [ ] No nested state management with string comparisons

**Rule 2: DRY (Don't Repeat Yourself):**
- [ ] No duplicate code blocks (same logic appearing multiple times)
- [ ] Repeated patterns extracted into helper functions
- [ ] Configuration values in tables, not hardcoded
- [ ] Data-driven approaches used where appropriate

**Rule 3: Self-Contained Scripts:**
- [ ] No `/snd run` calls to other scripts
- [ ] No `require()` statements
- [ ] All helper functions defined within the file
- [ ] No assumptions about globals from other scripts
- [ ] Script works independently

## Required Version Pattern

**Every script MUST have these version elements:**

```lua
-- 1. SCRIPT_VERSION constant (after metadata, before main code)
local SCRIPT_VERSION = "1.0.0"

-- 2. Versioned header in output
yield("/echo [ScriptName] === Script Title v" .. SCRIPT_VERSION .. " ===")

-- 3. Metadata version (must match SCRIPT_VERSION)
--[=====[
[[SND Metadata]]
version: 1.0.0
...
[[End Metadata]]
--]=====]

-- 4. Comment block version (if present, must match)
--[[
================================================================================
                              SCRIPT TITLE
                              Version 1.0.0
================================================================================
]]
```

This enables debug correlation per the chattwo-debug skill.

## Common Issues to Look For

### Version Mismatches
```lua
-- Metadata says:
version: 2.12.1

-- SCRIPT_VERSION says:
local SCRIPT_VERSION = "2.11.0"
-- ❌ These must match!
```

### Missing Version in Header
```lua
-- ❌ Wrong - no version
yield("/echo [Script] === Starting ===")

-- ✅ Correct - includes version
yield("/echo [Script] === Starting v" .. SCRIPT_VERSION .. " ===")
```

### Rule Numbering Gaps
```markdown
### Rule #1: ...
### Rule #2: ...
### Rule #4: ...  ❌ Missing #3!
```

### Missing Skills in CLAUDE.md
```markdown
## Skills Documentation
| **snd-core** | ... |
| **snd-addons** | ... |
<!-- ❌ Missing snd-questionable which exists in skills/ -->
```

### Rule Violations in Code
```lua
-- ❌ Rule #3 violation: Config flag not checked everywhere
if USE_FEATURE then
    DoSomething()
end
-- But another code path doesn't check USE_FEATURE!
```

### Inconsistent Logic Messages
```lua
-- At level 100, shouldn't say "Continue leveling to 100!"
-- Should say "Already at max level!" or similar
```

### Common Code Bugs to Check

```lua
-- ❌ BUG: Infinite loop - no exit condition
while true do
    DoSomething()
    yield("/wait 1")
end

-- ✅ CORRECT: Loop with exit condition
while not StopFlag do
    DoSomething()
    yield("/wait 1")
end

-- ❌ BUG: Missing timeout on wait
while IsBusy() do
    yield("/wait 0.1")  -- Can hang forever!
end

-- ✅ CORRECT: Wait with timeout
local startTime = os.clock()
while IsBusy() and (os.clock() - startTime) < 30 do
    yield("/wait 0.1")
end

-- ❌ BUG: Nil access without check
local level = Player.GetJob(jobId).Level  -- Crashes if GetJob returns nil

-- ✅ CORRECT: Check before access
local job = Player.GetJob(jobId)
local level = job and job.Level or 0

-- ❌ BUG: Off-by-one error in gearset slots
yield("/gearset change " .. idx)  -- Wrong! API index != UI slot

-- ✅ CORRECT: Convert API index to UI slot
local uiSlot = idx + 1
yield("/gearset change " .. uiSlot)

-- ❌ BUG: Missing return path
function DoSomething()
    if condition then
        return true
    end
    -- Falls through with nil return!
end

-- ✅ CORRECT: All paths return
function DoSomething()
    if condition then
        return true
    end
    return false
end

-- ❌ BUG: State not handled
if result == "switched" then
    -- handle
elseif result == "complete" then
    -- handle
end
-- What about "continue", "compliant", "custom_macro"?

-- ✅ CORRECT: Handle all states
if result == "switched" then
    -- handle
elseif result == "complete" then
    -- handle
elseif result == "continue" then
    -- handle
elseif result == "compliant" then
    -- handle
elseif result == "custom_macro" then
    -- handle
else
    -- unknown state - log error
end
```

### Documentation Mismatch Examples

```lua
-- ❌ Documentation says:
-- "Switches to lowest level job"
-- But code does:
local highestJob = nil
for _, job in ipairs(jobs) do
    if job.level > highestLevel then  -- WRONG: Gets highest, not lowest!
        highestJob = job
    end
end

-- ❌ Config says:
--   MaxLevel:
--     description: Maximum level to reach
-- But code does:
if level > MAX_LEVEL then  -- Uses > instead of >=, off by one!
    -- ...
end

-- ❌ HOW IT WORKS says step 5 does X, but code does Y
-- Always trace through the actual code flow!
```

### Architecture Violation Examples

```lua
-- ❌ BAD: No state machine (linear flow)
yield("/echo Starting")
DoStep1()
DoStep2()
DoStep3()
yield("/echo Done")

-- ❌ BAD: State machine with string comparisons
local state = "ready"
while not StopFlag do
    if state == "ready" then
        -- ...
        state = "working"
    elseif state == "working" then
        -- ...
    end
end

-- ✅ CORRECT: Proper state machine
CharacterState = {
    ready = Ready,
    working = Working,
}

function Ready()
    State = CharacterState.working
end

function Working()
    -- ...
end

State = CharacterState.ready
while not StopFlag do
    State()
    yield("/wait 0.1")
end
```

## Audit Output Format

After completing an audit, summarize findings:

```markdown
## Audit Summary

### Issues Found
| Location | Issue | Severity | Status |
|----------|-------|----------|--------|
| CLAUDE.md:81-86 | Rule numbering out of order | Medium | Fixed |
| CosmicLeveling.lua:78 | Version mismatch | Low | Fixed |
| ShowAllLevels.lua | Missing SCRIPT_VERSION | Low | Fixed |
| UpdateAllGear.lua:142 | Missing timeout on wait loop | High | Fixed |
| TeleportMapper.lua:89 | Documentation says X, code does Y | Medium | Fixed |

### Scripts Audited
- [x] CosmicLeveling.lua - 2 issues fixed
- [x] UpdateAllGear.lua - 1 issue fixed
- [x] ShowAllLevels.lua - 1 issue fixed

### Code Review Results
| Script | Bugs | Doc Accuracy | Architecture | Status |
|--------|------|--------------|--------------|--------|
| CosmicLeveling.lua | ✓ None | ✓ Accurate | ✓ Compliant | Clean |
| UpdateAllGear.lua | 1 fixed | ✓ Accurate | ✓ Compliant | Fixed |
| ShowAllLevels.lua | ✓ None | 1 fixed | ✓ Compliant | Fixed |

### Skills Audited
- [x] snd-core - Clean
- [x] snd-ice - Clean
...

### Commands Audited
- [x] audit.md - Clean
- [x] other-command.md - 1 issue fixed
...

### Rule Compliance
- [x] All scripts have versioned headers
- [x] All plugin usage has HasPlugin() checks
- [x] Git operations use GitHub MCP

### Architecture Compliance
- [x] All scripts use state machine pattern
- [x] No DRY violations (no duplicate code)
- [x] All scripts are self-contained

### Overall Status
All issues resolved. Codebase is consistent.
```

## Auto-Fix Procedures

### Missing SCRIPT_VERSION Fix
1. Add `local SCRIPT_VERSION = "X.Y.Z"` after metadata
2. Update header output to include version
3. Ensure metadata version matches

### Version Mismatch Fix
1. Determine correct version (usually metadata is source of truth)
2. Update SCRIPT_VERSION constant
3. Update comment block version (if present)
4. Update header output

### Rule Numbering Fix
1. Renumber rules sequentially
2. Keep rule content unchanged
3. Update any cross-references

### Missing Skill Fix
1. Add to appropriate table in CLAUDE.md
2. Add to Skill Locations tree
3. Verify skill file exists

### Command Reference Fix
1. Find all references to old/renamed skills or rules
2. Update to use current names
3. Verify referenced skills/rules exist

### Bug Fix Procedures

**Missing Timeout Fix:**
```lua
-- Before (bug):
while IsBusy() do
    yield("/wait 0.1")
end

-- After (fixed):
local startTime = os.clock()
local timeout = 30  -- seconds
while IsBusy() and (os.clock() - startTime) < timeout do
    yield("/wait 0.1")
end
if IsBusy() then
    yield("/echo [Script] ERROR: Timeout waiting for busy state")
end
```

**Nil Access Fix:**
```lua
-- Before (bug):
local level = Player.GetJob(jobId).Level

-- After (fixed):
local job = Player.GetJob(jobId)
local level = job and job.Level or 0
```

**Missing Return Path Fix:**
```lua
-- Before (bug):
function CheckCondition()
    if condition then
        return true
    end
    -- No return!
end

-- After (fixed):
function CheckCondition()
    if condition then
        return true
    end
    return false
end
```

**Unhandled State Fix:**
```lua
-- Before (bug):
if result == "a" then
    HandleA()
elseif result == "b" then
    HandleB()
end

-- After (fixed):
if result == "a" then
    HandleA()
elseif result == "b" then
    HandleB()
else
    yield("/echo [Script] ERROR: Unknown result: " .. tostring(result))
    StopFlag = true
end
```

### Documentation Accuracy Fix
1. Read the entire script to understand actual behavior
2. Compare documented behavior (comment block, HOW IT WORKS) with code
3. Update documentation to match code, OR fix code if docs are correct
4. Verify config descriptions match actual usage
5. Test script to confirm behavior

### Architecture Compliance Fix

**Adding State Machine:**
1. Identify distinct operational phases in the script
2. Create CharacterState table with function references
3. Move logic into state functions
4. Replace linear flow with state transitions
5. Add main loop that only calls State()

**Fixing DRY Violations:**
1. Identify duplicate code blocks
2. Extract into helper function with parameters
3. Replace duplicates with function calls
4. Ensure function handles all variations

## Post-Audit Actions

After fixing ALL issues (regardless of severity):

1. **Push to SND** - `node sync.js push` (Rule #6)
2. **Commit changes** - Use GitHub MCP (Rule #7)
3. **Verify** - Run audit again to confirm all fixes applied
