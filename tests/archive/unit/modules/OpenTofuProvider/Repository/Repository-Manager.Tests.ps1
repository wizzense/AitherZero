BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Mock data
    $script:testRepoUrl = "https://github.com/test/infrastructure-templates.git"
    $script:testRepoName = "test-repo"
    $script:testCachePath = Join-Path $TestDrive "cache" "repositories" $testRepoName
    $script:testRegistryPath = Join-Path $TestDrive "configs" "infrastructure-repositories"
}

Describe "Register-InfrastructureRepository Tests" {
    BeforeEach {
        # Create test registry directory
        New-Item -Path $script:testRegistryPath -ItemType Directory -Force | Out-Null
        
        # Mock environment variable
        $env:PROJECT_ROOT = $TestDrive
    }
    
    AfterEach {
        # Clean up
        Remove-Item -Path $script:testRegistryPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Context "Parameter Validation" {
        It "Should validate repository URL format" {
            { Register-InfrastructureRepository -RepositoryUrl "invalid-url" -Name "test" } | 
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
        }
        
        It "Should validate repository name format" {
            { Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name "test@repo!" } | 
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
        }
        
        It "Should validate cache TTL range" {
            { Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name "test" -CacheTTL 100 } | 
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
        }
    }
    
    Context "Repository Registration" {
        It "Should create repository configuration file" {
            $result = Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName
            
            $result.Success | Should -Be $true
            $result.Name | Should -Be $script:testRepoName
            $result.RepositoryUrl | Should -Be $script:testRepoUrl
            
            $configFile = Join-Path $script:testRegistryPath "$($script:testRepoName).json"
            Test-Path $configFile | Should -Be $true
        }
        
        It "Should handle existing repository" {
            # Register first time
            Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName
            
            # Register again - should update
            $result = Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName -Branch "develop"
            
            $result.Success | Should -Be $true
            $result.Branch | Should -Be "develop"
        }
        
        It "Should support WhatIf" {
            $result = Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName -WhatIf
            
            $result.WhatIf | Should -Be $true
            $configFile = Join-Path $script:testRegistryPath "$($script:testRepoName).json"
            Test-Path $configFile | Should -Be $false
        }
    }
    
    Context "Auto-Sync Feature" {
        It "Should skip auto-sync when not requested" {
            Mock Sync-InfrastructureRepository { return @{ Success = $true } }
            
            Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName
            
            Should -Not -Invoke Sync-InfrastructureRepository
        }
        
        It "Should perform auto-sync when requested" {
            Mock Sync-InfrastructureRepository { return @{ Success = $true } }
            
            Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName -AutoSync
            
            Should -Invoke Sync-InfrastructureRepository -Times 1 -ParameterFilter {
                $Name -eq $script:testRepoName
            }
        }
    }
}

Describe "Get-InfrastructureRepository Tests" {
    BeforeEach {
        # Create test environment
        $env:PROJECT_ROOT = $TestDrive
        New-Item -Path $script:testRegistryPath -ItemType Directory -Force | Out-Null
        
        # Create test repositories
        $repos = @(
            @{ Name = "repo1"; Tags = @("production", "hyperv") },
            @{ Name = "repo2"; Tags = @("development", "testing") },
            @{ Name = "repo3"; Tags = @("production", "azure") }
        )
        
        foreach ($repo in $repos) {
            $config = @{
                Name = $repo.Name
                RepositoryUrl = "https://github.com/test/$($repo.Name).git"
                Branch = "main"
                Tags = $repo.Tags
                CacheTTL = 86400
                CachePath = Join-Path $TestDrive "cache" $repo.Name
                RegisteredDate = Get-Date
                LastModified = Get-Date
                Status = "Registered"
            }
            
            $configPath = Join-Path $script:testRegistryPath "$($repo.Name).json"
            $config | ConvertTo-Json | Set-Content -Path $configPath
        }
    }
    
    Context "Repository Listing" {
        It "Should list all repositories" {
            $repos = Get-InfrastructureRepository
            
            $repos.Count | Should -Be 3
            $repos.Name | Should -Contain "repo1"
            $repos.Name | Should -Contain "repo2"
            $repos.Name | Should -Contain "repo3"
        }
        
        It "Should filter by name with wildcards" {
            $repos = Get-InfrastructureRepository -Name "repo*"
            $repos.Count | Should -Be 3
            
            $repos = Get-InfrastructureRepository -Name "repo1"
            $repos.Count | Should -Be 1
            $repos[0].Name | Should -Be "repo1"
        }
        
        It "Should filter by tags" {
            $repos = Get-InfrastructureRepository -Tag "production"
            $repos.Count | Should -Be 2
            $repos.Name | Should -Contain "repo1"
            $repos.Name | Should -Contain "repo3"
            
            $repos = Get-InfrastructureRepository -Tag "hyperv"
            $repos.Count | Should -Be 1
            $repos[0].Name | Should -Be "repo1"
        }
    }
    
    Context "Status Information" {
        It "Should include status when requested" {
            $repos = Get-InfrastructureRepository -IncludeStatus
            
            $repos[0].PSObject.Properties.Name | Should -Contain "Status"
            $repos[0].PSObject.Properties.Name | Should -Contain "LastSync"
            $repos[0].PSObject.Properties.Name | Should -Contain "CacheExpired"
            $repos[0].PSObject.Properties.Name | Should -Contain "CacheExists"
        }
        
        It "Should calculate cache expiry correctly" {
            # Update one repo with recent sync
            $config = Get-Content (Join-Path $script:testRegistryPath "repo1.json") | ConvertFrom-Json
            $config.LastSync = (Get-Date).AddHours(-1)
            $config | ConvertTo-Json | Set-Content -Path (Join-Path $script:testRegistryPath "repo1.json")
            
            $repo = Get-InfrastructureRepository -Name "repo1" -IncludeStatus
            
            $repo.CacheExpired | Should -Be $false
            $repo.CacheExpiry | Should -BeGreaterThan (Get-Date)
        }
    }
}

Describe "Sync-InfrastructureRepository Tests" {
    BeforeEach {
        $env:PROJECT_ROOT = $TestDrive
        New-Item -Path $script:testRegistryPath -ItemType Directory -Force | Out-Null
        
        # Register test repository
        Register-InfrastructureRepository -RepositoryUrl $script:testRepoUrl -Name $script:testRepoName
    }
    
    Context "Basic Sync Operations" {
        It "Should handle missing repository" {
            { Sync-InfrastructureRepository -Name "non-existent" } | 
                Should -Throw "*not found*"
        }
        
        It "Should respect cache validity" {
            # Set recent sync time
            $configPath = Join-Path $script:testRegistryPath "$($script:testRepoName).json"
            $config = Get-Content $configPath | ConvertFrom-Json
            $config.LastSync = Get-Date
            $config | ConvertTo-Json | Set-Content -Path $configPath
            
            $result = Sync-InfrastructureRepository -Name $script:testRepoName
            
            $result.Status | Should -Be "CacheValid"
            $result.Success | Should -Be $true
        }
        
        It "Should force sync when requested" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0; return "Success" }
            
            # Set recent sync time
            $configPath = Join-Path $script:testRegistryPath "$($script:testRepoName).json"
            $config = Get-Content $configPath | ConvertFrom-Json
            $config.LastSync = Get-Date
            $config | ConvertTo-Json | Set-Content -Path $configPath
            
            $result = Sync-InfrastructureRepository -Name $script:testRepoName -Force
            
            $result.Status | Should -Be "Synced"
            Should -Invoke Invoke-Expression
        }
    }
    
    Context "Offline Mode" {
        It "Should use cache in offline mode" {
            # Create cache directory
            New-Item -Path $script:testCachePath -ItemType Directory -Force | Out-Null
            
            $result = Sync-InfrastructureRepository -Name $script:testRepoName -Offline
            
            $result.Status | Should -Be "Offline"
            $result.Success | Should -Be $true
        }
        
        It "Should fail offline mode without cache" {
            { Sync-InfrastructureRepository -Name $script:testRepoName -Offline } | 
                Should -Throw "*No offline cache available*"
        }
    }
}

Describe "Test-RepositoryCompatibility Tests" {
    BeforeEach {
        $script:testRepoPath = Join-Path $TestDrive "test-repo"
        New-Item -Path $script:testRepoPath -ItemType Directory -Force | Out-Null
        
        # Mock Get-ProjectVersion
        Mock Get-ProjectVersion { return "1.0.0" }
    }
    
    Context "Repository Structure Validation" {
        It "Should detect missing Terraform files" {
            $result = Test-RepositoryCompatibility -Path $script:testRepoPath -Detailed
            
            $result.Compatible | Should -Be $false
            $result.Issues | Should -Contain "No Terraform/OpenTofu files (*.tf) found"
        }
        
        It "Should validate Hyper-V provider presence" {
            # Create a .tf file without Hyper-V provider
            @'
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
'@ | Set-Content -Path (Join-Path $script:testRepoPath "main.tf")
            
            $result = Test-RepositoryCompatibility -Path $script:testRepoPath -Detailed
            
            $result.Compatible | Should -Be $false
            $result.Issues | Should -Contain "Hyper-V provider not found in any .tf file"
        }
        
        It "Should pass with valid structure" {
            # Create valid structure
            @'
terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">= 1.2.1"
    }
  }
}
'@ | Set-Content -Path (Join-Path $script:testRepoPath "main.tf")
            
            "# Test Repository" | Set-Content -Path (Join-Path $script:testRepoPath "README.md")
            
            $result = Test-RepositoryCompatibility -Path $script:testRepoPath -Detailed
            
            $result.Compatible | Should -Be $true
            $result.Score | Should -BeGreaterThan 50
        }
    }
    
    Context "Scoring System" {
        It "Should calculate scores based on completeness" {
            # Create minimal valid repo
            @'
provider "hyperv" {
  host = var.hyperv_host
}
'@ | Set-Content -Path (Join-Path $script:testRepoPath "main.tf")
            
            $result1 = Test-RepositoryCompatibility -Path $script:testRepoPath -Detailed
            $score1 = $result1.Score
            
            # Add more files for better score
            "variable vm_name {}" | Set-Content -Path (Join-Path $script:testRepoPath "variables.tf")
            "output vm_id {}" | Set-Content -Path (Join-Path $script:testRepoPath "outputs.tf")
            "# README" | Set-Content -Path (Join-Path $script:testRepoPath "README.md")
            New-Item -Path (Join-Path $script:testRepoPath "examples") -ItemType Directory -Force | Out-Null
            
            $result2 = Test-RepositoryCompatibility -Path $script:testRepoPath -Detailed
            $score2 = $result2.Score
            
            $score2 | Should -BeGreaterThan $score1
        }
    }
}

Describe "New-TemplateRepository Tests" {
    Context "Repository Creation" {
        It "Should create complete repository structure" {
            $repoPath = Join-Path $TestDrive "new-template-repo"
            
            $result = New-TemplateRepository -Path $repoPath -Name "Test Templates" -AddExamples
            
            $result.Success | Should -Be $true
            Test-Path $repoPath | Should -Be $true
            Test-Path (Join-Path $repoPath "template.yaml") | Should -Be $true
            Test-Path (Join-Path $repoPath "README.md") | Should -Be $true
            Test-Path (Join-Path $repoPath ".gitignore") | Should -Be $true
            Test-Path (Join-Path $repoPath "base") | Should -Be $true
            Test-Path (Join-Path $repoPath "deployments") | Should -Be $true
            Test-Path (Join-Path $repoPath "examples") | Should -Be $true
        }
        
        It "Should fail on non-empty directory" {
            $repoPath = Join-Path $TestDrive "existing-repo"
            New-Item -Path $repoPath -ItemType Directory -Force | Out-Null
            "test" | Set-Content -Path (Join-Path $repoPath "file.txt")
            
            { New-TemplateRepository -Path $repoPath -Name "Test" } | 
                Should -Throw "*not empty*"
        }
    }
}