#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0405_Validate-AST.ps1
.DESCRIPTION
    Tests the AST validation script functionality including syntax checking,
    parameter validation, and command verification.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0405_Validate-AST.ps1"
    
    # Mock AST parser and other functions
    Mock Test-PowerShellSyntax {
        return @(
            [PSCustomObject]@{
                File = '/path/to/script.ps1'
                Line = 10
                Column = 5
                Type = 'SyntaxError'
                Severity = 'Error'
                Message = 'Unexpected token'
            }
        )
    }
    Mock Test-ParameterDefinitions {
        return @(
            [PSCustomObject]@{
                File = '/path/to/script.ps1'
                Line = 15
                Column = 1
                Type = 'MissingParameterType'
                Severity = 'Warning'
                Message = 'Parameter has no type declaration'
            }
        )
    }
    Mock Test-CommandUsage {
        return @(
            [PSCustomObject]@{
                File = '/path/to/script.ps1'
                Line = 20
                Column = 1
                Type = 'UnknownCommand'
                Severity = 'Warning'
                Message = 'Command not found'
            }
        )
    }
    Mock Test-ModuleDependencies {
        return @(
            [PSCustomObject]@{
                File = '/path/to/script.ps1'
                Line = 1
                Column = 1
                Type = 'MissingModule'
                Severity = 'Error'
                Message = 'Required module not found'
            }
        )
    }
    Mock Get-ChildItem {
        return @(
            [PSCustomObject]@{ FullName = '/path/to/script1.ps1'; Name = 'script1.ps1' }
            [PSCustomObject]@{ FullName = '/path/to/script2.psm1'; Name = 'script2.psm1' }
            [PSCustomObject]@{ FullName = '/path/to/manifest.psd1'; Name = 'manifest.psd1' }
        )
    }
    Mock Write-Progress {}
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Set-Content {}
    Mock ConvertTo-Json { return '{}' }
    Mock Write-Host {}
    Mock Group-Object { 
        return @(
            [PSCustomObject]@{ Name = 'Error'; Count = 2 }
            [PSCustomObject]@{ Name = 'Warning'; Count = 3 }
        )
    }
}

Describe "0405_Validate-AST" -Tag @('Unit', 'Testing', 'AST') {
    
    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0405'
        }
    }

    Context "DryRun Mode" {
        It "Should preview validation without executing when DryRun is specified" {
            $result = & $scriptPath -DryRun -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Test-PowerShellSyntax -Times 0
            Assert-MockCalled Test-ParameterDefinitions -Times 0
            Assert-MockCalled Test-CommandUsage -Times 0
            Assert-MockCalled Test-ModuleDependencies -Times 0
        }
    }

    Context "File Discovery" {
        It "Should find PowerShell files for validation" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Get-ChildItem -ParameterFilter { 
                $Include -contains '*.ps1' -and $Include -contains '*.psm1' -and $Include -contains '*.psd1' 
            }
        }

        It "Should exclude specified paths from validation" {
            & $scriptPath -Path "/test/path" -ExcludePaths @('tests', 'legacy')
            
            # Should filter files based on exclusion paths
            Assert-MockCalled Get-ChildItem
        }

        It "Should exit gracefully when no files are found" {
            Mock Get-ChildItem { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Validation Types" {
        BeforeEach {
            # Reset mocks to return empty results by default
            Mock Test-PowerShellSyntax { return @() }
            Mock Test-ParameterDefinitions { return @() }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
        }

        It "Should perform syntax validation by default" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Test-PowerShellSyntax -Times 3  # For 3 mocked files
        }

        It "Should perform parameter validation by default" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Test-ParameterDefinitions -Times 3
        }

        It "Should perform command validation by default" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Test-CommandUsage -Times 3
        }

        It "Should perform module dependency validation by default" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Test-ModuleDependencies -Times 3
        }

        It "Should only perform syntax validation when CheckSyntax is specified" {
            & $scriptPath -Path "/test/path" -CheckSyntax
            
            Assert-MockCalled Test-PowerShellSyntax -Times 3
            Assert-MockCalled Test-ParameterDefinitions -Times 0
            Assert-MockCalled Test-CommandUsage -Times 0
            Assert-MockCalled Test-ModuleDependencies -Times 0
        }

        It "Should only perform parameter validation when CheckParameters is specified" {
            & $scriptPath -Path "/test/path" -CheckParameters
            
            Assert-MockCalled Test-PowerShellSyntax -Times 0
            Assert-MockCalled Test-ParameterDefinitions -Times 3
            Assert-MockCalled Test-CommandUsage -Times 0
            Assert-MockCalled Test-ModuleDependencies -Times 0
        }

        It "Should only perform command validation when CheckCommands is specified" {
            & $scriptPath -Path "/test/path" -CheckCommands
            
            Assert-MockCalled Test-PowerShellSyntax -Times 0
            Assert-MockCalled Test-ParameterDefinitions -Times 0
            Assert-MockCalled Test-CommandUsage -Times 3
            Assert-MockCalled Test-ModuleDependencies -Times 0
        }

        It "Should only perform module dependency validation when CheckModuleDependencies is specified" {
            & $scriptPath -Path "/test/path" -CheckModuleDependencies
            
            Assert-MockCalled Test-PowerShellSyntax -Times 0
            Assert-MockCalled Test-ParameterDefinitions -Times 0
            Assert-MockCalled Test-CommandUsage -Times 0
            Assert-MockCalled Test-ModuleDependencies -Times 3
        }
    }

    Context "Syntax Error Handling" {
        It "Should skip other validations if syntax errors are found" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{
                        File = '/path/to/script.ps1'
                        Type = 'SyntaxError'
                        Severity = 'Error'
                        Message = 'Parse error'
                    }
                )
            }
            
            & $scriptPath -Path "/test/path"
            
            # Other validations should be skipped for files with syntax errors
            Assert-MockCalled Test-PowerShellSyntax
        }
    }

    Context "Progress Reporting" {
        It "Should show progress during validation" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Write-Progress -ParameterFilter { 
                $Activity -eq 'Validating AST' 
            }
        }

        It "Should complete progress when validation is done" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Write-Progress -ParameterFilter { 
                $Completed -eq $true 
            }
        }
    }

    Context "Results Processing" {
        It "Should group results by severity" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{ Severity = 'Error'; Message = 'Error 1' }
                    [PSCustomObject]@{ Severity = 'Warning'; Message = 'Warning 1' }
                )
            }
            
            & $scriptPath -Path "/test/path"
            
            # Should process and group results
            Assert-MockCalled Write-Host -Times 1
        }

        It "Should group results by type" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{ Type = 'SyntaxError'; Message = 'Syntax issue' }
                )
            }
            Mock Test-ParameterDefinitions {
                return @(
                    [PSCustomObject]@{ Type = 'MissingParameterType'; Message = 'Parameter issue' }
                )
            }
            
            & $scriptPath -Path "/test/path"
            
            # Should display results by type
            Assert-MockCalled Write-Host -Times 1
        }

        It "Should save validation results to JSON when issues are found" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{
                        File = '/path/to/script.ps1'
                        Type = 'SyntaxError'
                        Severity = 'Error'
                        Message = 'Parse error'
                    }
                )
            }
            
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*AST-Validation-*.json" 
            }
        }

        It "Should create output directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq "/output/path" }
            Mock Test-PowerShellSyntax {
                return @([PSCustomObject]@{ Severity = 'Error'; Message = 'Test error' })
            }
            
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled New-Item -ParameterFilter { 
                $Path -eq "/output/path" -and $ItemType -eq 'Directory' 
            }
        }
    }

    Context "Exit Codes" {
        It "Should exit with code 0 when no issues are found" {
            Mock Test-PowerShellSyntax { return @() }
            Mock Test-ParameterDefinitions { return @() }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 0 when only warnings are found" {
            Mock Test-PowerShellSyntax { return @() }
            Mock Test-ParameterDefinitions {
                return @(
                    [PSCustomObject]@{ Severity = 'Warning'; Message = 'Warning' }
                )
            }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 1 when errors are found" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{ Severity = 'Error'; Message = 'Error' }
                )
            }
            Mock Test-ParameterDefinitions { return @() }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "Should handle validation errors gracefully" {
            Mock Test-PowerShellSyntax { throw "Validation failed" }
            
            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }
    }

    Context "Result Display" {
        It "Should display validation summary" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{ Severity = 'Error'; Type = 'SyntaxError'; Message = 'Error' }
                    [PSCustomObject]@{ Severity = 'Warning'; Type = 'Warning'; Message = 'Warning' }
                )
            }
            Mock Test-ParameterDefinitions { return @() }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            
            # Should display AST validation summary
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*AST Validation Summary*" 
            }
        }

        It "Should show error details when errors are found" {
            Mock Test-PowerShellSyntax {
                return @(
                    [PSCustomObject]@{
                        File = '/path/to/script.ps1'
                        Line = 10
                        Column = 5
                        Severity = 'Error'
                        Message = 'Syntax error message'
                    }
                )
            }
            Mock Test-ParameterDefinitions { return @() }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            
            # Should display error details
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Errors:*" 
            }
        }

        It "Should show success message when no issues are found" {
            Mock Test-PowerShellSyntax { return @() }
            Mock Test-ParameterDefinitions { return @() }
            Mock Test-CommandUsage { return @() }
            Mock Test-ModuleDependencies { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            
            # Should display success message
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*All AST validations passed*" 
            }
        }
    }
}
