#!/usr/bin/env node

/**
 * Auto-build wrapper for AitherZero MCP Server
 * Automatically builds the server if needed, then starts it
 */

import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawnSync, spawn } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');
const distDir = join(rootDir, 'dist');
const distIndex = join(distDir, 'index.js');

// Check if server is built
if (!existsSync(distIndex)) {
  console.error('🔨 Building AitherZero MCP Server...');
  
  // Install dependencies if node_modules doesn't exist
  if (!existsSync(join(rootDir, 'node_modules'))) {
    console.error('📦 Installing dependencies...');
    const installResult = spawnSync('npm', ['install'], {
      cwd: rootDir,
      stdio: 'inherit',
      shell: true
    });
    
    if (installResult.status !== 0) {
      console.error('❌ Failed to install dependencies');
      process.exit(1);
    }
  }
  
  // Build the server
  const buildResult = spawnSync('npm', ['run', 'build'], {
    cwd: rootDir,
    stdio: 'inherit',
    shell: true
  });
  
  if (buildResult.status !== 0) {
    console.error('❌ Failed to build MCP server');
    process.exit(1);
  }
  
  console.error('✅ MCP Server built successfully');
}

// Start the server
const serverProcess = spawn('node', [distIndex], {
  stdio: 'inherit',
  shell: false
});

serverProcess.on('error', (error) => {
  console.error('❌ Server error:', error);
  process.exit(1);
});

serverProcess.on('exit', (code) => {
  process.exit(code || 0);
});
