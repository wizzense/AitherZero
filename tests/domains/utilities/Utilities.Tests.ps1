# Utilities Domain Tests - Comprehensive Coverage
# Tests for Utilities domain functions (SemanticVersioning, LicenseManager, RepoSync, PSScriptAnalyzer, UnifiedMaintenance)
# Total Expected Functions: 17

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    $script:DomainsPath = Join-Path $ProjectRoot "aither-core/domains"
    $script:TestDataPath = Join-Path $PSScriptRoot "test-data"
    
    # Import logging module first
    $LoggingModulePath = Join-Path $ProjectRoot "aither-core/modules/Logging/Logging.psm1"
    if (Test-Path $LoggingModulePath) {
        Import-Module $LoggingModulePath -Force
    }
    
    # Import test helpers
    $TestHelpersPath = Join-Path $ProjectRoot "tests/TestHelpers.psm1"
    if (Test-Path $TestHelpersPath) {
        Import-Module $TestHelpersPath -Force
    }
    
    # Import utilities domain
    $UtilitiesDomainPath = Join-Path $DomainsPath "utilities/Utilities.ps1"
    if (Test-Path $UtilitiesDomainPath) {
        . $UtilitiesDomainPath
    }
    
    # Create test data directory
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
    
    # Test data
    $script:TestVersion = "1.2.3"
    $script:TestCommits = @(
        "feat: add new feature",
        "fix: resolve bug",
        "docs: update documentation"
    )
}

Describe "Utilities Domain - Semantic Versioning Functions" {
    Context "Semantic Version Management" {
        It "Get-NextSemanticVersion should calculate next version" {
            Mock Write-CustomLog { }
            Mock Get-CommitRange { return $TestCommits }
            Mock ConvertFrom-ConventionalCommits { return @{ Major = 0; Minor = 1; Patch = 1 } }
            Mock Parse-SemanticVersion { return @{ Major = 1; Minor = 2; Patch = 3 } }
            
            $result = Get-NextSemanticVersion -CurrentVersion $TestVersion
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "ConvertFrom-ConventionalCommits should parse conventional commits" {
            Mock Write-CustomLog { }
            
            $result = ConvertFrom-ConventionalCommits -Commits $TestCommits
            $result | Should -Not -BeNullOrEmpty
            $result.Major | Should -BeOfType [int]
            $result.Minor | Should -BeOfType [int]
            $result.Patch | Should -BeOfType [int]
        }
        
        It "Test-SemanticVersion should validate semantic version" {
            Mock Write-CustomLog { }
            
            $result = Test-SemanticVersion -Version $TestVersion
            $result | Should -Be $true
            
            $result = Test-SemanticVersion -Version "invalid"
            $result | Should -Be $false
        }
        
        It "Compare-SemanticVersions should compare versions" {
            Mock Write-CustomLog { }
            Mock Parse-SemanticVersion { 
                param($Version)
                if ($Version -eq "1.2.3") { return @{ Major = 1; Minor = 2; Patch = 3 } }
                if ($Version -eq "1.2.4") { return @{ Major = 1; Minor = 2; Patch = 4 } }
            }
            
            $result = Compare-SemanticVersions -Version1 "1.2.3" -Version2 "1.2.4"
            $result | Should -Be -1
        }
        
        It "Parse-SemanticVersion should parse version string" {
            Mock Write-CustomLog { }
            
            $result = Parse-SemanticVersion -Version $TestVersion
            $result | Should -Not -BeNullOrEmpty
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Patch | Should -Be 3
        }
        
        It "Get-CurrentVersion should return current version" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return $TestVersion }
            
            $result = Get-CurrentVersion
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-CommitRange should return commit range" {
            Mock Write-CustomLog { }
            Mock git { return ($TestCommits -join "`n") }
            
            $result = Get-CommitRange -FromTag "v1.0.0" -ToTag "v1.1.0"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Calculate-NextVersion should calculate next version" {
            Mock Write-CustomLog { }
            Mock Get-CurrentVersion { return $TestVersion }
            Mock Get-CommitRange { return $TestCommits }
            Mock ConvertFrom-ConventionalCommits { return @{ Major = 0; Minor = 1; Patch = 1 } }
            
            $result = Calculate-NextVersion -FromTag "v1.0.0"
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Utilities Domain - License Management Functions" {
    Context "License Management" {
        It "Get-LicenseStatus should return license status" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"LicenseKey": "test-key", "Status": "Active"}' }
            
            $result = Get-LicenseStatus
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Test-FeatureAccess should test feature access" {
            Mock Write-CustomLog { }
            Mock Get-LicenseStatus { return @{ Status = "Active"; Features = @("AdvancedReporting") } }
            
            $result = Test-FeatureAccess -FeatureName "AdvancedReporting"
            $result | Should -BeOfType [bool]
        }
        
        It "Get-AvailableFeatures should return available features" {
            Mock Write-CustomLog { }
            Mock Get-LicenseStatus { return @{ Features = @("AdvancedReporting", "MultiUser") } }
            
            $result = Get-AvailableFeatures
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Utilities Domain - Analysis Functions" {
    Context "Analysis Status" {
        It "Get-AnalysisStatus should return analysis status" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"LastAnalysis": "2023-01-01", "Issues": 5}' }
            
            $result = Get-AnalysisStatus
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Utilities Domain - Repository Sync Functions" {
    Context "Repository Synchronization" {
        It "Sync-ToAitherLab should sync to AitherLab" {
            Mock Write-CustomLog { }
            Mock git { return "sync complete" }
            Mock Test-Path { return $true }
            
            { Sync-ToAitherLab -Branch "main" } | Should -Not -Throw
        }
        
        It "Get-RepoSyncStatus should return sync status" {
            Mock Write-CustomLog { }
            Mock git { return "On branch main" }
            
            $result = Get-RepoSyncStatus
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Utilities Domain - Maintenance Functions" {
    Context "Unified Maintenance" {
        It "Invoke-UnifiedMaintenance should perform maintenance" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-ChildItem { return @() }
            Mock Remove-Item { }
            
            { Invoke-UnifiedMaintenance -MaintenanceType "Cleanup" } | Should -Not -Throw
        }
        
        It "Get-UtilityServiceStatus should return utility service status" {
            Mock Write-CustomLog { }
            Mock Get-Service { return @{ Name = "TestService"; Status = "Running" } }
            
            $result = Get-UtilityServiceStatus
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Test-UtilityIntegration should test utility integration" {
            Mock Write-CustomLog { }
            Mock Get-UtilityServiceStatus { return @{ Status = "Running" } }
            Mock Test-Path { return $true }
            
            $result = Test-UtilityIntegration
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $TestDataPath) {
        Remove-Item -Path $TestDataPath -Recurse -Force
    }
}