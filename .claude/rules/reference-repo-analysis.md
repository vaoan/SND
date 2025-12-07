# Reference Repository Analysis Rule

When the user asks to "check for references and update skills/documentation/rules" or similar requests involving analyzing external repositories, follow this systematic process.

**IMPORTANT:** Do NOT ask for confirmation. Automatically start the analysis process immediately.

## Trigger Phrases

- "check for references and update"
- "analyze this repo and update skills"
- "use this repo as reference"
- "compare with our skills/documentation"
- "continue reference analysis"

## Process Overview

### Phase 1: Setup Checklist

1. **Fetch repository structure** using GitHub MCP tools
2. **Create a checklist file** at `.claude/reference-analysis/[repo-name]-checklist.md`
3. **List all relevant files** (Lua scripts, documentation) with status markers

### Phase 2: File-by-File Analysis

1. **Read one file at a time** from the checklist
2. **Compare patterns** with existing skills
3. **Document findings** in the checklist
4. **Make updates** to relevant skills or create new ones
5. **Mark file as complete** in checklist
6. **Commit progress** if appropriate

### Phase 3: Continue in New Context

When approaching context limits:
1. Save progress to the checklist file
2. Note which file to continue from
3. User can resume with "continue reference analysis"

## Checklist File Format

```markdown
# Reference Analysis: [Repository Name]

**Source:** [GitHub URL]
**Started:** [Date]
**Last Updated:** [Date]

## Progress Summary
- Total Files: X
- Analyzed: Y
- Remaining: Z

## Skills Updated
- [skill-name]: [brief description of changes]

## Skills Created
- [skill-name]: [brief description]

## File Checklist

### [Directory Name]
- [ ] `filename.lua` - [brief description if known]
  - Status: pending/in-progress/complete/skipped
  - Findings: [notes]
  - Actions: [what was done]

### [Another Directory]
- [x] `another-file.lua` - [description]
  - Status: complete
  - Findings: Contains useful pattern X
  - Actions: Updated snd-core with pattern X
```

## Analysis Guidelines

When analyzing each file, look for:

1. **New API patterns** not in current skills
2. **Helper functions** that could be generalized
3. **Error handling patterns** worth adopting
4. **Configuration patterns** to document
5. **State machine patterns** or workflows
6. **Plugin integrations** not yet documented
7. **Game data access** (Excel sheets, addons)
8. **Common constants** (IDs, names, conditions)

## Update Priority

1. **High Priority**: Core patterns used across multiple files
2. **Medium Priority**: Plugin-specific patterns
3. **Low Priority**: Niche/specialized patterns

## Skip Criteria

Skip files that are:
- Duplicates or near-duplicates
- Personal configuration files
- Incomplete/broken scripts
- Too specific to be generalized

## Resume Command

When user says "continue reference analysis":
1. Read the checklist file at `.claude/reference-analysis/[repo-name]-checklist.md`
2. Find first uncompleted item (Status: pending)
3. Automatically start analyzing from that point - do NOT ask for confirmation
4. After completing each file, continue to the next pending file
5. Stop only when approaching context limits or all files are complete

## Auto-Start Behavior

- When triggered, immediately begin work without asking "Should I start?" or similar
- Provide brief progress updates as you work
- Only pause to ask questions if genuinely ambiguous decisions are needed
- Keep momentum - analyze, update, mark complete, move to next
