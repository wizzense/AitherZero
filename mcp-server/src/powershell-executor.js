/**
 * PowerShell execution handler for AitherZero MCP Server
 */

import { spawn } from 'child_process';
import path from 'path';

export class PowerShellExecutor {
  constructor() {
    this.defaultTimeout = 300000; // 5 minutes
  }

  async execute(script, options = {}) {
    const {
      timeout = this.defaultTimeout,
      workingDirectory = process.cwd(),
      environment = {}
    } = options;

    return new Promise((resolve, reject) => {
      const startTime = Date.now();

      // Use pwsh (PowerShell 7+) if available, fallback to powershell
      const psCommand = process.platform === 'win32' ? 'pwsh' : 'pwsh';

      const psProcess = spawn(psCommand, ['-Command', script], {
        cwd: workingDirectory,
        env: { ...process.env, ...environment },
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: true
      });

      let stdout = '';
      let stderr = '';
      let timedOut = false;

      // Set up timeout
      const timeoutHandle = setTimeout(() => {
        timedOut = true;
        psProcess.kill('SIGTERM');
      }, timeout);

      // Collect output
      psProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      psProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      psProcess.on('close', (code) => {
        clearTimeout(timeoutHandle);

        const endTime = Date.now();
        const executionTime = endTime - startTime;

        if (timedOut) {
          reject(new Error(`PowerShell script execution timed out after ${timeout}ms`));
          return;
        }

        const result = {
          exitCode: code,
          output: stdout,
          error: stderr,
          hadErrors: code !== 0 || stderr.length > 0,
          executionTime: executionTime
        };

        resolve(result);
      });

      psProcess.on('error', (error) => {
        clearTimeout(timeoutHandle);
        reject(new Error(`Failed to start PowerShell process: ${error.message}`));
      });
    });
  }

  async validatePowerShellAvailability() {
    try {
      const result = await this.execute('$PSVersionTable.PSVersion');
      if (result.hadErrors) {
        throw new Error('PowerShell validation failed');
      }
      return true;
    } catch (error) {
      throw new Error(`PowerShell not available: ${error.message}`);
    }
  }

  async getAitherZeroModuleStatus() {
    const script = `
    try {
      # Import Find-ProjectRoot utility
      $projectRoot = Split-Path $PWD -Parent
      if (Test-Path "$projectRoot/aither-core/shared/Find-ProjectRoot.ps1") {
        . "$projectRoot/aither-core/shared/Find-ProjectRoot.ps1"
        $script:ProjectRoot = Find-ProjectRoot
      } else {
        $script:ProjectRoot = $projectRoot
      }

      # Check module availability
      $modulesPath = "$script:ProjectRoot/aither-core/modules"
      if (Test-Path $modulesPath) {
        $modules = Get-ChildItem $modulesPath -Directory | Select-Object Name
        @{
          ProjectRoot = $script:ProjectRoot
          ModulesPath = $modulesPath
          AvailableModules = ($modules | ForEach-Object { $_.Name })
          Status = "Available"
        } | ConvertTo-Json -Depth 5
      } else {
        @{
          Status = "ModulesNotFound"
          SearchedPath = $modulesPath
        } | ConvertTo-Json -Depth 5
      }
    } catch {
      @{
        Status = "Error"
        Error = $_.Exception.Message
      } | ConvertTo-Json -Depth 5
    }
    `;

    return await this.execute(script);
  }

  escapeForPowerShell(value) {
    if (typeof value === 'string') {
      // Escape single quotes by doubling them
      return value.replace(/'/g, "''");
    }
    return value;
  }

  buildParameterString(params) {
    const paramParts = [];

    for (const [key, value] of Object.entries(params)) {
      if (value === true) {
        paramParts.push(`-${key}`);
      } else if (value === false) {
        // Don't add boolean false parameters
        continue;
      } else if (Array.isArray(value)) {
        const arrayString = value.map(v => `'${this.escapeForPowerShell(v)}'`).join(', ');
        paramParts.push(`-${key} @(${arrayString})`);
      } else if (typeof value === 'object') {
        // Convert object to hashtable syntax
        const hashtableString = Object.entries(value)
          .map(([k, v]) => `'${k}' = '${this.escapeForPowerShell(v)}'`)
          .join('; ');
        paramParts.push(`-${key} @{${hashtableString}}`);
      } else {
        paramParts.push(`-${key} '${this.escapeForPowerShell(value)}'`);
      }
    }

    return paramParts.join(' ');
  }
}
