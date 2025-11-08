# Resources Directory

This directory contains resource implementations for your MCP server.

## What are Resources?

Resources are **read-only data** that AI assistants can query. They represent information that:
- Is static or semi-static
- Can be cached
- Doesn't change state
- Provides context or configuration
- Can be read multiple times without side effects

## Resource vs Tool

Use a **Resource** when:
- Data is read-only
- No side effects
- Can be cached
- Represents state or configuration

Use a **Tool** when:
- Action changes state
- Has side effects
- Cannot be safely cached
- Performs an operation

## Resource Structure

Each resource should:
1. Have a unique URI (format: `servername://resource-name`)
2. Include a descriptive name
3. Provide clear description
4. Specify MIME type
5. Return consistent format

## Example Resource

```typescript
// Define the resource
{
  uri: 'myserver://status',
  name: 'Server Status',
  description: 'Current status of the server including uptime and active connections',
  mimeType: 'application/json'
}

// Implement the reader
async function getServerStatus(): Promise<string> {
  log('Reading server status');
  
  try {
    const status = {
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      pid: process.pid,
      nodeVersion: process.version,
      timestamp: new Date().toISOString()
    };
    
    return JSON.stringify(status, null, 2);
  } catch (error) {
    logError('Error reading server status:', error);
    throw error;
  }
}
```

## Resource Patterns

### Pattern 1: Configuration Data

```typescript
async function getConfiguration(): Promise<string> {
  const configPath = join(SERVER_ROOT, 'config.json');
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  return JSON.stringify(config, null, 2);
}
```

### Pattern 2: Status Information

```typescript
async function getHealthStatus(): Promise<string> {
  const checks = {
    database: await checkDatabase(),
    api: await checkAPI(),
    disk: await checkDiskSpace(),
    memory: await checkMemory()
  };
  
  const overall = Object.values(checks).every(c => c.healthy);
  
  return JSON.stringify({
    overall: overall ? 'healthy' : 'unhealthy',
    checks,
    timestamp: new Date().toISOString()
  }, null, 2);
}
```

### Pattern 3: List of Items

```typescript
async function getAvailableEnvironments(): Promise<string> {
  const environments = [
    { name: 'dev', url: 'https://dev.example.com' },
    { name: 'staging', url: 'https://staging.example.com' },
    { name: 'prod', url: 'https://example.com' }
  ];
  
  return JSON.stringify(environments, null, 2);
}
```

### Pattern 4: Computed Metrics

```typescript
async function getProjectMetrics(): Promise<string> {
  const result = await executeCommand('find . -name "*.ts" | wc -l');
  const fileCount = parseInt(result.stdout);
  
  const metrics = {
    totalFiles: fileCount,
    lastBuild: await getLastBuildTime(),
    coverage: await getTestCoverage(),
    issues: await getOpenIssues()
  };
  
  return JSON.stringify(metrics, null, 2);
}
```

## MIME Types

Common MIME types for resources:

- `application/json` - JSON data (most common)
- `text/plain` - Plain text
- `text/markdown` - Markdown documentation
- `text/html` - HTML content
- `text/csv` - CSV data
- `application/xml` - XML data

## Caching Considerations

Resources may be cached by MCP clients. Consider:

1. **Update frequency** - How often does data change?
2. **Cache invalidation** - When should cache be cleared?
3. **Resource hints** - Future MCP versions may support cache control

For now, assume resources may be cached for a short time (seconds to minutes).

## Organizing Resources

For larger servers, organize resources into separate files:

```
resources/
├── config-resources.ts     # Configuration resources
├── status-resources.ts     # Status resources
├── metrics-resources.ts    # Metrics resources
└── index.ts                # Export all resources
```

## Best Practices

1. **Consistent format** - Always return same structure
2. **Handle errors** - Graceful error handling
3. **Log access** - Track resource reads
4. **Fast reads** - Resources should be quick to read
5. **Cacheable** - Design for caching
6. **Documented** - Clear descriptions
7. **Version aware** - Consider versioning for breaking changes

## Example: Complete Resource Implementation

```typescript
// In main index.ts

// 1. Define resource
server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: 'myserver://deployment-status',
      name: 'Deployment Status',
      description: 'Current status of all deployments',
      mimeType: 'application/json'
    }
  ]
}));

// 2. Implement reader
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;
  
  try {
    let content: string;
    
    switch (uri) {
      case 'myserver://deployment-status':
        content = await getDeploymentStatus();
        break;
      default:
        throw new Error(`Unknown resource: ${uri}`);
    }
    
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: content
        }
      ]
    };
  } catch (error) {
    logError(`Resource error (${uri}):`, error);
    throw error;
  }
});

// 3. Implement function
async function getDeploymentStatus(): Promise<string> {
  const status = {
    prod: { version: '1.2.3', health: 'healthy', uptime: 12345 },
    staging: { version: '1.3.0-rc1', health: 'healthy', uptime: 6789 },
    dev: { version: '1.4.0-dev', health: 'degraded', uptime: 123 }
  };
  
  return JSON.stringify(status, null, 2);
}
```

## Security Considerations

1. **No sensitive data** - Don't expose secrets
2. **Access control** - Consider who can read resources
3. **Data sanitization** - Remove internal details
4. **Validate URIs** - Check URI format
5. **Rate limiting** - Consider limits for expensive reads
