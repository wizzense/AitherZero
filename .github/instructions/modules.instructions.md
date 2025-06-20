---
applyTo: "**/*.ps1"
description: "Project module usage guidelines and standards"
---

# Module Guidelines

Import project modules from `aither-core/modules` and use their exported commands instead of writing ad-hoc utilities.

## Core Project Modules

- **BackupManager** – clean up and consolidate backup files
- **DevEnvironment** – set up local or remote development environments
- **LabRunner** – run labs and orchestrate automation workflows
- **Logging** – write logs with `Write-CustomLog -Level 'INFO|WARN|ERROR|SUCCESS' -Message 'text'`
- **ParallelExecution** – execute tasks concurrently with runspaces
- **PatchManager** – manage patch downloads and installation with git-controlled workflows
- **ScriptManager** – maintain reusable script templates
- **TestingFramework** – run Pester tests consistently with project configuration
- **UnifiedMaintenance** – entry point for housekeeping tasks

## Module Import Pattern

Always import modules with force parameter:

```powershell
Import-Module './aither-core/modules/ModuleName' -Force
```

## Error Handling Standard

Use comprehensive try-catch blocks with logging:

```powershell
try {
    # Operation here
    Write-CustomLog -Level 'INFO' -Message "Operation started"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
    throw
}
```
