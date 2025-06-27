#!/usr/bin/env node

/**
 * AitherZero Tools for Claude Code
 * 
 * Simplified interface for executing AitherZero automation directly from Claude Code
 */

import { ClaudeCodeAdapter } from './claude-code-adapter.js';
import { join } from 'path';

// Initialize the adapter
const adapter = new ClaudeCodeAdapter();

// Export convenient functions for Claude Code to use
export const AitherTools = {
  /**
   * Run bulletproof validation tests
   * @param {string} level - 'Quick', 'Standard', or 'Complete'
   * @param {boolean} failFast - Stop on first failure
   */
  async runTests(level = 'Quick', failFast = false) {
    return await adapter.executeTool('aither_testing_framework', {
      validationLevel: level,
      failFast: failFast
    });
  },

  /**
   * Create a patch with automated Git workflow
   * @param {string} description - Description of changes
   * @param {Function|string} operation - Code to execute
   * @param {boolean} createPR - Create pull request
   */
  async createPatch(description, operation, createPR = false) {
    return await adapter.executeTool('aither_patch_workflow', {
      description,
      operation: typeof operation === 'function' ? operation.toString() : operation,
      createPR,
      createIssue: true
    });
  },

  /**
   * Manage lab environments
   * @param {string} action - 'start', 'stop', or 'status'
   * @param {string} configPath - Path to lab configuration
   */
  async manageLab(action = 'status', configPath = null) {
    return await adapter.executeTool('aither_lab_automation', {
      action,
      configPath
    });
  },

  /**
   * Backup operations
   * @param {string} action - 'backup', 'restore', 'cleanup', or 'status'
   * @param {Object} options - Action-specific options
   */
  async backup(action = 'status', options = {}) {
    return await adapter.executeTool('aither_backup_management', {
      action,
      ...options
    });
  },

  /**
   * Setup or validate development environment
   * @param {string} action - 'setup', 'validate', or 'status'
   */
  async devEnvironment(action = 'status') {
    return await adapter.executeTool('aither_dev_environment', {
      action
    });
  },

  /**
   * Infrastructure deployment operations
   * @param {string} action - 'plan', 'apply', 'destroy', or 'status'
   * @param {string} configPath - Path to infrastructure configuration
   * @param {boolean} autoApprove - Auto-approve changes (careful!)
   */
  async infrastructure(action = 'status', configPath = null, autoApprove = false) {
    return await adapter.executeTool('aither_infrastructure_deployment', {
      action,
      configPath,
      autoApprove
    });
  },

  /**
   * List all available tools
   */
  async listTools() {
    return await adapter.listTools();
  },

  /**
   * Execute any tool by name with custom arguments
   * @param {string} toolName - Name of the tool to execute
   * @param {Object} args - Tool-specific arguments
   */
  async executeTool(toolName, args = {}) {
    return await adapter.executeTool(toolName, args);
  }
};

// Quick access functions for common operations
export const quickTest = () => AitherTools.runTests('Quick', true);
export const standardTest = () => AitherTools.runTests('Standard', false);
export const completeTest = () => AitherTools.runTests('Complete', false);

// CLI interface when run directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const command = args[0];

  console.log('\n🛠️  AitherZero Tools CLI\n');

  switch (command) {
    case 'list':
      await AitherTools.listTools();
      break;
      
    case 'test':
      const level = args[1] || 'Quick';
      console.log(`Running ${level} validation...`);
      const testResult = await AitherTools.runTests(level);
      console.log(testResult);
      break;
      
    case 'dev':
      const devAction = args[1] || 'status';
      console.log(`Development environment: ${devAction}...`);
      const devResult = await AitherTools.devEnvironment(devAction);
      console.log(devResult);
      break;
      
    case 'help':
    default:
      console.log('Usage: node aither-tools.js <command> [options]\n');
      console.log('Commands:');
      console.log('  list              - List all available tools');
      console.log('  test [level]      - Run validation (Quick/Standard/Complete)');
      console.log('  dev [action]      - Manage dev environment (setup/validate/status)');
      console.log('  help              - Show this help message');
      console.log('\nExample:');
      console.log('  node aither-tools.js test Quick');
      console.log('  node aither-tools.js dev setup');
      break;
  }
}