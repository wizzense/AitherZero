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
}

Describe "Infrastructure System Validation Tests" {
    
    Context "Module Loading and Functions" {
        
        It "Infrastructure module should load successfully" {
            Get-Module Infrastructure | Should -Not -BeNullOrEmpty
        }
        
        It "Should export all required infrastructure functions" {
            $expectedFunctions = @(
                'Test-OpenTofu',
                'Get-InfrastructureTool',
                'Invoke-InfrastructurePlan',
                'Invoke-InfrastructureApply',
                'Invoke-InfrastructureDestroy',
                'Get-InfrastructureState',
                'Test-InfrastructureConfiguration',
                'Invoke-InfrastructureRefresh',
                'Get-InfrastructureInventory',
                'Start-InfrastructureBootstrap'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$function should be exported"
            }
        }
    }
    
    Context "Directory Structure Creation" {
        
        It "Should create infrastructure directory structure when bootstrap is called" {
            $testDir = Join-Path $TestDrive "bootstrap-structure-test"
            
            # Create a mock configuration that will trigger fallback bootstrap
            $config = @{
                Infrastructure = @{
                    WorkingDirectory = $testDir
                    Bootstrap = $true
                }
            }
            
            # Call bootstrap with SkipPrerequisites to avoid tool checks
            try {
                Start-InfrastructureBootstrap -Configuration $config -SkipPrerequisites
            } catch {
                # Expected to fail due to missing tools, but should still create structure
            }
            
            # Verify directory structure was created
            $testDir | Should -Exist
            Join-Path $testDir "modules" | Should -Exist
            Join-Path $testDir "environments" | Should -Exist
            Join-Path $testDir "shared" | Should -Exist
        }
        
        It "Should create basic Terraform configuration files during bootstrap" {
            $testDir = Join-Path $TestDrive "bootstrap-files-test"
            
            $config = @{
                Infrastructure = @{
                    WorkingDirectory = $testDir
                    Bootstrap = $true
                }
            }
            
            # Call bootstrap
            try {
                Start-InfrastructureBootstrap -Configuration $config -SkipPrerequisites
            } catch {
                # Expected to fail due to missing tools
            }
            
            # Should create configuration files
            Join-Path $testDir "main.tf" | Should -Exist
            Join-Path $testDir "variables.tf" | Should -Exist
            Join-Path $testDir "outputs.tf" | Should -Exist
            
            # Verify file contents contain expected patterns
            $mainContent = Get-Content (Join-Path $testDir "main.tf") -Raw
            $mainContent | Should -Match "terraform"
            $mainContent | Should -Match "required_providers"
        }
    }
    
    Context "Tool Detection Logic" {
        
        It "Test-OpenTofu should handle missing tools gracefully" {
            # This will test the actual function with real system state
            $result = Test-OpenTofu
            # Should return boolean without throwing
            $result | Should -BeOfType [bool]
        }
        
        It "Get-InfrastructureTool should provide meaningful error when no tools available" {
            # Only run if no tools are actually available
            if (-not (Get-Command tofu -ErrorAction SilentlyContinue) -and 
                -not (Get-Command terraform -ErrorAction SilentlyContinue)) {
                
                { Get-InfrastructureTool } | Should -Throw -ExpectedMessage "*Neither OpenTofu nor Terraform found*"
            }
        }
    }
    
    Context "State Management Functions" {
        
        It "Get-InfrastructureState should handle non-existent directory gracefully" {
            $nonExistentDir = Join-Path $TestDrive "non-existent-dir"
            
            $state = Get-InfrastructureState -WorkingDirectory $nonExistentDir
            $state | Should -BeNullOrEmpty
        }
        
        It "Get-InfrastructureInventory should handle empty directory" {
            $emptyDir = Join-Path $TestDrive "empty-inventory-test"
            New-Item -ItemType Directory -Path $emptyDir -Force
            
            $inventory = Get-InfrastructureInventory -WorkingDirectory $emptyDir
            
            # Should return an object with "Tool not available" status when no infrastructure tool is present
            if ($inventory) {
                $inventory.Status | Should -Be "Tool not available"
                $inventory.Summary.TotalResources | Should -Be 0
            } else {
                # Or null if directory doesn't meet requirements
                $inventory | Should -BeNullOrEmpty
            }
        }
    }
}

Describe "Automation Scripts Validation" {
    
    Context "Script Existence and Syntax" {
        
        It "All infrastructure scripts should exist and have valid syntax" {
            $scriptsToTest = @(
                "0008_Install-OpenTofu.ps1",
                "0009_Initialize-OpenTofu.ps1", 
                "0109_Install-Tailscale.ps1",
                "0110_Configure-HyperVHost.ps1",
                "0300_Deploy-Infrastructure.ps1"
            )
            
            foreach ($script in $scriptsToTest) {
                $scriptPath = Join-Path $rootPath "automation-scripts" $script
                $scriptPath | Should -Exist -Because "$script should exist"
                
                # Test syntax using modern AST parser
                $errors = $null
                $tokens = $null
                $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
                $errors | Should -BeNullOrEmpty -Because "$script should have valid PowerShell syntax"
            }
        }
    }
    
    Context "Tailscale Installation Script" {
        
        It "Should handle disabled configuration gracefully" {
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
            
            # Should exit successfully when disabled
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
    }
    
    Context "Hyper-V Configuration Script" {
        
        It "Should handle non-Windows platforms gracefully" {
            $scriptPath = Join-Path $rootPath "automation-scripts/0110_Configure-HyperVHost.ps1"
            
            if (-not $IsWindows) {
                $config = @{
                    Features = @{
                        Infrastructure = @{
                            HyperV = @{
                                Enabled = $true
                            }
                        }
                    }
                }
                
                # Should exit successfully on non-Windows
                { & $scriptPath -Configuration $config } | Should -Not -Throw
            }
        }
    }
}

Describe "Playbook Configuration Validation" {
    
    Context "Playbook Files" {
        
        It "All infrastructure playbooks should exist and have valid JSON" {
            $playbookDir = Join-Path $rootPath "orchestration/playbooks/setup"
            $playbooks = @(
                "infrastructure-bootstrap.json",
                "zero-to-cloud.json", 
                "zero-to-hyperv-host.json"
            )
            
            foreach ($playbook in $playbooks) {
                $playbookPath = Join-Path $playbookDir $playbook
                $playbookPath | Should -Exist -Because "$playbook should exist"
                
                # Test JSON validity
                $content = Get-Content $playbookPath -Raw
                { $content | ConvertFrom-Json } | Should -Not -Throw -Because "$playbook should contain valid JSON"
                
                # Verify required structure
                $parsed = $content | ConvertFrom-Json
                $parsed.Name | Should -Not -BeNullOrEmpty
                $parsed.Description | Should -Not -BeNullOrEmpty
                $parsed.Stages | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Infrastructure bootstrap playbook should have correct sequence" {
            $playbookPath = Join-Path $rootPath "orchestration/playbooks/setup/infrastructure-bootstrap.json"
            $content = Get-Content $playbookPath -Raw | ConvertFrom-Json
            
            # Should contain infrastructure tools installation
            $toolsStage = $content.Stages | Where-Object { $_.Name -eq "Infrastructure Tools" }
            $toolsStage | Should -Not -BeNullOrEmpty
            $toolsStage.Sequence | Should -Contain "0008"  # OpenTofu installation
            $toolsStage.Sequence | Should -Contain "0009"  # OpenTofu initialization
        }
        
        It "Zero-to-hyperv-host playbook should include all required stages" {
            $playbookPath = Join-Path $rootPath "orchestration/playbooks/setup/zero-to-hyperv-host.json"
            $content = Get-Content $playbookPath -Raw | ConvertFrom-Json
            
            $requiredStages = @(
                "Environment Preparation",
                "Core Infrastructure Tools", 
                "Hyper-V Installation",
                "Infrastructure Bootstrap"
            )
            
            foreach ($requiredStage in $requiredStages) {
                $stage = $content.Stages | Where-Object { $_.Name -eq $requiredStage }
                $stage | Should -Not -BeNullOrEmpty -Because "Stage '$requiredStage' should exist"
            }
        }
    }
}

AfterAll {
    # Clean up
    if (Get-Module Infrastructure) {
        Remove-Module Infrastructure -Force -ErrorAction SilentlyContinue
    }
}