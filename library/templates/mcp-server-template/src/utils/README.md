# Utilities Directory

This directory contains utility functions used by your MCP server.

## Included Utilities

### logger.ts

Provides logging functions that write to stderr (to avoid interfering with stdio transport):

```typescript
import { log, logError, logDebug, logWarn } from './utils/logger.js';

log('Server starting...');           // Informational
logError('Something failed:', error); // Errors
logDebug('Debug info:', data);       // Debug (only if DEBUG env var set)
logWarn('Deprecated feature used');  // Warnings
```

### executor.ts

Provides safe command execution utilities:

```typescript
import { executeCommand, buildCommand, sanitizeCommand } from './utils/executor.js';

// Execute a command
const result = await executeCommand('ls -la', '/path/to/dir');
console.log(result.stdout);
console.log(result.stderr);
console.log(result.exitCode);

// Build a command with safe escaping
const cmd = buildCommand('echo', ['hello', 'world']);

// Sanitize user input
const safe = sanitizeCommand(userInput);
```

## Adding Custom Utilities

Create new utility files as needed:

### Example: config-loader.ts

```typescript
/**
 * Configuration Loader Utility
 */

import { readFile } from 'fs/promises';
import { join } from 'path';
import { log, logError } from './logger.js';

export interface Config {
  [key: string]: any;
}

let cachedConfig: Config | null = null;

export async function loadConfig(configPath: string): Promise<Config> {
  if (cachedConfig) {
    return cachedConfig;
  }
  
  try {
    const content = await readFile(configPath, 'utf8');
    cachedConfig = JSON.parse(content);
    log('Configuration loaded successfully');
    return cachedConfig;
  } catch (error) {
    logError('Failed to load configuration:', error);
    throw error;
  }
}

export function clearConfigCache(): void {
  cachedConfig = null;
}
```

### Example: validator.ts

```typescript
/**
 * Input Validation Utility
 */

export function validateRequired(value: any, name: string): void {
  if (value === undefined || value === null || value === '') {
    throw new Error(`${name} is required`);
  }
}

export function validateEnum(value: string, allowed: string[], name: string): void {
  if (!allowed.includes(value)) {
    throw new Error(`${name} must be one of: ${allowed.join(', ')}`);
  }
}

export function validateEmail(email: string): boolean {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

export function validatePath(path: string): boolean {
  // Prevent path traversal
  return !path.includes('..') && !path.startsWith('/');
}
```

### Example: cache.ts

```typescript
/**
 * Simple Cache Utility
 */

interface CacheEntry<T> {
  value: T;
  expiry: number;
}

class SimpleCache<T> {
  private cache: Map<string, CacheEntry<T>> = new Map();
  
  set(key: string, value: T, ttlSeconds: number = 60): void {
    this.cache.set(key, {
      value,
      expiry: Date.now() + (ttlSeconds * 1000)
    });
  }
  
  get(key: string): T | null {
    const entry = this.cache.get(key);
    
    if (!entry) {
      return null;
    }
    
    if (Date.now() > entry.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.value;
  }
  
  clear(): void {
    this.cache.clear();
  }
}

export const cache = new SimpleCache();
```

## Best Practices

1. **Single responsibility** - Each utility does one thing well
2. **Pure functions** - Prefer functions without side effects
3. **Type safety** - Use TypeScript types
4. **Error handling** - Handle errors gracefully
5. **Documentation** - Comment complex logic
6. **Testing** - Write tests for utilities
7. **Reusability** - Make utilities generic

## Importing Utilities

In your main `index.ts` or tool files:

```typescript
// Import individual functions
import { log, logError } from './utils/logger.js';
import { executeCommand } from './utils/executor.js';
import { validateRequired, validateEnum } from './utils/validator.js';

// Use in your code
log('Starting operation...');
validateRequired(param, 'parameter name');
const result = await executeCommand('ls -la');
```

## Common Utility Patterns

### Pattern 1: Retry Logic

```typescript
export async function retry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delayMs: number = 1000
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }
  throw new Error('Max retries exceeded');
}
```

### Pattern 2: Rate Limiting

```typescript
class RateLimiter {
  private timestamps: number[] = [];
  
  constructor(private maxRequests: number, private windowMs: number) {}
  
  canProceed(): boolean {
    const now = Date.now();
    this.timestamps = this.timestamps.filter(t => now - t < this.windowMs);
    
    if (this.timestamps.length < this.maxRequests) {
      this.timestamps.push(now);
      return true;
    }
    
    return false;
  }
}

export const rateLimiter = new RateLimiter(10, 60000); // 10 requests per minute
```

### Pattern 3: Async Queue

```typescript
class AsyncQueue<T> {
  private queue: (() => Promise<T>)[] = [];
  private running = false;
  
  async add(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await task();
          resolve(result);
          return result;
        } catch (error) {
          reject(error);
          throw error;
        }
      });
      
      this.process();
    });
  }
  
  private async process(): Promise<void> {
    if (this.running || this.queue.length === 0) return;
    
    this.running = true;
    const task = this.queue.shift()!;
    
    try {
      await task();
    } finally {
      this.running = false;
      this.process();
    }
  }
}

export const queue = new AsyncQueue();
```

## Testing Utilities

Create tests for your utilities:

```typescript
// tests/utils/validator.test.ts
import { validateRequired, validateEnum } from '../../src/utils/validator.js';

describe('validateRequired', () => {
  it('should throw for null', () => {
    expect(() => validateRequired(null, 'test')).toThrow();
  });
  
  it('should not throw for valid value', () => {
    expect(() => validateRequired('value', 'test')).not.toThrow();
  });
});
```
