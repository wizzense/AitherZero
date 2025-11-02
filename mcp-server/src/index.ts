#!/usr/bin/env node

/**
 * AitherZero MCP Server
 * 
 * Exposes AitherZero's infrastructure automation capabilities through the
 * Model Context Protocol, allowing AI assistants to interact with:
 * - Infrastructure deployment (OpenTofu/Terraform)
 * - VM management
 * - Automation scripts (0000-9999)
 * - Configuration management
 * - Testing and quality validation
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
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

/**
 * Execute a PowerShell command and return the result
 */
async function executePowerShell(script: string): Promise<{ stdout: string; stderr: string }> {
  try {
    const { stdout, stderr } = await exec(`${PWSH_PATH} -NoProfile -Command "${script.replace(/"/g, '\\"')}"`);
    return { stdout, stderr };
  } catch (error: any) {
    return { 
      stdout: error.stdout || '', 
      stderr: error.stderr || error.message 
    };
  }
}

/**
 * Execute an AitherZero script by number
 */
async function executeAitherScript(scriptNumber: string, params: Record<string, any> = {}): Promise<string> {
  const paramString = Object.entries(params)
    .map(([key, value]) => `-${key} ${JSON.stringify(value)}`)
    .join(' ');
  
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode Run -Target ${scriptNumber} ${paramString}
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Get list of available automation scripts
 */
async function listAutomationScripts(): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode List -Target scripts | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Search automation scripts by keyword
 */
async function searchScripts(query: string): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode Search -Query '${query}' | Out-String
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Execute a playbook
 */
async function executePlaybook(playbookName: string, profile?: string): Promise<string> {
  const profileParam = profile ? `-PlaybookProfile ${profile}` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ${playbookName} ${profileParam}
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Get configuration value
 */
async function getConfiguration(key?: string): Promise<string> {
  const keyParam = key ? `-Key '${key}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    Get-AitherConfiguration ${keyParam} | ConvertTo-Json -Depth 10
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

/**
 * Run Pester tests
 */
async function runTests(path?: string): Promise<string> {
  const pathParam = path ? `-Path '${path}'` : '';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode Run -Target 0402 ${pathParam}
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Run quality validation
 */
async function runQualityCheck(path?: string): Promise<string> {
  const pathParam = path ? `-Path '${path}'` : '-Path ./domains -Recursive';
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode Run -Target 0420 ${pathParam}
  `;
  
  const { stdout, stderr } = await executePowerShell(command);
  return stderr ? `${stdout}\n\nErrors: ${stderr}` : stdout;
}

/**
 * Get project report
 */
async function getProjectReport(): Promise<string> {
  const command = `
    cd '${AITHERZERO_ROOT}'
    Import-Module ./AitherZero.psd1 -Force
    & ./Start-AitherZero.ps1 -Mode Run -Target 0510 -ShowAll
  `;
  
  const { stdout } = await executePowerShell(command);
  return stdout;
}

// Create MCP server
const server = new Server(
  {
    name: 'aitherzero-server',
    version: '0.1.0',
  },
  {
    capabilities: {
      tools: {},
      resources: {},
    },
  }
);

// Register tool handlers
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'run_script',
      description: 'Execute an AitherZero automation script by number (0000-9999). Scripts cover environment setup, infrastructure deployment, development tools, testing, reporting, and maintenance.',
      inputSchema: {
        type: 'object',
        properties: {
          scriptNumber: {
            type: 'string',
            description: 'Script number (e.g., "0402" for tests, "0404" for linting, "0510" for project report)',
          },
          params: {
            type: 'object',
            description: 'Optional parameters to pass to the script',
            additionalProperties: true,
          },
        },
        required: ['scriptNumber'],
      },
    },
    {
      name: 'list_scripts',
      description: 'List all available automation scripts with their descriptions and categories.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'search_scripts',
      description: 'Search automation scripts by keyword or description.',
      inputSchema: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Search query (e.g., "test", "docker", "infrastructure")',
          },
        },
        required: ['query'],
      },
    },
    {
      name: 'execute_playbook',
      description: 'Execute a playbook (predefined sequence of automation scripts). Available playbooks: test-quick, test-full, setup-dev, setup-minimal.',
      inputSchema: {
        type: 'object',
        properties: {
          playbookName: {
            type: 'string',
            description: 'Name of the playbook to execute',
          },
          profile: {
            type: 'string',
            description: 'Execution profile (quick, standard, full, ci)',
          },
        },
        required: ['playbookName'],
      },
    },
    {
      name: 'get_configuration',
      description: 'Get AitherZero configuration values. Can retrieve entire configuration or specific keys.',
      inputSchema: {
        type: 'object',
        properties: {
          key: {
            type: 'string',
            description: 'Optional configuration key path (e.g., "Core.Profile", "Testing.Profile")',
          },
        },
      },
    },
    {
      name: 'run_tests',
      description: 'Run Pester tests for AitherZero. Can run all tests or tests for a specific path.',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Optional path to test file or directory (e.g., "./tests/unit/Configuration.Tests.ps1")',
          },
        },
      },
    },
    {
      name: 'run_quality_check',
      description: 'Run quality validation checks using PSScriptAnalyzer and custom quality standards.',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Path to file or directory to validate',
          },
        },
      },
    },
    {
      name: 'get_project_report',
      description: 'Generate comprehensive project report with statistics, test results, and quality metrics.',
      inputSchema: {
        type: 'object',
        properties: {},
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
        result = await listAutomationScripts();
        break;

      case 'search_scripts':
        result = await searchScripts(args.query as string);
        break;

      case 'execute_playbook':
        result = await executePlaybook(args.playbookName as string, args.profile as string | undefined);
        break;

      case 'get_configuration':
        result = await getConfiguration(args.key as string | undefined);
        break;

      case 'run_tests':
        result = await runTests(args.path as string | undefined);
        break;

      case 'run_quality_check':
        result = await runQualityCheck(args.path as string | undefined);
        break;

      case 'get_project_report':
        result = await getProjectReport();
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
      description: 'Current AitherZero configuration',
      mimeType: 'application/json',
    },
    {
      uri: 'aitherzero://scripts',
      name: 'Automation Scripts',
      description: 'List of available automation scripts',
      mimeType: 'text/plain',
    },
    {
      uri: 'aitherzero://project-report',
      name: 'Project Report',
      description: 'Comprehensive project status and metrics',
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

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('AitherZero MCP Server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
