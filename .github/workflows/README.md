# AitherZero CI/CD Workflows

This directory contains the essential GitHub Actions workflows for AitherZero. The workflows have been streamlined to provide real value without over-automation or noise.

## 🚀 Workflow Overview

### Quality & Validation

| Workflow | Purpose | Triggers | Duration |
|----------|---------|----------|----------|
| `quality-validation.yml` | Code quality checks (PSScriptAnalyzer, tests) | PR, Manual | 10-15 min |
| `pr-validation.yml` | PR validation and security checks | PR events | 3-5 min |
| `validate-manifests.yml` | PowerShell manifest validation | Push, PR, Manual | 2-3 min |
| `validate-config.yml` | Configuration file validation | Push, PR, Manual | 1-2 min |

### Issue Management

| Workflow | Purpose | Triggers | Duration |
|----------|---------|----------|----------|
| `auto-create-issues-from-failures.yml` | Creates issues from test failures | Quality Validation completion, Schedule, Manual | 3-5 min |

### Documentation & Publishing

| Workflow | Purpose | Triggers | Duration |
|----------|---------|----------|----------|
| `documentation-automation.yml` | Generate documentation from code | Push, PR, Manual | 5-10 min |
| `index-automation.yml` | Generate project indexes | Push, PR, Manual | 3-5 min |
| `jekyll-gh-pages.yml` | GitHub Pages deployment | Push, Manual | 3-5 min |
| `publish-test-reports.yml` | Publish test results to Pages | Manual, Workflow completion | 2-3 min |

### Deployment & Release

| Workflow | Purpose | Triggers | Duration |
|----------|---------|----------|----------|
| `deploy-pr-environment.yml` | Deploy PR preview environments | PR events, Manual | 5-10 min |
| `release-automation.yml` | Automated release creation and packaging | Tags, Manual | 10-15 min |
| `docker-publish.yml` | Build and publish Docker images to GHCR | Tags, Releases, Manual | 15-20 min |

## 📋 Workflow Details

### Quality Validation (`quality-validation.yml`)

**Purpose:** Runs PSScriptAnalyzer and comprehensive code quality checks on pull requests.

**Features:**
- 🔍 **PSScriptAnalyzer**: Full static analysis of PowerShell code
- 🧪 **Unit Tests**: Runs Pester tests for changed code
- 📊 **Reports**: Generates quality reports as artifacts
- 🐛 **Issue Creation**: Creates GitHub issues for quality failures (when configured)

**Triggers:**
- Pull requests with code changes
- Manual dispatch for full analysis

### PR Validation (`pr-validation.yml`)

**Purpose:** Fast validation for external/fork pull requests with security focus.

**Features:**
- 🔒 **Security**: Safe validation without code execution for fork PRs
- 📝 **Comments**: Automated PR feedback
- ✅ **Quick Checks**: Basic validation before deeper analysis

### Auto-Create Issues from Failures (`auto-create-issues-from-failures.yml`)

**Purpose:** Automatically creates GitHub issues for test failures and code quality problems.

**Features:**
- 📊 **Test Analysis**: Analyzes test results and creates targeted issues
- 🔍 **Quality Issues**: Creates issues for PSScriptAnalyzer findings
- 📅 **Daily Check**: Runs daily to catch missed failures
- 🎯 **Smart Deduplication**: Avoids creating duplicate issues

**Triggers:**
- When Quality Validation completes
- Daily schedule (7 AM UTC)
- Manual dispatch with dry-run option

### Documentation Automation (`documentation-automation.yml`)

**Purpose:** Automatically generates documentation from PowerShell code comments.

**Triggers:**
- Changes to PowerShell code
- Changes to documentation files
- Manual dispatch

### Release Automation (`release-automation.yml`)

**Purpose:** Automates the release process including versioning, packaging, and GitHub release creation.

**Triggers:**
- Version tags (v*)
- Manual dispatch

## 🔧 Configuration

### Environment Variables

Workflows use consistent environment variables:

```yaml
env:
  AITHERZERO_CI: true                    # Enable CI mode
  AITHERZERO_NONINTERACTIVE: true       # Disable interactive prompts
```

## 🧹 Recent Cleanup

The following over-engineered "AI coordination" workflows were removed as they provided no real value and generated noise:

**Removed workflows (11):**
- `ai-agent-coordinator.yml` - Wrapper around existing tools
- `automated-copilot-agent.yml` - Auto-assigned copilot to issues
- `intelligent-ci-orchestrator.yml` - Over-complex CI duplicating simpler workflows
- `qa-lifecycle-coordinator.yml` - Redundant validation layer
- `copilot-issue-commenter.yml` - Auto-commented on issues
- `copilot-pr-automation.yml` - Over-automated PR creation
- `intelligent-report-analyzer.yml` - Redundant analysis
- `auto-create-prs-for-issues.yml` - Over-automation
- `create-issues-now.yml` - Manual force issue creation
- `close-auto-issues.yml` - Cleaned up spam from above workflows
- `enhanced-cost-optimizer.yml` - Fake cost analysis with simulated data

**What was preserved:**
- `quality-validation.yml` - Real quality checks
- `auto-create-issues-from-failures.yml` - Legitimate issue tracking for real problems
- Other essential workflows for validation, documentation, and release management

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AitherZero Documentation](../../README.md)
- [PowerShell CI/CD Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/ci-cd-pipeline)

### Docker Image Publishing (`docker-publish.yml`)

**Purpose:** Build and publish multi-platform Docker images to GitHub Container Registry.

**Features:**
- 🐳 **Multi-Platform**: Builds for linux/amd64 and linux/arm64
- 📦 **GHCR Publishing**: Publishes to ghcr.io/wizzense/aitherzero
- 🏷️ **Smart Tagging**: Creates version, major.minor, major, latest, and SHA tags
- 🔒 **Security Scanning**: Trivy integration for vulnerability detection
- 🧪 **Automated Testing**: Smoke tests verify image functionality
- ⚡ **Build Caching**: GitHub Actions cache for faster builds

**Triggers:**
- Push of version tags (e.g., `v1.1.0`)
- GitHub Release published
- Manual workflow dispatch

**Image Tags Created:**
```
ghcr.io/wizzense/aitherzero:v1.1.0   # Specific version
ghcr.io/wizzense/aitherzero:1.1      # Major.minor
ghcr.io/wizzense/aitherzero:1        # Major version
ghcr.io/wizzense/aitherzero:latest   # Latest stable release
ghcr.io/wizzense/aitherzero:sha-abc  # Specific commit
```

**Usage:**
```bash
# Pull and run the latest image
docker pull ghcr.io/wizzense/aitherzero:latest
docker run -it --rm ghcr.io/wizzense/aitherzero:latest

# Pull specific version
docker pull ghcr.io/wizzense/aitherzero:v1.1.0
```

**Jobs:**
1. `build-and-push`: Builds multi-platform images and pushes to GHCR
2. `security-scan`: Scans images with Trivy and uploads results to GitHub Security

**Artifacts:**
- Docker images in GitHub Container Registry
- Security scan results (SARIF format) in GitHub Security tab

