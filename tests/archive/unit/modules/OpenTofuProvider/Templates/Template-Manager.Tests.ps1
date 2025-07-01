BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Mock Get-ProjectVersion
    Mock Get-ProjectVersion { return "1.0.0" } -ModuleName OpenTofuProvider
}

Describe "New-VersionedTemplate Tests" {
    BeforeEach {
        $script:testTemplatePath = Join-Path $TestDrive "test-template"
    }
    
    AfterEach {
        Remove-Item -Path $script:testTemplatePath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Context "Template Creation" {
        It "Should create versioned template structure" {
            $result = New-VersionedTemplate -TemplatePath $script:testTemplatePath `
                -Name "test-template" `
                -Version "1.0.0" `
                -Description "Test template"
            
            $result.Success | Should -Be $true
            $result.Name | Should -Be "test-template"
            $result.Version | Should -Be "1.0.0"
            
            # Check directory structure
            Test-Path $script:testTemplatePath | Should -Be $true
            Test-Path (Join-Path $script:testTemplatePath "versions") | Should -Be $true
            Test-Path (Join-Path $script:testTemplatePath "versions" "1.0.0") | Should -Be $true
            Test-Path (Join-Path $script:testTemplatePath "template.yaml") | Should -Be $true
            Test-Path (Join-Path $script:testTemplatePath "README.md") | Should -Be $true
        }
        
        It "Should fail on existing non-empty directory" {
            New-Item -Path $script:testTemplatePath -ItemType Directory -Force | Out-Null
            "test" | Set-Content -Path (Join-Path $script:testTemplatePath "file.txt")
            
            { New-VersionedTemplate -TemplatePath $script:testTemplatePath -Name "test" } | 
                Should -Throw "*not empty*"
        }
        
        It "Should validate version format" {
            { New-VersionedTemplate -TemplatePath $script:testTemplatePath -Name "test" -Version "1.0" } | 
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
        }
        
        It "Should create template with dependencies" {
            $deps = @(
                @{ Template = "base/network"; Version = ">=2.0.0" },
                @{ Template = "base/security"; Version = "~1.5.0"; Required = $false }
            )
            
            $result = New-VersionedTemplate -TemplatePath $script:testTemplatePath `
                -Name "complex-template" `
                -Dependencies $deps
            
            $metadata = Get-Content (Join-Path $script:testTemplatePath "template.yaml") | ConvertFrom-Json
            
            $metadata.dependencies.Count | Should -Be 2
            $metadata.dependencies[0].template | Should -Be "base/network"
            $metadata.dependencies[0].version | Should -Be ">=2.0.0"
            $metadata.dependencies[1].required | Should -Be $false
        }
    }
    
    Context "File Generation" {
        It "Should create valid Terraform files" {
            New-VersionedTemplate -TemplatePath $script:testTemplatePath -Name "test"
            
            $mainTf = Join-Path $script:testTemplatePath "versions" "1.0.0" "main.tf"
            $variablesTf = Join-Path $script:testTemplatePath "versions" "1.0.0" "variables.tf"
            $outputsTf = Join-Path $script:testTemplatePath "versions" "1.0.0" "outputs.tf"
            
            Test-Path $mainTf | Should -Be $true
            Test-Path $variablesTf | Should -Be $true
            Test-Path $outputsTf | Should -Be $true
            
            # Check content
            $mainContent = Get-Content $mainTf -Raw
            $mainContent | Should -Match "required_version"
            $mainContent | Should -Match "hyperv"
        }
    }
}

Describe "Get-TemplateVersion Tests" {
    BeforeEach {
        $script:testTemplatePath = Join-Path $TestDrive "versioned-template"
        
        # Create test template with multiple versions
        New-VersionedTemplate -TemplatePath $script:testTemplatePath -Name "test" -Version "1.0.0"
        
        # Manually create additional versions
        $versions = @("1.1.0", "1.2.0", "2.0.0")
        foreach ($v in $versions) {
            $vPath = Join-Path $script:testTemplatePath "versions" $v
            New-Item -Path $vPath -ItemType Directory -Force | Out-Null
            
            @{
                version = $v
                released = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                changelog = @("Version $v changes")
                compatibility = @{
                    breaking_changes = $v.StartsWith("2")
                }
            } | ConvertTo-Json | Set-Content -Path (Join-Path $vPath "version.json")
        }
        
        # Update current version
        $metadata = Get-Content (Join-Path $script:testTemplatePath "template.yaml") | ConvertFrom-Json
        $metadata.versioning.current = "2.0.0"
        $metadata.versioning.versions = @("1.0.0", "1.1.0", "1.2.0", "2.0.0")
        $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:testTemplatePath "template.yaml")
    }
    
    Context "Version Retrieval" {
        It "Should get all versions" {
            $result = Get-TemplateVersion -TemplatePath $script:testTemplatePath
            
            $result.IsVersioned | Should -Be $true
            $result.CurrentVersion | Should -Be "2.0.0"
            $result.Versions.Count | Should -Be 4
            $result.LatestVersion | Should -Be "2.0.0"
        }
        
        It "Should get specific version" {
            $result = Get-TemplateVersion -TemplatePath $script:testTemplatePath -Version "1.1.0"
            
            $result.Versions.Count | Should -Be 1
            $result.Versions[0].Version | Should -Be "1.1.0"
        }
        
        It "Should get latest version only" {
            $result = Get-TemplateVersion -TemplatePath $script:testTemplatePath -Latest
            
            $result.Versions.Count | Should -Be 1
            $result.Versions[0].Version | Should -Be "2.0.0"
        }
        
        It "Should detect update availability" {
            # Change current version to older
            $metadata = Get-Content (Join-Path $script:testTemplatePath "template.yaml") | ConvertFrom-Json
            $metadata.versioning.current = "1.0.0"
            $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:testTemplatePath "template.yaml")
            
            $result = Get-TemplateVersion -TemplatePath $script:testTemplatePath
            
            $result.UpdateAvailable | Should -Be $true
            $result.UpdateVersion | Should -Be "2.0.0"
        }
    }
    
    Context "Non-versioned Templates" {
        It "Should handle non-versioned templates" {
            $nonVersionedPath = Join-Path $TestDrive "non-versioned"
            New-Item -Path $nonVersionedPath -ItemType Directory -Force | Out-Null
            
            @{ metadata = @{ name = "test" } } | ConvertTo-Json | 
                Set-Content -Path (Join-Path $nonVersionedPath "template.json")
            
            $result = Get-TemplateVersion -TemplatePath $nonVersionedPath
            
            $result.IsVersioned | Should -Be $false
            $result.CurrentVersion | Should -Be "unversioned"
        }
    }
}

Describe "Update-TemplateVersion Tests" {
    BeforeEach {
        $script:testTemplatePath = Join-Path $TestDrive "update-template"
        New-VersionedTemplate -TemplatePath $script:testTemplatePath -Name "test" -Version "1.0.0"
    }
    
    Context "Version Updates" {
        It "Should bump patch version" {
            $result = Update-TemplateVersion -TemplatePath $script:testTemplatePath `
                -VersionBump "Patch" `
                -Changes "Bug fixes"
            
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be "1.0.1"
            
            Test-Path (Join-Path $script:testTemplatePath "versions" "1.0.1") | Should -Be $true
        }
        
        It "Should bump minor version" {
            $result = Update-TemplateVersion -TemplatePath $script:testTemplatePath `
                -VersionBump "Minor" `
                -Changes "New features"
            
            $result.NewVersion | Should -Be "1.1.0"
        }
        
        It "Should bump major version with breaking changes" {
            $result = Update-TemplateVersion -TemplatePath $script:testTemplatePath `
                -VersionBump "Major" `
                -Changes "Breaking API changes" `
                -BreakingChanges
            
            $result.NewVersion | Should -Be "2.0.0"
            $result.BreakingChanges | Should -Be $true
        }
        
        It "Should create changelog" {
            Update-TemplateVersion -TemplatePath $script:testTemplatePath `
                -NewVersion "1.2.0" `
                -Changes @("Feature 1", "Feature 2")
            
            $changelogPath = Join-Path $script:testTemplatePath "CHANGELOG.md"
            Test-Path $changelogPath | Should -Be $true
            
            $changelog = Get-Content $changelogPath -Raw
            $changelog | Should -Match "Feature 1"
            $changelog | Should -Match "Feature 2"
            $changelog | Should -Match "\[1\.2\.0\]"
        }
        
        It "Should reject lower version numbers" {
            { Update-TemplateVersion -TemplatePath $script:testTemplatePath -NewVersion "0.9.0" } |
                Should -Throw "*must be higher*"
        }
    }
    
    Context "File Management" {
        It "Should copy files from previous version" {
            # Add custom file to version 1.0.0
            $v1Path = Join-Path $script:testTemplatePath "versions" "1.0.0"
            "resource test {}" | Set-Content -Path (Join-Path $v1Path "custom.tf")
            
            Update-TemplateVersion -TemplatePath $script:testTemplatePath -NewVersion "1.1.0"
            
            $v11Path = Join-Path $script:testTemplatePath "versions" "1.1.0"
            Test-Path (Join-Path $v11Path "custom.tf") | Should -Be $true
        }
        
        It "Should update root level files" {
            Update-TemplateVersion -TemplatePath $script:testTemplatePath -NewVersion "1.1.0"
            
            # Root files should exist and match new version
            Test-Path (Join-Path $script:testTemplatePath "main.tf") | Should -Be $true
            Test-Path (Join-Path $script:testTemplatePath "variables.tf") | Should -Be $true
            Test-Path (Join-Path $script:testTemplatePath "outputs.tf") | Should -Be $true
        }
    }
}

Describe "Test-TemplateDependencies Tests" {
    BeforeEach {
        # Mock Get-TemplateMetadata
        Mock Get-TemplateMetadata {
            return @{
                name = "test-template"
                version = "1.0.0"
                dependencies = @(
                    @{ template = "base/network"; version = ">=2.0.0"; required = $true },
                    @{ template = "base/security"; version = "~1.5.0"; required = $false }
                )
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Dependency Validation" {
        It "Should pass with no dependencies" {
            Mock Get-TemplateMetadata {
                return @{ name = "simple"; version = "1.0.0"; dependencies = @() }
            } -ModuleName OpenTofuProvider
            
            $result = Test-TemplateDependencies -Template "simple"
            
            $result.Success | Should -Be $true
            $result.Dependencies.Count | Should -Be 0
        }
        
        It "Should check required dependencies" {
            $result = Test-TemplateDependencies -Template "test"
            
            $result.Dependencies.Count | Should -Be 1
            $result.Dependencies[0].Template | Should -Be "base/network"
        }
        
        It "Should include optional dependencies when requested" {
            $result = Test-TemplateDependencies -Template "test" -IncludeOptional
            
            $result.Dependencies.Count | Should -Be 2
        }
    }
    
    Context "Version Constraint Testing" {
        It "Should validate >= constraints" {
            # Internal function test through mock
            Mock Test-SingleDependency {
                return @{
                    Template = "base/network"
                    Found = $true
                    Compatible = $true
                    MatchedVersion = "2.1.0"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Test-TemplateDependencies -Template "test"
            $result.Success | Should -Be $true
        }
        
        It "Should detect version conflicts" {
            Mock Test-SingleDependency {
                return @{
                    Template = "base/network"
                    Found = $true
                    Compatible = $false
                    Reason = "No compatible version found"
                    AvailableVersions = @("1.0.0", "1.5.0")
                }
            } -ModuleName OpenTofuProvider
            
            $result = Test-TemplateDependencies -Template "test"
            
            $result.Success | Should -Be $false
            $result.Conflicts.Count | Should -Be 1
        }
    }
}