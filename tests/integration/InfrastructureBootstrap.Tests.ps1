#Requires -Version 7.0

BeforeAll {
    # Import required modules
    $rootPath = Join-Path $PSScriptRoot ".." ".."
    $infraModulePath = Join-Path $rootPath "domains/infrastructure/Infrastructure.psm1"
    
    if (Test-Path $infraModulePath) {
        Import-Module $infraModulePath -Force
    } else {
        throw "Infrastructure module not found: $infraModulePath"
    }
    
    # Test configuration
    $script:TestConfig = @{
        Infrastructure = @{
            WorkingDirectory = Join-Path $TestDrive "test-infrastructure"
            Bootstrap = $true
            Provider = "opentofu"
        }
    }
}

Describe "Infrastructure Bootstrap Integration Tests" {
    
    Context "Prerequisites and Tool Detection" {
        
        It "Should detect missing OpenTofu/Terraform gracefully" {
            # Test with no tools available
            Mock Get-Command { return $null } -ParameterFilter { $Name -in @('tofu', 'terraform') }
            
            $result = Test-OpenTofu
            $result | Should -Be $false
        }
        
        It "Should prefer OpenTofu over Terraform when both available" {
            Mock Get-Command { 
                return @{ Name = 'tofu' } 
            } -ParameterFilter { $Name -eq 'tofu' } -ModuleName Infrastructure
            
            Mock Get-Command { 
                return @{ Name = 'terraform' } 
            } -ParameterFilter { $Name -eq 'terraform' } -ModuleName Infrastructure
            
            $tool = Get-InfrastructureTool
            $tool | Should -Be "tofu"
        }
        
        It "Should fallback to Terraform when OpenTofu not available" {
            Mock Get-Command { 
                return $null 
            } -ParameterFilter { $Name -eq 'tofu' } -ModuleName Infrastructure
            
            Mock Get-Command { 
                return @{ Name = 'terraform' } 
            } -ParameterFilter { $Name -eq 'terraform' } -ModuleName Infrastructure
            
            $tool = Get-InfrastructureTool
            $tool | Should -Be "terraform"
        }
    }
    
    Context "Directory Structure Creation" {
        
        It "Should create basic infrastructure directory structure" {
            $testDir = Join-Path $TestDrive "infra-structure-test"
            
            # Mock OpenTofu availability to skip tool checks
            Mock Test-OpenTofu { return $true } -ModuleName Infrastructure
            Mock Get-InfrastructureTool { return "tofu" } -ModuleName Infrastructure
            Mock Invoke-InfrastructureToolCommand { } -ModuleName Infrastructure
            
            $config = @{
                Infrastructure = @{
                    WorkingDirectory = $testDir
                    Bootstrap = $true
                }
            }
            
            $result = Start-InfrastructureBootstrap -Configuration $config -SkipPrerequisites
            
            # Should create directory structure
            $testDir | Should -Exist
            Join-Path $testDir "modules" | Should -Exist
            Join-Path $testDir "environments" | Should -Exist  
            Join-Path $testDir "shared" | Should -Exist
        }
        
        It "Should create basic Terraform configuration files" {
            $testDir = Join-Path $TestDrive "infra-files-test"
            
            # Mock OpenTofu availability
            Mock Test-OpenTofu { return $true }
            Mock Get-InfrastructureTool { return "tofu" }
            Mock Invoke-InfrastructureToolCommand { }
            
            $config = @{
                Infrastructure = @{
                    WorkingDirectory = $testDir
                    Bootstrap = $true
                }
            }
            
            $result = Start-InfrastructureBootstrap -Configuration $config -SkipPrerequisites
            
            # Should create configuration files
            Join-Path $testDir "main.tf" | Should -Exist
            Join-Path $testDir "variables.tf" | Should -Exist
            Join-Path $testDir "outputs.tf" | Should -Exist
            
            # Verify file contents
            $mainContent = Get-Content (Join-Path $testDir "main.tf") -Raw
            $mainContent | Should -Match "terraform"
            $mainContent | Should -Match "required_providers"
        }
    }
    
    Context "Configuration Validation" {
        
        It "Should validate Terraform configuration syntax" {
            $testDir = Join-Path $TestDrive "config-validation-test"
            New-Item -ItemType Directory -Path $testDir -Force
            
            # Create a valid main.tf
            $validConfig = @"
terraform {
  required_version = ">= 1.0"
}

resource "null_resource" "test" {
  # Test resource
}
"@
            Set-Content -Path (Join-Path $testDir "main.tf") -Value $validConfig
            
            # Mock tofu validate command
            Mock Invoke-InfrastructureToolCommand { 
                $global:LASTEXITCODE = 0
            } -ParameterFilter { $Arguments -contains 'validate' }
            
            Mock Get-InfrastructureTool { return "tofu" }
            
            $result = Test-InfrastructureConfiguration -WorkingDirectory $testDir
            $result | Should -Be $true
        }
        
        It "Should detect invalid Terraform configuration" {
            $testDir = Join-Path $TestDrive "invalid-config-test"
            New-Item -ItemType Directory -Path $testDir -Force
            
            # Create an invalid main.tf
            $invalidConfig = @"
invalid syntax here
resource "missing_quotes {
"@
            Set-Content -Path (Join-Path $testDir "main.tf") -Value $invalidConfig
            
            # Mock tofu validate command failure
            Mock Invoke-InfrastructureToolCommand { 
                $global:LASTEXITCODE = 1
                Write-Error "Invalid configuration"
            } -ParameterFilter { $Arguments -contains 'validate' }
            
            Mock Get-InfrastructureTool { return "tofu" }
            
            $result = Test-InfrastructureConfiguration -WorkingDirectory $testDir
            $result | Should -Be $false
        }
    }
    
    Context "State Management" {
        
        It "Should handle empty state gracefully" {
            $testDir = Join-Path $TestDrive "empty-state-test"
            New-Item -ItemType Directory -Path $testDir -Force
            
            # Mock empty state
            Mock Invoke-InfrastructureToolCommand { 
                $global:LASTEXITCODE = 1  # No state file
                return ""
            } -ParameterFilter { $Arguments[0] -eq 'state' }
            
            Mock Get-InfrastructureTool { return "tofu" }
            
            $state = Get-InfrastructureState -WorkingDirectory $testDir
            $state.Status | Should -Be "No state"
            $state.Resources | Should -BeEmpty
        }
        
        It "Should parse state list output correctly" {
            $testDir = Join-Path $TestDrive "state-parsing-test"
            New-Item -ItemType Directory -Path $testDir -Force
            
            $mockStateOutput = @"
azurerm_resource_group.main
azurerm_virtual_network.main
null_resource.test
"@
            
            # Mock state list command
            Mock Invoke-InfrastructureToolCommand { 
                $global:LASTEXITCODE = 0
                return $mockStateOutput
            } -ParameterFilter { $Arguments[0] -eq 'state' }
            
            # Mock output command (empty)
            Mock Invoke-InfrastructureToolCommand { 
                $global:LASTEXITCODE = 1
                return ""
            } -ParameterFilter { $Arguments[0] -eq 'output' }
            
            Mock Get-InfrastructureTool { return "tofu" }
            
            $state = Get-InfrastructureState -WorkingDirectory $testDir
            $state.Status | Should -Be "Active"
            $state.Resources.Count | Should -Be 3
            $state.Resources[0].Type | Should -Be "azurerm_resource_group"
            $state.Resources[0].Name | Should -Be "main"
        }
    }
    
    Context "Inventory Generation" {
        
        It "Should generate infrastructure inventory in Object format" {
            $testDir = Join-Path $TestDrive "inventory-object-test"
            
            # Mock state data
            Mock Get-InfrastructureState {
                return @{
                    Status = "Active"
                    ResourceCount = 2
                    Resources = @(
                        @{ Type = "azurerm_resource_group"; Name = "main"; FullName = "azurerm_resource_group.main" }
                        @{ Type = "null_resource"; Name = "test"; FullName = "null_resource.test" }
                    )
                    Outputs = @{ 
                        resource_group_name = @{ value = "rg-test" }
                    }
                }
            }
            
            $inventory = Get-InfrastructureInventory -WorkingDirectory $testDir -Format "Object"
            
            $inventory | Should -Not -BeNullOrEmpty
            $inventory.Status | Should -Be "Active"
            $inventory.Summary.TotalResources | Should -Be 2
            $inventory.Resources.Count | Should -Be 2
        }
        
        It "Should generate infrastructure inventory in JSON format" {
            $testDir = Join-Path $TestDrive "inventory-json-test"
            
            # Mock state data
            Mock Get-InfrastructureState {
                return @{
                    Status = "Active"
                    ResourceCount = 1
                    Resources = @(
                        @{ Type = "null_resource"; Name = "test"; FullName = "null_resource.test" }
                    )
                    Outputs = @{}
                }
            }
            
            $inventory = Get-InfrastructureInventory -WorkingDirectory $testDir -Format "JSON"
            
            $inventory | Should -Not -BeNullOrEmpty
            { $inventory | ConvertFrom-Json } | Should -Not -Throw
            
            $parsed = $inventory | ConvertFrom-Json
            $parsed.Status | Should -Be "Active"
        }
    }
}

Describe "Automation Script Integration Tests" {
    
    Context "Tailscale Installation Script" {
        
        It "Should handle disabled Tailscale configuration gracefully" {
            $scriptPath = Join-Path $rootPath "automation-scripts/0109_Install-Tailscale.ps1"
            
            $config = @{
                Features = @{
                    Infrastructure = @{
                        Tailscale = @{
                            Enabled = $false
                        }
                    }
                }
            }
            
            # Execute script with mocked configuration
            $result = & $scriptPath -Configuration $config
            $LASTEXITCODE | Should -Be 0
        }
    }
    
    Context "Hyper-V Configuration Script" {
        
        It "Should skip on non-Windows platforms" {
            $scriptPath = Join-Path $rootPath "automation-scripts/0110_Configure-HyperVHost.ps1"
            
            # Mock non-Windows environment
            if ($IsWindows) {
                # Skip this test on Windows since we can't mock $IsWindows effectively
                Set-ItResult -Skipped -Because "Running on Windows - cannot test non-Windows behavior"
                return
            }
            
            $config = @{
                Features = @{
                    Infrastructure = @{
                        HyperV = @{
                            Enabled = $true
                        }
                    }
                }
            }
            
            # Should exit gracefully on non-Windows
            $result = & $scriptPath -Configuration $config
            $LASTEXITCODE | Should -Be 0
        }
    }
}

AfterAll {
    # Clean up any test artifacts
    if (Get-Module Infrastructure) {
        Remove-Module Infrastructure -Force
    }
}