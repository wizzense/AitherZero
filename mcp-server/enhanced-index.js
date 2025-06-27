#!/usr/bin/env node

/**
 * Enhanced AitherZero MCP Server
 * Exposes the comprehensive AitherZero infrastructure automation framework
 * as Model Context Protocol tools for AI agents with full VS Code toolset integration
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { PowerShellExecutor } from './src/powershell-executor.js';
import { EnhancedToolDefinitions } from './src/enhanced-tool-definitions.js';
import { AitherCommandGenerator } from './src/aither-command-generator.js';
import { ValidationSchema } from './src/validation-schema.js';
import { Logger } from './src/logger.js';
import fs from 'fs';
import path from 'path';

class EnhancedAitherZeroMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'aitherzero-mcp-server',
        version: '2.0.0-enhanced',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.psExecutor = new PowerShellExecutor();
    this.logger = new Logger();
    this.toolDefs = new EnhancedToolDefinitions();
    this.commandGen = new AitherCommandGenerator();
    this.validator = new ValidationSchema();

    this.setupHandlers();
    this.generateVSCodeToolsets();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      this.logger.info('Tools list requested');

      const tools = this.toolDefs.getAllTools();
      this.logger.info(`Returning ${tools.length} tools`);

      return {
        tools: tools,
      };
    });

    // Execute tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        const { name, arguments: args } = request.params;

        this.logger.info(`Tool called: ${name}`, {
          args: this.sanitizeArgsForLogging(args)
        });

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

        this.logger.info(`Tool execution completed: ${name}`, {
          success: true,
          category: tool.category
        });

        return {
          content: [
            {
              type: 'text',
              text: this.formatResult(result, name, tool.category),
            },
          ],
        };
      } catch (error) {
        this.logger.error(`Tool execution failed: ${request.params.name}`, error);

        return {
          content: [
            {
              type: 'text',
              text: `❌ Error executing ${request.params.name}: ${error.message}\\n\\nSee logs for detailed error information.`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async executeTool(toolName, args) {
    try {
      // Generate PowerShell command using enhanced command generator
      const psScript = this.commandGen.generateCommand(toolName, args);

      this.logger.debug(`Generated PowerShell script for ${toolName}`, {
        scriptLength: psScript.length
      });

      // Execute the PowerShell script
      const result = await this.psExecutor.execute(psScript);

      // Process and enhance the result
      return this.processToolResult(toolName, result, args);

    } catch (error) {
      this.logger.error(`Tool execution error for ${toolName}`, error);
      throw new Error(`Failed to execute ${toolName}: ${error.message}`);
    }
  }

  processToolResult(toolName, rawResult, args) {
    const tool = this.toolDefs.getTool(toolName);

    const processedResult = {
      tool: toolName,
      category: tool.category,
      timestamp: new Date().toISOString(),
      success: rawResult.success,
      exitCode: rawResult.exitCode,
      executionTime: rawResult.executionTime,

      // Enhanced result processing
      output: this.processOutput(rawResult.stdout, toolName),
      errors: this.processErrors(rawResult.stderr, toolName),
      warnings: this.extractWarnings(rawResult.stdout),

      // Tool-specific metadata
      metadata: this.generateToolMetadata(toolName, args, rawResult),

      // Next steps and recommendations
      nextSteps: this.generateNextSteps(toolName, rawResult, args),

      // Related tools and workflows
      relatedTools: this.getRelatedTools(toolName),
    };

    return processedResult;
  }

  processOutput(stdout, toolName) {
    if (!stdout || stdout.trim() === '') {
      return 'Operation completed successfully (no output)';
    }

    // Clean up PowerShell noise and format nicely
    let cleanOutput = stdout
      .replace(/^\\s*$/, '') // Remove empty lines
      .replace(/WARNING: .*$/gm, '') // Remove warning lines (processed separately)
      .replace(/VERBOSE: .*$/gm, '') // Remove verbose lines
      .replace(/DEBUG: .*$/gm, '') // Remove debug lines
      .trim();

    // Add tool-specific formatting
    switch (toolName) {
      case 'aither_patch_workflow':
        return this.formatPatchWorkflowOutput(cleanOutput);
      case 'aither_testing_framework':
        return this.formatTestingOutput(cleanOutput);
      case 'aither_lab_automation':
        return this.formatLabOutput(cleanOutput);
      default:
        return cleanOutput || 'Operation completed successfully';
    }
  }

  processErrors(stderr, toolName) {
    if (!stderr || stderr.trim() === '') {
      return null;
    }

    return {
      raw: stderr,
      summary: this.summarizeErrors(stderr),
      suggestions: this.generateErrorSuggestions(stderr, toolName)
    };
  }

  extractWarnings(stdout) {
    if (!stdout) return [];

    const warningMatches = stdout.match(/WARNING: (.*)$/gm) || [];
    return warningMatches.map(match => match.replace('WARNING: ', '').trim());
  }

  generateToolMetadata(toolName, args, rawResult) {
    const tool = this.toolDefs.getTool(toolName);

    return {
      description: tool.description,
      category: tool.category,
      argumentsUsed: Object.keys(args),
      recommendedFollowup: this.getRecommendedFollowup(toolName, rawResult.success),
      documentationLinks: this.getDocumentationLinks(toolName),
    };
  }

  generateNextSteps(toolName, result, args) {
    if (!result.success) {
      return [
        "❌ Operation failed - check error details above",
        "🔧 Consider running system diagnostics: aither_health_diagnostics",
        "📋 Review logs: aither_logging_system with operation 'view'",
        "🆘 For critical issues, try: aither_emergency_rollback"
      ];
    }

    // Success-specific next steps
    switch (toolName) {
      case 'aither_patch_workflow':
        return [
          "✅ Patch applied successfully",
          "🧪 Run tests: aither_testing_framework with operation 'bulletproof'",
          "🔍 Check system status: aither_system_status",
          args.createPR ? "📋 Review the created pull request on GitHub" : "📤 Consider creating a PR with createPR: true"
        ];

      case 'aither_dev_environment':
        return [
          "✅ Development environment configured",
          "🧪 Validate setup: aither_fast_validation",
          "🔨 Try a quick patch: aither_quick_patch",
          "📚 Explore available tools with different categories"
        ];

      case 'aither_testing_framework':
        return [
          "✅ Testing completed",
          "📊 Review test results above",
          "🔧 If issues found, use: aither_maintenance_operations",
          "📈 For performance analysis: aither_performance_monitoring"
        ];

      case 'aither_lab_automation':
        return [
          "✅ Lab automation completed",
          "🔗 Test connections: aither_remote_connection",
          "🏗️ Deploy infrastructure: aither_infrastructure_deployment",
          "📊 Monitor status: aither_system_status"
        ];

      default:
        return [
          "✅ Operation completed successfully",
          "🔍 Check system status: aither_system_status",
          "📋 View logs: aither_logging_system",
          "🔧 Run maintenance: aither_maintenance_operations"
        ];
    }
  }

  getRelatedTools(toolName) {
    const tool = this.toolDefs.getTool(toolName);
    if (!tool) return [];

    // Get other tools in the same category
    const categoryTools = this.toolDefs.getToolsByCategory(tool.category)
      .filter(t => t.name !== toolName)
      .slice(0, 3)
      .map(t => ({
        name: t.name,
        description: t.description
      }));

    // Add cross-category recommendations
    const crossCategory = this.getCrossCategoryRecommendations(toolName);

    return [...categoryTools, ...crossCategory];
  }

  getCrossCategoryRecommendations(toolName) {
    const recommendations = {
      'aither_patch_workflow': [
        { name: 'aither_testing_framework', description: 'Validate your changes' },
        { name: 'aither_backup_management', description: 'Backup before major changes' }
      ],
      'aither_lab_automation': [
        { name: 'aither_infrastructure_deployment', description: 'Deploy infrastructure' },
        { name: 'aither_remote_connection', description: 'Connect to lab systems' }
      ],
      'aither_testing_framework': [
        { name: 'aither_patch_workflow', description: 'Fix any issues found' },
        { name: 'aither_maintenance_operations', description: 'Address maintenance needs' }
      ]
    };

    return recommendations[toolName] || [];
  }

  formatResult(result, toolName, category) {
    const categoryIcons = {
      'development': '💻',
      'infrastructure': '🏗️',
      'operations': '⚙️',
      'security': '🔒',
      'iso': '💿',
      'advanced': '🚀',
      'quick': '⚡'
    };

    const icon = categoryIcons[category] || '🔧';

    let formatted = `${icon} **${toolName}** (${category})\\n\\n`;

    // Add execution summary
    if (result.success) {
      formatted += `✅ **Status**: Success\\n`;
    } else {
      formatted += `❌ **Status**: Failed (Exit Code: ${result.exitCode})\\n`;
    }

    formatted += `⏱️ **Execution Time**: ${result.executionTime}ms\\n`;
    formatted += `📅 **Timestamp**: ${result.timestamp}\\n\\n`;

    // Add main output
    if (result.output) {
      formatted += `**Output:**\\n\`\`\`\\n${result.output}\\n\`\`\`\\n\\n`;
    }

    // Add warnings if any
    if (result.warnings && result.warnings.length > 0) {
      formatted += `**Warnings:**\\n`;
      result.warnings.forEach(warning => {
        formatted += `⚠️ ${warning}\\n`;
      });
      formatted += '\\n';
    }

    // Add errors if any
    if (result.errors) {
      formatted += `**Errors:**\\n\`\`\`\\n${result.errors.summary}\\n\`\`\`\\n\\n`;
      if (result.errors.suggestions && result.errors.suggestions.length > 0) {
        formatted += `**Suggestions:**\\n`;
        result.errors.suggestions.forEach(suggestion => {
          formatted += `💡 ${suggestion}\\n`;
        });
        formatted += '\\n';
      }
    }

    // Add next steps
    if (result.nextSteps && result.nextSteps.length > 0) {
      formatted += `**Next Steps:**\\n`;
      result.nextSteps.forEach(step => {
        formatted += `${step}\\n`;
      });
      formatted += '\\n';
    }

    // Add related tools
    if (result.relatedTools && result.relatedTools.length > 0) {
      formatted += `**Related Tools:**\\n`;
      result.relatedTools.forEach(tool => {
        formatted += `🔗 \`${tool.name}\` - ${tool.description}\\n`;
      });
      formatted += '\\n';
    }

    // Add metadata
    if (result.metadata) {
      formatted += `**Tool Information:**\\n`;
      formatted += `📝 ${result.metadata.description}\\n`;
      if (result.metadata.argumentsUsed.length > 0) {
        formatted += `🔧 Arguments used: ${result.metadata.argumentsUsed.join(', ')}\\n`;
      }
    }

    return formatted;
  }

  // Helper methods for specific tool output formatting
  formatPatchWorkflowOutput(output) {
    if (output.includes('Patch workflow completed successfully')) {
      return '🎉 Patch workflow completed successfully!\\n\\n' + output;
    }
    return output;
  }

  formatTestingOutput(output) {
    if (output.includes('tests passed') || output.includes('PASSED')) {
      return '✅ Tests completed successfully!\\n\\n' + output;
    }
    if (output.includes('failed') || output.includes('FAILED')) {
      return '❌ Some tests failed - review details below:\\n\\n' + output;
    }
    return output;
  }

  formatLabOutput(output) {
    if (output.includes('Lab automation completed')) {
      return '🏗️ Lab automation completed successfully!\\n\\n' + output;
    }
    return output;
  }

  summarizeErrors(stderr) {
    // Extract key error patterns
    const lines = stderr.split('\\n').filter(line => line.trim());
    const errorLines = lines.filter(line =>
      line.includes('Error') ||
      line.includes('Exception') ||
      line.includes('Failed')
    );

    if (errorLines.length === 0) {
      return stderr.trim();
    }

    return errorLines.slice(0, 3).join('\\n'); // Show first 3 error lines
  }

  generateErrorSuggestions(stderr, toolName) {
    const suggestions = [];

    if (stderr.includes('module') && stderr.includes('not found')) {
      suggestions.push('Try running module validation: aither_fast_validation');
      suggestions.push('Check development environment: aither_dev_environment');
    }

    if (stderr.includes('permission') || stderr.includes('access denied')) {
      suggestions.push('Check file permissions and run as administrator if needed');
      suggestions.push('Review security settings: aither_credential_management');
    }

    if (stderr.includes('network') || stderr.includes('connection')) {
      suggestions.push('Check network connectivity and firewall settings');
      suggestions.push('Test remote connections: aither_remote_connection');
    }

    if (stderr.includes('path') || stderr.includes('directory')) {
      suggestions.push('Verify file paths and directory structure');
      suggestions.push('Run system diagnostics: aither_health_diagnostics');
    }

    // Tool-specific suggestions
    switch (toolName) {
      case 'aither_patch_workflow':
        if (stderr.includes('git')) {
          suggestions.push('Check Git configuration and authentication');
          suggestions.push('Verify GitHub CLI is properly authenticated');
        }
        break;
      case 'aither_testing_framework':
        suggestions.push('Check test dependencies and module imports');
        suggestions.push('Try running tests individually to isolate issues');
        break;
    }

    return suggestions;
  }

  getRecommendedFollowup(toolName, success) {
    if (!success) {
      return ['aither_health_diagnostics', 'aither_system_status'];
    }

    const followups = {
      'aither_patch_workflow': ['aither_testing_framework', 'aither_system_status'],
      'aither_dev_environment': ['aither_fast_validation', 'aither_quick_patch'],
      'aither_testing_framework': ['aither_maintenance_operations', 'aither_system_status'],
      'aither_lab_automation': ['aither_remote_connection', 'aither_infrastructure_deployment']
    };

    return followups[toolName] || ['aither_system_status'];
  }

  getDocumentationLinks(toolName) {
    const baseUrl = 'https://github.com/wizzense/AitherZero/blob/main/docs/';

    const links = {
      'aither_patch_workflow': [`${baseUrl}DEVELOPER-ONBOARDING.md#patchmanager-v21`],
      'aither_testing_framework': [`${baseUrl}BULLETPROOF-TESTING-GUIDE.md`],
      'aither_dev_environment': [`${baseUrl}DEVELOPER-ONBOARDING.md#development-environment-setup`],
      'aither_lab_automation': [`${baseUrl}COMPLETE-ARCHITECTURE.md#lab-automation`]
    };

    return links[toolName] || [`${baseUrl}README.md`];
  }

  generateVSCodeToolsets() {
    try {
      const toolsets = this.toolDefs.getToolsetDefinition();
      const outputPath = path.join(process.cwd(), 'enhanced-vscode-toolsets.json');

      fs.writeFileSync(outputPath, JSON.stringify(toolsets, null, 2));
      this.logger.info(`Generated VS Code toolsets configuration: ${outputPath}`);
    } catch (error) {
      this.logger.error('Failed to generate VS Code toolsets', error);
    }
  }

  sanitizeArgsForLogging(args) {
    // Remove sensitive information from args for logging
    const sanitized = { ...args };

    // Remove potential passwords, tokens, etc.
    const sensitiveKeys = ['password', 'token', 'key', 'secret', 'credential'];
    sensitiveKeys.forEach(key => {
      if (sanitized[key]) {
        sanitized[key] = '[REDACTED]';
      }
    });

    // Truncate very long operation strings
    if (sanitized.operation && sanitized.operation.length > 200) {
      sanitized.operation = sanitized.operation.substring(0, 200) + '... [TRUNCATED]';
    }

    return sanitized;
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    this.logger.info('Enhanced AitherZero MCP Server started successfully');
    this.logger.info(`Available tools: ${this.toolDefs.getAllTools().length}`);
    this.logger.info(`Available categories: ${this.toolDefs.getCategories().length}`);
  }
}

// Start the server
const server = new EnhancedAitherZeroMCPServer();
server.run().catch(console.error);
