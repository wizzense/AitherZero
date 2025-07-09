#Requires -Modules Pester

BeforeAll {
    # Import the LicenseManager module
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force

    # Create test license directory
    $script:TestLicenseDir = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-Tests"
    $script:TestLicensePath = Join-Path $script:TestLicenseDir "license.json"

    if (Test-Path $script:TestLicenseDir) {
        Remove-Item $script:TestLicenseDir -Recurse -Force
    }
    New-Item -Path $script:TestLicenseDir -ItemType Directory -Force | Out-Null

    # Mock the script license path for testing
    $testPath = $script:TestLicensePath
    InModuleScope LicenseManager {
        $script:LicensePath = $args[0]
    } -ArgumentList $testPath

    # Create test license data
    $script:TestLicense = @{
        licenseId = [Guid]::NewGuid().ToString()
        tier = "pro"
        features = @("core", "development", "infrastructure", "ai", "automation")
        issuedTo = "Test User"
        issuedDate = (Get-Date).ToString('yyyy-MM-dd')
        expiryDate = (Get-Date).AddDays(365).ToString('yyyy-MM-dd')
        signature = ""
    }

    # Generate signature for test license
    $dataToSign = "licenseId:$($script:TestLicense.licenseId)|tier:$($script:TestLicense.tier)|issuedTo:$($script:TestLicense.issuedTo)|expiryDate:$($script:TestLicense.expiryDate)|features:$($script:TestLicense.features -join ',')"
    $script:TestLicense.signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dataToSign))

    # Create expired license for testing
    $script:ExpiredLicense = $script:TestLicense.Clone()
    $script:ExpiredLicense.expiryDate = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
    $expiredDataToSign = "licenseId:$($script:ExpiredLicense.licenseId)|tier:$($script:ExpiredLicense.tier)|issuedTo:$($script:ExpiredLicense.issuedTo)|expiryDate:$($script:ExpiredLicense.expiryDate)|features:$($script:ExpiredLicense.features -join ',')"
    $script:ExpiredLicense.signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($expiredDataToSign))

    # Create invalid license for testing
    $script:InvalidLicense = @{
        licenseId = "invalid"
        tier = "invalid-tier"
        features = @()
        issuedTo = ""
        expiryDate = "invalid-date"
        signature = "invalid-signature"
    }
}

AfterAll {
    # Cleanup test files
    if (Test-Path $script:TestLicenseDir) {
        Remove-Item $script:TestLicenseDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "LicenseManager Module" {
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module LicenseManager | Should -Not -BeNullOrEmpty
        }

        It "Should export all required functions" {
            $ExpectedFunctions = @(
                'Get-LicenseStatus', 'Set-License', 'Test-FeatureAccess',
                'Get-AvailableFeatures', 'Clear-License', 'Get-FeatureTier',
                'Test-ModuleAccess', 'Get-LicenseInfo', 'New-License'
            )

            $ExportedFunctions = (Get-Module LicenseManager).ExportedFunctions.Keys
            foreach ($Function in $ExpectedFunctions) {
                $ExportedFunctions | Should -Contain $Function
            }
        }
    }

    Context "License Status - No License" {
        BeforeEach {
            # Ensure no license file exists
            if (Test-Path $script:TestLicensePath) {
                Remove-Item $script:TestLicensePath -Force
            }
        }

        It "Should return free tier when no license exists" {
            $Status = Get-LicenseStatus
            $Status.IsValid | Should -Be $false
            $Status.Tier | Should -Be "free"
            $Status.Features | Should -Contain "core"
            $Status.Features | Should -Contain "development"
            $Status.IssuedTo | Should -Be "Unlicensed"
        }
    }

    Context "License Installation" {
        BeforeEach {
            # Clean up any existing license
            if (Test-Path $script:TestLicensePath) {
                Remove-Item $script:TestLicensePath -Force
            }
        }

        It "Should install license from JSON string" {
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            $Result = Set-License -LicenseString $LicenseJson -Force

            $Result.Success | Should -Be $true
            $Result.Tier | Should -Be "pro"
            $Result.IssuedTo | Should -Be "Test User"

            # Verify license file was created
            Test-Path $script:TestLicensePath | Should -Be $true
        }

        It "Should install license from file" {
            # Create temporary license file
            $TempLicenseFile = Join-Path $script:TestLicenseDir "temp-license.json"
            $script:TestLicense | ConvertTo-Json -Depth 10 | Set-Content -Path $TempLicenseFile

            $Result = Set-License -LicensePath $TempLicenseFile -Force

            $Result.Success | Should -Be $true
            $Result.Tier | Should -Be "pro"

            # Clean up temp file
            Remove-Item $TempLicenseFile -Force
        }

        It "Should install license from base64 key" {
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Compress
            $LicenseKey = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($LicenseJson))

            $Result = Set-License -LicenseKey $LicenseKey -Force

            $Result.Success | Should -Be $true
            $Result.Tier | Should -Be "pro"
        }

        It "Should reject expired license" {
            $LicenseJson = $script:ExpiredLicense | ConvertTo-Json -Depth 10

            $Result = Set-License -LicenseString $LicenseJson -Force

            $Result.Success | Should -Be $false
            $Result.Error | Should -Match "expired"
        }

        It "Should reject invalid license format" {
            $Result = Set-License -LicenseString "invalid-json" -Force

            $Result.Success | Should -Be $false
            $Result.Error | Should -Match "format"
        }

        It "Should validate signature in strict mode" {
            # Create license with invalid signature
            $BadLicense = $script:TestLicense.Clone()
            $BadLicense.signature = "invalid-signature"
            $LicenseJson = $BadLicense | ConvertTo-Json -Depth 10

            $Result = Set-License -LicenseString $LicenseJson -StrictValidation -Force

            $Result.Success | Should -Be $false
            $Result.Error | Should -Match "signature"
        }
    }

    Context "License Validation" {
        BeforeEach {
            # Install a valid license
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            Set-License -LicenseString $LicenseJson -Force | Out-Null
        }

        It "Should return valid status for good license" {
            $Status = Get-LicenseStatus
            $Status.IsValid | Should -Be $true
            $Status.Tier | Should -Be "pro"
            $Status.Features | Should -Contain "core"
            $Status.Features | Should -Contain "infrastructure"
        }

        It "Should detect license corruption" {
            # Corrupt the license file
            "corrupted data" | Set-Content -Path $script:TestLicensePath

            $Status = Get-LicenseStatus
            $Status.IsValid | Should -Be $false
            $Status.Message | Should -Match "error"
        }
    }

    Context "Feature Access Testing" {
        BeforeEach {
            # Install pro license
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            Set-License -LicenseString $LicenseJson -Force | Out-Null
        }

        It "Should grant access to pro tier features" {
            Test-FeatureAccess -FeatureName "infrastructure" | Should -Be $true
            Test-FeatureAccess -FeatureName "ai" | Should -Be $true
            Test-FeatureAccess -FeatureName "automation" | Should -Be $true
        }

        It "Should deny access to enterprise features" {
            Test-FeatureAccess -FeatureName "security" | Should -Be $false
            Test-FeatureAccess -FeatureName "monitoring" | Should -Be $false
            Test-FeatureAccess -FeatureName "enterprise" | Should -Be $false
        }

        It "Should throw on denied access when requested" {
            { Test-FeatureAccess -FeatureName "security" -ThrowOnDenied } | Should -Throw
        }

        It "Should test module access" {
            Test-ModuleAccess -ModuleName "OpenTofuProvider" | Should -Be $true
            Test-ModuleAccess -ModuleName "SecureCredentials" | Should -Be $false
        }
    }

    Context "Feature Registry" {
        It "Should load feature registry" {
            InModuleScope LicenseManager {
                $Registry = Get-FeatureRegistry
                $Registry | Should -Not -BeNullOrEmpty
                $Registry.features | Should -Not -BeNullOrEmpty
                $Registry.tiers | Should -Not -BeNullOrEmpty
            }
        }

        It "Should get feature tier requirements" {
            Get-FeatureTier -Feature "core" | Should -Be "free"
            Get-FeatureTier -Feature "infrastructure" | Should -Be "pro"
            Get-FeatureTier -Feature "security" | Should -Be "enterprise"
        }
    }

    Context "Available Features" {
        BeforeEach {
            # Install pro license
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            Set-License -LicenseString $LicenseJson -Force | Out-Null
        }

        It "Should list available features" {
            $Features = Get-AvailableFeatures
            $Features | Should -Not -BeNullOrEmpty

            $AvailableFeatures = $Features | Where-Object IsAvailable -eq $true
            $AvailableFeatures.Name | Should -Contain "core"
            $AvailableFeatures.Name | Should -Contain "infrastructure"
        }

        It "Should include locked features when requested" {
            $AllFeatures = Get-AvailableFeatures -IncludeLocked
            $LockedFeatures = $AllFeatures | Where-Object IsAvailable -eq $false
            $LockedFeatures | Should -Not -BeNullOrEmpty
        }
    }

    Context "License Information" {
        BeforeEach {
            # Install pro license
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            Set-License -LicenseString $LicenseJson -Force | Out-Null
        }

        It "Should provide detailed license information" {
            $Info = Get-LicenseInfo
            $Info.Status | Should -Be "Valid"
            $Info.Tier | Should -Be "pro"
            $Info.IssuedTo | Should -Be "Test User"
            $Info.Features | Should -Contain "infrastructure"
        }
    }

    Context "License Clearing" {
        BeforeEach {
            # Install a license
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            Set-License -LicenseString $LicenseJson -Force | Out-Null
        }

        It "Should clear license and revert to free tier" {
            $Result = Clear-License -Force
            $Result | Should -Be $true

            $Status = Get-LicenseStatus
            $Status.Tier | Should -Be "free"
            $Status.IsValid | Should -Be $false
        }
    }

    Context "License Generation" {
        It "Should generate valid test licenses" {
            $LicenseKey = New-License -Tier "pro" -Email "test@example.com" -Days 365
            $LicenseKey | Should -Not -BeNullOrEmpty
            $LicenseKey.Length | Should -BeGreaterThan 50

            # Test that generated license can be installed
            $Result = Set-License -LicenseKey $LicenseKey -Force
            $Result.Success | Should -Be $true
            $Result.Tier | Should -Be "pro"
        }

        It "Should generate enterprise licenses with all features" {
            $LicenseKey = New-License -Tier "enterprise" -Email "admin@example.com" -Days 365
            $Result = Set-License -LicenseKey $LicenseKey -Force

            $Result.Success | Should -Be $true
            $Result.Tier | Should -Be "enterprise"
            $Result.Features | Should -Contain "security"
            $Result.Features | Should -Contain "monitoring"
        }
    }

    Context "Tier Access Logic" {
        It "Should correctly compare tier levels" {
            InModuleScope LicenseManager {
                Test-TierAccess -RequiredTier "free" -CurrentTier "pro" | Should -Be $true
                Test-TierAccess -RequiredTier "pro" -CurrentTier "free" | Should -Be $false
                Test-TierAccess -RequiredTier "enterprise" -CurrentTier "pro" | Should -Be $false
                Test-TierAccess -RequiredTier "pro" -CurrentTier "enterprise" | Should -Be $true
            }
        }

        It "Should handle unknown tiers gracefully" {
            InModuleScope LicenseManager {
                Test-TierAccess -RequiredTier "unknown" -CurrentTier "pro" | Should -Be $true
                Test-TierAccess -RequiredTier "pro" -CurrentTier "unknown" | Should -Be $false
            }
        }
    }

    Context "Security Validation" {
        It "Should detect signatures with insufficient entropy" {
            InModuleScope LicenseManager {
                Test-SignatureFormat -Signature "AAAAAAA=" | Should -Be $false
                Test-SignatureFormat -Signature "1111111=" | Should -Be $false
                Test-SignatureFormat -Signature "SGVsbG8gV29ybGQ=" | Should -Be $true
            }
        }

        It "Should validate license integrity" {
            InModuleScope LicenseManager {
                $ValidLicense = $script:TestLicense
                Test-LicenseIntegrity -License ([PSCustomObject]$ValidLicense) | Should -Be $true

                $InvalidLicense = $script:InvalidLicense
                Test-LicenseIntegrity -License ([PSCustomObject]$InvalidLicense) | Should -Be $false
            }
        }

        It "Should validate canonical license data creation" {
            InModuleScope LicenseManager {
                $TestLicense = $script:TestLicense
                $CanonicalData = Get-CanonicalLicenseData -License ([PSCustomObject]$TestLicense)

                $CanonicalData | Should -Match "licenseId:"
                $CanonicalData | Should -Match "tier:"
                $CanonicalData | Should -Match "issuedTo:"
                $CanonicalData | Should -Match "expiryDate:"
                $CanonicalData | Should -Match "features:"
            }
        }
    }

    Context "Error Handling" {
        It "Should handle missing license file gracefully" {
            # Ensure no license exists
            if (Test-Path $script:TestLicensePath) {
                Remove-Item $script:TestLicensePath -Force
            }

            { Get-LicenseStatus } | Should -Not -Throw
            $Status = Get-LicenseStatus
            $Status.Tier | Should -Be "free"
        }

        It "Should handle corrupted license files" {
            "invalid json content" | Set-Content -Path $script:TestLicensePath

            { Get-LicenseStatus } | Should -Not -Throw
            $Status = Get-LicenseStatus
            $Status.IsValid | Should -Be $false
        }

        It "Should handle feature access with invalid license" {
            # Remove license
            if (Test-Path $script:TestLicensePath) {
                Remove-Item $script:TestLicensePath -Force
            }

            { Test-FeatureAccess -FeatureName "infrastructure" } | Should -Not -Throw
            Test-FeatureAccess -FeatureName "infrastructure" | Should -Be $false
        }
    }

    Context "Performance" {
        It "Should complete license operations within reasonable time" {
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Install license
            $LicenseJson = $script:TestLicense | ConvertTo-Json -Depth 10
            Set-License -LicenseString $LicenseJson -Force | Out-Null

            # Check status
            Get-LicenseStatus | Out-Null

            # Test feature access multiple times
            for ($i = 0; $i -lt 10; $i++) {
                Test-FeatureAccess -FeatureName "infrastructure" | Out-Null
            }

            $Stopwatch.Stop()
            $Stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
        }
    }
}
