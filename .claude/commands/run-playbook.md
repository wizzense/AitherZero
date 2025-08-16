# run-playbook

Execute AitherZero orchestration playbooks directly

## Usage
```
run-playbook <playbook-name> [options]
```

## Available Playbooks

### Testing & Validation
- `test-quick` - Fast syntax and linting validation
- `test-full` - Complete test suite with coverage
- `test-fix-workflow` - Automatically fix failing tests using AI
- `test-ci` - CI/CD test pipeline

### Development Workflows  
- `feature-branch` - Create and setup feature branch
- `commit-changes` - Stage and commit with validation
- `create-pr` - Create pull request with tests
- `code-review` - AI-powered code review

### AI Agent Workflows
- `ai-fix-tests` - Fix all failing tests autonomously
- `ai-review-code` - Comprehensive AI code review
- `ai-generate-docs` - Generate documentation
- `ai-optimize` - Performance optimization
- `ai-security-scan` - Security vulnerability scan

### Infrastructure
- `deploy-dev` - Deploy to development environment
- `deploy-staging` - Deploy to staging with tests
- `deploy-prod` - Production deployment pipeline

## Options
- `--non-interactive` - Run without prompts
- `--what-if` - Preview without executing
- `--verbose` - Detailed output
- `--parallel` - Run stages in parallel where possible

## Examples
```bash
# Fix failing tests
run-playbook test-fix-workflow --non-interactive

# Quick validation
run-playbook test-quick

# Full CI pipeline
run-playbook test-ci --verbose

# Create feature with tests
run-playbook feature-branch --name my-feature
```

## Integration
This command integrates with:
- AitherZero orchestration engine
- Claude Code AI agents
- GitHub Actions workflows
- PowerShell testing framework