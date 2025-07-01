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
    $cacheDir = Join-Path $TestDrive "cache"
    
    New-Item -Path $deploymentsDir -ItemType Directory -Force | Out-Null
    New-Item -Path $repositoriesDir -ItemType Directory -Force | Out-Null
    New-Item -Path $isosDir -ItemType Directory -Force | Out-Null
    New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
    
    # Global test variables
    $script:testRepoName = "comprehensive-test-repo"
    $script:testDeploymentId = $null
    $script:testSnapshotName = "integration-test-snapshot"
    
    # Mock external dependencies
    Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName OpenTofuProvider
    Mock Test-Path { 
        param($Path)
        if ($Path -like "*tofu*" -or $Path -like "*terraform*") {
            return $true
        }
        return (Test-Path $Path)
    } -ParameterFilter { $Path -like "*tofu*" -or $Path -like "*terraform*" } -ModuleName OpenTofuProvider
    
    Mock Get-Command { 
        return @{ Source = "C:\Tools\tofu.exe" }
    } -ParameterFilter { $Name -eq "tofu" } -ModuleName OpenTofuProvider
    
    Mock Get-CimInstance {
        param([string]$ClassName)
        switch ($ClassName) {
            'Win32_OperatingSystem' {
                return @{
                    FreePhysicalMemory = 8388608  # 8GB in KB
                    TotalVisibleMemorySize = 16777216  # 16GB in KB
                }
            }
            'Win32_Processor' {
                return @{
                    NumberOfLogicalProcessors = 8
                    LoadPercentage = 25
                }
            }
            'Win32_LogicalDisk' {
                return @{
                    DeviceID = "C:"
                    Size = 500GB
                    FreeSpace = 200GB
                }
            }
        }
    } -ModuleName OpenTofuProvider
}

Describe "Comprehensive OpenTofu Provider Integration Tests" {
    
    Context "Module Infrastructure and Setup" {
        It "Should have all required functions exported" {
            $module = Get-Module OpenTofuProvider
            $module | Should -Not -BeNullOrEmpty
            
            # Verify key function categories are present
            $functions = $module.ExportedFunctions.Keys
            
            # Repository Management
            $functions | Should -Contain 'Register-InfrastructureRepository'
            $functions | Should -Contain 'Sync-InfrastructureRepository'
            
            # Template Management
            $functions | Should -Contain 'New-VersionedTemplate'
            $functions | Should -Contain 'Get-TemplateVersion'
            
            # Deployment Orchestration
            $functions | Should -Contain 'Start-InfrastructureDeployment'
            $functions | Should -Contain 'New-DeploymentPlan'
            
            # Advanced Features
            $functions | Should -Contain 'Test-InfrastructureDrift'
            $functions | Should -Contain 'Start-DeploymentRollback'
            $functions | Should -Contain 'New-DeploymentSnapshot'
            
            # Performance Optimization
            $functions | Should -Contain 'Optimize-DeploymentPerformance'
            $functions | Should -Contain 'Test-ConcurrentDeployments'
            $functions | Should -Contain 'Optimize-MemoryUsage'
            $functions | Should -Contain 'Optimize-DeploymentCaching'
        }
        
        It "Should initialize cache infrastructure properly" {
            $cacheResult = Optimize-DeploymentCaching -ConfigurationPath (Join-Path $TestDrive "test-config.yaml") -CacheStrategy "Conservative"
            
            # Cache directory should be created
            $cacheDir = Join-Path $TestDrive "cache"
            Test-Path $cacheDir | Should -Be $true
            
            # Global cache manager should be initialized
            $global:OpenTofuCacheManager | Should -Not -BeNullOrEmpty
            $global:OpenTofuCacheManager.Initialized | Should -Be $true
        }
    }
    
    Context "Repository and Template Workflow" {
        BeforeAll {
            # Create test repository structure
            $script:testRepoPath = Join-Path $repositoriesDir $script:testRepoName
            New-Item -Path $script:testRepoPath -ItemType Directory -Force | Out-Null
            
            # Create repository metadata
            $repoMetadata = @{
                name = $script:testRepoName
                version = "1.0.0"
                description = "Comprehensive integration test repository"
                created = Get-Date
                templates = @("hyper-v-vm", "hyper-v-network")
                compatibility = @{
                    opentofu_version = ">=1.6.0"
                    provider_versions = @{
                        hyperv = ">=1.0.0"
                    }
                }
            }
            $repoMetadata | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:testRepoPath "repository.json")
            
            # Create template files
            $templateConfig = @{
                version = "1.0"
                template = @{
                    name = "hyper-v-vm"
                    version = "1.0.0"
                    description = "Comprehensive Hyper-V VM template"
                }
                infrastructure = @{
                    virtual_machine = @{
                        name = "integration-test-vm"
                        memory_mb = 4096
                        cpu_count = 4
                        disk_size_gb = 80
                    }
                }
            }
            $templateConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:testRepoPath "hyper-v-vm.json")
        }
        
        It "Should register repository successfully" {
            $repoResult = Register-InfrastructureRepository -Name $script:testRepoName -Source $script:testRepoPath -Type "Local"
            
            $repoResult | Should -Not -BeNullOrEmpty
            $repoResult.Success | Should -Be $true
            $repoResult.Repository.Name | Should -Be $script:testRepoName
        }
        
        It "Should validate repository compatibility" {
            $compatResult = Test-RepositoryCompatibility -Name $script:testRepoName
            
            $compatResult | Should -Not -BeNullOrEmpty
            $compatResult.IsCompatible | Should -Be $true
            $compatResult.RequiredProviders | Should -Contain "hyperv"
        }
        
        It "Should sync repository" {
            $syncResult = Sync-InfrastructureRepository -Name $script:testRepoName
            
            $syncResult | Should -Not -BeNullOrEmpty
            $syncResult.Success | Should -Be $true
            $syncResult.SyncType | Should -BeIn @("Full", "Incremental")
        }
        
        It "Should get template version information" {
            $versionResult = Get-TemplateVersion -RepositoryName $script:testRepoName -TemplateName "hyper-v-vm"
            
            $versionResult | Should -Not -BeNullOrEmpty
            $versionResult.Success | Should -Be $true
            $versionResult.CurrentVersion | Should -Be "1.0.0"
        }
    }
    
    Context "Configuration and Deployment Workflow" {
        BeforeAll {
            # Create comprehensive deployment configuration
            $script:testConfigPath = Join-Path $TestDrive "comprehensive-deployment-config.yaml"
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
    - name: "integration-vm-01"
      memory_mb: 4096
      cpu_count: 4
      disk_size_gb: 80
      network_adapter: "Default Switch"
    - name: "integration-vm-02"
      memory_mb: 2048
      cpu_count: 2
      disk_size_gb: 40
      network_adapter: "Default Switch"
deployment:
  auto_approve: true
  parallel_execution: true
  backup_before_deploy: true
  validate_before_apply: true
  max_parallel_jobs: 2
performance:
  enable_caching: true
  cache_strategy: "balanced"
  memory_optimization: true
  enable_monitoring: true
"@
            $configContent | Set-Content -Path $script:testConfigPath
        }
        
        It "Should read and validate deployment configuration" {
            $configResult = Read-DeploymentConfiguration -Path $script:testConfigPath
            
            $configResult | Should -Not -BeNullOrEmpty
            $configResult.Success | Should -Be $true
            $configResult.Configuration.infrastructure.virtual_machine | Should -HaveCount 2
            $configResult.Configuration.deployment.parallel_execution | Should -Be $true
        }
        
        It "Should create optimized deployment plan" {
            $planResult = New-DeploymentPlan -ConfigurationPath $script:testConfigPath -PlanName "comprehensive-integration-plan"
            
            $planResult | Should -Not -BeNullOrEmpty
            $planResult.Success | Should -Be $true
            $planResult.Plan.Stages | Should -HaveCount 4  # Prepare, Validate, Plan, Apply
            $planResult.Plan.Resources | Should -HaveCount 2
            $planResult.Plan.ParallelExecution | Should -Be $true
        }
        
        It "Should optimize deployment performance" {
            $optimizationResult = Optimize-DeploymentPerformance -ConfigurationPath $script:testConfigPath -OptimizationLevel "Balanced"
            
            $optimizationResult | Should -Not -BeNullOrEmpty
            $optimizationResult.Success | Should -Be $true
            $optimizationResult.Analysis.ResourceCount | Should -Be 2
            $optimizationResult.PerformanceGains.EstimatedTimeReduction | Should -BeGreaterThan 0
        }
        
        It "Should start infrastructure deployment" {
            $deployResult = Start-InfrastructureDeployment -ConfigurationPath $script:testConfigPath -PlanName "comprehensive-integration-plan"
            
            $deployResult | Should -Not -BeNullOrEmpty
            $deployResult.Success | Should -Be $true
            $deployResult.DeploymentId | Should -Not -BeNullOrEmpty
            
            # Store deployment ID for subsequent tests
            $script:testDeploymentId = $deployResult.DeploymentId
        }
        
        It "Should get deployment status" {
            $statusResult = Get-DeploymentStatus -DeploymentId $script:testDeploymentId
            
            $statusResult | Should -Not -BeNullOrEmpty
            $statusResult.Success | Should -Be $true
            $statusResult.Status | Should -BeIn @("Completed", "Running", "Failed")
        }
    }
    
    Context "Advanced Features Workflow" {
        It "Should create deployment snapshot" {
            $snapshotResult = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name $script:testSnapshotName -Description "Comprehensive integration test snapshot" -IncludeState -IncludeConfiguration
            
            $snapshotResult | Should -Not -BeNullOrEmpty
            $snapshotResult.Success | Should -Be $true
            $snapshotResult.SnapshotName | Should -Be $script:testSnapshotName
            $snapshotResult.Size | Should -BeGreaterThan 0
        }
        
        It "Should retrieve deployment snapshot" {
            $getSnapshotResult = Get-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name $script:testSnapshotName
            
            $getSnapshotResult | Should -Not -BeNullOrEmpty
            $getSnapshotResult.Name | Should -Be $script:testSnapshotName
            $getSnapshotResult.Description | Should -Be "Comprehensive integration test snapshot"
        }
        
        It "Should detect infrastructure drift" {
            $driftResult = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId
            
            $driftResult | Should -Not -BeNullOrEmpty
            $driftResult.Summary | Should -Not -BeNullOrEmpty
            $driftResult.Summary.TotalResources | Should -BeGreaterOrEqual 0
        }
        
        It "Should get deployment history" {
            $historyResult = Get-DeploymentHistory -DeploymentId $script:testDeploymentId -IncludeDetails
            
            $historyResult | Should -Not -BeNullOrEmpty
            $historyResult[0].DeploymentId | Should -Be $script:testDeploymentId
            $historyResult[0].Status | Should -Not -BeNullOrEmpty
        }
        
        It "Should configure deployment automation" {
            $automationResult = Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Monitoring" -EnableDriftDetection -EnableAutoBackup
            
            $automationResult | Should -Not -BeNullOrEmpty
            $automationResult.Success | Should -Be $true
            $automationResult.EnabledFeatures | Should -Contain "DriftDetection"
            $automationResult.EnabledFeatures | Should -Contain "AutoBackup"
        }
        
        It "Should get deployment automation info" {
            $automationInfo = Get-DeploymentAutomation -DeploymentId $script:testDeploymentId -IncludeHistory
            
            $automationInfo | Should -Not -BeNullOrEmpty
            $automationInfo[0].DeploymentId | Should -Be $script:testDeploymentId
            $automationInfo[0].AutomationType | Should -Be "Monitoring"
        }
        
        It "Should test rollback functionality (dry run)" {
            $rollbackResult = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -RollbackType "LastGood" -DryRun
            
            $rollbackResult | Should -Not -BeNullOrEmpty
            $rollbackResult.Success | Should -Be $true
            $rollbackResult.DryRun | Should -Be $true
        }
    }
    
    Context "Performance and Scalability Tests" {
        It "Should optimize memory usage" {
            $memoryResult = Optimize-MemoryUsage -ConfigurationPath $script:testConfigPath -OptimizationMode "Balanced" -EnableGarbageCollection -EnableResourcePooling
            
            $memoryResult | Should -Not -BeNullOrEmpty
            $memoryResult.Success | Should -Be $true
            $memoryResult.OptimizationsApplied | Should -Not -BeNullOrEmpty
            $memoryResult.MemoryReduction | Should -Not -BeNullOrEmpty
        }
        
        It "Should optimize deployment caching" {
            $cachingResult = Optimize-DeploymentCaching -ConfigurationPath $script:testConfigPath -CacheStrategy "Balanced" -EnableConfigurationCache -EnableStateCache
            
            $cachingResult | Should -Not -BeNullOrEmpty
            $cachingResult.Success | Should -Be $true
            $cachingResult.CachingEnabled | Should -Not -BeNullOrEmpty
            $cachingResult.PerformanceImpact.EstimatedSpeedupPercent | Should -BeGreaterThan 0
        }
        
        It "Should handle concurrent deployments stress test" {
            $stressResult = Test-ConcurrentDeployments -ConcurrencyLevel 2 -StressLevel "Light" -TestDuration 2
            
            $stressResult | Should -Not -BeNullOrEmpty
            $stressResult.Analysis.TotalDeployments | Should -BeGreaterOrEqual 2
            $stressResult.Analysis.SuccessfulDeployments | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "Provider Integration Tests" {
        It "Should register Hyper-V provider" {
            $providerResult = Register-InfrastructureProvider -Name "Hyper-V" -Type "hyperv" -ConfigurationPath $script:testConfigPath
            
            $providerResult | Should -Not -BeNullOrEmpty
            $providerResult.Success | Should -Be $true
            $providerResult.Provider.Name | Should -Be "Hyper-V"
        }
        
        It "Should test provider capabilities" {
            $capabilityResult = Test-ProviderCapability -ProviderName "Hyper-V" -Capability "VirtualMachine"
            
            $capabilityResult | Should -Not -BeNullOrEmpty
            $capabilityResult.IsSupported | Should -Be $true
        }
        
        It "Should validate provider configuration" {
            $configValidation = Test-ProviderConfiguration -ProviderName "Hyper-V" -Configuration @{ 
                host = "localhost"
                authentication = "integrated"
            }
            
            $configValidation | Should -Not -BeNullOrEmpty
            $configValidation.IsValid | Should -Be $true
        }
        
        It "Should get infrastructure provider info" {
            $providerInfo = Get-InfrastructureProvider -Name "Hyper-V"
            
            $providerInfo | Should -Not -BeNullOrEmpty
            $providerInfo.Name | Should -Be "Hyper-V"
            $providerInfo.Type | Should -Be "hyperv"
        }
    }
    
    Context "ISO Management Integration" {
        It "Should initialize deployment ISOs" {
            $isoResult = Initialize-DeploymentISOs -ConfigurationPath $script:testConfigPath
            
            $isoResult | Should -Not -BeNullOrEmpty
            $isoResult.Success | Should -Be $true
        }
        
        It "Should test ISO requirements" {
            $isoReqResult = Test-ISORequirements -ConfigurationPath $script:testConfigPath
            
            $isoReqResult | Should -Not -BeNullOrEmpty
            $isoReqResult.IsCompatible | Should -Be $true
        }
        
        It "Should get ISO configuration" {
            $isoConfigResult = Get-ISOConfiguration -ConfigurationPath $script:testConfigPath
            
            $isoConfigResult | Should -Not -BeNullOrEmpty
            $isoConfigResult.Success | Should -Be $true
        }
    }
    
    Context "Error Handling and Resilience" {
        It "Should handle invalid configuration gracefully" {
            $invalidConfig = @{
                version = "invalid"
                infrastructure = @{
                    virtual_machine = @{
                        memory_mb = "not-a-number"
                    }
                }
            }
            $invalidConfigPath = Join-Path $TestDrive "invalid-config.json"
            $invalidConfig | ConvertTo-Json | Set-Content -Path $invalidConfigPath
            
            { Read-DeploymentConfiguration -Path $invalidConfigPath } | Should -Throw
        }
        
        It "Should handle missing repository gracefully" {
            { Test-RepositoryCompatibility -Name "non-existent-repo" } | Should -Throw
        }
        
        It "Should handle missing deployment gracefully" {
            { Get-DeploymentStatus -DeploymentId "non-existent-deployment" } | Should -Throw
        }
        
        It "Should handle missing snapshot gracefully" {
            { Get-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "non-existent-snapshot" } | Should -Throw
        }
    }
    
    Context "Cleanup and Resource Management" {
        It "Should stop deployment automation" {
            $stopResult = Stop-DeploymentAutomation -DeploymentId $script:testDeploymentId
            
            $stopResult | Should -Not -BeNullOrEmpty
            $stopResult.Success | Should -Be $true
        }
        
        It "Should remove deployment snapshot" {
            Remove-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name $script:testSnapshotName -Force
            
            # Verify snapshot is removed
            { Get-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name $script:testSnapshotName } | Should -Throw
        }
        
        It "Should clean up global resources" {
            # Clean up global cache manager
            if ($global:OpenTofuCacheManager) {
                Remove-Variable -Name OpenTofuCacheManager -Scope Global -Force -ErrorAction SilentlyContinue
            }
            
            # Clean up resource pools
            if ($global:OpenTofuResourcePools) {
                Remove-Variable -Name OpenTofuResourcePools -Scope Global -Force -ErrorAction SilentlyContinue
            }
            
            # Clean up memory monitoring
            if ($global:OpenTofuMemoryMonitor) {
                Remove-Variable -Name OpenTofuMemoryMonitor -Scope Global -Force -ErrorAction SilentlyContinue
            }
            
            # Verify cleanup
            $global:OpenTofuCacheManager | Should -BeNullOrEmpty
            $global:OpenTofuResourcePools | Should -BeNullOrEmpty
            $global:OpenTofuMemoryMonitor | Should -BeNullOrEmpty
        }
    }
}

Describe "Cross-Module Integration and Compatibility Tests" {
    
    Context "Logging Integration" {
        It "Should integrate properly with Logging module" {
            Mock Write-CustomLog {} -ModuleName OpenTofuProvider
            
            # Perform operation that should generate logs
            $configResult = Read-DeploymentConfiguration -Path $script:testConfigPath
            
            # Verify logging was called
            Should -Invoke Write-CustomLog -ModuleName OpenTofuProvider -AtLeast 1
        }
    }
    
    Context "Module Interoperability" {
        It "Should work with ISOManager module" {
            # Test that OpenTofuProvider can work alongside ISOManager
            $isoManagerModule = Get-Module ISOManager
            $openTofuModule = Get-Module OpenTofuProvider
            
            $isoManagerModule | Should -Not -BeNullOrEmpty
            $openTofuModule | Should -Not -BeNullOrEmpty
            
            # Should not have function name conflicts
            $isoFunctions = $isoManagerModule.ExportedFunctions.Keys
            $openTofuFunctions = $openTofuModule.ExportedFunctions.Keys
            
            $conflicts = $isoFunctions | Where-Object { $_ -in $openTofuFunctions }
            $conflicts | Should -BeNullOrEmpty
        }
    }
    
    Context "PowerShell Compatibility" {
        It "Should support PowerShell 7.0+" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
        }
        
        It "Should handle different execution policies" {
            # Test should work regardless of execution policy
            Get-ExecutionPolicy | Should -BeIn @('Restricted', 'AllSigned', 'RemoteSigned', 'Unrestricted', 'Bypass', 'Undefined')
        }
    }
}

Describe "Performance Benchmarks and Metrics" {
    
    Context "Execution Time Benchmarks" {
        It "Should execute configuration reading within acceptable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $configResult = Read-DeploymentConfiguration -Path $script:testConfigPath
            $stopwatch.Stop()
            
            $configResult.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 2000  # Should complete within 2 seconds
        }
        
        It "Should execute deployment planning within acceptable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $planResult = New-DeploymentPlan -ConfigurationPath $script:testConfigPath -PlanName "benchmark-plan"
            $stopwatch.Stop()
            
            $planResult.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete within 5 seconds
        }
        
        It "Should execute snapshot creation within acceptable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $snapshotResult = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "benchmark-snapshot"
            $stopwatch.Stop()
            
            $snapshotResult.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 3000  # Should complete within 3 seconds
            
            # Cleanup
            Remove-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "benchmark-snapshot" -Force
        }
    }
    
    Context "Memory Usage Benchmarks" {
        It "Should maintain reasonable memory usage during operations" {
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # Perform multiple operations
            $configResult = Read-DeploymentConfiguration -Path $script:testConfigPath
            $planResult = New-DeploymentPlan -ConfigurationPath $script:testConfigPath -PlanName "memory-test-plan"
            $snapshotResult = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "memory-test-snapshot"
            
            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            $finalMemory = [System.GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Memory increase should be reasonable (less than 50MB)
            $memoryIncrease | Should -BeLessThan 50MB
            
            # Cleanup
            Remove-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "memory-test-snapshot" -Force
        }
    }
}

AfterAll {
    # Final cleanup
    if ($script:originalProjectRoot) {
        $env:PROJECT_ROOT = $script:originalProjectRoot
    } else {
        Remove-Item Env:PROJECT_ROOT -ErrorAction SilentlyContinue
    }
    
    # Clean up any remaining global variables
    Remove-Variable -Name OpenTofuCacheManager -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OpenTofuResourcePools -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OpenTofuMemoryMonitor -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OpenTofuMemoryLeakDetector -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OpenTofuObjectLifecycleManager -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OpenTofuStreamingMode -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OpenTofuConfigurationCache -Scope Global -Force -ErrorAction SilentlyContinue
}