# Template Customization Guide

This guide walks you through customizing the MCP server template for your specific use case.

## Step-by-Step Customization

### 1. Server Identity

**File: `package.json`**

Replace these placeholders:
- `@YOURORG` - Your organization/username (e.g., `@mycompany`)
- `SERVERNAME` - Your server name (e.g., `docker-manager`)
- `DESCRIPTION` - Brief description of what your server does
- `AUTHOR` - Your name or organization

Example:
```json
{
  "name": "@mycompany/docker-manager-mcp-server",
  "description": "Model Context Protocol server for Docker container management",
  "author": "MyCompany DevOps Team"
}
```

### 2. Main Server Implementation

**File: `src/index.ts`**

1. **Update server constants** (lines 22-24):
```typescript
const SERVER_NAME = 'docker-manager-server';
const SERVER_VERSION = '0.1.0';
const SERVER_ROOT = process.env.DOCKER_MANAGER_ROOT || process.cwd();
```

2. **Define your tools** (in `ListToolsRequestSchema` handler):
```typescript
{
  name: 'list_containers',
  description: 'List all Docker containers',
  inputSchema: {
    type: 'object',
    properties: {
      all: {
        type: 'boolean',
        description: 'Include stopped containers'
      }
    }
  }
}
```

3. **Implement tool functions**:
```typescript
async function listContainers(all: boolean = false): Promise<string> {
  const flag = all ? '-a' : '';
  const result = await executeCommand(`docker ps ${flag}`, SERVER_ROOT);
  return result.stdout;
}
```

4. **Add tool handlers** (in `CallToolRequestSchema` handler):
```typescript
case 'list_containers':
  result = await listContainers(args.all as boolean);
  break;
```

5. **Define resources** (if needed):
```typescript
{
  uri: 'docker://status',
  name: 'Docker Status',
  description: 'Current Docker daemon status',
  mimeType: 'application/json'
}
```

6. **Implement resource readers**:
```typescript
async function getDockerStatus(): Promise<string> {
  const result = await executeCommand('docker info --format json', SERVER_ROOT);
  return result.stdout;
}
```

### 3. Custom Types

**File: `src/types.ts`**

Add type definitions for your server:
```typescript
export interface Container {
  id: string;
  name: string;
  image: string;
  status: string;
}

export interface DockerStatus {
  version: string;
  containersRunning: number;
  containersPaused: number;
  containersStopped: number;
}
```

### 4. Utilities

**Files: `src/utils/logger.ts`, `src/utils/executor.ts`**

These are generally ready to use, but you can:
- Add custom logging levels
- Add specific command execution patterns
- Add error handling for your specific backend

### 5. Testing

**File: `test/basic-test.mjs`**

Customize the test to:
- Test your specific tools
- Verify your resources
- Add integration tests

Example:
```javascript
// Test 3: Test your custom tool
console.log('\n✓ Test 3: List containers');
const listRequest = {
  jsonrpc: '2.0',
  id: 3,
  method: 'tools/call',
  params: {
    name: 'list_containers',
    arguments: { all: true }
  }
};
const listResponse = await sendRequest(serverProcess, listRequest);
console.log('  Result:', listResponse.result.content[0].text);
```

### 6. Documentation

Update these documentation files:

**README.md**: Replace SERVERNAME and DESCRIPTION throughout

**docs/SETUP.md**: Add your specific setup instructions
- Prerequisites for your server
- Configuration requirements
- Environment variables

**docs/USAGE.md**: Document your tools and resources
- Tool examples
- Resource examples
- Common workflows

**docs/ARCHITECTURE.md**: Explain your server's design
- Architecture diagram
- Component interactions
- Design decisions

### 7. Configuration Examples

**files: `examples/claude-config.json`, `examples/copilot-config.json`**

Update with your server's configuration:
```json
{
  "mcpServers": {
    "docker-manager": {
      "command": "node",
      "args": ["/path/to/docker-manager/scripts/start-with-build.mjs"],
      "env": {
        "DOCKER_MANAGER_ROOT": "/path/to/docker-manager",
        "DOCKER_HOST": "unix:///var/run/docker.sock"
      }
    }
  }
}
```

## Renaming Template Files

After customization, rename `.template` files:

```bash
# Rename TypeScript files
mv src/index.ts.template src/index.ts
mv src/types.ts.template src/types.ts
mv src/utils/logger.ts.template src/utils/logger.ts
mv src/utils/executor.ts.template src/utils/executor.ts

# Rename package.json
mv package.json.template package.json

# Rename test file
mv test/basic-test.mjs.template test/basic-test.mjs

# Rename documentation
mv docs/SETUP.md.template docs/SETUP.md
mv docs/USAGE.md.template docs/USAGE.md
mv docs/ARCHITECTURE.md.template docs/ARCHITECTURE.md
mv docs/TROUBLESHOOTING.md.template docs/TROUBLESHOOTING.md
```

Or use the automation script which does this automatically:
```bash
az 0754 -ServerName "my-server" -Description "My MCP server"
```

## Building and Testing

After customization:

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Test the server
npm run test:manual

# Run automated tests
npm test

# Start the server
npm start
```

## Integration Testing

Test with an actual MCP client:

1. **Add to Claude Desktop** config
2. **Restart Claude**
3. **Try asking**: "List available tools" or "What can you do with [your server]?"
4. **Execute a tool**: Ask Claude to use one of your tools

Or test with VS Code/GitHub Copilot:

1. **Add to `.vscode/settings.json`** or `.github/mcp-servers.json`
2. **Reload VS Code**
3. **Use Copilot Chat**: Try using your server's capabilities

## Common Customization Patterns

### Pattern 1: CLI Tool Wrapper

If wrapping a CLI tool like `kubectl`, `terraform`, etc.:

1. **Tools** = CLI commands (e.g., `apply`, `destroy`, `list`)
2. **Resources** = Static info (e.g., current state, config)
3. **Use executeCommand** utility for running commands

### Pattern 2: API Integration

If integrating with REST APIs:

1. **Tools** = API actions (e.g., `create_issue`, `update_status`)
2. **Resources** = API data (e.g., user info, project details)
3. **Add** `fetch` or HTTP client library
4. **Handle** authentication via environment variables

### Pattern 3: File Operations

If managing files/configs:

1. **Tools** = File operations (e.g., `read_config`, `update_setting`)
2. **Resources** = File contents or metadata
3. **Add** file system utilities
4. **Validate** paths for security

### Pattern 4: Database Operations

If querying databases:

1. **Tools** = Queries (e.g., `search_users`, `get_stats`)
2. **Resources** = Schema info, connection status
3. **Add** database client library
4. **Use** parameterized queries only
5. **Implement** connection pooling

## Tips for Success

1. **Start simple** - Get one tool working before adding more
2. **Test frequently** - Build and test after each change
3. **Clear descriptions** - AI assistants rely on good descriptions
4. **Handle errors** - Every tool should have error handling
5. **Log everything** - Use logger utility for debugging
6. **Document examples** - Show actual usage examples
7. **Security first** - Validate inputs, sanitize commands
8. **Version your API** - Make breaking changes in new versions

## Getting Help

- Review AitherZero's MCP server: `/mcp-server/src/index.ts`
- Check MCP SDK docs: https://github.com/modelcontextprotocol/sdk
- Read MCP spec: https://modelcontextprotocol.io/
- Ask in discussions: https://github.com/wizzense/AitherZero/discussions
