#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    UserPromptSubmit hook to enforce PatchManager usage for git operations
    
.DESCRIPTION
    This hook intercepts user prompts in Claude Code and enforces the use of
    PatchManager instead of direct git commands. It provides helpful alternatives
    and checks for uncommitted changes.
    
.NOTES
    Part of AitherZero's Git workflow enforcement system
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string]$InputJson
)

# Read input from Claude Code
if (-not $InputJson) {
    $InputJson = $input | Out-String
}

try {
    $hookInput = $InputJson | ConvertFrom-Json
    $prompt = $hookInput.prompt
    
    # Patterns to detect direct git/gh commands
    $blockedPatterns = @{
        'git\s+commit' = @{
            Alternative = 'Import-Module ./aither-core/modules/PatchManager; New-QuickFix -Description "Your description" -Changes { }'
            Message = 'Use PatchManager for commits'
        }
        'git\s+push' = @{
            Alternative = 'Git push is handled automatically by PatchManager workflows'
            Message = 'PatchManager handles pushing automatically'
        }
        'gh\s+pr\s+create' = @{
            Alternative = 'Use New-Feature or New-Patch with -CreatePR flag'
            Message = 'Use PatchManager to create PRs'
        }
        'git\s+checkout\s+-b' = @{
            Alternative = 'Use New-Feature -Description "Feature description" -Changes { }'
            Message = 'PatchManager handles branch creation'
        }
        'git\s+merge' = @{
            Alternative = 'PRs should be merged through GitHub UI after approval'
            Message = 'Use GitHub PR workflow for merges'
        }
        'git\s+rebase' = @{
            Alternative = 'Use Sync-GitBranch -Force if needed'
            Message = 'PatchManager handles rebasing safely'
        }
    }
    
    # Check for uncommitted changes notification
    if ($prompt -match 'Stop hook feedback.*uncommitted changes') {
        # Extract the number of changes
        $changeCount = if ($prompt -match '(\d+)\s+uncommitted') { $matches[1] } else { 'uncommitted' }
        
        # Return a helpful response about using PatchManager
        $response = @{
            decision = "allow"
            context = @"

REMINDER: You have $changeCount uncommitted changes. Please commit using PatchManager:

```powershell
Import-Module ./aither-core/modules/PatchManager -Force
New-QuickFix -Description "Save work" -Changes { }
```

Or for feature work:
```powershell
New-Feature -Description "Add new functionality" -Changes { }
```
"@
        }
        
        $response | ConvertTo-Json -Depth 10
        return
    }
    
    # Check for blocked patterns
    foreach ($pattern in $blockedPatterns.Keys) {
        if ($prompt -match $pattern) {
            $info = $blockedPatterns[$pattern]
            
            $response = @{
                decision = "block"
                reason = @"
🚫 Direct git command detected: $($matches[0])

$($info.Message)

Please use PatchManager instead:
```powershell
$($info.Alternative)
```

PatchManager v3.0 provides atomic operations that prevent merge conflicts and ensure consistent workflow tracking.
"@
            }
            
            $response | ConvertTo-Json -Depth 10
            return
        }
    }
    
    # Check for general git status/log commands (these are allowed but we add context)
    if ($prompt -match 'git\s+(status|log|diff|branch)') {
        $response = @{
            decision = "allow"
            context = @"

ℹ️ Git read operations are allowed. For any changes, remember to use PatchManager:
- Quick fixes: New-QuickFix
- Features: New-Feature  
- Hotfixes: New-Hotfix
- Smart mode: New-Patch (auto-detects best approach)
"@
        }
        
        $response | ConvertTo-Json -Depth 10
        return
    }
    
    # Allow the prompt to proceed normally
    @{ decision = "allow" } | ConvertTo-Json -Depth 10
    
} catch {
    # On error, allow the prompt but log the issue
    @{
        decision = "allow"
        context = "Hook error: $($_.Exception.Message)"
    } | ConvertTo-Json -Depth 10
}