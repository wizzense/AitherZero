#!/usr/bin/env node

/**
 * Enhanced Claude Code Adapter for AitherZero MCP Server
 * 
 * This version includes automatic PowerShell 7 detection and installation
 */

import { spawn, execSync } from 'child_process';
import { promisify } from 'util';
import { readFile, writeFile, mkdir } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';
import { platform, tmpdir } from 'os';
import https from 'https';
import { createWriteStream } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

class EnhancedClaudeCodeAdapter {
  constructor() {
    this.projectRoot = process.env.PROJECT_ROOT || join(__dirname, '..');
    this.toolDefinitions = null;
    this.pwshCommand = null;
    this.isPowerShell7Available = false;
    this.platform = platform();
  }

  /**
   * Initialize the adapter and check for PowerShell 7
   */
  async initialize() {
    console.log('🔍 Initializing Claude Code Adapter...\n');
    
    // Check for PowerShell 7
    this.isPowerShell7Available = await this.checkPowerShell7();
    
    if (!this.isPowerShell7Available) {
      console.log('⚠️  PowerShell 7 not found. Would you like to install it?\n');
      const canInstall = await this.canAutoInstallPowerShell7();
      
      if (canInstall) {
        console.log('📦 Installing PowerShell 7...\n');
        const installed = await this.installPowerShell7();
        if (installed) {
          this.isPowerShell7Available = await this.checkPowerShell7();
        }
      } else {
        console.log('ℹ️  PowerShell 7 installation is required for full functionality.');
        console.log('   Please install it manually from: https://github.com/PowerShell/PowerShell\n');
      }
    }

    // Load tool definitions
    await this.loadToolDefinitions();
    
    return this.isPowerShell7Available;
  }

  /**
   * Check if PowerShell 7 is available
   */
  async checkPowerShell7() {
    const commands = ['pwsh', 'pwsh.exe', 'powershell'];
    
    for (const cmd of commands) {
      try {
        const result = execSync(`${cmd} -Version`, { encoding: 'utf8' });
        if (result.includes('PowerShell 7')) {
          this.pwshCommand = cmd;
          console.log(`✅ PowerShell 7 found: ${cmd}\n`);
          return true;
        }
      } catch (e) {
        // Command not found, continue checking
      }
    }
    
    return false;
  }

  /**
   * Check if we can auto-install PowerShell 7 on this platform
   */
  async canAutoInstallPowerShell7() {
    // Currently, auto-installation is only supported on Windows
    return this.platform === 'win32';
  }

  /**
   * Install PowerShell 7 (Windows only for now)
   */
  async installPowerShell7() {
    if (this.platform !== 'win32') {
      console.log('❌ Automatic installation is currently only supported on Windows.');
      console.log('   For other platforms, please install PowerShell 7 manually:\n');
      console.log('   🐧 Linux: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux');
      console.log('   🍎 macOS: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos\n');
      return false;
    }

    try {
      // Download PowerShell 7 installer
      const pwshUrl = 'https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.6-win-x64.msi';
      const installerPath = join(tmpdir(), 'PowerShell-7-Installer.msi');
      
      console.log('📥 Downloading PowerShell 7 installer...');
      await this.downloadFile(pwshUrl, installerPath);
      
      console.log('🔧 Installing PowerShell 7 (this may take a moment)...');
      
      // Run MSI installer silently
      const installCmd = `msiexec.exe /i "${installerPath}" /quiet /norestart`;
      execSync(installCmd, { stdio: 'inherit' });
      
      // Clean up installer
      if (existsSync(installerPath)) {
        require('fs').unlinkSync(installerPath);
      }
      
      console.log('✅ PowerShell 7 installed successfully!\n');
      
      // Update PATH for current session
      const pwshPath = 'C:\\Program Files\\PowerShell\\7';
      if (existsSync(pwshPath)) {
        process.env.PATH = `${pwshPath};${process.env.PATH}`;
      }
      
      return true;
    } catch (error) {
      console.error('❌ Failed to install PowerShell 7:', error.message);
      return false;
    }
  }

  /**
   * Download a file from URL
   */
  async downloadFile(url, destination) {
    return new Promise((resolve, reject) => {
      const file = createWriteStream(destination);
      
      https.get(url, (response) => {
        if (response.statusCode === 302 || response.statusCode === 301) {
          // Handle redirect
          https.get(response.headers.location, (redirectResponse) => {
            redirectResponse.pipe(file);
          });
        } else {
          response.pipe(file);
        }
        
        file.on('finish', () => {
          file.close();
          resolve();
        });
      }).on('error', (err) => {
        file.close();
        require('fs').unlinkSync(destination);
        reject(err);
      });
    });
  }

  /**
   * Fallback: Generate PowerShell bootstrap script
   */
  async generateBootstrapScript() {
    const bootstrapScript = `
# Auto-generated PowerShell 7 bootstrap script
# This script will download and run the AitherZero bootstrap

$ErrorActionPreference = 'Stop'

Write-Host "🚀 Bootstrapping AitherZero with PowerShell 7 installation..." -ForegroundColor Cyan

# Download and run bootstrap script
$bootstrapUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero/main/Bootstrap-AitherZero.ps1'
$bootstrapContent = Invoke-WebRequest -Uri $bootstrapUrl -UseBasicParsing | Select-Object -ExpandProperty Content

# Execute bootstrap with PowerShell 7 installation
Invoke-Expression $bootstrapContent

Write-Host "✅ Bootstrap complete!" -ForegroundColor Green
`;

    const scriptPath = join(this.projectRoot, 'mcp-server', 'bootstrap-pwsh7.ps1');
    await writeFile(scriptPath, bootstrapScript, 'utf8');
    
    console.log('\n📝 Generated bootstrap script: bootstrap-pwsh7.ps1');
    console.log('   Run this script with your existing PowerShell to install PowerShell 7:');
    console.log(`   powershell.exe -ExecutionPolicy Bypass -File "${scriptPath}"\n`);
    
    return scriptPath;
  }

  async loadToolDefinitions() {
    try {
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
    
    if (!this.isPowerShell7Available) {
      console.log('⚠️  Note: PowerShell 7 is required to execute these tools.');
      console.log('   Run this adapter with --install-pwsh to install it automatically.\n');
    }
  }

  /**
   * Execute a specific AitherZero tool
   */
  async executeTool(toolName, args = {}) {
    if (!this.isPowerShell7Available) {
      console.log('\n❌ PowerShell 7 is required to execute tools.');
      console.log('   Please install it first by running: node claude-code-adapter-enhanced.js --install-pwsh\n');
      throw new Error('PowerShell 7 not available');
    }

    console.log(`\n🚀 Executing tool: ${toolName}\n`);

    try {
      const psScript = this.generatePowerShellScript(toolName, args);
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
    // Use the same script generation from the original adapter
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
      const ps = spawn(this.pwshCommand, ['-NoProfile', '-NonInteractive', '-Command', script], {
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
            const result = JSON.parse(stdout);
            resolve(result);
          } catch {
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
    console.log('\n🎯 AitherZero Tools - Enhanced Claude Code Interface\n');
    
    const args = process.argv.slice(2);
    
    if (args.includes('--install-pwsh')) {
      await this.installPowerShell7();
      return;
    }
    
    if (args.includes('--bootstrap')) {
      await this.generateBootstrapScript();
      return;
    }
    
    // Initialize and check PowerShell 7
    const initialized = await this.initialize();
    
    if (args.includes('--list')) {
      await this.listTools();
      return;
    }
    
    if (!initialized) {
      console.log('💡 Tip: Use --install-pwsh flag to attempt automatic installation.\n');
    } else {
      console.log('💡 PowerShell 7 is ready! You can now use all AitherZero tools.\n');
      await this.listTools();
    }
  }
}

// Export for use as a module
export { EnhancedClaudeCodeAdapter };

// Run interactive CLI if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const adapter = new EnhancedClaudeCodeAdapter();
  adapter.interactiveCLI().catch(console.error);
}