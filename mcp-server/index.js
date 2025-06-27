#!/usr/bin/env node

/**
 * AitherZero MCP Server
 * Exposes the comprehensive AitherZero infrastructure automation framework
 * as Model Context Protocol tools for AI agents
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import { PowerShellExecutor } from './src/powershell-executor.js';
import { ToolDefinitions } from './src/tool-definitions.js';
import { ValidationSchema } from './src/validation-schema.js';
import { Logger } from './src/logger.js';

class AitherZeroMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'aitherzero-mcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.psExecutor = new PowerShellExecutor();
    this.logger = new Logger();
    this.toolDefs = new ToolDefinitions();
    this.validator = new ValidationSchema();

    this.setupHandlers();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: this.toolDefs.getAllTools(),
      };
    });

    // Execute tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        const { name, arguments: args } = request.params;

        this.logger.info(`Tool called: ${name}`, { args });

        // Validate tool exists
        const tool = this.toolDefs.getTool(name);
        if (!tool) {
          throw new Error(`Unknown tool: ${name}`);
        }

        // Validate arguments
        const validation = this.validator.validateArgs(name, args || {});
        if (!validation.valid) {
          throw new Error(`Invalid arguments: ${validation.errors.join(', ')}`);
        }

        // Execute the tool
        const result = await this.executeTool(name, args || {});

        this.logger.info(`Tool execution completed: ${name}`, { success: true });

        return {
          content: [
            {
              type: 'text',
              text: this.formatResult(result),
            },
          ],
        };
      } catch (error) {
        this.logger.error(`Tool execution failed: ${request.params.name}`, error);

        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async executeTool(toolName, args) {
    const psScript = this.generatePowerShellScript(toolName, args);
    const result = await this.psExecutor.execute(psScript);

    return {
      toolName,
      success: result.hadErrors === false,
      output: result.output,
      errors: result.hadErrors ? result.error : null,
      metadata: {
        executionTime: result.executionTime,
        timestamp: new Date().toISOString(),
      },
    };
  }

  generatePowerShellScript(toolName, args) {
    // Base script template that sets up the AitherZero environment
    const baseScript = `
# AitherZero MCP Tool Execution Script
# Tool: ${toolName}
$ErrorActionPreference = 'Stop'

# Import Find-ProjectRoot utility
$projectRoot = "${process.cwd().replace(/\\/g, '/')}/aither-core"
. "$projectRoot/shared/Find-ProjectRoot.ps1"
$script:ProjectRoot = Find-ProjectRoot

# Import required modules
Import-Module "$script:ProjectRoot/aither-core/modules/Logging" -Force
`;

    // Add tool-specific PowerShell code
    switch (toolName) {
      case 'aither_patch_workflow':
        return baseScript + this.generatePatchWorkflowScript(args);

      case 'aither_lab_automation':
        return baseScript + this.generateLabAutomationScript(args);

      case 'aither_backup_management':
        return baseScript + this.generateBackupManagementScript(args);

      case 'aither_dev_environment':
        return baseScript + this.generateDevEnvironmentScript(args);

      case 'aither_iso_management':
        return baseScript + this.generateISOManagementScript(args);

      case 'aither_testing_framework':
        return baseScript + this.generateTestingFrameworkScript(args);

      case 'aither_infrastructure_deployment':
        return baseScript + this.generateInfrastructureScript(args);

      case 'aither_remote_connection':
        return baseScript + this.generateRemoteConnectionScript(args);

      case 'aither_credential_management':
        return baseScript + this.generateCredentialManagementScript(args);

      case 'aither_logging_system':
        return baseScript + this.generateLoggingSystemScript(args);

      case 'aither_parallel_execution':
        return baseScript + this.generateParallelExecutionScript(args);

      case 'aither_script_management':
        return baseScript + this.generateScriptManagementScript(args);

      case 'aither_maintenance_operations':
        return baseScript + this.generateMaintenanceOperationsScript(args);

      case 'aither_repo_sync':
        return baseScript + this.generateRepoSyncScript(args);

      default:
        throw new Error(`No PowerShell implementation for tool: ${toolName}`);
    }
  }

  generatePatchWorkflowScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/PatchManager" -Force

try {
    $params = @{
        PatchDescription = "${args.description || 'MCP-initiated patch'}"
        ${args.createPR ? 'CreatePR = $true' : ''}
        ${args.createIssue ? 'CreateIssue = $true' : 'CreateIssue = $false'}
        ${args.priority ? `Priority = "${args.priority}"` : ''}
        ${args.targetFork ? `TargetFork = "${args.targetFork}"` : ''}
    }

    if ("${args.operation}") {
        $params.PatchOperation = {
            ${args.operation}
        }
    }

    ${args.testCommands ? `$params.TestCommands = @(${args.testCommands.map(cmd => `"${cmd}"`).join(', ')})` : ''}

    $result = Invoke-PatchWorkflow @params
    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateLabAutomationScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/LabRunner" -Force

try {
    $params = @{
        ${args.configPath ? `ConfigPath = "${args.configPath}"` : ''}
        ${args.labName ? `LabName = "${args.labName}"` : ''}
        ${args.steps ? `Steps = @(${args.steps.map(step => `"${step}"`).join(', ')})` : ''}
        ${args.parallel ? 'Parallel = $true' : ''}
        ${args.verbosity ? `Verbosity = "${args.verbosity}"` : ''}
    }

    $result = Start-LabAutomation @params
    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateBackupManagementScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/BackupManager" -Force

try {
    switch ("${args.operation}") {
        "consolidate" {
            $result = Invoke-BackupConsolidation
        }
        "cleanup" {
            $result = Invoke-PermanentCleanup -Days ${args.retentionDays || 30}
        }
        "backup" {
            $result = Start-BackupOperation ${args.path ? `-Path "${args.path}"` : ''}
        }
        "status" {
            $result = Get-BackupStatus
        }
        default {
            $result = Get-BackupStatistics
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateDevEnvironmentScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/DevEnvironment" -Force

try {
    switch ("${args.operation}") {
        "initialize" {
            $result = Initialize-DevelopmentEnvironment -Force:$${args.force || 'false'}
        }
        "test" {
            $result = Test-DevelopmentSetup
        }
        "status" {
            $result = Get-DevEnvironmentStatus
        }
        "resolve-imports" {
            $result = Resolve-ModuleImportIssues
        }
        default {
            $result = Test-DevEnvironment
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateISOManagementScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/ISOManager" -Force
Import-Module "$script:ProjectRoot/aither-core/modules/ISOCustomizer" -Force

try {
    switch ("${args.operation}") {
        "download" {
            $result = Get-ISODownload -Product "${args.product}" ${args.version ? `-Version "${args.version}"` : ''}
        }
        "inventory" {
            $result = Get-ISOInventory ${args.path ? `-Path "${args.path}"` : ''}
        }
        "metadata" {
            $result = Get-ISOMetadata -ISOPath "${args.isoPath}"
        }
        "integrity" {
            $result = Test-ISOIntegrity -ISOPath "${args.isoPath}"
        }
        "customize" {
            $result = New-CustomISO -SourceISO "${args.sourceISO}" -OutputPath "${args.outputPath}"
        }
        "autounattend" {
            $result = New-AutounattendFile ${args.config ? `-Config ${args.config}` : ''}
        }
        default {
            $result = Get-ISOInventory
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateTestingFrameworkScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/TestingFramework" -Force

try {
    switch ("${args.operation}") {
        "bulletproof" {
            $result = pwsh -File "$script:ProjectRoot/tests/Run-BulletproofValidation.ps1" -ValidationLevel "${args.level || 'Quick'}"
        }
        "unified" {
            $params = @{
                ${args.modules ? `Modules = @(${args.modules.map(m => `"${m}"`).join(', ')})` : ''}
                ${args.testTypes ? `TestTypes = @(${args.testTypes.map(t => `"${t}"`).join(', ')})` : ''}
                ${args.parallel ? 'Parallel = $true' : ''}
            }
            $result = Invoke-UnifiedTestExecution @params
        }
        "discover" {
            $result = Get-DiscoveredModules
        }
        default {
            $result = Get-TestConfiguration
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateInfrastructureScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/OpenTofuProvider" -Force

try {
    switch ("${args.operation}") {
        "install" {
            $result = Install-OpenTofuSecure
        }
        "deploy" {
            $result = New-LabInfrastructure -ConfigPath "${args.configPath}"
        }
        "security" {
            $result = Test-OpenTofuSecurity -ConfigPath "${args.configPath}"
        }
        "template" {
            $result = Export-LabTemplate -TemplateName "${args.templateName}"
        }
        "compliance" {
            $result = Test-InfrastructureCompliance -ConfigPath "${args.configPath}"
        }
        default {
            $result = Initialize-OpenTofuProvider
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateRemoteConnectionScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/RemoteConnection" -Force

try {
    switch ("${args.operation}") {
        "new" {
            $params = @{
                Name = "${args.name}"
                HostName = "${args.hostname}"
                EndpointType = "${args.endpointType || 'SSH'}"
                ${args.port ? `Port = ${args.port}` : ''}
                ${args.credentialName ? `CredentialName = "${args.credentialName}"` : ''}
            }
            $result = New-RemoteConnection @params
        }
        "test" {
            $result = Test-RemoteConnection -Name "${args.name}"
        }
        "connect" {
            $result = Connect-RemoteEndpoint -Name "${args.name}"
        }
        "execute" {
            $result = Invoke-RemoteCommand -ConnectionName "${args.name}" -Command "${args.command}"
        }
        "list" {
            $result = Get-RemoteConnection
        }
        default {
            $result = Get-RemoteConnection
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateCredentialManagementScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/SecureCredentials" -Force

try {
    switch ("${args.operation}") {
        "set" {
            $result = Set-SecureCredential -Name "${args.name}" -Username "${args.username}"
        }
        "get" {
            $result = Get-SecureCredential -Name "${args.name}"
        }
        "test" {
            $result = Test-SecureCredential -Name "${args.name}"
        }
        "list" {
            $result = Get-SecureCredential
        }
        "remove" {
            $result = Remove-SecureCredential -Name "${args.name}"
        }
        default {
            $result = Get-SecureCredential
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateLoggingSystemScript(args) {
    return `
try {
    switch ("${args.operation}") {
        "initialize" {
            $result = Initialize-LoggingSystem -ConsoleLevel "${args.consoleLevel || 'INFO'}" -LogLevel "${args.logLevel || 'DEBUG'}"
        }
        "log" {
            Write-CustomLog -Level "${args.level || 'INFO'}" -Message "${args.message}"
            $result = @{ Success = $true; Message = "Log entry created" }
        }
        "config" {
            $result = Get-LoggingConfiguration
        }
        default {
            $result = Get-LoggingConfiguration
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateParallelExecutionScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/ParallelExecution" -Force

try {
    switch ("${args.operation}") {
        "execute" {
            $scriptBlocks = @(${args.scriptBlocks ? args.scriptBlocks.map(sb => `{ ${sb} }`).join(', ') : ''})
            $result = Invoke-ParallelOperation -Operations $scriptBlocks -MaxParallelJobs ${args.maxJobs || 4}
        }
        "status" {
            $result = Get-ParallelExecutionStatus
        }
        default {
            $result = @{ ParallelExecutionModule = "Available"; MaxRecommendedJobs = [Environment]::ProcessorCount }
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateScriptManagementScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/ScriptManager" -Force

try {
    switch ("${args.operation}") {
        "register" {
            $result = Register-OneOffScript -ScriptName "${args.scriptName}" -ScriptPath "${args.scriptPath}"
        }
        "execute" {
            $result = Invoke-OneOffScript -ScriptName "${args.scriptName}"
        }
        "repository" {
            $result = Get-ScriptRepository
        }
        "template" {
            $result = Get-ScriptTemplate -TemplateName "${args.templateName}"
        }
        "test" {
            $result = Test-OneOffScript -ScriptName "${args.scriptName}"
        }
        default {
            $result = Get-ScriptRepository
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateMaintenanceOperationsScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/UnifiedMaintenance" -Force

try {
    $params = @{
        Mode = "${args.mode || 'Quick'}"
        ${args.autoFix ? 'AutoFix = $true' : ''}
        ${args.updateChangelog ? 'UpdateChangelog = $true' : ''}
    }

    $result = Invoke-UnifiedMaintenance @params
    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  generateRepoSyncScript(args) {
    return `
Import-Module "$script:ProjectRoot/aither-core/modules/RepoSync" -Force

try {
    switch ("${args.operation}") {
        "sync" {
            $result = Sync-Repository ${args.targetRepo ? `-TargetRepo "${args.targetRepo}"` : ''}
        }
        "status" {
            $result = Get-SyncStatus
        }
        default {
            $result = Get-SyncStatus
        }
    }

    $result | ConvertTo-Json -Depth 10
} catch {
    @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5
}
`;
  }

  formatResult(result) {
    if (typeof result.output === 'string') {
      try {
        const parsed = JSON.parse(result.output);
        return `## ${result.toolName} Execution Results

**Status:** ${result.success ? '✅ Success' : '❌ Failed'}
**Timestamp:** ${result.metadata.timestamp}
**Execution Time:** ${result.metadata.executionTime}ms

### Output
\`\`\`json
${JSON.stringify(parsed, null, 2)}
\`\`\`

${result.errors ? `### Errors\n\`\`\`\n${result.errors}\n\`\`\`` : ''}
`;
      } catch {
        return `## ${result.toolName} Execution Results

**Status:** ${result.success ? '✅ Success' : '❌ Failed'}
**Timestamp:** ${result.metadata.timestamp}
**Execution Time:** ${result.metadata.executionTime}ms

### Output
\`\`\`
${result.output}
\`\`\`

${result.errors ? `### Errors\n\`\`\`\n${result.errors}\n\`\`\`` : ''}
`;
      }
    }

    return `## ${result.toolName} Execution Results

**Status:** ${result.success ? '✅ Success' : '❌ Failed'}
**Timestamp:** ${result.metadata.timestamp}

### Output
${result.output}

${result.errors ? `### Errors\n${result.errors}` : ''}
`;
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    this.logger.info('AitherZero MCP Server started');
  }
}

// Start the server
const server = new AitherZeroMCPServer();
server.start().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
