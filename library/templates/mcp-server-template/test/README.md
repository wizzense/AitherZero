# Testing Guide

This guide explains how to test your MCP server.

## Types of Tests

### 1. Manual Testing

Test the server manually using JSON-RPC:

```bash
# Ensure server is built
npm run build

# Test tool listing
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js

# Test resource listing
echo '{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}' | node dist/index.js

# Test calling a tool
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"example_tool","arguments":{"param1":"test"}}}' | node dist/index.js

# Test reading a resource
echo '{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"SERVERNAME://example"}}' | node dist/index.js
```

### 2. Automated Testing

Run the basic test suite:

```bash
npm test
```

This runs `test/basic-test.mjs` which verifies:
- Server starts successfully
- Tools can be listed
- Resources can be listed
- JSON-RPC protocol works correctly

### 3. Integration Testing

Test with actual MCP client (Claude, VS Code):

1. Configure the server in your MCP client
2. Start the AI assistant
3. Ask it to list available capabilities
4. Try executing each tool
5. Try reading each resource
6. Verify results are correct

## Writing Tests

### Adding Test Cases

Edit `test/basic-test.mjs`:

```javascript
// Test 3: Test a specific tool
console.log('\n✓ Test 3: Test example tool');
const toolRequest = {
  jsonrpc: '2.0',
  id: 3,
  method: 'tools/call',
  params: {
    name: 'example_tool',
    arguments: { param1: 'test_value' }
  }
};
const toolResponse = await sendRequest(serverProcess, toolRequest);

if (toolResponse.error) {
  throw new Error(`Tool call failed: ${JSON.stringify(toolResponse.error)}`);
}

console.log('  Tool result:', toolResponse.result.content[0].text);
```

### Unit Testing (Optional)

For more comprehensive testing, add a unit test framework:

```bash
# Install Jest
npm install --save-dev jest @types/jest ts-jest

# Create jest.config.js
```

Example unit test:

```typescript
// tests/tools.test.ts
import { exampleTool } from '../src/index';

describe('exampleTool', () => {
  it('should execute successfully with valid input', async () => {
    const result = await exampleTool('test', 'value');
    expect(result).toBeDefined();
    expect(typeof result).toBe('string');
  });
  
  it('should throw error with invalid input', async () => {
    await expect(exampleTool('', '')).rejects.toThrow();
  });
});
```

## Test Checklist

Before releasing your server, verify:

- [ ] All tools can be listed
- [ ] All resources can be listed
- [ ] Each tool executes successfully with valid input
- [ ] Each tool handles invalid input gracefully
- [ ] Each resource returns valid data
- [ ] Error messages are clear and helpful
- [ ] Server starts without errors
- [ ] Server responds to JSON-RPC requests
- [ ] Configuration is properly loaded
- [ ] Environment variables work correctly
- [ ] Logs are written correctly
- [ ] Server shuts down gracefully
- [ ] Memory usage is reasonable
- [ ] Response times are acceptable

## Performance Testing

Test server performance:

```bash
# Test response time
time echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js

# Test multiple requests
for i in {1..10}; do
  echo '{"jsonrpc":"2.0","id":'$i',"method":"tools/list","params":{}}' | node dist/index.js
done

# Monitor memory usage
node --max-old-space-size=512 dist/index.js
```

## Debugging Tests

Enable debug logging:

```bash
DEBUG=1 npm test
```

Or add debug statements:

```typescript
import { logDebug } from './utils/logger.js';

logDebug('Tool called with params:', params);
logDebug('Result:', result);
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Test MCP Server

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm run build
      - run: npm test
```

## Coverage (Optional)

Add test coverage tracking:

```bash
npm install --save-dev nyc

# Run with coverage
nyc npm test

# Generate coverage report
nyc report --reporter=html
```

## Best Practices

1. **Test early and often** - Test after each change
2. **Test all paths** - Cover success and error cases
3. **Automate** - Use automated tests in CI/CD
4. **Integration test** - Always test with real MCP clients
5. **Document tests** - Explain what each test verifies
6. **Keep tests fast** - Tests should run quickly
7. **Mock external services** - Don't depend on external APIs in tests
