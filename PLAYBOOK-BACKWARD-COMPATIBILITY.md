# Orchestration Playbook Backward Compatibility

**Version**: 3.0  
**Date**: 2025-11-05  
**Status**: ✅ Fully Backward Compatible

## Overview

The orchestration engine supports three playbook formats with full backward compatibility:

- **v1.0** - Legacy format (simple structure)
- **v2.0** - Stages-based format (current JSON playbooks)
- **v3.0** - Jobs-based format (GitHub Actions workflows)

**All existing JSON playbooks continue to work without modification.**

## Playbook Format Support

### v1.0 - Legacy Format (Deprecated)

Simple structure with basic fields:

```json
{
  "name": "my-playbook",
  "description": "Description",
  "sequence": ["0001", "0002"],
  "variables": {}
}
```

**Status**: ✅ Supported (read-only)  
**Use Case**: Legacy playbooks from v1.x releases

### v2.0 - Stages-Based Format (Current)

Enhanced structure with metadata and stages:

```json
{
  "metadata": {
    "name": "ci-pr-validation",
    "description": "Validate pull requests",
    "version": "1.0.0",
    "category": "operations"
  },
  "requirements": {
    "minimumPowerShellVersion": "7.0"
  },
  "orchestration": {
    "defaultVariables": {},
    "profiles": {},
    "stages": [
      {
        "name": "Syntax Validation",
        "sequences": ["0407"],
        "variables": {}
      }
    ]
  }
}
```

**Status**: ✅ Fully Supported (primary format)  
**Use Case**: All current JSON playbooks in `/orchestration/playbooks/`  
**Backward Compatibility**: 100% - No changes needed to existing playbooks

### v3.0 - Jobs-Based Format (New)

GitHub Actions-compatible structure with jobs and steps:

```json
{
  "metadata": {
    "name": "test-workflow",
    "description": "Converted from GitHub Actions"
  },
  "orchestration": {
    "jobs": {
      "test": {
        "name": "Run Tests",
        "steps": [
          {
            "name": "Run unit tests",
            "run": "0402"
          }
        ]
      }
    }
  }
}
```

**Status**: ✅ Supported (auto-converted to v2.0)  
**Use Case**: Converted GitHub Actions workflows  
**Backward Compatibility**: 100% - Automatically converted to stages format for execution

## Automatic Conversion

The `ConvertTo-StandardPlaybookFormat` function automatically detects and converts all formats:

```powershell
# Loads any format transparently
$playbook = Get-OrchestrationPlaybook -Name "any-playbook"

# Format is detected and converted automatically:
# - v1.0 → Internal format
# - v2.0 → Internal format (no conversion needed)
# - v3.0 → Converted to v2.0 stages, then internal format
```

### Conversion Logic

```
┌─────────────────────────────────────────────────────┐
│                Load Playbook JSON                    │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
          ┌───────────────┐
          │ Detect Format │
          └───────┬───────┘
                  │
     ┌────────────┼────────────┐
     │            │            │
     ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│ v1.0    │  │ v2.0    │  │ v3.0    │
│ Legacy  │  │ Stages  │  │ Jobs    │
└────┬────┘  └────┬────┘  └────┬────┘
     │            │            │
     │            │            │ Convert jobs
     │            │            │ to stages
     │            │            ▼
     │            │       ┌─────────┐
     │            │       │ v2.0    │
     │            │       │ Stages  │
     │            │       └────┬────┘
     │            │            │
     └────────────┴────────────┘
                  │
                  ▼
     ┌─────────────────────────┐
     │  Internal Standard      │
     │  Format for Execution   │
     └─────────────────────────┘
```

## Migration Path

### From v2.0 to v3.0 (Optional)

If you want to use the new jobs-based format:

```powershell
# Your existing v2.0 playbooks work as-is
# No migration needed

# Optional: Convert to v3.0 for GitHub Actions compatibility
# (Not implemented yet - v2.0 is the recommended format)
```

### From GitHub Actions to AitherZero

Use the workflow parser to convert:

```powershell
# Convert GitHub Actions workflow
./automation-scripts/0964_Run-GitHubWorkflow.ps1 `
    -WorkflowPath ".github/workflows/test.yml" `
    -ConvertOnly

# Result: v3.0 jobs-based playbook
# Automatically compatible with orchestration engine
```

## Compatibility Guarantees

### What's Guaranteed

1. ✅ **All existing v2.0 JSON playbooks work without modification**
2. ✅ **v1.0 playbooks continue to work (read-only)**
3. ✅ **v3.0 playbooks auto-convert to v2.0 for execution**
4. ✅ **No breaking changes to existing playbook APIs**
5. ✅ **All new features are opt-in**

### What's Not Guaranteed

1. ❌ Writing v3.0 format directly (use workflow parser)
2. ❌ Direct execution of v3.0 jobs (converted to stages first)
3. ❌ v1.0 format for new playbooks (use v2.0)

## Testing Backward Compatibility

### Automated Tests

Run the compatibility test suite:

```powershell
# Test all formats
./automation-scripts/0965_Test-PlaybookCompatibility.ps1

# Test specific format
./automation-scripts/0965_Test-PlaybookCompatibility.ps1 -Format v2.0
```

### Manual Verification

```powershell
# Test v2.0 playbook (existing format)
Invoke-OrchestrationSequence -LoadPlaybook "ci-pr-validation" -DryRun

# Should load and execute without errors
# Output should show: "Loading v2.0 stages-based playbook"
```

## Examples

### Example 1: Existing v2.0 Playbook (No Changes)

```json
// File: orchestration/playbooks/core/operations/ci-pr-validation.json
// This file works exactly as before - no modifications needed
{
  "metadata": {
    "name": "ci-pr-validation"
  },
  "orchestration": {
    "stages": [
      {
        "name": "Syntax Validation",
        "sequences": ["0407"]
      }
    ]
  }
}
```

Usage remains the same:

```powershell
# Works exactly as before
Invoke-OrchestrationSequence -LoadPlaybook "ci-pr-validation"
```

### Example 2: New v3.0 Playbook (Auto-Converted)

```json
// File: orchestration/playbooks/converted/test-workflow.json
// Converted from GitHub Actions workflow
{
  "metadata": {
    "name": "test-workflow"
  },
  "orchestration": {
    "jobs": {
      "test": {
        "name": "Run Tests",
        "steps": [
          { "name": "Unit tests", "run": "0402" }
        ]
      }
    }
  }
}
```

Usage is identical:

```powershell
# Automatically converted to stages format
Invoke-OrchestrationSequence -LoadPlaybook "test-workflow"
# Output: "Loading v3.0 jobs-based playbook: test-workflow"
```

## Common Questions

### Q: Do I need to update my existing playbooks?

**A: No.** All existing v2.0 JSON playbooks work without modification.

### Q: Can I mix v2.0 and v3.0 playbooks?

**A: Yes.** The orchestration engine handles both transparently.

### Q: Which format should I use for new playbooks?

**A: v2.0 stages-based format** is recommended for manual playbook creation. v3.0 is primarily for converted GitHub Actions workflows.

### Q: Will v2.0 be deprecated?

**A: No.** v2.0 is the primary playbook format and will remain fully supported.

### Q: Can I include v3.0 playbooks from v2.0 playbooks?

**A: Yes.** All formats are compatible with the reusable workflow system (when implemented).

## Version History

| Version | Release Date | Format | Status |
|---------|-------------|--------|--------|
| v1.0 | 2024-Q1 | Legacy | Deprecated (read-only) |
| v2.0 | 2024-Q3 | Stages-based | Current (recommended) |
| v3.0 | 2025-Q1 | Jobs-based | New (auto-converted) |

## Implementation Details

### Format Detection Logic

```powershell
# From ConvertTo-StandardPlaybookFormat function

# v3.0 detection
if ($Playbook.orchestration.ContainsKey('jobs')) {
    # Load as v3.0, convert to v2.0 stages
}

# v2.0 detection
elseif ($Playbook.ContainsKey('metadata') -and 
        $Playbook.ContainsKey('orchestration')) {
    # Load as v2.0 stages
}

# v1.0 detection (fallback)
else {
    # Load as legacy v1.0
}
```

### Jobs to Stages Conversion

```powershell
# v3.0 job
{
  "jobs": {
    "test": {
      "steps": [
        { "run": "0402" },
        { "run": "0404" }
      ]
    }
  }
}

# Converts to v2.0 stage
{
  "stages": [
    {
      "name": "test",
      "sequences": ["0402", "0404"]
    }
  ]
}
```

## Support

- **Documentation**: This file (`PLAYBOOK-BACKWARD-COMPATIBILITY.md`)
- **Issues**: https://github.com/wizzense/AitherZero/issues
- **Examples**: All existing playbooks in `orchestration/playbooks/`

---

**Summary**: All existing JSON playbooks work without modification. New v3.0 format is automatically converted. Full backward compatibility guaranteed.

**Last Updated**: 2025-11-05  
**Version**: 3.0  
**Status**: Production Ready ✅
