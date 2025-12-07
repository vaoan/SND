#!/usr/bin/env node
/**
 * Cross-platform wrapper script for Vercel MCP server
 *
 * Loads VERCEL_TOKEN from environment files and runs the MCP server.
 * Checks the following locations (in order):
 * 1. Project root: .env.local
 * 2. Script directory: .claude/tools/.env.local
 *
 * Uses @vercel/sdk - the OFFICIAL Vercel SDK with MCP server support.
 * GitHub: https://github.com/vercel/sdk
 * Provides ~95+ tools covering the full Vercel REST API.
 *
 * Requires VERCEL_TOKEN environment variable to be set.
 *
 * To get a Vercel token:
 * 1. Go to https://vercel.com/account/tokens
 * 2. Click "Create" to generate a new token
 * 3. Add to .env.local: VERCEL_TOKEN=your_token_here
 *
 * Requires Node.js v20 or greater.
 * Compatible with Windows, macOS, and Linux.
 */
/* global process */

import { spawn } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

// Get the directory where this script is located
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const scriptDir = __dirname;
// Go up two levels: .claude/tools/ -> .claude/ -> project root
const projectRoot = path.resolve(scriptDir, "..", "..");

// Change to project root
process.chdir(projectRoot);

// Function to load environment variables from .env.local
function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.split("\n");

  for (const line of lines) {
    // Skip comments and empty lines
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    // Match VERCEL_TOKEN=value
    const match = trimmed.match(/^VERCEL_TOKEN=(.+)$/);
    if (match) {
      // Remove quotes if present
      let token = match[1].trim();
      if (
        (token.startsWith('"') && token.endsWith('"')) ||
        (token.startsWith("'") && token.endsWith("'"))
      ) {
        token = token.slice(1, -1);
      }
      process.env.VERCEL_TOKEN = token;
      break;
    }
  }
}

// Load from project root .env.local
const projectEnvPath = path.join(projectRoot, ".env.local");
loadEnvFile(projectEnvPath);

// Also check .claude/tools/.env.local
const toolsEnvPath = path.join(scriptDir, ".env.local");
loadEnvFile(toolsEnvPath);

// Ensure token is available
const token = process.env.VERCEL_TOKEN;
if (!token) {
  console.error("Error: VERCEL_TOKEN not found.");
  console.error(
    "Please set VERCEL_TOKEN in .env.local or .claude/tools/.env.local",
  );
  console.error("Get a token at: https://vercel.com/account/tokens");
  process.exit(1);
}

// Run the official Vercel SDK MCP server with bearer token auth
// Using @vercel/sdk - official Vercel package
const args = [
  "-y",
  "--package",
  "@vercel/sdk",
  "--",
  "mcp",
  "start",
  "--bearer-token",
  token,
  ...process.argv.slice(2),
];

// On Windows, use shell: true to properly handle .cmd files
const spawnOptions = {
  stdio: "inherit",
  env: process.env,
  cwd: projectRoot,
  ...(process.platform === "win32" && { shell: true }),
};

const child = spawn("npx", args, spawnOptions);

child.on("error", (error) => {
  console.error("Error spawning Vercel MCP server:", error);
  process.exit(1);
});

child.on("exit", (code) => {
  process.exit(code || 0);
});
