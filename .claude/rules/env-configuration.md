# Environment Configuration Rule

## NO HARDCODING - No Exceptions

**Nothing user-configurable should ever be hardcoded in the Node.js project.**

This rule has **NO EXCEPTIONS**.

---

## Configuration Structure

### `.env.example` - Default Values (Committed)
- Contains ALL default configuration values
- This is the template users copy to create their `.env`
- Always committed to version control

### `.env` and variants - User Overrides (NOT Committed)
- User creates by copying `.env.example`
- Contains user-specific overrides
- NEVER committed (in `.gitignore`)

### File Location
```
/                       # Project root (Node.js)
├── .env.example        # Defaults (committed)
├── .env                # User overrides (ignored)
├── .env.local          # Local overrides (ignored)
├── package.json
├── index.js
└── Playroom/           # Lua scripts (hardcoding allowed)
    └── *.lua
```

---

## Rules

1. **NEVER hardcode user-configurable values in code**
   - No magic strings for paths, URLs, credentials, IDs
   - No inline defaults that should be configurable
   - If a user might want to change it, it goes in `.env.example`

2. **All environment variables MUST be defined in `.env.example` first**
   - Never add a `process.env.VAR_NAME` reference without adding it to `.env.example`
   - Include a descriptive comment for each variable
   - Provide sensible default values

3. **Never commit `.env` files (except `.env.example`)**
   - The `.gitignore` already excludes `.env` and variants
   - Only `.env.example` should be in version control

4. **When adding new configuration:**
   - First add to `.env.example` with default value and documentation
   - Then reference in code via `process.env.VAR_NAME`
   - Code should work with just `.env.example` defaults

---

## Scope

### Applies To: Node.js Project (Root)
All code at the project root MUST follow this rule without exception.

### Does NOT Apply To: Lua Scripts (`Playroom/`)
The Lua scripts (SND macros) in `Playroom/` are designed to run in a third-party plugin (Something Need Doing) that has no access to the Node.js environment. Therefore, Lua scripts may contain hardcoded values as necessary.
