/**
 * Validation schema for AitherZero MCP tools
 */

import Joi from 'joi';

export class ValidationSchema {
  constructor() {
    this.schemas = new Map();
    this.initializeSchemas();
  }

  initializeSchemas() {
    // PatchManager workflow validation
    this.schemas.set('aither_patch_workflow', Joi.object({
      description: Joi.string().required().min(10).max(500),
      operation: Joi.string().optional(),
      createPR: Joi.boolean().default(false),
      createIssue: Joi.boolean().default(true),
      priority: Joi.string().valid('Low', 'Medium', 'High', 'Critical').optional(),
      targetFork: Joi.string().valid('origin', 'upstream', 'root').optional(),
      testCommands: Joi.array().items(Joi.string()).optional()
    }));

    // Lab automation validation
    this.schemas.set('aither_lab_automation', Joi.object({
      configPath: Joi.string().optional(),
      labName: Joi.string().optional(),
      steps: Joi.array().items(Joi.string()).optional(),
      parallel: Joi.boolean().default(false),
      verbosity: Joi.string().valid('silent', 'normal', 'detailed').optional()
    }));

    // Backup management validation
    this.schemas.set('aither_backup_management', Joi.object({
      operation: Joi.string().valid('consolidate', 'cleanup', 'backup', 'status', 'statistics').required(),
      path: Joi.string().when('operation', { is: 'backup', then: Joi.required(), otherwise: Joi.optional() }),
      retentionDays: Joi.number().integer().min(1).max(365).default(30).optional()
    }));

    // Development environment validation
    this.schemas.set('aither_dev_environment', Joi.object({
      operation: Joi.string().valid('initialize', 'test', 'status', 'resolve-imports').required(),
      force: Joi.boolean().default(false)
    }));

    // ISO management validation
    this.schemas.set('aither_iso_management', Joi.object({
      operation: Joi.string().valid('download', 'inventory', 'metadata', 'integrity', 'customize', 'autounattend').required(),
      product: Joi.string().when('operation', { is: 'download', then: Joi.required(), otherwise: Joi.optional() }),
      version: Joi.string().optional(),
      path: Joi.string().when('operation', { is: 'inventory', then: Joi.optional(), otherwise: Joi.forbidden() }),
      isoPath: Joi.string().when('operation', { is: Joi.string().valid('metadata', 'integrity'), then: Joi.required(), otherwise: Joi.optional() }),
      sourceISO: Joi.string().when('operation', { is: 'customize', then: Joi.required(), otherwise: Joi.optional() }),
      outputPath: Joi.string().when('operation', { is: 'customize', then: Joi.required(), otherwise: Joi.optional() }),
      config: Joi.object().when('operation', { is: 'autounattend', then: Joi.optional(), otherwise: Joi.forbidden() })
    }));

    // Testing framework validation
    this.schemas.set('aither_testing_framework', Joi.object({
      operation: Joi.string().valid('bulletproof', 'unified', 'discover', 'config').required(),
      level: Joi.string().valid('Quick', 'Standard', 'Complete').default('Quick'),
      modules: Joi.array().items(Joi.string()).optional(),
      testTypes: Joi.array().items(Joi.string().valid('unit', 'integration', 'performance', 'security')).optional(),
      parallel: Joi.boolean().default(false)
    }));

    // Infrastructure deployment validation
    this.schemas.set('aither_infrastructure_deployment', Joi.object({
      operation: Joi.string().valid('install', 'deploy', 'security', 'template', 'compliance').required(),
      configPath: Joi.string().when('operation', {
        is: Joi.string().valid('deploy', 'security', 'compliance'),
        then: Joi.required(),
        otherwise: Joi.optional()
      }),
      templateName: Joi.string().when('operation', { is: 'template', then: Joi.required(), otherwise: Joi.optional() })
    }));

    // Remote connection validation
    this.schemas.set('aither_remote_connection', Joi.object({
      operation: Joi.string().valid('new', 'test', 'connect', 'execute', 'list').required(),
      name: Joi.string().when('operation', {
        is: Joi.string().valid('new', 'test', 'connect', 'execute'),
        then: Joi.required(),
        otherwise: Joi.optional()
      }),
      hostname: Joi.string().when('operation', { is: 'new', then: Joi.required(), otherwise: Joi.optional() }),
      endpointType: Joi.string().valid('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes').default('SSH'),
      port: Joi.number().integer().min(1).max(65535).optional(),
      credentialName: Joi.string().optional(),
      command: Joi.string().when('operation', { is: 'execute', then: Joi.required(), otherwise: Joi.optional() })
    }));

    // Credential management validation
    this.schemas.set('aither_credential_management', Joi.object({
      operation: Joi.string().valid('set', 'get', 'test', 'list', 'remove').required(),
      name: Joi.string().when('operation', {
        is: Joi.string().valid('set', 'get', 'test', 'remove'),
        then: Joi.required(),
        otherwise: Joi.optional()
      }),
      username: Joi.string().when('operation', { is: 'set', then: Joi.required(), otherwise: Joi.optional() })
    }));

    // Logging system validation
    this.schemas.set('aither_logging_system', Joi.object({
      operation: Joi.string().valid('initialize', 'log', 'config').required(),
      consoleLevel: Joi.string().valid('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS').optional(),
      logLevel: Joi.string().valid('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS').optional(),
      level: Joi.string().valid('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS').when('operation', {
        is: 'log',
        then: Joi.required(),
        otherwise: Joi.optional()
      }),
      message: Joi.string().when('operation', { is: 'log', then: Joi.required(), otherwise: Joi.optional() })
    }));

    // Parallel execution validation
    this.schemas.set('aither_parallel_execution', Joi.object({
      operation: Joi.string().valid('execute', 'status').required(),
      scriptBlocks: Joi.array().items(Joi.string()).when('operation', {
        is: 'execute',
        then: Joi.array().items(Joi.string()).required().min(1),
        otherwise: Joi.array().items(Joi.string()).optional()
      }),
      maxJobs: Joi.number().integer().min(1).max(16).default(4)
    }));

    // Script management validation
    this.schemas.set('aither_script_management', Joi.object({
      operation: Joi.string().valid('register', 'execute', 'repository', 'template', 'test').required(),
      scriptName: Joi.string().when('operation', {
        is: Joi.string().valid('register', 'execute', 'test'),
        then: Joi.required(),
        otherwise: Joi.optional()
      }),
      scriptPath: Joi.string().when('operation', { is: 'register', then: Joi.required(), otherwise: Joi.optional() }),
      templateName: Joi.string().when('operation', { is: 'template', then: Joi.required(), otherwise: Joi.optional() })
    }));

    // Maintenance operations validation
    this.schemas.set('aither_maintenance_operations', Joi.object({
      mode: Joi.string().valid('Quick', 'Full', 'Emergency').default('Quick'),
      autoFix: Joi.boolean().default(false),
      updateChangelog: Joi.boolean().default(false)
    }));

    // Repository sync validation
    this.schemas.set('aither_repo_sync', Joi.object({
      operation: Joi.string().valid('sync', 'status').required(),
      targetRepo: Joi.string().when('operation', { is: 'sync', then: Joi.optional(), otherwise: Joi.optional() })
    }));
  }

  validateArgs(toolName, args) {
    const schema = this.schemas.get(toolName);

    if (!schema) {
      return {
        valid: false,
        errors: [`No validation schema found for tool: ${toolName}`]
      };
    }

    const { error, value } = schema.validate(args, {
      abortEarly: false,
      allowUnknown: false,
      stripUnknown: true
    });

    if (error) {
      return {
        valid: false,
        errors: error.details.map(detail => detail.message),
        validatedArgs: null
      };
    }

    return {
      valid: true,
      errors: [],
      validatedArgs: value
    };
  }

  getSchemaDescription(toolName) {
    const schema = this.schemas.get(toolName);
    if (!schema) {
      return null;
    }

    return schema.describe();
  }

  getAllSchemas() {
    const descriptions = {};
    for (const [toolName, schema] of this.schemas) {
      descriptions[toolName] = schema.describe();
    }
    return descriptions;
  }
}
