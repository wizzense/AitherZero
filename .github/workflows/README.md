# AitherZero CI/CD Workflows

This directory contains the optimized GitHub Actions workflows for AitherZero. The workflow structure has been streamlined for efficiency, maintainability, and optimal resource usage.

## 🚀 Workflow Overview

### Core Workflows

| Workflow | Purpose | Triggers | Duration |
|----------|---------|----------|----------|
| `intelligent-ci-orchestrator.yml` | Main CI/CD with smart change detection | Push, PR, Manual | 10-20 min |
| `automated-copilot-agent.yml` | Automated issue creation and Copilot task assignment | CI completion, Schedule, Manual | 3-5 min |
| `ai-agent-coordinator.yml` | Coordinates AI agents for code review, testing, security | PR, Issues, Schedule, Manual | 5-15 min |
| `copilot-pr-automation.yml` | Automated PR creation for Copilot fixes | Manual | 5-10 min |
| `pr-validation.yml` | Fast PR validation and automated review | PR events | 3-5 min |
| `release-automation.yml` | Automated release creation and packaging | Tags, Manual | 10-15 min |

### Supporting Workflows

| Workflow | Purpose | Triggers |
|----------|---------|----------|
| `create-issues-now.yml` | Manual issue creation from analysis | Manual |
| `documentation-automation.yml` | Documentation generation and updates | Push, PR, Manual |
| `enhanced-cost-optimizer.yml` | CI cost analysis and optimization | Schedule, Manual |
| `intelligent-report-analyzer.yml` | Analysis reporting and metrics | Schedule, Manual |
| `qa-lifecycle-coordinator.yml` | QA workflow coordination | PR, Manual |
| `validate-manifests.yml` | PowerShell manifest validation | Push, PR, Manual |
| `jekyll-gh-pages.yml` | GitHub Pages deployment | Push, Manual |

## 📋 Primary Workflow Details

### Intelligent CI Orchestrator (`intelligent-ci-orchestrator.yml`)

**The main CI/CD pipeline** - Intelligently orchestrates all testing and validation.

**Features:**
- 🧠 **Smart Change Detection**: Only runs necessary validations based on changed files
- ⚡ **Quick Validation**: Fast syntax checks (< 2 min)
- 🔍 **Core Validation**: PSScriptAnalyzer and comprehensive analysis
- 🔒 **Security Validation**: Security-focused scanning for sensitive changes
- 🧪 **Comprehensive Testing**: Parallelized test matrix by priority and category
- 🌍 **Cross-Platform**: Ubuntu, Windows, macOS validation for main/develop branches
- 🤖 **AI Integration**: Automatically triggers AI Agent Coordinator on failures

**Optimization Features:**
- Intelligent path-based change detection
- Parallelized test execution (8 concurrent test categories)
- Priority-based test ordering (P1-P4)
- Conditional job execution based on changes
- Smart caching for dependencies

### Automated Copilot Agent (`automated-copilot-agent.yml`)

**Automated issue creation** - Analyzes code and creates actionable issues for Copilot.

**Features:**
- 📊 **Fast Analysis**: Ultra-fast PSScriptAnalyzer (3s vs 60s+)
- 🧪 **Test Analysis**: Optimized Pester test execution
- 🔒 **Security Scanning**: Pattern-based security issue detection
- 🎯 **Smart Issue Creation**: Creates targeted issues with fix instructions
- 🤖 **Copilot Assignment**: Auto-assigns issues to @copilot
- 🔄 **Iterative Resolution**: Tracks resolution progress

**Trigger Conditions:**
- When Intelligent CI Orchestrator completes (main/develop branches only)
- Manual dispatch for forced analysis
- Scheduled runs every 6 hours
- When issues are opened/labeled

### AI Agent Coordinator (`ai-agent-coordinator.yml`)

**Coordinates AI agent actions** - Runs real PowerShell analysis tools and creates quality issues.

**Features:**
- 🔍 **Code Review Agent**: PSScriptAnalyzer analysis (az 0404)
- 🧪 **Testing Agent**: Unit test execution (az 0402)
- 🔒 **Security Agent**: Syntax and security validation (az 0407)
- 📊 **Reporting**: Comprehensive project reports (az 0510)
- 💬 **PR Comments**: Automated feedback on pull requests
- 🐛 **Issue Creation**: Creates GitHub issues for detected problems

**Real Analysis:**
- Uses actual AitherZero automation scripts
- Provides actionable, real results
- Priority-based execution (critical, high, normal, low)
- Timeout management and resource optimization

### Copilot PR Automation (`copilot-pr-automation.yml`)

**Automated PR creation** - Creates PRs for Copilot-fixed issues (manual trigger only).

**Features:**
- 👀 **Issue Monitoring**: Scans for Copilot-assigned issues
- 🛠️ **Automated Fixes**: Applies PSScriptAnalyzer fixes, test updates, security improvements
- 🔄 **PR Creation**: Creates PRs with fix summary and validation steps
- 💬 **PR Comments**: Updates issues with PR links
- ✅ **Auto-merge**: Eligible PRs can be auto-merged after validation

**Fix Strategies:**
- PSScriptAnalyzer auto-fixes
- Test parameter conflict resolution
- Security suppression additions
- Code quality improvements

## 🔧 Configuration

### Environment Variables

All workflows use consistent environment variables:

```yaml
env:
  AITHERZERO_CI: true                    # Enable CI mode
  AITHERZERO_NONINTERACTIVE: true       # Disable interactive prompts
  AI_AGENT_MODE: true                    # Enable AI agent features
  CI_OPTIMIZATION_LEVEL: 'aggressive'    # Optimization level
```

### Workflow Optimization

**Change Detection:**
- Infrastructure changes → Full validation + security scan + full tests
- Security-sensitive files → Security scan + core validation
- PowerShell files → Security scan + basic validation
- Test changes → Core validation only
- Documentation → Skip CI (handled by docs workflow)

**Test Parallelization:**
Tests run in parallel by priority and category:
- **P1 (Priority 1)**: Core Domain Tests, Core Unit Tests
- **P2 (Priority 2)**: Infrastructure Tests, Testing Framework Tests
- **P3 (Priority 3)**: Development Tests, CI/CD Tests
- **P4 (Priority 4)**: Reporting Tests, Integration Tests

**Benefits:**
- ✅ Faster feedback (parallel execution)
- ✅ Priority-based failure detection
- ✅ Better resource utilization
- ✅ Easier debugging (isolated test categories)

### Timeouts and Limits

| Component | Timeout | Purpose |
|-----------|---------|---------|
| Quick Validation | 2 min | Fast feedback |
| Core Validation | 10 min | Comprehensive analysis |
| Security Validation | 10 min | Security scanning |
| Comprehensive Testing | 20 min per category | Parallelized test execution |
| Cross-Platform | 15 min | Platform compatibility |

## 🔄 Workflow Optimization Changes

### Removed Workflows

The following workflows have been removed to eliminate duplication and confusion:

| Removed Workflow | Reason | Replaced By |
|-----------------|--------|-------------|
| `ci-pipeline.yml` | DEPRECATED - marked for removal | `intelligent-ci-orchestrator.yml` |
| `ai-issue-creator.yml` | Duplicate issue creation | `automated-copilot-agent.yml` |
| `automated-issue-management.yml` | Legacy issue management | `automated-copilot-agent.yml` |
| `ci-cost-optimizer.yml` | Old version | `enhanced-cost-optimizer.yml` |
| `test-intelligent-ci.yml` | Test workflow in production | N/A (removed) |

### Benefits of Optimization

- ✅ **Eliminated 5 duplicate/obsolete workflows** (19 → 14 workflows)
- ✅ **Clearer workflow purposes and triggers**
- ✅ **Reduced schedule overhead** (fewer cron triggers)
- ✅ **Better Copilot integration** (automated issue creation and PR workflow)
- ✅ **Streamlined issue creation** (single source of truth)
- ✅ **Improved maintainability** (less confusion, better docs)

### Key Improvements

1. **Automated Issue Creation**: Now properly triggers from CI failures on main/develop
2. **Copilot PR Automation**: Simplified and focused on manual triggers
3. **AI Agent Coordination**: Enhanced with real analysis tools
4. **Smart CI Orchestration**: Intelligent change detection reduces unnecessary runs
5. **Schedule Optimization**: Reduced from hourly to 6-8 hour intervals

## 🎯 Usage Examples

### Manual Triggers

#### Run Full CI Pipeline
```bash
# Via GitHub UI: Actions → Intelligent CI Orchestrator → Run workflow
# Choose test scope: quick, standard, comprehensive
```

#### Force Issue Analysis
```bash
# Via GitHub UI: Actions → Automated Copilot Agent → Run workflow
# Check "Force new analysis and issue creation"
```

#### Create Copilot PR for Issue
```bash
# Via GitHub UI: Actions → Copilot PR Automation → Run workflow
# Optionally specify issue number
# Check "Force PR creation"
```

### Automatic Triggers

#### Push to Main/Develop
- Triggers Intelligent CI Orchestrator
- On failure, triggers Automated Copilot Agent
- Creates issues for detected problems

#### Pull Request
- Runs PR validation immediately
- Triggers AI Agent Coordinator for review
- Links to comprehensive CI pipeline

## 📊 Monitoring and Debugging

### Workflow Status

Check workflow status at:
- **CI Pipeline**: `https://github.com/wizzense/AitherZero/actions/workflows/intelligent-ci-orchestrator.yml`
- **Copilot Agent**: `https://github.com/wizzense/AitherZero/actions/workflows/automated-copilot-agent.yml`
- **AI Coordinator**: `https://github.com/wizzense/AitherZero/actions/workflows/ai-agent-coordinator.yml`

### Debugging Common Issues

#### Syntax Validation Failures
```bash
# Local debugging
./az.ps1 0407                    # Run syntax validation
```

#### Test Failures
```bash
# Run tests locally
./az.ps1 0402                    # Unit tests
./az.ps1 0404                    # Code analysis
```

#### Issue Creation Not Working
1. Check if CI is completing successfully (no issues created for passing builds)
2. Verify workflow permissions (needs write access to issues)
3. Check workflow run logs for error messages
4. Manually trigger with `workflow_dispatch`

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AitherZero Documentation](../../README.md)
- [PowerShell CI/CD Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/ci-cd)

For questions or issues with the CI/CD workflows, please [create an issue](../../issues/new) with the `ci/cd` label.
