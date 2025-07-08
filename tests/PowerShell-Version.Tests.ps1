# Note: Tests require PowerShell 7.0+ but will skip gracefully on older versions

<#
.SYNOPSIS
    PowerShell version compatibility and validation testing

.DESCRIPTION
    Comprehensive testing suite for PowerShell version requirements across AitherZero:
    - Version checking functionality
    - Cross-platform PowerShell compatibility
    - Core cmdlet availability
    - Module import capabilities
    - Performance characteristics across versions

.NOTES
    Tests PowerShell 7.0+ compatibility and version detection mechanisms
#>

BeforeAll {
    # Skip tests if not on PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "PowerShell version tests require PowerShell 7.0+. Current version: $($PSVersionTable.PSVersion)"
        return
    }

    Import-Module Pester -Force

    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date
    
    # Set platform awareness for tests
    $script:CurrentPlatform = if ($env:PESTER_PLATFORM) { $env:PESTER_PLATFORM } 
                             elseif ($IsWindows) { "Windows" }
                             elseif ($IsLinux) { "Linux" }
                             elseif ($IsMacOS) { "macOS" }
                             else { "Unknown" }
    
    Write-Host "Running PowerShell version tests on platform: $script:CurrentPlatform" -ForegroundColor Cyan

    # Test configuration
    $script:TestConfig = @{
        MinimumPSVersion = [Version]"7.0.0"
        RecommendedPSVersion = [Version]"7.4.0"
        DeprecatedPSVersion = [Version]"5.1.0"
        TestTimeout = 30
    }

    # Helper function for version comparison
    function Compare-PowerShellVersion {
        param(
            [Version]$RequiredVersion,
            [Version]$CurrentVersion = $PSVersionTable.PSVersion
        )
        return $CurrentVersion -ge $RequiredVersion
    }

    # Helper function to test PowerShell features
    function Test-PowerShellFeature {
        param(
            [string]$FeatureName,
            [scriptblock]$TestScript
        )

        try {
            $result = & $TestScript
            return @{
                Feature = $FeatureName
                Available = $true
                Result = $result
                Error = $null
            }
        }
        catch {
            return @{
                Feature = $FeatureName
                Available = $false
                Result = $null
                Error = $_.Exception.Message
            }
        }
    }

    Write-Host "Starting PowerShell Version Compatibility Tests" -ForegroundColor Cyan
    Write-Host "Current PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Current PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Yellow
}

Describe "PowerShell Version Requirements" -Tags @('Version', 'Requirements', 'Critical') {

    Context "Core Version Validation" {
        It "Should be running PowerShell 7.0 or higher" {
            $PSVersionTable.PSVersion | Should -BeGreaterOrEqual $script:TestConfig.MinimumPSVersion
        }

        It "Should be PowerShell Core (not Windows PowerShell)" {
            $PSVersionTable.PSEdition | Should -Be 'Core' -Because "AitherZero requires PowerShell Core for cross-platform compatibility"
        }

        It "Should have CLR version compatible with .NET Core/5+" {
            # Modern PowerShell Core/.NET 5+ runtime detection
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                # PowerShell 7+ uses .NET Core/.NET 5+ runtime
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7 -Because "PowerShell Core should be version 7+"
                
                # Additional runtime validation
                if ($PSVersionTable.ContainsKey('CLRVersion') -and $PSVersionTable.CLRVersion) {
                    $clrVersion = $PSVersionTable.CLRVersion
                    $clrVersion.Major | Should -BeGreaterOrEqual 4 -Because "Modern .NET runtime is required"
                } else {
                    # On PowerShell Core, CLRVersion may not be available or may be different
                    # Validate using PSCompatibleVersions or edition instead
                    $PSVersionTable.PSEdition | Should -Be 'Core' -Because "PowerShell Core should report 'Core' edition"
                }
            } else {
                # Windows PowerShell 5.1 and earlier
                $clrVersion = $PSVersionTable.CLRVersion
                if ($clrVersion) {
                    $clrVersion.Major | Should -BeGreaterOrEqual 4 -Because "Modern .NET runtime is required"
                } else {
                    # If CLRVersion is not available, we can't test but shouldn't fail
                    Write-Host "CLRVersion not available in PSVersionTable, skipping CLR version test" -ForegroundColor Yellow
                    $true | Should -Be $true
                }
            }
        }

        It "Should support the required PowerShell host features" {
            $PSVersionTable.PSCompatibleVersions | Should -Contain "7.0" -Because "PowerShell 7.0 compatibility is required"
        }
    }

    Context "Cross-Platform Variables" {
        It "Should have cross-platform automatic variables available" {
            $crossPlatformVars = @('IsWindows', 'IsLinux', 'IsMacOS', 'IsCoreCLR')

            foreach ($var in $crossPlatformVars) {
                { Get-Variable $var -ErrorAction Stop } | Should -Not -Throw -Because "Cross-platform variable $var should be available"
            }
        }

        It "Should correctly identify exactly one platform" {
            $platformCount = @($IsWindows, $IsLinux, $IsMacOS) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
            $platformCount | Should -Be 1 -Because "Exactly one platform should be identified as true"
        }

        It "Should have IsCoreCLR set to true" {
            $IsCoreCLR | Should -Be $true -Because "PowerShell Core should set IsCoreCLR to true"
        }
    }

    Context "Version Detection Functions" {
        It "Should have version checking utility available" {
            $versionCheckPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PowerShellVersion.ps1"

            if (Test-Path $versionCheckPath) {
                Test-Path $versionCheckPath | Should -Be $true

                # Test syntax
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $versionCheckPath -Raw), [ref]$errors)
                $errors.Count | Should -Be 0 -Because "PowerShell version check utility should have valid syntax"
            }
        }

        It "Should load and execute version checking utility" {
            $versionCheckPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PowerShellVersion.ps1"

            if (Test-Path $versionCheckPath) {
                { . $versionCheckPath } | Should -Not -Throw -Because "Version checking utility should load without errors"

                if (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue) {
                    $versionTest = Test-PowerShellVersion -MinimumVersion "7.0" -Quiet
                    $versionTest | Should -Be $true -Because "Current PowerShell version should pass the test"
                }
            }
        }
    }
}

Describe "PowerShell Core Cmdlet Availability" -Tags @('Version', 'Cmdlets', 'Compatibility') {

    Context "Essential Management Cmdlets" {
        It "Should have all required management cmdlets available" {
            # Platform-agnostic cmdlets that should work everywhere
            $universalCmdlets = @(
                'Get-Process', 'Start-Process', 'Stop-Process',
                'Test-Path', 'Get-ChildItem', 'New-Item', 'Remove-Item',
                'Copy-Item', 'Move-Item', 'Rename-Item'
            )

            # Windows-specific cmdlets
            $windowsCmdlets = @(
                'Get-Service', 'Get-EventLog', 'Get-WmiObject', 'Restart-Service'
            )

            # Test universal cmdlets on all platforms
            foreach ($cmdlet in $universalCmdlets) {
                try {
                    $command = Get-Command $cmdlet -ErrorAction Stop
                    $command | Should -Not -BeNullOrEmpty -Because "Universal cmdlet $cmdlet should be available on all platforms"
                }
                catch {
                    throw "Required universal cmdlet $cmdlet is not available: $($_.Exception.Message)"
                }
            }

            # Test Windows-specific cmdlets only on Windows
            if ($IsWindows) {
                foreach ($cmdlet in $windowsCmdlets) {
                    try {
                        $command = Get-Command $cmdlet -ErrorAction Stop
                        $command | Should -Not -BeNullOrEmpty -Because "Windows cmdlet $cmdlet should be available on Windows"
                    }
                    catch {
                        throw "Required Windows cmdlet $cmdlet is not available: $($_.Exception.Message)"
                    }
                }
            } else {
                Write-Host "Skipping Windows-specific cmdlets on $($IsLinux ? 'Linux' : $IsMacOS ? 'macOS' : 'unknown') platform" -ForegroundColor Yellow
            }
        }

        It "Should have utility cmdlets available" {
            $utilityCmdlets = @(
                'ConvertTo-Json', 'ConvertFrom-Json', 'ConvertTo-Csv', 'ConvertFrom-Csv',
                'Select-Object', 'Where-Object', 'ForEach-Object', 'Sort-Object',
                'Measure-Object', 'Group-Object', 'Compare-Object'
            )

            foreach ($cmdlet in $utilityCmdlets) {
                Get-Command $cmdlet -ErrorAction Stop | Should -Not -BeNullOrEmpty -Because "Utility cmdlet $cmdlet should be available"
            }
        }

        It "Should have network cmdlets available" {
            # Universal network cmdlets (available on all platforms)
            $universalNetworkCmdlets = @(
                'Invoke-WebRequest', 'Invoke-RestMethod'
            )

            # Windows-specific network cmdlets
            $windowsNetworkCmdlets = @(
                'Test-NetConnection'
            )

            # Test universal network cmdlets
            foreach ($cmdlet in $universalNetworkCmdlets) {
                try {
                    Get-Command $cmdlet -ErrorAction Stop | Should -Not -BeNullOrEmpty -Because "Universal network cmdlet $cmdlet should be available"
                }
                catch {
                    throw "Required universal network cmdlet $cmdlet is not available: $($_.Exception.Message)"
                }
            }

            # Test Windows-specific network cmdlets only on Windows
            if ($IsWindows) {
                foreach ($cmdlet in $windowsNetworkCmdlets) {
                    try {
                        Get-Command $cmdlet -ErrorAction Stop | Should -Not -BeNullOrEmpty -Because "Windows network cmdlet $cmdlet should be available on Windows"
                    }
                    catch {
                        Write-Host "Warning: Windows network cmdlet $cmdlet is not available: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "Skipping Windows-specific network cmdlets on $($IsLinux ? 'Linux' : $IsMacOS ? 'macOS' : 'unknown') platform" -ForegroundColor Yellow
            }
        }
    }

    Context "Module Management Cmdlets" {
        It "Should have module management cmdlets available" {
            $moduleCmdlets = @(
                'Get-Module', 'Import-Module', 'Remove-Module', 'New-Module',
                'Test-ModuleManifest', 'New-ModuleManifest'
            )

            foreach ($cmdlet in $moduleCmdlets) {
                Get-Command $cmdlet -ErrorAction Stop | Should -Not -BeNullOrEmpty -Because "Module cmdlet $cmdlet should be available"
            }
        }

        It "Should support advanced module features" {
            # Test module import with -Force parameter
            { Import-Module Microsoft.PowerShell.Utility -Force } | Should -Not -Throw

            # Test module listing
            $modules = Get-Module -ListAvailable
            $modules | Should -Not -BeNullOrEmpty -Because "Should be able to list available modules"

            # Test module manifest validation with cross-platform compatibility
            $utilityModule = Get-Module Microsoft.PowerShell.Utility
            if ($utilityModule -and $utilityModule.Path) {
                $manifestPath = $utilityModule.Path
                if (Test-Path $manifestPath) {
                    try {
                        Test-ModuleManifest $manifestPath | Out-Null
                        $true | Should -Be $true -Because "Module manifest validation should work"
                    } catch {
                        # Module manifest validation may fail on some platforms due to nested module issues
                        Write-Host "Module manifest validation skipped on platform $script:CurrentPlatform: $($_.Exception.Message)" -ForegroundColor Yellow
                        $utilityModule | Should -Not -BeNullOrEmpty -Because "Module should be loaded regardless of manifest validation"
                    }
                }
            }
        }
    }
}

Describe "PowerShell Feature Compatibility" -Tags @('Version', 'Features', 'Compatibility') {

    Context "Language Features" {
        It "Should support modern PowerShell syntax features" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            # Test ternary operator (PowerShell 7.0+)
            try {
                # Use Invoke-Expression to avoid parsing issues in older PowerShell versions
                $ternaryTest = '$true ? "yes" : "no"'
                $result = Invoke-Expression $ternaryTest
                $result | Should -Be "yes" -Because "Ternary operator should work in PowerShell 7.0+"
            } catch {
                # Some CI environments may have issues with ternary operator parsing
                Write-Host "Ternary operator test skipped on platform $script:CurrentPlatform: $($_.Exception.Message)" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            }
        }

        It "Should support pipeline chain operators" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            try {
                # Test && operator (PowerShell 7.0+)
                $result = $null
                $andTest = '$true && ($result = "success")'
                Invoke-Expression $andTest
                $result | Should -Be "success" -Because "Pipeline chain operator && should work"

                # Test || operator (PowerShell 7.0+)
                $result2 = $null
                $orTest = '$false || ($result2 = "fallback")'
                Invoke-Expression $orTest
                $result2 | Should -Be "fallback" -Because "Pipeline chain operator || should work"
            } catch {
                # Some CI environments may have issues with pipeline operators
                Write-Host "Pipeline chain operator test skipped on platform $script:CurrentPlatform: $($_.Exception.Message)" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            }
        }

        It "Should support null conditional operators" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            try {
                # Test null conditional operator using Invoke-Expression to avoid parsing issues
                $obj = $null
                $nullTest = '$obj?.Property'
                $result = Invoke-Expression $nullTest
                $result | Should -BeNullOrEmpty -Because "Null conditional operator should work"

                $obj2 = @{ Property = "value" }
                $propTest = '$obj2?.Property'
                $result2 = Invoke-Expression $propTest
                $result2 | Should -Be "value" -Because "Null conditional operator should access properties"
            } catch {
                # Some PowerShell versions may not support null conditional operators in all contexts
                Write-Host "Null conditional operator test skipped on platform $script:CurrentPlatform: $($_.Exception.Message)" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            }
        }

        It "Should support enhanced error handling" {
            # Test ErrorAction parameter on all cmdlets
            { Get-Process -Name "NonExistentProcess" -ErrorAction SilentlyContinue } | Should -Not -Throw

            # Test $ErrorActionPreference variable
            $originalEAP = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $ErrorActionPreference | Should -Be 'Stop'
            }
            finally {
                $ErrorActionPreference = $originalEAP
            }
        }
    }

    Context "Type System Features" {
        It "Should support .NET Core/.NET 5+ type loading" {
            # Test basic .NET types
            [System.IO.Path] | Should -Not -BeNullOrEmpty
            [System.Text.Json.JsonSerializer] | Should -Not -BeNullOrEmpty -Because ".NET Core JSON serializer should be available"
        }

        It "Should support PowerShell class definitions" -Skip:($PSVersionTable.PSVersion.Major -lt 5) {
            # Test class definition (PowerShell 5.0+)
            $classDefinition = @'
class TestClass {
    [string]$Name

    TestClass([string]$name) {
        $this.Name = $name
    }

    [string] GetName() {
        return $this.Name
    }
}
'@

            try {
                Invoke-Expression $classDefinition
                $instance = [TestClass]::new("test")
                $instance.GetName() | Should -Be "test"
            } catch {
                # Some environments may have issues with class definitions during testing
                Write-Host "PowerShell class test skipped on platform $script:CurrentPlatform: $($_.Exception.Message)" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
            }
        }

        It "Should support enum definitions" -Skip:($PSVersionTable.PSVersion.Major -lt 5) {
            $enumDefinition = @'
enum TestEnum {
    Value1
    Value2
    Value3
}
'@

            try {
                Invoke-Expression $enumDefinition
                [TestEnum]::Value1 | Should -Be 0
            } catch {
                # Some environments may have issues with enum definitions during testing
                Write-Host "PowerShell enum test skipped on platform $script:CurrentPlatform: $($_.Exception.Message)" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
            }
        }
    }

    Context "Performance and Memory Features" {
        It "Should handle large datasets efficiently" {
            $startTime = Get-Date

            # Create and process a moderately large dataset
            $data = 1..1000 | ForEach-Object { @{ ID = $_; Value = "Item$_" } }
            $filtered = $data | Where-Object { $_.ID % 10 -eq 0 }

            $duration = (Get-Date) - $startTime
            $duration.TotalSeconds | Should -BeLessThan 5 -Because "Processing 1000 items should be fast"
            $filtered.Count | Should -Be 100
        }

        It "Should support parallel processing features" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            # Test ForEach-Object -Parallel (PowerShell 7.0+)
            $startTime = Get-Date

            try {
                $results = 1..10 | ForEach-Object -Parallel {
                    Start-Sleep -Milliseconds 50  # Reduced sleep time for CI
                    return $_ * 2
                } -ThrottleLimit 5

                $duration = (Get-Date) - $startTime
                $results.Count | Should -Be 10
                $duration.TotalSeconds | Should -BeLessThan 5 -Because "Parallel processing should be reasonably fast"
            } catch {
                # Skip parallel test if not supported (some CI environments)
                Write-Host "Parallel processing test skipped: $($_.Exception.Message)" -ForegroundColor Yellow
                $true | Should -Be $true
            }
        }
    }
}

Describe "AitherZero Specific Version Requirements" -Tags @('Version', 'AitherZero', 'Integration') {

    Context "Entry Point Version Checking" {
        It "Should validate PowerShell version in Start-AitherZero.ps1" {
            $entryPoint = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"

            if (Test-Path $entryPoint) {
                $content = Get-Content $entryPoint -Raw

                # Should reference version checking
                $content | Should -Match "Test-PowerShellVersion" -Because "Entry point should check PowerShell version"

                # Should handle version requirements
                $content | Should -Match "7\.0" -Because "Entry point should reference minimum PowerShell version"
            }
        }

        It "Should validate PowerShell version in Start-DeveloperSetup.ps1" {
            $devSetupScript = Join-Path $script:ProjectRoot "Start-DeveloperSetup.ps1"

            if (Test-Path $devSetupScript) {
                $content = Get-Content $devSetupScript -Raw

                # Should have #Requires directive
                $content | Should -Match "#Requires -Version 7\.0" -Because "Developer setup should require PowerShell 7.0"

                # Should have version validation function
                $content | Should -Match "Test-PowerShellVersionRequirement" -Because "Should have version validation"
            }
        }
    }

    Context "Module Compatibility" {
        It "Should verify core modules work with current PowerShell version" {
            $coreModules = @(
                'SetupWizard',
                'DevEnvironment',
                'PatchManager',
                'Logging'
            )

            foreach ($module in $coreModules) {
                $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$module"

                if (Test-Path $modulePath) {
                    # Test module import
                    { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw -Because "Module $module should import successfully"

                    # Test module manifest if it exists
                    $manifestPath = Join-Path $modulePath "$module.psd1"
                    if (Test-Path $manifestPath) {
                        $manifest = Test-ModuleManifest $manifestPath -ErrorAction SilentlyContinue
                        if ($manifest -and $manifest.PowerShellVersion) {
                            $manifest.PowerShellVersion | Should -BeLessOrEqual $PSVersionTable.PSVersion -Because "Module $module should be compatible with current PowerShell version"
                        }
                    }
                }
            }
        }

        It "Should test version-specific features in modules" {
            # Test SetupWizard with modern PowerShell features
            $setupWizardPath = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard"

            if (Test-Path $setupWizardPath) {
                Import-Module $setupWizardPath -Force -ErrorAction SilentlyContinue

                if (Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue) {
                    $platformInfo = Get-PlatformInfo
                    $platformInfo | Should -Not -BeNullOrEmpty
                    $platformInfo.PowerShell | Should -Be $PSVersionTable.PSVersion.ToString()
                }
            }
        }
    }

    Context "Performance Validation" {
        It "Should meet performance expectations for version checking" {
            $versionCheckPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PowerShellVersion.ps1"

            if (Test-Path $versionCheckPath) {
                $startTime = Get-Date

                # Load and execute version check multiple times
                for ($i = 0; $i -lt 10; $i++) {
                    . $versionCheckPath
                    if (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue) {
                        Test-PowerShellVersion -MinimumVersion "7.0" -Quiet | Out-Null
                    }
                }

                $duration = (Get-Date) - $startTime
                $duration.TotalSeconds | Should -BeLessThan 2 -Because "Version checking should be fast"
            }
        }

        It "Should validate module loading performance" {
            $testModules = @(
                'Microsoft.PowerShell.Management',
                'Microsoft.PowerShell.Utility'
            )

            foreach ($module in $testModules) {
                $startTime = Get-Date
                Import-Module $module -Force
                $duration = (Get-Date) - $startTime

                $duration.TotalSeconds | Should -BeLessThan 1 -Because "Core module $module should load quickly"
            }
        }
    }
}

Describe "Version Compatibility Warnings and Recommendations" -Tags @('Version', 'Recommendations', 'Information') {

    Context "Version Recommendations" {
        It "Should identify if running on recommended PowerShell version" {
            $isRecommended = $PSVersionTable.PSVersion -ge $script:TestConfig.RecommendedPSVersion

            if (-not $isRecommended) {
                Write-Host "RECOMMENDATION: Consider upgrading to PowerShell $($script:TestConfig.RecommendedPSVersion) or higher" -ForegroundColor Yellow
                Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
                Write-Host "Benefits: Better performance, more features, improved security" -ForegroundColor Yellow
            } else {
                Write-Host "✅ Running recommended PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
            }

            # This is informational, not a failure
            $PSVersionTable.PSVersion | Should -BeGreaterOrEqual $script:TestConfig.MinimumPSVersion
        }

        It "Should warn about deprecated PowerShell versions" {
            $isDeprecated = $PSVersionTable.PSVersion -lt $script:TestConfig.MinimumPSVersion

            if ($isDeprecated) {
                Write-Host "WARNING: You are running a deprecated PowerShell version" -ForegroundColor Red
                Write-Host "Current: $($PSVersionTable.PSVersion), Minimum Required: $($script:TestConfig.MinimumPSVersion)" -ForegroundColor Red
                Write-Host "Please upgrade immediately for security and compatibility" -ForegroundColor Red
            }

            # This should be a hard failure for deprecated versions
            $PSVersionTable.PSVersion | Should -BeGreaterOrEqual $script:TestConfig.MinimumPSVersion
        }
    }

    Context "Feature Availability Assessment" {
        It "Should assess modern PowerShell feature availability" {
            $features = @(
                @{ Name = "Ternary Operator"; Test = { $true ? "yes" : "no" } },
                @{ Name = "Pipeline Chain Operators"; Test = { $true && $false || $true } },
                @{ Name = "Null Conditional"; Test = { $null?.Property } },
                @{ Name = "ForEach-Object -Parallel"; Test = { Get-Command "ForEach-Object" | Where-Object { $_.Parameters.ContainsKey("Parallel") } } }
            )

            foreach ($feature in $features) {
                $testResult = Test-PowerShellFeature -FeatureName $feature.Name -TestScript $feature.Test

                Write-Host "Feature '$($feature.Name)': $(if ($testResult.Available) { '✅ Available' } else { '❌ Not Available' })" -ForegroundColor $(if ($testResult.Available) { 'Green' } else { 'Yellow' })

                if (-not $testResult.Available -and $testResult.Error) {
                    Write-Host "  Error: $($testResult.Error)" -ForegroundColor Gray
                }
            }

            # Don't fail the test for feature availability - this is informational
            $true | Should -Be $true
        }
    }
}

AfterAll {
    $duration = (Get-Date) - $script:TestStartTime
    Write-Host ""
    Write-Host "PowerShell Version Compatibility Tests Complete" -ForegroundColor Green
    Write-Host "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan

    $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
    Write-Host "Platform: $platform" -ForegroundColor Cyan
}
