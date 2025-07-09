# Infrastructure Domain Tests - Comprehensive Coverage
# Tests for LabRunner, OpenTofuProvider, SystemMonitoring, ISOManager
# Total Expected Functions: 64 (17 + 11 + 19 + 17)

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
    
    # Import domain files
    $InfrastructureDomainPath = Join-Path $DomainsPath "infrastructure"
    Get-ChildItem -Path $InfrastructureDomainPath -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
    
    # Create test data directory
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
}

Describe "Infrastructure Domain - LabRunner Functions" {
    Context "Platform Detection Functions" {
        It "Get-Platform should return valid platform" {
            $platform = Get-Platform
            $platform | Should -BeIn @('Windows', 'Linux', 'MacOS')
        }
        
        It "Get-CrossPlatformTempPath should return valid path" {
            $tempPath = Get-CrossPlatformTempPath
            $tempPath | Should -Not -BeNullOrEmpty
            if ($tempPath) {
                $parentPath = Split-Path $tempPath -Parent
                if ($parentPath) {
                    Test-Path $parentPath | Should -Be $true
                }
            }
        }
    }
    
    Context "Command Execution Functions" {
        It "Invoke-CrossPlatformCommand should execute command safely" {
            Mock Write-CustomLog { }
            
            $result = Invoke-CrossPlatformCommand -Command "echo 'test'" -Description "Test command"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Write-ProgressLog should log progress correctly" {
            Mock Write-Host { }
            
            { Write-ProgressLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
        }
    }
    
    Context "Path Resolution Functions" {
        It "Resolve-ProjectPath should handle relative paths" {
            Mock Test-Path { return $true }
            
            $resolved = Resolve-ProjectPath -Path "test-path"
            $resolved | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Lab Execution Functions" {
        It "Invoke-LabStep should execute step with proper validation" {
            Mock Write-CustomLog { }
            Mock Invoke-Expression { return "success" }
            
            $result = Invoke-LabStep -StepName "Test Step" -Command "echo 'test'"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Invoke-LabDownload should handle download operations" {
            Mock Write-CustomLog { }
            Mock Invoke-WebRequest { return @{ StatusCode = 200 } }
            
            { Invoke-LabDownload -Url "https://example.com/file.zip" -OutputPath "test.zip" } | Should -Not -Throw
        }
        
        It "Read-LoggedInput should capture user input" {
            Mock Read-Host { return "test-input" }
            Mock Write-CustomLog { }
            
            $result = Read-LoggedInput -Prompt "Enter value"
            $result | Should -Be "test-input"
        }
        
        It "Invoke-LabWebRequest should make web requests" {
            Mock Invoke-WebRequest { return @{ Content = "test-content" } }
            Mock Write-CustomLog { }
            
            $result = Invoke-LabWebRequest -Uri "https://example.com"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Invoke-LabNpm should execute npm commands" {
            Mock Invoke-CrossPlatformCommand { return "npm success" }
            
            $result = Invoke-LabNpm -Command "install"
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Lab Configuration Functions" {
        It "Get-LabConfig should return configuration" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"test": "config"}' }
            
            $config = Get-LabConfig
            $config | Should -Not -BeNullOrEmpty
        }
        
        It "Start-LabAutomation should orchestrate lab operations" {
            Mock Write-CustomLog { }
            Mock Get-LabConfig { return @{ name = "test-lab" } }
            Mock Invoke-LabStep { return "success" }
            
            { Start-LabAutomation -ConfigPath "test-config.json" } | Should -Not -Throw
        }
        
        It "Test-ParallelRunnerSupport should validate parallel capabilities" {
            Mock Write-CustomLog { }
            
            $result = Test-ParallelRunnerSupport
            $result | Should -BeOfType [bool]
        }
        
        It "Get-LabStatus should return lab status" {
            Mock Write-CustomLog { }
            Mock Get-LabConfig { return @{ name = "test-lab" } }
            
            $status = Get-LabStatus
            $status | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Enhanced Lab Deployment Functions" {
        It "Start-EnhancedLabDeployment should handle complex deployments" {
            Mock Write-CustomLog { }
            Mock Get-LabConfig { return @{ name = "test-lab" } }
            Mock Invoke-LabStep { return "success" }
            
            { Start-EnhancedLabDeployment -ConfigPath "test-config.json" } | Should -Not -Throw
        }
        
        It "Test-LabDeploymentHealth should validate deployment health" {
            Mock Write-CustomLog { }
            Mock Get-LabConfig { return @{ name = "test-lab" } }
            
            $health = Test-LabDeploymentHealth
            $health | Should -Not -BeNullOrEmpty
        }
        
        It "Write-EnhancedDeploymentSummary should generate deployment summary" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            
            { Write-EnhancedDeploymentSummary -DeploymentResult @{ Status = "Success" } } | Should -Not -Throw
        }
    }
}

Describe "Infrastructure Domain - OpenTofuProvider Functions" {
    Context "YAML Conversion Functions" {
        It "ConvertFrom-Yaml should parse YAML correctly" {
            $yamlContent = "key: value"
            
            $result = ConvertFrom-Yaml -YamlContent $yamlContent
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "ConvertTo-Yaml should convert to YAML correctly" {
            $hashtable = @{ key = "value" }
            
            $result = ConvertTo-Yaml -InputObject $hashtable
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "OpenTofu Installation Functions" {
        It "Test-OpenTofuInstallation should validate installation" {
            Mock Write-CustomLog { }
            Mock Get-Command { return @{ Name = "tofu" } }
            
            $result = Test-OpenTofuInstallation
            $result | Should -BeOfType [bool]
        }
        
        It "Install-OpenTofuSecure should install OpenTofu securely" {
            Mock Write-CustomLog { }
            Mock Invoke-CrossPlatformCommand { return "success" }
            
            { Install-OpenTofuSecure } | Should -Not -Throw
        }
    }
    
    Context "Provider Configuration Functions" {
        It "New-TaliesinsProviderConfig should create provider configuration" {
            Mock Write-CustomLog { }
            
            $config = New-TaliesinsProviderConfig -VMwareHost "test-host" -Username "test-user" -Password "test-pass"
            $config | Should -Not -BeNullOrEmpty
        }
        
        It "Test-TaliesinsProviderInstallation should validate provider installation" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            
            $result = Test-TaliesinsProviderInstallation
            $result | Should -BeOfType [bool]
        }
    }
    
    Context "OpenTofu Command Functions" {
        It "Invoke-OpenTofuCommand should execute OpenTofu commands" {
            Mock Write-CustomLog { }
            Mock Invoke-CrossPlatformCommand { return "success" }
            
            $result = Invoke-OpenTofuCommand -Command "version"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Initialize-OpenTofuProvider should initialize provider" {
            Mock Write-CustomLog { }
            Mock Invoke-OpenTofuCommand { return "success" }
            Mock Test-Path { return $true }
            
            { Initialize-OpenTofuProvider -ConfigPath "test-config" } | Should -Not -Throw
        }
    }
    
    Context "Infrastructure Deployment Functions" {
        It "Start-InfrastructureDeployment should deploy infrastructure" {
            Mock Write-CustomLog { }
            Mock Invoke-OpenTofuCommand { return "success" }
            Mock Test-Path { return $true }
            
            { Start-InfrastructureDeployment -ConfigPath "test-config" } | Should -Not -Throw
        }
        
        It "New-LabInfrastructure should create lab infrastructure" {
            Mock Write-CustomLog { }
            Mock New-TaliesinsProviderConfig { return @{ provider = "test" } }
            Mock Invoke-OpenTofuCommand { return "success" }
            
            { New-LabInfrastructure -VMwareHost "test-host" -Username "test-user" -Password "test-pass" } | Should -Not -Throw
        }
        
        It "Get-DeploymentStatus should return deployment status" {
            Mock Write-CustomLog { }
            Mock Invoke-OpenTofuCommand { return "success" }
            Mock Test-Path { return $true }
            
            $status = Get-DeploymentStatus -ConfigPath "test-config"
            $status | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Infrastructure Domain - SystemMonitoring Functions" {
    Context "System Information Functions" {
        It "Get-CpuUsageLinux should return CPU usage on Linux" {
            Mock Get-Platform { return "Linux" }
            Mock Get-Content { return "cpu 1000 2000 3000 4000" }
            
            $result = Get-CpuUsageLinux
            $result | Should -BeOfType [double]
        }
        
        It "Get-MemoryInfo should return memory information" {
            Mock Write-CustomLog { }
            Mock Get-CimInstance { return @{ TotalPhysicalMemory = 8589934592; FreePhysicalMemory = 4294967296 } }
            
            $result = Get-MemoryInfo
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-DiskInfo should return disk information" {
            Mock Write-CustomLog { }
            Mock Get-CimInstance { return @{ Size = 1000000000; FreeSpace = 500000000; DeviceID = "C:" } }
            
            $result = Get-DiskInfo
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-NetworkInfo should return network information" {
            Mock Write-CustomLog { }
            Mock Get-CimInstance { return @{ Name = "Ethernet"; InterfaceOperationalStatus = 1 } }
            
            $result = Get-NetworkInfo
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Service Monitoring Functions" {
        It "Get-CriticalServiceStatus should check critical services" {
            Mock Write-CustomLog { }
            Mock Get-Service { return @{ Name = "TestService"; Status = "Running" } }
            
            $result = Get-CriticalServiceStatus
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-ServiceStatus should return service status" {
            Mock Write-CustomLog { }
            Mock Get-Service { return @{ Name = "TestService"; Status = "Running" } }
            
            $result = Get-ServiceStatus -ServiceName "TestService"
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Alert Functions" {
        It "Get-AlertStatus should return alert status" {
            Mock Write-CustomLog { }
            
            $result = Get-AlertStatus
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-CurrentAlerts should return current alerts" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 95 } }
            
            $result = Get-CurrentAlerts
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-SystemAlerts should return system alerts" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 95 } }
            
            $result = Get-SystemAlerts
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Health and Status Functions" {
        It "Get-OverallHealthStatus should return overall health" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 50 } }
            Mock Get-DiskInfo { return @{ UsedPercent = 60 } }
            
            $result = Get-OverallHealthStatus
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-SystemUptime should return system uptime" {
            Mock Write-CustomLog { }
            Mock Get-CimInstance { return @{ LastBootUpTime = (Get-Date).AddHours(-24) } }
            
            $result = Get-SystemUptime
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Convert-SizeToGB should convert bytes to GB" {
            $result = Convert-SizeToGB -SizeInBytes 1073741824
            $result | Should -Be 1
        }
    }
    
    Context "Dashboard Functions" {
        It "Show-ConsoleDashboard should display dashboard" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 50 } }
            Mock Get-DiskInfo { return @{ UsedPercent = 60 } }
            
            { Show-ConsoleDashboard } | Should -Not -Throw
        }
        
        It "Get-SystemDashboard should return dashboard data" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 50 } }
            Mock Get-DiskInfo { return @{ UsedPercent = 60 } }
            
            $result = Get-SystemDashboard
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-SystemPerformance should return performance metrics" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 50 } }
            Mock Get-DiskInfo { return @{ UsedPercent = 60 } }
            
            $result = Get-SystemPerformance
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Monitoring Control Functions" {
        It "Start-SystemMonitoring should start monitoring" {
            Mock Write-CustomLog { }
            Mock Start-Job { return @{ Id = 1 } }
            
            { Start-SystemMonitoring } | Should -Not -Throw
        }
        
        It "Stop-SystemMonitoring should stop monitoring" {
            Mock Write-CustomLog { }
            Mock Get-Job { return @{ Id = 1 } }
            Mock Stop-Job { }
            Mock Remove-Job { }
            
            { Stop-SystemMonitoring } | Should -Not -Throw
        }
        
        It "Invoke-HealthCheck should perform health check" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 50 } }
            Mock Get-DiskInfo { return @{ UsedPercent = 60 } }
            
            $result = Invoke-HealthCheck
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-PerformanceBaseline should set performance baseline" {
            Mock Write-CustomLog { }
            Mock Get-MemoryInfo { return @{ UsedPercent = 50 } }
            Mock Get-DiskInfo { return @{ UsedPercent = 60 } }
            
            { Set-PerformanceBaseline } | Should -Not -Throw
        }
    }
}

Describe "Infrastructure Domain - ISOManager Functions" {
    Context "ISO URL Functions" {
        It "Get-WindowsISOUrl should return Windows ISO URL" {
            Mock Write-CustomLog { }
            
            $result = Get-WindowsISOUrl -Version "Windows 11"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-LinuxISOUrl should return Linux ISO URL" {
            Mock Write-CustomLog { }
            
            $result = Get-LinuxISOUrl -Distribution "Ubuntu" -Version "22.04"
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Security and Validation Functions" {
        It "Test-AdminPrivileges should check admin privileges" {
            Mock Write-CustomLog { }
            
            $result = Test-AdminPrivileges
            $result | Should -BeOfType [bool]
        }
        
        It "Test-ISOIntegrity should validate ISO integrity" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-FileHash { return @{ Hash = "ABC123" } }
            
            $result = Test-ISOIntegrity -ISOPath "test.iso" -ExpectedHash "ABC123"
            $result | Should -BeOfType [bool]
        }
    }
    
    Context "Download Functions" {
        It "Invoke-ModernHttpDownload should download files" {
            Mock Write-CustomLog { }
            Mock Invoke-WebRequest { return @{ StatusCode = 200 } }
            
            { Invoke-ModernHttpDownload -Url "https://example.com/file.iso" -OutputPath "test.iso" } | Should -Not -Throw
        }
        
        It "Invoke-BitsDownload should use BITS for download" {
            Mock Write-CustomLog { }
            Mock Start-BitsTransfer { }
            
            { Invoke-BitsDownload -Url "https://example.com/file.iso" -OutputPath "test.iso" } | Should -Not -Throw
        }
        
        It "Invoke-WebRequestDownload should use WebRequest for download" {
            Mock Write-CustomLog { }
            Mock Invoke-WebRequest { return @{ StatusCode = 200 } }
            
            { Invoke-WebRequestDownload -Url "https://example.com/file.iso" -OutputPath "test.iso" } | Should -Not -Throw
        }
    }
    
    Context "ISO Customization Functions" {
        It "Get-BootstrapTemplate should return bootstrap template" {
            Mock Write-CustomLog { }
            
            $result = Get-BootstrapTemplate -OSType "Windows"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Apply-OfflineRegistryChanges should apply registry changes" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            
            { Apply-OfflineRegistryChanges -MountPath "C:\Mount" -RegistryChanges @{} } | Should -Not -Throw
        }
        
        It "New-AutounattendFile should create autounattend file" {
            Mock Write-CustomLog { }
            Mock New-Item { }
            
            { New-AutounattendFile -OutputPath "autounattend.xml" -ProductKey "12345" } | Should -Not -Throw
        }
    }
    
    Context "ISO Management Functions" {
        It "Find-DuplicateISOs should find duplicate ISO files" {
            Mock Write-CustomLog { }
            Mock Get-ChildItem { return @(@{ Name = "test.iso"; Length = 1000 }) }
            
            $result = Find-DuplicateISOs -SearchPath "C:\ISOs"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Compress-ISOFile should compress ISO file" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Compress-Archive { }
            
            { Compress-ISOFile -ISOPath "test.iso" -OutputPath "test.zip" } | Should -Not -Throw
        }
        
        It "Get-ISODownload should download ISO file" {
            Mock Write-CustomLog { }
            Mock Invoke-ModernHttpDownload { }
            Mock Test-ISOIntegrity { return $true }
            
            { Get-ISODownload -Url "https://example.com/file.iso" -OutputPath "test.iso" } | Should -Not -Throw
        }
        
        It "Get-ISOMetadata should return ISO metadata" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Item { return @{ Name = "test.iso"; Length = 1000; CreationTime = (Get-Date) } }
            
            $result = Get-ISOMetadata -ISOPath "test.iso"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "New-CustomISO should create custom ISO" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock New-Item { }
            Mock Copy-Item { }
            
            { New-CustomISO -SourcePath "source.iso" -OutputPath "custom.iso" -CustomizationScript {} } | Should -Not -Throw
        }
        
        It "Get-ISOInventory should return ISO inventory" {
            Mock Write-CustomLog { }
            Mock Get-ChildItem { return @(@{ Name = "test.iso"; Length = 1000 }) }
            Mock Get-ISOMetadata { return @{ Name = "test.iso"; Size = 1000 } }
            
            $result = Get-ISOInventory -SearchPath "C:\ISOs"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Optimize-ISOStorage should optimize ISO storage" {
            Mock Write-CustomLog { }
            Mock Find-DuplicateISOs { return @() }
            Mock Compress-ISOFile { }
            
            { Optimize-ISOStorage -StoragePath "C:\ISOs" } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $TestDataPath) {
        Remove-Item -Path $TestDataPath -Recurse -Force
    }
}