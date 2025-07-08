#Requires -Version 7.0

BeforeAll {
    # Import LabRunner module directly
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $ModulePath -Force
    
    # Mock external dependencies for testing
    Mock Write-CustomLog { }
    Mock Write-Host { }
    Mock Start-Sleep { }
    Mock Write-ProgressLog { }
    Mock Start-ProgressOperation { return "mock-progress-id" }
    Mock Update-ProgressOperation { }
    Mock Complete-ProgressOperation { }
    Mock Add-ProgressError { }
    Mock Add-ProgressWarning { }
    Mock Import-Module { } -ParameterFilter { $Name -like "*OpenTofuProvider*" }
}

Describe "LabRunner Module Tests" {
    
    Context "Module Structure and Loading" {
        It "Should load the LabRunner module successfully" {
            Get-Module -Name LabRunner | Should -Not -BeNullOrEmpty
        }
        
        It "Should export all required functions" {
            $expectedFunctions = @(
                'Get-CrossPlatformTempPath',
                'Invoke-CrossPlatformCommand', 
                'Invoke-LabStep',
                'Invoke-LabDownload',
                'Read-LoggedInput',
                'Invoke-LabWebRequest',
                'Invoke-LabNpm',
                'Resolve-ProjectPath',
                'Get-LabConfig',
                'Format-Config',
                'Expand-All',
                'Get-MenuSelection',
                'Get-GhDownloadArgs',
                'Invoke-ArchiveDownload',
                'Get-Platform',
                'Invoke-OpenTofuInstaller',
                'Invoke-ParallelLabRunner',
                'Test-ParallelRunnerSupport',
                'Start-LabAutomation',
                'Get-LabStatus',
                'Start-EnhancedLabDeployment'
            )
            
            $exportedFunctions = (Get-Module LabRunner).ExportedFunctions.Keys
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
        
        It "Should have proper module manifest" {
            $manifest = Test-ModuleManifest (Join-Path $PSScriptRoot "../LabRunner.psd1")
            $manifest | Should -Not -BeNullOrEmpty
            $manifest.Name | Should -Be "LabRunner"
        }
    }
    
    Context "Platform Detection" {
        It "Should detect platform correctly" {
            $platform = Get-Platform
            $platform | Should -BeIn @('Windows', 'Linux', 'MacOS', 'Unknown')
        }
        
        It "Should return cross-platform temp path" {
            $tempPath = Get-CrossPlatformTempPath
            $tempPath | Should -Not -BeNullOrEmpty
            Test-Path $tempPath | Should -Be $true
        }
    }
    
    Context "Parallel Execution Support" {
        It "Should test parallel runner support" {
            $result = Test-ParallelRunnerSupport
            $result | Should -BeOfType [bool]
        }
        
        It "Should provide detailed parallel support information" {
            $result = Test-ParallelRunnerSupport -Detailed
            $result | Should -Not -BeNullOrEmpty
            $result.Supported | Should -BeOfType [bool]
            $result.PowerShellVersion | Should -Not -BeNullOrEmpty
            $result.Platform | Should -Not -BeNullOrEmpty
            $result.MaxConcurrency | Should -BeGreaterThan 0
        }
        
        It "Should handle ThreadJob module availability" {
            # This test verifies the function handles both available and unavailable scenarios
            { Test-ParallelRunnerSupport } | Should -Not -Throw
        }
    }
    
    Context "Lab Configuration Management" {
        BeforeEach {
            $testConfigPath = Join-Path $TestDrive "test-config.yaml"
            $testConfig = @"
name: Test Lab
environment: dev
network:
  subnet: 192.168.1.0/24
  gateway: 192.168.1.1
nodes:
  - name: web-01
    role: webserver
    cpu: 2
    memory: 4GB
"@
            Set-Content -Path $testConfigPath -Value $testConfig
        }
        
        It "Should load lab configuration from file" {
            $config = Get-LabConfig -Path $testConfigPath
            $config | Should -Not -BeNullOrEmpty
            $config.name | Should -Be "Test Lab"
        }
        
        It "Should handle missing configuration file gracefully" {
            $result = Get-LabConfig -Path "non-existent.yaml"
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Lab Status and Monitoring" {
        It "Should get lab status" {
            $status = Get-LabStatus
            $status | Should -Not -BeNullOrEmpty
            $status.Timestamp | Should -Not -BeNullOrEmpty
            $status.Platform | Should -Not -BeNullOrEmpty
            $status.ParallelSupport | Should -BeOfType [bool]
        }
        
        It "Should get detailed lab status" {
            $status = Get-LabStatus -Detailed
            $status | Should -Not -BeNullOrEmpty
            $status.ParallelSupportDetails | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Lab Automation Workflow" {
        It "Should start lab automation with default parameters" {
            Mock Start-ProgressOperation { return "test-progress-id" }
            Mock Update-ProgressOperation { }
            Mock Complete-ProgressOperation { }
            Mock Get-LabConfig { return @{ name = "test"; steps = @("step1", "step2") } }
            
            $result = Start-LabAutomation -Configuration @{ name = "test" }
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Success"
        }
        
        It "Should handle lab automation with specific steps" {
            Mock Start-ProgressOperation { return "test-progress-id" }
            Mock Update-ProgressOperation { }
            Mock Complete-ProgressOperation { }
            Mock Invoke-LabStep { return $true }
            
            $steps = @("Setup", "Deploy", "Validate")
            $result = Start-LabAutomation -Steps $steps -Configuration @{ name = "test" }
            $result | Should -Not -BeNullOrEmpty
            $result.ExecutedSteps | Should -Be $steps
        }
    }
    
    Context "Parallel Lab Runner" {
        It "Should handle empty script list" {
            Mock Start-ThreadJob { return @{ State = "Completed"; PSBeginTime = (Get-Date) } }
            Mock Receive-Job { return @{ Success = $true; Message = "Test completed" } }
            Mock Remove-Job { }
            
            $result = Invoke-ParallelLabRunner -Scripts @() -Config @{ name = "test" }
            $result | Should -Not -BeNullOrEmpty
            $result.TotalScripts | Should -BeGreaterOrEqual 0
        }
        
        It "Should generate deployment scripts from configuration" {
            $config = @{
                infrastructure = @{ provider = "hyperv" }
                network = @{ subnet = "192.168.1.0/24" }
                vms = @(
                    @{ name = "vm1"; role = "web" }
                )
                applications = @(
                    @{ name = "app1"; type = "web" }
                )
            }
            
            # This is an internal function test - we'll test it through the main function
            Mock Start-ThreadJob { 
                return @{ 
                    Id = 1
                    Name = "Test-Job"
                    State = "Completed"
                    PSBeginTime = (Get-Date)
                }
            }
            Mock Receive-Job { return @{ Success = $true; Message = "Generated scripts" } }
            Mock Remove-Job { }
            
            $result = Invoke-ParallelLabRunner -Config $config -MaxConcurrency 1
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Enhanced Lab Deployment" {
        BeforeEach {
            $testConfigPath = Join-Path $TestDrive "deploy-config.yaml"
            $testConfig = @"
name: Enhanced Test Lab
infrastructure:
  provider: test
network:
  subnet: 10.0.0.0/24
"@
            Set-Content -Path $testConfigPath -Value $testConfig
        }
        
        It "Should start enhanced lab deployment" {
            Mock Get-LabConfig { return @{ name = "Enhanced Test Lab"; network = @{ subnet = "10.0.0.0/24" } } }
            Mock Get-Module { return $null }  # No OpenTofuProvider
            Mock Start-LabAutomation { return @{ Status = "Success" } }
            Mock Test-LabDeploymentHealth { return @{ Success = $true; Warnings = @() } }
            Mock Start-ProgressOperation { return "enhanced-progress-id" }
            Mock Update-ProgressOperation { }
            Mock Complete-ProgressOperation { }
            Mock Write-EnhancedDeploymentSummary { }
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $testConfigPath
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should handle enhanced deployment with dry run" {
            Mock Get-LabConfig { return @{ name = "Test Lab" } }
            Mock Get-Module { return $null }
            Mock Start-LabAutomation { return @{ Status = "Success" } }
            Mock Test-LabDeploymentHealth { return @{ Success = $true; Warnings = @() } }
            Mock Start-ProgressOperation { return "dry-run-progress-id" }
            Mock Update-ProgressOperation { }
            Mock Complete-ProgressOperation { }
            Mock Write-EnhancedDeploymentSummary { }
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $testConfigPath -DryRun
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
        }
    }
    
    Context "Cross-Platform Command Execution" {
        It "Should execute available commands" {
            Mock Get-Command { return @{ Name = "Test-Command" } }
            
            $result = Invoke-CrossPlatformCommand -CommandName "Test-Command" -Parameters @{ TestParam = "value" }
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle unavailable commands with mock result" {
            Mock Get-Command { return $null }
            
            $mockResult = "Mock Result"
            $result = Invoke-CrossPlatformCommand -CommandName "Non-Existent-Command" -MockResult $mockResult
            $result | Should -Be $mockResult
        }
        
        It "Should skip unavailable commands when requested" {
            Mock Get-Command { return $null }
            
            $result = Invoke-CrossPlatformCommand -CommandName "Non-Existent-Command" -SkipOnUnavailable
            $result | Should -BeNullOrEmpty
        }
        
        It "Should throw for unavailable commands by default" {
            Mock Get-Command { return $null }
            
            { Invoke-CrossPlatformCommand -CommandName "Non-Existent-Command" } | Should -Throw
        }
    }
    
    Context "Lab Step Execution" {
        It "Should execute lab steps with configuration" {
            $testConfig = @{ name = "test"; value = "config" }
            $executed = $false
            
            $result = Invoke-LabStep -Body { 
                param($Config)
                $script:executed = $true
                $Config.name | Should -Be "test"
            } -Config $testConfig
            
            $executed | Should -Be $true
        }
        
        It "Should handle lab step errors properly" {
            { 
                Invoke-LabStep -Body { 
                    throw "Test error"
                } -Config @{}
            } | Should -Throw "Test error"
        }
    }
    
    Context "Input and Interaction" {
        It "Should handle non-interactive input" {
            Mock Read-Host { return "default-value" }
            
            # Set non-interactive environment
            $originalHost = $Host.Name
            $env:PESTER_RUN = 'true'
            
            $result = Read-LoggedInput -Prompt "Test prompt" -DefaultValue "default"
            $result | Should -Be "default"
            
            # Cleanup
            $env:PESTER_RUN = $null
        }
        
        It "Should handle secure string input in non-interactive mode" {
            $env:PESTER_RUN = 'true'
            
            $result = Read-LoggedInput -Prompt "Secure prompt" -AsSecureString -DefaultValue "test"
            $result | Should -BeOfType [System.Security.SecureString]
            
            # Cleanup
            $env:PESTER_RUN = $null
        }
    }
    
    Context "Network and Download Operations" {
        It "Should execute web requests with error handling" {
            Mock Invoke-WebRequest { return @{ StatusCode = 200 } }
            
            $result = Invoke-LabWebRequest -Uri "https://example.com" -UseBasicParsing
            $result.StatusCode | Should -Be 200
        }
        
        It "Should handle web request failures" {
            Mock Invoke-WebRequest { throw "Network error" }
            
            { Invoke-LabWebRequest -Uri "https://invalid.com" } | Should -Throw "Network error"
        }
    }
    
    Context "Error Handling and Resilience" {
        It "Should handle module import failures gracefully" {
            # Test that the module can function even when optional modules are not available
            { Get-LabStatus } | Should -Not -Throw
        }
        
        It "Should provide meaningful error messages" {
            try {
                Invoke-LabStep -Body { throw "Test error" } -Config @{}
            } catch {
                $_.Exception.Message | Should -Match "Test error"
            }
        }
    }
}

Describe "LabRunner Integration Tests" {
    
    Context "Module Integration" {
        It "Should integrate with Logging module when available" {
            # Test logging integration
            Mock Import-Module { } -ParameterFilter { $Name -like "*Logging*" }
            Mock Write-CustomLog { }
            
            { Get-LabStatus } | Should -Not -Throw
        }
        
        It "Should integrate with ProgressTracking module when available" {
            Mock Import-Module { } -ParameterFilter { $Name -like "*ProgressTracking*" }
            Mock Start-ProgressOperation { return "test-id" }
            Mock Update-ProgressOperation { }
            Mock Complete-ProgressOperation { }
            
            { Start-LabAutomation -ShowProgress } | Should -Not -Throw
        }
    }
    
    Context "Real-World Scenarios" {
        It "Should handle a complete lab deployment workflow" {
            # Mock all external dependencies
            Mock Get-LabConfig { 
                return @{
                    name = "Integration Test Lab"
                    infrastructure = @{ provider = "test" }
                    network = @{ subnet = "192.168.1.0/24" }
                    vms = @(@{ name = "test-vm"; role = "test" })
                }
            }
            Mock Start-ThreadJob { 
                return @{ 
                    Id = 1
                    Name = "Integration-Test"
                    State = "Completed"
                    PSBeginTime = (Get-Date)
                }
            }
            Mock Receive-Job { return @{ Success = $true; Message = "Integration test passed" } }
            Mock Remove-Job { }
            Mock Test-LabDeploymentHealth { return @{ Success = $true; Warnings = @() } }
            
            $result = Invoke-ParallelLabRunner -MaxConcurrency 1
            $result | Should -Not -BeNullOrEmpty
            $result.TotalScripts | Should -BeGreaterThan 0
        }
    }
}

Describe "LabRunner Performance Tests" {
    
    Context "Performance Metrics" {
        It "Should complete parallel support test quickly" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Test-ParallelRunnerSupport | Out-Null
            $stopwatch.Stop()
            
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete in under 5 seconds
        }
        
        It "Should handle multiple concurrent operations efficiently" {
            Mock Start-ThreadJob { 
                return @{ 
                    Id = Get-Random
                    Name = "Perf-Test-$(Get-Random)"
                    State = "Completed"
                    PSBeginTime = (Get-Date)
                }
            }
            Mock Receive-Job { return @{ Success = $true; Message = "Performance test" } }
            Mock Remove-Job { }
            
            $scripts = 1..5 | ForEach-Object {
                @{
                    Name = "Performance-Test-$_"
                    Path = "Test-Performance"
                    Config = @{ id = $_ }
                }
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Invoke-ParallelLabRunner -Scripts $scripts -MaxConcurrency 3
            $stopwatch.Stop()
            
            $result.TotalScripts | Should -Be 5
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000  # Should complete efficiently
        }
    }
}