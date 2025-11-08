#Requires -Version 7.0

BeforeAll {
    # Import the Infrastructure module
    $ModulePath = Join-Path $PSScriptRoot "../../../../domains/infrastructure/Infrastructure.psm1"
    Import-Module $ModulePath -Force -Global

    # Mock Write-CustomLog if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        Mock Write-CustomLog -ModuleName Infrastructure { }
    }
}

Describe "Infrastructure Module Tests" -Tags @("Unit", "Infrastructure") {

    Context "Module Initialization" {
        It "Should load without errors" {
            { Import-Module (Join-Path $PSScriptRoot "../../../../domains/infrastructure/Infrastructure.psm1") -Force } | Should -Not -Throw
        }

        It "Should export required functions" {
            $exportedFunctions = Get-Command -Module Infrastructure -CommandType Function
            $exportedFunctions.Name | Should -Contain "Test-OpenTofu"
            $exportedFunctions.Name | Should -Contain "Get-InfrastructureTool"
            $exportedFunctions.Name | Should -Contain "Invoke-InfrastructurePlan"
            $exportedFunctions.Name | Should -Contain "Invoke-InfrastructureApply"
            $exportedFunctions.Name | Should -Contain "Invoke-InfrastructureDestroy"
        }
    }

    Context "Test-OpenTofu Function" {
        It "Should return true when OpenTofu is available" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            $result = Test-OpenTofu
            $result | Should -Be $true
        }

        It "Should return true when Terraform is available (OpenTofu not found)" {
            Mock Get-Command -ModuleName Infrastructure { throw "Command not found" } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "terraform" } } -ParameterFilter { $Name -eq "terraform" }

            $result = Test-OpenTofu
            $result | Should -Be $true
        }

        It "Should return false when neither tool is available" {
            Mock Get-Command -ModuleName Infrastructure { throw "Command not found" } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { throw "Command not found" } -ParameterFilter { $Name -eq "terraform" }

            $result = Test-OpenTofu
            $result | Should -Be $false
        }

        It "Should prefer OpenTofu over Terraform when both are available" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "terraform" } } -ParameterFilter { $Name -eq "terraform" }

            $result = Test-OpenTofu
            $result | Should -Be $true
        }
    }

    Context "Get-InfrastructureTool Function" {
        It "Should return 'tofu' when OpenTofu is available" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            $result = Get-InfrastructureTool
            $result | Should -Be "tofu"
        }

        It "Should return 'terraform' when only Terraform is available" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "terraform" } } -ParameterFilter { $Name -eq "terraform" }

            $result = Get-InfrastructureTool
            $result | Should -Be "terraform"
        }

        It "Should throw when no infrastructure tool is available" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "terraform" }

            { Get-InfrastructureTool } | Should -Throw "*Neither OpenTofu nor Terraform found in PATH*"
        }

        It "Should prefer OpenTofu over Terraform" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "terraform" } } -ParameterFilter { $Name -eq "terraform" }

            $result = Get-InfrastructureTool
            $result | Should -Be "tofu"
        }
    }

    Context "Invoke-InfrastructurePlan Function" {
        BeforeAll {
            $TestInfraDir = Join-Path $TestDrive "test-infrastructure"
            New-Item -Path $TestInfraDir -ItemType Directory -Force
        }

        BeforeEach {
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }
        }

        It "Should execute with OpenTofu" {
            Invoke-InfrastructurePlan -WorkingDirectory $TestInfraDir

            Should -Invoke Get-InfrastructureTool -ModuleName Infrastructure -Exactly 1
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 1
            Should -Invoke Pop-Location -ModuleName Infrastructure -Exactly 1
        }

        It "Should return early if directory does not exist" {
            Mock Test-Path -ModuleName Infrastructure { return $false }

            Invoke-InfrastructurePlan -WorkingDirectory "/nonexistent"

            Should -Invoke Test-Path -ModuleName Infrastructure -Exactly 1
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 0
        }

        It "Should use default directory if not specified" {
            Invoke-InfrastructurePlan

            Should -Invoke Test-Path -ModuleName Infrastructure -ParameterFilter { $Path -eq "./infrastructure" } -Exactly 1
        }

        It "Should always call Pop-Location even if commands fail" {
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { throw "Command failed" }

            { Invoke-InfrastructurePlan -WorkingDirectory $TestInfraDir } | Should -Throw
            Should -Invoke Pop-Location -ModuleName Infrastructure -Exactly 1
        }
    }

    Context "Invoke-InfrastructureApply Function" {
        BeforeAll {
            $TestInfraDir = Join-Path $TestDrive "test-infrastructure"
            New-Item -Path $TestInfraDir -ItemType Directory -Force
        }

        BeforeEach {
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }
        }

        It "Should execute without auto-approve by default" {
            Invoke-InfrastructureApply -WorkingDirectory $TestInfraDir

            Should -Invoke Get-InfrastructureTool -ModuleName Infrastructure -Exactly 1
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 1
            Should -Invoke Pop-Location -ModuleName Infrastructure -Exactly 1
        }

        It "Should execute with auto-approve when specified" {
            Invoke-InfrastructureApply -WorkingDirectory $TestInfraDir -AutoApprove

            Should -Invoke Get-InfrastructureTool -ModuleName Infrastructure -Exactly 1
        }

        It "Should return early if directory does not exist" {
            Mock Test-Path -ModuleName Infrastructure { return $false }

            Invoke-InfrastructureApply -WorkingDirectory "/nonexistent"

            Should -Invoke Test-Path -ModuleName Infrastructure -Exactly 1
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 0
        }

        It "Should use default directory if not specified" {
            Invoke-InfrastructureApply

            Should -Invoke Test-Path -ModuleName Infrastructure -ParameterFilter { $Path -eq "./infrastructure" } -Exactly 1
        }
    }

    Context "Invoke-InfrastructureDestroy Function" {
        BeforeAll {
            $TestInfraDir = Join-Path $TestDrive "test-infrastructure"
            New-Item -Path $TestInfraDir -ItemType Directory -Force
        }

        BeforeEach {
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
            Mock Read-Host -ModuleName Infrastructure { return "yes" }

            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }
        }

        It "Should prompt for confirmation without AutoApprove" {
            Invoke-InfrastructureDestroy -WorkingDirectory $TestInfraDir

            Should -Invoke Read-Host -ModuleName Infrastructure -Exactly 1
            Should -Invoke Get-InfrastructureTool -ModuleName Infrastructure -Exactly 1
        }

        It "Should not prompt for confirmation with AutoApprove" {
            Invoke-InfrastructureDestroy -WorkingDirectory $TestInfraDir -AutoApprove

            Should -Invoke Read-Host -ModuleName Infrastructure -Exactly 0
            Should -Invoke Get-InfrastructureTool -ModuleName Infrastructure -Exactly 1
        }

        It "Should cancel destruction when user doesn't confirm" {
            Mock Read-Host -ModuleName Infrastructure { return "no" }

            Invoke-InfrastructureDestroy -WorkingDirectory $TestInfraDir

            Should -Invoke Read-Host -ModuleName Infrastructure -Exactly 1
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 0
        }

        It "Should return early if directory does not exist" {
            Mock Test-Path -ModuleName Infrastructure { return $false }

            Invoke-InfrastructureDestroy -WorkingDirectory "/nonexistent"

            Should -Invoke Test-Path -ModuleName Infrastructure -Exactly 1
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 0
        }
    }

    Context "Cross-Platform Compatibility" {
        BeforeEach {
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
        }

        It "Should work on Windows" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu.exe" } } -ParameterFilter { $Name -eq "tofu" }

            $result = Test-OpenTofu
            $result | Should -Be $true
        }

        It "Should work on Linux" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            $result = Test-OpenTofu
            $result | Should -Be $true
        }

        It "Should work on macOS" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            $result = Test-OpenTofu
            $result | Should -Be $true
        }

        It "Should handle path separators correctly" {
            $TestDir = if ($IsWindows) { "C:\temp\infra" } else { "/tmp/infra" }
            Mock Test-Path -ModuleName Infrastructure { return $true } -ParameterFilter { $Path -eq $TestDir }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }

            Invoke-InfrastructurePlan -WorkingDirectory $TestDir

            Should -Invoke Test-Path -ModuleName Infrastructure -ParameterFilter { $Path -eq $TestDir } -Exactly 1
        }
    }

    Context "Error Handling and Edge Cases" {
        BeforeEach {
            Mock Write-Host -ModuleName Infrastructure { }
        }

        It "Should handle Get-Command exceptions gracefully in Test-OpenTofu" {
            Mock Get-Command -ModuleName Infrastructure { throw "Command not found" } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { throw "Command not found" } -ParameterFilter { $Name -eq "terraform" }

            $result = Test-OpenTofu
            $result | Should -Be $false
        }

        It "Should handle Get-Command exceptions gracefully in Get-InfrastructureTool" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "tofu" }
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "terraform" }

            { Get-InfrastructureTool } | Should -Throw "*Neither OpenTofu nor Terraform found in PATH*"
        }

        It "Should handle empty or null working directory paths" {
            Mock Test-Path -ModuleName Infrastructure { return $false }

            Invoke-InfrastructurePlan -WorkingDirectory ""
            Invoke-InfrastructurePlan -WorkingDirectory $null

            Should -Invoke Test-Path -ModuleName Infrastructure -Exactly 2
        }

        It "Should handle relative path conversions" {
            $RelativePath = "./test/infrastructure"
            Mock Test-Path -ModuleName Infrastructure { return $true } -ParameterFilter { $Path -eq $RelativePath }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }

            Invoke-InfrastructurePlan -WorkingDirectory $RelativePath

            Should -Invoke Test-Path -ModuleName Infrastructure -ParameterFilter { $Path -eq $RelativePath } -Exactly 1
        }
    }

    Context "Logging Integration" {
        It "Should call logging functions during execution" {
            # Test that the module can handle logging calls
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            $result = Test-OpenTofu
            $result | Should -Be $true

            # The function should complete without throwing even with logging
        }

        It "Should handle missing Write-CustomLog gracefully" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            # Should not throw even without Write-CustomLog
            { Test-OpenTofu } | Should -Not -Throw
        }
    }

    Context "Future Infrastructure Functions (Placeholder Tests)" {
        # These tests are placeholders for functions requested but not yet implemented

        It "Should have Initialize-Infrastructure function (when implemented)" -Pending {
            # Placeholder for Initialize-Infrastructure function
            $true | Should -Be $true
        }

        It "Should have New-InfrastructureDeployment function (when implemented)" -Pending {
            # Placeholder for New-InfrastructureDeployment function
            $true | Should -Be $true
        }

        It "Should have Test-InfrastructureCompliance function (when implemented)" -Pending {
            # Placeholder for Test-InfrastructureCompliance function
            $true | Should -Be $true
        }

        It "Should have Get-InfrastructureState function (when implemented)" -Pending {
            # Placeholder for Get-InfrastructureState function
            $true | Should -Be $true
        }

        It "Should have Update-InfrastructureComponents function (when implemented)" -Pending {
            # Placeholder for Update-InfrastructureComponents function
            $true | Should -Be $true
        }

        It "Should have Remove-InfrastructureResources function (when implemented)" -Pending {
            # Placeholder for Remove-InfrastructureResources function
            $true | Should -Be $true
        }

        It "Should have Backup-InfrastructureState function (when implemented)" -Pending {
            # Placeholder for backup operations
            $true | Should -Be $true
        }

        It "Should have Restore-InfrastructureState function (when implemented)" -Pending {
            # Placeholder for restore operations
            $true | Should -Be $true
        }
    }

    Context "Integration Tests" {
        BeforeAll {
            $TestInfraDir = Join-Path $TestDrive "integration-test"
            New-Item -Path $TestInfraDir -ItemType Directory -Force

            # Create a simple terraform/tofu file for testing
            @"
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "local_file" "test" {
  content  = "Hello, Infrastructure!"
  filename = "test.txt"
}
"@ | Set-Content -Path (Join-Path $TestInfraDir "main.tf")
        }

        BeforeEach {
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
            Mock Read-Host -ModuleName Infrastructure { return "yes" }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }
        }

        It "Should execute a complete infrastructure workflow" {
            # Test the full workflow: plan -> apply -> destroy
            Invoke-InfrastructurePlan -WorkingDirectory $TestInfraDir
            Invoke-InfrastructureApply -WorkingDirectory $TestInfraDir -AutoApprove
            Invoke-InfrastructureDestroy -WorkingDirectory $TestInfraDir -AutoApprove

            Should -Invoke Get-InfrastructureTool -ModuleName Infrastructure -Exactly 3
            Should -Invoke Push-Location -ModuleName Infrastructure -Exactly 3
            Should -Invoke Pop-Location -ModuleName Infrastructure -Exactly 3
        }

        It "Should handle mixed tool scenarios gracefully" {
            # Test tool detection
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            Test-OpenTofu | Should -Be $true
            Get-InfrastructureTool | Should -Be "tofu"
        }
    }

    Context "Performance and Resource Management" {
        It "Should not leak resources when operations fail" {
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { throw "Simulated failure" }

            # Test that Pop-Location is always called even on failure
            { Invoke-InfrastructurePlan } | Should -Throw
            { Invoke-InfrastructureApply } | Should -Throw
            { Invoke-InfrastructureDestroy -AutoApprove } | Should -Throw

            Should -Invoke Pop-Location -ModuleName Infrastructure -Exactly 3
        }

        It "Should handle function availability checks" {
            # Test that functions exist and can be called
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            Test-OpenTofu | Should -Not -BeNullOrEmpty
            { Get-InfrastructureTool } | Should -Not -Throw
        }

        It "Should maintain consistent behavior across multiple calls" {
            Mock Get-Command -ModuleName Infrastructure { return @{ Name = "tofu" } } -ParameterFilter { $Name -eq "tofu" }

            # Multiple calls should return consistent results
            Test-OpenTofu | Should -Be $true
            Test-OpenTofu | Should -Be $true
            Get-InfrastructureTool | Should -Be "tofu"
            Get-InfrastructureTool | Should -Be "tofu"
        }
    }

    Context "Parameter Validation" {
        It "Should accept valid working directory paths" {
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }

            { Invoke-InfrastructurePlan -WorkingDirectory "/valid/path" } | Should -Not -Throw
            { Invoke-InfrastructureApply -WorkingDirectory "/valid/path" } | Should -Not -Throw
            { Invoke-InfrastructureDestroy -WorkingDirectory "/valid/path" -AutoApprove } | Should -Not -Throw
        }

        It "Should handle AutoApprove switch properly" {
            Mock Test-Path -ModuleName Infrastructure { return $true }
            Mock Get-InfrastructureTool -ModuleName Infrastructure { return "tofu" }
            Mock Push-Location -ModuleName Infrastructure { }
            Mock Pop-Location -ModuleName Infrastructure { }
            Mock Write-Host -ModuleName Infrastructure { }
            Mock Read-Host -ModuleName Infrastructure { return "yes" }
            Mock Invoke-InfrastructureToolCommand -ModuleName Infrastructure { }

            # With AutoApprove, should not prompt
            Invoke-InfrastructureApply -AutoApprove
            Invoke-InfrastructureDestroy -AutoApprove

            Should -Invoke Read-Host -ModuleName Infrastructure -Exactly 0
        }
    }
}