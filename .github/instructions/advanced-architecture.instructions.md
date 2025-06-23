# Advanced Architecture & Development Patterns - GitHub Copilot Instructions

This file provides advanced guidance for GitHub Copilot when working with the Aitherium Infrastructure Automation project's sophisticated architecture and development patterns.

## 🏗️ Advanced Architecture Patterns

### Shared Utilities Integration

Always prioritize shared utilities over module-specific implementations:

```powershell
# ✅ ALWAYS use shared utilities
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# ✅ Correct import patterns by location:
# From modules/ModuleName/Public: . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
# From modules/ModuleName/Private: . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
# From tests/unit/modules: . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
# From aither-core root: . "$PSScriptRoot/shared/Find-ProjectRoot.ps1"

# ❌ NEVER implement custom path detection
$projectRoot = Split-Path $PSScriptRoot -Parent  # Don't do this
```

### Dynamic Repository Awareness

All code should be repository-agnostic and work across the fork chain:

```powershell
# ✅ Dynamic repository detection
$repoInfo = Get-GitRepositoryInfo
$targetRepo = "$($repoInfo.Owner)/$($repoInfo.Name)"

# ✅ Cross-fork operations
Invoke-PatchWorkflow -Description "Feature" -TargetFork "upstream" -CreatePR

# ❌ NEVER hardcode repository references
gh issue create --repo "wizzense/AitherZero"  # Don't hardcode
```

### Module Architecture Standards

Every module must follow the standardized pattern:

```powershell
# Module Structure (REQUIRED):
ModuleName/
├── ModuleName.psd1          # Manifest with proper exports
├── ModuleName.psm1          # Main module loader
├── Public/                  # Exported functions
│   └── *.ps1               # One function per file
├── Private/                 # Internal functions
│   └── *.ps1               # Helper functions
└── README.md               # Module documentation

# ✅ Correct function structure
function Public-Function {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParam,

        [Parameter()]
        [switch]$OptionalSwitch
    )

    begin {
        # Import shared utilities at function level
        . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($RequiredParam, "Operation")) {
                # Main logic here
                Write-CustomLog -Level 'INFO' -Message "Operation started"
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
            throw
        }
    }
}
```

### PatchManager v2.1 Integration Patterns

ALWAYS use PatchManager for Git operations:

```powershell
# ✅ PREFERRED: Single-step workflow
Invoke-PatchWorkflow -PatchDescription "Clear description of changes" -PatchOperation {
    # Your changes here - ANY working tree state is fine
    $content = Get-Content "file.ps1" -Raw
    $content = $content -replace "old", "new"
    Set-Content "file.ps1" -Value $content
} -CreatePR -TestCommands @("validation-command")

# ✅ Cross-fork contribution
Invoke-PatchWorkflow -PatchDescription "Improvement for upstream" -TargetFork "upstream" -CreatePR -PatchOperation {
    # Changes for upstream repository
}

# ✅ Emergency operations
Invoke-PatchWorkflow -PatchDescription "Critical fix" -Priority "Critical" -TargetFork "root" -CreatePR -PatchOperation {
    # Critical changes
}

# ❌ NEVER use manual Git commands for workflows
git add .; git commit -m "manual commit"  # Don't do this
```

## 🧪 Testing Integration Patterns

### Bulletproof Testing Standards

All code changes must include appropriate testing:

```powershell
# ✅ Standard test structure
BeforeAll {
    # ALWAYS import shared utilities in tests
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $script:ProjectRoot = Find-ProjectRoot

    # Import modules with force
    Import-Module "$script:ProjectRoot/aither-core/modules/ModuleName" -Force

    # Mock external dependencies
    Mock Write-CustomLog { }
    Mock Invoke-ExternalCommand { return @{ Success = $true } }
}

Describe "ModuleName Core Functionality" -Tags @('Unit', 'ModuleName', 'Fast') {
    Context "When function is called with valid parameters" {
        It "Should return expected result" {
            # Arrange - Act - Assert pattern
            $result = Invoke-ModuleFunction -ValidInput "test"
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
}

# ✅ Cross-fork testing for PatchManager features
Describe "Cross-Fork Operations" -Tags @('Integration', 'CrossFork', 'PatchManager') {
    BeforeEach {
        Mock Get-GitRepositoryInfo {
            return @{
                Owner = 'wizzense'; Name = 'AitherZero'; Type = 'Development'
                ForkChain = @(
                    @{ Name = 'origin'; Owner = 'wizzense'; Repo = 'AitherZero' },
                    @{ Name = 'upstream'; Owner = 'Aitherium'; Repo = 'AitherLabs' }
                )
            }
        }
    }
}
```

### Test Execution Patterns

```powershell
# ✅ Use bulletproof validation for comprehensive testing
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"    # 30 seconds
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard" # 2-5 minutes
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete" # 10-15 minutes

# ✅ Module-specific testing
Invoke-Pester -Path "tests/unit/modules/PatchManager" -Output Detailed

# ✅ Tag-based testing
Invoke-Pester -Path "tests/" -Tag "Fast" -ExcludeTag "Slow"
```

## 🎨 VS Code Integration Patterns

### Task Creation Standards

When creating new VS Code tasks, follow these patterns:

```json
{
    "label": "🎯 Category: Clear Description",
    "type": "shell",
    "command": "pwsh",
    "args": [
        "-Command",
        "Write-Host '🎯 Starting operation...' -ForegroundColor Cyan; # Your command here; Write-Host '✅ Operation completed!' -ForegroundColor Green"
    ],
    "group": "test|build",
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
```

### Task Categories and Naming

- **🚀** - Bulletproof validation and testing
- **🔧** - PatchManager and Git operations
- **⚡** - Testing and validation operations
- **🎯** - CoreRunner and automation
- **🧹** - Cleanup and maintenance
- **📚** - Documentation operations
- **🏗️** - Architecture and system validation
- **🌐** - Repository and cross-fork operations
- **🔍** - Debugging and diagnostics

## 🔧 Error Handling & Logging Patterns

### Comprehensive Error Handling

```powershell
# ✅ Standard error handling pattern
function Invoke-Operation {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$InputData)

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting $($MyInvocation.MyCommand.Name)"
    }

    process {
        try {
            # Validate inputs
            if (-not $InputData) {
                throw "InputData cannot be null or empty"
            }

            if ($PSCmdlet.ShouldProcess($InputData, "Process Data")) {
                # Main operation
                $result = Process-Data -Data $InputData
                Write-CustomLog -Level 'SUCCESS' -Message "Operation completed successfully"
                return $result
            }
        } catch {
            $errorDetails = @{
                Function = $MyInvocation.MyCommand.Name
                Parameters = $PSBoundParameters
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }

            Write-CustomLog -Level 'ERROR' -Message "Operation failed: $($_.Exception.Message)"
            Write-CustomLog -Level 'ERROR' -Message "Stack trace: $($_.ScriptStackTrace)"

            # Log detailed error for debugging
            $errorDetails | ConvertTo-Json -Depth 5 | Out-File "logs/error-details-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

            throw
        }
    }
}
```

### Logging Standards

```powershell
# ✅ Use consistent logging levels
Write-CustomLog -Level 'INFO' -Message "General information"
Write-CustomLog -Level 'WARN' -Message "Warning condition"
Write-CustomLog -Level 'ERROR' -Message "Error occurred"
Write-CustomLog -Level 'SUCCESS' -Message "Operation successful"

# ✅ Include context in log messages
Write-CustomLog -Level 'INFO' -Message "Processing file: $FilePath"
Write-CustomLog -Level 'INFO' -Message "Repository detected: $($repoInfo.GitHubRepo)"
```

## 🌟 Advanced Development Patterns

### Cross-Platform Compatibility

```powershell
# ✅ Always use cross-platform paths
$configPath = Join-Path $projectRoot "configs/app-config.json"
$modulePath = Join-Path $projectRoot "aither-core/modules/ModuleName"

# ✅ Platform-aware operations
if ($IsWindows) {
    # Windows-specific logic
} elseif ($IsLinux) {
    # Linux-specific logic
} elseif ($IsMacOS) {
    # macOS-specific logic
}

# ❌ NEVER use hardcoded paths
$configPath = "$projectRoot\configs\app-config.json"  # Windows-only
$configPath = "$projectRoot/configs/app-config.json"  # Better, but use Join-Path
```

### Performance Optimization Patterns

```powershell
# ✅ Use parallel execution for independent operations
Import-Module './aither-core/modules/ParallelExecution' -Force
$operations = @(
    { Process-File $file1 },
    { Process-File $file2 },
    { Process-File $file3 }
)
Invoke-ParallelOperation -Operations $operations -MaxParallelJobs 4

# ✅ Cache expensive operations
$script:CachedResults = @{}
function Get-ExpensiveData {
    param([string]$Key)

    if ($script:CachedResults.ContainsKey($Key)) {
        return $script:CachedResults[$Key]
    }

    $result = Invoke-ExpensiveOperation -Key $Key
    $script:CachedResults[$Key] = $result
    return $result
}
```

### Configuration Management Patterns

```powershell
# ✅ Dynamic configuration based on repository context
$repoInfo = Get-GitRepositoryInfo
$configPath = Join-Path $projectRoot "configs/dynamic-repo-config.json"

if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
} else {
    # Generate dynamic configuration
    Update-RepositoryDocumentation
    $config = Get-Content $configPath | ConvertFrom-Json
}

# Use repository-aware settings
$setting = $config.repositories.$($repoInfo.Type).settingName
```

## 🚀 Advanced PatchManager Patterns

### Complex Workflow Orchestration

```powershell
# ✅ Multi-step workflow with validation
Invoke-PatchWorkflow -PatchDescription "Complex refactoring with multiple validations" -PatchOperation {
    # Step 1: Update core functionality
    Update-CoreModule -EnhancedFeatures

    # Step 2: Update dependent modules
    Get-DependentModules | ForEach-Object { Update-Module $_ }

    # Step 3: Update documentation
    Update-ModuleDocumentation -ModuleName "CoreModule"

    # Step 4: Update tests
    Update-TestSuite -ModuleName "CoreModule"
} -TestCommands @(
    "pwsh -File tests/unit/modules/CoreModule/CoreModule-Core.Tests.ps1",
    "pwsh -File tests/integration/CoreModule-Integration.Tests.ps1",
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick",
    "Import-Module './aither-core/modules/CoreModule' -Force"
) -CreatePR -Priority "High"
```

### Emergency Response Patterns

```powershell
# ✅ Critical security fix workflow
Invoke-PatchWorkflow -PatchDescription "SECURITY: Fix authentication bypass vulnerability" -TargetFork "root" -Priority "Critical" -PatchOperation {
    # Apply security fix
    $authModule = "aither-core/modules/Authentication/Private/Validate-Token.ps1"
    $content = Get-Content $authModule -Raw
    $secure = $content -replace 'weak_validation', 'secure_validation_with_signature_check'
    Set-Content $authModule -Value $secure

    # Add additional security tests
    Add-SecurityValidation -Module "Authentication"
} -TestCommands @(
    "pwsh -File tests/security/Authentication-Security.Tests.ps1"
) -CreatePR -Force

# ✅ Rollback patterns for emergencies
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup -DryRun  # Preview first
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup          # Execute rollback
```

## 📊 Monitoring and Observability Patterns

### Operational Monitoring

```powershell
# ✅ Include performance monitoring in operations
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$beforeMemory = [GC]::GetTotalMemory($false)

try {
    # Your operation here
    Invoke-LongRunningOperation

    $stopwatch.Stop()
    $afterMemory = [GC]::GetTotalMemory($true)

    Write-CustomLog -Level 'INFO' -Message "Operation completed in $($stopwatch.ElapsedMilliseconds)ms"
    Write-CustomLog -Level 'INFO' -Message "Memory usage: $([Math]::Round(($afterMemory - $beforeMemory) / 1MB, 2))MB"
} catch {
    $stopwatch.Stop()
    Write-CustomLog -Level 'ERROR' -Message "Operation failed after $($stopwatch.ElapsedMilliseconds)ms"
    throw
}
```

### Health Check Patterns

```powershell
# ✅ System health validation
function Test-SystemHealth {
    $healthChecks = @{
        'ProjectRoot' = { (Find-ProjectRoot) -and (Test-Path (Find-ProjectRoot)) }
        'Modules' = { (Get-ChildItem (Join-Path (Find-ProjectRoot) "aither-core/modules") -Directory).Count -gt 5 }
        'Repository' = { try { Get-GitRepositoryInfo; $true } catch { $false } }
        'GitAuth' = { try { gh auth status 2>$null; $LASTEXITCODE -eq 0 } catch { $false } }
    }

    $results = @{}
    foreach ($check in $healthChecks.GetEnumerator()) {
        try {
            $results[$check.Key] = & $check.Value
        } catch {
            $results[$check.Key] = $false
        }
    }

    return $results
}
```

## 🎯 Code Generation Guidelines

When generating new code, always:

1. **Start with shared utilities** - Import Find-ProjectRoot and other shared functions
2. **Use repository detection** - Make code work across all forks automatically
3. **Include comprehensive error handling** - Try-catch with detailed logging
4. **Add parameter validation** - ValidateNotNullOrEmpty and other attributes
5. **Support ShouldProcess** - For operations that make changes
6. **Include Verbose output** - For debugging and monitoring
7. **Use cross-platform paths** - Join-Path instead of hardcoded separators
8. **Add appropriate tests** - Unit tests with mocking for dependencies
9. **Follow naming conventions** - Clear, descriptive function and variable names
10. **Document complex logic** - Inline comments for complex operations

## 🔄 Refactoring Guidelines

When refactoring existing code:

1. **Move to shared utilities** - Convert module-specific utilities to shared
2. **Update import patterns** - Use correct relative paths for shared utilities
3. **Enhance error handling** - Add comprehensive try-catch blocks
4. **Improve logging** - Use Write-CustomLog consistently
5. **Add parameter validation** - Include proper validation attributes
6. **Update tests** - Ensure tests cover new functionality
7. **Remove hardcoded values** - Use dynamic repository detection
8. **Improve documentation** - Update comments and help text

---

*These patterns ensure consistent, maintainable, and robust code across the entire Aitherium Infrastructure Automation ecosystem.*
