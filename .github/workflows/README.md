# AitherZero CI/CD Workflows

This directory contains the consolidated and optimized GitHub Actions workflows for AitherZero. The workflow structure has been refactored for better efficiency, maintainability, and resource usage.

## 🚀 Workflow Overview

### Core Workflows

| Workflow | Purpose | Triggers | Duration |
|----------|---------|----------|----------|
| `ci-pipeline.yml` | Main CI/CD pipeline with comprehensive testing | Push, PR, Manual | 15-25 min |
| `pr-validation.yml` | Fast PR validation and automated review | PR events, Comments | 3-5 min |
| `release-automation.yml` | Automated release creation and packaging | Tags, Manual | 10-15 min |

## 📋 Workflow Details

### CI Pipeline (`ci-pipeline.yml`)

**The main workhorse** - Handles all comprehensive testing and validation.

**Features:**
- ⚡ **Quick Validation**: Fast syntax and module loading tests (5 min)  
- 🧪 **Cross-Platform Testing**: Ubuntu, Windows, macOS support
- 🔍 **Code Quality**: PSScriptAnalyzer integration
- 📊 **Reporting**: Coverage reports and project dashboards
- 📦 **Packaging**: Automated build artifact creation
- 🚀 **Release**: Conditional release creation for main branch

**Job Flow:**
```
quick-validation → comprehensive-testing → build-package → create-release
                                      ↘  
                                        ci-summary
```

**Optimization Features:**
- Dependency caching for faster builds
- Intelligent path-based triggering  
- Job matrices for parallel execution
- Conditional job execution to save resources

### PR Validation (`pr-validation.yml`)

**Fast feedback loop** - Provides immediate validation for pull requests.

**Features:**
- 📊 **Change Analysis**: Categorizes modified files
- 🔍 **Quick Validation**: Syntax checking for PowerShell changes
- 💬 **Automated Comments**: Progress updates and recommendations
- 🤖 **Copilot Integration**: Responds to @copilot mentions
- 📋 **Checklist Generation**: Automated review checklists

**Smart Analysis:**
- Detects PowerShell, workflow, test, and config changes
- Provides contextual recommendations
- Links to comprehensive CI for full validation

### Release Automation (`release-automation.yml`)

**Production releases** - Handles version management and release packaging.

**Features:**
- 🔍 **Pre-Release Validation**: Comprehensive quality checks
- 📦 **Multi-Format Packaging**: ZIP and TAR.GZ archives
- 📝 **Release Notes**: Auto-generated with build information
- 🏷️ **Tag Management**: Version and latest tag updates
- 📊 **Release Dashboard**: Post-release summary and links

**Package Contents:**
- Complete PowerShell module
- All automation scripts (0000-9999)
- Cross-platform bootstrap scripts
- Documentation and examples
- Build metadata and version info

## 🔧 Configuration

### Environment Variables

All workflows use consistent environment variables:

```yaml
env:
  AITHERZERO_CI: true                    # Enable CI mode
  AITHERZERO_NONINTERACTIVE: true       # Disable interactive prompts
  AITHERZERO_CI_PROGRESS: true          # Enable progress reporting
```

### Timeouts and Limits

| Component | Timeout | Purpose |
|-----------|---------|---------|
| Quick Validation | 5 min | Fast feedback |
| Comprehensive Testing | 25 min | Full validation |
| Pre-Release Validation | 15 min | Release quality |
| Build Packaging | 10 min | Artifact creation |

### Caching Strategy

Workflows implement intelligent caching:

```yaml
# PowerShell modules cache
~/.local/share/powershell/Modules
key: ${{ runner.os }}-powershell-modules-${{ hashFiles('**/*.psd1') }}

# Dependencies cache  
~/.cache/
key: ${{ runner.os }}-deps-${{ github.run_id }}
```

## 🎯 Usage Examples

### Manual Triggers

#### Run Full CI Pipeline
```bash
# Via GitHub UI: Actions → CI Pipeline → Run workflow
# Choose scope: quick, full, integration
```

#### Create Release
```bash
# Via GitHub UI: Actions → Release Automation → Run workflow  
# Specify version: 1.2.3
# Choose pre-release: true/false
```

### Automatic Triggers

#### Push to Main
- Triggers full CI pipeline
- Creates release if successful (on main branch)
- Deploys reports to GitHub Pages

#### Pull Request
- Runs PR validation immediately
- Links to comprehensive CI pipeline  
- Provides automated feedback and recommendations

#### Tag Push  
- Triggers release automation
- Creates GitHub release with artifacts
- Updates documentation and tags

## 📊 Monitoring and Debugging

### Workflow Status

Check workflow status at:
- **CI Pipeline**: `https://github.com/wizzense/AitherZero/actions/workflows/ci-pipeline.yml`
- **PR Validation**: `https://github.com/wizzense/AitherZero/actions/workflows/pr-validation.yml`  
- **Release**: `https://github.com/wizzense/AitherZero/actions/workflows/release-automation.yml`

### Artifacts and Reports

Generated artifacts:
- **Test Results**: `test-results-{os}-{scope}`
- **Coverage Reports**: `comprehensive-reports`  
- **Release Packages**: `aitherzero-package`
- **Build Info**: `build-info.json`

### Debugging Common Issues

#### Syntax Validation Failures
```bash
# Local debugging
./az 0407                    # Run syntax validation
Get-ChildItem -Recurse -Include "*.ps1" | Test-PowerShellSyntax
```

#### Module Loading Issues  
```bash
# Local testing
Import-Module ./AitherZero.psd1 -Force -Verbose
```

#### Test Failures
```bash  
# Run tests locally
./az 0402                    # Unit tests
./az 0409                    # All tests
./az 0404                    # Code analysis
```

## 🔄 Migration from Legacy Workflows

### Removed Workflows

The following legacy workflows have been consolidated:

| Old Workflow | Replaced By | Reason |
|--------------|-------------|---------|
| `ci.yml` | `ci-pipeline.yml` | Feature consolidation |
| `comprehensive-ci.yml` | `ci-pipeline.yml` | Duplication removal |
| `pr-automation.yml` | `pr-validation.yml` | Simplified PR handling |
| `quick-validation.yml` | `ci-pipeline.yml` (quick job) | Integration |
| `release.yml` | `release-automation.yml` | Enhanced features |
| `manual-release.yml` | `release-automation.yml` | Consolidation |

### Migration Benefits

- ✅ **50% fewer workflow files** (6 → 3)
- ✅ **Faster execution** through caching and optimization
- ✅ **Better resource usage** with intelligent job dependencies  
- ✅ **Consistent patterns** across all workflows
- ✅ **Enhanced features** like automated PR analysis
- ✅ **Improved maintainability** with cleaner structure

### Breaking Changes

⚠️ **None** - All existing functionality is preserved in the new workflows.

## 🛠️ Customization

### Adding New Jobs

To add a job to the CI pipeline:

1. Add the job definition to `ci-pipeline.yml`
2. Set appropriate dependencies with `needs:`
3. Use consistent naming and timeout patterns
4. Include artifact uploads for debugging

### Modifying Triggers

Common trigger modifications:

```yaml
# Add branch pattern
on:
  push:
    branches: [main, develop, 'feature/**', 'hotfix/**']

# Add path filtering  
on:
  push:
    paths:
      - '**.ps1'
      - '**.psm1'  
      - '**.psd1'
```

### Environment Customization

Workflows can be customized via environment variables in repository settings:

- `AITHERZERO_TEST_TIMEOUT`: Override test timeouts
- `AITHERZERO_ANALYSIS_TIMEOUT`: Override analysis timeouts  
- `AITHERZERO_SKIP_TESTS`: Skip specific test categories

---

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AitherZero Documentation](../README.md)
- [PowerShell CI/CD Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/ci-cd)

For questions or issues with the CI/CD workflows, please [create an issue](../../issues/new) with the `ci/cd` label.