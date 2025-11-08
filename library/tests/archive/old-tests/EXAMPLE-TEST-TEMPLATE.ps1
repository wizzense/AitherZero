#Requires -Version 7.0

<#
.SYNOPSIS
    Example test showing AST-based function extraction pattern
.DESCRIPTION
    This is a template for writing tests that extract functions from scripts
    using AST parsing, ensuring tests always reflect the actual implementation.
    
    Use this as a reference when writing new unit tests for automation scripts.
#>

BeforeAll {
    # 1. Set up paths
    $script:ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    $script:ScriptPath = Join-Path $script:ProjectRoot "automation-scripts/XXXX_YourScript.ps1"
    
    # Verify script exists
    if (-not (Test-Path $script:ScriptPath)) {
        throw "Cannot find script at: $script:ScriptPath"
    }
    
    # 2. Define helper function to extract functions from scripts using AST
    function Get-FunctionDefinitionFromScript {
        param(
            [string]$ScriptPath,
            [string]$FunctionName
        )
        
        # Parse script file without executing it
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptPath, 
            [ref]$null, 
            [ref]$null
        )
        
        # Find the specific function in the AST
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
}

Describe "Example Script - Function Testing with AST Extraction" {
    
    Context "Testing extracted function" {
        
        BeforeAll {
            # 3. Extract the actual function from the script
            $functionDef = Get-FunctionDefinitionFromScript -ScriptPath $script:ScriptPath -FunctionName 'Your-FunctionName'
            
            # 4. Set up mocks for dependencies BEFORE loading the function
            if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
                function global:Write-CustomLog { param($Level, $Message, $Source, $Data) }
            }
            Mock Write-CustomLog { }
            
            # 5. Load the extracted function into test scope
            Invoke-Expression $functionDef
        }
        
        It "Should test actual implementation behavior" {
            # Your test assertions here
            { Your-FunctionName -Parameter "value" } | Should -Not -Throw
        }
        
        It "Should handle edge cases" {
            # Test edge cases
            $result = Your-FunctionName -Parameter ""
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Verify actual script contains expected code" {
        It "Should have the function definition in source" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "function Your-FunctionName"
        }
        
        It "Should have expected logic in the function" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            if ($scriptContent -match '(?s)function Your-FunctionName.*?(?=\r?\nfunction|\z)') {
                $functionContent = $Matches[0]
                $functionContent | Should -Match "expected-pattern"
            } else {
                throw "Could not find Your-FunctionName in script"
            }
        }
    }
}

<#
.NOTES
Key Points:
1. Use Get-FunctionDefinitionFromScript to extract functions via AST
2. Never duplicate function code in tests
3. Mock dependencies before loading the function
4. Invoke-Expression the extracted function definition
5. Test the actual behavior, not a copy

Benefits:
- Tests always use current implementation
- Changes to source are automatically detected
- No risk of stale test code
- Single source of truth

See TEST-BEST-PRACTICES.md for more details.
#>
