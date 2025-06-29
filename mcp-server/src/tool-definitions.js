/**
 * Tool definitions for all AitherZero infrastructure automation capabilities
 */

export class ToolDefinitions {
  constructor() {
    this.tools = new Map();
    this.initializeTools();
  }

  initializeTools() {
    // 1. PatchManager - Git workflow automation
    this.tools.set('aither_patch_workflow', {
      name: 'aither_patch_workflow',
      description: 'Execute Git-controlled patch workflows with automated issue and PR creation',
      inputSchema: {
        type: 'object',
        properties: {
          description: {
            type: 'string',
            description: 'Clear description of the patch/changes being made'
          },
          operation: {
            type: 'string',
            description: 'PowerShell code to execute for the patch operation'
          },
          createPR: {
            type: 'boolean',
            description: 'Create a pull request after applying changes',
            default: false
          },
          createIssue: {
            type: 'boolean',
            description: 'Create a GitHub issue for tracking (default: true)',
            default: true
          },
          priority: {
            type: 'string',
            enum: ['Low', 'Medium', 'High', 'Critical'],
            description: 'Priority level for the patch'
          },
          targetFork: {
            type: 'string',
            enum: ['origin', 'upstream', 'root'],
            description: 'Target fork for cross-fork operations'
          },
          testCommands: {
            type: 'array',
            items: { type: 'string' },
            description: 'Validation commands to run after applying patch'
          }
        },
        required: ['description']
      }
    });

    // 2. LabRunner - Lab automation orchestration
    this.tools.set('aither_lab_automation', {
      name: 'aither_lab_automation',
      description: 'Orchestrate lab automation workflows and infrastructure deployment',
      inputSchema: {
        type: 'object',
        properties: {
          configPath: {
            type: 'string',
            description: 'Path to lab configuration file'
          },
          labName: {
            type: 'string',
            description: 'Name of the lab to execute'
          },
          steps: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific lab steps to execute'
          },
          parallel: {
            type: 'boolean',
            description: 'Execute lab steps in parallel where possible',
            default: false
          },
          verbosity: {
            type: 'string',
            enum: ['silent', 'normal', 'detailed'],
            description: 'Output verbosity level'
          }
        }
      }
    });

    // 3. BackupManager - Backup and cleanup operations
    this.tools.set('aither_backup_management', {
      name: 'aither_backup_management',
      description: 'Manage backups, cleanup operations, and file consolidation',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['consolidate', 'cleanup', 'backup', 'status', 'statistics'],
            description: 'Backup operation to perform'
          },
          path: {
            type: 'string',
            description: 'Path to backup (for backup operation)'
          },
          retentionDays: {
            type: 'number',
            description: 'Number of days to retain backups (for cleanup)',
            default: 30
          }
        },
        required: ['operation']
      }
    });

    // 4. DevEnvironment - Development environment management
    this.tools.set('aither_dev_environment', {
      name: 'aither_dev_environment',
      description: 'Setup, validate, and manage development environments',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['initialize', 'test', 'status', 'resolve-imports'],
            description: 'Development environment operation'
          },
          force: {
            type: 'boolean',
            description: 'Force initialization even if already set up',
            default: false
          }
        },
        required: ['operation']
      }
    });

    // 5. ISO Management - ISO download, customization, and management
    this.tools.set('aither_iso_management', {
      name: 'aither_iso_management',
      description: 'Download, customize, and manage ISO files for infrastructure deployment',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['download', 'inventory', 'metadata', 'integrity', 'customize', 'autounattend'],
            description: 'ISO management operation'
          },
          product: {
            type: 'string',
            description: 'Product name for ISO download (e.g., Windows11, Ubuntu)'
          },
          version: {
            type: 'string',
            description: 'Version of the product to download'
          },
          path: {
            type: 'string',
            description: 'Path for inventory operations'
          },
          isoPath: {
            type: 'string',
            description: 'Path to ISO file for metadata/integrity operations'
          },
          sourceISO: {
            type: 'string',
            description: 'Source ISO path for customization'
          },
          outputPath: {
            type: 'string',
            description: 'Output path for customized ISO'
          },
          config: {
            type: 'object',
            description: 'Configuration for autounattend file generation'
          }
        },
        required: ['operation']
      }
    });

    // 6. Testing Framework - Comprehensive testing orchestration
    this.tools.set('aither_testing_framework', {
      name: 'aither_testing_framework',
      description: 'Execute comprehensive testing suites including bulletproof validation',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['bulletproof', 'unified', 'discover', 'config'],
            description: 'Testing operation to perform'
          },
          level: {
            type: 'string',
            enum: ['Quick', 'Standard', 'Complete'],
            description: 'Validation level for bulletproof tests',
            default: 'Quick'
          },
          modules: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific modules to test'
          },
          testTypes: {
            type: 'array',
            items: { type: 'string' },
            description: 'Types of tests to run (unit, integration, performance)'
          },
          parallel: {
            type: 'boolean',
            description: 'Execute tests in parallel',
            default: false
          }
        },
        required: ['operation']
      }
    });

    // 7. Infrastructure Deployment - OpenTofu/Terraform management
    this.tools.set('aither_infrastructure_deployment', {
      name: 'aither_infrastructure_deployment',
      description: 'Deploy and manage infrastructure using OpenTofu with security validation',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['install', 'deploy', 'security', 'template', 'compliance'],
            description: 'Infrastructure operation to perform'
          },
          configPath: {
            type: 'string',
            description: 'Path to infrastructure configuration'
          },
          templateName: {
            type: 'string',
            description: 'Name of template to export'
          }
        },
        required: ['operation']
      }
    });

    // 8. Remote Connection - Multi-protocol remote access
    this.tools.set('aither_remote_connection', {
      name: 'aither_remote_connection',
      description: 'Manage remote connections across multiple protocols (SSH, WinRM, etc.)',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['new', 'test', 'connect', 'execute', 'list'],
            description: 'Remote connection operation'
          },
          name: {
            type: 'string',
            description: 'Connection name'
          },
          hostname: {
            type: 'string',
            description: 'Target hostname or IP address'
          },
          endpointType: {
            type: 'string',
            enum: ['SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes'],
            description: 'Type of remote endpoint',
            default: 'SSH'
          },
          port: {
            type: 'number',
            description: 'Connection port'
          },
          credentialName: {
            type: 'string',
            description: 'Name of stored credential to use'
          },
          command: {
            type: 'string',
            description: 'Command to execute remotely'
          }
        }
      }
    });

    // 9. Credential Management - Secure credential storage
    this.tools.set('aither_credential_management', {
      name: 'aither_credential_management',
      description: 'Securely manage credentials for infrastructure access',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['set', 'get', 'test', 'list', 'remove'],
            description: 'Credential management operation'
          },
          name: {
            type: 'string',
            description: 'Credential name'
          },
          username: {
            type: 'string',
            description: 'Username (for set operation)'
          }
        }
      }
    });

    // 10. Logging System - Centralized logging management
    this.tools.set('aither_logging_system', {
      name: 'aither_logging_system',
      description: 'Manage centralized logging across all operations',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['initialize', 'log', 'config'],
            description: 'Logging operation'
          },
          consoleLevel: {
            type: 'string',
            enum: ['DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS'],
            description: 'Console logging level'
          },
          logLevel: {
            type: 'string',
            enum: ['DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS'],
            description: 'File logging level'
          },
          level: {
            type: 'string',
            enum: ['DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS'],
            description: 'Log entry level'
          },
          message: {
            type: 'string',
            description: 'Log message content'
          }
        }
      }
    });

    // 11. Parallel Execution - Parallel task processing
    this.tools.set('aither_parallel_execution', {
      name: 'aither_parallel_execution',
      description: 'Execute tasks in parallel using PowerShell runspaces',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['execute', 'status'],
            description: 'Parallel execution operation'
          },
          scriptBlocks: {
            type: 'array',
            items: { type: 'string' },
            description: 'PowerShell script blocks to execute in parallel'
          },
          maxJobs: {
            type: 'number',
            description: 'Maximum number of parallel jobs',
            default: 4
          }
        }
      }
    });

    // 12. Script Management - Script repository and templates
    this.tools.set('aither_script_management', {
      name: 'aither_script_management',
      description: 'Manage script repositories, templates, and one-off script execution',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['register', 'execute', 'repository', 'template', 'test'],
            description: 'Script management operation'
          },
          scriptName: {
            type: 'string',
            description: 'Name of the script'
          },
          scriptPath: {
            type: 'string',
            description: 'Path to script file'
          },
          templateName: {
            type: 'string',
            description: 'Name of script template'
          }
        }
      }
    });

    // 13. Maintenance Operations - Unified maintenance orchestration
    this.tools.set('aither_maintenance_operations', {
      name: 'aither_maintenance_operations',
      description: 'Execute unified maintenance operations across all modules',
      inputSchema: {
        type: 'object',
        properties: {
          mode: {
            type: 'string',
            enum: ['Quick', 'Full', 'Emergency'],
            description: 'Maintenance mode',
            default: 'Quick'
          },
          autoFix: {
            type: 'boolean',
            description: 'Automatically apply fixes where possible',
            default: false
          },
          updateChangelog: {
            type: 'boolean',
            description: 'Update changelog with maintenance results',
            default: false
          }
        }
      }
    });

    // 14. Repository Sync - Cross-repository synchronization
    this.tools.set('aither_repo_sync', {
      name: 'aither_repo_sync',
      description: 'Synchronize repositories across the fork chain',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['sync', 'status'],
            description: 'Repository sync operation'
          },
          targetRepo: {
            type: 'string',
            description: 'Target repository for sync operation'
          }
        },
        required: ['operation']
      }
    });

    // 15. Configuration Management - Multi-environment configuration handling
    this.tools.set('aither_configuration_management', {
      name: 'aither_configuration_management',
      description: 'Manage configuration sets across multiple environments with carousel switching',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['switch', 'list', 'create', 'clone', 'delete', 'validate'],
            description: 'Configuration management operation'
          },
          configurationName: {
            type: 'string',
            description: 'Name of the configuration set'
          },
          environment: {
            type: 'string',
            enum: ['dev', 'staging', 'prod'],
            description: 'Target environment for configuration'
          },
          sourceRepository: {
            type: 'string',
            description: 'Source repository URL for cloning configurations'
          },
          migrationOptions: {
            type: 'object',
            properties: {
              preserveLocal: {
                type: 'boolean',
                description: 'Preserve local configuration changes during migration'
              },
              backupCurrent: {
                type: 'boolean', 
                description: 'Create backup of current configuration'
              }
            }
          }
        },
        required: ['operation']
      }
    });

    // 16. Configuration Repository Manager - Git-based configuration repositories
    this.tools.set('aither_configuration_repository', {
      name: 'aither_configuration_repository',
      description: 'Create and manage Git repositories for custom configurations',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['create', 'fork', 'sync', 'validate', 'migrate'],
            description: 'Repository management operation'
          },
          repositoryName: {
            type: 'string',
            description: 'Name for the new configuration repository'
          },
          templateSource: {
            type: 'string',
            enum: ['default', 'minimal', 'enterprise'],
            description: 'Configuration template to use'
          },
          gitProvider: {
            type: 'string',
            enum: ['github', 'gitlab', 'local'],
            description: 'Git provider for repository hosting'
          },
          privateRepository: {
            type: 'boolean',
            description: 'Create as private repository',
            default: true
          }
        },
        required: ['operation']
      }
    });

    // 17. Orchestration Playbooks - Advanced workflow orchestration
    this.tools.set('aither_orchestration_playbooks', {
      name: 'aither_orchestration_playbooks',
      description: 'Execute complex orchestration playbooks with conditional logic and parallel execution',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['run', 'validate', 'list', 'create', 'cancel', 'status'],
            description: 'Playbook operation'
          },
          playbookName: {
            type: 'string',
            description: 'Name of the playbook to execute'
          },
          playbookDefinition: {
            type: 'object',
            description: 'Inline playbook definition (YAML/JSON)',
            properties: {
              steps: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    name: { type: 'string' },
                    type: { type: 'string', enum: ['script', 'condition', 'parallel'] },
                    command: { type: 'string' },
                    condition: { type: 'string' },
                    parallel: { type: 'array' }
                  }
                }
              }
            }
          },
          parameters: {
            type: 'object',
            description: 'Runtime parameters for playbook execution'
          },
          executionMode: {
            type: 'string',
            enum: ['sequential', 'parallel', 'conditional'],
            description: 'Execution mode for playbook steps'
          },
          environmentContext: {
            type: 'string',
            enum: ['dev', 'staging', 'prod'],
            description: 'Environment context for security decisions'
          }
        },
        required: ['operation']
      }
    });

    // 18. AI Tools Integration - Manage AI development tools
    this.tools.set('aither_ai_tools_integration', {
      name: 'aither_ai_tools_integration',
      description: 'Install, configure, and manage AI development tools like Claude Code, Gemini CLI',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['install', 'configure', 'status', 'update', 'remove'],
            description: 'AI tools operation'
          },
          tool: {
            type: 'string',
            enum: ['claude-code', 'gemini-cli', 'codex-cli', 'all'],
            description: 'Specific AI tool to manage'
          },
          installationProfile: {
            type: 'string',
            enum: ['minimal', 'developer', 'full'],
            description: 'Installation profile for AI tools setup'
          },
          force: {
            type: 'boolean',
            description: 'Force installation even if already installed'
          }
        },
        required: ['operation']
      }
    });

    // 19. Environment Context Manager - Smart security and confirmation handling
    this.tools.set('aither_environment_context', {
      name: 'aither_environment_context',
      description: 'Manage environment context for smart security decisions and confirmations',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['detect', 'set', 'validate', 'policy'],
            description: 'Environment context operation'
          },
          environment: {
            type: 'string',
            enum: ['dev', 'staging', 'prod'],
            description: 'Target environment'
          },
          securityPolicy: {
            type: 'object',
            properties: {
              destructiveOperations: {
                type: 'string',
                enum: ['allow', 'confirm', 'block'],
                description: 'Policy for destructive operations'
              },
              autoConfirm: {
                type: 'boolean',
                description: 'Auto-confirm operations in this environment'
              }
            }
          }
        },
        required: ['operation']
      }
    });

    // 20. Setup Wizard Enhancement - Installation profiles and setup management
    this.tools.set('aither_setup_wizard', {
      name: 'aither_setup_wizard',
      description: 'Enhanced setup wizard with installation profiles and comprehensive environment setup',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['run', 'profile', 'validate', 'reset'],
            description: 'Setup wizard operation'
          },
          installationProfile: {
            type: 'string',
            enum: ['minimal', 'developer', 'full', 'interactive'],
            description: 'Installation profile for setup'
          },
          skipOptional: {
            type: 'boolean',
            description: 'Skip optional setup steps'
          },
          configurationPath: {
            type: 'string',
            description: 'Custom configuration file path'
          }
        },
        required: ['operation']
      }
    });
  }

  getAllTools() {
    return Array.from(this.tools.values());
  }

  getTool(name) {
    return this.tools.get(name);
  }

  getToolsByCategory() {
    return {
      'Infrastructure Management': [
        'aither_infrastructure_deployment',
        'aither_lab_automation',
        'aither_remote_connection'
      ],
      'Development Workflow': [
        'aither_patch_workflow',
        'aither_dev_environment',
        'aither_testing_framework',
        'aither_script_management'
      ],
      'System Operations': [
        'aither_backup_management',
        'aither_maintenance_operations',
        'aither_logging_system',
        'aither_parallel_execution'
      ],
      'Content Management': [
        'aither_iso_management',
        'aither_credential_management',
        'aither_repo_sync'
      ],
      'Configuration Management': [
        'aither_configuration_management',
        'aither_configuration_repository',
        'aither_environment_context'
      ],
      'AI Tools & Integration': [
        'aither_ai_tools_integration',
        'aither_setup_wizard'
      ],
      'Orchestration & Automation': [
        'aither_orchestration_playbooks'
      ]
    };
  }
}
