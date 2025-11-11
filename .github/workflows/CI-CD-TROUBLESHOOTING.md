# 🔧 CI/CD Pipeline Troubleshooting Playbook

## Quick Diagnostics

### Is the workflow running at all?

```bash
# Check recent workflow runs
gh run list --limit 10

# Check specific workflow
gh run list --workflow=01-master-orchestrator.yml --limit 5

# View workflow details
gh run view <run-id>
```

**Common Causes:**
- Workflow file has syntax errors
- Branch not in trigger list
- Workflow file not in `.github/workflows/`
- Repository settings block workflows

### Is the workflow getting canceled?

```bash
# Look for canceled runs
gh run list --status cancelled --limit 10

# Check concurrency groups
grep -A2 "concurrency:" .github/workflows/*.yml
```

**Common Causes:**
- Duplicate concurrency groups
- `cancel-in-progress: true` with overlapping groups
- Multiple commits in quick succession

### Is a specific job failing?

```bash
# View job details
gh run view <run-id>

# Download job logs
gh run view <run-id> --log

# View specific job logs
gh run view <run-id> --log | grep "job-name"
```

## Workflow-Specific Issues

### 01-Master Orchestrator Not Running

**Symptoms:**
- No orchestrator runs on PR events
- Workflow shows as "skipped"
- No child workflows triggered

**Diagnosis:**
```bash
# Check if workflow file exists
ls -la .github/workflows/01-master-orchestrator.yml

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/01-master-orchestrator.yml'))"

# Check branch triggers
grep -A5 "pull_request:" .github/workflows/01-master-orchestrator.yml
```

**Solutions:**

1. **Workflow not triggering**
   ```yaml
   # Ensure branch is in trigger list
   pull_request:
     branches: [main, dev, develop, dev-staging, ring-0, ring-0-integrations, ring-1, ring-1-integrations, ring-2]
   ```

2. **Concurrency blocking**
   ```yaml
   # Check concurrency group is unique
   concurrency:
     group: orchestrator-${{ github.event.pull_request.number || github.ref }}
     cancel-in-progress: true
   ```

3. **Job references incorrect**
   ```yaml
   # Summary job should reference pr-ecosystem, not pr-workflow
   needs: [orchestration, pr-ecosystem, release-workflow, ...]
   ```

### 02-PR Validation Build Not Called

**Symptoms:**
- Master orchestrator runs but doesn't call PR validation
- `pr-ecosystem` job shows as skipped
- `run-pr-workflow` output is false

**Diagnosis:**
```bash
# Check orchestrator decision logic
gh run view <run-id> --log | grep -A5 "Orchestration Decision"
```

**Solutions:**

1. **Workflow not identified as PR**
   ```bash
   # Check orchestration context detection
   IS_PR="${{ github.event_name == 'pull_request' }}"
   # Should be 'true' for PR events
   ```

2. **Output not set correctly**
   ```bash
   # Verify output step
   echo "run-pr-workflow=${RUN_PR_WORKFLOW}" >> $GITHUB_OUTPUT
   ```

3. **Condition not matching**
   ```yaml
   # Check if condition
   if: needs.orchestration.outputs.run-pr-workflow == 'true'
   ```

### 03-Test Execution Running But Failing

**Symptoms:**
- Tests start but fail immediately
- "Prepare test matrix" fails
- Module import errors

**Diagnosis:**
```bash
# Check bootstrap execution
gh run view <run-id> --log | grep -A10 "Bootstrap"

# Check module loading
gh run view <run-id> --log | grep -i "import.*module"
```

**Solutions:**

1. **Bootstrap failure**
   ```yaml
   # Ensure bootstrap runs with correct parameters
   - name: 🔧 Bootstrap Environment
     shell: pwsh
     run: |
       ./bootstrap.ps1 -Mode New -InstallProfile Minimal
   ```

2. **Module not loading**
   ```yaml
   # Import module explicitly
   - name: 📦 Load Module
     shell: pwsh
     run: |
       Import-Module ./AitherZero.psd1 -Force
   ```

3. **Pester not available**
   ```yaml
   # Install testing tools
   - name: Install Pester
     shell: pwsh
     run: |
       Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
   ```

### 04-Deploy PR Environment Docker Build Fails

**Symptoms:**
- Docker build starts but fails
- "Build and Push Container" step fails
- Tag generation issues

**Diagnosis:**
```bash
# Check Docker build logs
gh run view <run-id> --log | grep -A50 "Build and Push Container"

# Check tag generation
gh run view <run-id> --log | grep "Generated.*tags"
```

**Solutions:**

1. **Dockerfile syntax error**
   ```bash
   # Validate Dockerfile
   docker build --check .
   ```

2. **Tag generation failure**
   ```bash
   # Check tag generation step
   BRANCH_SLUG=$(echo "$BRANCH_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
   ```

3. **Push permission denied**
   ```yaml
   # Ensure GitHub token has package write permission
   permissions:
     packages: write
   ```

4. **Platforms not available**
   ```yaml
   # For CI, use single platform
   platforms: linux/amd64
   ```

## Playbook Execution Issues

### Invoke-AitherPlaybook Not Found

**Symptoms:**
- `Invoke-AitherPlaybook: command not found`
- Module not loaded

**Diagnosis:**
```bash
# Check if command is available
pwsh -Command "Import-Module ./AitherZero.psd1; Get-Command Invoke-AitherPlaybook"
```

**Solutions:**

1. **Module not imported**
   ```yaml
   - name: Load Module
     shell: pwsh
     run: |
       Import-Module ./AitherZero.psd1 -Force
   ```

2. **Function not exported**
   ```powershell
   # Check module manifest
   grep "Invoke-AitherPlaybook" AitherZero.psd1
   ```

### Playbook Not Found

**Symptoms:**
- `Playbook 'name' not found`
- File doesn't exist

**Diagnosis:**
```bash
# Check playbook exists
ls -la library/playbooks/pr-ecosystem-build.psd1

# Validate playbook syntax
pwsh -Command "Import-PowerShellDataFile ./library/playbooks/pr-ecosystem-build.psd1"
```

**Solutions:**

1. **File doesn't exist**
   ```bash
   # Create playbook file
   ls library/playbooks/
   ```

2. **Invalid syntax**
   ```bash
   # Validate PowerShell data file
   pwsh -Command "Import-PowerShellDataFile <file>"
   ```

### Script Referenced in Playbook Not Found

**Symptoms:**
- `Script '0515' not found`
- Playbook fails partway through

**Diagnosis:**
```bash
# Check script exists
ls -la library/automation-scripts/0515*.ps1

# Check playbook references
grep -n "Script = " library/playbooks/pr-ecosystem-build.psd1
```

**Solutions:**

1. **Script doesn't exist**
   ```bash
   # Find scripts in range
   ls library/automation-scripts/051*.ps1
   ```

2. **Script number incorrect**
   ```powershell
   # Update playbook with correct number
   @{
       Script = "0515"  # Must match filename prefix
   }
   ```

## Concurrency Issues

### Workflows Canceling Each Other

**Symptoms:**
- Workflow shows as "canceled"
- Multiple workflows trigger but only one runs
- Jobs get canceled midway

**Diagnosis:**
```bash
# Check concurrency groups
python3 << 'EOF'
import yaml
import glob

for file in glob.glob('.github/workflows/*.yml'):
    with open(file) as f:
        wf = yaml.safe_load(f)
    concurrency = wf.get('concurrency', {})
    if concurrency:
        print(f"{file}: {concurrency.get('group', 'N/A')}")
EOF
```

**Solutions:**

1. **Duplicate concurrency groups**
   ```yaml
   # Make groups unique per workflow
   concurrency:
     group: orchestrator-${{ github.event.pull_request.number || github.ref }}
     # NOT just: ${{ github.ref }}
   ```

2. **Aggressive cancellation**
   ```yaml
   # Consider if cancel-in-progress should be false
   concurrency:
     group: deploy-${{ github.event.pull_request.number }}
     cancel-in-progress: false  # Don't cancel deployments
   ```

## Deployment Issues

### Container Not Starting

**Symptoms:**
- Container starts then immediately exits
- Health check never succeeds
- Logs show errors

**Diagnosis:**
```bash
# Check container status
docker ps -a --filter "name=aitherzero-pr-"

# Check logs
docker logs aitherzero-pr-123

# Inspect container
docker inspect aitherzero-pr-123 --format '{{.State.Health.Status}}'
```

**Solutions:**

1. **Module load failure**
   ```bash
   # Test module loading
   docker exec aitherzero-pr-123 pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1"
   ```

2. **Health check timeout**
   ```dockerfile
   # Increase health check timeout in Dockerfile
   HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
     CMD pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1; exit 0"
   ```

3. **Port conflict**
   ```bash
   # Check port availability
   docker run -d -p 8124:8080 --name aitherzero-pr-124 <image>
   ```

### Dashboard Not Deployed

**Symptoms:**
- GitHub Pages doesn't show dashboard
- Dashboard job succeeds but nothing appears
- 404 on GitHub Pages URL

**Diagnosis:**
```bash
# Check GitHub Pages is enabled
gh repo view --json homepageUrl

# Check dashboard artifacts
gh run view <run-id> --log | grep -A10 "Deploy to GitHub Pages"

# Verify files were created
ls -la library/reports/pr-*/dashboard/
```

**Solutions:**

1. **GitHub Pages not enabled**
   ```bash
   # Enable in repository settings
   # Settings → Pages → Source: GitHub Actions
   ```

2. **Files not generated**
   ```yaml
   # Check dashboard generation playbook ran
   Invoke-AitherPlaybook -Name dashboard-generation-complete
   ```

3. **Wrong path**
   ```yaml
   # Verify publish directory
   publish_dir: ./library/reports/pr-${{ env.PR_NUMBER }}
   ```

## Performance Issues

### Workflows Taking Too Long

**Symptoms:**
- Workflows timeout
- Jobs run for excessive time
- Resource exhaustion

**Diagnosis:**
```bash
# Check workflow duration
gh run list --workflow=03-test-execution.yml --limit 10 --json durationMs,conclusion

# Identify slow jobs
gh run view <run-id> | grep "Duration:"
```

**Solutions:**

1. **Increase timeouts**
   ```yaml
   jobs:
     test:
       timeout-minutes: 30  # Increase from default 360
   ```

2. **Enable caching**
   ```yaml
   - name: Cache PowerShell Modules
     uses: actions/cache@v4
     with:
       path: ~/.local/share/powershell/Modules
       key: ${{ runner.os }}-pwsh-modules-${{ hashFiles('**/AitherZero.psd1') }}
   ```

3. **Use matrix for parallel execution**
   ```yaml
   strategy:
     matrix:
       test-suite: [unit, domain, integration]
     max-parallel: 3
   ```

## GitHub-Specific Issues

### Workflow Doesn't Appear in UI

**Symptoms:**
- Workflow file exists but doesn't show in Actions tab
- Can't trigger manually
- No workflow runs history

**Diagnosis:**
```bash
# Check workflow file location
ls -la .github/workflows/

# Validate workflow file
gh workflow list

# Check file syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/file.yml'))"
```

**Solutions:**

1. **File not committed**
   ```bash
   git add .github/workflows/
   git commit -m "Add workflow"
   git push
   ```

2. **YAML syntax error**
   ```bash
   # Fix and re-push
   yamllint .github/workflows/file.yml
   ```

3. **Workflow disabled**
   ```bash
   # Check if disabled
   gh workflow list
   # Enable if needed
   gh workflow enable <workflow-name>
   ```

### Permissions Denied

**Symptoms:**
- `403 Forbidden` errors
- Can't push Docker images
- Can't write to packages

**Diagnosis:**
```bash
# Check workflow permissions
gh run view <run-id> --log | grep -i "permission\|forbidden\|403"
```

**Solutions:**

1. **Missing permissions in workflow**
   ```yaml
   permissions:
     contents: read
     packages: write  # Required for Docker push
     pull-requests: write
   ```

2. **Repository settings restrictive**
   ```bash
   # Check Settings → Actions → General → Workflow permissions
   # Should be: "Read and write permissions"
   ```

3. **Token doesn't have scope**
   ```yaml
   # Use GITHUB_TOKEN with correct scope
   - name: Login to GHCR
     uses: docker/login-action@v3
     with:
       registry: ghcr.io
       username: ${{ github.actor }}
       password: ${{ secrets.GITHUB_TOKEN }}
   ```

## Emergency Procedures

### Kill All Running Workflows

```bash
# Cancel all running workflows
gh run list --status in_progress --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run cancel {}
```

### Force Workflow Re-run

```bash
# Re-run failed workflow
gh run rerun <run-id>

# Re-run specific job
gh run rerun <run-id> --job <job-id>
```

### Manual Deployment Override

```bash
# Trigger deploy workflow manually
gh workflow run 04-deploy-pr-environment.yml \
  -f pr_number=123 \
  -f force_redeploy=true
```

## Monitoring & Alerts

### Set Up Alerts

```bash
# GitHub CLI watch
gh run watch

# Monitor specific workflow
while true; do
  gh run list --workflow=01-master-orchestrator.yml --limit 1
  sleep 30
done
```

### Health Dashboard

Check these regularly:
- **Workflow Success Rate**: `gh run list --status completed --json conclusion | jq '[.[] | .conclusion] | group_by(.) | map({key: .[0], value: length}) | from_entries'`
- **Average Duration**: `gh run list --limit 50 --json durationMs | jq '[.[].durationMs] | add/length / 1000 / 60'`
- **Failure Patterns**: `gh run list --status failure --limit 20`

## Getting Help

1. **Check workflow logs**: `gh run view <run-id> --log`
2. **Review this playbook**: Most common issues covered
3. **Check documentation**: `.github/workflows/README.md`
4. **Create issue**: Document symptoms, steps, logs

---

**Last Updated**: 2025-11-11  
**Maintained By**: Infrastructure Team (Maya)  
**Version**: 1.0.0
