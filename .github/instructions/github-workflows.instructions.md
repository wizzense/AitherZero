---
applyTo: ".github/workflows/**/*.yml"
---

# GitHub Actions Workflow Requirements

When creating or modifying GitHub Actions workflows for AitherZero, follow these guidelines:

## Workflow Structure

### Standard Metadata

```yaml
---
name: 🎯 Workflow Name

on:
  workflow_dispatch:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read
  issues: write
  pull-requests: write
  checks: write

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true
```

### Standard Job Structure

```yaml
jobs:
  job-name:
    name: 📦 Job Description
    runs-on: ubuntu-latest
    timeout-minutes: 20
    
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4
      
      - name: 🔧 Bootstrap Environment
        shell: pwsh
        run: |
          ./bootstrap.ps1 -Mode New -InstallProfile Minimal
      
      - name: 📦 Load Module
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
      
      # Additional steps...
```

## Bootstrap Requirements

**ALWAYS bootstrap the environment** before using AitherZero:

```yaml
- name: 🔧 Bootstrap Environment
  shell: pwsh
  run: |
    Write-Host "🚀 Bootstrapping AitherZero..." -ForegroundColor Cyan
    ./bootstrap.ps1 -Mode New -InstallProfile Minimal
```

**Profiles:**
- `Minimal` - Fast bootstrap for CI/CD (recommended)
- `Standard` - Standard installation
- `Developer` - Full development tools
- `Full` - Complete installation with all features

## PowerShell Execution

Use `shell: pwsh` for all PowerShell steps:

```yaml
- name: Run PowerShell Script
  shell: pwsh
  run: |
    Write-Host "Running script..." -ForegroundColor Cyan
    ./library/automation-scripts/0402_Run-UnitTests.ps1
```

## Environment Variables

Set standard environment variables:

```yaml
env:
  AITHERZERO_CI: true                 # Detect CI environment
  AITHERZERO_NONINTERACTIVE: true     # Non-interactive mode
  AITHERZERO_SUPPRESS_BANNER: true    # Suppress banner output
  TERM: xterm-256color                # Terminal compatibility
```

## GitHub Issue Creation Pattern

**CRITICAL:** Use `actions/github-script@v7` for creating issues, NOT `gh` CLI!

❌ **WRONG - Do NOT use gh CLI in workflows:**
```yaml
- name: Create Issue
  run: |
    gh issue create --title "..." --body "..."  # Requires explicit auth setup
```

✅ **CORRECT - Use actions/github-script:**
```yaml
- name: Create Issue
  uses: actions/github-script@v7
  with:
    script: |
      const issue = await github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: 'Issue title',
        body: 'Issue body',
        labels: ['label1', 'label2']
      });
      console.log(`Created issue #${issue.data.number}`);
```

**Benefits of actions/github-script:**
- Built-in authentication (no GITHUB_TOKEN setup needed)
- Full GitHub REST API access
- Better error handling
- JavaScript/TypeScript for JSON manipulation

## Workflow Triggers

### PR Triggers

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]
```

### Push Triggers

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'aithercore/**'
      - 'tests/**'
      - '.github/workflows/**'
```

### Manual Triggers

```yaml
on:
  workflow_dispatch:
    inputs:
      parameter:
        description: 'Parameter description'
        required: true
        default: 'default-value'
        type: string
```

## Job Dependencies

Use `needs` to create workflow dependencies:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      # validation steps
  
  test:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      # test steps
  
  deploy:
    needs: [validate, test]
    runs-on: ubuntu-latest
    steps:
      # deployment steps
```

## Conditional Execution

Use `if` conditions for conditional jobs:

```yaml
jobs:
  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      # deployment steps
```

## Artifacts and Caching

### Upload Artifacts

```yaml
- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: tests/results/**/*
    retention-days: 7
```

### Cache Dependencies

```yaml
- name: Cache PowerShell Modules
  uses: actions/cache@v4
  with:
    path: ~/.local/share/powershell/Modules
    key: ${{ runner.os }}-pwsh-modules-${{ hashFiles('**/AitherZero.psd1') }}
    restore-keys: |
      ${{ runner.os }}-pwsh-modules-
```

## Error Handling

Set appropriate error handling:

```yaml
- name: Run Tests
  shell: pwsh
  run: |
    $ErrorActionPreference = 'Stop'
    try {
      ./library/automation-scripts/0402_Run-UnitTests.ps1
    }
    catch {
      Write-Error "Tests failed: $_"
      exit 1
    }
```

## Output and Summary

### Job Outputs

```yaml
jobs:
  build:
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - id: version
        run: |
          $version = "1.0.0"
          echo "version=$version" >> $env:GITHUB_OUTPUT
```

### Job Summary

```yaml
- name: Generate Summary
  shell: pwsh
  run: |
    $summary = @"
    ## Test Results
    - ✅ Passed: 150
    - ❌ Failed: 2
    - ⏭️ Skipped: 5
    "@
    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8
```

## Permissions

Set minimum required permissions:

```yaml
permissions:
  contents: read        # Read repository
  issues: write         # Create/update issues
  pull-requests: write  # Comment on PRs
  checks: write         # Update check runs
  statuses: write       # Update commit statuses
```

## Timeout and Resource Limits

Set appropriate timeouts:

```yaml
jobs:
  test:
    timeout-minutes: 30    # Job timeout
    steps:
      - name: Run Tests
        timeout-minutes: 20  # Step timeout
        run: |
          # test commands
```

## Matrix Strategies

Use matrix for multi-platform testing:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        pwsh-version: ['7.4']
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      # test steps
```

## Reusable Workflows

Create reusable workflows:

```yaml
# .github/workflows/reusable-test.yml
on:
  workflow_call:
    inputs:
      test-path:
        required: true
        type: string

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./run-tests.ps1 -Path ${{ inputs.test-path }}
```

Use from another workflow:

```yaml
jobs:
  call-test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      test-path: 'tests/unit'
```

## Best Practices

1. **Always bootstrap** - Run `bootstrap.ps1` before using AitherZero
2. **Use minimal profile** - `-InstallProfile Minimal` for CI performance
3. **Set timeouts** - Prevent hung workflows
4. **Upload artifacts** - Preserve test results and logs
5. **Use github-script** - For GitHub API operations (not gh CLI)
6. **Check exit codes** - Fail workflows on errors
7. **Add job summaries** - Provide clear feedback
8. **Use if: always()** - For cleanup and artifact upload
9. **Minimize permissions** - Only request what's needed
10. **Cache dependencies** - Speed up workflow execution

## Example Workflow Template

```yaml
---
name: 🧪 Test Workflow

on:
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  checks: write

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true

jobs:
  test:
    name: 🧪 Run Tests
    runs-on: ubuntu-latest
    timeout-minutes: 20
    
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4
      
      - name: 🔧 Bootstrap
        shell: pwsh
        run: |
          ./bootstrap.ps1 -Mode New -InstallProfile Minimal
      
      - name: 📦 Load Module
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
      
      - name: 🧪 Run Tests
        shell: pwsh
        run: |
          ./library/automation-scripts/0402_Run-UnitTests.ps1 -CI
      
      - name: 📊 Upload Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: tests/results/**/*
```

## Reference

- See `.github/copilot-instructions.md` for repository architecture
- See `.github/workflows/` for existing workflow examples
- See GitHub Actions documentation for advanced features
