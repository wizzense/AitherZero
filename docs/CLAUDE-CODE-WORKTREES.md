# Using Git Worktrees with Claude Code for Multi-Task Development

## Overview

Git worktrees allow Claude Code to work on multiple tasks simultaneously without conflicts, similar to having multiple developers working on the same project. Each task/sub-agent gets its own isolated working directory.

## Why Use Worktrees?

1. **Parallel Development**: Work on multiple features/fixes simultaneously
2. **No Context Switching**: Each task maintains its own state
3. **Clean Separation**: No risk of mixing changes between tasks
4. **Sub-Agent Isolation**: Each AI sub-agent works in its own space
5. **Easier Review**: Changes are organized by task/feature

## Quick Start

### 1. Setup a New Worktree for a Task

```powershell
# Create worktree for validation fixes
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "validation-fixes"

# Create worktree for a new feature
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "issue-lifecycle-feature"

# Create worktree from specific branch
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "hotfix-123" -BaseBranch "release/1.0"
```

### 2. List Active Worktrees

```powershell
# See all worktrees
./scripts/Configure-GitWorktrees.ps1 -Action List

# Get detailed status
./scripts/Configure-GitWorktrees.ps1 -Action Status
```

### 3. Remove a Worktree

```powershell
# Remove when task is complete
./scripts/Configure-GitWorktrees.ps1 -Action Remove -TaskName "validation-fixes"

# Force removal (even with uncommitted changes)
./scripts/Configure-GitWorktrees.ps1 -Action Remove -TaskName "validation-fixes" -Force
```

## Claude Code Instructions

When working with worktrees, follow these patterns:

### For Task-Specific Work

```markdown
I need you to work on fixing validation errors. Please:
1. Setup a worktree: ./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "fix-validation-errors"
2. Work in the worktree directory shown in the output
3. Use PatchManager for all commits in that worktree
4. When complete, create a PR from that branch
```

### For Multiple Sub-Agents

```markdown
I need three parallel tasks:
1. Sub-Agent 1: Fix CI workflow errors
   - Setup worktree: "ci-workflow-fixes"
2. Sub-Agent 2: Update documentation
   - Setup worktree: "documentation-updates"
3. Sub-Agent 3: Add new tests
   - Setup worktree: "test-coverage"

Each sub-agent should work only in their assigned worktree.
```

## Worktree Structure

```
/workspaces/
├── AitherZero/                    # Main repository
└── aitherzero-worktrees/          # Worktree container
    ├── validation-fixes/          # Task 1 worktree
    ├── issue-lifecycle-feature/   # Task 2 worktree
    └── hotfix-123/               # Task 3 worktree
```

## Best Practices

### 1. Task Naming Convention

Use descriptive task names that indicate the work:
- `fix-{issue-number}-{description}`
- `feature-{name}`
- `hotfix-{issue}`
- `refactor-{module}`

### 2. Branch Strategy

Each worktree gets its own branch:
- Pattern: `task/{taskname}/{timestamp}`
- Example: `task/validation-fixes/20250111-150230`

### 3. Worktree Lifecycle

1. **Create**: When starting a new task
2. **Work**: Make changes in the isolated directory
3. **Commit**: Use PatchManager in the worktree
4. **PR**: Create PR from the worktree branch
5. **Clean**: Remove worktree after PR is merged

### 4. Parallel Workflow Example

```powershell
# Claude Code can work on multiple tasks:

# Terminal 1 - Validation fixes
cd /workspaces/aitherzero-worktrees/validation-fixes
# Fix validation errors here

# Terminal 2 - New feature
cd /workspaces/aitherzero-worktrees/new-feature
# Implement feature here

# Terminal 3 - Documentation
cd /workspaces/aitherzero-worktrees/docs-update
# Update documentation here
```

## Configuration

Worktree configuration is stored in `.claude/worktree-config.json`:

```json
{
  "worktrees": [
    {
      "name": "validation-fixes",
      "path": "/workspaces/aitherzero-worktrees/validation-fixes",
      "branch": "task/validation-fixes/20250111-150230",
      "created": "2025-01-11 15:02:30",
      "status": "active"
    }
  ],
  "settings": {
    "maxWorktrees": 10,
    "autoCleanDays": 30,
    "namingPattern": "task/{taskname}/{date}"
  }
}
```

## Task-Specific Configuration

Each worktree contains `.claude-task.json`:

```json
{
  "task": "validation-fixes",
  "branch": "task/validation-fixes/20250111-150230",
  "baseBranch": "main",
  "created": "2025-01-11 15:02:30",
  "claudeInstructions": "Work only in this directory..."
}
```

## Automated Cleanup

Stale worktrees are automatically cleaned:

```powershell
# Clean worktrees older than 30 days
./scripts/Configure-GitWorktrees.ps1 -Action Clean

# Force clean all inactive worktrees
./scripts/Configure-GitWorktrees.ps1 -Action Clean -Force
```

## Integration with Validation Pipeline

Worktrees integrate with the validation pipeline:

1. **Pre-commit hooks** work in each worktree
2. **Validation** runs on worktree changes
3. **Issues** are created with worktree context
4. **CI/CD** runs on worktree branches

## Troubleshooting

### Common Issues

1. **Worktree already exists**
   ```powershell
   # Use -Force to replace
   ./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "task" -Force
   ```

2. **Cannot remove worktree**
   ```powershell
   # Force removal
   ./scripts/Configure-GitWorktrees.ps1 -Action Remove -TaskName "task" -Force
   ```

3. **Lost track of worktrees**
   ```powershell
   # List all worktrees
   git worktree list
   
   # Prune broken worktrees
   git worktree prune
   ```

## Example Claude Code Session

```markdown
User: I need you to fix all validation errors and update the documentation in parallel.

Claude: I'll set up two worktrees to work on these tasks simultaneously.

# Setting up worktree for validation fixes
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "fix-validation-errors"

# Setting up worktree for documentation
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "update-documentation"

Now I'll work on both tasks:

## Task 1: Validation Fixes
Working in: /workspaces/aitherzero-worktrees/fix-validation-errors
[Makes changes to fix validation errors]

## Task 2: Documentation Updates  
Working in: /workspaces/aitherzero-worktrees/update-documentation
[Updates documentation files]

Both tasks are complete. I'll create PRs for each:
- PR #1: From branch task/fix-validation-errors/20250111-152045
- PR #2: From branch task/update-documentation/20250111-152050
```

## Benefits for AI Development

1. **No Merge Conflicts**: Each task is isolated
2. **Clear Context**: Each worktree has specific instructions
3. **Parallel Processing**: Multiple tasks progress simultaneously
4. **Better Organization**: Changes grouped by purpose
5. **Easier Review**: PRs are focused on single tasks

## Advanced Usage

### Custom Branch Names

```powershell
# Use specific branch name
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "feature-x" -Branch "feature/authentication-module"
```

### Worktree Templates

Create templates for common tasks:

```powershell
# Create template worktree
./scripts/Configure-GitWorktrees.ps1 -Action Setup -TaskName "template-bugfix" -Branch "template/bugfix"

# Copy for new bugfix
cp -r /workspaces/aitherzero-worktrees/template-bugfix /workspaces/aitherzero-worktrees/bugfix-123
```

### Integration with PatchManager

```powershell
# In worktree directory
cd /workspaces/aitherzero-worktrees/validation-fixes

# Use PatchManager normally
Import-Module ./aither-core/modules/PatchManager -Force
New-Feature -Description "Fix validation errors" -Changes {
    # Make changes
}
```

## Summary

Git worktrees enable Claude Code to work like a team of developers, each focused on their specific task without interfering with others. This approach ensures clean, organized development with proper isolation between different work streams.