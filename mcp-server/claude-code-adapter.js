#!/usr/bin/env node

/**
 * Claude Code Adapter for AitherZero MCP Server
 * 
 * This adapter allows Claude Code to directly execute AitherZero tools
 * without requiring the MCP protocol transport layer.
 */

import { spawn } from 'child_process';
import { promisify } from 'util';
import { readFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

class ClaudeCodeAdapter {
  constructor() {
    this.projectRoot = process.env.PROJECT_ROOT || join(__dirname, '..');
    this.toolDefinitions = null;
    this.loadToolDefinitions();
  }

  async loadToolDefinitions() {
    try {
      // Dynamically import the tool definitions
      const { ToolDefinitions } = await import('./src/tool-definitions.js');
      const toolDefs = new ToolDefinitions();
      this.toolDefinitions = toolDefs.getAllTools();
    } catch (error) {
      console.error('Failed to load tool definitions:', error);
      this.toolDefinitions = [];
    }
  }

  /**
   * List all available AitherZero tools
   */
  async listTools() {
    if (!this.toolDefinitions) {
      await this.loadToolDefinitions();
    }

    console.log('\n🛠️  Available AitherZero Tools:\n');
    
    this.toolDefinitions.forEach(tool => {
      console.log(`📌 ${tool.name}`);
      console.log(`   ${tool.description}`);
      if (tool.inputSchema?.properties) {
        console.log('   Parameters:');
        Object.entries(tool.inputSchema.properties).forEach(([key, schema]) => {
          const required = tool.inputSchema.required?.includes(key) ? ' (required)' : '';
          console.log(`     - ${key}: ${schema.description}${required}`);
        });
      }
      console.log('');
    });
  }

  /**
   * Execute a specific AitherZero tool
   */
  async executeTool(toolName, args = {}) {
    console.log(`\n🚀 Executing tool: ${toolName}\n`);

    try {
      // Generate the PowerShell script based on the tool
      const psScript = this.generatePowerShellScript(toolName, args);
      
      // Execute the PowerShell script
      const result = await this.executePowerShell(psScript);
      
      console.log('✅ Tool execution completed successfully\n');
      return result;
    } catch (error) {
      console.error(`❌ Tool execution failed: ${error.message}\n`);
      throw error;
    }
  }

  /**
   * Generate PowerShell script for the specific tool
   */
  generatePowerShellScript(toolName, args) {
    const scripts = {
      aither_patch_workflow: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force

        $params = @{
          PatchDescription = "${args.description || 'Automated patch via Claude Code'}"
        }
        
        ${args.createPR ? '$params.CreatePR = $true' : ''}
        ${args.createIssue === false ? '$params.CreateIssue = $false' : ''}
        ${args.priority ? `$params.Priority = "${args.priority}"` : ''}
        ${args.targetFork ? `$params.TargetFork = "${args.targetFork}"` : ''}
        
        ${args.operation ? `
        $params.PatchOperation = {
          ${args.operation}
        }` : ''}
        
        ${args.testCommands?.length ? `
        $params.TestCommands = @(${args.testCommands.map(cmd => `"${cmd}"`).join(', ')})
        ` : ''}

        Invoke-PatchWorkflow @params | ConvertTo-Json -Depth 10
      `,

      aither_testing_framework: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        
        $validationLevel = "${args.validationLevel || 'Quick'}"
        $ci = ${args.ci ? '$true' : '$false'}
        $failFast = ${args.failFast ? '$true' : '$false'}
        
        & (Join-Path $projectRoot "tests/Run-BulletproofValidation.ps1") -ValidationLevel $validationLevel ${ci ? '-CI' : ''} ${failFast ? '-FailFast' : ''} | ConvertTo-Json -Depth 10
      `,

      aither_lab_automation: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/LabRunner") -Force

        ${args.action === 'start' ? `
        Start-LabEnvironment -ConfigPath "${args.configPath || 'default'}" | ConvertTo-Json -Depth 10
        ` : args.action === 'stop' ? `
        Stop-LabEnvironment | ConvertTo-Json -Depth 10
        ` : args.action === 'status' ? `
        Get-LabStatus | ConvertTo-Json -Depth 10
        ` : `
        Write-Output @{Error = "Unknown action: ${args.action}"} | ConvertTo-Json
        `}
      `,

      aither_backup_management: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/BackupManager") -Force

        ${args.action === 'backup' ? `
        Start-Backup -SourcePath "${args.sourcePath}" -DestinationPath "${args.destinationPath || ''}" | ConvertTo-Json -Depth 10
        ` : args.action === 'cleanup' ? `
        Invoke-BackupCleanup -RetentionDays ${args.retentionDays || 30} | ConvertTo-Json -Depth 10
        ` : args.action === 'restore' ? `
        Restore-Backup -BackupPath "${args.backupPath}" -RestorePath "${args.restorePath || ''}" | ConvertTo-Json -Depth 10
        ` : `
        Get-BackupStatus | ConvertTo-Json -Depth 10
        `}
      `,

      aither_dev_environment: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/DevEnvironment") -Force

        ${args.action === 'setup' ? `
        Initialize-DevEnvironment | ConvertTo-Json -Depth 10
        ` : args.action === 'validate' ? `
        Test-DevEnvironment | ConvertTo-Json -Depth 10
        ` : `
        Get-DevEnvironmentStatus | ConvertTo-Json -Depth 10
        `}
      `,

      aither_infrastructure_deployment: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force

        ${args.action === 'plan' ? `
        Invoke-InfrastructurePlan -ConfigPath "${args.configPath || 'default'}" | ConvertTo-Json -Depth 10
        ` : args.action === 'apply' ? `
        Invoke-InfrastructureApply -ConfigPath "${args.configPath || 'default'}" ${args.autoApprove ? '-AutoApprove' : ''} | ConvertTo-Json -Depth 10
        ` : args.action === 'destroy' ? `
        Invoke-InfrastructureDestroy -ConfigPath "${args.configPath || 'default'}" ${args.autoApprove ? '-AutoApprove' : ''} | ConvertTo-Json -Depth 10
        ` : `
        Get-InfrastructureStatus | ConvertTo-Json -Depth 10
        `}
      `
    };

    const scriptGenerator = scripts[toolName];
    if (!scriptGenerator) {
      throw new Error(`Tool '${toolName}' is not yet implemented in Claude Code adapter`);
    }

    return scriptGenerator();
  }

  /**
   * Execute PowerShell script and return results
   */
  async executePowerShell(script) {
    return new Promise((resolve, reject) => {
      const ps = spawn('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], {
        cwd: this.projectRoot,
        env: {
          ...process.env,
          PROJECT_ROOT: this.projectRoot
        }
      });

      let stdout = '';
      let stderr = '';

      ps.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      ps.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      ps.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`PowerShell exited with code ${code}: ${stderr}`));
        } else {
          try {
            // Try to parse as JSON first
            const result = JSON.parse(stdout);
            resolve(result);
          } catch {
            // If not JSON, return as plain text
            resolve({ output: stdout });
          }
        }
      });

      ps.on('error', (err) => {
        reject(err);
      });
    });
  }

  /**
   * Interactive CLI for testing tools
   */
  async interactiveCLI() {
    console.log('\n🎯 AitherZero Tools - Claude Code Interface\n');
    console.log('This adapter allows Claude Code to execute AitherZero automation tools directly.\n');

    // Example usage
    console.log('📘 Example Usage:\n');
    console.log('const adapter = new ClaudeCodeAdapter();');
    console.log('await adapter.listTools();');
    console.log('const result = await adapter.executeTool("aither_testing_framework", { validationLevel: "Quick" });\n');

    // List available tools
    await this.listTools();

    console.log('💡 To use these tools programmatically, import this adapter in your scripts.\n');
  }
}

// Export for use as a module
export { ClaudeCodeAdapter };

// Run interactive CLI if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const adapter = new ClaudeCodeAdapter();
  adapter.interactiveCLI().catch(console.error);
}