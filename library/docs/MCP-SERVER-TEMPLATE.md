# MCP Server Development Template Guide

## Overview

AitherZero provides a comprehensive template system for creating new Model Context Protocol (MCP) servers based on lessons learned from building the AitherZero MCP server. This guide explains how to use the template to quickly develop production-ready MCP servers.

## What's Included

The MCP server template (`docs/templates/mcp-server-template/`) provides:

- **Complete TypeScript scaffold** with MCP SDK integration
- **Auto-build system** for seamless first-time setup
- **Tool and resource patterns** with working examples
- **Error handling best practices** built-in
- **Comprehensive documentation templates** for all aspects
- **Testing infrastructure** with examples
- **Automation script (0754)** for scaffolding new servers
- **Configuration examples** for Claude and VS Code

## Quick Start

### Three Ways to Use the Template

#### 1. Manual Setup

```bash
# Copy the template
cp -r docs/templates/mcp-server-template /path/to/my-new-server

# Navigate and customize
cd /path/to/my-new-server

# Follow TEMPLATE-GUIDE.md for customization
# Then build and test
npm install
npm run build
npm test
```

#### 2. Automated Setup (Recommended)

```bash
# Use AitherZero automation script
./automation-scripts/0754_Create-MCPServer.ps1 \
  -ServerName "docker-manager" \
  -Description "Docker container management MCP server" \
  -Author "Your Name"

# Or with az wrapper
az 0754 -ServerName "my-server" -Description "My MCP server"
```

This automatically:

- Copies and customizes the template
- Renames all `.template` files
- Replaces placeholders with your values
- Initializes git repository
- Installs dependencies
- Builds TypeScript
- Tests the server

#### 3. AI Agent Scaffolding

AI agents can use the template via automation script:

```
@agent Create a new MCP server called "infrastructure-monitor" that monitors
system infrastructure. Use the MCP server template at
docs/templates/mcp-server-template and automation script 0754_Create-MCPServer.ps1.
```

## Template Features

### 1. Auto-Build System

The template includes `scripts/start-with-build.mjs` that:

- Checks if server is built
- Installs dependencies if needed
- Builds TypeScript if needed
- Starts server seamlessly

**Why this matters**: Users don't need to manually run `npm install` or `npm run build`. The server "just works" when configured in AI assistants.

### 2. Tool Pattern

Clear pattern for defining and implementing tools:

```typescript
// Define the tool
{
  name: 'deploy_application',
  description: 'Deploy an application to the specified environment',
  inputSchema: {
    type: 'object',
    properties: {
      appName: { type: 'string', description: 'Application name' },
      environment: { type: 'string', enum: ['dev', 'staging', 'prod'] }
    },
    required: ['appName', 'environment']
  }
}

// Implement the function
async function deployApplication(appName: string, environment: string): Promise<string> {
  // Validation
  // Execution
  // Return result
}
```

### 3. Resource Pattern

Pattern for read-only data:

```typescript
// Define the resource
{
  uri: 'myserver://status',
  name: 'Server Status',
  mimeType: 'application/json'
}

// Implement the reader
async function getServerStatus(): Promise<string> {
  // Fetch data
  // Format as JSON string
  // Return
}
```

### 4. Built-in Utilities

- **logger.ts**: Logging to stderr (doesn't interfere with stdio)
- **executor.ts**: Safe command execution with timeouts
- **types.ts**: TypeScript definitions

### 5. Comprehensive Documentation

Template includes documentation templates for:

- **README.md**: Overview and quick start
- **TEMPLATE-GUIDE.md**: Step-by-step customization
- **docs/SETUP.md**: Installation and configuration
- **docs/USAGE.md**: Usage examples and workflows
- **docs/ARCHITECTURE.md**: Technical architecture
- **docs/TROUBLESHOOTING.md**: Common issues and solutions

## Lessons Learned (From AitherZero Implementation)

### 1. Auto-Build is Essential

**Problem**: Users had to manually run npm install and build.

**Solution**: Auto-build wrapper handles everything automatically.

**Template**: Includes ready-to-use `scripts/start-with-build.mjs`.

### 2. Clear Tool Descriptions

**Problem**: AI didn't know when to use tools with vague descriptions.

**Solution**: Write descriptions from AI's perspective: "Execute...", "List...", "Search...".

**Template**: Includes examples of effective descriptions.

### 3. Robust Error Handling

**Problem**: Errors crashed server or gave poor feedback.

**Solution**: Wrap all operations in try-catch, capture stderr, provide context.

**Template**: Error handling built into all patterns.

### 4. Resources vs Tools

**When to use Resources**:

- Static or semi-static data
- Can be cached
- Read-only
- Configuration, status, lists

**When to use Tools**:

- Actions that change state
- Cannot be safely cached
- Operations with side effects

**Template**: Includes examples of both with clear guidance.

### 5. Configuration Management

**Problem**: Hard-coded paths made server inflexible.

**Solution**: Use environment variables with sensible defaults.

**Template**: Configuration pattern built-in.

### 6. Documentation for Multiple Audiences

Different people need different docs:

- **Users**: Setup and usage guides
- **Developers**: Architecture and customization guides
- **AI Assistants**: Tool/resource descriptions

**Template**: Includes all documentation types.

## Common Use Cases

The template works well for:

### 1. CLI Tool Wrappers

Wrap command-line tools like Docker, kubectl, terraform:

```typescript
// Example: Docker commands as MCP tools
async function dockerPs(all: boolean): Promise<string> {
  const flag = all ? '-a' : '';
  const result = await executeCommand(`docker ps ${flag}`);
  return result.stdout;
}
```

### 2. API Integrations

Expose REST APIs through MCP:

```typescript
// Example: GitHub API integration
async function createIssue(title: string, body: string): Promise<string> {
  const response = await fetch('https://api.github.com/repos/owner/repo/issues', {
    method: 'POST',
    headers: { 'Authorization': `token ${process.env.GITHUB_TOKEN}` },
    body: JSON.stringify({ title, body })
  });
  return JSON.stringify(await response.json());
}
```

### 3. File Operations

Manage configuration files or data:

```typescript
// Example: Config file management
async function updateConfig(key: string, value: string): Promise<string> {
  const config = JSON.parse(await readFile('config.json', 'utf8'));
  config[key] = value;
  await writeFile('config.json', JSON.stringify(config, null, 2));
  return `Updated ${key} = ${value}`;
}
```

### 4. Infrastructure Automation

Like AitherZero, expose infrastructure management:

```typescript
// Example: VM deployment
async function deployVM(name: string, specs: VMSpecs): Promise<string> {
  // Call infrastructure tool
  // Return deployment status
}
```

## Template Structure

```
mcp-server-template/
├── README.md                          # Template documentation
├── TEMPLATE-GUIDE.md                  # Customization guide
├── package.json.template              # npm package template
├── tsconfig.json                      # TypeScript config
├── .gitignore                         # Git ignore patterns
├── src/
│   ├── index.ts.template             # Main server
│   ├── types.ts.template             # Type definitions
│   ├── tools/README.md               # Tool patterns
│   ├── resources/README.md           # Resource patterns
│   └── utils/                        # Utilities
│       ├── logger.ts.template        # Logging
│       ├── executor.ts.template      # Command execution
│       └── README.md                 # Utilities guide
├── scripts/
│   ├── start-with-build.mjs          # Auto-build wrapper
│   └── README.md                     # Scripts documentation
├── test/
│   ├── basic-test.mjs.template       # Basic tests
│   └── README.md                     # Testing guide
├── docs/
│   ├── SETUP.md.template             # Setup documentation
│   ├── USAGE.md.template             # Usage examples
│   ├── ARCHITECTURE.md.template      # Architecture details
│   └── TROUBLESHOOTING.md.template   # Troubleshooting
└── examples/
    ├── claude-config.json            # Claude Desktop config
    ├── copilot-config.json           # VS Code/Copilot config
    └── README.md                     # Configuration guide
```

## Customization Checklist

After scaffolding from the template:

- [ ] Update package.json with server name and details
- [ ] Define your tools in src/index.ts
- [ ] Define your resources in src/index.ts
- [ ] Implement tool handler functions
- [ ] Implement resource reader functions
- [ ] Update README.md with your server info
- [ ] Customize docs/SETUP.md with prerequisites
- [ ] Add usage examples to docs/USAGE.md
- [ ] Document architecture in docs/ARCHITECTURE.md
- [ ] Add custom troubleshooting to docs/TROUBLESHOOTING.md
- [ ] Update configuration examples
- [ ] Add tests for your tools
- [ ] Build and test: `npm run build && npm test`
- [ ] Test with actual MCP client

## Best Practices

### Security

1. **Validate all inputs** - Never trust AI-provided data
2. **Sanitize commands** - Use proper escaping
3. **Limit permissions** - Run with minimal privileges
4. **Audit logging** - Log all operations
5. **No secrets in code** - Use environment variables

### Performance

1. **Async operations** - Use async/await properly
2. **Set timeouts** - Prevent hanging operations
3. **Cache when appropriate** - Cache expensive operations
4. **Handle errors gracefully** - Don't crash on errors

### User Experience

1. **Clear descriptions** - Help AI understand tools
2. **Good error messages** - Actionable error information
3. **Examples in docs** - Show how to use your server
4. **Test with real clients** - Verify AI integration works

## Testing Your Server

After creating from template:

```bash
# 1. Build
npm run build

# 2. Manual test
npm run test:manual

# 3. Automated tests
npm test

# 4. Test with AI assistant
# - Add to Claude or VS Code config
# - Ask AI to list available tools
# - Try using your tools
```

## Integration with AI Assistants

### Claude Desktop

```json
{
  "mcpServers": {
    "your-server": {
      "command": "node",
      "args": ["/path/to/your-server/scripts/start-with-build.mjs"],
      "env": {
        "YOUR_SERVER_ROOT": "/path/to/your-server"
      }
    }
  }
}
```

### VS Code / GitHub Copilot

```json
{
  "mcpServers": {
    "your-server": {
      "command": "node",
      "args": ["${workspaceFolder}/your-server/scripts/start-with-build.mjs"],
      "description": "Your server description",
      "capabilities": {
        "resources": true,
        "tools": true
      }
    }
  }
}
```

## Getting Help

- **Template Guide**: `docs/templates/mcp-server-template/TEMPLATE-GUIDE.md`
- **Example Implementation**: `/mcp-server/` (AitherZero MCP server)
- **MCP Specification**: <https://modelcontextprotocol.io/>
- **MCP SDK**: <https://github.com/modelcontextprotocol/sdk>
- **Issues**: <https://github.com/wizzense/AitherZero/issues>

## Contributing Template Improvements

If you improve the template:

1. Test your changes thoroughly
2. Update documentation
3. Submit PR to AitherZero
4. Share your use case in discussions

## Related Resources

- **AitherZero MCP Server**: `/integrations/mcp-server/` - Reference implementation
- **MCP Documentation**: `docs/AITHERZERO-MCP-SERVER.md`
- **MCP Setup Guide**: `docs/COPILOT-MCP-SETUP.md`
- **GitHub Copilot Integration**: `.github/copilot-instructions.md`

---

This template represents the accumulated experience of building and deploying the AitherZero MCP server. It's designed to help you avoid common pitfalls and build high-quality MCP servers quickly.
