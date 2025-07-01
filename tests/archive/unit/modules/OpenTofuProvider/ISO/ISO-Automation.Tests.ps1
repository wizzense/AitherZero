BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Mock environment
    $env:PROJECT_ROOT = $TestDrive
    
    # Test data
    $script:testConfig = @{
        version = "1.0"
        iso_requirements = @(
            @{
                name = "WindowsServer2025"
                type = "WindowsServer2025"
                customization = "standard"
                cache = $true
            },
            @{
                name = "WindowsServer2022"
                type = "WindowsServer2022" 
                cache = $true
            }
        )
    }
    
    # Create test ISO repository
    $script:testISORepo = Join-Path $TestDrive "iso-repository"
    New-Item -Path $script:testISORepo -ItemType Directory -Force | Out-Null
}

Describe "Initialize-DeploymentISOs Tests" {
    Context "Configuration Loading" {
        It "Should load deployment configuration from file" {
            $configPath = Join-Path $TestDrive "deploy.json"
            $script:testConfig | ConvertTo-Json | Set-Content -Path $configPath
            
            $result = Initialize-DeploymentISOs -DeploymentConfig $configPath
            
            $result.Success | Should -Be $true
            $result.Requirements.Count | Should -Be 2
            $result.ConfigPath | Should -Be $configPath
        }
        
        It "Should accept configuration object directly" {
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig
            
            $result.Success | Should -Be $true
            $result.Requirements.Count | Should -Be 2
            $result.ConfigPath | Should -Be "Object"
        }
        
        It "Should handle missing configuration file" {
            { Initialize-DeploymentISOs -DeploymentConfig "non-existent.json" } |
                Should -Throw "*not found*"
        }
        
        It "Should handle configuration without ISO requirements" {
            $configNoISO = @{ version = "1.0"; template = "test" }
            
            $result = Initialize-DeploymentISOs -DeploymentConfig $configNoISO
            
            $result.Success | Should -Be $true
            $result.Requirements.Count | Should -Be 0
        }
    }
    
    Context "ISO Repository Management" {
        It "Should create ISO repository if missing" {
            $customRepo = Join-Path $TestDrive "custom-iso-repo"
            
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig -ISORepository $customRepo
            
            Test-Path $customRepo | Should -Be $true
            $result.ISORepository | Should -Be $customRepo
        }
        
        It "Should use default repository if not specified" {
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig
            
            $result.ISORepository | Should -Match "iso-repository"
        }
    }
    
    Context "ISO Detection" {
        It "Should detect existing ISOs" {
            # Create test ISO file
            $isoPath = Join-Path $script:testISORepo "WindowsServer2025_x64_standard.iso"
            "test" | Set-Content -Path $isoPath
            $stream = [System.IO.File]::OpenWrite($isoPath)
            $stream.SetLength(200MB)
            $stream.Close()
            
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig -ISORepository $script:testISORepo
            
            $result.ExistingISOs.Count | Should -BeGreaterThan 0
            $result.ExistingISOs[0].Name | Should -Be "WindowsServer2025"
            $result.ExistingISOs[0].Exists | Should -Be $true
        }
        
        It "Should identify missing ISOs" {
            # Clean repository
            Remove-Item -Path "$script:testISORepo\*" -Force -ErrorAction SilentlyContinue
            
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig -ISORepository $script:testISORepo
            
            $result.MissingISOs.Count | Should -Be 2
            $result.TotalSizeRequired | Should -BeGreaterThan 0
        }
        
        It "Should skip existing check when requested" {
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig -SkipExistingCheck
            
            $result.ExistingISOs.Count | Should -Be 0
            $result.MissingISOs.Count | Should -Be 0
        }
    }
    
    Context "Update Detection" {
        It "Should check for updates when requested" {
            Mock Check-ISOUpdate {
                return @{
                    UpdateAvailable = $true
                    LatestVersion = "26100.2000"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Initialize-DeploymentISOs -DeploymentConfig $script:testConfig -UpdateCheck
            
            $result.UpdatesAvailable.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Test-ISORequirements Tests" {
    BeforeEach {
        # Create test requirements object
        $script:testRequirements = [PSCustomObject]@{
            Requirements = @(
                @{
                    Name = "WindowsServer2025"
                    Type = "WindowsServer2025"
                    Exists = $true
                    Path = Join-Path $script:testISORepo "WindowsServer2025.iso"
                    Customization = "standard"
                },
                @{
                    Name = "WindowsServer2022"
                    Type = "WindowsServer2022"
                    Exists = $false
                    Path = Join-Path $script:testISORepo "WindowsServer2022.iso"
                }
            )
        }
        
        # Create test ISO
        $testISO = $script:testRequirements.Requirements[0].Path
        "test" | Set-Content -Path $testISO
        $stream = [System.IO.File]::OpenWrite($testISO)
        $stream.SetLength(200MB)
        $stream.Close()
    }
    
    Context "Basic Validation" {
        It "Should validate existing ISOs" {
            $result = Test-ISORequirements -Requirements $script:testRequirements
            
            $result.TotalRequirements | Should -Be 2
            $result.Validated | Should -Be 1
            $result.Failed | Should -Be 1
            $result.ReadyForDeployment | Should -Be $false
        }
        
        It "Should handle empty requirements" {
            $emptyReq = [PSCustomObject]@{ Requirements = @() }
            
            $result = Test-ISORequirements -Requirements $emptyReq
            
            $result.ReadyForDeployment | Should -Be $true
            $result.TotalRequirements | Should -Be 0
        }
        
        It "Should fail on non-ISO files" {
            $nonISO = Join-Path $script:testISORepo "notaniso.txt"
            "test" | Set-Content -Path $nonISO
            
            $req = [PSCustomObject]@{
                Requirements = @(
                    @{
                        Name = "Test"
                        Exists = $true
                        Path = $nonISO
                    }
                )
            }
            
            $result = Test-ISORequirements -Requirements $req
            
            $result.Failed | Should -Be 1
            $result.Details[0].Errors | Should -Contain "File is not an ISO: .txt"
        }
    }
    
    Context "Integrity Validation" {
        It "Should perform integrity check when requested" {
            # Create checksum file
            $hash = Get-FileHash -Path $script:testRequirements.Requirements[0].Path -Algorithm SHA256
            "$($hash.Hash)  WindowsServer2025.iso" | Set-Content -Path "$($script:testRequirements.Requirements[0].Path).sha256"
            
            $result = Test-ISORequirements -Requirements $script:testRequirements -ValidateIntegrity
            
            $result.Details[0].IntegrityValid | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Customization Validation" {
        It "Should check customization when requested" {
            $result = Test-ISORequirements -Requirements $script:testRequirements -ValidateCustomization
            
            $result.Details[0].CustomizationValid | Should -Not -BeNullOrEmpty
        }
        
        It "Should detect customization from filename" {
            $customISO = Join-Path $script:testISORepo "WindowsServer2025_standard.iso"
            "test" | Set-Content -Path $customISO
            $stream = [System.IO.File]::OpenWrite($customISO)
            $stream.SetLength(200MB)
            $stream.Close()
            
            $req = [PSCustomObject]@{
                Requirements = @(
                    @{
                        Name = "Test"
                        Exists = $true
                        Path = $customISO
                        Customization = "standard"
                    }
                )
            }
            
            Mock Test-SingleISOCustomization {
                return @{ Valid = $true; CanBeCustomized = $true }
            } -ModuleName OpenTofuProvider
            
            $result = Test-ISORequirements -Requirements $req -ValidateCustomization
            
            $result.Details[0].CustomizationValid | Should -Be $true
        }
    }
    
    Context "Fail Fast Mode" {
        It "Should stop on first failure with FailFast" {
            $multiReq = [PSCustomObject]@{
                Requirements = @(
                    @{ Name = "ISO1"; Exists = $false; Path = "missing1.iso" },
                    @{ Name = "ISO2"; Exists = $false; Path = "missing2.iso" },
                    @{ Name = "ISO3"; Exists = $false; Path = "missing3.iso" }
                )
            }
            
            $result = Test-ISORequirements -Requirements $multiReq -FailFast
            
            $result.Details.Count | Should -Be 1
            $result.Failed | Should -Be 1
        }
    }
}

Describe "Update-DeploymentISOs Tests" {
    BeforeEach {
        $script:updateRequirements = [PSCustomObject]@{
            ISORepository = $script:testISORepo
            MissingISOs = @(
                @{
                    Name = "WindowsServer2025"
                    Type = "WindowsServer2025"
                    EstimatedSize = 5GB
                }
            )
            UpdatesAvailable = @()
            Requirements = @()
        }
    }
    
    Context "Download Operations" {
        It "Should download missing ISOs" {
            Mock Download-ISO {
                return @{
                    Success = $true
                    Path = Join-Path $script:testISORepo "WindowsServer2025.iso"
                    BytesTransferred = 5GB
                }
            } -ModuleName OpenTofuProvider
            
            $result = Update-DeploymentISOs -ISORequirements $script:updateRequirements -AutoApprove
            
            $result.Downloaded | Should -Be 1
            $result.TotalBytesDownloaded | Should -Be 5GB
            $result.Success | Should -Be $true
        }
        
        It "Should handle download failures" {
            Mock Download-ISO {
                return @{
                    Success = $false
                    Error = "Network error"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Update-DeploymentISOs -ISORequirements $script:updateRequirements -AutoApprove
            
            $result.Failed | Should -Be 1
            $result.Success | Should -Be $false
            $result.Errors.Count | Should -Be 1
        }
        
        It "Should respect WhatIf" {
            Mock Download-ISO {} -ModuleName OpenTofuProvider
            
            $result = Update-DeploymentISOs -ISORequirements $script:updateRequirements -AutoApprove -WhatIf
            
            Should -Not -Invoke Download-ISO -ModuleName OpenTofuProvider
        }
    }
    
    Context "Update Operations" {
        It "Should update ISOs when available" {
            $script:updateRequirements.UpdatesAvailable = @(
                @{
                    Name = "WindowsServer2022"
                    CurrentVersion = "20348.1"
                    AvailableVersion = "20348.2"
                }
            )
            $script:updateRequirements.MissingISOs = @()
            
            Mock Update-SingleISO {
                return @{
                    Success = $true
                    Path = "updated.iso"
                    BytesTransferred = 5GB
                }
            } -ModuleName OpenTofuProvider
            
            $result = Update-DeploymentISOs -ISORequirements $script:updateRequirements -AutoApprove
            
            $result.Updated | Should -Be 1
        }
    }
    
    Context "Customization Operations" {
        It "Should customize ISOs when profile specified" {
            $script:updateRequirements.Requirements = @(
                @{
                    Name = "Test"
                    Exists = $true
                    Path = Join-Path $script:testISORepo "test.iso"
                    Customization = $null
                }
            )
            $script:updateRequirements.MissingISOs = @()
            
            Mock Customize-ISO {
                return @{
                    Success = $true
                    Path = "customized.iso"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Update-DeploymentISOs -ISORequirements $script:updateRequirements -CustomizationProfile "lab" -AutoApprove
            
            $result.Customized | Should -Be 1
        }
    }
}

Describe "Get-ISOConfiguration Tests" {
    BeforeEach {
        # Create test ISOs
        @("WindowsServer2025_x64.iso", "WindowsServer2022_x64_custom.iso", "Ubuntu-22.04.iso") | ForEach-Object {
            $path = Join-Path $script:testISORepo $_
            "test" | Set-Content -Path $path
            $stream = [System.IO.File]::OpenWrite($path)
            $stream.SetLength(1GB)
            $stream.Close()
        }
    }
    
    Context "Repository Scanning" {
        It "Should find all ISOs in repository" {
            $configs = Get-ISOConfiguration -Repository $script:testISORepo
            
            ($configs | Where-Object { $_.Type -ne "Summary" }).Count | Should -Be 3
        }
        
        It "Should filter by name with wildcards" {
            $configs = Get-ISOConfiguration -Name "Windows*" -Repository $script:testISORepo
            
            ($configs | Where-Object { $_.Type -ne "Summary" }).Count | Should -Be 2
        }
        
        It "Should detect customization from filename" {
            $configs = Get-ISOConfiguration -Repository $script:testISORepo
            
            $customized = $configs | Where-Object { $_.Name -like "*2022*" }
            $customized.IsCustomized | Should -Be $true
            $customized.CustomizationProfile | Should -Be "custom"
        }
    }
    
    Context "Deployment Configuration Integration" {
        It "Should get ISOs from deployment config" {
            $configPath = Join-Path $TestDrive "deploy.json"
            $script:testConfig | ConvertTo-Json | Set-Content -Path $configPath
            
            Mock Initialize-DeploymentISOs {
                return [PSCustomObject]@{
                    Requirements = @(
                        @{
                            Name = "WindowsServer2025"
                            Type = "WindowsServer2025"
                            Path = Join-Path $script:testISORepo "WindowsServer2025_x64.iso"
                            Exists = $true
                        }
                    )
                }
            } -ModuleName OpenTofuProvider
            
            $configs = Get-ISOConfiguration -DeploymentConfig $configPath
            
            $configs.Count | Should -BeGreaterThan 0
            $configs[0].Name | Should -Be "WindowsServer2025"
        }
    }
    
    Context "Metadata and Updates" {
        It "Should include metadata when requested" {
            Mock Get-ISOMetadata {
                return @{
                    Version = "26100.1"
                    Architecture = "x64"
                }
            } -ModuleName OpenTofuProvider
            
            $configs = Get-ISOConfiguration -Repository $script:testISORepo -IncludeMetadata
            
            $iso = $configs | Where-Object { $_.Name -like "*2025*" }
            $iso.Metadata | Should -Not -BeNullOrEmpty
        }
        
        It "Should check for updates when requested" {
            Mock Check-ISOUpdate {
                return @{
                    UpdateAvailable = $true
                    LatestVersion = "26100.2000"
                }
            } -ModuleName OpenTofuProvider
            
            $configs = Get-ISOConfiguration -Repository $script:testISORepo -CheckUpdates
            
            $updates = $configs | Where-Object { $_.UpdateAvailable -eq $true }
            $updates.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Summary Generation" {
        It "Should include summary for multiple ISOs" {
            $configs = Get-ISOConfiguration -Repository $script:testISORepo
            
            $summary = $configs | Where-Object { $_.Name -eq "=== SUMMARY ===" }
            $summary | Should -Not -BeNullOrEmpty
            $summary.Summary.TotalISOs | Should -Be 3
            $summary.Summary.TotalSizeGB | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    # Restore environment
    $env:PROJECT_ROOT = $projectRoot
}