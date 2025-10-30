#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0744_Generate-AutoDocumentation.ps1 Write-DocLog function
.DESCRIPTION
    Tests that the Write-DocLog function handles all log levels correctly
    without throwing null ForegroundColor errors. This validates the fix
    where a default case was added to the switch statement.
    
    IMPORTANT: This test extracts the actual function from the script under test
    using AST parsing, ensuring tests always reflect the current implementation.
    Do NOT duplicate function code in tests - always extract from source.
#>

BeforeAll {
    # Determine project root path (4 levels up from test file)
    $script:ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $script:ScriptPath = Join-Path $script:ProjectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
    
    # Verify script exists
    if (-not (Test-Path $script:ScriptPath)) {
        throw "Cannot find script at: $script:ScriptPath"
    }
    
    # Helper function to extract function definitions from a script file using AST parsing.
    # This approach ensures tests always use the actual function implementation from the script,
    # not a duplicate that could become stale when the source code changes.
    function Get-FunctionDefinitionFromScript {
        param(
            [string]$ScriptPath,
            [string]$FunctionName
        )
        
        # Parse the script file without executing it to get its Abstract Syntax Tree (AST)
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptPath, 
            [ref]$null, 
            [ref]$null
        )
        
        # Find the specific function definition in the AST
        $functionAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $FunctionName
        }, $true) | Select-Object -First 1
        
        if (-not $functionAst) {
            throw "Function '$FunctionName' not found in script '$ScriptPath'"
        }
        
        # Return the complete function definition as text
        return $functionAst.Extent.Text
    }
}

Describe "0744_Generate-AutoDocumentation - Write-DocLog Function Fix" {
    
    Context "Validating the fix prevents null ForegroundColor errors" {
        
        BeforeAll {
            # Extract the actual Write-DocLog function from the script under test using AST.
            # This approach ensures we're testing the real implementation, not a potentially
            # outdated duplicate. If the source function changes, the test will automatically
            # reflect those changes, maintaining test accuracy.
            $functionDefinition = Get-FunctionDefinitionFromScript -ScriptPath $script:ScriptPath -FunctionName 'Write-DocLog'
            
            # Set up mocks for dependencies BEFORE loading the extracted function
            # so they're available when the function is invoked.
            
            # Ensure Write-CustomLog exists as a stub for mocking
            if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
                function global:Write-CustomLog { param($Level, $Message, $Source, $Data) }
            }
            Mock Write-CustomLog { }
            
            # Mock Write-Host to track and validate calls without producing output
            Mock Write-Host { }
            
            # Mock Get-Command to return null for Write-CustomLog lookups.
            # This forces Write-DocLog to use the Write-Host fallback path,
            # which is what we want to test (the color mapping logic).
            Mock Get-Command {
                return $null
            } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            # Load the extracted function definition into the test scope
            Invoke-Expression $functionDefinition
        }
        
        It "Should not throw error with Information level" {
            { Write-DocLog -Message "Test message" -Level 'Information' } | Should -Not -Throw
        }
        
        It "Should not throw error with Warning level" {
            { Write-DocLog -Message "Warning message" -Level 'Warning' } | Should -Not -Throw
        }
        
        It "Should not throw error with Error level" {
            { Write-DocLog -Message "Error message" -Level 'Error' } | Should -Not -Throw
        }
        
        It "Should not throw error with unknown level (Debug) - KEY FIX VALIDATION" {
            # This is the critical test - before the fix, this would throw:
            # "Cannot convert null to type System.ConsoleColor"
            # After the fix, it uses the default White color
            { Write-DocLog -Message "Test message" -Level 'Debug' } | Should -Not -Throw
        }
        
        It "Should not throw error with empty level value" {
            { Write-DocLog -Message "Test message" -Level '' } | Should -Not -Throw
        }
        
        It "Should not throw error with various unknown levels" {
            { Write-DocLog -Message "Test message" -Level 'UnknownLevel' } | Should -Not -Throw
            { Write-DocLog -Message "Test message" -Level 'Verbose' } | Should -Not -Throw
            { Write-DocLog -Message "Test message" -Level 'Critical' } | Should -Not -Throw
            { Write-DocLog -Message "Test message" -Level 'Trace' } | Should -Not -Throw
        }
        
        It "Should call Write-Host with White color for Information level" {
            Write-DocLog -Message "Test message" -Level 'Information'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Information]*Test message*" -and 
                $ForegroundColor -eq 'White'
            }
        }
        
        It "Should call Write-Host with Yellow color for Warning level" {
            Write-DocLog -Message "Warning message" -Level 'Warning'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Warning]*Warning message*" -and 
                $ForegroundColor -eq 'Yellow'
            }
        }
        
        It "Should call Write-Host with Red color for Error level" {
            Write-DocLog -Message "Error message" -Level 'Error'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Error]*Error message*" -and 
                $ForegroundColor -eq 'Red'
            }
        }
        
        It "Should call Write-Host with White (default) for unknown level" {
            Write-DocLog -Message "Test message" -Level 'Debug'
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Debug]*Test message*" -and 
                $ForegroundColor -eq 'White'
            }
        }
        
        It "Should use default Information level when not specified" {
            Write-DocLog -Message "Test message"
            
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*[Information]*"
            }
        }
        
        It "Should handle null data parameter gracefully" {
            { Write-DocLog -Message "Test message" -Data $null } | Should -Not -Throw
        }
        
        It "Should handle empty data hashtable" {
            { Write-DocLog -Message "Test message" -Data @{} } | Should -Not -Throw
        }
    }
    
    Context "Verify actual script contains the fix" {
        It "Should have 'default' case in the Write-DocLog switch statement" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            
            # The fixed script should contain the default case
            $scriptContent | Should -Match "default\s*\{\s*'White'\s*\}"
        }
        
        It "Should have the complete Write-DocLog function with the fix" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            
            # Extract the Write-DocLog function (more flexible regex)
            if ($scriptContent -match '(?s)function Write-DocLog.*?(?=\r?\nfunction|\r?\n\r?\n[a-z]|\z)') {
                $functionContent = $Matches[0]
                
                # Verify it contains all expected cases plus default
                $functionContent | Should -Match "'Information'"
                $functionContent | Should -Match "'Warning'"
                $functionContent | Should -Match "'Error'"
                $functionContent | Should -Match "default"
            } else {
                throw "Could not find Write-DocLog function in script"
            }
        }
    }
}



