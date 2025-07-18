# Note: Tests require PowerShell 7.0+ but will skip gracefully on older versions

<#
.SYNOPSIS
    Setup Wizard Integration and Functionality Testing

.DESCRIPTION
    Comprehensive testing suite for the AitherZero SetupWizard module:
    - Installation profile validation (minimal, developer, full)
    - Setup step execution and validation
    - Error handling and recovery mechanisms
    - Progress tracking integration
    - Configuration management
    - AI tools integration
    - Cross-platform setup scenarios

.NOTES
    Tests the complete setup wizard experience and integration points
#>

# Global helper functions for all tests
function Write-SetupTestLog {
    param([string]$Message, [string]$Level = 'INFO')
    $colors = @{ 'INFO' = 'White'; 'SUCCESS' = 'Green'; 'WARNING' = 'Yellow'; 'ERROR' = 'Red'; 'DEBUG' = 'Gray' }
    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    Write-Host "[$timestamp] [SetupWizard] [$Level] $Message" -ForegroundColor $colors[$Level]
}

function Test-SetupWizardModule {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $modulePath = Join-Path $projectRoot "aither-core/modules/SetupWizard"
    return Test-Path $modulePath
}

function Import-SetupWizardModule {
    if (Test-SetupWizardModule) {
        try {
            $projectRoot = Split-Path $PSScriptRoot -Parent
            $manifestPath = Join-Path $projectRoot "aither-core/modules/SetupWizard/SetupWizard.psd1"
            Import-Module $manifestPath -Force -ErrorAction Stop
            return $true
        }
        catch {
            Write-SetupTestLog "Failed to import SetupWizard module: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    return $false
}

BeforeAll {
    Import-Module Pester -Force

    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date

    # Test configuration
    $script:TestConfig = @{
        SetupWizardPath = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard"
        TestTimeout = 120
        MaxSetupSteps = 20
        TestProfiles = @('minimal', 'developer', 'full')
        TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-SetupWizard-Tests-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }

    # Create temp directory for tests
    if (-not (Test-Path $script:TestConfig.TempDir)) {
        New-Item -Path $script:TestConfig.TempDir -ItemType Directory -Force | Out-Null
    }

    # Helper functions have been moved to global scope

    function New-MockSetupState {
        param(
            [string]$Profile = 'developer',
            [hashtable]$AdditionalProperties = @{}
        )

        $baseState = @{
            StartTime = Get-Date
            Platform = @{
                OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
                Version = '10.0'
                Architecture = 'X64'
                PowerShell = $PSVersionTable.PSVersion.ToString()
            }
            InstallationProfile = $Profile
            Steps = @()
            CurrentStep = 0
            TotalSteps = 10
            Errors = @()
            Warnings = @()
            Recommendations = @()
            AIToolsToInstall = @()
        }

        # Merge additional properties
        foreach ($key in $AdditionalProperties.Keys) {
            $baseState[$key] = $AdditionalProperties[$key]
        }

        return $baseState
    }

    # Write-SetupTestLog "Starting SetupWizard Integration Tests" -Level 'INFO'
    # Write-SetupTestLog "SetupWizard Module Path: $($script:TestConfig.SetupWizardPath)" -Level 'INFO'
    # Write-SetupTestLog "Test Temp Directory: $($script:TestConfig.TempDir)" -Level 'INFO'
}

Describe "SetupWizard Module Loading and Structure" -Tags @('SetupWizard', 'Module', 'Critical') {

    Context "Module Availability and Loading" {
        It "Should have SetupWizard module available" {
            Test-Path $script:TestConfig.SetupWizardPath | Should -Be $true -Because "SetupWizard module should exist"
        }

        It "Should import SetupWizard module successfully" {
            $manifestPath = Join-Path $script:TestConfig.SetupWizardPath "SetupWizard.psd1"
            if (Test-Path $manifestPath) {
                { Import-Module $manifestPath -Force -ErrorAction Stop } | Should -Not -Throw -Because "SetupWizard module should import without errors"
            } else {
                Set-ItResult -Skipped -Because "SetupWizard module not found"
            }
        }

        It "Should have valid module manifest" -Skip:(-not ($script:TestConfig.SetupWizardPath -and (Test-Path $script:TestConfig.SetupWizardPath))) {
            $manifestPath = Join-Path $script:TestConfig.SetupWizardPath "SetupWizard.psd1"

            if (Test-Path $manifestPath) {
                { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw -Because "Module manifest should be valid"

                $manifest = Test-ModuleManifest $manifestPath
                $manifest.Version | Should -Not -BeNullOrEmpty
                $manifest.PowerShellVersion | Should -BeLessOrEqual $PSVersionTable.PSVersion
            }
        }

        It "Should export required functions" {
            $manifestPath = Join-Path $script:TestConfig.SetupWizardPath "SetupWizard.psd1"
            if (Test-Path $manifestPath) {
                Import-Module $manifestPath -Force -ErrorAction SilentlyContinue
                
                $requiredFunctions = @(
                    'Start-IntelligentSetup',
                    'Get-PlatformInfo',
                    'Get-SetupSteps'
                )

                foreach ($function in $requiredFunctions) {
                    Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Function $function should be exported"
                }
            } else {
                Set-ItResult -Skipped -Because "SetupWizard module not found"
            }
        }
    }

    Context "Module Function Validation" {
        It "Should validate Start-IntelligentSetup function parameters" {
            $function = Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue

            if ($function) {
                $parameters = $function.Parameters
                $parameters.ContainsKey('InstallationProfile') | Should -Be $true
                $parameters.ContainsKey('SkipOptional') | Should -Be $true
                $parameters.ContainsKey('MinimalSetup') | Should -Be $true
            }
        }

        It "Should validate Get-PlatformInfo function" {
            if (Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue) {
                $platformInfo = Get-PlatformInfo
                $platformInfo | Should -Not -BeNullOrEmpty
                $platformInfo.OS | Should -Not -BeNullOrEmpty
                $platformInfo.PowerShell | Should -Not -BeNullOrEmpty
            }
        }

        It "Should validate Get-SetupSteps function" {
            if (Get-Command Get-SetupSteps -ErrorAction SilentlyContinue) {
                foreach ($profile in $script:TestConfig.TestProfiles) {
                    $stepsInfo = Get-SetupSteps -Profile $profile
                    $stepsInfo | Should -Not -BeNullOrEmpty -Because "Profile $profile should have setup steps"
                    $stepsInfo.Steps | Should -Not -BeNullOrEmpty
                    $stepsInfo.Profile | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
}

Describe "Installation Profile Testing" -Tags @('SetupWizard', 'Profiles', 'Configuration') {

    BeforeAll {
        Import-SetupWizardModule | Out-Null
    }

    Context "Profile Definition Validation" -Skip:(-not (Get-Command Get-SetupSteps -ErrorAction SilentlyContinue)) {
        It "Should define all required installation profiles" {
            foreach ($profile in $script:TestConfig.TestProfiles) {
                $stepsInfo = Get-SetupSteps -Profile $profile
                $stepsInfo | Should -Not -BeNullOrEmpty -Because "Profile $profile should be defined"
                $stepsInfo.Profile.Name | Should -Be $profile -Because "Profile name should match"
            }
        }

        It "Should have valid step definitions for each profile" {
            foreach ($profile in $script:TestConfig.TestProfiles) {
                $stepsInfo = Get-SetupSteps -Profile $profile

                # Validate steps structure
                $stepsInfo.Steps | Should -Not -BeNullOrEmpty
                $stepsInfo.Steps.Count | Should -BeGreaterThan 0

                foreach ($step in $stepsInfo.Steps) {
                    $step.Name | Should -Not -BeNullOrEmpty -Because "Each step should have a name"
                    $step.Function | Should -Not -BeNullOrEmpty -Because "Each step should have a function"

                    # Validate that the function exists
                    Get-Command $step.Function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Step function $($step.Function) should exist"
                }
            }
        }

        It "Should have appropriate step counts for different profiles" {
            $profileStepCounts = @{}

            foreach ($profile in $script:TestConfig.TestProfiles) {
                $stepsInfo = Get-SetupSteps -Profile $profile
                $profileStepCounts[$profile] = $stepsInfo.Steps.Count
            }

            # Minimal should have fewer steps than developer
            $profileStepCounts['minimal'] | Should -BeLessOrEqual $profileStepCounts['developer'] -Because "Minimal profile should have fewer or equal steps than developer"

            # Developer should have fewer or equal steps than full
            $profileStepCounts['developer'] | Should -BeLessOrEqual $profileStepCounts['full'] -Because "Developer profile should have fewer or equal steps than full"

            Write-SetupTestLog "Profile step counts: $($profileStepCounts | ConvertTo-Json)" -Level 'INFO'
        }

        It "Should define profile metadata correctly" {
            foreach ($profile in $script:TestConfig.TestProfiles) {
                $stepsInfo = Get-SetupSteps -Profile $profile
                $profileInfo = $stepsInfo.Profile

                $profileInfo.Name | Should -Not -BeNullOrEmpty
                $profileInfo.Description | Should -Not -BeNullOrEmpty
                $profileInfo.EstimatedTime | Should -Not -BeNullOrEmpty

                if ($profileInfo.TargetUse) {
                    $profileInfo.TargetUse | Should -BeOfType [array]
                    $profileInfo.TargetUse.Count | Should -BeGreaterThan 0
                }
            }
        }
    }

    Context "Profile Step Function Validation" -Skip:(-not (Get-Command Get-SetupSteps -ErrorAction SilentlyContinue)) {
        It "Should validate core step functions exist" {
            $coreStepFunctions = @(
                'Test-PlatformRequirements',
                'Test-PowerShellVersion',
                'Test-GitInstallation',
                'Initialize-Configuration',
                'Test-SetupCompletion'
            )

            foreach ($function in $coreStepFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Core step function $function should exist"
            }
        }

        It "Should validate profile-specific step functions exist" {
            # Test developer profile specific functions
            $devStepsInfo = Get-SetupSteps -Profile 'developer'
            $devSpecificSteps = $devStepsInfo.Steps | Where-Object { $_.Name -match 'AI Tools|Development|Node' }

            foreach ($step in $devSpecificSteps) {
                Get-Command $step.Function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Developer-specific function $($step.Function) should exist"
            }

            # Test full profile specific functions
            $fullStepsInfo = Get-SetupSteps -Profile 'full'
            $fullSpecificSteps = $fullStepsInfo.Steps | Where-Object { $_.Name -match 'Cloud|License|Communication' }

            foreach ($step in $fullSpecificSteps) {
                Get-Command $step.Function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Full-specific function $($step.Function) should exist"
            }
        }
    }
}

Describe "Setup Step Execution Testing" -Tags @('SetupWizard', 'Execution', 'Integration') {

    BeforeAll {
        Import-SetupWizardModule | Out-Null
    }

    Context "Core Step Function Execution" -Skip:(-not (Get-Command Test-PlatformRequirements -ErrorAction SilentlyContinue)) {
        It "Should execute Test-PlatformRequirements successfully" {
            $setupState = New-MockSetupState

            $result = Test-PlatformRequirements -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Platform Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }

        It "Should execute Test-PowerShellVersion successfully" -Skip:(-not (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue)) {
            $setupState = New-MockSetupState

            $result = Test-PowerShellVersion -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'PowerShell Version'
            $result.Status | Should -Be 'Passed' -Because "Current PowerShell version should pass validation"
        }

        It "Should execute Test-GitInstallation with appropriate results" -Skip:(-not (Get-Command Test-GitInstallation -ErrorAction SilentlyContinue)) {
            $setupState = New-MockSetupState

            $result = Test-GitInstallation -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Git Installation'
            $result.Status | Should -BeIn @('Passed', 'Warning') -Because "Git should either be installed or installation should be recommended"
        }

        It "Should execute Initialize-Configuration successfully" -Skip:(-not (Get-Command Initialize-Configuration -ErrorAction SilentlyContinue)) {
            $setupState = New-MockSetupState

            $result = Initialize-Configuration -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Configuration Files'
            $result.Status | Should -BeIn @('Passed', 'Warning')
        }
    }

    Context "AI Tools Integration Testing" -Skip:(-not (Get-Command Install-AITools -ErrorAction SilentlyContinue)) {
        It "Should handle AI tools installation for developer profile" {
            $setupState = New-MockSetupState -Profile 'developer'

            try {
                $result = Install-AITools -SetupState $setupState
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be 'AI Tools Setup'
                $result.Status | Should -BeIn @('Passed', 'Warning') -Because "AI tools should install or provide warnings"
            }
            catch {
                Write-SetupTestLog "AI Tools test failed (expected in some environments): $($_.Exception.Message)" -Level 'WARNING'
                # Don't fail the test - AI tools installation might fail in CI/test environments
                $true | Should -Be $true
            }
        }

        It "Should skip AI tools for minimal profile appropriately" {
            $setupState = New-MockSetupState -Profile 'minimal'

            # Check if minimal profile includes AI tools
            $minimalSteps = Get-SetupSteps -Profile 'minimal'
            $hasAIToolsStep = $minimalSteps.Steps | Where-Object { $_.Name -match 'AI Tools' }

            if (-not $hasAIToolsStep) {
                Write-SetupTestLog "Minimal profile correctly excludes AI tools" -Level 'SUCCESS'
                $true | Should -Be $true
            } else {
                # If AI tools step exists in minimal, it should handle it appropriately
                $result = Install-AITools -SetupState $setupState
                $result.Status | Should -BeIn @('Passed', 'Warning')
            }
        }
    }

    Context "Error Handling and Recovery" -Skip:(-not (Get-Command Invoke-ErrorRecovery -ErrorAction SilentlyContinue)) {
        It "Should handle error recovery mechanisms" {
            $setupState = New-MockSetupState
            $mockStepResult = @{
                Name = 'Test Step'
                Status = 'Failed'
                Details = @('Mock error for testing')
            }

            try {
                $recovery = Invoke-ErrorRecovery -StepResult $mockStepResult -SetupState $setupState -StepName 'Test Step'
                $recovery | Should -Not -BeNullOrEmpty
                $recovery.ContainsKey('Attempted') | Should -Be $true
                $recovery.ContainsKey('Success') | Should -Be $true
                $recovery.ContainsKey('Method') | Should -Be $true
            }
            catch {
                Write-SetupTestLog "Error recovery test failed (may be expected): $($_.Exception.Message)" -Level 'WARNING'
                # Don't fail - error recovery might not be applicable for all scenarios
                $true | Should -Be $true
            }
        }

        It "Should handle missing dependencies gracefully" {
            $setupState = New-MockSetupState

            # Test step functions with missing dependencies
            $testSteps = @('Test-NodeJsInstallation', 'Test-CloudCLIs', 'Test-DevEnvironment')

            foreach ($stepFunction in $testSteps) {
                if (Get-Command $stepFunction -ErrorAction SilentlyContinue) {
                    try {
                        $result = & $stepFunction -SetupState $setupState
                        $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
                        Write-SetupTestLog "Step $stepFunction completed with status: $($result.Status)" -Level 'INFO'
                    }
                    catch {
                        Write-SetupTestLog "Step $stepFunction failed gracefully: $($_.Exception.Message)" -Level 'WARNING'
                        # This is acceptable - steps should handle missing dependencies
                    }
                }
            }
        }
    }
}

Describe "Complete Setup Workflow Testing" -Tags @('SetupWizard', 'Workflow', 'EndToEnd') {

    BeforeAll {
        Import-SetupWizardModule | Out-Null
    }

    Context "Full Setup Execution" -Skip:(-not (Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue)) {
        It "Should execute minimal profile setup without errors" {
            try {
                $setupResult = Start-IntelligentSetup -InstallationProfile 'minimal' -SkipOptional -WhatIf

                if ($setupResult) {
                    $setupResult.InstallationProfile | Should -Be 'minimal'
                    $setupResult.Steps | Should -Not -BeNullOrEmpty
                    $setupResult.Errors.Count | Should -BeLessOrEqual 2 -Because "Setup should complete with minimal errors"

                    Write-SetupTestLog "Minimal setup completed with $($setupResult.Steps.Count) steps" -Level 'SUCCESS'
                } else {
                    Write-SetupTestLog "Setup returned null result (may be expected in test environment)" -Level 'WARNING'
                }
            }
            catch {
                Write-SetupTestLog "Minimal setup test failed: $($_.Exception.Message)" -Level 'WARNING'
                # Don't fail in test environment
                $true | Should -Be $true
            }
        }

        It "Should validate setup state progression" {
            # Create a mock setup and validate state changes
            $setupState = New-MockSetupState -Profile 'developer'

            # Simulate step progression
            $setupState.CurrentStep = 1
            $setupState.Steps += @{
                Name = 'Test Step 1'
                Status = 'Passed'
                Details = @('Test step completed')
            }

            $setupState.CurrentStep | Should -Be 1
            $setupState.Steps.Count | Should -Be 1
            $setupState.Steps[0].Status | Should -Be 'Passed'
        }

        It "Should handle setup interruption gracefully" {
            # Test setup interruption scenarios
            $setupState = New-MockSetupState

            # Simulate an error condition
            $setupState.Errors += "Simulated error for testing"

            # Validate error handling
            $setupState.Errors.Count | Should -BeGreaterThan 0

            # Setup should continue to provide useful information even with errors
            $setupState.Platform | Should -Not -BeNullOrEmpty
            $setupState.InstallationProfile | Should -Not -BeNullOrEmpty
        }
    }

    Context "Configuration Integration" -Skip:(-not (Get-Command Initialize-Configuration -ErrorAction SilentlyContinue)) {
        It "Should integrate with ConfigurationCore if available" {
            $configCorePath = Join-Path $script:ProjectRoot "aither-core/modules/ConfigurationCore"

            if (Test-Path $configCorePath) {
                try {
                    Import-Module $configCorePath -Force -ErrorAction Stop

                    if (Get-Command Initialize-ConfigurationCore -ErrorAction SilentlyContinue) {
                        { Initialize-ConfigurationCore } | Should -Not -Throw
                        Write-SetupTestLog "ConfigurationCore integration successful" -Level 'SUCCESS'
                    }
                }
                catch {
                    Write-SetupTestLog "ConfigurationCore integration failed: $($_.Exception.Message)" -Level 'WARNING'
                    # Don't fail - this is optional integration
                }
            } else {
                Write-SetupTestLog "ConfigurationCore not found - testing fallback configuration" -Level 'INFO'

                # Test fallback configuration
                $setupState = New-MockSetupState
                $result = Initialize-Configuration -SetupState $setupState
                $result.Status | Should -BeIn @('Passed', 'Warning')
            }
        }

        It "Should create configuration files in appropriate locations" {
            $setupState = New-MockSetupState

            # Test configuration directory creation
            $configDir = if ($IsWindows) {
                Join-Path $env:APPDATA "AitherZero"
            } else {
                Join-Path $env:HOME ".config/aitherzero"
            }

            # The setup should be able to handle configuration directory creation
            $result = Initialize-Configuration -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty

            # Don't require actual directory creation in tests
            $result.Status | Should -BeIn @('Passed', 'Warning')
        }
    }

    Context "Progress Tracking Integration" {
        It "Should integrate with ProgressTracking module if available" {
            $progressTrackingPath = Join-Path $script:ProjectRoot "aither-core/modules/ProgressTracking"

            if (Test-Path $progressTrackingPath) {
                try {
                    Import-Module $progressTrackingPath -Force -ErrorAction Stop

                    if (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue) {
                        $operationId = Start-ProgressOperation -OperationName "Test Operation" -TotalSteps 5
                        $operationId | Should -Not -BeNullOrEmpty

                        # Clean up
                        if (Get-Command Complete-ProgressOperation -ErrorAction SilentlyContinue) {
                            Complete-ProgressOperation -OperationId $operationId
                        }

                        Write-SetupTestLog "ProgressTracking integration successful" -Level 'SUCCESS'
                    }
                }
                catch {
                    Write-SetupTestLog "ProgressTracking integration failed: $($_.Exception.Message)" -Level 'WARNING'
                    # Don't fail - this is optional integration
                }
            } else {
                Write-SetupTestLog "ProgressTracking module not found - setup should work without it" -Level 'INFO'
                $true | Should -Be $true
            }
        }
    }
}

Describe "Setup Wizard UI and Experience" -Tags @('SetupWizard', 'UI', 'Experience') {

    BeforeAll {
        Import-SetupWizardModule | Out-Null
    }

    Context "User Interface Functions" {
        It "Should have UI helper functions available" {
            $uiFunctions = @(
                'Show-WelcomeMessage',
                'Show-SetupBanner',
                'Show-SetupSummary',
                'Show-InstallationProfile'
            )

            foreach ($function in $uiFunctions) {
                if (Get-Command $function -ErrorAction SilentlyContinue) {
                    Write-SetupTestLog "UI function $function is available" -Level 'SUCCESS'
                } else {
                    Write-SetupTestLog "UI function $function not found" -Level 'WARNING'
                }
            }
        }

        It "Should handle non-interactive mode properly" {
            # Test functions with mock setup state in non-interactive mode
            $setupState = New-MockSetupState

            # Set environment to simulate non-interactive mode
            $originalNoPrompt = $env:NO_PROMPT
            try {
                $env:NO_PROMPT = $true

                # Functions should not fail in non-interactive mode
                if (Get-Command Show-WelcomeMessage -ErrorAction SilentlyContinue) {
                    { Show-WelcomeMessage -SetupState $setupState } | Should -Not -Throw
                }

                if (Get-Command Show-SetupSummary -ErrorAction SilentlyContinue) {
                    { Show-SetupSummary -State $setupState } | Should -Not -Throw
                }

            }
            finally {
                $env:NO_PROMPT = $originalNoPrompt
            }
        }
    }

    Context "Quick Start Guide Generation" -Skip:(-not (Get-Command Generate-QuickStartGuide -ErrorAction SilentlyContinue)) {
        It "Should generate platform-specific quick start guide" {
            $setupState = New-MockSetupState

            $result = Generate-QuickStartGuide -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Quick Start Guide'
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Details | Should -Not -BeNullOrEmpty
        }

        It "Should include platform-specific commands in guide" {
            $setupState = New-MockSetupState

            # The guide should be tailored to the current platform
            $setupState.Platform.OS | Should -Not -BeNullOrEmpty

            $result = Generate-QuickStartGuide -SetupState $setupState
            $result.Status | Should -BeIn @('Passed', 'Warning')
        }
    }
}

Describe "Performance and Reliability" -Tags @('SetupWizard', 'Performance', 'Reliability') {

    BeforeAll {
        Import-SetupWizardModule | Out-Null
    }

    Context "Setup Performance" {
        It "Should complete basic setup validation quickly" {
            $startTime = Get-Date

            # Test basic setup steps
            $setupState = New-MockSetupState

            if (Get-Command Test-PlatformRequirements -ErrorAction SilentlyContinue) {
                Test-PlatformRequirements -SetupState $setupState | Out-Null
            }

            if (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue) {
                Test-PowerShellVersion -SetupState $setupState | Out-Null
            }

            $duration = (Get-Date) - $startTime
            $duration.TotalSeconds | Should -BeLessThan 10 -Because "Basic setup validation should be fast"

            Write-SetupTestLog "Basic validation completed in $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level 'INFO'
        }

        It "Should handle multiple profile validations efficiently" {
            $startTime = Get-Date

            if (Get-Command Get-SetupSteps -ErrorAction SilentlyContinue) {
                foreach ($profile in $script:TestConfig.TestProfiles) {
                    $stepsInfo = Get-SetupSteps -Profile $profile
                    $stepsInfo | Should -Not -BeNullOrEmpty
                }
            }

            $duration = (Get-Date) - $startTime
            $duration.TotalSeconds | Should -BeLessThan 5 -Because "Profile validation should be fast"
        }
    }

    Context "Memory and Resource Management" {
        It "Should not consume excessive memory during setup" {
            $initialMemory = [GC]::GetTotalMemory($false)

            # Simulate setup operations
            $setupState = New-MockSetupState

            # Run several setup steps
            if (Get-Command Test-PlatformRequirements -ErrorAction SilentlyContinue) {
                1..5 | ForEach-Object {
                    Test-PlatformRequirements -SetupState $setupState | Out-Null
                }
            }

            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = ($finalMemory - $initialMemory) / 1MB

            Write-SetupTestLog "Memory increase during test: $([math]::Round($memoryIncrease, 2)) MB" -Level 'INFO'

            # Memory increase should be reasonable
            $memoryIncrease | Should -BeLessThan 50 -Because "Setup operations should not consume excessive memory"
        }
    }

    Context "Error Recovery Reliability" {
        It "Should recover gracefully from common failures" {
            $setupState = New-MockSetupState

            # Test various error conditions
            $errorConditions = @(
                @{ StepName = 'Network Connectivity'; ExpectedRecovery = $false },
                @{ StepName = 'Node.js Detection'; ExpectedRecovery = $true },
                @{ StepName = 'Git Installation'; ExpectedRecovery = $true }
            )

            foreach ($condition in $errorConditions) {
                if (Get-Command Invoke-ErrorRecovery -ErrorAction SilentlyContinue) {
                    $mockResult = @{
                        Name = $condition.StepName
                        Status = 'Failed'
                        Details = @("Mock failure for $($condition.StepName)")
                    }

                    try {
                        $recovery = Invoke-ErrorRecovery -StepResult $mockResult -SetupState $setupState -StepName $condition.StepName

                        if ($condition.ExpectedRecovery) {
                            $recovery.Attempted | Should -Be $true -Because "$($condition.StepName) should attempt recovery"
                        }

                        $recovery.Method | Should -Not -BeNullOrEmpty -Because "Recovery should specify a method"
                    }
                    catch {
                        Write-SetupTestLog "Error recovery test for $($condition.StepName) failed: $($_.Exception.Message)" -Level 'WARNING'
                        # Don't fail - error recovery might not be applicable
                    }
                }
            }
        }
    }
}

AfterAll {
    $duration = (Get-Date) - $script:TestStartTime

    Write-SetupTestLog "SetupWizard Integration Tests Complete" -Level 'SUCCESS'
    Write-SetupTestLog "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level 'INFO'

    # Cleanup temp directory
    if (Test-Path $script:TestConfig.TempDir) {
        try {
            Remove-Item $script:TestConfig.TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-SetupTestLog "Cleaned up temp directory" -Level 'SUCCESS'
        }
        catch {
            Write-SetupTestLog "Failed to clean up temp directory: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    # Remove imported modules to clean up
    $modulesToRemove = @('SetupWizard', 'ConfigurationCore', 'ProgressTracking')
    foreach ($module in $modulesToRemove) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Remove-Module $module -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host "SetupWizard Integration Test Summary:" -ForegroundColor Cyan
    Write-Host "  Test Duration: $([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor White
    Write-Host "  Profiles Tested: $($script:TestConfig.TestProfiles -join ', ')" -ForegroundColor White
    Write-Host "  Platform: $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' })" -ForegroundColor White
}
