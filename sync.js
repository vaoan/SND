require('dotenv').config();
const fs = require('fs');
const path = require('path');

const config = {
  sndConfigPath: process.env.SND_CONFIG_PATH,
  localScriptsRoot: process.env.LOCAL_SCRIPTS_ROOT || 'Playroom',
  sndTargetFolder: process.env.SND_TARGET_FOLDER || 'Synced',
};

// Validate config
function validateConfig() {
  if (!config.sndConfigPath) {
    console.error('ERROR: SND_CONFIG_PATH not set in .env');
    process.exit(1);
  }
  if (!fs.existsSync(config.sndConfigPath)) {
    console.error(`ERROR: SND config not found at: ${config.sndConfigPath}`);
    process.exit(1);
  }
}

// Read SND config JSON (handles BOM)
function readSndConfig() {
  let content = fs.readFileSync(config.sndConfigPath, 'utf8');
  // Remove BOM if present
  if (content.charCodeAt(0) === 0xFEFF) {
    content = content.slice(1);
  }
  return JSON.parse(content);
}

// Write SND config JSON (preserves BOM, compact format for SND compatibility)
function writeSndConfig(data) {
  const content = '\uFEFF' + JSON.stringify(data);
  fs.writeFileSync(config.sndConfigPath, content, 'utf8');
}

// Get macros from the target SND folder
function getSndMacros(sndConfig) {
  return sndConfig.Macros.filter(m => {
    // Match macros in target folder or subfolders
    return m.FolderPath === config.sndTargetFolder ||
           m.FolderPath.startsWith(config.sndTargetFolder + '/');
  });
}

// Convert SND folder path to local path
// e.g., "Synced/SubFolder" -> "Playroom/SubFolder"
function sndPathToLocal(sndFolderPath) {
  if (sndFolderPath === config.sndTargetFolder) {
    return config.localScriptsRoot;
  }
  const subPath = sndFolderPath.slice(config.sndTargetFolder.length + 1);
  return path.join(config.localScriptsRoot, subPath);
}

// Convert local path to SND folder path
// e.g., "Playroom/SubFolder" -> "Synced/SubFolder"
function localPathToSnd(localFolderPath) {
  if (localFolderPath === config.localScriptsRoot) {
    return config.sndTargetFolder;
  }
  const subPath = localFolderPath.slice(config.localScriptsRoot.length + 1);
  return subPath ? `${config.sndTargetFolder}/${subPath.replace(/\\/g, '/')}` : config.sndTargetFolder;
}

// Sanitize macro name for filename
function sanitizeFilename(name) {
  return name.replace(/[<>:"/\\|?*]/g, '_').replace(/\s+/g, '_');
}

// PULL: Sync from SND JSON -> Local Lua files
function pullFromSnd() {
  console.log('=== PULL: SND -> Local ===\n');

  validateConfig();
  const sndConfig = readSndConfig();
  const macros = getSndMacros(sndConfig);

  console.log(`Found ${macros.length} macros in "${config.sndTargetFolder}" folder\n`);

  let created = 0, updated = 0, unchanged = 0;

  for (const macro of macros) {
    const localFolder = sndPathToLocal(macro.FolderPath);
    const filename = sanitizeFilename(macro.Name) + '.lua';
    const localPath = path.join(localFolder, filename);

    // Ensure directory exists
    fs.mkdirSync(localFolder, { recursive: true });

    // Check if file exists and compare content
    if (fs.existsSync(localPath)) {
      const localContent = fs.readFileSync(localPath, 'utf8');
      if (localContent === macro.Content) {
        console.log(`  [unchanged] ${localPath}`);
        unchanged++;
        continue;
      }
      console.log(`  [updated]   ${localPath}`);
      updated++;
    } else {
      console.log(`  [created]   ${localPath}`);
      created++;
    }

    fs.writeFileSync(localPath, macro.Content, 'utf8');
  }

  console.log(`\nSummary: ${created} created, ${updated} updated, ${unchanged} unchanged`);
}

// PUSH: Sync from Local Lua files -> SND JSON
function pushToSnd() {
  console.log('=== PUSH: Local -> SND ===\n');

  validateConfig();
  const sndConfig = readSndConfig();

  // Find all local .lua files
  const localFiles = findLuaFiles(config.localScriptsRoot);
  console.log(`Found ${localFiles.length} local Lua files\n`);

  let created = 0, updated = 0, unchanged = 0;

  for (const localFile of localFiles) {
    const content = fs.readFileSync(localFile, 'utf8');
    const relativePath = path.relative(config.localScriptsRoot, localFile);
    const folderPath = path.dirname(relativePath);
    const filename = path.basename(localFile, '.lua');

    // Determine SND folder path
    const sndFolderPath = folderPath === '.'
      ? config.sndTargetFolder
      : `${config.sndTargetFolder}/${folderPath.replace(/\\/g, '/')}`;

    // Look for existing macro by name in the same folder
    const existingIndex = sndConfig.Macros.findIndex(m =>
      sanitizeFilename(m.Name) === filename && m.FolderPath === sndFolderPath
    );

    // Also check by exact name match
    const exactMatchIndex = existingIndex === -1
      ? sndConfig.Macros.findIndex(m => m.Name === filename && m.FolderPath === sndFolderPath)
      : existingIndex;

    const matchIndex = existingIndex !== -1 ? existingIndex : exactMatchIndex;

    if (matchIndex !== -1) {
      // Update existing macro
      if (sndConfig.Macros[matchIndex].Content === content) {
        console.log(`  [unchanged] ${relativePath}`);
        unchanged++;
        continue;
      }
      console.log(`  [updated]   ${relativePath} -> ${sndConfig.Macros[matchIndex].Name}`);
      sndConfig.Macros[matchIndex].Content = content;
      sndConfig.Macros[matchIndex].Metadata.LastModified = new Date().toISOString();
      updated++;
    } else {
      // Create new macro
      console.log(`  [created]   ${relativePath}`);
      const newMacro = createMacroEntry(filename, content, sndFolderPath);
      sndConfig.Macros.push(newMacro);
      created++;
    }
  }

  writeSndConfig(sndConfig);
  console.log(`\nSummary: ${created} created, ${updated} updated, ${unchanged} unchanged`);
}

// Find all .lua files recursively
function findLuaFiles(dir) {
  const files = [];

  if (!fs.existsSync(dir)) {
    return files;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...findLuaFiles(fullPath));
    } else if (entry.name.endsWith('.lua')) {
      files.push(fullPath);
    }
  }

  return files;
}

// Create a new macro entry
function createMacroEntry(name, content, folderPath) {
  return {
    Id: generateUuid(),
    Name: name,
    Type: 1, // Lua script
    Metadata: {
      TriggerEvents: [],
      CraftingLoop: false,
      CraftLoopCount: 0,
      Description: '',
      Author: '',
      Version: '1.0.0',
      LastModified: new Date().toISOString(),
      AdditionalData: {},
      Configs: {},
      AddonEventConfig: null,
      PluginDependecies: [],
      PluginsToDisable: [],
      Dependencies: []
    },
    FolderPath: folderPath,
    GitInfo: {
      RepositoryUrl: '',
      Owner: '',
      Repo: '',
      Branch: 'main',
      FilePath: '',
      CommitHash: '',
      AutoUpdate: true,
      CurrentVersion: '',
      LatestVersion: '',
      HasUpdate: false,
      LastUpdateCheck: '0001-01-01T00:00:00',
      VersionHistory: []
    },
    IsGitMacro: false,
    Content: content,
    State: 4 // Stopped
  };
}

// Generate UUID v4
function generateUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// STATUS: Show sync status
function showStatus() {
  console.log('=== SYNC STATUS ===\n');

  validateConfig();
  const sndConfig = readSndConfig();
  const sndMacros = getSndMacros(sndConfig);
  const localFiles = findLuaFiles(config.localScriptsRoot);

  console.log(`SND Config: ${config.sndConfigPath}`);
  console.log(`Local Root: ${config.localScriptsRoot}`);
  console.log(`SND Target: ${config.sndTargetFolder}\n`);

  console.log(`SND Macros in "${config.sndTargetFolder}": ${sndMacros.length}`);
  sndMacros.forEach(m => console.log(`  - ${m.Name} (${m.FolderPath})`));

  console.log(`\nLocal Lua files: ${localFiles.length}`);
  localFiles.forEach(f => console.log(`  - ${path.relative(config.localScriptsRoot, f)}`));
}

// CLI
const command = process.argv[2];

switch (command) {
  case 'pull':
    pullFromSnd();
    break;
  case 'push':
    pushToSnd();
    break;
  case 'status':
    showStatus();
    break;
  default:
    console.log('SND Sync Tool\n');
    console.log('Usage:');
    console.log('  node sync.js pull    - Pull macros from SND to local files');
    console.log('  node sync.js push    - Push local files to SND');
    console.log('  node sync.js status  - Show sync status');
}
