---
applyTo: "library/automation-scripts/**/*.ps1"
---

# Automation Script Requirements

When creating or modifying automation scripts in AitherZero's number-based orchestration system (0000-9999), follow these guidelines:

## Script Numbering System

Scripts follow numeric ranges for systematic execution:
- **0000-0099**: Environment preparation (PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)
- **0200-0299**: Development tools (Git, Node, Python, Docker, VS Code)
- **0400-0499**: Testing & validation
- **0500-0599**: Reporting & metrics
- **0700-0799**: Git automation & AI tools
- **0800-0899**: Issue management
- **9000-9999**: Maintenance & cleanup

## HARD REQUIREMENT: Single-Purpose Scripts with Parameters

**NEVER create duplicate or "alternative" versions of automation scripts!**

❌ **WRONG:**
```
0404_Run-PSScriptAnalyzer.ps1
0404_Run-PSScriptAnalyzer-Fast.ps1     ❌ NEVER DO THIS
0404_Run-PSScriptAnalyzer-Parallel.ps1 ❌ NEVER DO THIS
```

✅ **CORRECT:**
```powershell
# ONE script with parameters for behavior modification
./0404_Run-PSScriptAnalyzer.ps1                    # Full scan
./0404_Run-PSScriptAnalyzer.ps1 -Fast              # Fast mode
./0404_Run-PSScriptAnalyzer.ps1 -Severity Error   # Errors only
```

**Core Principles:**
1. **One Script = One Job** - Each numbered script does ONE thing well
2. **Parameters NOT Duplicates** - Modify behavior with parameters
3. **Different Numbers = Different Functions** - Use different numbers for truly different purposes
4. **Orchestration for Workflows** - Use playbooks for complex workflows

## Script Structure

### Required Header

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Brief description of script purpose
.DESCRIPTION
    Detailed description with exit codes
    
    Exit Codes:
    0   - Success
    1   - Failure
    2   - Execution error
    
.NOTES
    Stage: <Testing|Infrastructure|Development|etc>
    Order: <script-number>
    Dependencies: <comma-separated list of script numbers>
    Tags: <comma-separated tags>
    AllowParallel: <true|false>
#>
```

### Standard Parameters

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path,
    [switch]$DryRun,
    [switch]$PassThru,
    [switch]$CI,
    [switch]$UseCache = $false,
    [switch]$ForceRun = $false
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
```

## HARD REQUIREMENT: Use ScriptUtilities Module

**NEVER duplicate common helper functions in automation scripts!**

❌ **WRONG - Defining helper functions in each script:**
```powershell
function Write-ScriptLog {
    # 40 lines of duplicate logging code...
}
```

✅ **CORRECT - Import ScriptUtilities module:**
```powershell
# Import ScriptUtilities for common functions
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1") -Force

# Now use the functions directly
Write-ScriptLog "Starting..." -Level 'Information'
$token = Get-GitHubToken -ErrorAction SilentlyContinue
```

**Available Functions in ScriptUtilities:**
- `Write-ScriptLog` - Centralized logging
- `Get-GitHubToken` - GitHub authentication
- `Test-Prerequisites` - Validate dependencies
- `Get-ProjectRoot` - Get repository root
- `Get-ScriptMetadata` - Parse script metadata
- `Test-CommandAvailable` - Check if command exists
- `Invoke-WithRetry` - Retry failed operations

## Script Metadata Comments

Scripts MUST include metadata in the `.NOTES` section for orchestration:

```powershell
.NOTES
    Stage: Testing
    Order: 0402
    Dependencies: 0400
    Tags: testing, unit-tests, pester
    AllowParallel: false
```

**Fields:**
- **Stage** - Execution stage (Testing, Infrastructure, Development, etc.)
- **Order** - Script number for sequencing
- **Dependencies** - Comma-separated list of required script numbers
- **Tags** - Searchable keywords
- **AllowParallel** - Can this script run in parallel? (true/false)

## Environment Detection

Scripts should adapt to CI vs local execution:

```powershell
# Detect CI environment
$isCI = $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'

# CI-specific behavior
if ($isCI) {
    # Non-interactive, automated behavior
} else {
    # Interactive, developer-friendly behavior
}
```

## Terminal Compatibility

Set TERM environment variable for CI:

```powershell
# Ensure TERM is set for terminal operations (required in CI)
if (-not $env:TERM) {
    $env:TERM = 'xterm-256color'
}
```

## Configuration Integration

Use configuration system for defaults:

```powershell
# Import Configuration module
$configModule = Join-Path $projectRoot "aithercore/configuration/Configuration.psm1"
if (Test-Path $configModule) {
    Import-Module $configModule -Force -ErrorAction SilentlyContinue
}

# Apply configuration defaults
if (-not $PSBoundParameters.ContainsKey('CoverageThreshold')) {
    if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
        $CoverageThreshold = Get-ConfiguredValue -Name 'CoverageThreshold' -Section 'Testing' -Default 80
    } else {
        $CoverageThreshold = 80
    }
}
```

## Error Handling

Use try/catch with proper logging:

```powershell
try {
    Write-ScriptLog "Starting operation..." -Source "0402_MyScript"
    
    # Script logic here
    
    Write-ScriptLog "Operation completed successfully" -Level 'Success'
    exit 0
}
catch {
    Write-ScriptLog "Operation failed: $_" -Level 'Error' -Source "0402_MyScript"
    exit 1
}
```

## WhatIf/DryRun Support

Support ShouldProcess for safe testing:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param([switch]$DryRun)

if ($PSCmdlet.ShouldProcess($target, $action)) {
    # Perform operation
}

# Or manual DryRun check
if ($DryRun) {
    Write-Host "DRY RUN: Would perform operation"
    return
}
```

## Output and Exit Codes

Use consistent exit codes:

```powershell
# Success
exit 0

# Failure (operation failed)
exit 1

# Error (execution error, exception)
exit 2

# Restart required (Windows-specific)
exit 3010
```

## GitHub Issue Creation Pattern

**CRITICAL:** Don't create GitHub issues in CI - let workflows handle it:

```powershell
if ($shouldCreateIssues -and ($overallStatus -eq 'Failed')) {
    # In GitHub Actions/CI, skip issue creation - workflow handles it
    if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
        Write-Host "Issue creation skipped - running in CI environment"
    } else {
        # Local execution - try to use gh CLI
        if (Test-GitHubAuthentication) {
            # Create issues with gh CLI...
        }
    }
}
```

## Cross-Platform Paths

Handle paths correctly across platforms:

```powershell
# Use Join-Path for cross-platform paths
$configPath = Join-Path $projectRoot "config.psd1"

# Check platform
if ($IsWindows) {
    $tempPath = "C:\temp"
} elseif ($IsLinux) {
    $tempPath = "/tmp"
} elseif ($IsMacOS) {
    $tempPath = "/tmp"
}
```

## Logging Best Practices

1. **Log at start** - "Starting operation..."
2. **Log progress** - "Processing file X of Y..."
3. **Log completion** - "Operation completed successfully"
4. **Log errors** - "Operation failed: error details"
5. **Use appropriate levels** - Information, Warning, Error, Success

## Testing Requirements

Every automation script must have:
1. Unit test in `/tests/unit/automation-scripts/<range>/`
2. Integration test if applicable
3. Validation test for metadata
4. WhatIf execution test

Tests are auto-generated by `0950_Generate-AllTests.ps1` - do NOT write tests manually!

## Example Script Template

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Brief script description
.DESCRIPTION
    Detailed description
    
    Exit Codes:
    0   - Success
    1   - Failure
    
.NOTES
    Stage: Testing
    Order: 0402
    Dependencies: 0400
    Tags: testing, example
    AllowParallel: true
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = "default/path",
    [switch]$DryRun,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure TERM is set for terminal operations
if (-not $env:TERM) {
    $env:TERM = 'xterm-256color'
}

# Import ScriptUtilities
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1") -Force

try {
    Write-ScriptLog "Starting operation..." -Source "0402_Example"
    
    # Script logic here
    
    Write-ScriptLog "Operation completed successfully" -Level 'Success'
    exit 0
}
catch {
    Write-ScriptLog "Operation failed: $_" -Level 'Error'
    exit 1
}
```

## Automatic Test Generation

After creating a new script:
1. Run `./library/automation-scripts/0950_Generate-AllTests.ps1 -Mode Quick`
2. Or let CI auto-generate tests via `auto-generate-tests.yml` workflow
3. Validate with `./library/automation-scripts/0426_Validate-TestScriptSync.ps1`

## Reference

- See `.github/copilot-instructions.md` for comprehensive architecture
- See `docs/STYLE-GUIDE.md` for coding standards
- See `/tests/TEST-BEST-PRACTICES.md` for testing guidelines
