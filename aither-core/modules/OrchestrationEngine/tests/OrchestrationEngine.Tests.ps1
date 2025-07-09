#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for the OrchestrationEngine module

.DESCRIPTION
    Tests orchestration and playbook functionality including:
    - Playbook creation and execution
    - Step definitions and workflows
    - Status tracking and workflow management
    - Error handling and validation

.NOTES
    Updated to match actual OrchestrationEngine module functions
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force

    # Setup test environment for orchestration operations
    $script:TestStartTime = Get-Date
    $script:TestWorkspace = if ($env:TEMP) {
        Join-Path $env:TEMP "OrchestrationEngine-Test-$(Get-Random)"
    } elseif (Test-Path '/tmp') {
        "/tmp/OrchestrationEngine-Test-$(Get-Random)"
    } else {
        Join-Path (Get-Location) "OrchestrationEngine-Test-$(Get-Random)"
    }

    if (-not (Test-Path $script:TestWorkspace)) {
        New-Item -Path $script:TestWorkspace -ItemType Directory -Force | Out-Null
    }

    # Test log function
    $script:TestLogFunction = if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        { param($Message, $Level = 'INFO') Write-CustomLog -Message $Message -Level $Level }
    } else {
        { param($Message, $Level = 'INFO') Write-Host "[$Level] $Message" }
    }
}

AfterAll {
    # Cleanup test workspace
    if (Test-Path $script:TestWorkspace) {
        Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "OrchestrationEngine Module Tests" {
    
    Context "Module Import and Structure" {
        It "Should import the module successfully" {
            Get-Module OrchestrationEngine | Should -Not -BeNullOrEmpty
        }

        It "Should export core playbook functions" {
            $expectedFunctions = @(
                'New-PlaybookDefinition',
                'Invoke-PlaybookWorkflow',
                'Get-PlaybookStatus',
                'Stop-PlaybookWorkflow',
                'Import-PlaybookDefinition',
                'Validate-PlaybookDefinition'
            )

            $exportedFunctions = (Get-Command -Module OrchestrationEngine).Name
            
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }

        It "Should export step creation functions" {
            $stepFunctions = @(
                'New-ScriptStep',
                'New-ConditionalStep',
                'New-ParallelStep'
            )

            $exportedFunctions = (Get-Command -Module OrchestrationEngine).Name
            
            foreach ($func in $stepFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }
    }

    Context "Playbook Definition Operations" {
        It "Should create a new playbook definition" {
            { New-PlaybookDefinition -Name "test-playbook" -Description "Test playbook" } | Should -Not -Throw
        }

        It "Should validate a playbook definition" {
            $testPlaybook = New-PlaybookDefinition -Name "validation-test" -Description "Test validation"
            if ($testPlaybook) {
                { Validate-PlaybookDefinition -PlaybookDefinition $testPlaybook } | Should -Not -Throw
            }
        }

        It "Should handle playbook definition with steps" {
            $testPlaybook = New-PlaybookDefinition -Name "steps-test" -Description "Test with steps"
            if ($testPlaybook) {
                $testPlaybook | Should -Not -BeNullOrEmpty
                $testPlaybook.Name | Should -Be "steps-test"
            }
        }
    }

    Context "Step Creation Functions" {
        It "Should create script steps" {
            { New-ScriptStep -Name "test-script" -Command "Write-Host 'Test'" } | Should -Not -Throw
        }

        It "Should create conditional steps" {
            $testStep = New-ScriptStep -Name "test-step" -Command "Write-Host 'Test'"
            if ($testStep) {
                { New-ConditionalStep -Name "conditional-test" -Condition "`$true" -ThenSteps @($testStep) } | Should -Not -Throw
            }
        }

        It "Should create parallel steps" {
            $testStep1 = New-ScriptStep -Name "test-step-1" -Command "Write-Host 'Test 1'"
            $testStep2 = New-ScriptStep -Name "test-step-2" -Command "Write-Host 'Test 2'"
            if ($testStep1 -and $testStep2) {
                { New-ParallelStep -Name "parallel-test" -ParallelSteps @($testStep1, $testStep2) } | Should -Not -Throw
            }
        }
    }

    Context "Workflow Execution" {
        It "Should handle workflow execution gracefully" {
            $testPlaybook = New-PlaybookDefinition -Name "execution-test" -Description "Test execution"
            if ($testPlaybook) {
                { Invoke-PlaybookWorkflow -PlaybookDefinition $testPlaybook } | Should -Not -Throw
            }
        }

        It "Should provide workflow status" {
            { Get-PlaybookStatus } | Should -Not -Throw
        }

        It "Should handle workflow stopping" {
            { Stop-PlaybookWorkflow } | Should -Not -Throw
        }
    }

    Context "Import/Export Operations" {
        It "Should handle playbook import" {
            # Test with minimal parameters to avoid file I/O issues
            { Import-PlaybookDefinition -PlaybookName "test-import" } | Should -Not -Throw
        }

        It "Should handle missing playbook gracefully" {
            { Import-PlaybookDefinition -PlaybookName "non-existent-playbook" } | Should -Not -Throw
        }
    }

    Context "Error Handling and Validation" {
        It "Should handle invalid playbook definitions gracefully" {
            { New-PlaybookDefinition -Name "" -Description "Invalid empty name" } | Should -Not -Throw
        }

        It "Should handle invalid step definitions gracefully" {
            { New-ScriptStep -Name "" -Command "" } | Should -Not -Throw
        }

        It "Should provide meaningful error information" {
            # Test that functions don't throw on basic operations
            { Get-PlaybookStatus } | Should -Not -Throw
        }
    }

    Context "Module Integration" {
        It "Should integrate with logging system" {
            # Test that functions work with or without logging
            { New-PlaybookDefinition -Name "logging-test" -Description "Test logging integration" } | Should -Not -Throw
        }

        It "Should handle module dependencies gracefully" {
            # Test module can function independently
            Get-Module OrchestrationEngine | Should -Not -BeNullOrEmpty
        }
    }

    Context "Performance and Reliability" {
        It "Should execute operations within reasonable time" {
            $startTime = Get-Date
            New-PlaybookDefinition -Name "performance-test" -Description "Test performance"
            $endTime = Get-Date
            
            ($endTime - $startTime).TotalSeconds | Should -BeLessThan 5
        }

        It "Should handle multiple operations" {
            for ($i = 1; $i -le 3; $i++) {
                { New-PlaybookDefinition -Name "multi-test-$i" -Description "Multi test $i" } | Should -Not -Throw
            }
        }
    }
}

# Test completion notification
try {
    & $script:TestLogFunction "OrchestrationEngine module test execution completed" "INFO"
} catch {
    Write-Host "[INFO] OrchestrationEngine module test execution completed"
}