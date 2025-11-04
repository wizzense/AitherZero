# Scripts Directory

This directory contains helper scripts for building and running your MCP server.

## Included Scripts

### start-with-build.mjs

**Purpose**: Auto-build wrapper that handles first-time setup automatically.

**What it does**:
1. Checks if `dist/index.js` exists
2. If not, checks if `node_modules` exists
3. Runs `npm install` if dependencies are missing
4. Runs `npm run build` to compile TypeScript
5. Starts the server with `node dist/index.js`

**Usage**:
```bash
# Just run the wrapper - it handles everything
node scripts/start-with-build.mjs
```

**Why it exists**:
Users don't need to remember to run `npm install` or `npm run build`. The server "just works" on first use. This is especially important for MCP server configuration where users just point to a script and expect it to work.

**Configuration**:
No configuration needed - it's ready to use as-is.

## Adding Custom Scripts

### Example: watch-and-restart.mjs

Automatically rebuild and restart server when code changes:

```javascript
#!/usr/bin/env node

import { spawn } from 'child_process';
import { watch } from 'fs';

let serverProcess = null;

function startServer() {
  if (serverProcess) {
    serverProcess.kill();
  }
  
  console.log('🚀 Starting server...');
  serverProcess = spawn('node', ['dist/index.js'], {
    stdio: 'inherit'
  });
}

function rebuild() {
  console.log('🔨 Rebuilding...');
  const build = spawn('npm', ['run', 'build'], {
    stdio: 'inherit'
  });
  
  build.on('exit', (code) => {
    if (code === 0) {
      startServer();
    }
  });
}

// Watch src directory
watch('./src', { recursive: true }, (eventType, filename) => {
  console.log(`📝 Changed: ${filename}`);
  rebuild();
});

// Initial build and start
rebuild();
```

Then add to package.json:
```json
{
  "scripts": {
    "watch": "node scripts/watch-and-restart.mjs"
  }
}
```

### Example: test-server.mjs

Quick script to test server functionality:

```javascript
#!/usr/bin/env node

import { spawn } from 'child_process';

async function testServer() {
  console.log('🧪 Testing MCP Server...\n');
  
  const server = spawn('node', ['dist/index.js'], {
    stdio: ['pipe', 'pipe', 'inherit']
  });
  
  // Test 1: List tools
  const toolsRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/list',
    params: {}
  };
  
  server.stdin.write(JSON.stringify(toolsRequest) + '\n');
  
  server.stdout.once('data', (data) => {
    const response = JSON.parse(data.toString());
    console.log('✅ Server responding');
    console.log(`Found ${response.result.tools.length} tools`);
    server.kill();
    process.exit(0);
  });
  
  setTimeout(() => {
    console.error('❌ Test timeout');
    server.kill();
    process.exit(1);
  }, 5000);
}

testServer();
```

### Example: validate-config.mjs

Validate server configuration:

```javascript
#!/usr/bin/env node

import { readFile } from 'fs/promises';
import { existsSync } from 'fs';

async function validateConfig() {
  console.log('🔍 Validating configuration...\n');
  
  // Check package.json
  if (!existsSync('package.json')) {
    console.error('❌ package.json not found');
    process.exit(1);
  }
  
  const pkg = JSON.parse(await readFile('package.json', 'utf8'));
  console.log('✅ package.json valid');
  
  // Check dependencies
  if (!pkg.dependencies?.['@modelcontextprotocol/sdk']) {
    console.error('❌ Missing MCP SDK dependency');
    process.exit(1);
  }
  console.log('✅ MCP SDK dependency present');
  
  // Check TypeScript config
  if (!existsSync('tsconfig.json')) {
    console.error('❌ tsconfig.json not found');
    process.exit(1);
  }
  console.log('✅ tsconfig.json exists');
  
  // Check source files
  if (!existsSync('src/index.ts')) {
    console.error('❌ src/index.ts not found');
    process.exit(1);
  }
  console.log('✅ Source files present');
  
  console.log('\n✅ Configuration valid!');
}

validateConfig();
```

## Script Best Practices

1. **Shebang** - Include `#!/usr/bin/env node` for direct execution
2. **Error handling** - Handle errors gracefully
3. **User feedback** - Use emoji and clear messages
4. **Exit codes** - Use proper exit codes (0 = success, 1 = error)
5. **Documentation** - Add comments explaining what script does
6. **Cross-platform** - Test on Windows, macOS, Linux
7. **Permissions** - Make scripts executable: `chmod +x script.mjs`

## Using Scripts

### In package.json

Add scripts to package.json for easy access:

```json
{
  "scripts": {
    "start": "node dist/index.js",
    "start:auto": "node scripts/start-with-build.mjs",
    "dev": "node scripts/watch-and-restart.mjs",
    "test:server": "node scripts/test-server.mjs",
    "validate": "node scripts/validate-config.mjs"
  }
}
```

Then run with npm:
```bash
npm run start:auto
npm run dev
npm run test:server
npm run validate
```

### In MCP Configuration

Reference scripts in MCP client configurations:

```json
{
  "command": "node",
  "args": ["${workspaceFolder}/scripts/start-with-build.mjs"]
}
```

## Troubleshooting Scripts

### Permission Denied

```bash
# Make script executable
chmod +x scripts/your-script.mjs
```

### Module Not Found

```bash
# Ensure you're using .mjs extension for ES modules
# Or add "type": "module" to package.json
```

### Path Issues

```bash
# Use absolute paths or __dirname
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');
```
