# Development Domain

This domain contains modules for development automation, including Git operations, issue tracking, and pull request management.

## Modules

### GitAutomation.psm1
Core Git operations and workflow automation:
- Branch management
- Commit automation
- Repository synchronization
- Git configuration helpers

### IssueTracker.psm1
GitHub issue integration and management:
- Create and update issues
- Link commits to issues
- Auto-close issues on merge
- Issue templates and labels

### PullRequestManager.psm1
Pull request workflow automation:
- Create PRs with templates
- Auto-merge capabilities
- PR consolidation
- Review request automation

## Key Features

- **Cross-Platform**: Works on Windows, Linux, and macOS
- **GitHub CLI Integration**: Uses `gh` for GitHub operations
- **Audit Trail**: All operations logged for compliance
- **AI-Friendly**: Clear function names and comprehensive help

## Usage Examples

```powershell
# Git operations
New-GitBranch -Name "feature/new-feature" -From "main"
Invoke-GitCommit -Message "feat: Add new feature" -AutoStage

# Issue management
New-GitHubIssue -Title "Bug: Fix login" -Body "Details..." -Labels @("bug")
Close-GitHubIssue -Number 123 -Comment "Fixed in PR #124"

# Pull requests
New-PullRequest -Title "Feature: Add dashboard" -Draft
Enable-AutoMerge -PRNumber 124 -MergeMethod "squash"
```