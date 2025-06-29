BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/ISOManager") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/ISOCustomizer") -Force
    
    # Set up test environment
    $env:PROJECT_ROOT = $TestDrive
    
    # Create directory structure
    $deploymentsDir = Join-Path $TestDrive "deployments"
    $repositoriesDir = Join-Path $TestDrive "repositories"
    $isosDir = Join-Path $TestDrive "isos"
    
    New-Item -Path $deploymentsDir -ItemType Directory -Force | Out-Null
    New-Item -Path $repositoriesDir -ItemType Directory -Force | Out-Null
    New-Item -Path $isosDir -ItemType Directory -Force | Out-Null
    
    # Create test repository
    $script:testRepoName = "test-hyper-v-infrastructure"
    $script:testRepoPath = Join-Path $repositoriesDir $script:testRepoName
    New-Item -Path $script:testRepoPath -ItemType Directory -Force | Out-Null
    
    # Create test template files
    $templateConfig = @{
        version = "1.0"
        template = @{
            name = "hyper-v-vm"
            version = "1.0.0"
            description = "Basic Hyper-V virtual machine"
            provider = "hyperv"
        }
        dependencies = @{}
        infrastructure = @{
            virtual_machine = @{
                name = "test-vm-01"
                memory_mb = 2048
                cpu_count = 2
                disk_size_gb = 40
                network_adapter = "Default Switch"
                os_type = "windows"
                iso_path = "windows-server-2022.iso"
            }
        }
        configuration = @{
            auto_start = $true
            enable_nested_virtualization = $false
            enable_secure_boot = $true
        }
    }
    $templateConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:testRepoPath "infrastructure-template.json")
    
    # Create template metadata
    $templateMeta = @{
        name = "hyper-v-vm"
        version = "1.0.0"
        description = "Basic Hyper-V virtual machine template"
        author = "AitherZero Test Suite"
        created = Get-Date
        dependencies = @()
        tags = @("hyper-v", "windows", "vm")
        changelog = @(
            @{
                version = "1.0.0"
                date = Get-Date
                changes = @("Initial template version")
            }
        )
    }
    $templateMeta | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:testRepoPath "template-metadata.json")
    
    # Create test configuration file
    $script:testConfigPath = Join-Path $TestDrive "test-deployment-config.yaml"
    $configContent = @"
version: "1.0"
repository:
  name: "$($script:testRepoName)"
  version: "1.0.0"
  source: "local"
template:
  name: "hyper-v-vm"
  version: "1.0.0"
infrastructure:
  virtual_machine:
    name: "integration-test-vm"
    memory_mb: 4096
    cpu_count: 4
    disk_size_gb: 60
    network_adapter: "Default Switch"
    os_type: "windows"
    iso_path: "windows-server-2022.iso"
deployment:
  auto_approve: true
  parallel_execution: false
  backup_before_deploy: true
  validate_before_apply: true
"@
    $configContent | Set-Content -Path $script:testConfigPath
    
    # Mock external dependencies
    Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName OpenTofuProvider
    Mock Test-Path { 
        param($Path)
        if ($Path -like "*tofu*" -or $Path -like "*terraform*") {
            return $true
        }
        return $false
    } -ParameterFilter { $Path -like "*tofu*" -or $Path -like "*terraform*" } -ModuleName OpenTofuProvider
    
    Mock Get-Command { 
        return @{ Source = "C:\Tools\tofu.exe" }
    } -ParameterFilter { $Name -eq "tofu" } -ModuleName OpenTofuProvider
}

Describe "End-to-End OpenTofu Provider Integration Tests" {
    
    Context "Complete Deployment Workflow" {
        It "Should execute full deployment lifecycle successfully" {
            # Step 1: Register repository
            $repoResult = Register-InfrastructureRepository -Name $script:testRepoName -Source $script:testRepoPath -Type "Local"
            $repoResult.Success | Should -Be $true
            
            # Step 2: Validate repository compatibility
            $compatResult = Test-RepositoryCompatibility -Name $script:testRepoName
            $compatResult.IsCompatible | Should -Be $true
            
            # Step 3: Read and validate configuration
            $configResult = Read-DeploymentConfiguration -Path $script:testConfigPath
            $configResult.Success | Should -Be $true
            $configResult.Configuration.infrastructure.virtual_machine.name | Should -Be "integration-test-vm"
            
            # Step 4: Initialize ISOs (if needed)
            $isoResult = Initialize-DeploymentISOs -ConfigurationPath $script:testConfigPath
            $isoResult.Success | Should -Be $true
            
            # Step 5: Create deployment plan
            $planResult = New-DeploymentPlan -ConfigurationPath $script:testConfigPath -PlanName "integration-test-plan"
            $planResult.Success | Should -Be $true
            $planResult.Plan.Stages | Should -HaveCount 4  # Prepare, Validate, Plan, Apply
            
            # Step 6: Start infrastructure deployment
            $deployResult = Start-InfrastructureDeployment -ConfigurationPath $script:testConfigPath -PlanName "integration-test-plan"
            $deployResult.Success | Should -Be $true
            $deployResult.DeploymentId | Should -Not -BeNullOrEmpty
            
            # Step 7: Check deployment status
            $statusResult = Get-DeploymentStatus -DeploymentId $deployResult.DeploymentId
            $statusResult.Success | Should -Be $true
            $statusResult.Status | Should -BeIn @("Completed", "Running")
            
            # Store deployment ID for subsequent tests
            $script:testDeploymentId = $deployResult.DeploymentId
        }
        
        It "Should handle drift detection after deployment" {
            # Test drift detection on completed deployment
            $driftResult = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId
            $driftResult | Should -Not -BeNullOrEmpty
            $driftResult.Summary | Should -Not -BeNullOrEmpty
        }
        
        It "Should create and manage snapshots" {
            # Create deployment snapshot
            $snapshotResult = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "integration-test-snapshot" -Description "End-to-end test snapshot"
            $snapshotResult.Success | Should -Be $true
            $snapshotResult.SnapshotName | Should -Be "integration-test-snapshot"
            
            # Retrieve snapshot
            $getSnapshotResult = Get-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "integration-test-snapshot"
            $getSnapshotResult | Should -Not -BeNullOrEmpty
            $getSnapshotResult.Name | Should -Be "integration-test-snapshot"
        }
        
        It "Should track deployment history" {
            # Get deployment history
            $historyResult = Get-DeploymentHistory -DeploymentId $script:testDeploymentId
            $historyResult | Should -Not -BeNullOrEmpty
            $historyResult[0].DeploymentId | Should -Be $script:testDeploymentId
        }
        
        It "Should handle deployment automation configuration" {
            # Configure deployment automation
            $automationResult = Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Monitoring" -EnableDriftDetection
            $automationResult.Success | Should -Be $true
            $automationResult.EnabledFeatures | Should -Contain "DriftDetection"
            
            # Get automation info
            $automationInfo = Get-DeploymentAutomation -DeploymentId $script:testDeploymentId
            $automationInfo | Should -Not -BeNullOrEmpty
            $automationInfo[0].AutomationType | Should -Be "Monitoring"
            
            # Stop automation
            $stopResult = Stop-DeploymentAutomation -DeploymentId $script:testDeploymentId
            $stopResult.Success | Should -Be $true
        }
    }
    
    Context "Repository Management Integration" {
        It "Should handle repository lifecycle operations" {
            # Test repository sync
            $syncResult = Sync-InfrastructureRepository -Name $script:testRepoName
            $syncResult.Success | Should -Be $true
            
            # Test repository status
            $repoStatus = Get-InfrastructureRepository -Name $script:testRepoName
            $repoStatus | Should -Not -BeNullOrEmpty
            $repoStatus.Name | Should -Be $script:testRepoName
            $repoStatus.Status | Should -BeIn @("Ready", "Synced")
        }
        
        It "Should handle template versioning" {
            # Get template version info
            $versionResult = Get-TemplateVersion -RepositoryName $script:testRepoName -TemplateName "hyper-v-vm"
            $versionResult.Success | Should -Be $true
            $versionResult.CurrentVersion | Should -Be "1.0.0"
        }
    }
    
    Context "Provider Integration" {
        It "Should register and validate Hyper-V provider" {
            # Register Hyper-V provider
            $providerResult = Register-InfrastructureProvider -Name "Hyper-V" -Type "hyperv" -ConfigurationPath $script:testConfigPath
            $providerResult.Success | Should -Be $true
            
            # Test provider capabilities
            $capabilityResult = Test-ProviderCapability -ProviderName "Hyper-V" -Capability "VirtualMachine"
            $capabilityResult.IsSupported | Should -Be $true
            
            # Validate provider configuration
            $configValidation = Test-ProviderConfiguration -ProviderName "Hyper-V" -Configuration @{ test = "value" }
            $configValidation.IsValid | Should -Be $true
        }
    }
    
    Context "Error Handling and Recovery" {
        It "Should handle deployment failures gracefully" {
            # Create invalid configuration to test error handling
            $invalidConfig = @{
                version = "1.0"
                repository = @{ name = "non-existent-repo" }
                infrastructure = @{
                    virtual_machine = @{
                        name = "invalid-vm"
                        memory_mb = -1  # Invalid value
                    }
                }
            }
            $invalidConfigPath = Join-Path $TestDrive "invalid-config.json"
            $invalidConfig | ConvertTo-Json | Set-Content -Path $invalidConfigPath
            
            # Should fail validation
            { Read-DeploymentConfiguration -Path $invalidConfigPath } | Should -Throw
        }
        
        It "Should handle rollback operations" {
            # Test rollback functionality (dry run)
            $rollbackResult = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -RollbackType "LastGood" -DryRun
            $rollbackResult.Success | Should -Be $true
            $rollbackResult.DryRun | Should -Be $true
        }
    }
    
    Context "Performance and Scalability" {
        It "Should handle multiple concurrent operations" {
            # Test concurrent snapshot creation
            $jobs = @()
            
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($DeploymentId, $SnapshotName, $ProjectRoot)
                    
                    $env:PROJECT_ROOT = $ProjectRoot
                    Import-Module (Join-Path $ProjectRoot "aither-core/modules/OpenTofuProvider") -Force
                    
                    New-DeploymentSnapshot -DeploymentId $DeploymentId -Name $SnapshotName -Description "Concurrent test snapshot"
                } -ArgumentList $script:testDeploymentId, "concurrent-snapshot-$i", $projectRoot
            }
            
            # Wait for all jobs to complete
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # Verify all snapshots were created successfully
            $results | Should -HaveCount 3
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
        
        It "Should efficiently handle large configuration files" {
            # Create a large configuration with multiple resources
            $largeConfig = @{
                version = "1.0"
                repository = @{ name = $script:testRepoName; version = "1.0.0" }
                template = @{ name = "hyper-v-vm" }
                infrastructure = @{
                    virtual_machine = @()
                }
            }
            
            # Add 10 VMs to test performance
            for ($i = 1; $i -le 10; $i++) {
                $largeConfig.infrastructure.virtual_machine += @{
                    name = "perf-test-vm-$i"
                    memory_mb = 2048
                    cpu_count = 2
                    disk_size_gb = 40
                }
            }
            
            $largeConfigPath = Join-Path $TestDrive "large-config.json"
            $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $largeConfigPath
            
            # Measure configuration reading performance
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $configResult = Read-DeploymentConfiguration -Path $largeConfigPath
            $stopwatch.Stop()
            
            $configResult.Success | Should -Be $true
            $configResult.Configuration.infrastructure.virtual_machine | Should -HaveCount 10
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete within 5 seconds
        }
    }
    
    Context "Resource Cleanup" {
        It "Should clean up test resources" {
            # Remove test snapshots
            $snapshots = Get-DeploymentSnapshot -DeploymentId $script:testDeploymentId -ListOnly
            foreach ($snapshot in $snapshots) {
                Remove-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name $snapshot.Name -Force
            }
            
            # Verify cleanup
            $remainingSnapshots = Get-DeploymentSnapshot -DeploymentId $script:testDeploymentId -ListOnly
            $remainingSnapshots | Should -BeNullOrEmpty
        }
    }
}

Describe "Cross-Module Integration Tests" {
    
    Context "OpenTofuProvider and ISOManager Integration" {
        It "Should integrate with ISOManager for deployment requirements" {
            # Mock ISOManager functions
            Mock Get-ISOInventory { 
                return @(
                    @{
                        Name = "windows-server-2022.iso"
                        Path = Join-Path $TestDrive "isos/windows-server-2022.iso"
                        IsAvailable = $true
                        Checksum = "abc123"
                    }
                )
            } -ModuleName OpenTofuProvider
            
            Mock Test-ISOCompatibility {
                return @{
                    IsCompatible = $true
                    RequiredISOs = @("windows-server-2022.iso")
                    AvailableISOs = @("windows-server-2022.iso")
                    MissingISOs = @()
                }
            } -ModuleName OpenTofuProvider
            
            # Test ISO requirements check
            $isoResult = Test-ISORequirements -ConfigurationPath $script:testConfigPath
            $isoResult.IsCompatible | Should -Be $true
            $isoResult.MissingISOs | Should -HaveCount 0
        }
    }
    
    Context "OpenTofuProvider and Logging Integration" {
        It "Should properly integrate with logging system" {
            # Test that logging calls are made during operations
            Mock Write-CustomLog {} -ModuleName OpenTofuProvider
            
            # Perform operation that should generate logs
            $configResult = Read-DeploymentConfiguration -Path $script:testConfigPath
            
            # Verify logging was called
            Should -Invoke Write-CustomLog -ModuleName OpenTofuProvider -AtLeast 1
        }
    }
}

AfterAll {
    # Restore environment
    if ($script:originalProjectRoot) {
        $env:PROJECT_ROOT = $script:originalProjectRoot
    } else {
        Remove-Item Env:PROJECT_ROOT -ErrorAction SilentlyContinue
    }
}