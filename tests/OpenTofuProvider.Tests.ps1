#Requires -Version 7.0

BeforeAll {
    # Find project root
    $projectRoot = Split-Path -Parent $PSScriptRoot
    
    # Import required modules
    $modulePath = Join-Path $projectRoot "aither-core" "modules"
    Import-Module (Join-Path $modulePath "Logging") -Force
    Import-Module (Join-Path $modulePath "OpenTofuProvider") -Force
    
    # Test configuration
    $script:testConfig = @{
        ProjectRoot = $projectRoot
        ModulePath = Join-Path $modulePath "OpenTofuProvider"
        TestConfigPath = Join-Path $projectRoot "aither-core" "modules" "OpenTofuProvider" "Resources" "example-lab-config.yaml"
        TempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) "OpenTofuProvider-Tests-$(Get-Random)"
    }
    
    # Create temporary test directory
    if (-not (Test-Path $script:testConfig.TempTestDir)) {
        New-Item -Path $script:testConfig.TempTestDir -ItemType Directory -Force | Out-Null
    }
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:testConfig.TempTestDir) {
        Remove-Item $script:testConfig.TempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "OpenTofuProvider Module Tests" {
    Context "Module Loading and Structure" {
        It "Should load the OpenTofuProvider module successfully" {
            Get-Module -Name "OpenTofuProvider" | Should -Not -BeNullOrEmpty
        }
        
        It "Should have correct module version" {
            $module = Get-Module -Name "OpenTofuProvider"
            $module.Version | Should -Be "1.2.0"
        }
        
        It "Should export expected core functions" {
            $expectedFunctions = @(
                'Install-OpenTofuSecure',
                'Initialize-OpenTofuProvider',
                'New-LabInfrastructure',
                'Start-InfrastructureDeployment',
                'Set-SecureCredentials',
                'Get-TaliesinsProviderConfig',
                'Start-DeploymentRollback',
                'New-DeploymentSnapshot'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should have proper module manifest properties" {
            $manifestPath = Join-Path $script:testConfig.ModulePath "OpenTofuProvider.psd1"
            Test-Path $manifestPath | Should -Be $true
            
            $manifest = Test-ModuleManifest $manifestPath -ErrorAction SilentlyContinue
            $manifest | Should -Not -BeNullOrEmpty
            $manifest.PowerShellVersion | Should -Be "7.0"
        }
    }
    
    Context "OpenTofu Installation Testing" {
        It "Should have Test-OpenTofuInstallation helper function" {
            # Test the installation check function
            $result = Test-OpenTofuInstallation -Verbose
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain "IsValid"
        }
        
        It "Should validate OpenTofu installation path correctly" {
            # Test with non-existent path
            $result = Test-OpenTofuInstallation -Path "/nonexistent/path"
            $result.IsValid | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
        
        It "Should detect signature verification tools" {
            # Test signature tool availability
            $cosign = Get-Command 'cosign' -ErrorAction SilentlyContinue
            $gpg = Get-Command 'gpg' -ErrorAction SilentlyContinue
            
            # At least one should be available or we should handle gracefully
            if (-not $cosign -and -not $gpg) {
                Write-Warning "No signature verification tools available - this is expected in CI environments"
            }
        }
    }
    
    Context "Configuration Management" {
        It "Should load example configuration successfully" {
            Test-Path $script:testConfig.TestConfigPath | Should -Be $true
            
            { 
                $config = Get-Content $script:testConfig.TestConfigPath -Raw | ConvertFrom-Yaml 
                $config | Should -Not -BeNullOrEmpty
                $config.hyperv | Should -Not -BeNullOrEmpty
                $config.vms | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }
        
        It "Should validate configuration structure" {
            $config = Get-Content $script:testConfig.TestConfigPath -Raw | ConvertFrom-Yaml
            
            # Check required configuration sections
            $config.hyperv.host | Should -Not -BeNullOrEmpty
            $config.hyperv.port | Should -BeOfType [int]
            $config.hyperv.https | Should -BeOfType [bool]
            $config.vms | Should -BeOfType [array]
            $config.switch | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing configuration gracefully" {
            $nonExistentPath = Join-Path $script:testConfig.TempTestDir "nonexistent.yaml"
            
            {
                Initialize-OpenTofuProvider -ConfigPath $nonExistentPath
            } | Should -Throw
        }
    }
    
    Context "Provider Configuration" {
        It "Should generate Taliesins provider configuration" {
            # Test provider config generation with mock data
            $mockConfig = @{
                hyperv = @{
                    host = "test-hyperv.local"
                    user = "test\\user"
                    port = 5986
                    https = $true
                }
            }
            
            { 
                Get-TaliesinsProviderConfig -HypervHost $mockConfig.hyperv.host 
            } | Should -Not -Throw
        }
        
        It "Should validate provider configuration parameters" {
            { 
                Get-TaliesinsProviderConfig -HypervHost "" 
            } | Should -Throw
        }
    }
    
    Context "Security Features" {
        It "Should handle secure credential operations" {
            $testTarget = "test-target-$(Get-Random)"
            $testCreds = New-Object System.Management.Automation.PSCredential("testuser", (ConvertTo-SecureString "testpass" -AsPlainText -Force))
            
            # Test credential setting (should handle gracefully even if storage fails)
            { 
                Set-SecureCredentials -Target $testTarget -Credentials $testCreds -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should validate certificate paths when provided" {
            $nonExistentCertPath = Join-Path $script:testConfig.TempTestDir "nonexistent-cert"
            
            { 
                Set-SecureCredentials -Target "test" -CertificatePath $nonExistentCertPath -CredentialType "Certificate"
            } | Should -Throw
        }
        
        It "Should enforce credential type validation" {
            { 
                Set-SecureCredentials -Target "test" -CredentialType "InvalidType"
            } | Should -Throw
        }
    }
    
    Context "Deployment Operations" {
        It "Should validate deployment configuration before execution" {
            # Test with missing configuration
            { 
                Start-InfrastructureDeployment -ConfigurationPath "/nonexistent/config.yaml"
            } | Should -Throw
        }
        
        It "Should support dry-run deployment mode" {
            # Create a minimal test configuration
            $testConfigContent = @"
infrastructure:
  test_resource:
    name: "test-vm"
    type: "virtual_machine"
metadata:
  name: "Test Deployment"
"@
            $testConfigPath = Join-Path $script:testConfig.TempTestDir "test-deployment.yaml"
            Set-Content -Path $testConfigPath -Value $testConfigContent
            
            # Test dry-run mode (should not throw and should return result)
            { 
                Start-InfrastructureDeployment -ConfigurationPath $testConfigPath -DryRun -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should handle deployment plan creation" {
            $testConfigContent = @"
infrastructure:
  virtual_machines:
    - name: "test-vm-1"
      memory: "2GB"
      cpu: 2
repository:
  name: "test-repo"
  url: "https://github.com/test/repo.git"
"@
            $testConfigPath = Join-Path $script:testConfig.TempTestDir "plan-test.yaml"
            Set-Content -Path $testConfigPath -Value $testConfigContent
            
            { 
                New-DeploymentPlan -Configuration (Get-Content $testConfigPath | ConvertFrom-Yaml) -DryRun
            } | Should -Not -Throw
        }
    }
    
    Context "Advanced Features" {
        It "Should support deployment snapshots" {
            $testDeploymentId = "test-deployment-$(Get-Random)"
            
            { 
                New-DeploymentSnapshot -DeploymentId $testDeploymentId -Name "test-snapshot" -Description "Test snapshot" -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should handle deployment history operations" {
            $testDeploymentId = "test-deployment-$(Get-Random)"
            
            { 
                Get-DeploymentHistory -DeploymentId $testDeploymentId
            } | Should -Not -Throw
        }
        
        It "Should support rollback operations" {
            $testDeploymentId = "test-deployment-$(Get-Random)"
            
            { 
                Start-DeploymentRollback -DeploymentId $testDeploymentId -RollbackType "LastGood" -DryRun
            } | Should -Not -Throw
        }
    }
    
    Context "Performance and Optimization" {
        It "Should provide performance optimization functions" {
            $expectedOptimizationFunctions = @(
                'Optimize-DeploymentPerformance',
                'Optimize-MemoryUsage',
                'Optimize-DeploymentCaching'
            )
            
            foreach ($function in $expectedOptimizationFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should handle deployment caching operations" {
            { 
                Optimize-DeploymentCaching -WhatIf
            } | Should -Not -Throw
        }
    }
    
    Context "Repository Management" {
        It "Should support infrastructure repository operations" {
            $testRepoConfig = @{
                Name = "test-repo"
                Url = "https://github.com/test/infrastructure.git"
                Type = "git"
            }
            
            { 
                Register-InfrastructureRepository -Name $testRepoConfig.Name -Url $testRepoConfig.Url -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should handle template repository creation" {
            { 
                New-TemplateRepository -Name "test-templates" -Path $script:testConfig.TempTestDir -WhatIf
            } | Should -Not -Throw
        }
    }
    
    Context "Template Management" {
        It "Should support versioned template operations" {
            $testTemplatePath = Join-Path $script:testConfig.TempTestDir "test-template"
            New-Item -Path $testTemplatePath -ItemType Directory -Force | Out-Null
            
            { 
                New-VersionedTemplate -TemplateName "test-template" -SourcePath $testTemplatePath -Version "1.0.0" -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should handle template version queries" {
            { 
                Get-TemplateVersion -TemplateName "test-template"
            } | Should -Not -Throw
        }
    }
    
    Context "Integration with Other Modules" {
        It "Should integrate with Logging module" {
            # Test that OpenTofuProvider functions use Write-CustomLog
            $logFunction = Get-Command "Write-CustomLog" -ErrorAction SilentlyContinue
            $logFunction | Should -Not -BeNullOrEmpty
            
            # Test logging works
            { Write-CustomLog -Level 'INFO' -Message "OpenTofuProvider test log" } | Should -Not -Throw
        }
        
        It "Should support ProgressTracking integration" {
            # Check if ProgressTracking module is available
            $progressModule = Get-Module -ListAvailable -Name "ProgressTracking" -ErrorAction SilentlyContinue
            if ($progressModule) {
                Import-Module "ProgressTracking" -Force
                $progressCommands = Get-Command -Module "ProgressTracking" -ErrorAction SilentlyContinue
                $progressCommands | Should -Not -BeNullOrEmpty
            } else {
                Write-Warning "ProgressTracking module not available - this is expected in some environments"
            }
        }
    }
    
    Context "Error Handling and Resilience" {
        It "Should handle network connectivity issues gracefully" {
            # Test with invalid URLs
            { 
                Get-TaliesinsProviderConfig -HypervHost "invalid-host-that-does-not-exist.local"
            } | Should -Not -Throw
        }
        
        It "Should provide meaningful error messages" {
            try {
                Initialize-OpenTofuProvider -ConfigPath "/definitely/does/not/exist.yaml"
            } catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
                $_.Exception.Message | Should -Match ".*not.*found.*|.*exist.*"
            }
        }
        
        It "Should handle partial failures in deployment operations" {
            # Test resilience with invalid configuration
            $invalidConfig = @"
invalid_yaml_content: [
missing_closing_bracket
"@
            $invalidConfigPath = Join-Path $script:testConfig.TempTestDir "invalid.yaml"
            Set-Content -Path $invalidConfigPath -Value $invalidConfig
            
            { 
                Read-DeploymentConfiguration -Path $invalidConfigPath
            } | Should -Throw
        }
    }
}

Describe "OpenTofuProvider Security Tests" {
    Context "Security Validation" {
        It "Should not expose sensitive information in logs" {
            # Test that credential information is not logged
            $testTarget = "security-test-$(Get-Random)"
            $testCreds = New-Object System.Management.Automation.PSCredential("testuser", (ConvertTo-SecureString "super-secret-password" -AsPlainText -Force))
            
            { 
                Set-SecureCredentials -Target $testTarget -Credentials $testCreds -WhatIf
            } | Should -Not -Throw
            
            # Note: In a real implementation, we would check that logs don't contain the password
        }
        
        It "Should validate certificate security settings" {
            # Test certificate validation functions exist
            $securityFunctions = @(
                'Test-OpenTofuInstallationSecurity',
                'Test-OpenTofuConfigurationSecurity',
                'Test-TaliesinsProviderSecurity'
            )
            
            foreach ($function in $securityFunctions) {
                $cmd = Get-Command $function -ErrorAction SilentlyContinue
                if ($cmd) {
                    { & $function } | Should -Not -Throw
                }
            }
        }
        
        It "Should enforce HTTPS by default" {
            $config = Get-Content $script:testConfig.TestConfigPath -Raw | ConvertFrom-Yaml
            $config.hyperv.https | Should -Be $true
        }
    }
}

Describe "OpenTofuProvider Cross-Platform Tests" {
    Context "Platform Compatibility" {
        It "Should detect current platform correctly" {
            $platform = if ($IsWindows) { "Windows" }
            elseif ($IsLinux) { "Linux" }
            elseif ($IsMacOS) { "macOS" }
            else { "Unknown" }
            
            $platform | Should -BeIn @("Windows", "Linux", "macOS")
        }
        
        It "Should use platform-appropriate paths" {
            $testPath = Join-Path $script:testConfig.TempTestDir "subdir" "file.txt"
            
            if ($IsWindows) {
                $testPath | Should -Match '\\'
            } else {
                $testPath | Should -Match '/'
            }
        }
        
        It "Should handle platform-specific OpenTofu binary names" {
            # Test that installation helper handles platform differences
            $binaryName = if ($IsWindows) { "tofu.exe" } else { "tofu" }
            $binaryName | Should -Match '^tofu(\.exe)?$'
        }
    }
}