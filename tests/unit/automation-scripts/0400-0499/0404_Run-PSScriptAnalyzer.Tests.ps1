#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0404_Run-PSScriptAnalyzer.ps1
.DESCRIPTION
    Tests the PSScriptAnalyzer script functionality including static analysis,
    fix mode, and result reporting.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0404_Run-PSScriptAnalyzer.ps1"
    
    # Mock PSScriptAnalyzer and other functions
    Mock Invoke-ScriptAnalyzer {
        return @(
            [PSCustomObject]@{
                RuleName = 'PSUseDeclaredVarsMoreThanAssignments'
                Severity = 'Warning'
                ScriptName = 'TestScript.ps1'
                Line = 10
                Column = 5
                Message = 'Variable $unused is assigned but never used'
            }
            [PSCustomObject]@{
                RuleName = 'PSAvoidUsingCmdletAliases'
                Severity = 'Warning'
                ScriptName = 'TestScript2.ps1'
                Line = 15
                Column = 1
                Message = 'Alias ls is used. Please use full cmdlet name Get-ChildItem'
            }
            [PSCustomObject]@{
                RuleName = 'PSUseSingularNouns'
                Severity = 'Error'
                ScriptName = 'TestScript3.ps1'
                Line = 5
                Column = 10
                Message = 'Function name should use singular noun'
            }
        )
    }
    Mock Import-Module {}
    Mock Get-Module { 
        return @([PSCustomObject]@{
            Name = 'PSScriptAnalyzer'
            Version = [Version]'1.20.0'
        }) 
    }
    Mock Get-ChildItem { 
        if ($Filter -eq '*.ps1') {
            return @(
                [PSCustomObject]@{ FullName = '/path/to/Script1.ps1' }
                [PSCustomObject]@{ FullName = '/path/to/Script2.ps1' }
                [PSCustomObject]@{ FullName = '/path/to/Script3.ps1' }
            )
        }
        return @()
    }
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Get-Content { return '{"Testing":{"PSScriptAnalyzer":{"Enabled":true,"Rules":{"Severity":["Error","Warning"],"ExcludeRules":["PSAvoidUsingWriteHost"]}}}}' }
    Mock ConvertFrom-Json { 
        return @{
            Testing = @{
                PSScriptAnalyzer = @{
                    Enabled = $true
                    Rules = @{
                        Severity = @('Error', 'Warning')
                        ExcludeRules = @('PSAvoidUsingWriteHost')
                    }
                }
            }
        }
    }
    Mock Export-Csv {}
    Mock Set-Content {}
    Mock ConvertTo-Json { return '{}' }
    Mock Write-Host {}
    Mock Group-Object { 
        return @(
            [PSCustomObject]@{ Name = 'Warning'; Count = 2 }
            [PSCustomObject]@{ Name = 'Error'; Count = 1 }
        )
    }
}

Describe "0404_Run-PSScriptAnalyzer" -Tag @('Unit', 'Testing', 'StaticAnalysis') {
    
    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0404'
        }
    }

    Context "DryRun Mode" {
        It "Should preview analysis without executing when DryRun is specified" {
            $result = & $scriptPath -DryRun -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-ScriptAnalyzer -Times 0
        }
        
        It "Should show file count in DryRun mode" {
            & $scriptPath -DryRun -Path "/test/path"
            
            # Should have checked for PS files
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Include -contains '*.ps1' }
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without executing analysis" {
            { & $scriptPath -WhatIf -Path "/test/path" } | Should -Not -Throw
            
            Assert-MockCalled Invoke-ScriptAnalyzer -Times 0
        }
    }

    Context "Module Dependencies" {
        It "Should check for PSScriptAnalyzer availability" {
            Mock Get-Module { return $null } -ParameterFilter { 
                $ListAvailable -and $Name -eq 'PSScriptAnalyzer' 
            }
            
            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should import PSScriptAnalyzer module" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Import-Module -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
        }
    }

    Context "File Filtering" {
        It "Should analyze all PowerShell files by default" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { 
                $Path -eq "/test/path" -and $Recurse -eq $true 
            }
        }

        It "Should exclude specified paths from analysis" {
            Mock Get-ChildItem { 
                return @(
                    [PSCustomObject]@{ FullName = '/path/to/included.ps1' }
                    [PSCustomObject]@{ FullName = '/path/to/tests/excluded.ps1' }
                )
            } -ParameterFilter { $Filter -eq '*.ps1' }
            
            & $scriptPath -Path "/test/path" -ExcludePaths @('tests')
            
            # Should filter files
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Filter -eq '*.ps1' }
        }

        It "Should handle no files after exclusions gracefully" {
            Mock Get-ChildItem { 
                return @(
                    [PSCustomObject]@{ FullName = '/path/to/tests/test.ps1' }
                )
            } -ParameterFilter { $Filter -eq '*.ps1' }
            
            $result = & $scriptPath -Path "/test/path" -ExcludePaths @('tests')
            
            # Should return success with no files message
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Analysis Configuration" {
        It "Should load configuration from config.psd1 if available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*config.psd1" }
            
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Get-Content -ParameterFilter { $Path -like "*config.psd1" }
        }

        It "Should use PSScriptAnalyzer settings file if available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*PSScriptAnalyzerSettings.psd1" }
            
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { 
                $Settings -like "*PSScriptAnalyzerSettings.psd1" 
            }
        }

        It "Should use default configuration if config.psd1 not found" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*config.psd1" }
            
            & $scriptPath -Path "/test/path"
            
            # Should still run with defaults
            Assert-MockCalled Invoke-ScriptAnalyzer
        }
    }

    Context "Fix Mode" {
        It "Should enable fix mode when Fix parameter is used" {
            & $scriptPath -Path "/test/path" -Fix
            
            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { 
                $Fix -eq $true 
            }
        }

        It "Should warn about file modifications in fix mode" {
            & $scriptPath -Path "/test/path" -Fix
            
            # Should display warning about fix mode
            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Include Suppressed Rules" {
        It "Should include suppressed rules when IncludeSuppressed is specified" {
            & $scriptPath -Path "/test/path" -IncludeSuppressed
            
            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { 
                $IncludeSuppressed -eq $true 
            }
        }
    }

    Context "Results Processing" {
        It "Should process and categorize analysis results" {
            $result = & $scriptPath -Path "/test/path"
            
            # Should display summary
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*PSScriptAnalyzer Summary*" 
            }
        }

        It "Should save results as CSV when issues are found" {
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled Export-Csv -ParameterFilter { 
                $Path -like "*PSScriptAnalyzer-*.csv" 
            }
        }

        It "Should save summary as JSON when issues are found" {
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*PSScriptAnalyzer-Summary-*.json" 
            }
        }

        It "Should create output directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq "/output/path" }
            
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled New-Item -ParameterFilter { 
                $Path -eq "/output/path" -and $ItemType -eq 'Directory' 
            }
        }
    }

    Context "Multiple File Handling" {
        It "Should handle multiple files by analyzing each individually when needed" {
            Mock Get-ChildItem { 
                return @(
                    [PSCustomObject]@{ FullName = '/path/file1.ps1' }
                    [PSCustomObject]@{ FullName = '/path/file2.ps1' }
                )
            } -ParameterFilter { $Filter -eq '*.ps1' }
            
            & $scriptPath -Path "/test/path" -ExcludePaths @('exclude')
            
            # Should call analysis (mocked to handle both single and multiple files)
            Assert-MockCalled Invoke-ScriptAnalyzer
        }
    }

    Context "Exit Codes" {
        It "Should exit with code 0 when no issues are found" {
            Mock Invoke-ScriptAnalyzer { return @() }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 1 when issues are found" {
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 1
        }

        It "Should exit with code 1 when errors are found" {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        RuleName = 'PSUseSingularNouns'
                        Severity = 'Error'
                        ScriptName = 'TestScript.ps1'
                        Line = 5
                        Column = 10
                        Message = 'Function name should use singular noun'
                    }
                )
            }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 1
        }

        It "Should exit with code 1 when only warnings are found" {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        RuleName = 'PSAvoidUsingCmdletAliases'
                        Severity = 'Warning'
                        ScriptName = 'TestScript.ps1'
                        Line = 15
                        Column = 1
                        Message = 'Alias ls is used'
                    }
                )
            }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "Should handle analysis errors gracefully" {
            Mock Invoke-ScriptAnalyzer { throw "Analysis failed" }
            
            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }
    }

    Context "Result Display" {
        It "Should display results by severity" {
            $result = & $scriptPath -Path "/test/path"
            
            # Should group and display by severity
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*By Severity*" 
            }
        }

        It "Should show top violated rules" {
            $result = & $scriptPath -Path "/test/path"
            
            # Should display top rules
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Top Rules Violated*" 
            }
        }

        It "Should show files with most issues" {
            $result = & $scriptPath -Path "/test/path"
            
            # Should display problem files
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Files with Most Issues*" 
            }
        }

        It "Should display detailed error information" {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        RuleName = 'PSUseSingularNouns'
                        Severity = 'Error'
                        ScriptName = '/path/to/TestScript.ps1'
                        Line = 5
                        Column = 10
                        Message = 'Function name should use singular noun'
                    }
                )
            }
            
            $result = & $scriptPath -Path "/test/path"
            
            # Should display error details
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Errors Found*" 
            }
        }
    }

    Context "SARIF Report Generation" {
        It "Should generate SARIF report when ConvertTo-SarifReport is available" {
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'ConvertTo-SarifReport' }
            Mock ConvertTo-SarifReport { return '{"sarif":"data"}' }
            
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled ConvertTo-SarifReport
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*.sarif" 
            }
        }

        It "Should skip SARIF generation when ConvertTo-SarifReport is not available" {
            Mock Get-Command { return $false } -ParameterFilter { $Name -eq 'ConvertTo-SarifReport' }
            
            & $scriptPath -Path "/test/path" -OutputPath "/output/path"
            
            Assert-MockCalled ConvertTo-SarifReport -Times 0
        }
    }
}
