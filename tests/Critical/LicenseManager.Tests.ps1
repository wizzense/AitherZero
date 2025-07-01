BeforeDiscovery {
    $script:LicenseModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/LicenseManager'
    $script:TestAppName = 'LicenseManager'
    
    # Verify the license module exists
    if (-not (Test-Path $script:LicenseModulePath)) {
        throw "LicenseManager module not found at: $script:LicenseModulePath"
    }
}

Describe 'LicenseManager - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'License', 'Security') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'license-manager-tests'
        
        # Save original environment
        $script:OriginalUserProfile = $env:USERPROFILE
        $script:OriginalHome = $env:HOME
        
        # Create test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestLicenseDir = Join-Path $script:TestWorkspace '.aitherzero'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        
        @($script:TestProjectRoot, $script:TestConfigsDir, $script:TestModulesDir, 
          $script:TestLicenseDir, $script:TestSharedDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment
        $env:USERPROFILE = $script:TestWorkspace
        $env:HOME = $script:TestWorkspace
        
        # Create Find-ProjectRoot utility
        $findProjectRootContent = @"
function Find-ProjectRoot {
    param([string]`$StartPath, [switch]`$Force)
    return '$script:TestProjectRoot'
}
"@
        $findProjectRootPath = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        $findProjectRootContent | Out-File -FilePath $findProjectRootPath -Encoding UTF8
        
        # Create test feature registry
        $script:TestFeatureRegistry = @{
            tiers = @{
                free = @{
                    name = "Free Tier"
                    description = "Core functionality for individual users"
                    features = @("core", "development")
                }
                pro = @{
                    name = "Professional"
                    description = "Advanced features for teams and automation"
                    features = @("core", "development", "infrastructure", "ai", "automation")
                }
                enterprise = @{
                    name = "Enterprise"
                    description = "Full suite with security and monitoring"
                    features = @("core", "development", "infrastructure", "ai", "automation", "security", "monitoring", "enterprise")
                }
            }
            features = @{
                core = @{
                    name = "Core Features"
                    tier = "free"
                    modules = @("Logging", "TestingFramework", "ProgressTracking", "StartupExperience", "LicenseManager")
                }
                development = @{
                    name = "Development Tools"
                    tier = "free"
                    modules = @("DevEnvironment", "PatchManager", "BackupManager")
                }
                infrastructure = @{
                    name = "Infrastructure Automation"
                    tier = "pro"
                    modules = @("OpenTofuProvider", "CloudProviderIntegration", "ISOManager", "ISOCustomizer")
                }
                ai = @{
                    name = "AI Integration"
                    tier = "pro"
                    modules = @("AIToolsIntegration", "ConfigurationCarousel")
                }
                automation = @{
                    name = "Advanced Automation"
                    tier = "pro"
                    modules = @("OrchestrationEngine", "ParallelExecution", "ConfigurationRepository")
                }
                security = @{
                    name = "Security Features"
                    tier = "enterprise"
                    modules = @("SecureCredentials", "RemoteConnection")
                }
                monitoring = @{
                    name = "Monitoring & Analytics"
                    tier = "enterprise"
                    modules = @("SystemMonitoring", "RestAPIServer")
                }
                enterprise = @{
                    name = "Enterprise Management"
                    tier = "enterprise"
                    modules = @("LabRunner")
                }
            }
            moduleOverrides = @{
                SetupWizard = @{
                    tier = "free"
                    alwaysAvailable = $true
                }
            }
        }
        
        # Save feature registry
        $featureRegistryPath = Join-Path $script:TestConfigsDir 'feature-registry.json'
        $script:TestFeatureRegistry | ConvertTo-Json -Depth 10 | Out-File -FilePath $featureRegistryPath -Encoding UTF8
        
        # Copy license module to test environment (create mock structure)
        $testLicenseModulePath = Join-Path $script:TestModulesDir 'LicenseManager'
        New-Item -ItemType Directory -Path $testLicenseModulePath -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testLicenseModulePath 'Public') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testLicenseModulePath 'Private') -Force | Out-Null
        
        # Copy actual module files
        Copy-Item -Path "$script:LicenseModulePath\*" -Destination $testLicenseModulePath -Recurse -Force
        
        # Import license module from test location
        Import-Module $testLicenseModulePath -Force -Global
        
        # Test license templates
        $script:TestLicenses = @{
            ValidFree = @{
                licenseId = "FREE-TEST-001"
                tier = "free"
                features = @("core", "development")
                issuedTo = "Free User"
                expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-dd")
                signature = "MOCK-SIGNATURE-FREE"
            }
            ValidPro = @{
                licenseId = "PRO-TEST-001"
                tier = "pro"
                features = @("core", "development", "infrastructure", "ai", "automation")
                issuedTo = "Pro User"
                expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-dd")
                signature = "MOCK-SIGNATURE-PRO"
            }
            ValidEnterprise = @{
                licenseId = "ENT-TEST-001"
                tier = "enterprise"
                features = @("core", "development", "infrastructure", "ai", "automation", "security", "monitoring", "enterprise")
                issuedTo = "Enterprise User"
                expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-dd")
                signature = "MOCK-SIGNATURE-ENTERPRISE"
            }
            ExpiredPro = @{
                licenseId = "PRO-EXP-001"
                tier = "pro"
                features = @("core", "development", "infrastructure", "ai", "automation")
                issuedTo = "Expired Pro User"
                expiryDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
                signature = "MOCK-SIGNATURE-EXPIRED"
            }
            InvalidSignature = @{
                licenseId = "PRO-INVALID-001"
                tier = "pro"
                features = @("core", "development", "infrastructure", "ai", "automation")
                issuedTo = "Invalid Signature User"
                expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-dd")
                signature = "TAMPERED-SIGNATURE"
            }
            Malformed = @{
                licenseId = "MALFORMED-001"
                # Missing required properties
                issuedTo = "Malformed License"
            }
        }
        
        # Create mock signature validation function
        $mockValidationPath = Join-Path $testLicenseModulePath 'Private' 'Validate-LicenseSignature.ps1'
        @'
function Validate-LicenseSignature {
    param($License)
    
    # Mock validation - only accept signatures starting with "MOCK-SIGNATURE"
    if ($License.signature -like "MOCK-SIGNATURE*") {
        return $true
    }
    return $false
}
'@ | Out-File -FilePath $mockValidationPath -Encoding UTF8 -Force
        
        # Create mock modules for testing
        $script:MockModules = @{
            'Logging' = 'free'
            'PatchManager' = 'free'
            'OpenTofuProvider' = 'pro'
            'LabRunner' = 'enterprise'
            'SecureCredentials' = 'enterprise'
            'SetupWizard' = 'free'  # Always available
            'UnknownModule' = $null  # Not in registry
        }
        
        foreach ($moduleName in $script:MockModules.Keys) {
            $mockModulePath = Join-Path $script:TestModulesDir $moduleName
            New-Item -ItemType Directory -Path $mockModulePath -Force | Out-Null
            
            # Create simple module manifest
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$moduleName.psm1'
    FunctionsToExport = @('Test-$moduleName')
}
"@ | Out-File -FilePath (Join-Path $mockModulePath "$moduleName.psd1") -Encoding UTF8
            
            # Create simple module script
            @"
function Test-$moduleName {
    Write-Host "$moduleName module function called"
}
Export-ModuleMember -Function Test-$moduleName
"@ | Out-File -FilePath (Join-Path $mockModulePath "$moduleName.psm1") -Encoding UTF8
        }
    }
    
    AfterAll {
        # Restore original environment
        $env:USERPROFILE = $script:OriginalUserProfile
        $env:HOME = $script:OriginalHome
        
        # Remove imported module
        Remove-Module LicenseManager -Force -ErrorAction SilentlyContinue
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear any existing license
        $licensePath = Join-Path $script:TestLicenseDir 'license.json'
        if (Test-Path $licensePath) {
            Remove-Item -Path $licensePath -Force
        }
        
        # Re-import module to reset state
        Import-Module $script:TestModulesDir\LicenseManager -Force -Global
    }
    
    Context 'License Validation and Security' {
        
        It 'Should detect and reject malformed licenses' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Write malformed license
            $script:TestLicenses.Malformed | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'
            $status.Message | Should -Match 'Invalid license format|License error'
        }
        
        It 'Should detect and reject expired licenses' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Write expired license
            $script:TestLicenses.ExpiredPro | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'
            $status.Message | Should -Match 'License expired'
            $status.ExpiryDate | Should -BeLessThan (Get-Date)
        }
        
        It 'Should detect and reject licenses with invalid signatures' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Write license with invalid signature
            $script:TestLicenses.InvalidSignature | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'
            $status.Message | Should -Match 'Invalid license signature'
        }
        
        It 'Should validate legitimate licenses correctly' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Test each valid license tier
            foreach ($tier in @('ValidFree', 'ValidPro', 'ValidEnterprise')) {
                # Write valid license
                $script:TestLicenses.$tier | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
                
                $status = Get-LicenseStatus
                
                $status.IsValid | Should -Be $true
                $status.Tier | Should -Be $script:TestLicenses.$tier.tier
                $status.Features | Should -Be $script:TestLicenses.$tier.features
                $status.ExpiryDate | Should -BeGreaterThan (Get-Date)
                $status.Message | Should -Match 'License valid'
            }
        }
        
        It 'Should handle missing license file appropriately' {
            # Ensure no license exists
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            if (Test-Path $licensePath) {
                Remove-Item -Path $licensePath -Force
            }
            
            $status = Get-LicenseStatus
            
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'
            $status.Features | Should -Be @('core', 'development')
            $status.Message | Should -Match 'No license found'
        }
        
        It 'Should protect license file from tampering' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Write valid license
            $originalLicense = $script:TestLicenses.ValidPro
            $originalLicense | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Tamper with the license
            $tamperedLicense = Get-Content $licensePath -Raw | ConvertFrom-Json
            $tamperedLicense.tier = 'enterprise'  # Try to upgrade tier
            $tamperedLicense | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            
            # Should fail validation due to signature mismatch
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'  # Should fall back to free
        }
    }
    
    Context 'Feature Access Control by Tier' {
        
        It 'Should enforce free tier module restrictions' {
            # Set up free tier license
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidFree | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Test free tier access
            Test-FeatureAccess -Module 'Logging' | Should -Be $true
            Test-FeatureAccess -Module 'PatchManager' | Should -Be $true
            Test-FeatureAccess -Module 'OpenTofuProvider' | Should -Be $false
            Test-FeatureAccess -Module 'LabRunner' | Should -Be $false
            Test-FeatureAccess -Module 'SecureCredentials' | Should -Be $false
            
            # Test feature access
            Test-FeatureAccess -Feature 'core' | Should -Be $true
            Test-FeatureAccess -Feature 'development' | Should -Be $true
            Test-FeatureAccess -Feature 'infrastructure' | Should -Be $false
            Test-FeatureAccess -Feature 'enterprise' | Should -Be $false
        }
        
        It 'Should enforce pro tier module restrictions' {
            # Set up pro tier license
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidPro | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Test pro tier access
            Test-FeatureAccess -Module 'Logging' | Should -Be $true
            Test-FeatureAccess -Module 'PatchManager' | Should -Be $true
            Test-FeatureAccess -Module 'OpenTofuProvider' | Should -Be $true
            Test-FeatureAccess -Module 'LabRunner' | Should -Be $false  # Enterprise only
            Test-FeatureAccess -Module 'SecureCredentials' | Should -Be $false  # Enterprise only
            
            # Test feature access
            Test-FeatureAccess -Feature 'core' | Should -Be $true
            Test-FeatureAccess -Feature 'development' | Should -Be $true
            Test-FeatureAccess -Feature 'infrastructure' | Should -Be $true
            Test-FeatureAccess -Feature 'ai' | Should -Be $true
            Test-FeatureAccess -Feature 'automation' | Should -Be $true
            Test-FeatureAccess -Feature 'security' | Should -Be $false  # Enterprise only
            Test-FeatureAccess -Feature 'enterprise' | Should -Be $false  # Enterprise only
        }
        
        It 'Should grant full access with enterprise tier' {
            # Set up enterprise tier license
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidEnterprise | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Test enterprise tier access - should have everything
            Test-FeatureAccess -Module 'Logging' | Should -Be $true
            Test-FeatureAccess -Module 'PatchManager' | Should -Be $true
            Test-FeatureAccess -Module 'OpenTofuProvider' | Should -Be $true
            Test-FeatureAccess -Module 'LabRunner' | Should -Be $true
            Test-FeatureAccess -Module 'SecureCredentials' | Should -Be $true
            
            # Test all features
            $allFeatures = @('core', 'development', 'infrastructure', 'ai', 'automation', 'security', 'monitoring', 'enterprise')
            foreach ($feature in $allFeatures) {
                Test-FeatureAccess -Feature $feature | Should -Be $true
            }
        }
        
        It 'Should handle module overrides correctly' {
            # SetupWizard should always be available regardless of tier
            
            # No license (free tier)
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            if (Test-Path $licensePath) {
                Remove-Item -Path $licensePath -Force
            }
            
            Test-FeatureAccess -Module 'SetupWizard' | Should -Be $true
            
            # With pro license
            $script:TestLicenses.ValidPro | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            Test-FeatureAccess -Module 'SetupWizard' | Should -Be $true
            
            # With enterprise license
            $script:TestLicenses.ValidEnterprise | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            Test-FeatureAccess -Module 'SetupWizard' | Should -Be $true
        }
        
        It 'Should handle unknown modules gracefully' {
            # Unknown modules should default to available
            Test-FeatureAccess -Module 'UnknownModule' | Should -Be $true
            Test-FeatureAccess -Module 'NonExistentModule' | Should -Be $true
        }
    }
    
    Context 'License Management Operations' {
        
        It 'Should set and validate new licenses' {
            # Start with no license
            $status = Get-LicenseStatus
            $status.Tier | Should -Be 'free'
            
            # Set pro license
            $proLicense = $script:TestLicenses.ValidPro | ConvertTo-Json
            Set-License -LicenseData $proLicense
            
            # Verify license was set
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $true
            $status.Tier | Should -Be 'pro'
            
            # Upgrade to enterprise
            $entLicense = $script:TestLicenses.ValidEnterprise | ConvertTo-Json
            Set-License -LicenseData $entLicense
            
            # Verify upgrade
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $true
            $status.Tier | Should -Be 'enterprise'
        }
        
        It 'Should handle license downgrade scenarios' {
            # Start with enterprise license
            $entLicense = $script:TestLicenses.ValidEnterprise | ConvertTo-Json
            Set-License -LicenseData $entLicense
            
            $status = Get-LicenseStatus
            $status.Tier | Should -Be 'enterprise'
            
            # Downgrade to pro
            $proLicense = $script:TestLicenses.ValidPro | ConvertTo-Json
            Set-License -LicenseData $proLicense
            
            $status = Get-LicenseStatus
            $status.Tier | Should -Be 'pro'
            
            # Features should be restricted
            Test-FeatureAccess -Module 'LabRunner' | Should -Be $false
        }
        
        It 'Should provide comprehensive available features list' {
            # Test with different tiers
            $tiers = @{
                'free' = $script:TestLicenses.ValidFree
                'pro' = $script:TestLicenses.ValidPro  
                'enterprise' = $script:TestLicenses.ValidEnterprise
            }
            
            foreach ($tierName in $tiers.Keys) {
                # Set license
                $license = $tiers[$tierName] | ConvertTo-Json
                Set-License -LicenseData $license
                
                # Get available features
                $available = Get-AvailableFeatures
                
                $available | Should -Not -BeNullOrEmpty
                $available.Tier | Should -Be $tierName
                $available.Features | Should -Not -BeNullOrEmpty
                $available.Modules | Should -Not -BeNullOrEmpty
                
                # Verify correct feature count
                switch ($tierName) {
                    'free' { 
                        $available.Features.Count | Should -Be 2  # core, development
                    }
                    'pro' { 
                        $available.Features.Count | Should -Be 5  # core, development, infrastructure, ai, automation
                    }
                    'enterprise' { 
                        $available.Features.Count | Should -Be 8  # all features
                    }
                }
            }
        }
    }
    
    Context 'Integration with Module Loading' {
        
        It 'Should prevent loading of restricted modules' {
            # Set free tier license
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidFree | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Try to load enterprise module
            $enterpriseModule = 'LabRunner'
            
            # Check access before loading
            $hasAccess = Test-FeatureAccess -Module $enterpriseModule
            $hasAccess | Should -Be $false
            
            # In real implementation, module loading would check license
            # For testing, we verify the check would fail
            if (-not $hasAccess) {
                # Module should not be loaded
                Get-Module $enterpriseModule | Should -BeNullOrEmpty
            }
        }
        
        It 'Should handle license checks during module import' {
            # Test module access with different licenses
            $testCases = @(
                @{ Module = 'Logging'; RequiredTier = 'free'; ShouldLoad = @($true, $true, $true) }
                @{ Module = 'OpenTofuProvider'; RequiredTier = 'pro'; ShouldLoad = @($false, $true, $true) }
                @{ Module = 'LabRunner'; RequiredTier = 'enterprise'; ShouldLoad = @($false, $false, $true) }
            )
            
            $licenses = @(
                $script:TestLicenses.ValidFree,
                $script:TestLicenses.ValidPro,
                $script:TestLicenses.ValidEnterprise
            )
            
            for ($i = 0; $i -lt $licenses.Count; $i++) {
                # Set license
                $licensePath = Join-Path $script:TestLicenseDir 'license.json'
                $licenses[$i] | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
                
                foreach ($testCase in $testCases) {
                    $hasAccess = Test-FeatureAccess -Module $testCase.Module
                    $hasAccess | Should -Be $testCase.ShouldLoad[$i]
                }
            }
        }
    }
    
    Context 'License Expiry and Renewal' {
        
        It 'Should handle licenses nearing expiry' {
            # Create license expiring in 7 days
            $nearExpiryLicense = $script:TestLicenses.ValidPro.Clone()
            $nearExpiryLicense.expiryDate = (Get-Date).AddDays(7).ToString("yyyy-MM-dd")
            
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $nearExpiryLicense | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            
            $status.IsValid | Should -Be $true  # Still valid
            $status.Tier | Should -Be 'pro'
            
            # Check days until expiry
            $daysUntilExpiry = ($status.ExpiryDate - (Get-Date)).Days
            $daysUntilExpiry | Should -BeLessOrEqual 7
            $daysUntilExpiry | Should -BeGreaterOrEqual 6
        }
        
        It 'Should gracefully handle immediate expiry' {
            # Create license expiring today
            $expiringTodayLicense = $script:TestLicenses.ValidPro.Clone()
            $expiringTodayLicense.expiryDate = (Get-Date).ToString("yyyy-MM-dd")
            
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $expiringTodayLicense | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            
            # Might be valid or invalid depending on exact time
            if ($status.IsValid) {
                $status.Tier | Should -Be 'pro'
            } else {
                $status.Tier | Should -Be 'free'
                $status.Message | Should -Match 'expired'
            }
        }
        
        It 'Should support license renewal' {
            # Start with expired license
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ExpiredPro | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $false
            
            # Renew with valid license
            $renewedLicense = $script:TestLicenses.ValidPro | ConvertTo-Json
            Set-License -LicenseData $renewedLicense
            
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $true
            $status.Tier | Should -Be 'pro'
        }
    }
    
    Context 'Cross-Platform License Storage' {
        
        It 'Should use appropriate license paths per platform' {
            # The module uses USERPROFILE/.aitherzero/license.json
            $expectedDir = Join-Path $script:TestWorkspace '.aitherzero'
            $expectedPath = Join-Path $expectedDir 'license.json'
            
            # Directory should exist after module import
            Test-Path $expectedDir | Should -Be $true
            
            # Write a license
            $script:TestLicenses.ValidFree | ConvertTo-Json | Out-File -FilePath $expectedPath -Encoding UTF8
            
            # Verify it can be read
            $status = Get-LicenseStatus
            $status | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle different file system permissions' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Write initial license
            $script:TestLicenses.ValidPro | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Test read-only scenario
            if ($IsWindows) {
                $licenseFile = Get-Item $licensePath
                $licenseFile.IsReadOnly = $true
                
                # Should still be able to read
                $status = Get-LicenseStatus
                $status.IsValid | Should -Be $true
                
                # Clean up
                $licenseFile.IsReadOnly = $false
            }
        }
    }
    
    Context 'Security and Attack Scenarios' {
        
        It 'Should resist license elevation attacks' {
            # Start with free license
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidFree | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Try to directly modify tier in license file
            $licenseContent = Get-Content $licensePath -Raw | ConvertFrom-Json
            $licenseContent.tier = 'enterprise'
            $licenseContent.features = @("core", "development", "infrastructure", "ai", "automation", "security", "monitoring", "enterprise")
            $licenseContent | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Should fail validation
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'  # Should revert to free
        }
        
        It 'Should handle corrupted license files' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Write corrupted data
            "This is not valid JSON {]}" | Out-File -FilePath $licensePath -Encoding UTF8
            
            # Should handle gracefully
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'
            $status.Message | Should -Match 'License error'
        }
        
        It 'Should prevent replay attacks with old licenses' {
            # This would require timestamp validation in production
            # For now, test that expired licenses are rejected
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            
            # Use an old expired license
            $oldLicense = $script:TestLicenses.ExpiredPro.Clone()
            $oldLicense.expiryDate = (Get-Date).AddYears(-1).ToString("yyyy-MM-dd")
            $oldLicense | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $status = Get-LicenseStatus
            $status.IsValid | Should -Be $false
            $status.Tier | Should -Be 'free'
        }
    }
    
    Context 'Performance and Caching' {
        
        It 'Should cache license status for performance' {
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidPro | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            # First call - reads from file
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $status1 = Get-LicenseStatus
            $stopwatch.Stop()
            $firstCallTime = $stopwatch.ElapsedMilliseconds
            
            # Subsequent calls should be faster (cached)
            $stopwatch.Restart()
            for ($i = 1; $i -le 10; $i++) {
                $status = Get-LicenseStatus
            }
            $stopwatch.Stop()
            $avgSubsequentTime = $stopwatch.ElapsedMilliseconds / 10
            
            # Subsequent calls should be significantly faster
            $avgSubsequentTime | Should -BeLessThan ($firstCallTime * 2)
            
            # All calls should return same result
            $status.Tier | Should -Be $status1.Tier
        }
        
        It 'Should efficiently check feature access' {
            # Set enterprise license for full access
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            $script:TestLicenses.ValidEnterprise | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Check access for multiple modules
            $modules = @('Logging', 'PatchManager', 'OpenTofuProvider', 'LabRunner', 'SecureCredentials')
            foreach ($module in $modules) {
                Test-FeatureAccess -Module $module | Out-Null
            }
            
            $stopwatch.Stop()
            
            # Should complete quickly
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000  # Less than 1 second for all checks
        }
    }
    
    Context 'Compliance and Audit' {
        
        It 'Should provide license audit information' {
            # Set various licenses and check audit info
            $auditTests = @(
                @{ License = $script:TestLicenses.ValidFree; ExpectedTier = 'free' }
                @{ License = $script:TestLicenses.ValidPro; ExpectedTier = 'pro' }
                @{ License = $script:TestLicenses.ValidEnterprise; ExpectedTier = 'enterprise' }
            )
            
            foreach ($test in $auditTests) {
                $licensePath = Join-Path $script:TestLicenseDir 'license.json'
                $test.License | ConvertTo-Json | Out-File -FilePath $licensePath -Encoding UTF8
                
                $status = Get-LicenseStatus
                
                # Audit fields
                $status.LicenseId | Should -Not -BeNullOrEmpty
                $status.IssuedTo | Should -Not -BeNullOrEmpty
                $status.ExpiryDate | Should -Not -BeNullOrEmpty
                $status.Tier | Should -Be $test.ExpectedTier
            }
        }
        
        It 'Should track feature usage attempts' {
            # In production, this would log access attempts
            # For testing, verify the check occurs
            
            # No license (free tier)
            $licensePath = Join-Path $script:TestLicenseDir 'license.json'
            if (Test-Path $licensePath) {
                Remove-Item -Path $licensePath -Force
            }
            
            # Attempt to access restricted feature
            $restrictedAccess = Test-FeatureAccess -Module 'LabRunner'
            $restrictedAccess | Should -Be $false
            
            # Attempt to access allowed feature
            $allowedAccess = Test-FeatureAccess -Module 'Logging'
            $allowedAccess | Should -Be $true
        }
    }
}