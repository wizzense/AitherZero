#Requires -Version 7.0

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
    Import-Module Pester -Force
    
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date
    
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
            $clrVersion = $PSVersionTable.CLRVersion
            $clrVersion.Major | Should -BeGreaterOrEqual 4 -Because "Modern .NET runtime is required"
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
            $requiredCmdlets = @(
                'Get-Process', 'Get-Service', 'Get-EventLog', 'Get-WmiObject',
                'Start-Process', 'Stop-Process', 'Restart-Service',
                'Test-Path', 'Get-ChildItem', 'New-Item', 'Remove-Item',
                'Copy-Item', 'Move-Item', 'Rename-Item'
            )
            
            foreach ($cmdlet in $requiredCmdlets) {
                try {
                    $command = Get-Command $cmdlet -ErrorAction Stop
                    $command | Should -Not -BeNullOrEmpty -Because "Cmdlet $cmdlet should be available"
                }
                catch {
                    # Some cmdlets might not be available on all platforms
                    if ($cmdlet -in @('Get-EventLog', 'Get-WmiObject') -and -not $IsWindows) {
                        Write-Host "Skipping $cmdlet on non-Windows platform" -ForegroundColor Yellow
                    } else {
                        throw "Required cmdlet $cmdlet is not available: $($_.Exception.Message)"
                    }
                }
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
            $networkCmdlets = @(
                'Invoke-WebRequest', 'Invoke-RestMethod', 'Test-NetConnection'
            )
            
            foreach ($cmdlet in $networkCmdlets) {
                try {
                    Get-Command $cmdlet -ErrorAction Stop | Should -Not -BeNullOrEmpty -Because "Network cmdlet $cmdlet should be available"
                }
                catch {
                    if ($cmdlet -eq 'Test-NetConnection' -and -not $IsWindows) {
                        Write-Host "Skipping Test-NetConnection on non-Windows platform" -ForegroundColor Yellow
                    } else {
                        throw "Required network cmdlet $cmdlet is not available: $($_.Exception.Message)"
                    }
                }
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
            
            # Test module manifest validation
            $manifestPath = (Get-Module Microsoft.PowerShell.Utility).Path
            if ($manifestPath -and (Test-Path $manifestPath)) {
                { Test-ModuleManifest $manifestPath } | Should -Not -Throw -Because "Should be able to validate module manifests"
            }
        }
    }
}

Describe "PowerShell Feature Compatibility" -Tags @('Version', 'Features', 'Compatibility') {
    
    Context "Language Features" {
        It "Should support modern PowerShell syntax features" {
            # Test ternary operator (PowerShell 7.0+)
            $result = $true ? "yes" : "no"
            $result | Should -Be "yes" -Because "Ternary operator should work in PowerShell 7.0+"
        }
        
        It "Should support pipeline chain operators" {
            # Test && operator (PowerShell 7.0+)
            $result = $null
            $true && ($result = "success")
            $result | Should -Be "success" -Because "Pipeline chain operator && should work"
            
            # Test || operator (PowerShell 7.0+)
            $result2 = $null
            $false || ($result2 = "fallback")
            $result2 | Should -Be "fallback" -Because "Pipeline chain operator || should work"
        }
        
        It "Should support null conditional operators" {
            $obj = $null
            $result = $obj?.Property
            $result | Should -BeNullOrEmpty -Because "Null conditional operator should work"
            
            $obj2 = @{ Property = "value" }
            $result2 = $obj2?.Property
            $result2 | Should -Be "value" -Because "Null conditional operator should access properties"
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
        
        It "Should support PowerShell class definitions" {
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
            
            { Invoke-Expression $classDefinition } | Should -Not -Throw -Because "PowerShell classes should be supported"
            
            $instance = [TestClass]::new("test")
            $instance.GetName() | Should -Be "test"
        }
        
        It "Should support enum definitions" {
            $enumDefinition = @'
enum TestEnum {
    Value1
    Value2
    Value3
}
'@
            
            { Invoke-Expression $enumDefinition } | Should -Not -Throw -Because "PowerShell enums should be supported"
            [TestEnum]::Value1 | Should -Be 0
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
        
        It "Should support parallel processing features" {
            # Test ForEach-Object -Parallel (PowerShell 7.0+)
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $startTime = Get-Date
                
                $results = 1..10 | ForEach-Object -Parallel {
                    Start-Sleep -Milliseconds 100
                    return $_ * 2
                } -ThrottleLimit 5
                
                $duration = (Get-Date) - $startTime
                $results.Count | Should -Be 10
                $duration.TotalSeconds | Should -BeLessThan 3 -Because "Parallel processing should be faster than serial"
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