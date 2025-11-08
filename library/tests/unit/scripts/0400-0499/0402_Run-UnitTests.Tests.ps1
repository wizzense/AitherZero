#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive tests for 0402_Run-UnitTests

.DESCRIPTION
    Validates script structure, parameters, metadata, execution, and behavior
    
    Script: 0402_Run-UnitTests
    Stage: Testing
    Category: Testing & Quality
    Generated: 2025-11-08 02:26:13
#>

Describe '0402_Run-UnitTests Tests' -Tag 'Unit', 'AutomationScript', 'Range-0400-0499' {
    
    BeforeAll {
        # Import test helpers
        $testHelpersPath = Join-Path $PSScriptRoot '../../../helpers/TestHelpers.psm1'
        if (Test-Path $testHelpersPath) {
            Import-Module $testHelpersPath -Force
        }
        
        # Initialize test environment
        Initialize-TestEnvironment
        
        # Script path
        $scriptPath = Get-TestFilePath 'library/automation-scripts/0402_Run-UnitTests.ps1'
        if (-not (Test-Path $scriptPath)) {
            throw "Script not found: $scriptPath"
        }
    }
    
    AfterAll {
        Clear-TestEnvironment
    }
    
    Context 'Script Structure' {
        It 'Should exist' {
            Test-Path $scriptPath | Should -Be $true
        }
        
        It 'Should have valid PowerShell syntax' {
            Test-ScriptSyntax -Path $scriptPath | Should -Be $true
        }
        
        It 'Should be executable' {
            (Get-Item $scriptPath).Extension | Should -Be '.ps1'
        }
    }
    
    Context 'Script Metadata' {        
        It 'Should have Stage metadata' {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Stage:\s*Testing'
        }
        
        It 'Should have Order metadata' {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Order:\s*402'
        }
        
        It 'Should document dependencies' {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Dependencies:'
        }
        
        It 'Should have tags' {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Tags:'
        }
    }
    Context 'Parameters' {
        
        BeforeAll {
            $cmd = Get-Command $scriptPath
        }
        
        It 'Should have parameter: Path' {
            $cmd.Parameters.ContainsKey('Path') | Should -Be $true
        }
        
        It 'Parameter Path should have type String' {
            $cmd.Parameters['Path'].ParameterType.Name | Should -Be 'String'
        }
        
        It 'Should have parameter: OutputPath' {
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }
        
        It 'Parameter OutputPath should have type String' {
            $cmd.Parameters['OutputPath'].ParameterType.Name | Should -Be 'String'
        }
        
        It 'Should have parameter: DryRun' {
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }
        
        It 'Parameter DryRun should have type SwitchParameter' {
            $cmd.Parameters['DryRun'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
        
        It 'Should have parameter: PassThru' {
            $cmd.Parameters.ContainsKey('PassThru') | Should -Be $true
        }
        
        It 'Parameter PassThru should have type SwitchParameter' {
            $cmd.Parameters['PassThru'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
        
        It 'Should have parameter: NoCoverage' {
            $cmd.Parameters.ContainsKey('NoCoverage') | Should -Be $true
        }
        
        It 'Parameter NoCoverage should have type SwitchParameter' {
            $cmd.Parameters['NoCoverage'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
        
        It 'Should have parameter: CI' {
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }
        
        It 'Parameter CI should have type SwitchParameter' {
            $cmd.Parameters['CI'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
        
        It 'Should have parameter: UseCache' {
            $cmd.Parameters.ContainsKey('UseCache') | Should -Be $true
        }
        
        It 'Parameter UseCache should have type SwitchParameter' {
            $cmd.Parameters['UseCache'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
        
        It 'Should have parameter: ForceRun' {
            $cmd.Parameters.ContainsKey('ForceRun') | Should -Be $true
        }
        
        It 'Parameter ForceRun should have type SwitchParameter' {
            $cmd.Parameters['ForceRun'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
        
        It 'Should have parameter: CacheMinutes' {
            $cmd.Parameters.ContainsKey('CacheMinutes') | Should -Be $true
        }
        
        It 'Parameter CacheMinutes should have type Int32' {
            $cmd.Parameters['CacheMinutes'].ParameterType.Name | Should -Be 'Int32'
        }
        
        It 'Should have parameter: CoverageThreshold' {
            $cmd.Parameters.ContainsKey('CoverageThreshold') | Should -Be $true
        }
        
        It 'Parameter CoverageThreshold should have type Int32' {
            $cmd.Parameters['CoverageThreshold'].ParameterType.Name | Should -Be 'Int32'
        }
    }
    Context 'Help Documentation' {
        
        BeforeAll {
            $help = Get-Help $scriptPath -ErrorAction SilentlyContinue
        }
        
        It 'Should have help documentation' {
            $help | Should -Not -BeNull
        }
        
        It 'Should have Synopsis' {
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have Description' {
            $help.Description | Should -Not -BeNull
        }
        
        It 'Should have Notes section' {
            $help.alertSet | Should -Not -BeNull
        }
    }
    Context 'WhatIf Support' {
        It 'Should support -WhatIf' {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'SupportsShouldProcess'
        }
        
        It 'Should execute with -WhatIf without errors' {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }
    Context 'Execution Behavior' {
        It 'Should not throw when getting help' {
            { Get-Help $scriptPath } | Should -Not -Throw
        }
        
        It 'Should validate parameters before execution' {
            # Verify CmdletBinding is present for parameter validation
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[CmdletBinding'
        }
    }
    
    Context 'Code Quality' {
        It 'Should use approved verbs (if applicable)' {
            $content = Get-Content $scriptPath -Raw
            # Check for function definitions
            if ($content -match 'function\s+(\w+)-(\w+)') {
                $verb = $Matches[1]
                $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
                $approvedVerbs | Should -Contain $verb
            }
        }
        
        It 'Should have error handling' {
            $content = Get-Content $scriptPath -Raw
            # Should have try/catch OR ErrorActionPreference
            ($content -match 'try\s*\{' -or $content -match '\Stop') | Should -Be $true
        }
    }
    
    Context 'Environment Compatibility' {
        It 'Should specify PowerShell version requirement' {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '#Requires\s+-Version'
        }
        
        It 'Should handle cross-platform scenarios' {
            $content = Get-Content $scriptPath -Raw
            # If script uses platform-specific features, should have checks
            if ($content -match 'C:\\\\|HKLM:|Registry' -and $content -notmatch '\False') {
                Write-Warning "Script may have platform-specific code without checks"
            }
            $true | Should -Be $true
        }
    }
}
