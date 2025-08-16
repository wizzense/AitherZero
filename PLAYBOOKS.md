# AitherZero Playbook System

## How to Run Playbooks

### Using the Universal `az` Command:

#### Single Scripts:
```bash
az 0402              # Run unit tests
az 0404              # Run PSScriptAnalyzer
az 0407              # Validate syntax
az 0510              # Generate project report
```

#### Sequences:
```bash
az 0402,0404,0407    # Run test, lint, validate
az 0400-0409         # Run all testing scripts
az 0500-0599         # Run all reporting scripts
```

#### Playbooks:
```bash
az playbook test-quick        # Fast validation
az pb test-fix-workflow       # AI test fixing
az playbook build-release     # Build release
az pb audit-full              # Complete audit
```

### Direct PowerShell (if needed):
```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook <name> -NonInteractive
```

## Available Playbooks

### 🧪 Testing & Quality
- `test-quick` - Fast validation (syntax, linting) ~2 min
- `test-full` - Complete test suite with coverage ~10 min
- `test-fix-workflow` - AI-powered test fixing ~5 min per issue
- `test-ci` - CI/CD test pipeline ~5 min
- `test-integration` - Integration tests ~15 min
- `test-performance` - Performance testing ~10 min

### 🔨 Building & Deployment
- `build-dev` - Build for development
- `build-staging` - Build for staging with validation
- `build-release` - Production build with signing
- `deploy-dev` - Deploy to development
- `deploy-staging` - Deploy to staging with tests  
- `deploy-prod` - Production deployment (requires approval)
- `rollback` - Rollback last deployment

### 📊 Auditing & Compliance
- `audit-security` - Security vulnerability scan
- `audit-dependencies` - Dependency audit
- `audit-compliance` - Compliance check
- `audit-code-quality` - Code quality metrics
- `audit-full` - Complete audit suite

### 📈 Reporting & Analytics
- `report-test-coverage` - Test coverage report
- `report-tech-debt` - Technical debt analysis
- `report-performance` - Performance metrics
- `report-security` - Security posture report
- `report-dashboard` - Executive dashboard
- `report-weekly` - Weekly summary report

### 🚀 Release Management
- `release-prepare` - Prepare release (version bump, changelog)
- `release-validate` - Validate release readiness
- `release-create` - Create GitHub release
- `release-publish` - Publish to package registries
- `release-announce` - Send release announcements

### 🔄 Development Workflows
- `feature-start` - Start new feature branch
- `feature-complete` - Complete feature with PR
- `hotfix-start` - Start hotfix branch
- `hotfix-deploy` - Fast-track hotfix deployment
- `code-review` - AI code review
- `refactor` - Automated refactoring

### 🤖 AI-Powered Workflows
- `ai-fix-tests` - Fix all failing tests
- `ai-optimize` - Performance optimization
- `ai-security-fix` - Fix security issues
- `ai-docs-generate` - Generate documentation
- `ai-review` - Comprehensive AI review

### 🔧 Maintenance
- `cleanup` - Clean temporary files and caches
- `update-dependencies` - Update all dependencies
- `backup` - Backup configuration and data
- `restore` - Restore from backup
- `health-check` - System health check

## Creating Custom Playbooks

Place new playbooks in `/orchestration/playbooks-psd1/` with structure:

```powershell
@{
    Name = 'my-playbook'
    Description = 'What this playbook does'
    Version = '1.0.0'
    
    Stages = @(
        @{
            Name = 'Stage1'
            Description = 'First stage'
            Sequence = @('0400', '0402')  # Script numbers to run
            ContinueOnError = $false
        }
    )
    
    Variables = @{
        DefaultVar = 'value'
    }
}
```

## Playbook Execution Flow

1. **Load** - Playbook configuration loaded
2. **Validate** - Check prerequisites and permissions
3. **Execute** - Run stages sequentially or in parallel
4. **Report** - Generate execution report
5. **Cleanup** - Clean temporary resources

## Integration with Claude

Claude can run any playbook directly:
```
Run the test-quick playbook
Deploy to staging
Generate security report
Fix all failing tests
```

The orchestration system handles:
- Error recovery
- Logging and auditing
- Progress tracking
- Notifications
- Approval workflows (for production)

## Best Practices

1. Use `test-quick` before commits
2. Run `test-full` before merges
3. Use `audit-security` weekly
4. Generate reports for stakeholders
5. Use AI workflows for repetitive tasks
6. Always use `-WhatIf` for production changes first