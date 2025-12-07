#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a symlink from .cursor/mcp.json to .mcp.json for shared MCP configuration.

.DESCRIPTION
    This script creates a symbolic link so both Claude Code and Cursor use the same
    .mcp.json configuration file. Automatically requests elevation if needed.

.NOTES
    Run from project root or provide -ProjectRoot parameter.
#>

param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

# Paths
$mcpSource = Join-Path $ProjectRoot ".mcp.json"
$cursorDir = Join-Path $ProjectRoot ".cursor"
$mcpTarget = Join-Path $cursorDir "mcp.json"

# Check if source exists
if (-not (Test-Path $mcpSource)) {
    Write-Host "ERROR: .mcp.json not found at $mcpSource" -ForegroundColor Red
    exit 1
}

# Check if symlink already exists and is valid
if (Test-Path $mcpTarget) {
    $item = Get-Item $mcpTarget -Force
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "Symlink already exists: $mcpTarget -> $($item.Target)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Removing existing file (not a symlink): $mcpTarget" -ForegroundColor Yellow
        Remove-Item $mcpTarget -Force
    }
}

# Create .cursor directory if needed
if (-not (Test-Path $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    Write-Host "Created directory: $cursorDir" -ForegroundColor Cyan
}

# Check if we have admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Check if Developer Mode is enabled (allows symlinks without admin)
$devMode = $false
try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (Test-Path $regPath) {
        $devMode = (Get-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
    }
} catch {
    $devMode = $false
}

if (-not $isAdmin -and -not $devMode) {
    Write-Host "Elevation required. Requesting administrator privileges..." -ForegroundColor Yellow

    # Re-launch as admin
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ProjectRoot `"$ProjectRoot`""

    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -Wait
    exit $LASTEXITCODE
}

# Create the symlink
try {
    # Use relative path for cleaner symlink
    $relativePath = "..\.mcp.json"

    # cmd /c mklink works better on Windows
    $result = cmd /c mklink "$mcpTarget" "$relativePath" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: Created symlink" -ForegroundColor Green
        Write-Host "  $mcpTarget -> $relativePath" -ForegroundColor Cyan
    } else {
        throw "mklink failed: $result"
    }
} catch {
    Write-Host "ERROR: Failed to create symlink: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nDone! Both Claude Code and Cursor will now use .mcp.json" -ForegroundColor Green
