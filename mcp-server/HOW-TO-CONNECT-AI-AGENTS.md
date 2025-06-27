# 🤖 How to Connect AI Agents to AitherZero

## Current Status
✅ **AitherZero MCP Server is RUNNING**
- 32 tools available across 7 categories
- Enhanced server listening on stdio
- VS Code toolsets auto-generated

## For GitHub Copilot in VS Code

### Step 1: Configure MCP Settings
Create or update your VS Code settings:

```json
{
  "mcp.servers": {
    "aitherzero": {
      "command": "node",
      "args": ["enhanced-index.js"],
      "cwd": "C:\\Users\\alexa\\OneDrive\\Documents\\0. wizzense\\AitherZero\\mcp-server"
    }
  }
}
```

### Step 2: Enable Toolsets in Agent Mode
1. Open Command Palette (`Ctrl+Shift+P`)
2. Type "GitHub Copilot: Configure AI Agent Mode"
3. Select AitherZero toolsets:
   - `aither-infrastructure` - Infrastructure deployment
   - `aither-development` - Development workflows
   - `aither-operations` - System operations
   - `aither-security` - Security & credentials
   - `aither-iso` - ISO management
   - `aither-advanced` - Advanced automation
   - `aither-quick-actions` - One-click tasks

### Step 3: Test Agent Access
Ask GitHub Copilot to:
- "Check system status using AitherZero tools"
- "Set up a development environment"
- "Create a backup of my project"

## For Claude Desktop / API

### Step 1: Configure MCP in Claude
Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on Mac, `%APPDATA%\\Claude\\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["enhanced-index.js"],
      "cwd": "C:\\Users\\alexa\\OneDrive\\Documents\\0. wizzense\\AitherZero\\mcp-server"
    }
  }
}
```

### Step 2: Restart Claude Desktop
- Restart the application to load the new MCP server
- Look for "AitherZero" in the available tools

## For ChatGPT / OpenAI API

### Using Custom Actions (ChatGPT Plus)
Create a custom action with this OpenAPI schema:

```yaml
openapi: 3.0.0
info:
  title: AitherZero Infrastructure Automation
  version: 1.0.0
servers:
  - url: http://localhost:3000
paths:
  /tools:
    get:
      summary: List available AitherZero tools
      responses:
        '200':
          description: List of tools
  /execute:
    post:
      summary: Execute AitherZero tool
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                tool:
                  type: string
                args:
                  type: object
```

## For Any AI Agent via HTTP Bridge

### Create HTTP Bridge
```javascript
// http-bridge.js
import express from 'express';
import { AitherZeroAgentConnector } from './connect-agent.js';

const app = express();
app.use(express.json());

const connector = new AitherZeroAgentConnector();
await connector.connect();

app.get('/tools', async (req, res) => {
  const tools = await connector.client.listTools();
  res.json(tools);
});

app.post('/execute', async (req, res) => {
  try {
    const { tool, args } = req.body;
    const result = await connector.client.callTool({
      name: tool,
      arguments: args
    });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => {
  console.log('🚀 AitherZero HTTP Bridge running on port 3000');
});
```

## Quick Test Examples

### Test 1: System Health Check
```
Tool: aither_system_status
Args: { "operation": "health" }
Expected: System health report with module status
```

### Test 2: Development Environment Setup
```
Tool: aither_dev_environment
Args: { "operation": "setup", "force": true }
Expected: Complete dev environment configuration
```

### Test 3: Quick Backup
```
Tool: aither_instant_backup
Args: { "source": ".", "retentionDays": 30 }
Expected: Backup created with cleanup of old files
```

### Test 4: Patch Workflow
```
Tool: aither_patch_workflow
Args: {
  "description": "Fix configuration issue",
  "operation": "echo 'Fixed config'",
  "createPR": false
}
Expected: Git workflow with branch creation and commit
```

## Available Tool Categories

| Category | Tools | Description |
|----------|-------|-------------|
| 🏗️ Infrastructure | 4 | Deploy, manage, orchestrate infrastructure |
| 💻 Development | 5 | Complete development lifecycle automation |
| ⚙️ Operations | 5 | Automated operations & maintenance |
| 🔒 Security | 4 | Enterprise security & credential management |
| 💿 ISO Management | 4 | Complete ISO lifecycle management |
| 🚀 Advanced | 5 | Advanced automation & AI integration |
| ⚡ Quick Actions | 5 | One-click actions for common tasks |

## Troubleshooting

### Common Issues

1. **"MCP Server not found"**
   - Ensure `node enhanced-index.js` runs successfully
   - Check the working directory path is correct

2. **"Tool execution failed"**
   - Verify PowerShell 7+ is available
   - Check that AitherZero modules are properly imported

3. **"Connection timeout"**
   - The server may still be starting up
   - Check server logs for errors

### Verification Commands

```bash
# Test server startup
cd mcp-server
node enhanced-index.js

# Expected output:
# [INFO] Enhanced AitherZero MCP Server started successfully
# [INFO] Available tools: 32
# [INFO] Available categories: 7
```

---

## 🎯 Next Steps

1. **Choose your AI agent** (GitHub Copilot, Claude, ChatGPT, etc.)
2. **Follow the configuration steps** for your chosen agent
3. **Test with simple tools** like `aither_system_status`
4. **Explore complex workflows** using multiple tool categories
5. **Build custom automation** by chaining AitherZero tools

**Your AitherZero infrastructure automation framework is now ready for AI agent integration!**
