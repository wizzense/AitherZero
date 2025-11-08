# MCP Server Template

A comprehensive template for creating Model Context Protocol (MCP) servers. This template is based on the battle-tested AitherZero MCP server implementation and includes all the best practices, patterns, and infrastructure needed to quickly develop production-ready MCP servers.

## What is This Template?

This template provides a complete starting point for building custom MCP servers that can be used with AI assistants like Claude, GitHub Copilot, and other MCP-compatible clients. It includes:

- ✅ **TypeScript setup** with proper MCP SDK integration
- ✅ **Build infrastructure** (npm, TypeScript compiler, watch mode)
- ✅ **Auto-build wrapper** for seamless startup without manual building
- ✅ **Tool and resource patterns** with examples
- ✅ **Error handling** and logging best practices
- ✅ **Testing infrastructure** with examples
- ✅ **Documentation templates** for all aspects
- ✅ **Configuration management** patterns
- ✅ **Cross-platform support** considerations

## Quick Start

### Prerequisites

- **Node.js 18+** (required for MCP SDK)
- **npm** (comes with Node.js)
- **TypeScript knowledge** (for customization)
- **Understanding of MCP protocol** (see [MCP Specification](https://modelcontextprotocol.io/))

### Using the Template

There are three ways to use this template:

#### Option 1: Manual Setup (Traditional)

```bash
# 1. Copy the template to your new location
cp -r templates/mcp-server-template /path/to/your-new-mcp-server

# 2. Navigate to the new directory
cd /path/to/your-new-mcp-server

# 3. Customize the template (see Customization Guide below)
# - Update package.json with your server name and details
# - Edit src/index.ts with your tools and resources
# - Update README.md with your server documentation

# 4. Install dependencies and build
npm install
npm run build

# 5. Test your server
npm run test:manual
```

#### Option 2: Using AitherZero Automation (Recommended)

```bash
# Use the AitherZero automation script to scaffold a new MCP server
./automation-scripts/0754_Create-MCPServer.ps1 -ServerName "my-server" -Description "My custom MCP server"

# Or with the az wrapper
az 0754 -ServerName "my-server" -Description "My custom MCP server"

# This will:
# - Copy and customize the template
# - Initialize git repository
# - Install dependencies
# - Build the server
# - Create initial documentation
```

#### Option 3: AI Agent Scaffolding (For Copilot Agents)

AI agents can reference this template and use the automation script:

```
@agent Create a new MCP server called "infrastructure-monitor" that monitors 
system infrastructure and exposes tools for checking CPU, memory, and disk usage.

Use the MCP server template at templates/mcp-server-template and the 
automation script 0754_Create-MCPServer.ps1 to scaffold the server.
```

## Template Structure

```
mcp-server-template/
├── README.md                          # This file - template documentation
├── TEMPLATE-GUIDE.md                  # Detailed customization guide
├── package.json.template              # npm package configuration template
├── tsconfig.json                      # TypeScript compiler configuration
├── .gitignore                         # Git ignore patterns
├── src/
│   ├── index.ts.template             # Main server implementation template
│   ├── types.ts.template             # TypeScript type definitions template
│   ├── tools/                        # Tool implementations
│   │   ├── example-tool.ts.template  # Example tool implementation
│   │   └── README.md                 # Tool development guide
│   ├── resources/                    # Resource implementations
│   │   ├── example-resource.ts.template  # Example resource
│   │   └── README.md                 # Resource development guide
│   └── utils/                        # Utility functions
│       ├── logger.ts.template        # Logging utilities
│       ├── executor.ts.template      # Command execution utilities
│       └── README.md                 # Utilities guide
├── scripts/
│   ├── start-with-build.mjs          # Auto-build wrapper (ready to use)
│   └── README.md                     # Scripts documentation
├── test/
│   ├── basic-test.mjs.template       # Basic server test template
│   └── README.md                     # Testing guide
├── docs/
│   ├── SETUP.md.template             # Setup documentation template
│   ├── USAGE.md.template             # Usage examples template
│   ├── ARCHITECTURE.md.template      # Architecture documentation template
│   └── TROUBLESHOOTING.md.template   # Troubleshooting guide template
└── examples/
    ├── claude-config.json            # Example Claude Desktop config
    ├── copilot-config.json           # Example VS Code/Copilot config
    └── README.md                     # Configuration examples guide
```

## Key Features

### 1. Auto-Build Wrapper

The template includes `scripts/start-with-build.mjs` that automatically:
- Checks if dependencies are installed
- Installs dependencies if missing
- Builds TypeScript if needed
- Starts the server seamlessly

This means users don't need to manually run `npm install` or `npm run build` - the server just works!

### 2. Tool Pattern Template

The template provides a clean pattern for defining tools:

```typescript
{
  name: 'your_tool_name',
  description: 'Clear description of what the tool does',
  inputSchema: {
    type: 'object',
    properties: {
      param1: {
        type: 'string',
        description: 'Parameter description'
      }
    },
    required: ['param1']
  }
}
```

### 3. Resource Pattern Template

Similarly for resources:

```typescript
{
  uri: 'yourserver://resource-name',
  name: 'Resource Display Name',
  description: 'What this resource provides',
  mimeType: 'application/json'
}
```

### 4. Error Handling Best Practices

Built-in error handling patterns:

```typescript
try {
  // Tool execution
  result = await yourToolFunction(args);
  return {
    content: [{ type: 'text', text: result }]
  };
} catch (error) {
  return {
    content: [{ 
      type: 'text', 
      text: `Error: ${error instanceof Error ? error.message : String(error)}`
    }],
    isError: true
  };
}
```

## Lessons Learned from AitherZero

These lessons come from building the AitherZero MCP server:

### 1. Auto-Build is Essential
**Problem**: Users had to manually run `npm install` and `npm run build`.
**Solution**: Auto-build wrapper automates this completely.

### 2. Clear Tool Descriptions Matter
**Problem**: AI assistants didn't know when to use tools.
**Solution**: Write descriptions from the AI's perspective.

### 3. Error Handling Must Be Robust
**Problem**: Errors crashed the server or provided poor feedback.
**Solution**: Wrap all implementations in try-catch.

### 4. Resources vs Tools
**Resources**: Static or cacheable data (config, status, lists)
**Tools**: Actions that change state or execute commands

### 5. Configuration is Key
**Problem**: Hard-coded paths made server inflexible.
**Solution**: Use environment variables with sensible defaults.

### 6. Documentation for Multiple Audiences
- README.md - Overview for everyone
- SETUP.md - For users configuring the server
- ARCHITECTURE.md - For developers extending the server
- Tool descriptions - For AI assistants using the server

## Resources

- **MCP Specification**: https://modelcontextprotocol.io/
- **MCP SDK Documentation**: https://github.com/modelcontextprotocol/sdk
- **AitherZero MCP Server**: `/integrations/mcp-server/` (reference implementation)
- **TypeScript Handbook**: https://www.typescriptlang.org/docs/

## License

This template is part of AitherZero and is released under the MIT License.

---

**Happy MCP Server Building!** 🚀
