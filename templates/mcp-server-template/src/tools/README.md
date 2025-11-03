# Tools Directory

This directory contains tool implementations for your MCP server.

## What are Tools?

Tools are **actions** that AI assistants can invoke. They represent operations that:
- Change state
- Execute commands
- Perform calculations
- Interact with external systems
- Take some action

## Tool Structure

Each tool should:
1. Have a clear, descriptive name (use `snake_case`)
2. Include a detailed description for the AI
3. Define an input schema with proper types
4. Handle errors gracefully
5. Return formatted results

## Example Tool

```typescript
// Define the tool
{
  name: 'deploy_application',
  description: 'Deploy an application to the specified environment',
  inputSchema: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'Name of the application to deploy'
      },
      environment: {
        type: 'string',
        enum: ['dev', 'staging', 'prod'],
        description: 'Target environment for deployment'
      }
    },
    required: ['appName', 'environment']
  }
}

// Implement the function
async function deployApplication(appName: string, environment: string): Promise<string> {
  log(`Deploying ${appName} to ${environment}`);
  
  try {
    // Validate inputs
    if (!['dev', 'staging', 'prod'].includes(environment)) {
      throw new Error('Invalid environment');
    }
    
    // Execute deployment
    const result = await executeCommand(
      `deploy --app ${appName} --env ${environment}`,
      SERVER_ROOT
    );
    
    return `Successfully deployed ${appName} to ${environment}\n${result.stdout}`;
  } catch (error) {
    logError('Deployment failed:', error);
    throw error;
  }
}
```

## Tool Patterns

### Pattern 1: Simple Command Wrapper

```typescript
async function restartService(serviceName: string): Promise<string> {
  const result = await executeCommand(`systemctl restart ${serviceName}`);
  return result.stdout;
}
```

### Pattern 2: API Call

```typescript
async function createIssue(title: string, body: string): Promise<string> {
  const response = await fetch('https://api.example.com/issues', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, body })
  });
  
  const data = await response.json();
  return JSON.stringify(data, null, 2);
}
```

### Pattern 3: File Operation

```typescript
async function updateConfig(key: string, value: string): Promise<string> {
  const configPath = join(SERVER_ROOT, 'config.json');
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  
  config[key] = value;
  
  await writeFile(configPath, JSON.stringify(config, null, 2));
  return `Updated ${key} = ${value}`;
}
```

### Pattern 4: Multi-Step Operation

```typescript
async function backupAndUpdate(database: string): Promise<string> {
  // Step 1: Backup
  log('Creating backup...');
  await executeCommand(`pg_dump ${database} > backup.sql`);
  
  // Step 2: Update
  log('Running update...');
  await executeCommand(`psql ${database} < update.sql`);
  
  // Step 3: Verify
  log('Verifying update...');
  const result = await executeCommand(`psql ${database} -c "SELECT version()"`);
  
  return `Update complete. Version: ${result.stdout}`;
}
```

## Best Practices

1. **Validate all inputs** - Never trust data from AI
2. **Handle errors gracefully** - Always use try-catch
3. **Log operations** - Use logger utility
4. **Return useful information** - Help AI understand results
5. **Keep functions focused** - One tool = one responsibility
6. **Document parameters** - Clear descriptions for AI
7. **Consider timeouts** - Some operations take time
8. **Test thoroughly** - Test with real MCP clients

## Organizing Tools

For larger servers, organize tools into separate files:

```
tools/
├── deployment-tools.ts    # Deployment related tools
├── monitoring-tools.ts    # Monitoring related tools
├── admin-tools.ts         # Admin related tools
└── index.ts               # Export all tools
```

Then import in main index.ts:
```typescript
import { deployApplication, rollbackDeployment } from './tools/deployment-tools.js';
```

## Security Considerations

1. **Input validation** - Validate and sanitize all inputs
2. **Command injection** - Use `buildCommand()` for safe escaping
3. **Path traversal** - Validate paths, use `path.join()`
4. **Sensitive data** - Don't log secrets or credentials
5. **Rate limiting** - Consider limits for expensive operations
6. **Permissions** - Run with minimal required privileges
