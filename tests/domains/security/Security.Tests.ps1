# Security Domain Tests - Comprehensive Coverage
# Tests for Security domain functions
# Total Expected Functions: 42

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
    
    # Import security domain
    $SecurityDomainPath = Join-Path $DomainsPath "security/Security.ps1"
    if (Test-Path $SecurityDomainPath) {
        . $SecurityDomainPath
    }
    
    # Create test data directory
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
    
    # Test credentials and data
    $script:TestCredentialStore = Join-Path $TestDataPath "credentials.json"
    $script:TestUsername = "TestUser"
    $script:TestPassword = "TestPassword123!"
    $script:TestSecureString = ConvertTo-SecureString $TestPassword -AsPlainText -Force
    $script:TestCredential = New-Object System.Management.Automation.PSCredential($TestUsername, $TestSecureString)
}

Describe "Security Domain - Secure Credential Store Functions" {
    Context "Credential Store Initialization" {
        It "Initialize-SecureCredentialStore should create credential store" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $false }
            Mock New-Item { }
            Mock Set-Content { }
            
            { Initialize-SecureCredentialStore -StorePath $TestCredentialStore } | Should -Not -Throw
        }
    }
    
    Context "Credential Management" {
        It "New-SecureCredential should create new credential" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{}' }
            Mock Set-Content { }
            
            { New-SecureCredential -Name "TestCred" -Username $TestUsername -Password $TestPassword } | Should -Not -Throw
        }
        
        It "Get-SecureCredential should retrieve credential" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestCred": {"Username": "TestUser", "Password": "encrypted"}}' }
            Mock ConvertTo-SecureString { return $TestSecureString }
            
            $result = Get-SecureCredential -Name "TestCred"
            $result | Should -Not -BeNullOrEmpty
            $result.Username | Should -Be $TestUsername
        }
        
        It "Get-AllSecureCredentials should retrieve all credentials" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestCred1": {}, "TestCred2": {}}' }
            
            $result = Get-AllSecureCredentials
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
        
        It "Update-SecureCredential should update existing credential" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestCred": {"Username": "TestUser", "Password": "encrypted"}}' }
            Mock Set-Content { }
            
            { Update-SecureCredential -Name "TestCred" -Username $TestUsername -Password $TestPassword } | Should -Not -Throw
        }
        
        It "Remove-SecureCredential should remove credential" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestCred": {"Username": "TestUser", "Password": "encrypted"}}' }
            Mock Set-Content { }
            
            { Remove-SecureCredential -Name "TestCred" } | Should -Not -Throw
        }
    }
    
    Context "Credential Store Operations" {
        It "Backup-SecureCredentialStore should backup credential store" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Copy-Item { }
            
            { Backup-SecureCredentialStore } | Should -Not -Throw
        }
        
        It "Test-SecureCredentialCompliance should test compliance" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestCred": {"Username": "TestUser", "Password": "encrypted"}}' }
            
            $result = Test-SecureCredentialCompliance
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Export-SecureCredential should export credential" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestCred": {"Username": "TestUser", "Password": "encrypted"}}' }
            Mock Set-Content { }
            
            { Export-SecureCredential -Name "TestCred" -ExportPath "exported.json" } | Should -Not -Throw
        }
        
        It "Import-SecureCredential should import credential" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"Username": "TestUser", "Password": "encrypted"}' }
            Mock Set-Content { }
            
            { Import-SecureCredential -Name "TestCred" -ImportPath "imported.json" } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Active Directory Security Functions" {
    Context "AD Security Assessment" {
        It "Get-ADSecurityAssessment should assess AD security" {
            Mock Write-CustomLog { }
            Mock Get-ADDomain { return @{ DomainMode = "Windows2016Domain" } }
            Mock Get-ADUser { return @(@{ Name = "TestUser"; Enabled = $true }) }
            Mock Get-ADComputer { return @(@{ Name = "TestComputer"; Enabled = $true }) }
            
            $result = Get-ADSecurityAssessment -DomainName "test.local"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-ADPasswordPolicy should set password policy" {
            Mock Write-CustomLog { }
            Mock Set-ADDefaultDomainPasswordPolicy { }
            
            { Set-ADPasswordPolicy -Domain "test.local" -MinPasswordLength 12 -ComplexityEnabled $true } | Should -Not -Throw
        }
        
        It "Get-ADDelegationRisks should identify delegation risks" {
            Mock Write-CustomLog { }
            Mock Get-ADUser { return @(@{ Name = "TestUser"; TrustedForDelegation = $true }) }
            Mock Get-ADComputer { return @(@{ Name = "TestComputer"; TrustedForDelegation = $true }) }
            
            $result = Get-ADDelegationRisks -Domain "test.local"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Enable-ADSmartCardLogon should enable smart card logon" {
            Mock Write-CustomLog { }
            Mock Set-ADUser { }
            
            { Enable-ADSmartCardLogon -Username "TestUser" -Domain "test.local" } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Certificate Management Functions" {
    Context "Certificate Authority Functions" {
        It "Install-EnterpriseCA should install enterprise CA" {
            Mock Write-CustomLog { }
            Mock Install-WindowsFeature { return @{ Success = $true } }
            Mock Install-ADCSCertificationAuthority { }
            
            { Install-EnterpriseCA -CAName "TestCA" -CAType "EnterpriseRootCA" } | Should -Not -Throw
        }
        
        It "New-CertificateTemplate should create certificate template" {
            Mock Write-CustomLog { }
            Mock New-CATemplate { }
            Mock Set-CATemplate { }
            
            { New-CertificateTemplate -TemplateName "TestTemplate" -Purpose "ServerAuthentication" } | Should -Not -Throw
        }
        
        It "Enable-CertificateAutoEnrollment should enable auto-enrollment" {
            Mock Write-CustomLog { }
            Mock Set-GPRegistryValue { }
            
            { Enable-CertificateAutoEnrollment -TemplateName "TestTemplate" } | Should -Not -Throw
        }
        
        It "Invoke-CertificateLifecycleManagement should manage certificate lifecycle" {
            Mock Write-CustomLog { }
            Mock Get-Certificate { return @(@{ Subject = "CN=TestCert"; NotAfter = (Get-Date).AddDays(30) }) }
            Mock Request-Certificate { }
            
            { Invoke-CertificateLifecycleManagement } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Windows Security Hardening Functions" {
    Context "Security Hardening" {
        It "Enable-CredentialGuard should enable credential guard" {
            Mock Write-CustomLog { }
            Mock Get-CimInstance { return @{ Name = "Microsoft Windows" } }
            Mock Set-ItemProperty { }
            
            { Enable-CredentialGuard -Force } | Should -Not -Throw
        }
        
        It "Enable-AdvancedAuditPolicy should enable advanced audit policy" {
            Mock Write-CustomLog { }
            Mock auditpol { return "Success" }
            
            { Enable-AdvancedAuditPolicy -AuditLevel "Enhanced" } | Should -Not -Throw
        }
        
        It "Set-AppLockerPolicy should set AppLocker policy" {
            Mock Write-CustomLog { }
            Mock New-AppLockerPolicy { return @{ Rules = @() } }
            Mock Set-AppLockerPolicy { }
            
            { Set-AppLockerPolicy -PolicyLevel "Enforced" -RuleCollections @("Exe", "Dll") } | Should -Not -Throw
        }
        
        It "Set-WindowsFirewallProfile should configure firewall profile" {
            Mock Write-CustomLog { }
            Mock Set-NetFirewallProfile { }
            
            { Set-WindowsFirewallProfile -Profile "Domain" -Enabled $true -DefaultInboundAction "Block" } | Should -Not -Throw
        }
        
        It "Enable-ExploitProtection should enable exploit protection" {
            Mock Write-CustomLog { }
            Mock Set-ProcessMitigation { }
            
            { Enable-ExploitProtection -ProcessName "notepad.exe" -Mitigations @("DEP", "ASLR") } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Network Security Functions" {
    Context "Network Security Configuration" {
        It "Set-IPsecPolicy should set IPsec policy" {
            Mock Write-CustomLog { }
            Mock New-NetIPsecPolicy { return @{ Name = "TestPolicy" } }
            Mock New-NetIPsecRule { }
            
            { Set-IPsecPolicy -PolicyName "TestPolicy" -SourceAddress "192.168.1.0/24" -DestinationAddress "192.168.2.0/24" } | Should -Not -Throw
        }
        
        It "Set-SMBSecurity should configure SMB security" {
            Mock Write-CustomLog { }
            Mock Set-SmbServerConfiguration { }
            Mock Set-SmbClientConfiguration { }
            
            { Set-SMBSecurity -RequireSecuritySignature $true -EnableEncryption $true } | Should -Not -Throw
        }
        
        It "Disable-WeakProtocols should disable weak protocols" {
            Mock Write-CustomLog { }
            Mock Set-ItemProperty { }
            Mock Disable-WindowsOptionalFeature { }
            
            { Disable-WeakProtocols -Protocols @("SSLv2", "SSLv3", "TLS1.0") } | Should -Not -Throw
        }
        
        It "Enable-DNSSECValidation should enable DNSSEC validation" {
            Mock Write-CustomLog { }
            Mock Set-DnsServerSetting { }
            
            { Enable-DNSSECValidation -ZoneName "test.local" } | Should -Not -Throw
        }
        
        It "Set-DNSSinkhole should configure DNS sinkhole" {
            Mock Write-CustomLog { }
            Mock Add-DnsServerResourceRecord { }
            
            { Set-DNSSinkhole -MaliciousDomain "malicious.com" -SinkholeIP "192.168.1.100" } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Remote Access Security Functions" {
    Context "Remote Access Security" {
        It "Set-WinRMSecurity should configure WinRM security" {
            Mock Write-CustomLog { }
            Mock Set-WSManInstance { }
            Mock Set-Item { }
            
            { Set-WinRMSecurity -RequireSSL $true -AllowedHosts @("trusted.com") } | Should -Not -Throw
        }
        
        It "Enable-PowerShellRemotingSSL should enable PowerShell remoting with SSL" {
            Mock Write-CustomLog { }
            Mock New-WSManInstance { }
            Mock Set-Item { }
            
            { Enable-PowerShellRemotingSSL -CertificateThumbprint "ABC123" } | Should -Not -Throw
        }
        
        It "New-JEASessionConfiguration should create JEA session configuration" {
            Mock Write-CustomLog { }
            Mock New-PSSessionConfigurationFile { }
            Mock Register-PSSessionConfiguration { }
            
            { New-JEASessionConfiguration -ConfigurationName "TestJEA" -AllowedCommands @("Get-Process") } | Should -Not -Throw
        }
        
        It "New-JEAEndpoint should create JEA endpoint" {
            Mock Write-CustomLog { }
            Mock New-PSRoleCapabilityFile { }
            Mock New-PSSessionConfigurationFile { }
            
            { New-JEAEndpoint -EndpointName "TestEndpoint" -AllowedUsers @("TestUser") } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Privileged Access Management Functions" {
    Context "Privileged Access Management" {
        It "Enable-JustInTimeAccess should enable JIT access" {
            Mock Write-CustomLog { }
            Mock New-ScheduledTask { }
            Mock Register-ScheduledTask { }
            
            { Enable-JustInTimeAccess -Username "TestUser" -AccessDuration 2 -Resources @("Server1") } | Should -Not -Throw
        }
        
        It "Get-PrivilegedAccountActivity should get privileged account activity" {
            Mock Write-CustomLog { }
            Mock Get-WinEvent { return @(@{ TimeCreated = (Get-Date); Id = 4624; Message = "Successful logon" }) }
            
            $result = Get-PrivilegedAccountActivity -Username "TestUser" -Days 7
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-PrivilegedAccountPolicy should set privileged account policy" {
            Mock Write-CustomLog { }
            Mock Set-ADUser { }
            Mock Set-ADGroup { }
            
            { Set-PrivilegedAccountPolicy -AccountName "TestAdmin" -MaxLogonAge 30 -RequireMFA $true } | Should -Not -Throw
        }
    }
}

Describe "Security Domain - Security Monitoring Functions" {
    Context "Security Monitoring and Assessment" {
        It "Get-SystemSecurityInventory should get security inventory" {
            Mock Write-CustomLog { }
            Mock Get-Service { return @(@{ Name = "TestService"; Status = "Running" }) }
            Mock Get-HotFix { return @(@{ HotFixID = "KB123456"; InstalledOn = (Get-Date) }) }
            Mock Get-NetFirewallProfile { return @(@{ Name = "Domain"; Enabled = $true }) }
            
            $result = Get-SystemSecurityInventory
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-InsecureServices should identify insecure services" {
            Mock Write-CustomLog { }
            Mock Get-Service { return @(@{ Name = "TestService"; Status = "Running" }) }
            Mock Get-CimInstance { return @(@{ Name = "TestService"; StartMode = "Manual" }) }
            
            $result = Get-InsecureServices
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-SystemHardening should apply system hardening" {
            Mock Write-CustomLog { }
            Mock Set-ItemProperty { }
            Mock Set-Service { }
            
            { Set-SystemHardening -Level "Enhanced" -ApplyImmediately $true } | Should -Not -Throw
        }
        
        It "Set-WindowsFeatureSecurity should configure Windows feature security" {
            Mock Write-CustomLog { }
            Mock Disable-WindowsOptionalFeature { }
            Mock Enable-WindowsOptionalFeature { }
            
            { Set-WindowsFeatureSecurity -DisableFeatures @("TelnetClient") -EnableFeatures @("Windows-Defender") } | Should -Not -Throw
        }
        
        It "Search-SecurityEvents should search security events" {
            Mock Write-CustomLog { }
            Mock Get-WinEvent { return @(@{ TimeCreated = (Get-Date); Id = 4624; Message = "Successful logon" }) }
            
            $result = Search-SecurityEvents -EventIDs @(4624, 4625) -Hours 24
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Test-SecurityConfiguration should test security configuration" {
            Mock Write-CustomLog { }
            Mock Get-NetFirewallProfile { return @(@{ Name = "Domain"; Enabled = $true }) }
            Mock Get-Service { return @(@{ Name = "TestService"; Status = "Running" }) }
            
            $result = Test-SecurityConfiguration
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-SecuritySummary should get security summary" {
            Mock Write-CustomLog { }
            Mock Get-SystemSecurityInventory { return @{ Services = @(); Updates = @(); Firewall = @() } }
            Mock Get-InsecureServices { return @() }
            Mock Test-SecurityConfiguration { return @{ Score = 85 } }
            
            $result = Get-SecuritySummary
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $TestDataPath) {
        Remove-Item -Path $TestDataPath -Recurse -Force
    }
}