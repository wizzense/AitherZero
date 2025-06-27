#!/usr/bin/env node

/**
 * Claude Code MCP Server
 * 
 * This is a simplified MCP server implementation that works with Claude Code
 * without requiring the full MCP protocol transport layer.
 */

import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';
import { tmpdir } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Import tool definitions
import { ToolDefinitions } from './src/tool-definitions.js';

class ClaudeCodeMCPServer {
  constructor() {
    this.projectRoot = process.env.PROJECT_ROOT || join(__dirname, '..');
    this.toolDefs = new ToolDefinitions();
    this.tools = this.toolDefs.getAllTools();
  }

  /**
   * List all available tools in MCP format
   */
  listTools() {
    return {
      tools: this.tools.map(tool => ({
        name: tool.name,
        description: tool.description,
        inputSchema: tool.inputSchema
      }))
    };
  }

  /**
   * Execute a tool and return MCP-formatted response
   */
  async callTool(toolName, args = {}) {
    try {
      // Find the tool
      const tool = this.tools.find(t => t.name === toolName);
      if (!tool) {
        throw new Error(`Unknown tool: ${toolName}`);
      }

      // Generate and execute PowerShell script
      const psScript = this.generatePowerShellScript(toolName, args);
      const result = await this.executePowerShell(psScript);

      return {
        content: [
          {
            type: 'text',
            text: this.formatResult(result)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error: ${error.message}`
          }
        ],
        isError: true
      };
    }
  }

  /**
   * Generate PowerShell script based on tool and arguments
   */
  generatePowerShellScript(toolName, args) {
    const scriptGenerators = {
      aither_patch_workflow: () => `
        $ErrorActionPreference = 'Stop'
        $projectRoot = "${this.projectRoot}"
        if (Test-Path (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")) {
          . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
          $projectRoot = Find-ProjectRoot
        }
        Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force

        $params = @{
          PatchDescription = "${args.description || 'Automated patch'}"
        }
        ${args.createPR ? '$params.CreatePR = $true' : ''}
        ${args.createIssue === false ? '$params.CreateIssue = $false' : ''}
        ${args.operation ? `$params.PatchOperation = { ${args.operation} }` : ''}

        Invoke-PatchWorkflow @params | ConvertTo-Json -Depth 10
      `,

      aither_testing_framework: () => `
        $ErrorActionPreference = 'Stop'
        $projectRoot = "${this.projectRoot}"
        if (Test-Path (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")) {
          . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
          $projectRoot = Find-ProjectRoot
        }
        
        & (Join-Path $projectRoot "tests/Run-BulletproofValidation.ps1") \\
          -ValidationLevel "${args.validationLevel || 'Quick'}" \\
          ${args.ci ? '-CI' : ''} \\
          ${args.failFast ? '-FailFast' : ''} | ConvertTo-Json -Depth 10
      `,

      aither_dev_environment: () => `
        $ErrorActionPreference = 'Stop'
        $projectRoot = "${this.projectRoot}"
        if (Test-Path (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")) {
          . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
          $projectRoot = Find-ProjectRoot
        }
        Import-Module (Join-Path $projectRoot "aither-core/modules/DevEnvironment") -Force

        ${args.operation === 'setup' ? 'Initialize-DevEnvironment' : 
          args.operation === 'validate' ? 'Test-DevEnvironment' : 
          'Get-DevEnvironmentStatus'} | ConvertTo-Json -Depth 10
      `,

      aither_lab_automation: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/LabRunner") -Force

        ${args.operation === 'start' ? `Start-LabEnvironment -ConfigPath "${args.configPath || 'default'}"` :
          args.operation === 'stop' ? 'Stop-LabEnvironment' :
          args.operation === 'status' ? 'Get-LabStatus' :
          'Get-LabStatus'} | ConvertTo-Json -Depth 10
      `,

      aither_backup_management: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/BackupManager") -Force

        ${args.operation === 'backup' ? `Start-Backup -SourcePath "${args.path}"` :
          args.operation === 'cleanup' ? `Invoke-BackupCleanup -RetentionDays ${args.retentionDays || 30}` :
          'Get-BackupStatus'} | ConvertTo-Json -Depth 10
      `,

      aither_infrastructure_deployment: () => `
        $ErrorActionPreference = 'Stop'
        . "${this.projectRoot}/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force

        ${args.operation === 'plan' ? `Invoke-InfrastructurePlan -ConfigPath "${args.configPath || 'default'}"` :
          args.operation === 'apply' ? `Invoke-InfrastructureApply -ConfigPath "${args.configPath || 'default'}" ${args.autoApprove ? '-AutoApprove' : ''}` :
          args.operation === 'destroy' ? `Invoke-InfrastructureDestroy -ConfigPath "${args.configPath || 'default'}" ${args.autoApprove ? '-AutoApprove' : ''}` :
          'Get-InfrastructureStatus'} | ConvertTo-Json -Depth 10
      `
    };

    const generator = scriptGenerators[toolName];
    if (!generator) {
      // For tools not yet implemented, return a placeholder
      return `Write-Output @{message="Tool ${toolName} execution simulated"; args=$(ConvertFrom-Json '${JSON.stringify(args)}')} | ConvertTo-Json`;
    }

    return generator();
  }

  /**
   * Execute PowerShell script
   */
  async executePowerShell(script) {
    // First check if PowerShell 7 is available
    let pwshCommand = await this.findPowerShell();
    if (!pwshCommand) {
      console.log('⚠️  PowerShell 7 not found. Installing...\n');
      const installed = await this.installPowerShell7();
      if (installed) {
        pwshCommand = await this.findPowerShell();
      }
      if (!pwshCommand) {
        throw new Error('Failed to install PowerShell 7. Please install manually.');
      }
    }

    return new Promise((resolve, reject) => {
      const ps = spawn(pwshCommand, ['-NoProfile', '-NonInteractive', '-Command', script], {
        cwd: this.projectRoot,
        env: { ...process.env, PROJECT_ROOT: this.projectRoot }
      });

      let stdout = '';
      let stderr = '';

      ps.stdout.on('data', (data) => stdout += data.toString());
      ps.stderr.on('data', (data) => stderr += data.toString());

      ps.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`PowerShell error: ${stderr}`));
        } else {
          try {
            resolve(JSON.parse(stdout));
          } catch {
            resolve({ output: stdout });
          }
        }
      });

      ps.on('error', reject);
    });
  }

  /**
   * Find PowerShell command
   */
  async findPowerShell() {
    const commands = ['pwsh', 'pwsh.exe', 'powershell'];
    for (const cmd of commands) {
      try {
        const { execSync } = await import('child_process');
        execSync(`${cmd} -Version`, { stdio: 'ignore' });
        return cmd;
      } catch {
        continue;
      }
    }
    return null;
  }

  /**
   * Install PowerShell 7
   */
  async installPowerShell7() {
    const { platform } = await import('os');
    const { execSync } = await import('child_process');
    const os = platform();

    try {
      if (os === 'win32') {
        // Windows installation
        console.log('📥 Downloading PowerShell 7 for Windows...');
        const installerUrl = 'https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.6-win-x64.msi';
        const installerPath = join(tmpdir(), 'PowerShell-7-Installer.msi');
        
        // Download installer
        await this.downloadFile(installerUrl, installerPath);
        
        // Install silently
        console.log('🔧 Installing PowerShell 7...');
        execSync(`msiexec.exe /i "${installerPath}" /quiet /norestart`, { stdio: 'inherit' });
        
        // Clean up
        if (existsSync(installerPath)) {
          const { unlinkSync } = await import('fs');
          unlinkSync(installerPath);
        }
        
        // Update PATH
        process.env.PATH = `C:\\Program Files\\PowerShell\\7;${process.env.PATH}`;
        
        console.log('✅ PowerShell 7 installed successfully!\n');
        return true;
        
      } else if (os === 'linux') {
        // Linux installation
        console.log('📥 Installing PowerShell 7 for Linux...');
        
        // Try to detect the Linux distribution
        try {
          const osRelease = execSync('cat /etc/os-release', { encoding: 'utf8' });
          
          if (osRelease.includes('Ubuntu') || osRelease.includes('Debian')) {
            // Ubuntu/Debian installation
            console.log('Detected Ubuntu/Debian. Installing via apt...');
            execSync('wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb', { stdio: 'inherit' });
            execSync('sudo dpkg -i packages-microsoft-prod.deb', { stdio: 'inherit' });
            execSync('sudo apt-get update', { stdio: 'inherit' });
            execSync('sudo apt-get install -y powershell', { stdio: 'inherit' });
            execSync('rm packages-microsoft-prod.deb', { stdio: 'inherit' });
            
          } else if (osRelease.includes('Red Hat') || osRelease.includes('CentOS') || osRelease.includes('Fedora')) {
            // RHEL/CentOS/Fedora installation
            console.log('Detected RHEL/CentOS/Fedora. Installing via yum...');
            execSync('curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo', { stdio: 'inherit' });
            execSync('sudo yum install -y powershell', { stdio: 'inherit' });
            
          } else {
            // Generic Linux installation via snap
            console.log('Using snap to install PowerShell...');
            execSync('sudo snap install powershell --classic', { stdio: 'inherit' });
          }
          
          console.log('✅ PowerShell 7 installed successfully!\n');
          return true;
          
        } catch (error) {
          console.error('Failed to auto-install on Linux:', error.message);
          console.log('Please install manually:');
          console.log('  Ubuntu/Debian: sudo apt install powershell');
          console.log('  RHEL/Fedora: sudo yum install powershell');
          console.log('  Others: sudo snap install powershell --classic');
          return false;
        }
        
      } else if (os === 'darwin') {
        // macOS installation
        console.log('📥 Installing PowerShell 7 for macOS...');
        
        try {
          // Check if Homebrew is installed
          execSync('which brew', { stdio: 'ignore' });
          console.log('Installing via Homebrew...');
          execSync('brew install --cask powershell', { stdio: 'inherit' });
          console.log('✅ PowerShell 7 installed successfully!\n');
          return true;
          
        } catch {
          console.log('Homebrew not found. Please install PowerShell manually:');
          console.log('  1. Install Homebrew: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"');
          console.log('  2. Install PowerShell: brew install --cask powershell');
          return false;
        }
      }
      
    } catch (error) {
      console.error('Installation failed:', error.message);
      return false;
    }
  }

  /**
   * Download file helper
   */
  async downloadFile(url, destination) {
    const https = await import('https');
    const { createWriteStream } = await import('fs');
    
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
        const { unlinkSync } = require('fs');
        unlinkSync(destination);
        reject(err);
      });
    });
  }

  /**
   * Format result for display
   */
  formatResult(result) {
    if (typeof result === 'string') {
      return result;
    }
    return JSON.stringify(result, null, 2);
  }
}

// Export the server class
export { ClaudeCodeMCPServer };

// Create global instance for Claude Code to use
const server = new ClaudeCodeMCPServer();

// Export convenient functions that Claude Code can call directly
export const MCPTools = {
  list: () => server.listTools(),
  call: (toolName, args) => server.callTool(toolName, args)
};

// CLI interface for testing
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  
  if (args[0] === 'list') {
    console.log(JSON.stringify(server.listTools(), null, 2));
  } else if (args[0] === 'call' && args[1]) {
    const toolName = args[1];
    const toolArgs = args[2] ? JSON.parse(args[2]) : {};
    server.callTool(toolName, toolArgs)
      .then(result => console.log(JSON.stringify(result, null, 2)))
      .catch(error => console.error(error));
  } else {
    console.log('Usage:');
    console.log('  node claude-code-mcp-server.js list');
    console.log('  node claude-code-mcp-server.js call <tool-name> [args-json]');
    console.log('\nExample:');
    console.log('  node claude-code-mcp-server.js call aither_testing_framework \'{"validationLevel":"Quick"}\'');
  }
}