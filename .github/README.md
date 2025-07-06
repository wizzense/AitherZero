# AitherZero GitHub Automation & Workflows

This directory contains all GitHub-related automation, workflows, and contributor resources for the AitherZero project.

## 📁 Directory Structure

```
.github/
├── README.md                          # This file - GitHub automation overview
├── workflows/                         # GitHub Actions workflows
│   ├── ci.yml                        # Continuous Integration
│   └── release.yml                   # Release automation
├── ISSUE_TEMPLATE/                   # Issue templates for bug reports and features
├── instructions/                     # Contributor and automation instructions
├── copilot/                         # GitHub Copilot configurations
├── prompts/                         # AI prompt templates
├── pull_request_template.md         # PR template
└── copilot-instructions.md          # Copilot integration guidelines
```

## 🚀 GitHub Actions Workflows

AitherZero uses a **simplified 2-workflow system** for maximum efficiency:

### 1. CI Workflow (`ci.yml`)
- **Triggers**: Push to main/develop, all PRs
- **Purpose**: Automated testing and validation  
- **Platforms**: Windows, Linux, macOS
- **Runtime**: ~2 minutes
- **Actions**:
  - PowerShell 7.0+ compatibility testing
  - Module import validation
  - Core functionality tests via `./tests/Run-Tests.ps1`
  - Cross-platform compatibility checks

### 2. Release Workflow (`release.yml`) 
- **Triggers**: Manual dispatch only (workflow_dispatch)
- **Purpose**: Version management and package creation
- **Runtime**: ~5 minutes
- **Actions**:
  - Automatic version bumping
  - Git tag creation
  - Multi-platform package building:
    - `AitherZero-vX.X.X-windows.zip`
    - `AitherZero-vX.X.X-linux.tar.gz` 
    - `AitherZero-vX.X.X-macos.tar.gz`
  - GitHub Release creation with artifacts
  - Release notes generation

## 🛠️ Using GitHub Workflows

### Creating a Release

**Method 1: GitHub UI (Recommended)**
1. Go to **Actions** → **Release** → **Run workflow**
2. Enter version number (e.g., `1.2.3`) and description
3. Click **Run workflow**
4. Workflow automatically creates PR → merge → tag → release

**Method 2: Local Script**
```powershell
# From repository root
./release.ps1                                    # Patch release
./release.ps1 -Type minor -Description "New features"   # Minor release  
./release.ps1 -Type major -Description "Breaking changes" # Major release
```

### Monitoring CI Status

```bash
# Using GitHub CLI
gh run list --workflow=CI
gh run watch                     # Watch current runs
gh run view <run-id>            # View specific run details

# Check PR status
gh pr status
gh pr checks <pr-number>        # Check PR workflow status
```

## 📝 Issue Templates

Located in `ISSUE_TEMPLATE/`, these templates help standardize bug reports and feature requests:

- **Bug Report**: Structured template for reporting issues
- **Feature Request**: Template for proposing new features  
- **Performance Issue**: Specialized template for performance-related reports
- **Documentation**: Template for documentation improvements

## 🤖 AI Integration (Copilot)

### Copilot Configuration

The `.github/copilot/` directory contains:
- **Project context**: AitherZero-specific instructions for GitHub Copilot
- **Coding standards**: PowerShell best practices and conventions
- **Architecture patterns**: Module structure and integration patterns

### Copilot Instructions

Key guidelines for AI assistance:
- **PowerShell 7.0+** targeting with cross-platform compatibility
- **Module-based architecture** with clear separation of concerns
- **PatchManager v3.0** workflow patterns for Git operations
- **Configuration Carousel** patterns for environment management
- **Enterprise security** considerations

## 🔧 Pull Request Workflow

### PR Template

The `pull_request_template.md` provides a structured format for PRs:
- **Summary**: Clear description of changes
- **Type of Change**: Bug fix, feature, refactoring, etc.
- **Testing**: Verification steps and test results
- **Breaking Changes**: Impact assessment
- **Checklist**: Code quality and documentation requirements

### PR Requirements

1. **Tests Pass**: All CI workflows must pass
2. **Code Review**: At least one approving review required
3. **Documentation**: README and module docs updated as needed
4. **Conventional Commits**: Use semantic commit messages
5. **No Conflicts**: PR must be up-to-date with target branch

### Automated Checks

PRs automatically trigger:
- **Multi-platform testing** (Windows/Linux/macOS)
- **PowerShell compatibility** validation
- **Module import** verification  
- **Code quality** assessment
- **Security scanning** (if configured)

## 📊 Workflow Status Badges

Add these badges to your README for workflow status visibility:

```markdown
[![CI](https://github.com/wizzense/AitherZero/actions/workflows/ci.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions/workflows/ci.yml)
[![Release](https://github.com/wizzense/AitherZero/actions/workflows/release.yml/badge.svg)](https://github.com/wizzense/AitherZero/actions/workflows/release.yml)
```

## 🔐 Security & Permissions

### Repository Secrets

Required secrets for workflows:
- `GITHUB_TOKEN`: Automatically provided by GitHub
- `RELEASE_TOKEN`: For release creation (if using custom token)

### Branch Protection

Recommended branch protection rules:
- **Require PR reviews**: At least 1 approving review
- **Require status checks**: CI workflow must pass
- **Require up-to-date branches**: PRs must be current
- **Restrict push access**: Only maintainers can push directly

## 🐛 Troubleshooting Workflows

### Common Issues

**CI Workflow Fails**
```bash
# Check PowerShell version compatibility
pwsh -NoProfile -Command '$PSVersionTable'

# Verify module imports locally
pwsh -NoProfile -File './tests/Run-Tests.ps1'

# Check for syntax errors
pwsh -NoProfile -Command 'Get-ChildItem -Recurse -Filter "*.ps1" | ForEach-Object { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$null) }'
```

**Release Workflow Issues**
```bash
# Check version format
git tag --list | sort -V | tail -5    # View recent tags

# Verify build artifacts locally
./build/Build-Package.ps1 -Platform all

# Test release script locally
./release.ps1 -DryRun -Type patch
```

### Workflow Debugging

Enable workflow debugging:
1. Set repository secret `ACTIONS_STEP_DEBUG` to `true`
2. Set repository secret `ACTIONS_RUNNER_DEBUG` to `true`
3. Re-run failed workflow for detailed logs

## 📚 Additional Resources

### Documentation
- **[Contributing Guide](../CONTRIBUTING.md)**: Complete contributor setup
- **[CLAUDE.md](../CLAUDE.md)**: AI assistant development guidance
- **[Testing Guide](../tests/README.md)**: Test execution and validation

### Workflow Examples
- **[GitHub Actions Documentation](https://docs.github.com/en/actions)**
- **[PowerShell in GitHub Actions](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-powershell)**

### Project-Specific
- **[PatchManager v3.0](../aither-core/modules/PatchManager/README.md)**: Git workflow automation
- **[Configuration Carousel](../configs/carousel/CONFIGURATION-CAROUSEL-GUIDE.md)**: Configuration management
- **[Release Process](../release.ps1)**: Local release automation

## 🤝 Contributing to Workflows

### Modifying Workflows

1. **Test Locally**: Use `act` or similar tools for local testing
2. **Small Changes**: Test in feature branch first
3. **Documentation**: Update this README for significant changes
4. **Review Process**: All workflow changes require review

### Best Practices

- **Keep workflows simple**: 2 workflows are better than 10
- **Fast feedback**: CI should complete in <5 minutes
- **Clear naming**: Descriptive job and step names
- **Error handling**: Fail fast with clear error messages
- **Security first**: Minimal permissions, secure secret handling

---

**The AitherZero GitHub automation system is designed for simplicity, reliability, and fast feedback. When in doubt, refer to the [CLAUDE.md](../CLAUDE.md) for AI-assisted development guidance.**