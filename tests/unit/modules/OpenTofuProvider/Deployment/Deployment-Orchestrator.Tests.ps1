BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Mock environment
    $env:PROJECT_ROOT = $TestDrive
    
    # Test data
    $script:testConfig = @{
        version = "1.0"
        repository = @{
            name = "test-infra"
            url = "https://github.com/test/infra.git"
            version = "1.0.0"
        }
        template = @{
            name = "hyperv-lab"
            version = "1.0.0"
        }
        variables = @{
            vm_count = 2
            vm_size = "Standard_B2s"
            admin_username = "admin"
        }
        infrastructure = @{
            hyperv_vm = @{
                count = 2
                name_prefix = "test-vm"
            }
            hyperv_network = @{
                name = "test-network"
            }
        }
        iso_requirements = @(
            @{
                name = "WindowsServer2025"
                type = "WindowsServer2025"
                customization = "lab"
            }
        )
    }
    
    # Create test deployment directory structure
    $script:deploymentsDir = Join-Path $TestDrive "deployments"
    New-Item -Path $script:deploymentsDir -ItemType Directory -Force | Out-Null
}

Describe "Start-InfrastructureDeployment Tests" {
    BeforeEach {
        # Save test configuration
        $script:configPath = Join-Path $TestDrive "test-deployment.json"
        $script:testConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $script:configPath
        
        # Mock dependencies
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Start-Transcript {} -ModuleName OpenTofuProvider
        Mock Stop-Transcript {} -ModuleName OpenTofuProvider
        Mock New-DeploymentPlan {
            return [PSCustomObject]@{
                IsValid = $true
                ValidationErrors = @()
                Stages = @{
                    Prepare = @{ Order = 1; Required = $true; CreateCheckpoint = $false }
                    Validate = @{ Order = 2; Required = $true; CreateCheckpoint = $false }
                    Plan = @{ Order = 3; Required = $true; CreateCheckpoint = $true }
                }
            }
        } -ModuleName OpenTofuProvider
        Mock Invoke-DeploymentStage {
            return [PSCustomObject]@{
                Success = $true
                StageName = $StageName
                Outputs = @{}
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Basic Deployment" {
        It "Should start deployment with valid configuration" {
            $result = Start-InfrastructureDeployment -ConfigurationPath $script:configPath -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.DeploymentId | Should -Match '^[a-f0-9\-]{36}$'
            $result.Configuration | Should -Not -BeNullOrEmpty
        }
        
        It "Should create deployment directory" {
            $result = Start-InfrastructureDeployment -ConfigurationPath $script:configPath -DryRun
            
            $deploymentDir = Join-Path $script:deploymentsDir $result.DeploymentId
            Test-Path $deploymentDir | Should -Be $true
        }
        
        It "Should fail with invalid configuration path" {
            { Start-InfrastructureDeployment -ConfigurationPath "non-existent.json" } |
                Should -Throw
        }
        
        It "Should support repository override" {
            Mock Read-DeploymentConfiguration {
                return [PSCustomObject]$script:testConfig
            } -ModuleName OpenTofuProvider
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $script:configPath -Repository "override-repo" -DryRun
            
            Should -Invoke Read-DeploymentConfiguration -ModuleName OpenTofuProvider
        }
    }
    
    Context "Stage Execution" {
        It "Should execute all stages in order" {
            $result = Start-InfrastructureDeployment -ConfigurationPath $script:configPath -DryRun
            
            Should -Invoke Invoke-DeploymentStage -Times 3 -ModuleName OpenTofuProvider
            $result.Stages.Count | Should -Be 3
        }
        
        It "Should execute single stage when specified" {
            $result = Start-InfrastructureDeployment -ConfigurationPath $script:configPath -Stage "Validate" -DryRun
            
            Should -Invoke Invoke-DeploymentStage -Times 1 -ModuleName OpenTofuProvider -ParameterFilter {
                $StageName -eq "Validate"
            }
        }
        
        It "Should handle stage failures" {
            Mock Invoke-DeploymentStage {
                return [PSCustomObject]@{
                    Success = $false
                    StageName = $StageName
                    Error = "Stage failed"
                }
            } -ModuleName OpenTofuProvider
            
            { Start-InfrastructureDeployment -ConfigurationPath $script:configPath } |
                Should -Throw "*Deployment failed at stage*"
        }
        
        It "Should continue on failure with Force flag" {
            Mock Invoke-DeploymentStage {
                if ($StageName -eq "Validate") {
                    return [PSCustomObject]@{
                        Success = $false
                        StageName = $StageName
                        Error = "Validation failed"
                    }
                }
                return [PSCustomObject]@{
                    Success = $true
                    StageName = $StageName
                }
            } -ModuleName OpenTofuProvider
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $script:configPath -Force -DryRun
            
            $result.Errors.Count | Should -BeGreaterThan 0
            $result.Warnings.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Checkpoint and Resume" {
        It "Should create checkpoints after stages" {
            Mock Save-DeploymentCheckpoint {} -ModuleName OpenTofuProvider
            
            Start-InfrastructureDeployment -ConfigurationPath $script:configPath -DryRun
            
            Should -Invoke Save-DeploymentCheckpoint -ModuleName OpenTofuProvider -ParameterFilter {
                $CheckpointName -eq "after-Plan"
            }
        }
        
        It "Should resume from checkpoint" {
            # Create mock checkpoint
            $mockCheckpoint = @{
                State = @{
                    CompletedStages = @("Prepare", "Validate")
                }
                StageOrder = 2
            }
            Mock Load-DeploymentCheckpoint { return $mockCheckpoint } -ModuleName OpenTofuProvider
            
            Start-InfrastructureDeployment -ConfigurationPath $script:configPath -Checkpoint "after-validate" -DryRun
            
            Should -Invoke Load-DeploymentCheckpoint -ModuleName OpenTofuProvider
            Should -Not -Invoke Invoke-DeploymentStage -ModuleName OpenTofuProvider -ParameterFilter {
                $StageName -in @("Prepare", "Validate")
            }
        }
    }
}

Describe "New-DeploymentPlan Tests" {
    Context "Plan Creation" {
        It "Should create valid deployment plan" {
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$script:testConfig)
            
            $plan | Should -Not -BeNullOrEmpty
            $plan.IsValid | Should -Be $true
            $plan.Id | Should -Match '^[a-f0-9\-]{36}$'
            $plan.Stages.Count | Should -BeGreaterThan 0
        }
        
        It "Should include all default stages" {
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$script:testConfig)
            
            $plan.Stages.Keys | Should -Contain "Prepare"
            $plan.Stages.Keys | Should -Contain "Validate"
            $plan.Stages.Keys | Should -Contain "Plan"
            $plan.Stages.Keys | Should -Contain "Apply"
            $plan.Stages.Keys | Should -Contain "Verify"
        }
        
        It "Should respect custom stages" {
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$script:testConfig) -CustomStages @("Plan", "Apply")
            
            $plan.Stages.Count | Should -Be 2
            $plan.Stages.Keys | Should -Contain "Plan"
            $plan.Stages.Keys | Should -Contain "Apply"
        }
        
        It "Should exclude Apply/Verify in dry-run mode" {
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$script:testConfig) -DryRun
            
            $plan.Stages.Keys | Should -Not -Contain "Apply"
            $plan.Stages.Keys | Should -Not -Contain "Verify"
        }
    }
    
    Context "Resource Analysis" {
        It "Should analyze infrastructure resources" {
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$script:testConfig)
            
            $plan.Resources.Count | Should -Be 2
            $plan.Resources.ContainsKey("hyperv_vm") | Should -Be $true
            $plan.Resources["hyperv_vm"].Count | Should -Be 2
        }
        
        It "Should detect ISO requirements" {
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$script:testConfig)
            
            $plan.RequiredISOs.Count | Should -Be 1
            $plan.RequiredISOs[0].Name | Should -Be "WindowsServer2025"
        }
        
        It "Should enable parallel execution for many resources" {
            $largeConfig = $script:testConfig.Clone()
            $largeConfig.infrastructure.hyperv_vm.count = 10
            
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$largeConfig) -ParallelThreshold 5
            
            $plan.ParallelExecution | Should -Be $true
            $plan.Stages["Apply"].CanRunParallel | Should -Be $true
        }
    }
    
    Context "Validation" {
        It "Should validate missing repository" {
            $invalidConfig = $script:testConfig.Clone()
            $invalidConfig.Remove("repository")
            
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$invalidConfig)
            
            $plan.IsValid | Should -Be $false
            $plan.ValidationErrors | Should -Contain "Repository name is required"
        }
        
        It "Should validate missing template" {
            $invalidConfig = $script:testConfig.Clone()
            $invalidConfig.Remove("template")
            
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$invalidConfig)
            
            $plan.IsValid | Should -Be $false
            $plan.ValidationErrors | Should -Contain "Template name is required"
        }
        
        It "Should skip validation with SkipPreChecks" {
            $invalidConfig = $script:testConfig.Clone()
            $invalidConfig.Remove("repository")
            
            $plan = New-DeploymentPlan -Configuration ([PSCustomObject]$invalidConfig) -SkipPreChecks
            
            $plan.IsValid | Should -Be $true
        }
    }
}

Describe "Invoke-DeploymentStage Tests" {
    BeforeEach {
        $script:testPlan = [PSCustomObject]@{
            Configuration = [PSCustomObject]$script:testConfig
            Stages = @{
                Test = @{
                    Name = "Test"
                    Prerequisites = @()
                    Actions = @(
                        @{
                            Name = "TestAction"
                            Type = "PowerShell"
                            Script = { param($Message) return "Executed: $Message" }
                            Parameters = @{ Message = "Hello" }
                            Timeout = [TimeSpan]::FromSeconds(30)
                            ContinueOnError = $false
                        }
                    )
                    RetryPolicy = @{
                        MaxAttempts = 2
                        DelaySeconds = 1
                    }
                }
            }
        }
        
        # Mock deploymentDir
        $script:deploymentDir = Join-Path $TestDrive "test-deployment"
        New-Item -Path $script:deploymentDir -ItemType Directory -Force | Out-Null
    }
    
    Context "Action Execution" {
        It "Should execute PowerShell actions" {
            $result = Invoke-DeploymentStage -Plan $script:testPlan -StageName "Test"
            
            $result.Success | Should -Be $true
            $result.Actions["TestAction"].Success | Should -Be $true
            $result.Actions["TestAction"].Output | Should -Be "Executed: Hello"
        }
        
        It "Should respect dry-run mode" {
            $result = Invoke-DeploymentStage -Plan $script:testPlan -StageName "Test" -DryRun
            
            $result.Success | Should -Be $true
            $result.Actions["TestAction"].Output.DryRun | Should -Be $true
        }
        
        It "Should handle action failures" {
            $script:testPlan.Stages.Test.Actions[0].Script = { throw "Action failed" }
            
            $result = Invoke-DeploymentStage -Plan $script:testPlan -StageName "Test"
            
            $result.Success | Should -Be $false
            $result.Actions["TestAction"].Success | Should -Be $false
            $result.Actions["TestAction"].Error | Should -Match "Action failed"
        }
        
        It "Should retry failed actions" {
            $script:attemptCount = 0
            $script:testPlan.Stages.Test.Actions[0].Script = {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Temporary failure"
                }
                return "Success after retry"
            }
            
            $result = Invoke-DeploymentStage -Plan $script:testPlan -StageName "Test" -MaxRetries 2
            
            $result.Success | Should -Be $true
            $result.Actions["TestAction"].RetryCount | Should -Be 1
        }
    }
    
    Context "OpenTofu Actions" {
        It "Should execute OpenTofu plan action" {
            Mock Push-Location {} -ModuleName OpenTofuProvider
            Mock Pop-Location {} -ModuleName OpenTofuProvider
            Mock Test-Path { $true } -ModuleName OpenTofuProvider
            Mock Copy-Item {} -ModuleName OpenTofuProvider
            Mock Set-Content {} -ModuleName OpenTofuProvider
            Mock Invoke-Expression { return "Plan: 2 to add, 0 to change, 0 to destroy" } -ModuleName OpenTofuProvider
            
            $script:testPlan.Stages.Test.Actions[0] = @{
                Name = "GeneratePlan"
                Type = "OpenTofu"
                Timeout = [TimeSpan]::FromMinutes(5)
            }
            
            $LASTEXITCODE = 0
            $result = Invoke-DeploymentStage -Plan $script:testPlan -StageName "Test"
            
            $result.Success | Should -Be $true
            $result.Actions["GeneratePlan"].Output.Summary.ToAdd | Should -Be 2
        }
    }
}

Describe "Get-DeploymentStatus Tests" {
    BeforeEach {
        # Create test deployment
        $script:testDeploymentId = [Guid]::NewGuid().ToString()
        $script:testDeploymentDir = Join-Path $script:deploymentsDir $script:testDeploymentId
        New-Item -Path $script:testDeploymentDir -ItemType Directory -Force | Out-Null
        
        # Create state file
        $testState = @{
            Id = $script:testDeploymentId
            Status = "Running:Apply"
            StartTime = (Get-Date).AddMinutes(-5)
            CurrentStage = "Apply"
            CompletedStages = @("Prepare", "Validate", "Plan")
            Errors = @()
            Warnings = @("Test warning")
            ConfigurationPath = $script:configPath
        }
        $testState | ConvertTo-Json | Set-Content -Path (Join-Path $script:testDeploymentDir "state.json")
    }
    
    Context "Status Retrieval" {
        It "Should get deployment status by ID" {
            $status = Get-DeploymentStatus -DeploymentId $script:testDeploymentId
            
            $status | Should -Not -BeNullOrEmpty
            $status.DeploymentId | Should -Be $script:testDeploymentId
            $status.Status | Should -Be "Running:Apply"
            $status.IsRunning | Should -Be $true
        }
        
        It "Should get latest deployment status" {
            $status = Get-DeploymentStatus -Latest
            
            $status | Should -Not -BeNullOrEmpty
            $status.DeploymentId | Should -Be $script:testDeploymentId
        }
        
        It "Should include deployment history" {
            # Create another deployment
            $oldDeploymentId = [Guid]::NewGuid().ToString()
            $oldDeploymentDir = Join-Path $script:deploymentsDir $oldDeploymentId
            New-Item -Path $oldDeploymentDir -ItemType Directory -Force | Out-Null
            @{ Id = $oldDeploymentId; Status = "Completed" } | ConvertTo-Json | 
                Set-Content -Path (Join-Path $oldDeploymentDir "state.json")
            
            $statuses = Get-DeploymentStatus -IncludeHistory
            
            $statuses.Count | Should -Be 2
        }
    }
    
    Context "Progress Calculation" {
        It "Should calculate deployment progress" {
            $status = Get-DeploymentStatus -DeploymentId $script:testDeploymentId
            
            $status.Progress.Percentage | Should -Be 60  # 3 of 5 stages
            $status.Progress.StagesCompleted | Should -Be 3
        }
    }
    
    Context "Output Formatting" {
        It "Should format as table" {
            Mock Format-Table {} -ModuleName OpenTofuProvider
            
            Get-DeploymentStatus -DeploymentId $script:testDeploymentId -Format Table
            
            Should -Invoke Format-Table -ModuleName OpenTofuProvider
        }
        
        It "Should format as JSON" {
            $json = Get-DeploymentStatus -DeploymentId $script:testDeploymentId -Format Json
            
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should format as summary" {
            Mock Write-DeploymentStatusSummary {} -ModuleName OpenTofuProvider
            
            Get-DeploymentStatus -DeploymentId $script:testDeploymentId -Format Summary
            
            Should -Invoke Write-DeploymentStatusSummary -ModuleName OpenTofuProvider
        }
    }
}

AfterAll {
    # Restore environment
    $env:PROJECT_ROOT = $projectRoot
}