# /aither

Main unified command for AitherZero orchestration - coordinate multiple modules for complete workflow automation.

## Usage
```
/aither [action] [options]
```

## Actions

### `setup` - Complete environment setup
Initialize and configure AitherZero components for development or production use with intelligent PowerShell version detection.

**Options:**
- `--dev-env` - Setup development environment only
- `--lab` - Setup lab environment components
- `--infra` - Setup infrastructure components
- `--all` - Complete setup (default)
- `--profile` - Installation profile: minimal, developer, full
- `--force-ps7` - Force PowerShell 7 installation if needed
- `--quickstart` - Enhanced interactive setup experience

**Examples:**
```bash
/aither setup --dev-env --profile developer
/aither setup --lab --infra --force-ps7
/aither setup --all --quickstart
```

### `workflow` - Multi-module workflow execution
Execute coordinated workflows across multiple AitherZero modules with enhanced conflict prevention.

**Options:**
- `--patch "description"` - Create patch workflow with PatchManager
- `--deploy "environment"` - Deploy to specific environment
- `--test "suite"` - Run test workflows
- `--create-pr` - Include PR creation in workflow
- `--validate` - Include validation steps
- `--force` - Force execution even with warnings
- `--sync` - Force Git synchronization before operations
- `--auto-fix-conflicts` - Automatically resolve Git conflicts

**Examples:**
```bash
/aither workflow --patch "Fix module loading issue" --create-pr --sync
/aither workflow --deploy staging --validate --auto-fix-conflicts
/aither workflow --test regression --create-pr
```

### `status` - Comprehensive system status
Show status across all AitherZero components and environments.

**Options:**
- `--all` - Show detailed status for all components (default)
- `--git` - Git repository status only
- `--infra` - Infrastructure status only
- `--lab` - Lab environment status only

**Examples:**
```bash
/aither status
/aither status --git
/aither status --infra --lab
```

### `deploy` - Full deployment workflow
Execute complete deployment workflow including infrastructure and applications.

**Options:**
- `--env "environment"` - Target environment (staging, production)
- `--validate` - Validate deployment before and after
- `--rollback-on-fail` - Automatic rollback on failure
- `--skip-infra` - Skip infrastructure deployment
- `--skip-apps` - Skip application deployment

**Examples:**
```bash
/aither deploy --env production --validate
/aither deploy --env staging --rollback-on-fail
/aither deploy --env dev --skip-infra
```

### `cleanup` - System maintenance and cleanup
Perform comprehensive system cleanup and maintenance tasks.

**Options:**
- `--git` - Git repository cleanup (branches, tags)
- `--lab` - Lab environment cleanup (expired resources)
- `--infra` - Infrastructure cleanup (unused resources)
- `--logs` - Log file cleanup
- `--all` - Complete cleanup (default)

**Examples:**
```bash
/aither cleanup --git --logs
/aither cleanup --lab --infra
/aither cleanup --all
```

### `help` - Show detailed help
Display comprehensive help information for all commands and options.

## Workflow Orchestration

### Development Workflow
```bash
# Setup development environment
/aither setup --dev-env

# Create feature with patch workflow
/aither workflow --patch "Add new feature" --create-pr

# Check overall status
/aither status --all
```

### Deployment Workflow
```bash
# Deploy to staging with validation
/aither deploy --env staging --validate

# Check deployment status
/aither status --infra

# Deploy to production
/aither deploy --env production --validate --rollback-on-fail
```

### Maintenance Workflow
```bash
# System status check
/aither status --all

# Perform maintenance cleanup
/aither cleanup --all

# Verify post-cleanup status
/aither status --all
```

## Integration with Individual Commands

The `/aither` command orchestrates and coordinates individual module commands:

- **PatchManager**: Git workflows, PR creation, rollbacks
- **LabRunner**: Lab environment management and testing
- **OpenTofuProvider**: Infrastructure deployment and scaling
- **DevEnvironment**: Development setup and configuration
- **BackupManager**: Data backup and consolidation
- **SecureCredentials**: Credential management
- **RemoteConnection**: Multi-protocol remote connections

## Advanced Features

### Multi-Environment Support
- **Development**: Local development environment setup
- **Staging**: Pre-production testing environment
- **Production**: Live production deployment
- **Lab**: Isolated testing and experimentation

### Intelligent Workflow Coordination
- **Dependency Resolution**: Automatic module dependency handling
- **Error Recovery**: Intelligent error handling and recovery
- **Progress Tracking**: Real-time workflow progress monitoring
- **Resource Optimization**: Efficient resource utilization

### Git Integration
- **Automated Branching**: Smart branch creation and management
- **PR Workflows**: Automated pull request creation and management
- **Cross-Fork Support**: Multi-repository workflow coordination
- **Rollback Capabilities**: Safe rollback and recovery options

### Monitoring and Observability
- **Real-time Status**: Live status monitoring across all components
- **Performance Metrics**: Resource usage and performance tracking
- **Alert Integration**: Automated alerting and notification
- **Audit Logging**: Complete audit trail of all operations

## Security and Compliance

### Access Control
- **Role-based Access**: Fine-grained permission management
- **Secure Credentials**: Integration with SecureCredentials module
- **Audit Trail**: Complete operation logging and tracking
- **Compliance Validation**: Automated compliance checking

### Data Protection
- **Secure Communication**: Encrypted communication channels
- **Data Sanitization**: Automatic sensitive data handling
- **Backup Integration**: Automated backup and recovery
- **Disaster Recovery**: Built-in disaster recovery capabilities

## Claude Code AI Integration

### Natural Language Workflows
- **Conversational Commands**: "Setup production environment with validation"
- **Intelligent Suggestions**: AI-powered workflow recommendations
- **Context Awareness**: Understanding of current system state
- **Error Explanation**: Human-readable error explanations

### Automation Capabilities
- **Smart Defaults**: Intelligent default parameter selection
- **Workflow Optimization**: AI-optimized execution paths
- **Predictive Actions**: Proactive issue prevention
- **Learning Integration**: Continuous improvement from usage patterns

The `/aither` command provides enterprise-grade orchestration with AI-powered automation, making complex multi-module workflows simple and reliable.