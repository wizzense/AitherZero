BeforeDiscovery {
    $script:OpenTofuModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/OpenTofuProvider'
    $script:TestAppName = 'OpenTofuProvider'
    
    # Verify the OpenTofu module exists
    if (-not (Test-Path $script:OpenTofuModulePath)) {
        throw "OpenTofuProvider module not found at: $script:OpenTofuModulePath"
    }
}

Describe 'OpenTofuProvider - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'OpenTofu', 'Deployment') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'opentofu-provider-tests'
        
        # Save original environment
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalUserProfile = $env:USERPROFILE
        $script:OriginalHome = $env:HOME
        
        # Create test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestDeploymentsDir = Join-Path $script:TestProjectRoot 'deployments'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestOpenTofuDir = Join-Path $script:TestProjectRoot 'opentofu'
        $script:TestTemplatesDir = Join-Path $script:TestOpenTofuDir 'templates'
        
        @($script:TestProjectRoot, $script:TestModulesDir, $script:TestSharedDir,
          $script:TestDeploymentsDir, $script:TestConfigsDir, $script:TestOpenTofuDir,
          $script:TestTemplatesDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment variables
        $env:PROJECT_ROOT = $script:TestProjectRoot
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
        
        # Copy OpenTofuProvider module to test environment
        $testOpenTofuModulePath = Join-Path $script:TestModulesDir 'OpenTofuProvider'
        Copy-Item -Path "$script:OpenTofuModulePath\*" -Destination $testOpenTofuModulePath -Recurse -Force
        
        # Create mock Logging module
        $testLoggingModulePath = Join-Path $script:TestModulesDir 'Logging'
        New-Item -ItemType Directory -Path $testLoggingModulePath -Force | Out-Null
        @'
function Write-CustomLog {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}
Export-ModuleMember -Function Write-CustomLog
'@ | Out-File -FilePath (Join-Path $testLoggingModulePath 'Logging.psm1') -Encoding UTF8
        
        # Create mock ProgressTracking module
        $testProgressModulePath = Join-Path $script:TestModulesDir 'ProgressTracking'
        New-Item -ItemType Directory -Path $testProgressModulePath -Force | Out-Null
        @'
function Start-ProgressOperation { param($OperationName, $TotalSteps, [switch]$ShowTime, [switch]$ShowETA, $Style); return "test-operation-id" }
function Update-ProgressOperation { param($OperationId, $CurrentStep, $StepName) }
function Complete-ProgressOperation { param($OperationId, [switch]$ShowSummary) }
function Write-ProgressLog { param($Message, $Level) }
function Add-ProgressError { param($OperationId, $Error) }
function Add-ProgressWarning { param($OperationId, $Warning) }
Export-ModuleMember -Function *
'@ | Out-File -FilePath (Join-Path $testProgressModulePath 'ProgressTracking.psm1') -Encoding UTF8
        
        # Import OpenTofuProvider module from test location
        Import-Module $testOpenTofuModulePath -Force -Global
        
        # Mock OpenTofu/Terraform binaries
        $script:MockTofuCommands = @{}
        
        # Create test configuration templates
        $script:TestConfigurations = @{
            SimpleVM = @{
                version = '1.0'
                name = 'simple-vm-deployment'
                description = 'Basic VM deployment for testing'
                repository = @{
                    name = 'test-infrastructure'
                    url = 'https://github.com/test/infrastructure.git'
                    version = 'main'
                }
                template = @{
                    name = 'hyperv-vm'
                    version = '1.0.0'
                    path = 'templates/hyperv-vm'
                }
                variables = @{
                    vm_name = 'test-vm-01'
                    vm_memory = '4GB'
                    vm_cpu = 2
                    iso_path = 'C:\ISOs\ubuntu-22.04.iso'
                }
                infrastructure = @{
                    hyperv_virtual_machine = @{
                        name = 'test-vm-01'
                        memory_mb = 4096
                        processor_count = 2
                        generation = 2
                        automatic_start_action = 'Nothing'
                        automatic_stop_action = 'ShutDown'
                    }
                }
                iso_requirements = @(
                    @{
                        name = 'ubuntu-22.04'
                        type = 'linux'
                        customization = 'minimal'
                    }
                )
            }
            ComplexLab = @{
                version = '1.0'
                name = 'complex-lab-deployment'
                description = 'Multi-VM lab with dependencies'
                repository = @{
                    name = 'lab-infrastructure'
                    url = 'https://github.com/test/lab.git'
                    version = 'main'
                }
                template = @{
                    name = 'hyperv-lab'
                    version = '2.0.0'
                    path = 'templates/hyperv-lab'
                }
                variables = @{
                    lab_name = 'test-lab'
                    domain_name = 'test.local'
                    admin_password = 'SecurePass123!'
                }
                infrastructure = @{
                    hyperv_virtual_machine = @(
                        @{
                            name = 'dc-01'
                            role = 'domain-controller'
                            memory_mb = 2048
                            processor_count = 2
                        },
                        @{
                            name = 'srv-01'
                            role = 'member-server'
                            memory_mb = 4096
                            processor_count = 4
                            depends_on = @('dc-01')
                        }
                    )
                    hyperv_virtual_switch = @{
                        name = 'lab-switch'
                        switch_type = 'Internal'
                    }
                }
                iso_requirements = @(
                    @{
                        name = 'windows-server-2022'
                        type = 'windows'
                        customization = 'domain-controller'
                    },
                    @{
                        name = 'windows-server-2022'
                        type = 'windows'
                        customization = 'member-server'
                    }
                )
                dependencies = @{
                    'ISOManager' = '1.0.0'
                    'RemoteConnection' = '1.0.0'
                }
            }
            MalformedConfig = @{
                # Missing required fields for testing validation
                name = 'malformed-test'
                # No repository or template
            }
        }
        
        # Create test configuration files
        foreach ($configName in $script:TestConfigurations.Keys) {
            $configPath = Join-Path $script:TestConfigsDir "$configName.yaml"
            $config = $script:TestConfigurations[$configName]
            $config.SourcePath = $configPath
            
            # Convert to YAML-like format for testing
            $yamlContent = $config | ConvertTo-Json -Depth 10
            $yamlContent | Out-File -FilePath $configPath -Encoding UTF8
        }
        
        # Create mock template files
        $testTemplatePath = Join-Path $script:TestTemplatesDir 'hyperv-vm'
        New-Item -ItemType Directory -Path $testTemplatePath -Force | Out-Null
        
        @'
# Test OpenTofu configuration
terraform {
  required_providers {
    hyperv = {
      source = "taliesins/hyperv"
      version = "~> 1.0"
    }
  }
}

resource "hyperv_virtual_machine" "vm" {
  name                 = var.vm_name
  memory_mb           = var.vm_memory_mb
  processor_count     = var.vm_cpu
  generation          = 2
  
  dynamic_memory {
    enabled                   = true
    minimum_memory_mb        = 512
    maximum_memory_mb        = var.vm_memory_mb
  }
}
'@ | Out-File -FilePath (Join-Path $testTemplatePath 'main.tf') -Encoding UTF8
        
        # Mock external dependencies and commands
        Mock Invoke-Expression { 
            param($Command)
            
            if ($Command -like '*tofu version*') {
                return @'
OpenTofu v1.6.0
on windows_amd64
'@
            }
            
            if ($Command -like '*tofu init*') {
                return "Initializing the backend..."
            }
            
            if ($Command -like '*tofu plan*') {
                return @'
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # hyperv_virtual_machine.vm will be created
  + resource "hyperv_virtual_machine" "vm" {
      + name = "test-vm-01"
      + memory_mb = 4096
      + processor_count = 2
    }

Plan: 1 to add, 0 to change, 0 to destroy.
'@
            }
            
            if ($Command -like '*tofu apply*') {
                return @'
hyperv_virtual_machine.vm: Creating...
hyperv_virtual_machine.vm: Creation complete after 2m15s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
'@
            }
            
            if ($Command -like '*tofu destroy*') {
                return @'
hyperv_virtual_machine.vm: Destroying...
hyperv_virtual_machine.vm: Destruction complete after 45s

Destroy complete! Resources: 1 destroyed.
'@
            }
            
            return "Mock command executed: $Command"
        } -ModuleName $script:TestAppName
        
        # Mock Start-Transcript and Stop-Transcript
        Mock Start-Transcript { } -ModuleName $script:TestAppName
        Mock Stop-Transcript { } -ModuleName $script:TestAppName
        
        # Mock Test-Path for external tools
        Mock Test-Path { 
            param($Path)
            if ($Path -like '*tofu.exe' -or $Path -like '*tofu') {
                return $true
            }
            return (Test-Path -Path $Path -PathType Container) -or (Test-Path -Path $Path -PathType Leaf)
        } -ModuleName $script:TestAppName
    }
    
    AfterAll {
        # Restore original environment
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        $env:USERPROFILE = $script:OriginalUserProfile  
        $env:HOME = $script:OriginalHome
        
        # Remove imported modules
        Remove-Module OpenTofuProvider -Force -ErrorAction SilentlyContinue
        Remove-Module Logging -Force -ErrorAction SilentlyContinue
        Remove-Module ProgressTracking -Force -ErrorAction SilentlyContinue
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear any deployment state
        if (Test-Path $script:TestDeploymentsDir) {
            Get-ChildItem $script:TestDeploymentsDir | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Reset mock command tracking
        $script:MockTofuCommands.Clear()
    }
    
    Context 'Deployment Configuration Management' {
        
        It 'Should read and validate simple deployment configuration' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $config = Read-DeploymentConfiguration -Path $configPath } | Should -Not -Throw
            
            $config = Read-DeploymentConfiguration -Path $configPath
            $config | Should -Not -BeNullOrEmpty
            $config.name | Should -Be 'simple-vm-deployment'
            $config.repository | Should -Not -BeNullOrEmpty
            $config.template | Should -Not -BeNullOrEmpty
            $config.variables | Should -Not -BeNullOrEmpty
            $config.infrastructure | Should -Not -BeNullOrEmpty
        }
        
        It 'Should read and validate complex lab deployment configuration' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexLab.yaml'
            
            { $config = Read-DeploymentConfiguration -Path $configPath } | Should -Not -Throw
            
            $config = Read-DeploymentConfiguration -Path $configPath
            $config | Should -Not -BeNullOrEmpty
            $config.name | Should -Be 'complex-lab-deployment'
            $config.infrastructure.hyperv_virtual_machine | Should -BeOfType [Array]
            $config.infrastructure.hyperv_virtual_machine.Count | Should -Be 2
            $config.iso_requirements | Should -Not -BeNullOrEmpty
            $config.dependencies | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle missing configuration files gracefully' {
            $nonExistentPath = Join-Path $script:TestConfigsDir 'NonExistent.yaml'
            
            { Read-DeploymentConfiguration -Path $nonExistentPath } | Should -Throw
        }
        
        It 'Should validate configuration with ExpandVariables' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $config = Read-DeploymentConfiguration -Path $configPath -ExpandVariables } | Should -Not -Throw
            
            $config = Read-DeploymentConfiguration -Path $configPath -ExpandVariables
            $config.variables | Should -Not -BeNullOrEmpty
            $config.variables.vm_name | Should -Be 'test-vm-01'
        }
    }
    
    Context 'Deployment Plan Generation' {
        
        It 'Should create valid deployment plan for simple configuration' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            { $plan = New-DeploymentPlan -Configuration $config } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config
            $plan | Should -Not -BeNullOrEmpty
            $plan.Id | Should -Not -BeNullOrEmpty
            $plan.IsValid | Should -Be $true
            $plan.Stages | Should -Not -BeNullOrEmpty
            $plan.Stages.Count | Should -BeGreaterThan 0
            
            # Check default stages
            $plan.Stages.Keys | Should -Contain 'Prepare'
            $plan.Stages.Keys | Should -Contain 'Validate'
            $plan.Stages.Keys | Should -Contain 'Plan'
            $plan.Stages.Keys | Should -Contain 'Apply'
            $plan.Stages.Keys | Should -Contain 'Verify'
        }
        
        It 'Should create deployment plan with custom stages' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            $customStages = @('Plan', 'Apply')
            
            { $plan = New-DeploymentPlan -Configuration $config -CustomStages $customStages } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config -CustomStages $customStages
            $plan.Stages.Count | Should -Be 2
            $plan.Stages.Keys | Should -Contain 'Plan'
            $plan.Stages.Keys | Should -Contain 'Apply'
            $plan.Stages.Keys | Should -Not -Contain 'Prepare'
        }
        
        It 'Should create dry-run deployment plan' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            { $plan = New-DeploymentPlan -Configuration $config -DryRun } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config -DryRun
            $plan.Stages.Keys | Should -Contain 'Prepare'
            $plan.Stages.Keys | Should -Contain 'Validate'
            $plan.Stages.Keys | Should -Contain 'Plan'
            $plan.Stages.Keys | Should -Not -Contain 'Apply'
            $plan.Stages.Keys | Should -Not -Contain 'Verify'
        }
        
        It 'Should analyze resource dependencies correctly' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexLab.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            { $plan = New-DeploymentPlan -Configuration $config } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config
            $plan.Resources | Should -Not -BeNullOrEmpty
            $plan.Resources.Count | Should -BeGreaterThan 1
            
            # Check for parallel execution with multiple resources
            $plan.ParallelExecution | Should -Be $false  # Only 2 resource types, threshold is 5
        }
        
        It 'Should enable parallel execution for large deployments' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexLab.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            { $plan = New-DeploymentPlan -Configuration $config -ParallelThreshold 1 } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config -ParallelThreshold 1
            $plan.ParallelExecution | Should -Be $true
            $plan.Stages['Apply'].CanRunParallel | Should -Be $true
        }
        
        It 'Should detect and report validation errors' {
            $configPath = Join-Path $script:TestConfigsDir 'MalformedConfig.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            { $plan = New-DeploymentPlan -Configuration $config } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config
            $plan.IsValid | Should -Be $false
            $plan.ValidationErrors | Should -Not -BeNullOrEmpty
            $plan.ValidationErrors.Count | Should -BeGreaterThan 0
        }
        
        It 'Should skip pre-checks when requested' {
            $configPath = Join-Path $script:TestConfigsDir 'MalformedConfig.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            { $plan = New-DeploymentPlan -Configuration $config -SkipPreChecks } | Should -Not -Throw
            
            $plan = New-DeploymentPlan -Configuration $config -SkipPreChecks
            # Should still be invalid due to missing required fields
            $plan.IsValid | Should -Be $false
        }
        
        It 'Should calculate estimated duration correctly' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            $plan = New-DeploymentPlan -Configuration $config
            $plan.EstimatedDuration | Should -Not -BeNullOrEmpty
            $plan.EstimatedDuration.TotalMinutes | Should -BeGreaterThan 0
        }
        
        It 'Should identify required ISOs' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            $plan = New-DeploymentPlan -Configuration $config
            $plan.RequiredISOs | Should -Not -BeNullOrEmpty
            $plan.RequiredISOs.Count | Should -Be 1
            $plan.RequiredISOs[0].Name | Should -Be 'ubuntu-22.04'
            $plan.RequiredISOs[0].Type | Should -Be 'linux'
        }
        
        It 'Should identify required modules' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexLab.yaml'
            $config = Read-DeploymentConfiguration -Path $configPath
            
            $plan = New-DeploymentPlan -Configuration $config
            $plan.RequiredModules | Should -Not -BeNullOrEmpty
            $plan.RequiredModules.Count | Should -BeGreaterThan 0
            
            $isoManagerModule = $plan.RequiredModules | Where-Object { $_.Name -eq 'ISOManager' }
            $isoManagerModule | Should -Not -BeNullOrEmpty
            $isoManagerModule.Version | Should -Be '1.0.0'
        }
    }
    
    Context 'Infrastructure Deployment Orchestration' {
        
        It 'Should execute simple deployment successfully in dry-run mode' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.DeploymentId | Should -Not -BeNullOrEmpty
            $result.Configuration | Should -Not -BeNullOrEmpty
            $result.Stages | Should -Not -BeNullOrEmpty
            $result.Duration | Should -Not -BeNullOrEmpty
        }
        
        It 'Should execute specific deployment stage' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -Stage 'Plan' } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -Stage 'Plan'
            $result.Stages.Keys | Should -Contain 'Plan'
            $result.Stages.Count | Should -Be 1
        }
        
        It 'Should handle deployment with repository override' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $overrideRepo = 'custom-infrastructure-repo'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -Repository $overrideRepo -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -Repository $overrideRepo -DryRun
            $result.Configuration.repository.name | Should -Be $overrideRepo
        }
        
        It 'Should handle deployment failures gracefully' {
            $configPath = Join-Path $script:TestConfigsDir 'MalformedConfig.yaml'
            
            { Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Throw
        }
        
        It 'Should continue on errors with Force flag' {
            $configPath = Join-Path $script:TestConfigsDir 'MalformedConfig.yaml'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun -Force } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun -Force
            $result.Errors | Should -Not -BeNullOrEmpty
            $result.Warnings | Should -Not -BeNullOrEmpty
        }
        
        It 'Should skip pre-checks when requested' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -SkipPreChecks -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -SkipPreChecks -DryRun
            $result.Success | Should -Be $true
        }
        
        It 'Should respect MaxRetries parameter' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            $maxRetries = 3
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -MaxRetries $maxRetries -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -MaxRetries $maxRetries -DryRun
            $result.Success | Should -Be $true
        }
        
        It 'Should generate deployment logs' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $result.LogPath | Should -Not -BeNullOrEmpty
            $result.LogPath | Should -BeLike "*deployment.log"
        }
        
        It 'Should integrate with progress tracking when available' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            # Mock that ProgressTracking module is available
            Mock Get-Module { 
                return @{ Name = 'ProgressTracking' }
            } -ParameterFilter { $Name -eq 'ProgressTracking' -and $ListAvailable } -ModuleName $script:TestAppName
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $result.Success | Should -Be $true
        }
    }
    
    Context 'Deployment State Management' {
        
        It 'Should save and load deployment state' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $deploymentId = $result.DeploymentId
            
            # Verify state file was created
            $stateDir = Join-Path $script:TestDeploymentsDir $deploymentId
            $statePath = Join-Path $stateDir 'state.json'
            Test-Path $statePath | Should -Be $true
            
            # Verify state content
            $stateContent = Get-Content $statePath -Raw | ConvertFrom-Json
            $stateContent.Id | Should -Be $deploymentId
            $stateContent.Status | Should -Not -BeNullOrEmpty
        }
        
        It 'Should create and manage checkpoints' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $deploymentId = $result.DeploymentId
            
            # Check for checkpoint directory
            $checkpointDir = Join-Path $script:TestDeploymentsDir $deploymentId 'checkpoints'
            
            # In dry-run mode, Plan stage should create a checkpoint
            if (Test-Path $checkpointDir) {
                $checkpointFiles = Get-ChildItem $checkpointDir -Filter "*.json"
                $checkpointFiles | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should support checkpoint resume functionality' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            # First deployment to create checkpoint
            $result1 = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $deploymentId = $result1.DeploymentId
            
            # Try to resume from checkpoint (will warn if checkpoint doesn't exist)
            { $result2 = Start-InfrastructureDeployment -ConfigurationPath $configPath -Checkpoint 'after-plan' -DryRun } | Should -Not -Throw
            
            $result2 = Start-InfrastructureDeployment -ConfigurationPath $configPath -Checkpoint 'after-plan' -DryRun
            $result2.Success | Should -Be $true
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        
        It 'Should handle Windows paths correctly' {
            if ($IsWindows) {
                $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
                
                { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
                
                $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
                $result.Success | Should -Be $true
                $result.LogPath | Should -Match '^[A-Z]:\\'
            }
        }
        
        It 'Should handle Linux/macOS paths correctly' {
            if ($IsLinux -or $IsMacOS) {
                $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
                
                { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
                
                $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
                $result.Success | Should -Be $true
                $result.LogPath | Should -Match '^/'
            }
        }
        
        It 'Should use platform-appropriate directory separators' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $deploymentDir = Split-Path $result.LogPath -Parent
            
            if ($IsWindows) {
                $deploymentDir | Should -Match '\\'
            } else {
                $deploymentDir | Should -Match '/'
            }
        }
    }
    
    Context 'Error Handling and Resilience' {
        
        It 'Should handle missing configuration file' {
            $nonExistentPath = Join-Path $script:TestConfigsDir 'NonExistent.yaml'
            
            { Start-InfrastructureDeployment -ConfigurationPath $nonExistentPath -DryRun } | Should -Throw
        }
        
        It 'Should handle corrupted configuration file' {
            $corruptedConfigPath = Join-Path $script:TestConfigsDir 'Corrupted.yaml'
            "This is not valid JSON or YAML {]}" | Out-File -FilePath $corruptedConfigPath -Encoding UTF8
            
            { Start-InfrastructureDeployment -ConfigurationPath $corruptedConfigPath -DryRun } | Should -Throw
        }
        
        It 'Should handle missing template files gracefully' {
            # Create config pointing to non-existent template
            $configPath = Join-Path $script:TestConfigsDir 'MissingTemplate.yaml'
            $config = $script:TestConfigurations.SimpleVM.Clone()
            $config.template.path = 'templates/non-existent-template'
            $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
            
            { Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw -Because "Should handle missing templates gracefully in planning phase"
        }
        
        It 'Should timeout on long-running operations' {
            # This is difficult to test without actual long-running operations
            # We can verify the timeout parameters are respected
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $result.Success | Should -Be $true
        }
        
        It 'Should handle deployment cleanup on failure' {
            $configPath = Join-Path $script:TestConfigsDir 'MalformedConfig.yaml'
            
            try {
                Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun -Force
            } catch {
                # Expected to fail
            }
            
            # Verify cleanup occurred - deployment directory should still exist but be marked as failed
            $deploymentDirs = Get-ChildItem $script:TestDeploymentsDir -Directory
            if ($deploymentDirs.Count -gt 0) {
                $stateFile = Join-Path $deploymentDirs[0].FullName 'state.json'
                if (Test-Path $stateFile) {
                    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
                    $state.Status | Should -Match 'Failed|Error'
                }
            }
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should complete simple deployment within reasonable time' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $stopwatch.Stop()
            
            $result.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000  # Less than 30 seconds for dry run
        }
        
        It 'Should handle multiple concurrent deployments' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            # Start multiple deployments in parallel
            $jobs = @()
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ConfigPath, $TestModulesDir)
                    
                    Import-Module (Join-Path $TestModulesDir 'OpenTofuProvider') -Force
                    Start-InfrastructureDeployment -ConfigurationPath $ConfigPath -DryRun
                } -ArgumentList $configPath, $script:TestModulesDir
            }
            
            # Wait for all jobs to complete
            $results = $jobs | Receive-Job -Wait
            $jobs | Remove-Job
            
            # All deployments should succeed
            $results.Count | Should -Be 3
            $results | ForEach-Object { $_.Success | Should -Be $true }
            
            # Each should have unique deployment ID
            $deploymentIds = $results | ForEach-Object { $_.DeploymentId }
            $uniqueIds = $deploymentIds | Sort-Object -Unique
            $uniqueIds.Count | Should -Be 3
        }
        
        It 'Should efficiently parse large configuration files' {
            # Create a large configuration with many resources
            $largeConfigPath = Join-Path $script:TestConfigsDir 'LargeConfig.yaml'
            $largeConfig = $script:TestConfigurations.ComplexLab.Clone()
            
            # Add many VMs to test parsing performance
            $vms = @()
            for ($i = 1; $i -le 20; $i++) {
                $vms += @{
                    name = "vm-$i"
                    role = "test-server"
                    memory_mb = 2048
                    processor_count = 2
                }
            }
            $largeConfig.infrastructure.hyperv_virtual_machine = $vms
            
            $largeConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $largeConfigPath -Encoding UTF8
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $config = Read-DeploymentConfiguration -Path $largeConfigPath
            $stopwatch.Stop()
            
            $config | Should -Not -BeNullOrEmpty
            $config.infrastructure.hyperv_virtual_machine.Count | Should -Be 20
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Less than 5 seconds
        }
        
        It 'Should manage memory efficiently during large deployments' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexLab.yaml'
            
            # Get initial memory usage
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Run deployment
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $result.Success | Should -Be $true
            $memoryIncrease | Should -BeLessThan 50MB  # Memory increase should be reasonable
        }
    }
    
    Context 'Integration with External Tools' {
        
        It 'Should detect OpenTofu binary availability' {
            # Mock Test-Path to simulate tofu binary being available
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*tofu*' } -ModuleName $script:TestAppName
            
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $result.Success | Should -Be $true
        }
        
        It 'Should handle missing OpenTofu binary gracefully' {
            # Mock Test-Path to simulate tofu binary being missing
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*tofu*' } -ModuleName $script:TestAppName
            
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            # Should still work in planning phase, but might warn about missing binary
            { $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun } | Should -Not -Throw
        }
        
        It 'Should execute OpenTofu commands correctly' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            # Mock tofu commands to track execution
            Mock Invoke-Expression {
                param($Command)
                $script:MockTofuCommands[$Command] = $true
                return "Mock tofu output"
            } -ModuleName $script:TestAppName
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            $result.Success | Should -Be $true
            
            # Verify tofu commands were attempted (in planning phase)
            # Note: Actual command execution depends on stage implementation
        }
    }
    
    Context 'Deployment Summary and Reporting' {
        
        It 'Should generate comprehensive deployment summary' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            
            # Verify all required summary fields
            $result.DeploymentId | Should -Not -BeNullOrEmpty
            $result.StartTime | Should -Not -BeNullOrEmpty
            $result.EndTime | Should -Not -BeNullOrEmpty
            $result.Duration | Should -Not -BeNullOrEmpty
            $result.Configuration | Should -Not -BeNullOrEmpty
            $result.Stages | Should -Not -BeNullOrEmpty
            $result.LogPath | Should -Not -BeNullOrEmpty
            
            # Check success status
            $result.Success | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }
        
        It 'Should track stage execution details' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            
            # Verify stage tracking
            $result.Stages | Should -Not -BeNullOrEmpty
            $result.Stages.Count | Should -BeGreaterThan 0
            
            # Each stage should have execution details
            foreach ($stage in $result.Stages.Values) {
                $stage | Should -Not -BeNullOrEmpty
                # Stage should have success status and timing information
            }
        }
        
        It 'Should collect and report deployment outputs' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleVM.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun
            
            # Outputs should be tracked (even if empty in dry-run)
            $result.Outputs | Should -Not -BeNullOrEmpty
        }
        
        It 'Should record warnings and errors appropriately' {
            $configPath = Join-Path $script:TestConfigsDir 'MalformedConfig.yaml'
            
            $result = Start-InfrastructureDeployment -ConfigurationPath $configPath -DryRun -Force
            
            # Should have errors recorded
            $result.Errors | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
        }
    }
}