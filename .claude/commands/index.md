# Claude Commands Index for AitherZero

This directory contains Claude command definitions for streamlining AitherZero operations. Each command provides a natural language interface to complex PowerShell automation workflows.

## 📚 Available Commands

### Core Orchestration
- **[/aither](aither.md)** - Main unified command for multi-module orchestration
  - Setup environments, execute workflows, monitor status, deploy infrastructure

### Development & Operations
- **[/patchmanager](patchmanager.md)** - Git workflow automation and PR management
  - Create patches, manage PRs, handle releases, fix divergence
  
- **[/test](test.md)** ⭐ NEW - Unified testing interface
  - Run test suites, generate coverage, validate changes, benchmark performance

### Infrastructure & Configuration
- **[/infra](infra.md)** - Infrastructure deployment with OpenTofu/Terraform
  - Deploy, scale, rollback, validate infrastructure
  
- **[/config](config.md)** ⭐ NEW - Configuration management
  - Switch environments, edit settings, backup/restore configs
  
- **[/lab](lab.md)** - Lab environment management
  - Create, manage, and tear down lab environments

### Security & Compliance
- **[/security](security.md)** ⭐ NEW - Security automation
  - Run scans, manage credentials, handle certificates, ensure compliance
  
- **[/backup](backup.md)** ⭐ NEW - Backup and restore operations
  - Create backups, schedule automation, verify integrity, manage retention

### Monitoring & Service Management
- **[/monitor](monitor.md)** - System monitoring and observability
  - Track performance, set alerts, view dashboards
  
- **[/service](service.md)** - Service lifecycle management
  - Start, stop, restart services, manage dependencies
  
- **[/ops](ops.md)** - Operational automation
  - Maintenance tasks, health checks, log management

### Advanced Workflows
- **[/orchestrate](orchestrate.md)** ⭐ NEW - Advanced workflow orchestration
  - Execute playbooks, manage complex workflows, schedule automation

### Requirements Tracking
- **[/requirements-start](requirements-start.md)** - Start requirements session
- **[/requirements-current](requirements-current.md)** - View current requirement
- **[/requirements-status](requirements-status.md)** - Check requirements status
- **[/requirements-list](requirements-list.md)** - List all requirements
- **[/requirements-remind](requirements-remind.md)** - Get context reminder
- **[/requirements-end](requirements-end.md)** - End requirements session

## 🚀 Quick Start Examples

### Daily Development Workflow
```bash
# Start your day - check system status
/aither status --all

# Run quick tests before starting work
/test run --suite quick

# Create a feature with automatic PR
/patchmanager workflow --description "Add user authentication" --create-pr

# Run security scan
/security scan --type quick --fix

# Create backup before major changes
/backup create --name pre-feature --compress
```

### Deployment Workflow
```bash
# Validate infrastructure
/infra validate --config production --standards cis,nist

# Run deployment playbook
/orchestrate run --playbook deploy-web-app --environment production

# Monitor deployment
/monitor status --environment production --real-time

# Verify deployment
/test run --suite integration --environment production
```

### Maintenance Workflow
```bash
# Schedule maintenance window
/orchestrate schedule --playbook maintenance --cron "0 2 * * SUN"

# Backup before maintenance
/backup create --type full --encrypt

# Run security audit
/security audit --standard soc2 --evidence

# Clean up old backups
/backup cleanup --older-than 90 --keep-min 3
```

## 🎯 Command Aliases

For faster access, these aliases are available:

- `/pr` → `/patchmanager workflow --create-pr`
- `/deploy-prod` → `/infra deploy --env production --validate`
- `/quick-test` → `/test run --suite quick`
- `/full-test` → `/test run --suite all`
- `/backup-now` → `/backup create --type full --encrypt`
- `/security-check` → `/security scan --type quick --fix`

## 📖 Command Structure

All commands follow a consistent structure:
```
/command [action] [options]
```

- **command** - The main command (e.g., test, config, security)
- **action** - The specific operation (e.g., run, create, list)
- **options** - Additional parameters prefixed with `--`

## 🔧 Implementation Details

Each command is backed by a PowerShell script in `.claude/scripts/` that:
1. Parses command-line arguments
2. Imports required AitherZero modules
3. Executes the requested operation
4. Provides consistent logging and error handling

## 💡 Best Practices

1. **Use natural language** - Commands are designed to be intuitive
2. **Check status first** - Always verify system state before major operations
3. **Use dry-run mode** - Test complex operations with `--dry-run`
4. **Enable verbose output** - Add `--verbose` for detailed information
5. **Leverage aliases** - Use shortcuts for common operations

## 🆕 New Features in This Update

### Enhanced Testing (`/test`)
- Quick 30-second test runs by default
- Coverage reporting with thresholds
- Integration with CI/CD pipeline
- Smart test selection based on changes

### Configuration Management (`/config`)
- Switch between environments instantly
- Backup configurations automatically
- Validate settings before applying
- Export/import for sharing

### Security Automation (`/security`)
- Automated vulnerability scanning
- Credential rotation management
- Compliance reporting (CIS, NIST, SOC2, PCI)
- Certificate lifecycle management

### Backup Operations (`/backup`)
- Incremental and differential backups
- Automated scheduling with retention
- Cross-platform storage support
- Disaster recovery procedures

### Workflow Orchestration (`/orchestrate`)
- Visual playbook creation
- Parallel execution support
- Conditional logic and loops
- State management and checkpoints

## 🔄 Integration with VS Code

These commands integrate with VS Code tasks. Access them via:
- `Ctrl+Shift+P` → `Tasks: Run Task`
- Look for tasks prefixed with "Claude:"

## 📝 Creating Custom Commands

To add a new Claude command:

1. Create command documentation: `.claude/commands/yourcommand.md`
2. Create implementation script: `.claude/scripts/yourcommand.ps1`
3. Add permissions to `.claude/settings.local.json`
4. Test the command thoroughly

## 🐛 Troubleshooting

If a command fails:
1. Check module dependencies are loaded
2. Verify permissions in `settings.local.json`
3. Run with `--verbose --debug` for detailed output
4. Check the logs in `$projectRoot/Logs/`

## 📚 Further Reading

- [CLAUDE.md](/workspaces/AitherZero/CLAUDE.md) - Main project documentation
- [PatchManager Documentation](../modules/PatchManager/README.md)
- [AitherZero Architecture](../../README.md)

The Claude command system makes complex PowerShell automation accessible through simple, intuitive commands.