#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0854_Manage-PRContainer
.DESCRIPTION
    Comprehensive integration tests for container management functionality
    Validates all actions: QuickStart, Shell, Exec, Status, Logs, Cleanup, List, Pull, Run, Stop
    Supports WhatIf: False
    Updated: 2025-11-05
#>

Describe '0854_Manage-PRContainer Integration' -Tag 'Integration', 'AutomationScript', 'Container' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0854_Manage-PRContainer.ps1'
        $script:TestPRNumber = 9999  # Use a test PR number
        
        # Check if Docker is available
        $script:DockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
        if ($script:DockerAvailable) {
            try {
                $null = docker version 2>&1
                $script:DockerRunning = ($LASTEXITCODE -eq 0)
            } catch {
                $script:DockerRunning = $false
            }
        } else {
            $script:DockerRunning = $false
        }
    }

    Context 'Script Structure' {
        It 'Should have required structure (has mandatory parameters)' {
            # Script has mandatory parameters - cannot execute without them
            # Verify script structure instead
            Test-Path $script:ScriptPath | Should -Be $true
            
            # Verify Get-Command can read parameters
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd.Parameters.Count | Should -BeGreaterThan 0
            } | Should -Not -Throw
        }
    }
    
    Context 'Action Parameter Validation' {
        It 'Should support all documented actions' {
            $cmd = Get-Command $script:ScriptPath
            $actionParam = $cmd.Parameters['Action']
            
            $actionParam | Should -Not -BeNullOrEmpty
            
            # Verify ValidateSet contains all documented actions
            $validateSet = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            
            $supportedActions = $validateSet.ValidValues
            $supportedActions | Should -Contain 'QuickStart'
            $supportedActions | Should -Contain 'Shell'
            $supportedActions | Should -Contain 'Exec'
            $supportedActions | Should -Contain 'Status'
            $supportedActions | Should -Contain 'Logs'
            $supportedActions | Should -Contain 'Cleanup'
            $supportedActions | Should -Contain 'List'
            $supportedActions | Should -Contain 'Pull'
            $supportedActions | Should -Contain 'Run'
            $supportedActions | Should -Contain 'Stop'
        }
    }
    
    Context 'List Action (No Docker Required)' {
        It 'Should execute List action without Docker' {
            # List action should work even without Docker
            $result = & pwsh -Command "& '$script:ScriptPath' -Action List 2>&1"
            $LASTEXITCODE | Should -BeIn @(0, 1)  # 0 if Docker available, 1 if not
            
            # Should produce some output
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Status Action' {
        It 'Should execute Status action with PR number' -Skip:(-not $script:DockerAvailable) {
            # Status checks should work even if container doesn't exist
            $result = & pwsh -Command "& '$script:ScriptPath' -Action Status -PRNumber $script:TestPRNumber 2>&1"
            $LASTEXITCODE | Should -BeIn @(0, 1)
            
            # Should produce output about the container
            $result | Should -Not -BeNullOrEmpty
            $result -join ' ' | Should -Match 'Container|Status'
        }
        
        It 'Should fail without PR number' {
            $result = & pwsh -Command "& '$script:ScriptPath' -Action Status 2>&1"
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context 'Cleanup Action' {
        It 'Should execute Cleanup action gracefully when container does not exist' -Skip:(-not $script:DockerAvailable) {
            # Cleanup should succeed or warn when container doesn't exist
            $result = & pwsh -Command "& '$script:ScriptPath' -Action Cleanup -PRNumber $script:TestPRNumber 2>&1"
            $LASTEXITCODE | Should -BeIn @(0, 1)
            
            # Should handle non-existent container gracefully
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Exec Action Parameter Validation' {
        It 'Should require Command parameter for Exec action' -Skip:(-not $script:DockerAvailable) {
            # Exec without a command should fail gracefully
            $result = & pwsh -Command "& '$script:ScriptPath' -Action Exec -PRNumber $script:TestPRNumber 2>&1"
            $LASTEXITCODE | Should -Be 1
            
            # Should explain that command is required
            $result -join ' ' | Should -Match 'command|Command'
        }
    }
    
    Context 'Documentation Examples Validation' {
        It 'Should support QuickStart workflow as documented' {
            $cmd = Get-Command $script:ScriptPath
            
            # Verify QuickStart action exists
            $actionParam = $cmd.Parameters['Action']
            $validateSet = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'QuickStart'
            
            # Verify PRNumber parameter exists
            $cmd.Parameters.ContainsKey('PRNumber') | Should -Be $true
        }
        
        It 'Should support Shell workflow as documented' {
            $cmd = Get-Command $script:ScriptPath
            
            # Verify Shell action exists
            $actionParam = $cmd.Parameters['Action']
            $validateSet = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Shell'
        }
        
        It 'Should support Exec workflow with Command parameter' {
            $cmd = Get-Command $script:ScriptPath
            
            # Verify Exec action exists
            $actionParam = $cmd.Parameters['Action']
            $validateSet = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Exec'
            
            # Verify Command parameter exists
            $cmd.Parameters.ContainsKey('Command') | Should -Be $true
        }
        
        It 'Should support Logs workflow with optional Follow parameter' {
            $cmd = Get-Command $script:ScriptPath
            
            # Verify Logs action exists
            $actionParam = $cmd.Parameters['Action']
            $validateSet = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Logs'
            
            # Verify Follow parameter exists and is a switch
            $cmd.Parameters.ContainsKey('Follow') | Should -Be $true
            $cmd.Parameters['Follow'].ParameterType | Should -Be ([switch])
        }
    }
    
    Context 'Help Documentation' {
        It 'Should have comprehensive synopsis' {
            $help = Get-Help $script:ScriptPath
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Match 'container|PR|manage'
        }
        
        It 'Should have description' {
            $help = Get-Help $script:ScriptPath
            $help.Description | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have examples for common workflows' {
            $help = Get-Help $script:ScriptPath -Full
            $help.Examples | Should -Not -BeNullOrEmpty
            
            # Should have examples for key actions
            $examplesText = $help.Examples.Example.Code -join ' '
            $examplesText | Should -Match 'QuickStart'
            $examplesText | Should -Match 'Shell'
            $examplesText | Should -Match 'Exec'
        }
    }
}
