#Requires -Version 7.0

BeforeAll {
    # Import the core module which loads all domains
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZero.psm1") -Force
}

Describe "Infrastructure Module Tests" {
    Context "Test-OpenTofu" {
        It "Should detect OpenTofu or Terraform" {
            # Mock commands for testing
            Mock Get-Command {
                if ($Name -eq 'tofu') {
                    return @{ Name = 'tofu' }
                }
                throw "Command not found"
            } -ModuleName Infrastructure
            
            $result = Test-OpenTofu
            
            $result | Should -Be $true
        }
        
        It "Should return false when neither tool is available" {
            Mock Get-Command {
                throw "Command not found"
            } -ModuleName Infrastructure
            
            $result = Test-OpenTofu
            
            $result | Should -Be $false
        }
    }
    
    Context "Get-InfrastructureTool" {
        It "Should prefer OpenTofu over Terraform" {
            Mock Get-Command {
                param($Name)
                if ($Name -eq 'tofu' -or $Name -eq 'terraform') {
                    return @{ Name = $Name }
                }
                return $null
            } -ModuleName Infrastructure
            
            $tool = Get-InfrastructureTool
            
            $tool | Should -Be 'tofu'
        }
        
        It "Should fallback to Terraform when OpenTofu not available" {
            Mock Get-Command {
                param($Name)
                if ($Name -eq 'terraform') {
                    return @{ Name = $Name }
                }
                return $null
            } -ModuleName Infrastructure
            
            $tool = Get-InfrastructureTool
            
            $tool | Should -Be 'terraform'
        }
        
        It "Should throw when no tool is available" {
            Mock Get-Command { return $null } -ModuleName Infrastructure
            
            { Get-InfrastructureTool } | Should -Throw "Neither OpenTofu nor Terraform found in PATH"
        }
    }
    
    Context "Invoke-InfrastructurePlan" {
        BeforeEach {
            $script:TestInfraDir = Join-Path $TestDrive "infrastructure"
            New-Item -ItemType Directory -Path $script:TestInfraDir -Force
        }
        
        It "Should execute plan in specified directory" {
            Mock Get-InfrastructureTool { return 'tofu' } -ModuleName Infrastructure
            Mock Push-Location {} -ModuleName Infrastructure
            Mock Pop-Location {} -ModuleName Infrastructure
            
            $script:CommandsCalled = @()
            Mock Invoke-Expression {
                param($Command)
                $script:CommandsCalled += $Command
            } -ModuleName Infrastructure
            
            Invoke-InfrastructurePlan -WorkingDirectory $script:TestInfraDir
            
            $script:CommandsCalled | Should -Contain 'init'
            $script:CommandsCalled | Should -Contain 'plan'
        }
        
        It "Should handle missing directory gracefully" {
            $missingDir = Join-Path $TestDrive "missing"
            
            { Invoke-InfrastructurePlan -WorkingDirectory $missingDir } | Should -Not -Throw
        }
    }
    
    Context "Invoke-InfrastructureApply" {
        BeforeEach {
            $script:TestInfraDir = Join-Path $TestDrive "infrastructure"
            New-Item -ItemType Directory -Path $script:TestInfraDir -Force
        }
        
        It "Should apply with auto-approve when specified" {
            Mock Get-InfrastructureTool { return 'tofu' } -ModuleName Infrastructure
            Mock Push-Location {} -ModuleName Infrastructure
            Mock Pop-Location {} -ModuleName Infrastructure
            
            $script:CommandsAndArgs = @()
            Mock Invoke-Expression {
                $script:CommandsAndArgs += $args -join ' '
            } -ModuleName Infrastructure
            
            Invoke-InfrastructureApply -WorkingDirectory $script:TestInfraDir -AutoApprove
            
            $script:CommandsAndArgs | Should -Contain 'apply -auto-approve'
        }
        
        It "Should apply without auto-approve by default" {
            Mock Get-InfrastructureTool { return 'tofu' } -ModuleName Infrastructure
            Mock Push-Location {} -ModuleName Infrastructure
            Mock Pop-Location {} -ModuleName Infrastructure
            
            $script:CommandsAndArgs = @()
            Mock Invoke-Expression {
                $script:CommandsAndArgs += $args -join ' '
            } -ModuleName Infrastructure
            
            Invoke-InfrastructureApply -WorkingDirectory $script:TestInfraDir
            
            $script:CommandsAndArgs | Should -Contain 'apply'
            $script:CommandsAndArgs | Should -Not -Contain 'apply -auto-approve'
        }
    }
    
    Context "Invoke-InfrastructureDestroy" {
        BeforeEach {
            $script:TestInfraDir = Join-Path $TestDrive "infrastructure"
            New-Item -ItemType Directory -Path $script:TestInfraDir -Force
        }
        
        It "Should prompt for confirmation by default" {
            Mock Get-InfrastructureTool { return 'tofu' } -ModuleName Infrastructure
            Mock Read-Host { return 'no' } -ModuleName Infrastructure
            Mock Push-Location {} -ModuleName Infrastructure
            Mock Pop-Location {} -ModuleName Infrastructure
            
            $script:DestroyExecuted = $false
            Mock Invoke-Expression {
                if ($args -contains 'destroy') {
                    $script:DestroyExecuted = $true
                }
            } -ModuleName Infrastructure
            
            Invoke-InfrastructureDestroy -WorkingDirectory $script:TestInfraDir
            
            $script:DestroyExecuted | Should -Be $false
        }
        
        It "Should destroy with auto-approve when specified" {
            Mock Get-InfrastructureTool { return 'tofu' } -ModuleName Infrastructure
            Mock Push-Location {} -ModuleName Infrastructure
            Mock Pop-Location {} -ModuleName Infrastructure
            
            $script:CommandsAndArgs = @()
            Mock Invoke-Expression {
                $script:CommandsAndArgs += $args -join ' '
            } -ModuleName Infrastructure
            
            Invoke-InfrastructureDestroy -WorkingDirectory $script:TestInfraDir -AutoApprove
            
            $script:CommandsAndArgs | Should -Contain 'destroy -auto-approve'
        }
    }
    
    AfterAll {
        # Clean up
        Remove-Module aitherzero -Force -ErrorAction SilentlyContinue
    }
}