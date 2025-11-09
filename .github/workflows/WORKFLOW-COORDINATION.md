# Workflow Coordination Guide

## Overview

AitherZero uses a sophisticated master orchestrator pattern to coordinate all CI/CD workflows. This ensures efficient, intelligent execution of build, test, and release processes based on the event context and changed files.

## Architecture

### Master Orchestrator

**File:** `.github/workflows/master-ci-cd.yml`

The master orchestrator is the central coordination point for all CI/CD processes. It:

1. **Analyzes Context**: Determines the event type (PR, push, release, manual)
2. **Detects Changes**: Identifies which files have changed
3. **Makes Decisions**: Decides which workflows need to run
4. **Delegates Work**: Calls appropriate workflows or runs standalone jobs
5. **Reports Results**: Provides comprehensive summary of what executed

### Workflow Types

#### 1. PR Workflow (pr-complete.yml)

**Trigger:** Pull request events (opened, synchronize, reopened)  
**Purpose:** Complete PR validation and build  
**Duration:** ~15-30 minutes

**Phases:**
- **Phase 1:** Quick Validation (syntax, config, manifests) - 2-3 min
- **Phase 2:** Comprehensive Testing (unit, domain, integration - matrix) - 10-15 min
- **Phase 3:** Build & Package (via playbook) - 5-10 min
- **Phase 3B:** Docker Container Build (multi-platform) - 10-15 min
- **Phase 4:** Quality Analysis (PSScriptAnalyzer, component quality) - 5-10 min
- **Phase 5:** Dashboard Generation (consolidate + deploy) - 3-5 min

**Outputs:**
- Test results (unit, domain, integration)
- Build packages (ZIP, TAR.GZ)
- Docker image tagged `pr-NUMBER`
- Quality analysis reports
- GitHub Pages dashboard

#### 2. Release Workflow (release-automation.yml)

**Trigger:** Git tags matching `v*` pattern  
**Purpose:** Full release with all artifacts  
**Duration:** ~30-45 minutes

**Jobs:**
- Pre-release validation (tests, quality checks)
- Create release package (ZIP, TAR.GZ)
- Build MCP server (Node.js package)
- Build Docker image (multi-platform, multiple tags)
- Publish to GitHub Packages
- Publish to GitHub Container Registry
- Generate release notes
- Update GitHub Release

**Outputs:**
- Release packages (AitherZero-vX.Y.Z.zip/tar.gz)
- MCP server package (@aitherzero/mcp-server)
- Docker images (ghcr.io/wizzense/aitherzero:vX.Y.Z, :latest, :stable)
- Comprehensive release notes

#### 3. Standalone Workflows

**Triggered by:** Push to main/dev (non-release)  
**Purpose:** Continuous validation  

**Jobs:**
- **Tests:** Comprehensive test suite
- **Build:** Package creation
- **Docker:** Container image build (if Dockerfile changed)
- **Docs:** Documentation generation (if docs changed)

## Coordination Logic

### Event Routing

```
Event Type → Orchestrator Decision → Action
├── Pull Request → pr-complete.yml (full PR workflow)
├── Release Tag (v*) → release-automation.yml (full release)
├── Push to main/dev → Standalone jobs (tests, build, Docker if changed)
└── workflow_dispatch → User-selected workflow
```

### File Change Detection

The orchestrator detects changes in:

- **PowerShell Files:** `**/*.ps1`, `**/*.psm1`, `**/*.psd1`
- **Docker Files:** `Dockerfile`, `docker-compose.yml`, `.dockerignore`
- **Workflows:** `.github/workflows/**/*.yml`
- **Documentation:** `docs/**/*`, `**/*.md`
- **Tests:** `tests/**/*`, `library/tests/**/*`

Based on changes, it conditionally executes:

| Changed Files | Triggered Jobs |
|---------------|----------------|
| PowerShell | Tests, Build |
| Docker | Docker build |
| Workflows | All (for safety) |
| Docs | Documentation generation |
| Tests | Test suite |

## Playbook Integration

### PR Ecosystem Playbooks

#### pr-ecosystem-build.psd1

**Purpose:** Build phase orchestration  
**Scripts:**
- 0407: Syntax validation
- 0515: Build metadata generation
- 0902: Release package creation
- 0900: Self-deployment validation

**Artifacts Tracked:**
- Build packages (ZIP, TAR.GZ)
- Build metadata JSON
- Docker container info

**Version:** 2.1.0 (includes Docker tracking)

#### pr-ecosystem-report.psd1

**Purpose:** Reporting phase orchestration  
**Scripts:**
- 0513: Changelog generation
- 0518: Recommendations
- 0512: Dashboard generation
- 0510: Detailed reports
- 0519: PR comment content

**Artifacts Tracked:**
- Dashboard (HTML, Markdown, JSON)
- Changelog
- Recommendations
- Docker image information

**Version:** 2.1.0 (includes Docker status)

#### pr-ecosystem-analyze.psd1

**Purpose:** Analysis phase orchestration  
**Scripts:**
- 0402, 0403: Unit and integration tests
- 0404, 0420: Quality analysis
- 0521, 0425: Documentation analysis
- 0523: Security scan
- 0514: Diff analysis
- 0517: Results aggregation

**Note:** Currently defined but not used in pr-complete.yml

## Docker Container Build

### PR Builds

**Registry:** GitHub Container Registry (ghcr.io)  
**Tags:**
- `pr-NUMBER` (e.g., pr-123)
- `pr-NUMBER-SHA` (e.g., pr-123-a1b2c3d)
- `refs/pull/NUMBER/merge`

**Platforms:** linux/amd64, linux/arm64

**Validation:**
- Container startup test
- Module manifest presence check
- Basic PowerShell execution

**Usage:**
```bash
# Pull PR image
docker pull ghcr.io/wizzense/aitherzero:pr-123

# Run interactively
docker run -it --rm ghcr.io/wizzense/aitherzero:pr-123
```

### Release Builds

**Tags:**
- Version: `X.Y.Z`, `vX.Y.Z`
- Major.Minor: `X.Y`
- Major: `X`
- Latest: `latest`, `stable`
- Commit: `sha-XXXXXXXX`
- Timestamp: `release-YYYYMMDD-HHMMSS`

**Platforms:** linux/amd64, linux/arm64

**Labels:**
- OCI standard labels (title, description, version, source, etc.)
- Custom labels (PR number, build type, etc.)

## Workflow Dependencies

### PR Complete Flow

```
quick-validation
    ↓
test-matrix-prepare
    ↓
┌───────────────┬──────────────┬─────────────────────┐
│ unit-tests    │ domain-tests │ integration-tests   │
└───────────────┴──────────────┴─────────────────────┘
    ↓
test-summary
    ↓
┌──────────┬───────────────────┐
│ build    │ quality-analysis  │
└──────────┴───────────────────┘
    ↓
build-docker-image
    ↓
dashboard
```

### Master Orchestrator Flow

```
orchestration (context analysis + file detection)
    ↓
┌─────────────┬─────────────────┬────────────────┐
│ pr-workflow │ release-workflow│ standalone jobs│
│ (if PR)     │ (if release tag)│ (other events) │
└─────────────┴─────────────────┴────────────────┘
    ↓
summary (comprehensive results)
```

## Manual Workflow Execution

### Via GitHub UI

1. Go to **Actions** tab
2. Select **Master CI/CD Orchestrator**
3. Click **Run workflow**
4. Choose:
   - **Workflow:** all, pr-validation, testing, build, release, documentation
   - **Force all tests:** true/false
5. Click **Run workflow**

### Via GitHub CLI

```bash
# Run all workflows
gh workflow run master-ci-cd.yml -f workflow=all

# Run specific workflow
gh workflow run master-ci-cd.yml -f workflow=testing -f force_all_tests=true

# Run release
gh workflow run master-ci-cd.yml -f workflow=release
```

## Monitoring and Troubleshooting

### Check Workflow Status

```bash
# List recent runs
gh run list --workflow=master-ci-cd.yml

# View specific run
gh run view RUN_ID

# View logs
gh run view RUN_ID --log
```

### Common Issues

#### 1. Docker Build Fails

**Symptoms:** build-docker-image job fails  
**Solution:**
- Check Dockerfile syntax
- Verify base image availability
- Review build logs for specific errors
- Ensure GitHub Container Registry permissions

#### 2. PR Workflow Doesn't Trigger

**Symptoms:** No workflow runs on PR  
**Solution:**
- Check branch protection rules
- Verify workflow file syntax
- Ensure PR is not from a fork (different permissions)
- Review workflow file triggers

#### 3. Playbook Execution Fails

**Symptoms:** Build or report phase fails  
**Solution:**
- Check playbook syntax (valid PowerShell data file)
- Verify referenced scripts exist (e.g., 0407, 0515)
- Review playbook validation: `./automation-scripts/0970_Validate-AllPlaybooks.ps1`
- Check script parameters match playbook definitions

#### 4. Artifacts Not Created

**Symptoms:** Expected files missing  
**Solution:**
- Check script execution succeeded
- Verify output paths in playbooks
- Review artifact upload conditions
- Check if files were created but not uploaded

## Best Practices

### For Contributors

1. **Let the orchestrator decide:** Don't manually trigger workflows unless necessary
2. **Review PR dashboard:** Check generated dashboard before requesting review
3. **Test locally first:** Run `./automation-scripts/0407_Validate-Syntax.ps1` before pushing
4. **Update playbooks:** If adding new build/report scripts, update relevant playbooks

### For Maintainers

1. **Monitor orchestrator decisions:** Review what runs and why
2. **Optimize file detection:** Adjust patterns if too many/few workflows trigger
3. **Update documentation:** Keep this guide in sync with workflow changes
4. **Review metrics:** Use workflow timings to identify optimization opportunities

### For Infrastructure Changes

1. **Docker changes:** Always trigger Docker build in CI
2. **Workflow changes:** Test with workflow_dispatch before pushing
3. **Playbook changes:** Validate with `0970_Validate-AllPlaybooks.ps1`
4. **Breaking changes:** Update documentation and notify team

## Performance Metrics

### Target Durations

| Workflow | Target | Typical |
|----------|--------|---------|
| Quick Validation | 3 min | 2-4 min |
| Test Matrix | 15 min | 10-18 min |
| Build Phase | 10 min | 5-12 min |
| Docker Build | 15 min | 10-20 min |
| Quality Analysis | 10 min | 5-12 min |
| Dashboard | 5 min | 3-7 min |
| **Total PR** | **30 min** | **25-35 min** |
| **Total Release** | **45 min** | **35-50 min** |

### Optimization Tips

1. **Parallel execution:** Use matrix jobs where possible
2. **Caching:** Enable Docker layer caching, dependency caching
3. **Selective execution:** Run only what changed (file detection)
4. **Early termination:** Fail fast on critical errors
5. **Artifact pruning:** Keep only necessary artifacts

## Related Documentation

- **Playbook Guide:** `library/playbooks/README.md`
- **CI/CD Sequences:** `.github/workflows/CONSOLIDATION-GUIDE.md`
- **Docker Documentation:** `DOCKER.md`
- **Release Process:** `.github/workflows/release-automation.yml` (inline docs)
- **Contributing Guide:** `CONTRIBUTING.md` (if exists)

## Version History

- **v2.1.0** (2025-11-09): Added Docker container build integration to PR workflow and playbooks
- **v2.0.0** (2025-11-08): Created master orchestrator for centralized coordination
- **v1.x.x** (earlier): Individual workflows without central coordination

---

**Last Updated:** 2025-11-09  
**Maintained By:** Infrastructure Team (Maya)  
**Contact:** Create an issue for questions or improvements
