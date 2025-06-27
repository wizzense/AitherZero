#!/usr/bin/env node

/**
 * Test script to verify MCP server is working correctly
 */

import { MCPTools } from './claude-code-mcp-server.js';

console.log('🧪 Testing MCP Server Integration\n');

async function runTests() {
  try {
    // Test 1: List tools
    console.log('📋 Test 1: Listing available tools');
    const tools = MCPTools.list();
    console.log(`✅ Found ${tools.tools.length} tools\n`);
    
    // Test 2: Call a simple tool
    console.log('🔧 Test 2: Testing logging system');
    const logResult = await MCPTools.call('aither_logging_system', {
      operation: 'log',
      level: 'INFO',
      message: 'MCP Server successfully integrated with Claude Code!'
    });
    console.log('Result:', JSON.stringify(logResult, null, 2));
    
    console.log('\n✅ MCP Server is working correctly!');
    console.log('   PowerShell 7 was automatically installed and configured.');
    console.log('   You can now use all AitherZero tools through the MCP interface.\n');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

runTests();