Perform a comprehensive audit of the entire SND codebase. Check for consistency, bugs, and documentation issues.

## Audit Scope

1. **CLAUDE.md** - Check rule numbering, skill listings, quick reference accuracy
2. **Lua Scripts** - Check version consistency, logic bugs, dead code
3. **Skill Documentation** - Check accuracy, completeness, cross-references
4. **Rules Files** - Check clarity, no conflicts
5. **Commands** - Check they exist and work

## Required Actions

1. Use the `snd-audit` skill for guidance
2. Read and verify each file systematically
3. Fix ALL issues found regardless of priority or impact
4. Push to SND after any script changes (Rule #6)
5. Provide a summary of findings and fixes

## Output Format

Provide:
- Table of issues found with location, description, and status
- List of files audited with status (Clean/Fixed)
- Confirmation that all issues are resolved
