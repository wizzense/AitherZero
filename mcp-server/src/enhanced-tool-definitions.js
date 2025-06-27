/**
 * Enhanced Tool Definitions for AitherZero MCP Server
 * Comprehensive infrastructure automation capabilities exposed as AI tools
 */

export class EnhancedToolDefinitions {
  constructor() {
    this.tools = new Map();
    this.categories = new Map();
    this.initializeTools();
    this.initializeCategories();
  }

  initializeCategories() {
    this.categories.set('infrastructure', {
      name: 'Infrastructure Management',
      description: 'Deploy, manage, and orchestrate infrastructure',
      icon: 'server',
      tools: ['aither_infrastructure_deployment', 'aither_lab_automation', 'aither_remote_connection', 'aither_opentofu_provider']
    });

    this.categories.set('development', {
      name: 'Development Workflow',
      description: 'Complete development lifecycle automation',
      icon: 'code',
      tools: ['aither_patch_workflow', 'aither_dev_environment', 'aither_testing_framework', 'aither_script_management', 'aither_repo_sync']
    });

    this.categories.set('operations', {
      name: 'System Operations',
      description: 'Automated operations and maintenance',
      icon: 'gear',
      tools: ['aither_backup_management', 'aither_maintenance_operations', 'aither_logging_system', 'aither_parallel_execution', 'aither_unified_maintenance']
    });

    this.categories.set('security', {
      name: 'Security & Credentials',
      description: 'Enterprise security and credential management',
      icon: 'shield',
      tools: ['aither_credential_management', 'aither_secure_storage', 'aither_encryption_tools', 'aither_audit_logging']
    });

    this.categories.set('iso', {
      name: 'ISO Management',
      description: 'Complete ISO lifecycle management',
      icon: 'package',
      tools: ['aither_iso_download', 'aither_iso_customization', 'aither_iso_validation', 'aither_autounattend_generation']
    });

    this.categories.set('advanced', {
      name: 'Advanced Automation',
      description: 'AI-powered advanced automation capabilities',
      icon: 'rocket',
      tools: ['aither_cross_platform_executor', 'aither_performance_monitoring', 'aither_health_diagnostics', 'aither_workflow_orchestration', 'aither_ai_integration']
    });

    this.categories.set('quick', {
      name: 'Quick Actions',
      description: 'One-click actions for common tasks',
      icon: 'zap',
      tools: ['aither_quick_patch', 'aither_emergency_rollback', 'aither_instant_backup', 'aither_fast_validation', 'aither_system_status']
    });
  }

  initializeTools() {
    // ===== DEVELOPMENT WORKFLOW TOOLS =====

    this.tools.set('aither_patch_workflow', {
      name: 'aither_patch_workflow',
      description: 'Execute Git-controlled patch workflows with automated issue and PR creation using PatchManager v2.1',
      category: 'development',
      inputSchema: {
        type: 'object',
        properties: {
          description: {
            type: 'string',
            description: 'Clear description of the patch/changes being made'
          },
          operation: {
            type: 'string',
            description: 'PowerShell code block to execute for the patch operation'
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
            description: 'Priority level for the patch',
            default: 'Medium'
          },
          targetFork: {
            type: 'string',
            enum: ['origin', 'upstream', 'root'],
            description: 'Target fork for cross-fork operations (origin=current, upstream=AitherLabs, root=Aitherium)',
            default: 'origin'
          },
          testCommands: {
            type: 'array',
            items: { type: 'string' },
            description: 'Validation commands to run after applying patch'
          },
          dryRun: {
            type: 'boolean',
            description: 'Preview changes without executing them',
            default: false
          }
        },
        required: ['description']
      },
      examples: [
        {
          description: "Fix module import issues",
          operation: "Resolve-ModuleImportIssues -Force",
          createPR: true,
          testCommands: ["Import-Module './aither-core/modules/DevEnvironment' -Force"]
        }
      ]
    });

    this.tools.set('aither_dev_environment', {
      name: 'aither_dev_environment',
      description: 'Setup and validate development environments with all required dependencies',
      category: 'development',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['setup', 'validate', 'repair', 'status', 'reset'],
            description: 'Development environment operation to perform',
            default: 'setup'
          },
          components: {
            type: 'array',
            items: {
              type: 'string',
              enum: ['powershell', 'git', 'github-cli', 'opentofu', 'vscode', 'modules', 'all']
            },
            description: 'Specific components to setup/validate',
            default: ['all']
          },
          force: {
            type: 'boolean',
            description: 'Force reinstallation of components',
            default: false
          },
          interactive: {
            type: 'boolean',
            description: 'Run in interactive mode with prompts',
            default: false
          }
        }
      }
    });

    this.tools.set('aither_testing_framework', {
      name: 'aither_testing_framework',
      description: 'Run comprehensive testing including bulletproof validation with multiple levels',
      category: 'development',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['bulletproof', 'unit', 'integration', 'performance', 'security', 'all'],
            description: 'Type of testing to perform'
          },
          level: {
            type: 'string',
            enum: ['Quick', 'Standard', 'Complete'],
            description: 'Validation level for bulletproof testing',
            default: 'Standard'
          },
          modules: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific modules to test (empty = all modules)'
          },
          parallel: {
            type: 'boolean',
            description: 'Run tests in parallel where possible',
            default: true
          },
          failFast: {
            type: 'boolean',
            description: 'Stop on first test failure',
            default: false
          },
          ci: {
            type: 'boolean',
            description: 'Run in CI mode with minimal output',
            default: false
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_script_management', {
      name: 'aither_script_management',
      description: 'Manage script repositories, templates, and automation scripts',
      category: 'development',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['list', 'create', 'update', 'delete', 'template', 'validate'],
            description: 'Script management operation'
          },
          scriptName: {
            type: 'string',
            description: 'Name of the script to manage'
          },
          templateType: {
            type: 'string',
            enum: ['module', 'test', 'automation', 'infrastructure', 'utility'],
            description: 'Type of script template to create'
          },
          parameters: {
            type: 'object',
            description: 'Parameters for script creation/updates'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_repo_sync', {
      name: 'aither_repo_sync',
      description: 'Synchronize repositories and manage cross-fork operations',
      category: 'development',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['sync', 'status', 'fetch', 'merge', 'rebase', 'push'],
            description: 'Repository synchronization operation'
          },
          source: {
            type: 'string',
            enum: ['upstream', 'origin', 'root'],
            description: 'Source repository for sync operation'
          },
          target: {
            type: 'string',
            enum: ['local', 'origin', 'upstream'],
            description: 'Target for sync operation'
          },
          branches: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific branches to sync (empty = current branch)'
          }
        },
        required: ['operation']
      }
    });

    // ===== INFRASTRUCTURE MANAGEMENT TOOLS =====

    this.tools.set('aither_infrastructure_deployment', {
      name: 'aither_infrastructure_deployment',
      description: 'Deploy infrastructure using OpenTofu/Terraform with security validation',
      category: 'infrastructure',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['plan', 'apply', 'destroy', 'validate', 'init', 'refresh'],
            description: 'Infrastructure operation to perform'
          },
          configPath: {
            type: 'string',
            description: 'Path to infrastructure configuration files'
          },
          environment: {
            type: 'string',
            enum: ['dev', 'staging', 'prod', 'lab'],
            description: 'Target environment for deployment',
            default: 'lab'
          },
          autoApprove: {
            type: 'boolean',
            description: 'Auto-approve changes without confirmation',
            default: false
          },
          variables: {
            type: 'object',
            description: 'Infrastructure variables to set'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_lab_automation', {
      name: 'aither_lab_automation',
      description: 'Orchestrate complete lab automation workflows and infrastructure deployment',
      category: 'infrastructure',
      inputSchema: {
        type: 'object',
        properties: {
          configPath: {
            type: 'string',
            description: 'Path to lab configuration file'
          },
          labName: {
            type: 'string',
            description: 'Name of the lab environment to deploy'
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
            description: 'Output verbosity level',
            default: 'normal'
          },
          auto: {
            type: 'boolean',
            description: 'Run in fully automated mode',
            default: false
          }
        }
      }
    });

    this.tools.set('aither_remote_connection', {
      name: 'aither_remote_connection',
      description: 'Manage multi-protocol remote connections (SSH, RDP, WinRM, etc.)',
      category: 'infrastructure',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['connect', 'test', 'list', 'configure', 'disconnect'],
            description: 'Remote connection operation'
          },
          protocol: {
            type: 'string',
            enum: ['ssh', 'rdp', 'winrm', 'vnc', 'auto'],
            description: 'Connection protocol to use',
            default: 'auto'
          },
          target: {
            type: 'string',
            description: 'Target host or connection name'
          },
          credentials: {
            type: 'string',
            description: 'Credential set name to use'
          },
          port: {
            type: 'integer',
            description: 'Custom port number'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_opentofu_provider', {
      name: 'aither_opentofu_provider',
      description: 'Manage OpenTofu providers and infrastructure state',
      category: 'infrastructure',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['install', 'upgrade', 'list', 'configure', 'validate'],
            description: 'Provider management operation'
          },
          providers: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific providers to manage'
          },
          version: {
            type: 'string',
            description: 'Provider version constraint'
          }
        },
        required: ['operation']
      }
    });

    // ===== OPERATIONS & MAINTENANCE TOOLS =====

    this.tools.set('aither_backup_management', {
      name: 'aither_backup_management',
      description: 'Comprehensive backup management, cleanup operations, and file consolidation',
      category: 'operations',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['consolidate', 'cleanup', 'backup', 'restore', 'status', 'statistics'],
            description: 'Backup operation to perform'
          },
          sourcePath: {
            type: 'string',
            description: 'Source path for backup operations'
          },
          backupPath: {
            type: 'string',
            description: 'Destination path for backups'
          },
          retentionDays: {
            type: 'integer',
            description: 'Number of days to retain backups',
            default: 30
          },
          force: {
            type: 'boolean',
            description: 'Force operation without confirmation',
            default: false
          },
          mode: {
            type: 'string',
            enum: ['Quick', 'Standard', 'Emergency'],
            description: 'Backup operation mode',
            default: 'Standard'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_maintenance_operations', {
      name: 'aither_maintenance_operations',
      description: 'Execute unified maintenance operations across all modules',
      category: 'operations',
      inputSchema: {
        type: 'object',
        properties: {
          mode: {
            type: 'string',
            enum: ['Quick', 'Standard', 'Full', 'Emergency'],
            description: 'Maintenance operation mode',
            default: 'Standard'
          },
          modules: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific modules to maintain (empty = all modules)'
          },
          autoFix: {
            type: 'boolean',
            description: 'Automatically fix detected issues',
            default: false
          },
          dryRun: {
            type: 'boolean',
            description: 'Preview maintenance actions without executing',
            default: false
          }
        }
      }
    });

    this.tools.set('aither_logging_system', {
      name: 'aither_logging_system',
      description: 'Manage centralized logging system with multiple levels and outputs',
      category: 'operations',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['configure', 'view', 'clear', 'export', 'analyze', 'tail'],
            description: 'Logging system operation'
          },
          logLevel: {
            type: 'string',
            enum: ['DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS'],
            description: 'Log level filter'
          },
          logPath: {
            type: 'string',
            description: 'Path to log files'
          },
          lines: {
            type: 'integer',
            description: 'Number of log lines to display',
            default: 100
          },
          follow: {
            type: 'boolean',
            description: 'Follow log file changes (tail -f behavior)',
            default: false
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_parallel_execution', {
      name: 'aither_parallel_execution',
      description: 'Execute tasks in parallel using PowerShell runspaces for improved performance',
      category: 'operations',
      inputSchema: {
        type: 'object',
        properties: {
          tasks: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                script: { type: 'string' },
                arguments: { type: 'object' }
              }
            },
            description: 'Tasks to execute in parallel'
          },
          maxParallelJobs: {
            type: 'integer',
            description: 'Maximum number of parallel jobs',
            default: 4
          },
          timeout: {
            type: 'integer',
            description: 'Timeout in seconds for each task',
            default: 300
          },
          aggregateResults: {
            type: 'boolean',
            description: 'Aggregate results from all tasks',
            default: true
          }
        },
        required: ['tasks']
      }
    });

    this.tools.set('aither_unified_maintenance', {
      name: 'aither_unified_maintenance',
      description: 'Unified entry point for all maintenance operations across the entire system',
      category: 'operations',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['health-check', 'cleanup', 'optimize', 'repair', 'update', 'full'],
            description: 'Type of maintenance operation'
          },
          scope: {
            type: 'string',
            enum: ['system', 'modules', 'infrastructure', 'logs', 'backups', 'all'],
            description: 'Scope of maintenance operation',
            default: 'all'
          },
          schedule: {
            type: 'boolean',
            description: 'Schedule for regular execution',
            default: false
          }
        },
        required: ['operation']
      }
    });

    // ===== SECURITY & CREDENTIAL TOOLS =====

    this.tools.set('aither_credential_management', {
      name: 'aither_credential_management',
      description: 'Enterprise-grade credential management and secure storage',
      category: 'security',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['store', 'retrieve', 'update', 'delete', 'list', 'rotate'],
            description: 'Credential management operation'
          },
          credentialName: {
            type: 'string',
            description: 'Name of the credential to manage'
          },
          credentialType: {
            type: 'string',
            enum: ['password', 'apikey', 'certificate', 'ssh-key', 'token'],
            description: 'Type of credential'
          },
          scope: {
            type: 'string',
            enum: ['user', 'machine', 'global'],
            description: 'Scope of credential storage',
            default: 'user'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_secure_storage', {
      name: 'aither_secure_storage',
      description: 'Secure storage operations with encryption and access control',
      category: 'security',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['encrypt', 'decrypt', 'store', 'retrieve', 'configure'],
            description: 'Secure storage operation'
          },
          dataPath: {
            type: 'string',
            description: 'Path to data for encryption/decryption'
          },
          keyName: {
            type: 'string',
            description: 'Encryption key name'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_encryption_tools', {
      name: 'aither_encryption_tools',
      description: 'Encryption and decryption tools for secure data handling',
      category: 'security',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['encrypt-file', 'decrypt-file', 'generate-key', 'sign', 'verify'],
            description: 'Encryption operation'
          },
          algorithm: {
            type: 'string',
            enum: ['AES-256', 'RSA-2048', 'RSA-4096'],
            description: 'Encryption algorithm',
            default: 'AES-256'
          },
          inputPath: {
            type: 'string',
            description: 'Input file path'
          },
          outputPath: {
            type: 'string',
            description: 'Output file path'
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_audit_logging', {
      name: 'aither_audit_logging',
      description: 'Security audit logging and compliance reporting',
      category: 'security',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['enable', 'disable', 'report', 'export', 'analyze'],
            description: 'Audit logging operation'
          },
          timeRange: {
            type: 'string',
            description: 'Time range for audit reports (e.g., "7d", "30d", "1y")'
          },
          eventTypes: {
            type: 'array',
            items: { type: 'string' },
            description: 'Types of events to audit'
          }
        },
        required: ['operation']
      }
    });

    // ===== ISO MANAGEMENT TOOLS =====

    this.tools.set('aither_iso_download', {
      name: 'aither_iso_download',
      description: 'Download and manage ISO files with verification and organization',
      category: 'iso',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['download', 'verify', 'list', 'organize', 'cleanup'],
            description: 'ISO download operation'
          },
          isoType: {
            type: 'string',
            enum: ['windows-11', 'windows-10', 'windows-server', 'ubuntu', 'centos', 'custom'],
            description: 'Type of ISO to download'
          },
          version: {
            type: 'string',
            description: 'Specific version to download'
          },
          downloadPath: {
            type: 'string',
            description: 'Path to download ISO files'
          },
          verify: {
            type: 'boolean',
            description: 'Verify ISO integrity after download',
            default: true
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_iso_customization', {
      name: 'aither_iso_customization',
      description: 'Customize ISO files with autounattend.xml generation and package injection',
      category: 'iso',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['customize', 'inject', 'autounattend', 'extract', 'rebuild'],
            description: 'ISO customization operation'
          },
          sourceISO: {
            type: 'string',
            description: 'Path to source ISO file'
          },
          outputISO: {
            type: 'string',
            description: 'Path for customized ISO output'
          },
          configTemplate: {
            type: 'string',
            description: 'Customization configuration template'
          },
          packages: {
            type: 'array',
            items: { type: 'string' },
            description: 'Packages to inject into ISO'
          },
          unattendConfig: {
            type: 'object',
            description: 'Autounattend.xml configuration parameters'
          }
        },
        required: ['operation', 'sourceISO']
      }
    });

    this.tools.set('aither_iso_validation', {
      name: 'aither_iso_validation',
      description: 'Validate ISO file integrity, structure, and customizations',
      category: 'iso',
      inputSchema: {
        type: 'object',
        properties: {
          isoPath: {
            type: 'string',
            description: 'Path to ISO file for validation'
          },
          validationType: {
            type: 'string',
            enum: ['integrity', 'structure', 'boot', 'content', 'all'],
            description: 'Type of validation to perform',
            default: 'all'
          },
          reportPath: {
            type: 'string',
            description: 'Path to save validation report'
          }
        },
        required: ['isoPath']
      }
    });

    this.tools.set('aither_autounattend_generation', {
      name: 'aither_autounattend_generation',
      description: 'Generate autounattend.xml files for automated Windows installation',
      category: 'iso',
      inputSchema: {
        type: 'object',
        properties: {
          template: {
            type: 'string',
            enum: ['windows-11', 'windows-10', 'server-2022', 'server-2019', 'custom'],
            description: 'Autounattend template to use'
          },
          configuration: {
            type: 'object',
            properties: {
              productKey: { type: 'string' },
              computerName: { type: 'string' },
              adminPassword: { type: 'string' },
              timezone: { type: 'string' },
              language: { type: 'string' },
              packages: { type: 'array', items: { type: 'string' } }
            },
            description: 'Installation configuration parameters'
          },
          outputPath: {
            type: 'string',
            description: 'Path to save autounattend.xml file'
          }
        },
        required: ['template']
      }
    });

    // ===== ADVANCED AUTOMATION TOOLS =====

    this.tools.set('aither_cross_platform_executor', {
      name: 'aither_cross_platform_executor',
      description: 'Execute commands and scripts across different platforms (Windows, Linux, macOS)',
      category: 'advanced',
      inputSchema: {
        type: 'object',
        properties: {
          script: {
            type: 'string',
            description: 'Script or command to execute'
          },
          platform: {
            type: 'string',
            enum: ['auto', 'windows', 'linux', 'macos'],
            description: 'Target platform for execution',
            default: 'auto'
          },
          interpreter: {
            type: 'string',
            enum: ['powershell', 'bash', 'cmd', 'python', 'auto'],
            description: 'Script interpreter to use',
            default: 'auto'
          },
          workingDirectory: {
            type: 'string',
            description: 'Working directory for script execution'
          },
          environmentVariables: {
            type: 'object',
            description: 'Environment variables to set'
          }
        },
        required: ['script']
      }
    });

    this.tools.set('aither_performance_monitoring', {
      name: 'aither_performance_monitoring',
      description: 'Monitor system and application performance with detailed metrics',
      category: 'advanced',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['start', 'stop', 'report', 'analyze', 'benchmark'],
            description: 'Performance monitoring operation'
          },
          metrics: {
            type: 'array',
            items: {
              type: 'string',
              enum: ['cpu', 'memory', 'disk', 'network', 'powershell', 'modules']
            },
            description: 'Specific metrics to monitor',
            default: ['cpu', 'memory', 'powershell']
          },
          duration: {
            type: 'integer',
            description: 'Monitoring duration in seconds',
            default: 60
          },
          interval: {
            type: 'integer',
            description: 'Sampling interval in seconds',
            default: 5
          }
        },
        required: ['operation']
      }
    });

    this.tools.set('aither_health_diagnostics', {
      name: 'aither_health_diagnostics',
      description: 'Comprehensive system health diagnostics and issue detection',
      category: 'advanced',
      inputSchema: {
        type: 'object',
        properties: {
          scope: {
            type: 'string',
            enum: ['system', 'modules', 'infrastructure', 'network', 'storage', 'all'],
            description: 'Scope of health check',
            default: 'all'
          },
          detailed: {
            type: 'boolean',
            description: 'Include detailed diagnostic information',
            default: false
          },
          autoRepair: {
            type: 'boolean',
            description: 'Automatically repair detected issues',
            default: false
          },
          reportPath: {
            type: 'string',
            description: 'Path to save diagnostic report'
          }
        }
      }
    });

    this.tools.set('aither_workflow_orchestration', {
      name: 'aither_workflow_orchestration',
      description: 'Orchestrate complex multi-step workflows across modules and systems',
      category: 'advanced',
      inputSchema: {
        type: 'object',
        properties: {
          workflowType: {
            type: 'string',
            enum: ['ISOWorkflow', 'DevelopmentWorkflow', 'LabDeployment', 'MaintenanceOperations', 'SecurityAudit', 'custom'],
            description: 'Type of workflow to orchestrate'
          },
          steps: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                tool: { type: 'string' },
                arguments: { type: 'object' },
                dependsOn: { type: 'array', items: { type: 'string' } }
              }
            },
            description: 'Custom workflow steps'
          },
          parameters: {
            type: 'object',
            description: 'Workflow-specific parameters'
          },
          dryRun: {
            type: 'boolean',
            description: 'Preview workflow without execution',
            default: false
          }
        },
        required: ['workflowType']
      }
    });

    this.tools.set('aither_ai_integration', {
      name: 'aither_ai_integration',
      description: 'AI-powered automation assistance and intelligent decision making',
      category: 'advanced',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['analyze', 'recommend', 'optimize', 'predict', 'assist'],
            description: 'AI operation to perform'
          },
          context: {
            type: 'string',
            description: 'Context for AI analysis (system state, logs, metrics, etc.)'
          },
          objective: {
            type: 'string',
            description: 'Objective or goal for AI assistance'
          },
          data: {
            type: 'object',
            description: 'Data for AI analysis'
          }
        },
        required: ['operation', 'objective']
      }
    });

    // ===== QUICK ACTION TOOLS =====

    this.tools.set('aither_quick_patch', {
      name: 'aither_quick_patch',
      description: 'Create quick patches for common issues with minimal configuration',
      category: 'quick',
      inputSchema: {
        type: 'object',
        properties: {
          issueType: {
            type: 'string',
            enum: ['module-import', 'path-fix', 'config-update', 'dependency-fix', 'custom'],
            description: 'Type of issue to patch'
          },
          description: {
            type: 'string',
            description: 'Brief description of the fix'
          },
          targetModule: {
            type: 'string',
            description: 'Module to apply the patch to'
          },
          createPR: {
            type: 'boolean',
            description: 'Create PR for the patch',
            default: true
          }
        },
        required: ['issueType', 'description']
      }
    });

    this.tools.set('aither_emergency_rollback', {
      name: 'aither_emergency_rollback',
      description: 'Emergency rollback operations for critical system recovery',
      category: 'quick',
      inputSchema: {
        type: 'object',
        properties: {
          rollbackType: {
            type: 'string',
            enum: ['LastCommit', 'SpecificCommit', 'LastWorkingState', 'ModuleReset'],
            description: 'Type of rollback to perform'
          },
          targetCommit: {
            type: 'string',
            description: 'Specific commit hash for rollback (if applicable)'
          },
          createBackup: {
            type: 'boolean',
            description: 'Create backup before rollback',
            default: true
          },
          force: {
            type: 'boolean',
            description: 'Force rollback without confirmation',
            default: false
          }
        },
        required: ['rollbackType']
      }
    });

    this.tools.set('aither_instant_backup', {
      name: 'aither_instant_backup',
      description: 'Instant backup of critical system components',
      category: 'quick',
      inputSchema: {
        type: 'object',
        properties: {
          scope: {
            type: 'string',
            enum: ['modules', 'configs', 'scripts', 'logs', 'all'],
            description: 'Scope of instant backup',
            default: 'all'
          },
          compress: {
            type: 'boolean',
            description: 'Compress backup archive',
            default: true
          },
          timestamp: {
            type: 'boolean',
            description: 'Include timestamp in backup name',
            default: true
          }
        }
      }
    });

    this.tools.set('aither_fast_validation', {
      name: 'aither_fast_validation',
      description: 'Fast validation of system state and critical components',
      category: 'quick',
      inputSchema: {
        type: 'object',
        properties: {
          validationType: {
            type: 'string',
            enum: ['modules', 'paths', 'dependencies', 'configs', 'all'],
            description: 'Type of validation to perform',
            default: 'all'
          },
          fixIssues: {
            type: 'boolean',
            description: 'Automatically fix detected issues',
            default: false
          }
        }
      }
    });

    this.tools.set('aither_system_status', {
      name: 'aither_system_status',
      description: 'Quick system status overview with key metrics and health indicators',
      category: 'quick',
      inputSchema: {
        type: 'object',
        properties: {
          format: {
            type: 'string',
            enum: ['summary', 'detailed', 'json', 'dashboard'],
            description: 'Output format for status report',
            default: 'summary'
          },
          includeMetrics: {
            type: 'boolean',
            description: 'Include performance metrics',
            default: true
          },
          refreshCache: {
            type: 'boolean',
            description: 'Refresh cached status information',
            default: false
          }
        }
      }
    });
  }

  getAllTools() {
    return Array.from(this.tools.values());
  }

  getTool(name) {
    return this.tools.get(name);
  }

  getToolsByCategory(category) {
    return Array.from(this.tools.values()).filter(tool => tool.category === category);
  }

  getCategories() {
    return Array.from(this.categories.values());
  }

  getToolsetDefinition() {
    const toolsets = {};

    for (const [categoryName, category] of this.categories) {
      toolsets[`aither-${categoryName}`] = {
        tools: category.tools,
        description: category.description,
        icon: category.icon
      };
    }

    // Add complete toolset
    toolsets['aither-complete'] = {
      tools: Array.from(this.tools.keys()),
      description: 'Complete AitherZero infrastructure automation framework',
      icon: 'briefcase'
    };

    return toolsets;
  }
}
