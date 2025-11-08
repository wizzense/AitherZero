#!/usr/bin/env node

/**
 * Simple test script to verify MCP server functionality
 * Tests that the server can start and respond to basic requests
 */

import { spawn } from 'child_process';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverPath = path.join(__dirname, '..', 'dist', 'index.js');

console.log('🧪 Testing AitherZero MCP Server...\n');

// Test 1: List Tools
console.log('Test 1: Listing available tools');
const listToolsRequest = {
  jsonrpc: '2.0',
  id: 1,
  method: 'tools/list',
  params: {}
};

const server = spawn('node', [serverPath], {
  stdio: ['pipe', 'pipe', 'pipe']
});

let output = '';
let errorOutput = '';

server.stdout.on('data', (data) => {
  output += data.toString();
});

server.stderr.on('data', (data) => {
  errorOutput += data.toString();
  if (errorOutput.includes('running on stdio')) {
    console.log('✅ Server started successfully\n');
    
    // Send the list tools request
    server.stdin.write(JSON.stringify(listToolsRequest) + '\n');
  }
});

server.on('close', (code) => {
  console.log('\n📊 Test Results:');
  console.log('Exit code:', code);
  
  if (output) {
    try {
      const response = JSON.parse(output.trim().split('\n')[0]);
      if (response.result && response.result.tools) {
        console.log('✅ Tools list received');
        console.log(`✅ Found ${response.result.tools.length} tools:`);
        response.result.tools.forEach((tool, index) => {
          console.log(`   ${index + 1}. ${tool.name} - ${tool.description.substring(0, 60)}...`);
        });
      }
    } catch (e) {
      console.log('❌ Failed to parse response:', e.message);
      console.log('Raw output:', output.substring(0, 200));
    }
  } else {
    console.log('⚠️  No output received');
  }
  
  if (errorOutput && !errorOutput.includes('running on stdio')) {
    console.log('\n⚠️  Errors:', errorOutput);
  }
  
  console.log('\n✨ Test complete!');
  process.exit(code);
});

// Timeout after 10 seconds
setTimeout(() => {
  console.log('\n⏰ Test timeout - closing server');
  server.kill();
}, 10000);
