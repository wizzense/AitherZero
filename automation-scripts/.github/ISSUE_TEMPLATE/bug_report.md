---
name: Bug Report
about: Create a report to help us improve AitherZero
title: '[BUG] '
labels: bug, needs-triage
assignees: ''

---

## Bug Description
<!-- A clear and concise description of what the bug is -->

## System Context
**AitherZero Version:** <!-- Run: (Get-Content ./VERSION).Trim() -->
**PowerShell Version:** <!-- Run: $PSVersionTable.PSVersion -->
**Operating System:** <!-- Windows/Linux/macOS + version -->
**Module:** <!-- Which module/domain is affected? -->

## Steps To Reproduce
1. Initialize environment: `./Initialize-AitherModules.ps1`
2. Run command: <!-- Exact command that causes the issue -->
3. See error

## Expected Behavior
<!-- What you expected to happen -->

## Actual Behavior
<!-- What actually happened -->

## Error Output
```powershell
# Paste error messages here
# Include full stack trace if available
```

## Test Results
<!-- If running tests, include output from: -->
```powershell
seq 0402  # Unit test results
seq 0404  # PSScriptAnalyzer results
```

## Logs
<!-- Check ./logs/transcript-YYYY-MM-DD.log for relevant entries -->
```
# Relevant log entries
```

## Additional Context
- [ ] This worked in a previous version
- [ ] This is blocking my work
- [ ] I have checked existing issues
- [ ] I have updated to the latest version

## Possible Solution
<!-- Optional: Suggest a fix/reason for the bug -->

## Session Context for AI
<!-- For AI continuation, include: -->
**Git Branch:** <!-- git branch --show-current -->
**Modified Files:** <!-- git status --short -->
**Last Command:** <!-- Get-History -Count 1 -->