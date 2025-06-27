# Enhanced VS Code Tasks for Unified Testing Framework

This document outlines the new VS Code task configuration that integrates with the enhanced TestingFramework module for streamlined testing workflows.

## New Unified Testing Tasks

Replace the current VS Code tasks with these simplified, powerful alternatives:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "🚀 Unified Tests - Quick",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'Quick' -TestProfile 'Development' -GenerateReport"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🔥 Unified Tests - All Modules",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'All' -TestProfile 'Development' -Parallel -GenerateReport -VSCodeIntegration"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "⚡ Unified Tests - Specific Module",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'Modules' -Modules @('${input:moduleName}') -TestProfile 'Development' -GenerateReport"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🧪 Unified Tests - Unit Only",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'Unit' -TestProfile 'Development' -Parallel"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🔗 Unified Tests - Integration",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'Integration' -TestProfile 'Development' -GenerateReport"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "📊 Unified Tests - Performance",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'Performance' -TestProfile 'Development' -GenerateReport"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🔧 Unified Tests - CI Mode",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'All' -TestProfile 'CI' -Parallel -GenerateReport -VSCodeIntegration"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🎯 Unified Tests - Non-Interactive",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-UnifiedTestExecution -TestSuite 'NonInteractive' -TestProfile 'CI' -GenerateReport"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🔍 Test Discovery",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Get-DiscoveredModules | Format-Table Name, Path"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "📈 Test Report Viewer",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "$reportPath = Get-ChildItem './tests/results/unified/reports' -Filter '*.html' | Sort-Object LastWriteTime | Select-Object -Last 1; if ($reportPath) { Start-Process $reportPath.FullName } else { Write-Host 'No test reports found. Run tests first.' -ForegroundColor Yellow }"
            ],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "🧹 Clean Test Results",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Remove-Item -Path './tests/results/unified/*' -Recurse -Force -ErrorAction SilentlyContinue; Write-Host '🧹 Test results cleaned' -ForegroundColor Green"
            ],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": true
            },
            "problemMatcher": [],
            "options": {
                "cwd": "${workspaceFolder}"
            }
        }
    ],
    "inputs": [
        {
            "id": "moduleName",
            "description": "Module name to test",
            "default": "LabRunner",
            "type": "pickString",
            "options": [
                "LabRunner",
                "PatchManager",
                "ParallelExecution",
                "DevEnvironment",
                "ScriptManager",
                "Logging",
                "UnifiedMaintenance",
                "TestingFramework"
            ]
        }
    ]
}
```

## Task Categories and Usage

### 🚀 Quick Development Tasks
- **Unified Tests - Quick**: Fast unit tests for immediate feedback
- **Unified Tests - Unit Only**: Focus on unit tests only
- **Test Discovery**: See available modules and test paths

### 🔥 Comprehensive Testing
- **Unified Tests - All Modules**: Complete test suite with parallel execution
- **Unified Tests - Integration**: Focus on module interaction testing
- **Unified Tests - Performance**: Benchmark and performance validation

### ⚡ Targeted Testing
- **Unified Tests - Specific Module**: Test individual modules
- **Unified Tests - Non-Interactive**: CI/CD compatible testing

### 🔧 CI/CD Integration
- **Unified Tests - CI Mode**: Optimized for continuous integration
- **Clean Test Results**: Cleanup for fresh test runs

### 📊 Reporting and Analysis
- **Test Report Viewer**: Open latest HTML test report
- **Test Discovery**: Explore available test modules

## Benefits of the New Task Structure

### 1. Simplified Interface
- Reduced from 25+ tasks to 11 focused tasks
- Clear naming convention with emojis for visual identification
- Logical grouping by purpose and scope

### 2. Unified Backend
- All tasks use the same TestingFramework module
- Consistent configuration and behavior
- Centralized logging and reporting

### 3. Intelligent Configuration
- Profile-based settings (Development, CI, Production)
- Automatic parallel execution where appropriate
- Smart output handling and VS Code integration

### 4. Enhanced Developer Experience
- Real-time feedback through VS Code integration
- HTML reports with detailed analysis
- Consistent error handling and logging

### 5. Maintainability
- Single source of truth for test execution
- Easy to add new test types or configurations
- Reduced code duplication

## Migration Plan

### Phase 1: Add New Tasks (Parallel Operation)
1. Add new unified tasks alongside existing tasks
2. Validate functionality with existing test suites
3. Ensure backward compatibility

### Phase 2: Developer Adoption
1. Update documentation with new task recommendations
2. Provide training on new unified testing approach
3. Collect feedback and iterate

### Phase 3: Legacy Deprecation
1. Mark old tasks as deprecated
2. Migrate any custom workflows to new tasks
3. Remove legacy tasks after validation period

## GitHub Actions Integration

The new TestingFramework also supports seamless GitHub Actions integration:

```yaml
name: Unified Testing Workflow

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        test-suite: [Quick, Unit, Integration]

    steps:
    - uses: actions/checkout@v4

    - name: Setup PowerShell
      uses: microsoft/setup-powershell@v1

    - name: Run Unified Tests
      run: |
        Import-Module './aither-core/modules/TestingFramework' -Force
        Invoke-UnifiedTestExecution -TestSuite '${{ matrix.test-suite }}' -TestProfile 'CI' -GenerateReport -VSCodeIntegration

    - name: Upload Test Results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results-${{ matrix.os }}-${{ matrix.test-suite }}
        path: tests/results/unified/
```

## Developer Workflow Examples

### Daily Development
```bash
# Quick feedback loop
Ctrl+Shift+P → Tasks: Run Task → 🚀 Unified Tests - Quick

# Module-specific testing
Ctrl+Shift+P → Tasks: Run Task → ⚡ Unified Tests - Specific Module → [Select Module]

# View results
Ctrl+Shift+P → Tasks: Run Task → 📈 Test Report Viewer
```

### Pre-Commit Validation
```bash
# Full validation before commit
Ctrl+Shift+P → Tasks: Run Task → 🔗 Unified Tests - Integration

# Non-interactive validation
Ctrl+Shift+P → Tasks: Run Task → 🎯 Unified Tests - Non-Interactive
```

### Performance Analysis
```bash
# Performance benchmarking
Ctrl+Shift+P → Tasks: Run Task → 📊 Unified Tests - Performance

# CI mode testing
Ctrl+Shift+P → Tasks: Run Task → 🔧 Unified Tests - CI Mode
```

This new task structure provides a much more maintainable, powerful, and user-friendly testing experience while maintaining all existing functionality.
