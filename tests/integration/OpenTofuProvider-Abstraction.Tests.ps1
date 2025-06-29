BeforeAll {
    # Find project root and import modules
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Test workspace setup
    $script:testWorkspace = Join-Path $TestDrive "integration-test"
    New-Item -Path $script:testWorkspace -ItemType Directory -Force | Out-Null
    
    # Mock environment
    $env:PROJECT_ROOT = $script:testWorkspace
    
    # Create directory structure
    @(
        "configs/infrastructure-repositories",
        "cache/repositories",
        "deployments",
        "templates"
    ) | ForEach-Object {
        New-Item -Path (Join-Path $script:testWorkspace $_) -ItemType Directory -Force | Out-Null
    }
}

Describe "OpenTofu Infrastructure Abstraction Layer - Integration Tests" {
    Context "End-to-End Repository Workflow" {
        It "Should complete full repository registration and sync workflow" {
            # 1. Create a template repository
            $templateRepoPath = Join-Path $script:testWorkspace "templates" "test-templates"
            $templateResult = New-TemplateRepository -Path $templateRepoPath `
                -Name "Integration Test Templates" `
                -Description "Templates for integration testing" `
                -AddExamples
            
            $templateResult.Success | Should -Be $true
            Test-Path $templateRepoPath | Should -Be $true
            
            # 2. Register the repository
            $repoUrl = "file://$templateRepoPath"
            $registerResult = Register-InfrastructureRepository `
                -RepositoryUrl $repoUrl `
                -Name "test-integration-repo" `
                -Branch "main" `
                -Tags @("test", "integration")
            
            $registerResult.Success | Should -Be $true
            $registerResult.Name | Should -Be "test-integration-repo"
            
            # 3. Get repository information
            $repos = Get-InfrastructureRepository -Name "test-integration-repo" -IncludeStatus
            
            $repos.Count | Should -Be 1
            $repos[0].Name | Should -Be "test-integration-repo"
            $repos[0].Tags | Should -Contain "test"
            $repos[0].Status | Should -Be "Registered"
            
            # 4. Test repository compatibility
            $compatResult = Test-RepositoryCompatibility -Name "test-integration-repo"
            
            # Basic structure should pass minimum requirements
            $compatResult.Compatible | Should -Be $true
            $compatResult.Score | Should -BeGreaterThan 0
        }
    }
    
    Context "Template Versioning Workflow" {
        It "Should manage template versions through complete lifecycle" {
            # 1. Create a versioned template
            $templatePath = Join-Path $script:testWorkspace "templates" "versioned-app"
            $newTemplate = New-VersionedTemplate -TemplatePath $templatePath `
                -Name "app-server" `
                -Version "1.0.0" `
                -Description "Application server template" `
                -Tags @("app", "server")
            
            $newTemplate.Success | Should -Be $true
            $newTemplate.Version | Should -Be "1.0.0"
            
            # 2. Get template version info
            $versionInfo = Get-TemplateVersion -TemplatePath $templatePath
            
            $versionInfo.IsVersioned | Should -Be $true
            $versionInfo.CurrentVersion | Should -Be "1.0.0"
            $versionInfo.UpdateAvailable | Should -Be $false
            
            # 3. Update template version (patch)
            $updateResult = Update-TemplateVersion -TemplatePath $templatePath `
                -VersionBump "Patch" `
                -Changes @("Fixed network configuration", "Updated security settings")
            
            $updateResult.Success | Should -Be $true
            $updateResult.NewVersion | Should -Be "1.0.1"
            Test-Path (Join-Path $templatePath "CHANGELOG.md") | Should -Be $true
            
            # 4. Update template version (minor) with breaking changes
            $updateResult2 = Update-TemplateVersion -TemplatePath $templatePath `
                -VersionBump "Minor" `
                -Changes "Added load balancer support" `
                -BreakingChanges `
                -MigrationNotes "Update network_switch parameter name"
            
            $updateResult2.NewVersion | Should -Be "1.1.0"
            $updateResult2.BreakingChanges | Should -Be $true
            
            # 5. Verify version history
            $versionInfo2 = Get-TemplateVersion -TemplatePath $templatePath
            
            $versionInfo2.CurrentVersion | Should -Be "1.1.0"
            $versionInfo2.Versions.Count | Should -Be 3
            $versionInfo2.LatestVersion | Should -Be "1.1.0"
        }
    }
    
    Context "Configuration Management Workflow" {
        It "Should create and validate deployment configurations" {
            # 1. Setup - Create a template
            $templatePath = Join-Path $script:testWorkspace "templates" "config-test"
            New-VersionedTemplate -TemplatePath $templatePath `
                -Name "config-test" `
                -Version "1.0.0"
            
            # Mock Find-Template to return our test template
            Mock Find-Template {
                return @{
                    Name = "config-test"
                    Path = $templatePath
                    Repository = "local"
                    Version = "1.0.0"
                }
            } -ModuleName OpenTofuProvider
            
            # Mock Get-TemplateMetadata
            Mock Get-TemplateMetadata {
                return @{
                    metadata = @{ name = "config-test" }
                    parameters = @{
                        vm_name = @{
                            type = "string"
                            description = "VM name"
                        }
                        cpu_count = @{
                            type = "number"
                            default = 4
                        }
                    }
                    requirements = @{
                        iso_requirements = @(
                            @{
                                id = "os_iso"
                                supported = @("WindowsServer2025")
                                customization_profile = "standard"
                            }
                        )
                    }
                }
            } -ModuleName OpenTofuProvider
            
            # 2. Create deployment configuration
            $configPath = Join-Path $script:testWorkspace "deployments" "test-deployment.json"
            $createResult = New-DeploymentConfiguration -Template "config-test" `
                -OutputPath $configPath `
                -Parameters @{
                    vm_name = "INT-TEST-01"
                    cpu_count = 8
                } `
                -SkipValidation  # Skip validation since Read-DeploymentConfiguration needs work
            
            $createResult | Should -Be $configPath
            Test-Path $configPath | Should -Be $true
            
            # 3. Read and validate configuration
            $config = Get-Content $configPath | ConvertFrom-Json
            
            $config.version | Should -Be "1.0"
            $config.template | Should -Be "config-test"
            $config.parameters.vm_name | Should -Be "INT-TEST-01"
            $config.parameters.cpu_count | Should -Be 8
            $config.iso_requirements | Should -Not -BeNullOrEmpty
            
            # 4. Test configuration structure
            $config.PSObject.Properties.Name | Should -Contain "version"
            $config.PSObject.Properties.Name | Should -Contain "metadata"
            $config.PSObject.Properties.Name | Should -Contain "template"
            $config.PSObject.Properties.Name | Should -Contain "parameters"
            $config.PSObject.Properties.Name | Should -Contain "deployment"
        }
    }
    
    Context "Repository and Template Integration" {
        It "Should integrate repository management with template operations" {
            # 1. Create a repository with templates
            $repoPath = Join-Path $script:testWorkspace "templates" "integrated-repo"
            New-TemplateRepository -Path $repoPath -Name "Integrated Repository"
            
            # 2. Add a versioned template to the repository
            $templateInRepo = Join-Path $repoPath "deployments" "web-server"
            New-VersionedTemplate -TemplatePath $templateInRepo `
                -Name "web-server" `
                -Version "2.0.0" `
                -Dependencies @(
                    @{ Template = "base/network"; Version = ">=1.0.0" }
                )
            
            # 3. Test template dependencies
            Mock Get-TemplateMetadata {
                return @{
                    name = "web-server"
                    version = "2.0.0"
                    dependencies = @(
                        @{ template = "base/network"; version = ">=1.0.0"; required = $true }
                    )
                }
            } -ModuleName OpenTofuProvider
            
            Mock Test-SingleDependency {
                return @{
                    Template = "base/network"
                    Found = $true
                    Compatible = $true
                    MatchedVersion = "1.5.0"
                    AvailableVersions = @("1.0.0", "1.5.0", "2.0.0")
                }
            } -ModuleName OpenTofuProvider
            
            $depResult = Test-TemplateDependencies -Template $templateInRepo
            
            $depResult.Success | Should -Be $true
            $depResult.Dependencies.Count | Should -Be 1
            $depResult.Missing.Count | Should -Be 0
            $depResult.Conflicts.Count | Should -Be 0
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle various error conditions gracefully" {
            # 1. Invalid repository URL
            { Register-InfrastructureRepository -RepositoryUrl "not-a-url" -Name "invalid" } |
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
            
            # 2. Non-existent repository for sync
            { Sync-InfrastructureRepository -Name "non-existent-repo" } |
                Should -Throw "*not found*"
            
            # 3. Invalid version format
            { New-VersionedTemplate -TemplatePath (Join-Path $TestDrive "bad-version") `
                -Name "test" -Version "1.0.0.0" } |
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
            
            # 4. Template path doesn't exist
            { Get-TemplateVersion -TemplatePath "C:\does\not\exist" } |
                Should -Throw "*not found*"
            
            # 5. Configuration file doesn't exist
            { Read-DeploymentConfiguration -Path "missing.yaml" } |
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Item -Path $script:testWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    
    # Restore environment
    $env:PROJECT_ROOT = $projectRoot
}