#!/usr/bin/env node

/**
 * AitherZero MCP Server v2.0
 * 
 * Modern Model Context Protocol server for AitherZero infrastructure automation platform.
 * 
 * Features:
 * - 880+ automation scripts in library/automation-scripts/
 * - 11 functional domains in aithercore/
 * - Playbook orchestration system
 * - Configuration-driven architecture
 * - Extension system support
 * - GitHub workflow integration
 * - Prompts for guided workflows
 * - Sampling for multi-step operations
 * 
 * Aligned with GitHub Copilot MCP best practices:
 * - Extended context through resources
 * - Seamless integration with multiple tools
 * - Security through minimal permissions
 * - Clear tool descriptions for agent mode
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  ListPromptsRequestSchema,
  GetPromptRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { spawn } from 'child_process';
import { promisify } from 'util';
import { exec as execCallback } from 'child_process';
import * as path from 'path';
import * as os from 'os';

const exec = promisify(execCallback);

// Configuration
const AITHERZERO_ROOT = process.env.AITHERZERO_ROOT || path.join(os.homedir(), 'AitherZero');
const PWSH_PATH = 'pwsh';
const NONINTERACTIVE = process.env.AITHERZERO_NONINTERACTIVE === '1';

/**
 * Execute a PowerShell command and return the result
 * Handles non-interactive mode for CI/automation environments
 */
async function executePowerShell(script: string): Promise<{ stdout: string; stderr: string }> {
  try {
    const nonInteractiveFlag = NONINTERACTIVE ? '-NonInteractive' : '';
    const { stdout, stderr } = await exec(`${PWSH_PATH} -NoProfile ${nonInteractiveFlag} -Command "${script.replace(/"/g, '\\"')}"`);
    return { stdout, stderr };
  } catch (error: any) {
    return { 
      stdout: error.stdout || '', 
      stderr: error.stderr || error.message 
    };
  }
}

/**
 * Execute an AitherZero script by number using new CLI cmdlets
 */
async function executeAitherScript(scriptNumber: string, params: Record<string, any> = {}): Promise<string> {
  const paramString = Object.entries(params)
    .map(([key, value]) => `-${key} ${JSON.stringify(value)}`)
    .join(' ');
  
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherScript -ScriptNumber ${scriptNumber} ${paramString} | Out-String
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Get list of available automation scripts using new CLI cmdlets
 */
async function listAutomationScripts(category?: string): Promise<string> {
  const categoryParam = category ? `-Category '${category}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-AitherScript ${categoryParam} | Format-Table -AutoSize | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Search automation scripts by keyword using new CLI cmdlets
 */
async function searchScripts(query: string): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-AitherScript -Search '${query}' | Format-Table -AutoSize | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Execute a playbook using new CLI cmdlets
 */
async function executePlaybook(playbookName: string, profile?: string): Promise<string> {
  const profileParam = profile ? `-Profile ${profile}` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherPlaybook -Name ${playbookName} ${profileParam} | Out-String
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Get configuration value using correct function name
 */
async function getConfiguration(section?: string, key?: string): Promise<string> {
  const sectionParam = section ? `-Section '${section}'` : '';
  const keyParam = key ? `-Key '${key}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-Configuration ${sectionParam} ${keyParam} | ConvertTo-Json -Depth 10
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Run Pester tests
 */
async function runTests(path?: string, tag?: string): Promise<string> {
  const pathParam = path ? `-Path '${path}'` : '';
  const tagParam = tag ? `-Tag '${tag}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherScript -ScriptNumber 0402 ${pathParam} ${tagParam} | Out-String
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Run quality validation - updated path to aithercore
 */
async function runQualityCheck(path?: string): Promise<string> {
  const pathParam = path ? `-Path '${path}'` : '-Path ./aithercore -Recursive';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherScript -ScriptNumber 0420 ${pathParam} | Out-String
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Get project report with comprehensive metrics
 */
async function getProjectReport(format?: string): Promise<string> {
  const formatParam = format ? `-Format ${format}` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherScript -ScriptNumber 0510 -ShowAll ${formatParam} | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * List available playbooks
 */
async function listPlaybooks(): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-AitherPlaybook | Format-Table -AutoSize | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Get information about aithercore domains
 */
async function getDomainInfo(domain?: string): Promise<string> {
  const domainParam = domain ? ` | Where-Object Name -eq '${domain}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-ChildItem ./aithercore -Directory${domainParam} | 
      ForEach-Object {
        [PSCustomObject]@{
          Domain = $_.Name
          Modules = (Get-ChildItem $_.FullName -Filter *.psm1).Count
          Path = $_.FullName
        }
      } | Format-Table -AutoSize | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * List available extensions
 */
async function listExtensions(): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-ChildItem ./extensions -Directory | 
      ForEach-Object {
        $manifest = Join-Path $_.FullName 'extension.psd1'
        if (Test-Path $manifest) {
          $ext = Import-PowerShellDataFile $manifest
          [PSCustomObject]@{
            Name = $ext.Name
            Version = $ext.Version
            Description = $ext.Description
            Enabled = $ext.Enabled
          }
        }
      } | Format-Table -AutoSize | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Get GitHub workflow status
 */
async function getWorkflowStatus(): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    gh workflow list --json name,state,id 2>$null | ConvertFrom-Json | Format-Table -AutoSize | Out-String
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr && stderr.includes('not found') 
    ? 'GitHub CLI not available or not authenticated' 
    : stdout;
}

/**
 * Generate documentation
 */
async function generateDocumentation(domain?: string): Promise<string> {
  const domainParam = domain ? `-Domain '${domain}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherScript -ScriptNumber 0530 ${domainParam} | Out-String
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

// Create MCP server
const server = new Server(
  {
    name: 'aitherzero-server',
    version: '2.0.0',
  },
  {
    capabilities: {
      tools: {},
      resources: {},
      prompts: {},
    },
  }
);

// Register tool handlers
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'run_script',
      description: 'Execute an AitherZero automation script by number (0000-9999) from library/automation-scripts/. Over 880 scripts covering environment setup, infrastructure deployment, development tools, testing, reporting, Git automation, and maintenance. Use for single-purpose automation tasks.',
      inputSchema: {
        type: 'object',
        properties: {
          scriptNumber: {
            type: 'string',
            description: 'Script number (e.g., "0402" for unit tests, "0404" for PSScriptAnalyzer, "0510" for project report, "0207" for Git setup)',
            pattern: '^\\d{4}$',
          },
          params: {
            type: 'object',
            description: 'Optional parameters to pass to the script as key-value pairs',
            additionalProperties: true,
          },
        },
        required: ['scriptNumber'],
      },
    },
    {
      name: 'list_scripts',
      description: 'List available automation scripts with descriptions, categories, and metadata. Optionally filter by category (e.g., testing, infrastructure, development).',
      inputSchema: {
        type: 'object',
        properties: {
          category: {
            type: 'string',
            description: 'Optional category filter (e.g., "testing", "infrastructure", "development", "reporting")',
          },
        },
      },
    },
    {
      name: 'search_scripts',
      description: 'Search automation scripts by keyword in name, description, or metadata. Returns matching scripts with full details.',
      inputSchema: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Search query (e.g., "docker", "test", "infrastructure", "quality")',
          },
        },
        required: ['query'],
      },
    },
    {
      name: 'list_playbooks',
      description: 'List all available playbooks (orchestrated sequences of scripts). Playbooks coordinate multiple automation scripts for complex workflows like full validation, environment setup, or PR checks.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'execute_playbook',
      description: 'Execute a playbook - a predefined orchestrated sequence of automation scripts. Use list_playbooks to see available options. Common playbooks: code-quality-full, pr-validation, comprehensive-validation, dev-environment-setup.',
      inputSchema: {
        type: 'object',
        properties: {
          playbookName: {
            type: 'string',
            description: 'Name of the playbook to execute (use list_playbooks to see options)',
          },
          profile: {
            type: 'string',
            description: 'Optional execution profile (quick, standard, full, ci)',
            enum: ['quick', 'standard', 'full', 'ci'],
          },
        },
        required: ['playbookName'],
      },
    },
    {
      name: 'get_configuration',
      description: 'Retrieve AitherZero configuration from config.psd1 manifest. Access configuration sections and keys to understand system settings, feature flags, and environment setup.',
      inputSchema: {
        type: 'object',
        properties: {
          section: {
            type: 'string',
            description: 'Optional configuration section (e.g., "Core", "Testing", "Features", "Infrastructure")',
          },
          key: {
            type: 'string',
            description: 'Optional specific key within section (e.g., "Profile", "Enabled")',
          },
        },
      },
    },
    {
      name: 'run_tests',
      description: 'Execute Pester tests for AitherZero codebase. Run all tests, specific test files, or filter by path. Supports unit and integration tests.',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Optional path to test file or directory (e.g., "./tests/unit/Configuration.Tests.ps1", "./tests/aithercore/automation")',
          },
          tag: {
            type: 'string',
            description: 'Optional Pester tag filter (e.g., "Unit", "Integration", "Fast")',
          },
        },
      },
    },
    {
      name: 'run_quality_check',
      description: 'Run comprehensive quality validation using PSScriptAnalyzer and custom quality standards. Checks error handling, logging, test coverage, and code standards.',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Path to file or directory to validate (defaults to ./aithercore if not specified)',
          },
        },
      },
    },
    {
      name: 'get_project_report',
      description: 'Generate comprehensive project metrics report including file counts, test results, quality metrics, tech debt analysis, and system health.',
      inputSchema: {
        type: 'object',
        properties: {
          format: {
            type: 'string',
            description: 'Optional output format (text, json, markdown)',
            enum: ['text', 'json', 'markdown'],
          },
        },
      },
    },
    {
      name: 'get_domain_info',
      description: 'Get information about aithercore functional domains (11 domains: ai-agents, automation, cli, configuration, development, documentation, infrastructure, reporting, security, testing, utilities). Each domain contains specialized PowerShell modules.',
      inputSchema: {
        type: 'object',
        properties: {
          domain: {
            type: 'string',
            description: 'Optional specific domain name to inspect (e.g., "automation", "testing", "infrastructure")',
          },
        },
      },
    },
    {
      name: 'list_extensions',
      description: 'List installed AitherZero extensions. Extensions use script range 8000-8999 and provide additional functionality through the extension system.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'get_workflow_status',
      description: 'Get status of GitHub Actions workflows for the repository (requires GitHub CLI authentication).',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'generate_documentation',
      description: 'Generate or update documentation for AitherZero modules and functions. Creates markdown documentation from PowerShell comment-based help.',
      inputSchema: {
        type: 'object',
        properties: {
          domain: {
            type: 'string',
            description: 'Optional specific domain to document (generates all if not specified)',
          },
        },
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let result: string;

    if (!args) {
      throw new Error('Missing arguments');
    }

    switch (name) {
      case 'run_script':
        result = await executeAitherScript(args.scriptNumber as string, args.params as Record<string, any>);
        break;

      case 'list_scripts':
        result = await listAutomationScripts(args.category as string | undefined);
        break;

      case 'search_scripts':
        result = await searchScripts(args.query as string);
        break;

      case 'list_playbooks':
        result = await listPlaybooks();
        break;

      case 'execute_playbook':
        result = await executePlaybook(args.playbookName as string, args.profile as string | undefined);
        break;

      case 'get_configuration':
        result = await getConfiguration(args.section as string | undefined, args.key as string | undefined);
        break;

      case 'run_tests':
        result = await runTests(args.path as string | undefined, args.tag as string | undefined);
        break;

      case 'run_quality_check':
        result = await runQualityCheck(args.path as string | undefined);
        break;

      case 'get_project_report':
        result = await getProjectReport(args.format as string | undefined);
        break;

      case 'get_domain_info':
        result = await getDomainInfo(args.domain as string | undefined);
        break;

      case 'list_extensions':
        result = await listExtensions();
        break;

      case 'get_workflow_status':
        result = await getWorkflowStatus();
        break;

      case 'generate_documentation':
        result = await generateDocumentation(args.domain as string | undefined);
        break;

      default:
        throw new Error(`Unknown tool: ${name}`);
    }

    return {
      content: [
        {
          type: 'text',
          text: result,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

// Register resource handlers
server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: 'aitherzero://config',
      name: 'AitherZero Configuration',
      description: 'Complete configuration from config.psd1 manifest - single source of truth for all system settings',
      mimeType: 'application/json',
    },
    {
      uri: 'aitherzero://scripts',
      name: 'Automation Scripts',
      description: 'List of 880+ automation scripts from library/automation-scripts/ with metadata',
      mimeType: 'text/plain',
    },
    {
      uri: 'aitherzero://playbooks',
      name: 'Orchestration Playbooks',
      description: 'Available playbooks for coordinated multi-script workflows',
      mimeType: 'text/plain',
    },
    {
      uri: 'aitherzero://domains',
      name: 'Aithercore Domains',
      description: 'Information about 11 functional domains in aithercore/',
      mimeType: 'text/plain',
    },
    {
      uri: 'aitherzero://project-report',
      name: 'Project Report',
      description: 'Comprehensive project status, metrics, and health analysis',
      mimeType: 'text/plain',
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  try {
    let content: string;

    switch (uri) {
      case 'aitherzero://config':
        content = await getConfiguration();
        break;

      case 'aitherzero://scripts':
        content = await listAutomationScripts();
        break;

      case 'aitherzero://playbooks':
        content = await listPlaybooks();
        break;

      case 'aitherzero://domains':
        content = await getDomainInfo();
        break;

      case 'aitherzero://project-report':
        content = await getProjectReport();
        break;

      default:
        throw new Error(`Unknown resource: ${uri}`);
    }

    return {
      contents: [
        {
          uri,
          mimeType: uri.includes('config') ? 'application/json' : 'text/plain',
          text: content,
        },
      ],
    };
  } catch (error) {
    throw new Error(`Failed to read resource ${uri}: ${error instanceof Error ? error.message : String(error)}`);
  }
});

// Register prompt handlers for guided workflows
server.setRequestHandler(ListPromptsRequestSchema, async () => ({
  prompts: [
    {
      name: 'setup-dev-environment',
      description: 'Guided workflow for setting up a complete AitherZero development environment',
      arguments: [
        {
          name: 'profile',
          description: 'Installation profile (minimal, standard, full)',
          required: false,
        },
      ],
    },
    {
      name: 'validate-code-quality',
      description: 'Step-by-step code quality validation workflow (syntax, linting, tests, coverage)',
      arguments: [
        {
          name: 'path',
          description: 'Path to validate (defaults to entire project)',
          required: false,
        },
      ],
    },
    {
      name: 'create-pr',
      description: 'Guided workflow for creating a pull request with proper validation',
      arguments: [
        {
          name: 'branch',
          description: 'Feature branch name',
          required: true,
        },
      ],
    },
    {
      name: 'troubleshoot-ci',
      description: 'Interactive troubleshooting for CI/CD pipeline failures',
      arguments: [],
    },
  ],
}));

server.setRequestHandler(GetPromptRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let messages: Array<{ role: 'user' | 'assistant'; content: { type: 'text'; text: string } }> = [];

    switch (name) {
      case 'setup-dev-environment':
        const profile = args?.profile || 'standard';
        messages = [
          {
            role: 'user',
            content: {
              type: 'text',
              text: `I want to set up AitherZero development environment with ${profile} profile`,
            },
          },
          {
            role: 'assistant',
            content: {
              type: 'text',
              text: `I'll help you set up AitherZero development environment. Let me start by checking prerequisites:\n\n1. PowerShell 7.0+\n2. Git 2.0+\n3. Node.js 18+ (for MCP server)\n\nLet me execute the setup steps:\n\nStep 1: Run bootstrap script\nStep 2: Install development tools (0201-0213 scripts)\nStep 3: Configure Git and GitHub CLI\nStep 4: Set up MCP servers (script 0010)\nStep 5: Validate installation\n\nShall I proceed?`,
            },
          },
        ];
        break;

      case 'validate-code-quality':
        const path = args?.path || 'entire project';
        messages = [
          {
            role: 'user',
            content: {
              type: 'text',
              text: `I want to validate code quality for ${path}`,
            },
          },
          {
            role: 'assistant',
            content: {
              type: 'text',
              text: `I'll run comprehensive code quality validation. This includes:\n\n1. Syntax validation (script 0407)\n2. PSScriptAnalyzer linting (script 0404)\n3. Unit tests (script 0402)\n4. Integration tests (script 0403)\n5. Quality checks (script 0420)\n\nOr I can run the code-quality-full playbook for the complete workflow.\n\nWhich approach would you prefer?`,
            },
          },
        ];
        break;

      case 'create-pr':
        const branch = args?.branch || 'feature-branch';
        messages = [
          {
            role: 'user',
            content: {
              type: 'text',
              text: `I want to create a PR for branch ${branch}`,
            },
          },
          {
            role: 'assistant',
            content: {
              type: 'text',
              text: `I'll guide you through creating a proper PR. Steps:\n\n1. Run pr-validation playbook to ensure code quality\n2. Generate documentation (script 0530)\n3. Update indexes (script 0531)\n4. Create PR with GitHub CLI (script 0703)\n5. Validate PR checks pass\n\nLet me start with validation first. Shall I proceed?`,
            },
          },
        ];
        break;

      case 'troubleshoot-ci':
        messages = [
          {
            role: 'user',
            content: {
              type: 'text',
              text: 'My CI/CD pipeline is failing, can you help troubleshoot?',
            },
          },
          {
            role: 'assistant',
            content: {
              type: 'text',
              text: `I'll help troubleshoot CI failures. Let me:\n\n1. Check workflow status using get_workflow_status tool\n2. Run diagnose-ci playbook\n3. Identify failing workflows and steps\n4. Suggest fixes based on common issues\n\nLet me start by checking the workflow status...`,
            },
          },
        ];
        break;

      default:
        throw new Error(`Unknown prompt: ${name}`);
    }

    return { messages };
  } catch (error) {
    throw new Error(`Failed to get prompt ${name}: ${error instanceof Error ? error.message : String(error)}`);
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('AitherZero MCP Server v2.0 running on stdio');
  console.error('14 tools, 5 resources, 4 prompts available');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
