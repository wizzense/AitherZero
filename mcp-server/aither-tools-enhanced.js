#!/usr/bin/env node

/**
 * Enhanced AitherZero Tools for Claude Code
 * 
 * This version includes automatic PowerShell 7 detection and installation
 */

import { EnhancedClaudeCodeAdapter } from './claude-code-adapter-enhanced.js';

// Initialize the enhanced adapter
const adapter = new EnhancedClaudeCodeAdapter();
let initialized = false;

// Auto-initialize on first use
async function ensureInitialized() {
  if (!initialized) {
    initialized = await adapter.initialize();
    if (!initialized) {
      console.log('\n⚠️  Some features may be limited without PowerShell 7.');
      console.log('   Run: node claude-code-adapter-enhanced.js --install-pwsh\n');
    }
  }
  return initialized;
}

// Export enhanced tools with auto-initialization
export const AitherTools = {
  /**
   * Initialize the adapter (called automatically on first use)
   */
  async initialize() {
    return await ensureInitialized();
  },

  /**
   * Check if PowerShell 7 is available
   */
  async checkPowerShell7() {
    await ensureInitialized();
    return adapter.isPowerShell7Available;
  },

  /**
   * Install PowerShell 7 if not available
   */
  async installPowerShell7() {
    if (adapter.platform === 'win32') {
      return await adapter.installPowerShell7();
    } else {
      console.log('ℹ️  Automatic installation is only available on Windows.');
      console.log('   For other platforms, please install manually:');
      console.log('   🐧 Linux: sudo apt install powershell  # or equivalent');
      console.log('   🍎 macOS: brew install powershell');
      return false;
    }
  },

  /**
   * Run bulletproof validation tests
   */
  async runTests(level = 'Quick', failFast = false) {
    await ensureInitialized();
    return await adapter.executeTool('aither_testing_framework', {
      validationLevel: level,
      failFast: failFast
    });
  },

  /**
   * Create a patch with automated Git workflow
   */
  async createPatch(description, operation, createPR = false) {
    await ensureInitialized();
    return await adapter.executeTool('aither_patch_workflow', {
      description,
      operation: typeof operation === 'function' ? operation.toString() : operation,
      createPR,
      createIssue: true
    });
  },

  /**
   * Manage lab environments
   */
  async manageLab(action = 'status', configPath = null) {
    await ensureInitialized();
    return await adapter.executeTool('aither_lab_automation', {
      action,
      configPath
    });
  },

  /**
   * Backup operations
   */
  async backup(action = 'status', options = {}) {
    await ensureInitialized();
    return await adapter.executeTool('aither_backup_management', {
      action,
      ...options
    });
  },

  /**
   * Setup or validate development environment
   */
  async devEnvironment(action = 'status') {
    await ensureInitialized();
    return await adapter.executeTool('aither_dev_environment', {
      action
    });
  },

  /**
   * Infrastructure deployment operations
   */
  async infrastructure(action = 'status', configPath = null, autoApprove = false) {
    await ensureInitialized();
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
    await ensureInitialized();
    return await adapter.listTools();
  },

  /**
   * Execute any tool by name with custom arguments
   */
  async executeTool(toolName, args = {}) {
    await ensureInitialized();
    return await adapter.executeTool(toolName, args);
  }
};

// Quick access functions
export const quickTest = () => AitherTools.runTests('Quick', true);
export const standardTest = () => AitherTools.runTests('Standard', false);
export const completeTest = () => AitherTools.runTests('Complete', false);

// CLI interface when run directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const command = args[0];

  console.log('\n🛠️  Enhanced AitherZero Tools CLI\n');

  switch (command) {
    case 'check':
      const hasPwsh = await AitherTools.checkPowerShell7();
      console.log(hasPwsh ? '✅ PowerShell 7 is available' : '❌ PowerShell 7 not found');
      break;

    case 'install':
      console.log('Installing PowerShell 7...');
      const installed = await AitherTools.installPowerShell7();
      console.log(installed ? '✅ Installation complete' : '❌ Installation failed');
      break;
      
    case 'list':
      await AitherTools.listTools();
      break;
      
    case 'test':
      const level = args[1] || 'Quick';
      console.log(`Running ${level} validation...`);
      try {
        const testResult = await AitherTools.runTests(level);
        console.log(testResult);
      } catch (error) {
        console.error('Test failed:', error.message);
      }
      break;
      
    case 'dev':
      const devAction = args[1] || 'status';
      console.log(`Development environment: ${devAction}...`);
      try {
        const devResult = await AitherTools.devEnvironment(devAction);
        console.log(devResult);
      } catch (error) {
        console.error('Operation failed:', error.message);
      }
      break;
      
    case 'help':
    default:
      console.log('Usage: node aither-tools-enhanced.js <command> [options]\n');
      console.log('Commands:');
      console.log('  check             - Check if PowerShell 7 is installed');
      console.log('  install           - Install PowerShell 7 (Windows only)');
      console.log('  list              - List all available tools');
      console.log('  test [level]      - Run validation (Quick/Standard/Complete)');
      console.log('  dev [action]      - Manage dev environment (setup/validate/status)');
      console.log('  help              - Show this help message');
      console.log('\nExamples:');
      console.log('  node aither-tools-enhanced.js check');
      console.log('  node aither-tools-enhanced.js install');
      console.log('  node aither-tools-enhanced.js test Quick');
      break;
  }
}