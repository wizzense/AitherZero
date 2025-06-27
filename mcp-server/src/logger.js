/**
 * Logger for AitherZero MCP Server
 */

export class Logger {
  constructor(options = {}) {
    this.level = options.level || 'info';
    this.enableConsole = options.enableConsole !== false;
    this.enableFile = options.enableFile || false;
    this.logFile = options.logFile || 'mcp-server.log';
  }

  log(level, message, metadata = {}) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level: level.toUpperCase(),
      message,
      ...metadata
    };

    if (this.enableConsole) {
      this.logToConsole(logEntry);
    }

    if (this.enableFile) {
      this.logToFile(logEntry);
    }
  }

  logToConsole(entry) {
    const colorMap = {
      ERROR: '\x1b[31m',   // Red
      WARN: '\x1b[33m',    // Yellow
      INFO: '\x1b[36m',    // Cyan
      DEBUG: '\x1b[37m',   // White
      SUCCESS: '\x1b[32m'  // Green
    };

    const reset = '\x1b[0m';
    const color = colorMap[entry.level] || reset;

    console.log(`${color}[${entry.timestamp}] ${entry.level}: ${entry.message}${reset}`);

    if (Object.keys(entry).length > 3) {
      const metadata = { ...entry };
      delete metadata.timestamp;
      delete metadata.level;
      delete metadata.message;
      console.log(`${color}Metadata:${reset}`, metadata);
    }
  }

  logToFile(entry) {
    // File logging implementation would go here
    // For now, just log to console in a structured format
    console.log(JSON.stringify(entry));
  }

  error(message, metadata = {}) {
    this.log('error', message, metadata);
  }

  warn(message, metadata = {}) {
    this.log('warn', message, metadata);
  }

  info(message, metadata = {}) {
    this.log('info', message, metadata);
  }

  debug(message, metadata = {}) {
    this.log('debug', message, metadata);
  }

  success(message, metadata = {}) {
    this.log('success', message, metadata);
  }
}
