#!/usr/bin/env node
/**
 * Cross-platform wrapper script for GitHub MCP server
 *
 * Loads GITHUB_PERSONAL_ACCESS_TOKEN from environment files and runs the MCP server.
 * Checks the following locations (in order):
 * 1. Project root: .env.local
 * 2. Script directory: .claude/tools/.env.local
 *
 * Uses @modelcontextprotocol/server-github package via npx.
 * Requires GITHUB_PERSONAL_ACCESS_TOKEN environment variable to be set.
 *
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

    // Match GITHUB_PERSONAL_ACCESS_TOKEN=value
    const match = trimmed.match(/^GITHUB_PERSONAL_ACCESS_TOKEN=(.+)$/);
    if (match) {
      // Remove quotes if present
      let token = match[1].trim();
      if (
        (token.startsWith('"') && token.endsWith('"')) ||
        (token.startsWith("'") && token.endsWith("'"))
      ) {
        token = token.slice(1, -1);
      }
      process.env.GITHUB_PERSONAL_ACCESS_TOKEN = token;
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

// Run the GitHub MCP server
const args = [
  "-y",
  "@modelcontextprotocol/server-github",
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
  console.error("Error spawning GitHub MCP server:", error);
  process.exit(1);
});

child.on("exit", (code) => {
  process.exit(code || 0);
});
