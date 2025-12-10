Perform a comprehensive audit of the entire SND codebase. Check for consistency, bugs, documentation accuracy, and rule compliance.

## Audit Scope

1. **CLAUDE.md** - Check rule numbering, skill listings, quick reference accuracy
2. **Lua Scripts** - Check version consistency, logic bugs, dead code
3. **Skill Documentation** - Check accuracy, completeness, cross-references
4. **Rules Files** - Check clarity, no conflicts
5. **Commands** - Check they exist and work
6. **Code Review** - Check for bugs, logic errors, nil access, missing timeouts
7. **Documentation Accuracy** - Verify code behavior matches documentation
8. **Architecture Compliance** - Verify scripts follow script-architecture.md rules

## Required Actions

1. Use the `audit` skill for guidance
2. Read and verify each file systematically
3. **Code Review**: For each script:
   - Check for bugs (infinite loops, nil access, missing timeouts, unhandled states)
   - Verify documentation matches actual code behavior
   - Check architecture compliance (state machine, DRY, self-contained)
4. Fix ALL issues found regardless of priority or impact
5. Push to SND after any script changes (Rule #6)
6. Provide a summary of findings and fixes

## Output Format

Provide:
- Table of issues found with location, description, and status
- Code Review Results table (Bugs, Doc Accuracy, Architecture per script)
- List of files audited with status (Clean/Fixed)
- Architecture Compliance summary
- Confirmation that all issues are resolved
