#!/usr/bin/env node

/**
 * Example script showing how to connect an AI agent to AitherZero MCP server
 */

import { spawn } from 'child_process';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

class AitherZeroAgentConnector {
  constructor() {
    this.client = null;
    this.transport = null;
  }

  async connect() {
    console.log('🚀 Connecting to AitherZero MCP Server...');

    // Start the enhanced MCP server as a child process
    const serverProcess = spawn('node', ['enhanced-index.js'], {
      stdio: ['pipe', 'pipe', 'pipe'],
      cwd: process.cwd()
    });

    // Create client and transport
    this.transport = new StdioClientTransport({
      reader: serverProcess.stdout,
      writer: serverProcess.stdin
    });

    this.client = new Client(
      {
        name: 'aitherzero-agent-client',
        version: '1.0.0',
      },
      {
        capabilities: {
          experimental: {},
          sampling: {},
        },
      }
    );

    // Connect the client
    await this.client.connect(this.transport);
    console.log('✅ Connected to AitherZero MCP Server!');

    // List available tools
    const tools = await this.client.listTools();
    console.log(`📊 Available tools: ${tools.tools.length}`);

    return tools;
  }

  async executeExample() {
    try {
      // Example: Check system status
      console.log('\n🔍 Testing system status check...');
      const result = await this.client.callTool({
        name: 'aither_system_status',
        arguments: {
          operation: 'health'
        }
      });

      console.log('✅ Tool execution result:');
      console.log(result.content[0].text);

    } catch (error) {
      console.error('❌ Tool execution failed:', error.message);
    }
  }

  async disconnect() {
    if (this.client && this.transport) {
      await this.client.close();
      console.log('👋 Disconnected from AitherZero MCP Server');
    }
  }
}

// Example usage
async function main() {
  const connector = new AitherZeroAgentConnector();

  try {
    const tools = await connector.connect();

    // Show available toolsets
    console.log('\n📦 Available AitherZero Toolsets:');
    console.log('🏗️  aither-infrastructure (4 tools)');
    console.log('💻  aither-development (5 tools)');
    console.log('⚙️  aither-operations (5 tools)');
    console.log('🔒  aither-security (4 tools)');
    console.log('💿  aither-iso (4 tools)');
    console.log('🚀  aither-advanced (5 tools)');
    console.log('⚡  aither-quick-actions (5 tools)');

    // Run example
    await connector.executeExample();

  } catch (error) {
    console.error('❌ Connection failed:', error.message);
  } finally {
    await connector.disconnect();
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export { AitherZeroAgentConnector };
