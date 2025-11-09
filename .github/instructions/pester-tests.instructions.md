---
applyTo: "**/*.Tests.ps1"
---

# Pester Test Requirements

When writing Pester tests for AitherZero, follow these guidelines to ensure consistency and maintainability:

## Core Principle: Test Accuracy

**Tests must accurately reflect the code they're testing.** Never duplicate function code in tests - always extract from source using AST parsing.

## Test Structure

1. **Use Pester 5.0+ syntax** - BeforeAll/BeforeEach/AfterAll/AfterEach blocks
2. **Require Pester module** - Use `#Requires -Modules Pester` at the top
3. **Set up project root** - Use `$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent` pattern
4. **Import modules under test** - Use `Import-Module` with `-Force` and `-ErrorAction Stop`

## AST-Based Function Extraction (CRITICAL)

**Never duplicate function code in tests.** Always extract functions from source using AST parsing:

```powershell
BeforeAll {
    $scriptPath = Join-Path $projectRoot "path/to/script.ps1"
    
    # Extract the actual function using AST parsing
    function Get-FunctionDefinitionFromScript {
        param([string]$ScriptPath, [string]$FunctionName)
        
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptPath, [ref]$null, [ref]$null
        )
        
        $functionAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $FunctionName
        }, $true) | Select-Object -First 1
        
        if (-not $functionAst) {
            throw "Function '$FunctionName' not found in script '$ScriptPath'"
        }
        
        return $functionAst.Extent.Text
    }
    
    # Extract and load the real function
    $functionDef = Get-FunctionDefinitionFromScript -ScriptPath $scriptPath -FunctionName 'MyFunction'
    Invoke-Expression $functionDef
}
```

**Benefits:**
- Tests always use the current implementation
- Code changes are automatically detected
- Single source of truth for functionality

## Mocking External Dependencies

Create stubs for external dependencies that may not exist in the test environment:

```powershell
BeforeAll {
    # Stub for dependencies
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function global:Write-CustomLog { param($Level, $Message, $Source, $Data) }
    }
    Mock Write-CustomLog { }
}
```

## Test Organization

1. **Use Describe blocks** - Group related tests with `-Tag 'Unit'` or `-Tag 'Integration'`
2. **Use Context blocks** - Organize tests by function or feature
3. **Use It blocks** - One assertion per test (or closely related assertions)
4. **Use BeforeEach** - Set up test data that should be fresh for each test
5. **Use TestDrive** - PowerShell's built-in temporary test directory

## Naming Conventions

- Test files: `<ModuleName>.Tests.ps1` or `<ScriptNumber>_<ScriptName>.Tests.ps1`
- Describe blocks: Match module or script name
- Context blocks: Match function name
- It blocks: Use descriptive "Should..." statements

## Test Coverage

1. **Happy path tests** - Normal operation
2. **Edge cases** - Boundary conditions, empty inputs
3. **Error handling** - Invalid inputs, missing files
4. **Parameter validation** - Required parameters, parameter sets

## Example Test Structure

```powershell
#Requires -Modules Pester

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "aithercore/mymodule/MyModule.psm1"
    
    Import-Module $script:ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module MyModule -Force -ErrorAction SilentlyContinue
}

Describe "MyModule" -Tag 'Unit' {
    BeforeEach {
        # Fresh test data for each test
        $script:TestData = @{
            Name = "Test"
            Value = 42
        }
    }
    
    Context "Get-MyFunction" {
        It "Should return expected value" {
            $result = Get-MyFunction -Name "Test"
            $result | Should -Be 42
        }
        
        It "Should handle missing parameter gracefully" {
            { Get-MyFunction } | Should -Not -Throw
        }
    }
}
```

## Common Patterns

- Use `Should -Be` for equality comparisons
- Use `Should -Not -BeNullOrEmpty` for existence checks
- Use `{ code } | Should -Throw` for error testing
- Use `Should -Match` for regex patterns
- Use `-ErrorAction` parameters to control error handling

## CI/CD Integration

Tests should:
- Run in CI without user interaction
- Use `TestDrive` for temporary files
- Clean up resources in AfterAll blocks
- Exit with proper exit codes (0 = success, non-zero = failure)

## Reference

See `/tests/TEST-BEST-PRACTICES.md` for comprehensive testing guidelines.
