#!/usr/bin/env node

/**
 * Test script for Claude Code integration with AitherZero tools
 */

import { AitherTools } from './aither-tools.js';

async function testClaudeCodeIntegration() {
  console.log('🧪 Testing Claude Code Integration with AitherZero Tools\n');

  try {
    // Test 1: List available tools
    console.log('📋 Test 1: Listing available tools...');
    await AitherTools.listTools();
    
    // Test 2: Check development environment status
    console.log('\n🔧 Test 2: Checking development environment...');
    const devStatus = await AitherTools.devEnvironment('status');
    console.log('Dev Environment Status:', devStatus);
    
    // Test 3: Run quick validation
    console.log('\n✅ Test 3: Running quick validation test...');
    const testResult = await AitherTools.runTests('Quick', true);
    console.log('Test Result:', testResult);
    
    console.log('\n✨ All tests completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    console.error('Stack:', error.stack);
  }
}

// Run the tests
testClaudeCodeIntegration();