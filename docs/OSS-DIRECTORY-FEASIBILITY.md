# OSS Directory Support - Feasibility Investigation

**Date**: November 1, 2025  
**Status**: Investigation Complete  
**Outcome**: ✅ FEASIBLE with Recommended Approach

## Executive Summary

Creating an "OSS Directory" (Open Source Support) within AitherZero to manage external projects is **highly feasible** and aligns well with the existing architecture. The platform's configuration-driven design, number-based orchestration system, and modular domain structure provide an excellent foundation for this capability.

### Recommended Approach
Implement a **Workspace Context System** that extends AitherZero's configuration management to support multiple project contexts while maintaining the existing architecture and tooling.

---

## Problem Statement

**User Request**: Enable AitherZero to:
1. Clone/fork external repositories into a dedicated OSS directory
2. Create new projects in that directory
3. Use AitherZero's capabilities (testing, Git automation, validation, etc.) on external projects
4. Maintain a "logical container" that adapts to each project's specific needs
5. Keep external projects separate from AitherZero's own codebase

**Key Requirements**:
- Non-invasive to AitherZero's core functionality
- Support multiple concurrent projects
- Adapt to different project structures and technologies
- Leverage existing automation scripts (0000-9999)
- Maintain configuration-driven approach

---

## Current Architecture Analysis

### Strengths Supporting OSS Directory

#### 1. **Configuration-Driven Design**
- Single source of truth in `config.psd1`
- Hierarchical configuration with environment support
- Dynamic configuration loading with precedence rules
- Easy to extend with project-specific sections

#### 2. **Number-Based Orchestration (0000-9999)**
- Systematic script execution model
- Scripts already parameterized and reusable
- Clear categorization by function (0000-0099: setup, 0200-0299: dev tools, etc.)
- Scripts accept configuration objects and path parameters

#### 3. **Modular Domain Structure**
- 12 independent domains (`/domains/`)
- Clear separation of concerns
- Domains already support path-based operations
- Git automation, testing, reporting all modular

#### 4. **Environment Variables**
- `$env:AITHERZERO_ROOT` - Root installation directory
- `$env:AITHERZERO_INITIALIZED` - Initialization state
- Easy to extend with `$env:AITHERZERO_WORKSPACE` or similar

#### 5. **Cross-Platform Support**
- Already handles Windows, Linux, macOS
- Path resolution abstraction in place
- Platform-specific feature detection

### Current Limitations

1. **Single Project Context**: Currently assumes operations target AitherZero itself
2. **Hardcoded Paths**: Some scripts use `$PSScriptRoot` or `$projectRoot` without context awareness
3. **No Workspace Concept**: No existing abstraction for "current working project"
4. **Configuration Scope**: Configuration is global, not per-project

---

## Proposed Solution: Workspace Context System

### Architecture Overview

```
AitherZero/                          # AitherZero installation
├── oss-projects/                    # OSS Directory (new)
│   ├── .workspace-config.psd1       # Workspace metadata
│   ├── project-one/                 # External project 1
│   │   ├── .aitherzero/             # Project-specific config
│   │   │   ├── config.psd1          # Project overrides
│   │   │   ├── scripts/             # Custom scripts
│   │   │   └── workspace.psd1       # Workspace metadata
│   │   └── [project files...]
│   └── project-two/                 # External project 2
│       └── .aitherzero/
├── domains/                         # AitherZero domains (existing)
│   ├── workspace/                   # NEW: Workspace management
│   │   ├── WorkspaceManager.psm1
│   │   └── ProjectContext.psm1
│   └── [other domains...]
├── automation-scripts/              # Existing scripts
└── config.psd1                      # Global config
```

### Core Components

#### 1. **Workspace Manager Module** (`domains/workspace/WorkspaceManager.psm1`)

**Key Functions**:
- `New-WorkspaceProject` - Clone/fork/create projects in OSS directory
- `Set-WorkspaceContext` - Switch between projects
- `Get-WorkspaceContext` - Get current workspace information
- `Get-WorkspaceProjects` - List all OSS projects
- `Initialize-WorkspaceProject` - Set up .aitherzero directory
- `Remove-WorkspaceProject` - Clean up project

**Responsibilities**:
- Manage `oss-projects/` directory
- Track active workspace context
- Merge global and project-specific configurations
- Validate project structures

#### 2. **Project Context Module** (`domains/workspace/ProjectContext.psm1`)

**Key Functions**:
- `Get-ProjectRoot` - Resolve current project root
- `Get-ProjectConfig` - Get merged configuration
- `Invoke-InProjectContext` - Run command in project context
- `Test-IsWorkspaceProject` - Check if in workspace project

**Responsibilities**:
- Context-aware path resolution
- Configuration inheritance and overrides
- Execution context management

#### 3. **Configuration Extensions**

Add to `config.psd1`:
```powershell
Workspace = @{
    Enabled = $true
    Directory = './oss-projects'  # Relative to AITHERZERO_ROOT
    DefaultSettings = @{
        Git = @{
            AutoCommit = $false
            DefaultBranch = 'main'
        }
        Testing = @{
            Framework = 'Auto-Detect'  # Pester, Jest, pytest, etc.
            CoverageThreshold = 80
        }
        Automation = @{
            InheritScripts = $true  # Use AitherZero's scripts
            CustomScripts = $true   # Allow project-specific scripts
        }
    }
    ProjectDefaults = @{
        # Template for new projects
        Structure = 'Standard'
        License = 'MIT'
        GitIgnore = $true
    }
}
```

#### 4. **Environment Variable Extensions**

```powershell
$env:AITHERZERO_WORKSPACE_ACTIVE = 'true'|'false'
$env:AITHERZERO_WORKSPACE_PROJECT = 'project-name'
$env:AITHERZERO_WORKSPACE_ROOT = '/path/to/oss-projects/project-name'
```

#### 5. **New Automation Scripts**

Add workspace management scripts in the **0600-0699 range** (currently unused):

- `0600_Initialize-WorkspaceDirectory.ps1` - Set up OSS directory
- `0601_New-WorkspaceProject.ps1` - Create/clone project
- `0602_Set-WorkspaceContext.ps1` - Switch active project
- `0603_List-WorkspaceProjects.ps1` - Show all projects
- `0604_Remove-WorkspaceProject.ps1` - Clean up project
- `0605_Sync-WorkspaceProject.ps1` - Update from upstream
- `0610_Run-InWorkspace.ps1` - Execute command in project context
- `0620_Validate-WorkspaceProject.ps1` - Check project health

### Configuration Inheritance Model

```
Priority (highest to lowest):
1. Command-line parameters
2. Project-specific config (.aitherzero/config.psd1)
3. Workspace defaults (config.psd1 -> Workspace.DefaultSettings)
4. Global AitherZero config (config.psd1)
5. Module defaults
```

### Usage Examples

#### Example 1: Create New OSS Project
```powershell
# Initialize OSS directory (one-time)
az 0600

# Create new project
az 0601 -Name "my-open-source-lib" -Type "PowerShell" -License "MIT"

# Switch to project context
az 0602 -Project "my-open-source-lib"

# Now all AitherZero commands work in project context
az 0402  # Run tests (uses project's tests)
az 0404  # PSScriptAnalyzer (on project code)
az 0701 -Type feature -Name "new-feature"  # Git branch
az 0702 -Type feat -Message "Add feature"  # Commit
```

#### Example 2: Clone External Repository
```powershell
# Clone external repo into workspace
az 0601 -Clone "https://github.com/user/external-project"

# Initialize AitherZero support
az 0602 -Project "external-project" -Initialize

# Use AitherZero tools on external project
az 0407  # Syntax validation
az 0510  # Generate project report
az 0703 -Title "Fix issue"  # Create PR
```

#### Example 3: Multi-Project Workflow
```powershell
# List all workspace projects
az 0603

# Switch between projects
az 0602 -Project "project-one"
az 0402  # Test project-one

az 0602 -Project "project-two"
az 0402  # Test project-two

# Return to AitherZero context
az 0602 -Reset
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1)
- [ ] Create `domains/workspace/` directory
- [ ] Implement `WorkspaceManager.psm1`
- [ ] Implement `ProjectContext.psm1`
- [ ] Add Workspace section to `config.psd1`
- [ ] Create `oss-projects/.workspace-config.psd1` template
- [ ] Update `AitherZero.psm1` to load workspace modules

**Deliverables**: Core modules and configuration

### Phase 2: Basic Scripts (Week 1-2)
- [ ] `0600_Initialize-WorkspaceDirectory.ps1`
- [ ] `0601_New-WorkspaceProject.ps1`
- [ ] `0602_Set-WorkspaceContext.ps1`
- [ ] `0603_List-WorkspaceProjects.ps1`
- [ ] Update existing scripts for context awareness

**Deliverables**: Basic workspace operations

### Phase 3: Integration (Week 2)
- [ ] Update `Get-ProjectRoot` calls to be context-aware
- [ ] Add workspace detection to automation scripts
- [ ] Update `Start-AitherZero.ps1` menu for workspace mode
- [ ] Create `.aitherzero/` directory template

**Deliverables**: Full integration with existing tools

### Phase 4: Advanced Features (Week 3)
- [ ] `0604_Remove-WorkspaceProject.ps1`
- [ ] `0605_Sync-WorkspaceProject.ps1`
- [ ] `0610_Run-InWorkspace.ps1`
- [ ] `0620_Validate-WorkspaceProject.ps1`
- [ ] Multi-project orchestration
- [ ] Project templates system

**Deliverables**: Advanced management features

### Phase 5: Testing & Documentation (Week 3-4)
- [ ] Unit tests for workspace modules
- [ ] Integration tests for workflows
- [ ] User documentation
- [ ] Migration guide
- [ ] Example projects

**Deliverables**: Complete, tested, documented feature

---

## Technical Considerations

### 1. **Backward Compatibility**
- All existing functionality remains unchanged
- Workspace features are opt-in via `Workspace.Enabled`
- Default behavior (no workspace) works as before
- No breaking changes to existing scripts or APIs

### 2. **Performance**
- Minimal overhead when workspace not active
- Lazy loading of workspace modules
- Configuration caching per project
- No impact on non-workspace operations

### 3. **Security**
- Projects isolated in `oss-projects/` directory
- No automatic execution of external code
- Git operations require explicit confirmation
- Workspace config validation before use

### 4. **Cross-Platform**
- Path handling already cross-platform
- Use existing platform detection
- Test on Windows, Linux, macOS

### 5. **Technology Detection**
- Auto-detect project type (PowerShell, Node.js, Python, Go, etc.)
- Adapt testing commands based on project structure
- Support multiple test frameworks
- Fallback to manual configuration

---

## Alternative Approaches Considered

### Alternative 1: Separate Installation Per Project
**Approach**: Install AitherZero in each external project  
**Pros**: Complete isolation, simpler context management  
**Cons**: Duplication, maintenance burden, version conflicts  
**Verdict**: ❌ Not recommended - too much overhead

### Alternative 2: Global Context Variable Only
**Approach**: Just set `$env:WORKING_PROJECT` and update scripts  
**Pros**: Minimal changes, simple implementation  
**Cons**: No configuration inheritance, no management tools, error-prone  
**Verdict**: ❌ Too simplistic - doesn't meet requirements

### Alternative 3: Container-Based Isolation
**Approach**: Run each project in Docker container with AitherZero  
**Pros**: True isolation, repeatable environments  
**Cons**: Overhead, complexity, limited integration  
**Verdict**: ⚠️ Possible future enhancement, not primary solution

---

## Benefits of Recommended Approach

### For Users
1. **Unified Tooling**: Use AitherZero capabilities across all projects
2. **Context Switching**: Easy navigation between projects
3. **Configuration Reuse**: Inherit settings, customize as needed
4. **Familiar Interface**: Same commands, just different context
5. **Project Isolation**: Each project maintains independence

### For AitherZero
1. **Extends Value**: Makes platform useful beyond self
2. **Dogfooding**: Tests tools on real external projects
3. **Community Growth**: Attracts users managing multiple projects
4. **Backward Compatible**: Existing functionality unaffected
5. **Modular Growth**: Foundation for future features

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Configuration conflicts | Medium | Medium | Clear precedence rules, validation |
| Script compatibility | High | Low | Gradual rollout, testing, fallbacks |
| User confusion | Medium | Medium | Documentation, clear error messages |
| Path resolution bugs | High | Medium | Comprehensive testing, validation |
| Performance degradation | Low | Low | Lazy loading, caching, profiling |

---

## Success Criteria

1. ✅ Clone external repository into `oss-projects/`
2. ✅ Switch context to external project
3. ✅ Run AitherZero tests on external code
4. ✅ Create Git branches/commits/PRs in external project
5. ✅ Generate reports for external project
6. ✅ No impact on existing AitherZero functionality
7. ✅ < 5% performance overhead when workspace active
8. ✅ Cross-platform compatible
9. ✅ Clear documentation and examples

---

## Conclusion

The OSS Directory feature is **highly feasible** and aligns perfectly with AitherZero's architecture. The recommended Workspace Context System approach:

- ✅ Minimal changes to existing code
- ✅ Leverages existing infrastructure
- ✅ Provides powerful, flexible capability
- ✅ Maintains backward compatibility
- ✅ Sets foundation for future enhancements

**Recommendation**: **PROCEED** with implementation using the phased approach outlined above.

---

## Next Steps

1. **Review & Approval**: Stakeholder review of this document
2. **Detailed Design**: Create technical specifications for Phase 1
3. **Prototype**: Build minimal working prototype of core modules
4. **Validation**: Test prototype with real external project
5. **Full Implementation**: Execute phases 1-5

---

## Appendix A: Example Project Structure

```
oss-projects/
├── .workspace-config.psd1          # Workspace metadata
├── external-powershell-module/     # PowerShell project
│   ├── .aitherzero/
│   │   ├── config.psd1             # Testing.Framework = 'Pester'
│   │   └── workspace.psd1
│   ├── src/
│   ├── tests/
│   └── README.md
├── nodejs-api-project/             # Node.js project
│   ├── .aitherzero/
│   │   ├── config.psd1             # Testing.Framework = 'Jest'
│   │   └── workspace.psd1
│   ├── src/
│   ├── tests/
│   └── package.json
└── python-ml-library/              # Python project
    ├── .aitherzero/
    │   ├── config.psd1             # Testing.Framework = 'pytest'
    │   └── workspace.psd1
    ├── src/
    ├── tests/
    └── requirements.txt
```

---

## Appendix B: Configuration Schema

### Project-Specific Config (`.aitherzero/config.psd1`)
```powershell
@{
    Project = @{
        Name = 'MyProject'
        Type = 'PowerShell' | 'Node.js' | 'Python' | 'Go' | 'Other'
        Version = '1.0.0'
        Description = 'Project description'
    }
    
    Testing = @{
        Framework = 'Pester' | 'Jest' | 'pytest' | 'go test' | 'Custom'
        TestPath = './tests'
        CoverageThreshold = 80
        CustomCommand = $null  # For non-standard frameworks
    }
    
    Git = @{
        DefaultBranch = 'main'
        CommitConvention = 'Conventional' | 'Custom'
        AutoPush = $false
    }
    
    Automation = @{
        InheritGlobalScripts = $true
        CustomScripts = @{
            'test' = './run-tests.sh'
            'lint' = './run-linter.sh'
        }
    }
    
    # Project-specific overrides
    Core = @{
        Profile = 'Developer'
    }
}
```

### Workspace Metadata (`.aitherzero/workspace.psd1`)
```powershell
@{
    Created = '2025-11-01T16:49:00Z'
    CreatedBy = 'AitherZero'
    Version = '1.0'
    Source = 'Clone' | 'Fork' | 'New'
    OriginalUrl = 'https://github.com/user/repo'
    LastSync = '2025-11-01T16:50:00Z'
    AitherZeroVersion = '2.0.0'
}
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-01  
**Author**: AitherZero Project Manager (David)
