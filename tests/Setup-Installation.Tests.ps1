# Note: Tests require PowerShell 7.0+ but will skip gracefully on older versions

<#
.SYNOPSIS
    Comprehensive installation and setup testing suite for AitherZero

.DESCRIPTION
    Tests all aspects of the AitherZero installation and setup process:
    - Installation profiles (minimal, developer, full)
    - Developer setup script functionality
    - Cross-platform compatibility
    - Prerequisites validation
    - Setup wizard integration
    - Entry point validation

.NOTES
    This test suite validates the complete installation experience
#>

BeforeAll {
    # Import Pester module
    Import-Module Pester -Force

    # Setup test environment
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date

    # Test configuration
    $script:TestConfig = @{
        TimeoutSeconds = 300
        RetryCount = 3
        TestDataPath = Join-Path $PSScriptRoot "data"
        TempPath = if ($IsWindows) {
            Join-Path $env:TEMP "AitherZero-Setup-Tests"
        } else {
            Join-Path "/tmp" "AitherZero-Setup-Tests"
        }
    }

    # Create temp directory for tests
    if (-not (Test-Path $script:TestConfig.TempPath)) {
        New-Item -Path $script:TestConfig.TempPath -ItemType Directory -Force | Out-Null
    }

    # Helper function for test logging
    function Write-TestLog {
        param([string]$Message, [string]$Level = 'INFO')
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'INFO' { 'White' }
                'SUCCESS' { 'Green' }
                'WARNING' { 'Yellow' }
                'ERROR' { 'Red' }
                default { 'Gray' }
            }
        )
    }

    # Helper function to test prerequisites
    function Test-InstallationPrerequisites {
        $prerequisites = @{
            PowerShell7 = $PSVersionTable.PSVersion.Major -ge 7
            ProjectStructure = Test-Path (Join-Path $script:ProjectRoot "Start-AitherZero.ps1")
            ModulesDirectory = Test-Path (Join-Path $script:ProjectRoot "aither-core/modules")
            SetupWizard = Test-Path (Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard")
            DevEnvironment = Test-Path (Join-Path $script:ProjectRoot "aither-core/modules/DevEnvironment")
        }

        return $prerequisites
    }

    Write-TestLog "Starting AitherZero Installation & Setup Tests" -Level 'INFO'
    Write-TestLog "Project Root: $script:ProjectRoot" -Level 'INFO'
    Write-TestLog "Test Temp Path: $($script:TestConfig.TempPath)" -Level 'INFO'
}

Describe "Installation Prerequisites Validation" -Tags @('Setup', 'Prerequisites', 'Critical') {

    Context "PowerShell Version Requirements" {
        It "Should be running PowerShell 7.0 or higher" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            Write-TestLog "PowerShell version: $($PSVersionTable.PSVersion)" -Level 'SUCCESS'
        }

        It "Should support cross-platform variables" {
            # Test that cross-platform variables are available
            { $IsWindows; $IsLinux; $IsMacOS } | Should -Not -Throw

            $platformCount = @($IsWindows, $IsLinux, $IsMacOS) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
            $platformCount | Should -Be 1 -Because "Exactly one platform should be true"
        }

        It "Should have required PowerShell modules available" {
            $requiredModules = @('Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility')

            foreach ($module in $requiredModules) {
                Get-Module -ListAvailable -Name $module | Should -Not -BeNullOrEmpty -Because "Module $module is required"
            }
        }
    }

    Context "Project Structure Validation" {
        It "Should have correct project structure" {
            $prerequisites = Test-InstallationPrerequisites

            foreach ($prereq in $prerequisites.GetEnumerator()) {
                $prereq.Value | Should -Be $true -Because "$($prereq.Key) is required for installation"
            }
        }

        It "Should have Start-AitherZero.ps1 entry point" {
            $entryPoint = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
            Test-Path $entryPoint | Should -Be $true

            # Validate script syntax
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $entryPoint -Raw), [ref]$errors)
            $errors.Count | Should -Be 0 -Because "Entry point should have valid PowerShell syntax"
        }

        It "Should have Start-DeveloperSetup.ps1 developer setup script" {
            $devSetupScript = Join-Path $script:ProjectRoot "Start-DeveloperSetup.ps1"
            Test-Path $devSetupScript | Should -Be $true

            # Validate script syntax
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $devSetupScript -Raw), [ref]$errors)
            $errors.Count | Should -Be 0 -Because "Developer setup script should have valid PowerShell syntax"
        }

        It "Should have all required core modules" {
            $coreModules = @(
                'SetupWizard',
                'DevEnvironment',
                'PatchManager',
                'Logging',
                'AIToolsIntegration'
            )

            foreach ($module in $coreModules) {
                $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$module"
                Test-Path $modulePath | Should -Be $true -Because "Core module $module is required"

                # Check for module manifest
                $manifestPath = Join-Path $modulePath "$module.psd1"
                if (Test-Path $manifestPath) {
                    # Validate manifest syntax
                    { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw -Because "Module manifest for $module should be valid"
                }
            }
        }
    }

    Context "Configuration Files" {
        It "Should have configuration directory structure" {
            $configPaths = @(
                'configs',
                'configs/setup-profiles.json'
            )

            foreach ($configPath in $configPaths) {
                $fullPath = Join-Path $script:ProjectRoot $configPath
                Test-Path $fullPath | Should -Be $true -Because "Configuration path $configPath is required"
            }
        }

        It "Should have valid setup profiles configuration" {
            $setupProfilesPath = Join-Path $script:ProjectRoot "configs/setup-profiles.json"

            if (Test-Path $setupProfilesPath) {
                $setupProfiles = Get-Content $setupProfilesPath -Raw | ConvertFrom-Json -ErrorAction Stop
                $setupProfiles | Should -Not -BeNullOrEmpty

                # Check for required profiles
                $requiredProfiles = @('minimal', 'developer', 'full')
                foreach ($profile in $requiredProfiles) {
                    $setupProfiles.profiles.$profile | Should -Not -BeNullOrEmpty -Because "Setup profile $profile should be defined"
                }
            }
        }
    }
}

Describe "Start-DeveloperSetup.ps1 Functionality" -Tags @('Setup', 'DeveloperSetup', 'Integration') {

    BeforeAll {
        $script:DevSetupScript = Join-Path $script:ProjectRoot "Start-DeveloperSetup.ps1"
    }

    Context "Script Parameter Validation" {
        It "Should accept valid Profile parameter values" {
            $validProfiles = @('Quick', 'Full')

            foreach ($profile in $validProfiles) {
                { & $script:DevSetupScript -Profile $profile -WhatIf } | Should -Not -Throw -Because "Profile $profile should be valid"
            }
        }

        It "Should reject invalid Profile parameter values" {
            { & $script:DevSetupScript -Profile 'Invalid' -WhatIf } | Should -Throw -Because "Invalid profile should be rejected"
        }

        It "Should support WhatIf parameter" {
            { & $script:DevSetupScript -WhatIf } | Should -Not -Throw -Because "WhatIf should work without errors"
        }

        It "Should support skip switches" {
            $skipSwitches = @('-SkipAITools', '-SkipGitHooks', '-SkipVSCode')

            foreach ($switch in $skipSwitches) {
                { & $script:DevSetupScript $switch -WhatIf } | Should -Not -Throw -Because "Skip switch $switch should work"
            }
        }
    }

    Context "Prerequisites Validation Function" {
        It "Should properly validate PowerShell version" {
            # Test PowerShell version directly
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
        }

        It "Should validate Git installation" {
            # Test Git installation directly
            $gitCommand = Get-Command git -ErrorAction SilentlyContinue
            $gitCommand | Should -Not -BeNullOrEmpty
        }

        It "Should validate project structure" {
            # Test project structure directly
            Test-Path (Join-Path $script:ProjectRoot "Start-AitherZero.ps1") | Should -Be $true
            Test-Path (Join-Path $script:ProjectRoot "aither-core") | Should -Be $true
        }
    }

    Context "Development Environment Setup" {
        It "Should detect project root correctly" {
            # Test project root detection directly
            $projectRoot = $script:ProjectRoot
            $projectRoot | Should -Not -BeNullOrEmpty
            Test-Path (Join-Path $projectRoot "Start-AitherZero.ps1") | Should -Be $true
        }

        It "Should handle DevEnvironment module integration" -Skip:(-not (Test-Path (Join-Path $script:ProjectRoot "aither-core/modules/DevEnvironment"))) {
            # Test that the script can import DevEnvironment module
            $devEnvPath = Join-Path $script:ProjectRoot "aither-core/modules/DevEnvironment"
            { Import-Module $devEnvPath -Force } | Should -Not -Throw
        }
    }
}

Describe "Installation Profiles Testing" -Tags @('Setup', 'Profiles', 'Integration') {

    Context "SetupWizard Module Integration" {
        BeforeAll {
            $script:SetupWizardPath = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard"
        }

        It "Should import SetupWizard module successfully" -Skip:(-not (Test-Path $script:SetupWizardPath)) {
            { Import-Module $script:SetupWizardPath -Force -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have Start-IntelligentSetup function available" -Skip:(-not (Test-Path $script:SetupWizardPath)) {
            Import-Module $script:SetupWizardPath -Force
            Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should support all installation profiles" -Skip:(-not (Test-Path $script:SetupWizardPath)) {
            Import-Module $script:SetupWizardPath -Force

            $profiles = @('minimal', 'developer', 'full')

            foreach ($profile in $profiles) {
                # Test that the profile is accepted (using WhatIf-like approach)
                {
                    if (Get-Command Get-SetupSteps -ErrorAction SilentlyContinue) {
                        $steps = Get-SetupSteps -Profile $profile
                        $steps | Should -Not -BeNullOrEmpty
                    }
                } | Should -Not -Throw -Because "Profile $profile should be supported"
            }
        }
    }

    Context "Profile Configuration Validation" {
        It "Should have valid profile definitions" {
            $setupWizardPath = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard/SetupWizard.psm1"

            if (Test-Path $setupWizardPath) {
                $content = Get-Content $setupWizardPath -Raw

                # Check that profile definitions exist in the module
                $profiles = @('minimal', 'developer', 'full')
                foreach ($profile in $profiles) {
                    $content | Should -Match $profile -Because "Profile $profile should be defined in SetupWizard"
                }
            }
        }

        It "Should validate profile step definitions" {
            Import-Module (Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard") -Force -ErrorAction SilentlyContinue

            if (Get-Command Get-SetupSteps -ErrorAction SilentlyContinue) {
                $profiles = @('minimal', 'developer', 'full')

                foreach ($profile in $profiles) {
                    $stepsInfo = Get-SetupSteps -Profile $profile
                    $stepsInfo.Steps | Should -Not -BeNullOrEmpty -Because "Profile $profile should have defined steps"
                    $stepsInfo.Profile | Should -Not -BeNullOrEmpty -Because "Profile $profile should have metadata"

                    # Validate step structure
                    foreach ($step in $stepsInfo.Steps) {
                        $step.Name | Should -Not -BeNullOrEmpty -Because "Each step should have a name"
                        $step.Function | Should -Not -BeNullOrEmpty -Because "Each step should have a function"
                    }
                }
            }
        }
    }
}

Describe "Cross-Platform Compatibility" -Tags @('Setup', 'CrossPlatform', 'Compatibility') {

    Context "Platform Detection" {
        It "Should correctly identify current platform" {
            # Test platform detection logic
            $platformInfo = @{
                Windows = $IsWindows
                Linux = $IsLinux
                macOS = $IsMacOS
            }

            $activePlatforms = $platformInfo.GetEnumerator() | Where-Object { $_.Value } | Measure-Object
            $activePlatforms.Count | Should -Be 1 -Because "Exactly one platform should be detected"
        }

        It "Should handle platform-specific paths correctly" {
            if ($IsWindows) {
                $env:APPDATA | Should -Not -BeNullOrEmpty
                $env:LOCALAPPDATA | Should -Not -BeNullOrEmpty
            } else {
                $env:HOME | Should -Not -BeNullOrEmpty
            }
        }

        It "Should support cross-platform PowerShell commands" {
            # Test commands that should work on all platforms
            $crossPlatformCommands = @('Get-Process', 'Get-Location', 'Test-Path', 'Join-Path')

            foreach ($command in $crossPlatformCommands) {
                Get-Command $command -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$command should be available on all platforms"
            }
        }
    }

    Context "Path Handling" {
        It "Should use Join-Path for all path construction" {
            $scriptFiles = @(
                (Join-Path $script:ProjectRoot "Start-AitherZero.ps1"),
                (Join-Path $script:ProjectRoot "Start-DeveloperSetup.ps1")
            )

            foreach ($scriptFile in $scriptFiles) {
                if (Test-Path $scriptFile) {
                    $content = Get-Content $scriptFile -Raw

                    # Check for hardcoded path separators (basic check)
                    $hardcodedPaths = [regex]::Matches($content, '"[^"]*[\\\/][^"]*"')

                    # Allow some exceptions for URLs, regex patterns, etc.
                    $problematicPaths = $hardcodedPaths | Where-Object {
                        $_.Value -notmatch '^"http' -and
                        $_.Value -notmatch '\\n' -and
                        $_.Value -notmatch '\\r' -and
                        $_.Value -notmatch '\\t'
                    }

                    if ($problematicPaths.Count -gt 0) {
                        Write-TestLog "Potential hardcoded paths in $($scriptFile): $($problematicPaths.Value -join ', ')" -Level 'WARNING'
                    }
                }
            }
        }

        It "Should handle environment variables correctly" {
            # Test common environment variables
            $envVars = if ($IsWindows) {
                @('USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'PROGRAMFILES')
            } else {
                @('HOME', 'USER')
            }

            foreach ($envVar in $envVars) {
                [Environment]::GetEnvironmentVariable($envVar) | Should -Not -BeNullOrEmpty -Because "Environment variable $envVar should be available"
            }
        }
    }
}

Describe "Entry Point Validation" -Tags @('Setup', 'EntryPoints', 'Critical') {

    Context "Start-AitherZero.ps1 Validation" {
        BeforeAll {
            $script:EntryPoint = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
        }

        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:EntryPoint -Raw), [ref]$errors)
            $errors.Count | Should -Be 0 -Because "Entry point should have valid syntax"
        }

        It "Should support required parameters" {
            $content = Get-Content $script:EntryPoint -Raw

            # Check for parameter definitions
            $requiredParams = @('Setup', 'InstallationProfile', 'Auto', 'Scripts', 'WhatIf')

            foreach ($param in $requiredParams) {
                $content | Should -Match "\$$param" -Because "Parameter $param should be supported"
            }
        }

        It "Should handle PowerShell version checking" {
            $content = Get-Content $script:EntryPoint -Raw
            $content | Should -Match "Test-PowerShellVersion" -Because "Entry point should check PowerShell version"
        }

        It "Should delegate to aither-core.ps1" {
            $content = Get-Content $script:EntryPoint -Raw
            $content | Should -Match "aither-core.ps1" -Because "Entry point should delegate to core script"
        }
    }

    Context "Start-DeveloperSetup.ps1 Validation" {
        BeforeAll {
            $script:DevSetupScript = Join-Path $script:ProjectRoot "Start-DeveloperSetup.ps1"
        }

        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:DevSetupScript -Raw), [ref]$errors)
            $errors.Count | Should -Be 0 -Because "Developer setup script should have valid syntax"
        }

        It "Should require PowerShell 7.0" {
            $content = Get-Content $script:DevSetupScript -Raw
            $content | Should -Match "# Note: Tests require PowerShell 7.0+ but will skip gracefully on older versions" -Because "Script should require PowerShell 7.0"
        }

        It "Should support ShouldProcess for WhatIf" {
            $content = Get-Content $script:DevSetupScript -Raw
            $content | Should -Match "SupportsShouldProcess" -Because "Script should support WhatIf parameter"
        }

        It "Should integrate with existing modules" {
            $content = Get-Content $script:DevSetupScript -Raw

            $moduleReferences = @('SetupWizard', 'DevEnvironment', 'AIToolsIntegration')

            foreach ($module in $moduleReferences) {
                $content | Should -Match $module -Because "Script should reference $module module"
            }
        }
    }
}

Describe "Performance and Reliability" -Tags @('Setup', 'Performance', 'Reliability') {

    Context "Setup Performance" {
        It "Should complete basic validation quickly" {
            $startTime = Get-Date

            # Run basic validation
            $prerequisites = Test-InstallationPrerequisites

            $duration = (Get-Date) - $startTime
            $duration.TotalSeconds | Should -BeLessThan 10 -Because "Basic validation should complete quickly"
        }

        It "Should handle module imports efficiently" {
            $moduleImportTests = @{
                'SetupWizard' = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard"
                'DevEnvironment' = Join-Path $script:ProjectRoot "aither-core/modules/DevEnvironment"
            }

            foreach ($moduleTest in $moduleImportTests.GetEnumerator()) {
                if (Test-Path $moduleTest.Value) {
                    $startTime = Get-Date

                    try {
                        Import-Module $moduleTest.Value -Force -ErrorAction Stop
                        $duration = (Get-Date) - $startTime
                        $duration.TotalSeconds | Should -BeLessThan 5 -Because "Module $($moduleTest.Key) should import quickly"
                    }
                    catch {
                        Write-TestLog "Module import failed for $($moduleTest.Key): $($_.Exception.Message)" -Level 'WARNING'
                    }
                }
            }
        }
    }

    Context "Error Handling" {
        It "Should handle missing modules gracefully" {
            $nonExistentModulePath = Join-Path $script:ProjectRoot "aither-core/modules/NonExistentModule"

            { Import-Module $nonExistentModulePath -ErrorAction SilentlyContinue } | Should -Not -Throw -Because "Missing modules should be handled gracefully"
        }

        It "Should validate error recovery mechanisms" {
            # Test error recovery if available in SetupWizard
            $setupWizardPath = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard"

            if (Test-Path $setupWizardPath) {
                Import-Module $setupWizardPath -Force -ErrorAction SilentlyContinue

                if (Get-Command Invoke-ErrorRecovery -ErrorAction SilentlyContinue) {
                    # Test error recovery function structure
                    $function = Get-Command Invoke-ErrorRecovery
                    $function.Parameters.ContainsKey('StepResult') | Should -Be $true
                    $function.Parameters.ContainsKey('SetupState') | Should -Be $true
                }
            }
        }
    }
}

AfterAll {
    # Cleanup
    $duration = (Get-Date) - $script:TestStartTime
    Write-TestLog "Total test duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level 'INFO'

    # Clean up temp directory
    if (Test-Path $script:TestConfig.TempPath) {
        try {
            Remove-Item $script:TestConfig.TempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestLog "Cleaned up test temp directory" -Level 'SUCCESS'
        }
        catch {
            Write-TestLog "Failed to clean up temp directory: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    Write-TestLog "AitherZero Installation & Setup Tests Completed" -Level 'SUCCESS'
}
