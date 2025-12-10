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
3. **Deep Code Review**: For each script, follow the 8-step process:
   - Step 1: Read entire script (don't skim)
   - Step 2: Check hardcoded values vs config (e.g., `100` vs `MAX_LEVEL`)
   - Step 3: Check empty collection edge cases (e.g., `AllJobsAtMax([])`)
   - Step 4: Trace all return values (all cases handled?)
   - Step 5: Verify boundary conditions (off-by-one errors)
   - Step 6: Check message accuracy (messages match conditions?)
   - Step 7: Document findings in table format
   - Step 8: Create quality assessment summary
4. Fix ALL issues found regardless of priority or impact
5. Push to SND after any script changes (Rule #6)
6. Provide a summary of findings and fixes

## Output Format

Provide:
- Table of issues found with location, description, severity, and status
- Code Review Results table (Bugs, Doc Accuracy, Architecture per script)
- Quality Assessment table (Timeout Protection, Nil Access, Edge Cases, etc.)
- List of files audited with status (Clean/Fixed)
- Architecture Compliance summary
- Confirmation that all issues are resolved
