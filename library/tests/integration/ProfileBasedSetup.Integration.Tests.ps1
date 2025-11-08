#Requires -Version 7.0

<#
.SYNOPSIS
    Integration tests for profile-based environment setup system
.DESCRIPTION
    Tests the integration of OS-specific configuration, deployment artifacts, and profile-based setup
#>

BeforeAll {
    # Import the core module
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZero.psm1") -Force
    
    # Create test directory
    $script:TestOutputPath = Join-Path $TestDrive "integration-test"
    New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
}

Describe "Profile-Based Environment Setup Integration Tests" {
    Context "Module Loading and Availability" {
        It "Should load EnvironmentConfig module" {
            $module = Get-Module -Name EnvironmentConfig
            $module | Should -Not -BeNullOrEmpty
        }
        
        It "Should load DeploymentArtifacts module" {
            $module = Get-Module -Name DeploymentArtifacts  
            $module | Should -Not -BeNullOrEmpty
        }
        
        It "Should export environment configuration functions" {
            $functions = Get-Command -Module EnvironmentConfig
            $functions.Count | Should -BeGreaterThan 0
            
            # Key functions
            Get-Command Get-EnvironmentConfiguration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Set-EnvironmentConfiguration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export deployment artifact functions" {
            $functions = Get-Command -Module DeploymentArtifacts
            $functions.Count | Should -BeGreaterThan 0
            
            # Key functions
            Get-Command New-Dockerfile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command New-WindowsUnattendXml -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "Configuration System" {
        It "Should load base configuration" {
            $config = Get-Configuration
            $config | Should -Not -BeNullOrEmpty
        }
        
        It "Should have EnvironmentConfiguration section" {
            $config = Get-Configuration
            $config.EnvironmentConfiguration | Should -Not -BeNullOrEmpty
        }
        
        It "Should have DeploymentArtifacts section" {
            $config = Get-Configuration
            $config.DeploymentArtifacts | Should -Not -BeNullOrEmpty
        }
        
        It "Should have ExecutionProfiles in Automation section" {
            $config = Get-Configuration
            $config.Automation.ExecutionProfiles | Should -Not -BeNullOrEmpty
        }
        
        It "Should load OS-specific configuration on current platform" {
            $config = Get-Configuration
            
            if ($IsWindows) {
                $config.EnvironmentConfiguration.Windows | Should -Not -BeNullOrEmpty
            } elseif ($IsLinux) {
                $config.EnvironmentConfiguration.Unix | Should -Not -BeNullOrEmpty
            } elseif ($IsMacOS) {
                $config.EnvironmentConfiguration.macOS | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Environment Configuration Functions" {
        It "Should get current environment configuration" {
            { Get-EnvironmentConfiguration } | Should -Not -Throw
        }
        
        It "Should return configuration hashtable" {
            $result = Get-EnvironmentConfiguration
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should set environment configuration in dry-run mode" {
            $testConfig = @{
                EnvironmentConfiguration = @{
                    EnvironmentVariables = @{
                        System = @{
                            'TEST_VAR' = 'TestValue'
                        }
                    }
                }
            }
            
            { Set-EnvironmentConfiguration -Configuration $testConfig -DryRun } | Should -Not -Throw
        }
    }

    Context "Deployment Artifact Generation" {
        It "Should generate Windows Dockerfile" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile.windows"
            
            { New-Dockerfile -Platform Windows -OutputPath $outputFile } | Should -Not -Throw
            
            if (Test-Path $outputFile) {
                $content = Get-Content $outputFile -Raw
                $content | Should -Match "FROM"
            }
        }
        
        It "Should generate Linux Dockerfile" {
            $outputFile = Join-Path $script:TestOutputPath "Dockerfile"
            
            { New-Dockerfile -Platform Linux -OutputPath $outputFile } | Should -Not -Throw
            
            if (Test-Path $outputFile) {
                $content = Get-Content $outputFile -Raw
                $content | Should -Match "FROM"
            }
        }
        
        It "Should generate Unattend.xml" {
            $outputFile = Join-Path $script:TestOutputPath "Autounattend.xml"
            
            { New-WindowsUnattendXml -OutputPath $outputFile } | Should -Not -Throw
            
            if (Test-Path $outputFile) {
                $content = Get-Content $outputFile -Raw
                $content | Should -Match "unattend"
            }
        }
        
        It "Should generate cloud-init config" {
            $outputFile = Join-Path $script:TestOutputPath "cloud-init.yaml"
            
            { New-LinuxCloudInitConfig -OutputPath $outputFile } | Should -Not -Throw
            
            if (Test-Path $outputFile) {
                $content = Get-Content $outputFile -Raw
                $content | Should -Match "#cloud-config"
            }
        }
        
        It "Should generate Brewfile" {
            $outputFile = Join-Path $script:TestOutputPath "Brewfile"
            
            { New-MacOSBrewfile -OutputPath $outputFile } | Should -Not -Throw
        }
    }

    Context "Automation Scripts" {
        It "Should have environment configuration script" {
            $script = Get-Item "./automation-scripts/0001_Configure-Environment.ps1" -ErrorAction SilentlyContinue
            $script | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GitHub CLI installation script" {
            $script = Get-Item "./automation-scripts/0211_Install-GitHubCLI.ps1" -ErrorAction SilentlyContinue
            $script | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Go installation script" {
            $script = Get-Item "./automation-scripts/0212_Install-Go.ps1" -ErrorAction SilentlyContinue
            $script | Should -Not -BeNullOrEmpty
        }
        
        It "Should have AI CLIs installation script" {
            $script = Get-Item "./automation-scripts/0220_Install-AI-CLIs.ps1" -ErrorAction SilentlyContinue
            $script | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GitHub Runner installation script" {
            $script = Get-Item "./automation-scripts/0850_Install-GitHub-Runner.ps1" -ErrorAction SilentlyContinue
            $script | Should -Not -BeNullOrEmpty
        }
    }

    Context "Orchestration Playbooks" {
        It "Should have dev environment setup playbook" {
            $playbook = Get-Item "./orchestration/playbooks/dev-environment-setup.psd1" -ErrorAction SilentlyContinue
            $playbook | Should -Not -BeNullOrEmpty
        }
        
        It "Should have deployment environment playbook" {
            $playbook = Get-Item "./orchestration/playbooks/deployment-environment.psd1" -ErrorAction SilentlyContinue
            $playbook | Should -Not -BeNullOrEmpty
        }
        
        It "Should have self-hosted runner setup playbook" {
            $playbook = Get-Item "./orchestration/playbooks/self-hosted-runner-setup.psd1" -ErrorAction SilentlyContinue
            $playbook | Should -Not -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Support" {
        It "Should detect current platform correctly" {
            $config = Get-EnvironmentConfiguration
            
            $config.Keys | Should -Contain 'Platform'
            
            if ($IsWindows) {
                $config.Platform | Should -Match "Windows"
            } elseif ($IsLinux) {
                $config.Platform | Should -Match "Linux"
            } elseif ($IsMacOS) {
                $config.Platform | Should -Match "macOS"
            }
        }
        
        It "Should handle platform-specific operations gracefully" {
            # Windows-specific
            if ($IsWindows) {
                { Enable-WindowsLongPathSupport -DryRun } | Should -Not -Throw
            }
            
            # Unix-specific
            if (-not $IsWindows) {
                { Add-ShellIntegration -DryRun } | Should -Not -Throw
            }
        }
    }

    Context "Profile System" {
        It "Should have execution profiles defined" {
            $config = Get-Configuration
            $profiles = $config.Automation.ExecutionProfiles
            
            $profiles | Should -Not -BeNullOrEmpty
            $profiles.Count | Should -BeGreaterThan 0
        }
        
        It "Should have Development profile" {
            $config = Get-Configuration
            $profiles = $config.Automation.ExecutionProfiles
            
            $profiles.Development | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Deployment profile" {
            $config = Get-Configuration
            $profiles = $config.Automation.ExecutionProfiles
            
            $profiles.Deployment | Should -Not -BeNullOrEmpty
        }
        
        It "Should have AI-Development profile" {
            $config = Get-Configuration
            $profiles = $config.Automation.ExecutionProfiles
            
            $profiles.'AI-Development' | Should -Not -BeNullOrEmpty
        }
    }
}
