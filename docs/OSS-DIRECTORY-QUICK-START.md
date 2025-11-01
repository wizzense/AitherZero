# OSS Directory - Quick Start Guide

## Overview

The OSS Directory feature allows you to use AitherZero's tools and capabilities on external projects. This guide shows you how to get started.

## Installation

The OSS Directory feature is available in AitherZero v2.0+. No additional installation required.

## Quick Start

### 1. Initialize the Workspace

First, create the OSS workspace directory:

```powershell
az 0600
```

This creates an `oss-projects/` directory in your AitherZero installation.

### 2. List Projects

Check what projects are in your workspace:

```powershell
az 0603
```

### 3. Switch to a Project

Once you have projects (see below for creating them), switch context:

```powershell
az 0602 -Project "my-project"
```

### 4. Use AitherZero Tools

Now all AitherZero commands work on your external project:

```powershell
az 0402  # Run tests
az 0404  # PSScriptAnalyzer
az 0510  # Generate report
az 0701 -Type feature -Name "new-feature"  # Create branch
```

### 5. Reset Context

Return to AitherZero context:

```powershell
az 0602 -Reset
```

## Creating Projects (Future)

The following scripts are planned for Phase 2:

- `az 0601 -Name "my-project"` - Create new project
- `az 0601 -Clone "https://github.com/user/repo"` - Clone repository

## Current Implementation Status

### ✅ Phase 1 Complete (Proof of Concept)
- [x] Workspace Manager module
- [x] Workspace initialization (az 0600)
- [x] Context switching (az 0602)
- [x] Project listing (az 0603)
- [x] Basic workspace operations

### 🚧 Phase 2 Planned
- [ ] Project creation/cloning (az 0601)
- [ ] Project removal (az 0604)
- [ ] Project synchronization (az 0605)
- [ ] Integration with existing scripts
- [ ] Multi-framework support

## Architecture

```
AitherZero/
├── oss-projects/                    # OSS workspace
│   ├── README.md                    # Workspace documentation
│   └── [your-projects]/             # Your external projects
├── domains/
│   └── workspace/                   # Workspace management
│       └── WorkspaceManager.psm1    # Core module
└── automation-scripts/
    ├── 0600_Initialize-WorkspaceDirectory.ps1
    ├── 0602_Set-WorkspaceContext.ps1
    └── 0603_List-WorkspaceProjects.ps1
```

## Environment Variables

When a workspace project is active:

- `AITHERZERO_WORKSPACE_ACTIVE='true'`
- `AITHERZERO_WORKSPACE_PROJECT='project-name'`
- `AITHERZERO_WORKSPACE_ROOT='/path/to/oss-projects/project-name'`

## Next Steps

1. Review the [Feasibility Report](./OSS-DIRECTORY-FEASIBILITY.md) for complete details
2. Try initializing a workspace with `az 0600`
3. Provide feedback on the design and functionality
4. Phase 2 implementation will add project creation and full integration

## Questions?

See the [Feasibility Report](./OSS-DIRECTORY-FEASIBILITY.md) for:
- Detailed architecture
- Implementation phases
- Technical considerations
- Usage examples

---

**Version**: 1.0 (Proof of Concept)  
**Last Updated**: 2025-11-01
