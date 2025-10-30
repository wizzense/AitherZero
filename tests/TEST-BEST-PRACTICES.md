# AitherZero Test Best Practices

This document provides guidelines for writing effective, maintainable tests in the AitherZero project.

## Core Principle: Test Accuracy

**Tests must accurately reflect the code they're testing.** If the implementation changes, tests should automatically detect those changes without requiring manual updates to duplicated code.

## Anti-Pattern: Duplicating Function Code in Tests

### ❌ DON'T DO THIS:
```powershell
BeforeAll {
    # BAD: Duplicating the function from the script being tested
    function Write-DocLog {
        param([string]$Message, [string]$Level = 'Information')
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'Information' { 'White' }
                'Warning' { 'Yellow' }
                'Error' { 'Red' }
                default { 'White' }
            }
        )
    }
}
```

**Problem:** If the actual `Write-DocLog` function in the script changes (e.g., adds a new log level, changes behavior), this test will continue passing with the old, duplicated version. The test becomes stale and inaccurate.

### ✅ DO THIS INSTEAD:
```powershell
BeforeAll {
    $scriptPath = Join-Path $projectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
    
    # GOOD: Extract the actual function using AST parsing
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
    $functionDef = Get-FunctionDefinitionFromScript -ScriptPath $scriptPath -FunctionName 'Write-DocLog'
    Invoke-Expression $functionDef
}
```

**Benefits:**
- Tests always use the current implementation
- Code changes are automatically detected
- No risk of tests passing with outdated logic
- Single source of truth for functionality

## When to Use Stubs vs. Extraction

### Use Stubs for Dependencies
Create stub functions for **external dependencies** that your code relies on:

```powershell
# ACCEPTABLE: Stub for a dependency that may not exist in test environment
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function global:Write-CustomLog { param($Level, $Message, $Source, $Data) }
}
Mock Write-CustomLog { }
```

### Use AST Extraction for Code Under Test
Always extract the **actual functions you're testing** from their source files:

```powershell
# CORRECT: Extract the function being tested
$functionDef = Get-FunctionDefinitionFromScript -ScriptPath $scriptPath -FunctionName 'Get-MyFunction'
Invoke-Expression $functionDef
```

## AST Parsing Advantages

Using PowerShell's Abstract Syntax Tree (AST) parser provides several benefits:

1. **No Execution**: Parses the script without running it (important for scripts with executable code at module level)
2. **Accurate Extraction**: Gets the exact function definition including all parameters, attributes, and logic
3. **Type Safety**: Uses PowerShell's built-in language parser, not fragile regex patterns
4. **Maintainable**: Single helper function can be reused across all test files

## Reference Example

See `/tests/unit/automation-scripts/0700-0799/0744_Generate-AutoDocumentation.Tests.ps1` for a complete working example of:
- AST-based function extraction
- Proper mocking setup
- Testing the real implementation
- Maintaining test accuracy

## Testing Scripts with Executable Code

Many automation scripts in AitherZero have executable code at the bottom (the "main" execution block). These scripts cannot be dot-sourced without triggering that code. AST parsing solves this by extracting just the function definitions without executing anything.

## Summary

- **Never duplicate function code in tests**
- **Always extract from source using AST parsing**
- **Stub external dependencies, extract code under test**
- **Tests should fail when implementation changes unexpectedly**

Following these practices ensures our test suite remains accurate, reliable, and maintainable as the codebase evolves.
