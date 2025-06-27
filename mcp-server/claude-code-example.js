#!/usr/bin/env node

/**
 * Example: How Claude Code can use AitherZero tools
 * 
 * This demonstrates practical usage of the MCP server adapter
 */

import { AitherTools } from './aither-tools.js';

// Example 1: Run a quick test
console.log('📊 Example 1: Running Quick Validation Test\n');
console.log('// Run a quick validation test (30 seconds)');
console.log('const testResult = await AitherTools.runTests("Quick", true);\n');

// Example 2: Create a patch workflow
console.log('📝 Example 2: Creating a Patch with Git Workflow\n');
console.log(`// Create a patch that modifies a file
const patchResult = await AitherTools.createPatch(
  "Fix typo in documentation",
  \`
    # This PowerShell code will be executed
    $file = Join-Path $env:PROJECT_ROOT "README.md"
    (Get-Content $file) -replace 'teh', 'the' | Set-Content $file
  \`,
  true  // Create PR
);\n`);

// Example 3: Check development environment
console.log('🔧 Example 3: Development Environment Operations\n');
console.log('// Check current dev environment status');
console.log('const devStatus = await AitherTools.devEnvironment("status");');
console.log('');
console.log('// Setup development environment');
console.log('const devSetup = await AitherTools.devEnvironment("setup");\n');

// Example 4: Backup operations
console.log('💾 Example 4: Backup Management\n');
console.log(`// Create a backup
const backupResult = await AitherTools.backup("backup", {
  sourcePath: "./important-data",
  destinationPath: "./backups"
});

// Clean up old backups
const cleanupResult = await AitherTools.backup("cleanup", {
  retentionDays: 30
});\n`);

// Example 5: Infrastructure operations
console.log('🏗️ Example 5: Infrastructure Deployment\n');
console.log(`// Plan infrastructure changes
const planResult = await AitherTools.infrastructure("plan", "./configs/lab-config.json");

// Apply changes (careful with autoApprove!)
const applyResult = await AitherTools.infrastructure("apply", "./configs/lab-config.json", false);\n`);

// Example 6: Direct tool execution
console.log('🎯 Example 6: Direct Tool Execution\n');
console.log(`// Execute any tool directly with custom arguments
const result = await AitherTools.executeTool("aither_logging_system", {
  operation: "log",
  level: "INFO",
  message: "Claude Code successfully integrated with AitherZero!"
});\n`);

// Interactive demonstration
console.log('💡 Try It Now!\n');
console.log('To use these examples in Claude Code:');
console.log('1. Import the tools: import { AitherTools } from "./mcp-server/aither-tools.js"');
console.log('2. Use await with any of the tool methods');
console.log('3. Handle the JSON results returned by each tool\n');

// Actually run a simple test
console.log('🚀 Running a live demonstration...\n');

try {
  console.log('Checking development environment status...');
  const status = await AitherTools.devEnvironment('status');
  console.log('Result:', JSON.stringify(status, null, 2));
} catch (error) {
  console.log('Note: Some tools require the full AitherZero environment to be set up.');
  console.log('Error:', error.message);
}