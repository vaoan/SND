# Claude Code Tools

Scripts and MCP server wrappers used by Claude Code hooks and automation.

## MCP Server Configuration

The project uses `.mcp.json` to configure MCP (Model Context Protocol) servers. These provide Claude Code with additional capabilities like browser automation, issue tracking, and deployment management.

### Configured Servers

| Server            | Purpose                      | Authentication         |
| ----------------- | ---------------------------- | ---------------------- |
| `shadcn`          | shadcn/ui component registry | None                   |
| `next-devtools`   | Next.js DevTools integration | None                   |
| `playwright`      | Browser automation testing   | None                   |
| `chrome-devtools` | Chrome DevTools Protocol     | None                   |
| `linear`          | Linear issue tracking        | OAuth (browser login)  |
| `github`          | GitHub API access            | Token via `.env.local` |
| `vercel`          | Vercel deployment management | Token via `.env.local` |

### Token Setup

For GitHub and Vercel MCP servers, you need to provide API tokens:

1. Copy the example file:

   ```bash
   cp .claude/tools/.env.local.example .claude/tools/.env.local
   ```

2. Edit `.claude/tools/.env.local` and add your tokens:

   ```bash
   # GitHub Personal Access Token
   # Get from: https://github.com/settings/tokens
   # Required scopes: 'repo' (for full repository access)
   GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxxxxxxxxxxx

   # Vercel API Token
   # Get from: https://vercel.com/account/tokens
   VERCEL_TOKEN=xxxxxxxxxxxx
   ```

3. Restart Claude Code after adding tokens.

## MCP Wrapper Scripts

Both wrapper scripts are cross-platform (Windows, macOS, Linux) and automatically load tokens from environment files before starting the MCP servers.

### github-mcp.mjs

Cross-platform wrapper that loads `GITHUB_PERSONAL_ACCESS_TOKEN` and runs the official `@modelcontextprotocol/server-github` package via npx.

**Token locations checked (in order):**

1. Project root: `.env.local`
2. Script directory: `.claude/tools/.env.local`

**Features:**

- Automatically parses `.env.local` files (supports quoted and unquoted values)
- Cross-platform compatibility (Windows, macOS, Linux)
- Proper error handling and exit codes
- Uses `npx` to run the latest version of `@modelcontextprotocol/server-github`

**Manual execution:**

```bash
node .claude/tools/github-mcp.mjs
```

### vercel-mcp.mjs

Cross-platform wrapper that loads `VERCEL_TOKEN` and runs the official `@vercel/sdk` MCP server.

**Token locations checked (in order):**

1. Project root: `.env.local`
2. Script directory: `.claude/tools/.env.local`

**Features:**

- Uses the official `@vercel/sdk` package (GitHub: https://github.com/vercel/sdk)
- Provides ~95+ tools covering the full Vercel REST API
- Automatically validates token presence before starting
- Cross-platform compatibility (Windows, macOS, Linux)
- Requires Node.js v20 or greater
- Proper error handling with helpful error messages

**Manual execution:**

```bash
node .claude/tools/vercel-mcp.mjs
```

**Note:** If `VERCEL_TOKEN` is not found, the script will exit with an error message pointing you to where to get a token.

## SessionStart Hook

The `SessionStart` hook runs when Claude Code starts a new session.

### Purpose

Check if `.cursor/mcp.json` exists. If it doesn't, run `Create-McpSymlink.ps1` to create a symlink so both Claude Code and Cursor share the same MCP configuration.

### Hook Logic

```
IF .cursor/mcp.json does NOT exist
    THEN run Create-McpSymlink.ps1
    (ignore script output - script handles everything internally)
ELSE
    do nothing
```

### Configuration

In `.claude/settings.local.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"if (process.platform === 'win32' && !require('fs').existsSync('.cursor/mcp.json')) { require('child_process').execSync('powershell -ExecutionPolicy Bypass -File .claude/tools/Create-McpSymlink.ps1', {stdio: 'inherit'}) }\""
          }
        ]
      }
    ]
  }
}
```

### Key Points

- Windows-only: Uses Node.js to check platform before running PowerShell
- Script output is not suppressed - let errors surface for debugging
- No `exit 0` override - if the script fails, the hook should report it

## Create-McpSymlink.ps1

Creates a symlink from `.cursor/mcp.json` to `.mcp.json` so both Claude Code and Cursor share the same MCP configuration.

### Requirements

- Windows with either:
  - Developer Mode enabled (no admin required), OR
  - Administrator privileges (UAC prompt)

### Manual Execution

```powershell
powershell -ExecutionPolicy Bypass -File .claude/tools/Create-McpSymlink.ps1
```

## File Structure

```
.claude/tools/
├── README.md                 # This file
├── .env.local.example        # Token template (copy to .env.local)
├── .env.local                # Your tokens (gitignored)
├── github-mcp.mjs            # GitHub MCP wrapper script
├── vercel-mcp.mjs            # Vercel MCP wrapper script
└── Create-McpSymlink.ps1     # Windows symlink creation script
```

## Troubleshooting

### MCP Server Not Connecting

1. Check if the token is set correctly in `.claude/tools/.env.local`
2. Verify the token has the required permissions/scopes
3. Restart Claude Code after adding/changing tokens
4. Check Claude Code logs for specific error messages

### GitHub MCP Issues

- Ensure token has `repo` scope for full repository access
- Token must not be expired
- For fine-grained tokens, ensure repository access is configured
- Token can be quoted or unquoted in `.env.local` files (both formats are supported)
- Script automatically handles Windows `.cmd` file execution

### Vercel MCP Issues

- Token must be valid and not expired
- Check team/account permissions if accessing team resources
- Requires Node.js v20 or greater
- If you see "VERCEL_TOKEN not found" error, ensure the token is set in either:
  - Project root `.env.local`, or
  - `.claude/tools/.env.local`
- Token can be quoted or unquoted in `.env.local` files
