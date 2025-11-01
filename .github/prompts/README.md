# AitherZero Copilot Prompt Library

Reusable one-shot prompts for common development tasks in AitherZero.

## Quick Start

```bash
# Use a prompt in Copilot Chat
@copilot Use the github-actions-troubleshoot prompt to diagnose workflow failures

# Or reference directly
@copilot Following the use-aitherzero-workflows prompt, run unit tests
```

## Available Prompts

### 🔧 Troubleshooting

| Prompt | Purpose | When to Use |
|--------|---------|-------------|
| **[github-actions-troubleshoot.md](./github-actions-troubleshoot.md)** | Fix GitHub Actions failures | Workflows not running, PR checks missing |
| **[test-failure-triage.md](./test-failure-triage.md)** | Analyze test failures | Tests failing, need root cause |
| **[pr-validation-failures.md](./pr-validation-failures.md)** | Fix PR validation | PR checks failing, quality issues |
| **[troubleshoot-ci-cd.md](./troubleshoot-ci-cd.md)** | Debug CI/CD pipeline | Artifacts missing, dependencies broken |

### 💻 Development

| Prompt | Purpose | When to Use |
|--------|---------|-------------|
| **[use-aitherzero-workflows.md](./use-aitherzero-workflows.md)** | Use AitherZero tools | Learn number-based scripts, playbooks |
| **[add-new-feature.md](./add-new-feature.md)** | Add features properly | New functionality needed |
| **[fix-powershell-quality.md](./fix-powershell-quality.md)** | Fix PSScriptAnalyzer | Quality warnings to address |
| **[refactor-function.md](./refactor-function.md)** | Refactor PowerShell | Code needs improvement |

### 📊 Testing & Quality

| Prompt | Purpose | When to Use |
|--------|---------|-------------|
| **[manage-test-reports.md](./manage-test-reports.md)** | Manage test results | Dashboard, reports, GitHub Pages |
| **[write-pester-tests.md](./write-pester-tests.md)** | Create Pester tests | New code needs tests |
| **[fix-test-infrastructure.md](./fix-test-infrastructure.md)** | Fix test system | Test framework issues |

### 📚 Documentation

| Prompt | Purpose | When to Use |
|--------|---------|-------------|
| **[generate-docs.md](./generate-docs.md)** | Generate documentation | Functions need docs |
| **[update-readme.md](./update-readme.md)** | Update README files | Documentation outdated |

## Prompt Structure

Each prompt follows this structure:

1. **One-Shot Command** - Copy/paste ready prompt for @copilot
2. **Specific Scenarios** - Common situations with solutions
3. **Prevention Best Practices** - Avoid future issues
4. **Quick Reference** - Commands and examples
5. **When to Use** - Situations where this prompt helps

## Usage Examples

### Example 1: Fix Broken Workflows

```
@copilot GitHub Actions workflows stopped appearing on my PR. 
Use the github-actions-troubleshoot prompt to diagnose and fix.
```

Copilot will:
1. Validate YAML syntax in all workflows
2. Check workflow triggers match your branch
3. Identify root causes
4. Apply fixes
5. Verify workflows run

### Example 2: Run Tests the AitherZero Way

```
@copilot Following use-aitherzero-workflows prompt, run comprehensive tests
```

Copilot will:
1. Initialize AitherZero environment
2. Run `az 0402` for unit tests
3. Run `az 0404` for PSScriptAnalyzer
4. Generate reports
5. Show results

### Example 3: Add New Feature

```
@copilot Use add-new-feature prompt to create a new VM management function
```

Copilot will:
1. Choose correct domain (infrastructure/)
2. Follow naming conventions
3. Add error handling
4. Create tests
5. Update documentation

## Creating New Prompts

Template structure:

```markdown
# [Prompt Name]

Brief description.

## One-Shot Troubleshooting Prompt

\```
@copilot [Complete instruction that Copilot can execute]

1. [Diagnostic step with commands]
2. [Analysis step]
3. [Fix step]
4. [Verification step]
\```

## Specific Scenarios

### Scenario Name
**Symptoms:** What user sees
**Root Causes:** Why it happens
**Quick Fix:** How to fix
\```bash
# Commands to fix
\```

## Prevention Best Practices

1. Practice 1
2. Practice 2

## Quick Reference Commands

\```powershell
# Key commands
\```

## When to Use This Prompt

- Situation 1
- Situation 2
```

## Best Practices

### Writing Prompts

1. **Self-contained** - Include all necessary context
2. **Step-by-step** - Clear numbered instructions
3. **Command examples** - Show exact commands to run
4. **Verification** - Always include check steps
5. **Root causes** - Explain why issues happen

### Using Prompts

1. **Reference by name** - "@copilot use X prompt"
2. **Combine prompts** - Multiple prompts for complex tasks
3. **Customize** - Add specific context to prompts
4. **Verify** - Always check results
5. **Update** - Improve prompts based on experience

### Maintaining Prompts

1. **Test regularly** - Ensure prompts work
2. **Update** - Keep current with project changes
3. **Document** - Add new scenarios as discovered
4. **Version** - Track major changes
5. **Share** - Contribute improvements

## AitherZero-Specific Patterns

### Number-Based Scripts

```powershell
az 0402  # Unit tests
az 0404  # PSScriptAnalyzer
az 0407  # Syntax validation
az 0510  # Project report
```

### Orchestration Playbooks

```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook [name]
```

### Environment Initialization

```powershell
./Initialize-AitherEnvironment.ps1  # Always run first
```

## Contributing

To add a new prompt:

1. Create file in `.github/prompts/`
2. Follow template structure
3. Test with @copilot
4. Add to this README
5. Submit PR

## Support

- **Issues**: Report prompt problems via GitHub Issues
- **Improvements**: Submit PRs with enhancements
- **Questions**: Ask in discussions

## Changelog

- **2025-11-01**: Initial prompt library created
  - 8 core troubleshooting prompts
  - 4 development prompts
  - 3 testing prompts
  - 2 documentation prompts
