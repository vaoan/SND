---
name: SND Audit
description: Use this skill when auditing the SND codebase for consistency, bugs, and documentation issues. Covers comprehensive audit procedures for scripts, skills, rules, and documentation.
---

# SND Codebase Audit

This skill defines the comprehensive audit process for maintaining consistency across the SND macro codebase.

## Audit Scope

A full audit covers:

1. **CLAUDE.md** - Main documentation
2. **Lua Scripts** - All scripts in `Playroom/`
3. **Skill Documentation** - All files in `.claude/skills/*/SKILL.md`
4. **Rules Files** - All files in `.claude/rules/*.md`
5. **Commands** - All files in `.claude/commands/*.md`

## Audit Checklist

### CLAUDE.md Checks

- [ ] Rule numbering is sequential (1, 2, 3, 4, 5, 6, 7...)
- [ ] All skills listed in tables match actual skill directories
- [ ] All skills listed in "Skill Locations" tree match actual files
- [ ] Quick Reference examples are accurate and up-to-date
- [ ] No duplicate or conflicting rules

### Lua Script Checks

For each script in `Playroom/`:

- [ ] Metadata version matches comment block version
- [ ] Description accurately describes current functionality
- [ ] plugin_dependencies list is complete and accurate
- [ ] All config options documented and have defaults
- [ ] No hardcoded values that should be configurable
- [ ] Error messages prefixed with `[ScriptName]`
- [ ] All functions have appropriate error handling
- [ ] No unreachable code or dead code paths
- [ ] Logic is consistent (e.g., max level handling)

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

## Common Issues to Look For

### Version Mismatches
```lua
-- Metadata says:
version: 2.12.1

-- Comment block says:
--                                  Version 2.11.0
-- ❌ These must match!
```

### Rule Numbering Gaps
```markdown
### Rule #1: ...
### Rule #2: ...
### Rule #4: ...  ❌ Missing #3!
### Rule #7: ...  ❌ Out of order!
### Rule #6: ...
```

### Missing Skills in CLAUDE.md
```markdown
## Skills Documentation
| **snd-core** | ... |
| **snd-addons** | ... |
<!-- ❌ Missing snd-questionable which exists in skills/ -->
```

### Inconsistent Logic Messages
```lua
-- At level 100, shouldn't say "Continue leveling to 100!"
-- Should say "Already at max level!" or similar
```

### Dead Code Paths
```lua
if level >= MAX_LEVEL then
    -- This branch is unreachable if earlier check catches it
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

### Scripts Audited
- [x] CosmicLeveling.lua - 2 issues fixed
- [x] UpdateAllGear.lua - Clean
- [x] TeleportationMapper.lua - Clean

### Skills Audited
- [x] snd-core - Clean
- [x] snd-ice - Clean
...

### Overall Status
All issues resolved. Codebase is consistent.
```

## Auto-Fix Procedures

### Version Mismatch Fix
1. Read metadata version
2. Update comment block version to match
3. Bump version if making functional changes

### Rule Numbering Fix
1. Renumber rules sequentially
2. Keep rule content unchanged
3. Update any cross-references

### Missing Skill Fix
1. Add to Plugin Integrations or Content Automation table
2. Add to Skill Locations tree
3. Verify skill file exists

## Post-Audit Actions

After fixing issues:

1. **Push to SND** - `node sync.js push` (Rule #6)
2. **Commit changes** - Use GitHub MCP (Rule #7)
3. **Verify** - Run audit again to confirm fixes
