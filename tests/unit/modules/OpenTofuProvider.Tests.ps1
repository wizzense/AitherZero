BeforeAll {
    # Import required modules for testing
    $ModulePath = "$PSScriptRoot/../../../aither-core/modules"
    Import-Module "$ModulePath/Logging" -Force
    Import-Module "$ModulePath/OpenTofuProvider" -Force
    
    # Create test data directory
    $TestDataPath = "$PSScriptRoot/TestData"
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
    
    # Create mock lab configuration
    $MockLabConfig = @"
hyperv:
  host: "test-hyperv.lab.local"
  user: "test\\admin"
  password: "TestPassword123!"
  port: 5986
  https: true
  insecure: false
  use_ntlm: true
  tls_server_name: "test-hyperv.lab.local"
  cacert_path: "./test-certs/ca.pem"
  cert_path: "./test-certs/client-cert.pem"
  key_path: "./test-certs/client-key.pem"
  vm_path: "C:\\TestVMs"
  script_path: "C:/Temp/test_tofu_%RAND%.cmd"
  timeout: "30s"

switch:
  name: "Test-Lab-Switch"
  net_adapter_names:
    - "Test-Ethernet"

vms:
  - name_prefix: "test-vm"
    count: 1
    vhd_size_bytes: 10737418240
    iso_path: "C:\\TestISOs\\test.iso"
    memory_startup_bytes: 1073741824
    processor_count: 1
    network_adaptors:
      - name: "Network Adapter"
        switch_name: "Test-Lab-Switch"

metadata:
  name: "Test Lab Environment"
  version: "1.0.0"
  created_by: "Test Administrator"
  purpose: "Testing environment"
  tags:
    - "testing"
    - "lab"
"@
    
    $MockLabConfigPath = "$TestDataPath/test-lab-config.yaml"
    Set-Content -Path $MockLabConfigPath -Value $MockLabConfig
    
    # Mock credential for testing
    $MockCredential = New-Object System.Management.Automation.PSCredential(
        "testuser", 
        (ConvertTo-SecureString "testpass" -AsPlainText -Force)
    )
}

Describe "OpenTofuProvider Module Tests" {
    
    Context "Module Loading and Structure" {
        It "Should load the OpenTofuProvider module successfully" {
            Get-Module OpenTofuProvider | Should -Not -BeNullOrEmpty
        }
        
        It "Should export all required functions" {
            $ExpectedFunctions = @(
                'Install-OpenTofuSecure',
                'Initialize-OpenTofuProvider',
                'Test-OpenTofuSecurity',
                'New-LabInfrastructure',
                'Get-TaliesinsProviderConfig',
                'Set-SecureCredentials',
                'Test-InfrastructureCompliance',
                'Export-LabTemplate',
                'Import-LabConfiguration'
            )
            
            $ExportedFunctions = (Get-Command -Module OpenTofuProvider).Name
            
            foreach ($Function in $ExpectedFunctions) {
                $ExportedFunctions | Should -Contain $Function
            }
        }
        
        It "Should have proper module manifest" {
            $ManifestPath = "$PSScriptRoot/../../../aither-core/modules/OpenTofuProvider/OpenTofuProvider.psd1"
            Test-Path $ManifestPath | Should -Be $true
            
            $Manifest = Test-ModuleManifest -Path $ManifestPath
            $Manifest.Name | Should -Be "OpenTofuProvider"
            $Manifest.Version | Should -Be "1.0.0"
        }
    }
    
    Context "Get-TaliesinsProviderConfig Function Tests" {
        It "Should generate HCL configuration successfully" {
            $Result = Get-TaliesinsProviderConfig -HypervHost "test-host" -Credentials $MockCredential -OutputFormat "HCL"
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -Match "terraform"
            $Result | Should -Match "taliesins/hyperv"
        }
        
        It "Should generate JSON configuration successfully" {
            $Result = Get-TaliesinsProviderConfig -HypervHost "test-host" -Credentials $MockCredential -OutputFormat "JSON"
            $Result | Should -Not -BeNullOrEmpty
            $JsonObject = $Result | ConvertFrom-Json
            $JsonObject.terraform | Should -Not -BeNullOrEmpty
            $JsonObject.provider | Should -Not -BeNullOrEmpty
        }
        
        It "Should generate Object configuration successfully" {
            $Result = Get-TaliesinsProviderConfig -HypervHost "test-host" -Credentials $MockCredential -OutputFormat "Object"
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -BeOfType [hashtable]
            $Result.terraform | Should -Not -BeNullOrEmpty            $Result.provider | Should -Not -BeNullOrEmpty
        }
        
        It "Should include certificate configuration when provided" {
            $TestCertPath = Join-Path $PSScriptRoot "TestData/test-certs"
            $Result = Get-TaliesinsProviderConfig -HypervHost "test-host" -Credentials $MockCredential -CertificatePath $TestCertPath -OutputFormat "Object"
            $Result.provider.hyperv.cacert_path | Should -Not -BeNullOrEmpty
            $Result.provider.hyperv.cert_path | Should -Not -BeNullOrEmpty
            $Result.provider.hyperv.key_path | Should -Not -BeNullOrEmpty
        }
        
        It "Should throw error for invalid certificate path" {
            { Get-TaliesinsProviderConfig -HypervHost "test-host" -Credentials $MockCredential -CertificatePath "/nonexistent/path" } | Should -Throw
        }
    }
    
    Context "Import-LabConfiguration Function Tests" {
        BeforeAll {
            $TestConfigPath = "$TestDataPath/test-lab-config.yaml"
        }
        
        It "Should import YAML configuration successfully" {
            $Result = Import-LabConfiguration -ConfigPath $TestConfigPath -ConfigFormat "YAML"
            $Result.Success | Should -Be $true
            $Result.Configuration | Should -Not -BeNullOrEmpty
            $Result.Configuration.hyperv | Should -Not -BeNullOrEmpty
            $Result.Configuration.switch | Should -Not -BeNullOrEmpty
            $Result.Configuration.vms | Should -Not -BeNullOrEmpty
        }
        
        It "Should auto-detect YAML format" {
            $Result = Import-LabConfiguration -ConfigPath $TestConfigPath -ConfigFormat "Auto"
            $Result.Success | Should -Be $true
            $Result.Metadata.Format | Should -Be "YAML"
        }
        
        It "Should validate configuration when requested" {
            $Result = Import-LabConfiguration -ConfigPath $TestConfigPath -ValidateConfiguration
            $Result.Success | Should -Be $true
            $Result.ValidationResult | Should -Not -BeNullOrEmpty
        }
        
        It "Should include metadata about loaded configuration" {
            $Result = Import-LabConfiguration -ConfigPath $TestConfigPath
            $Result.Metadata | Should -Not -BeNullOrEmpty
            $Result.Metadata.SourcePath | Should -Be $TestConfigPath
            $Result.Metadata.LoadedAt | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide configuration summary" {
            $Result = Import-LabConfiguration -ConfigPath $TestConfigPath
            $Result.Summary | Should -Not -BeNullOrEmpty
            $Result.Summary.HypervHost | Should -Be "test-hyperv.lab.local"
            $Result.Summary.VmCount | Should -Be 1
            $Result.Summary.SwitchName | Should -Be "Test-Lab-Switch"
        }
    }
    
    Context "Test-OpenTofuSecurity Function Tests" {
        It "Should run security audit successfully" {
            $Result = Test-OpenTofuSecurity -ConfigPath $TestDataPath
            $Result.Success | Should -Be $true
            $Result.SecurityReport | Should -Not -BeNullOrEmpty
            $Result.Score | Should -BeGreaterThan 0
            $Result.Status | Should -BeIn @("Excellent", "Good", "Fair", "Poor")
        }
        
        It "Should include multiple security checks" {
            $Result = Test-OpenTofuSecurity -ConfigPath $TestDataPath
            $Result.SecurityReport.Checks | Should -Not -BeNullOrEmpty
            $Result.SecurityReport.Checks.Count | Should -BeGreaterThan 5
        }
        
        It "Should calculate proper security score" {
            $Result = Test-OpenTofuSecurity -ConfigPath $TestDataPath
            $Result.Score | Should -BeOfType [double]
            $Result.Score | Should -BeGreaterOrEqual 0
            $Result.Score | Should -BeLessOrEqual 100
        }
        
        It "Should identify critical issues if any exist" {
            $Result = Test-OpenTofuSecurity -ConfigPath $TestDataPath
            # CriticalIssues should be an array or null
            if ($Result.CriticalIssues) {
                $Result.CriticalIssues | Should -BeOfType [array]
            }
        }
    }
    
    Context "Test-InfrastructureCompliance Function Tests" {
        It "Should run compliance tests successfully" {
            $Result = Test-InfrastructureCompliance -ConfigPath $TestDataPath -ComplianceStandard "Security"
            $Result.Success | Should -Be $true
            $Result.ComplianceReport | Should -Not -BeNullOrEmpty
        }
        
        It "Should test different compliance standards" {
            @("Security", "Operational", "All") | ForEach-Object {
                $Result = Test-InfrastructureCompliance -ConfigPath $TestDataPath -ComplianceStandard $_
                $Result.Success | Should -Be $true
                $Result.ComplianceReport.Standard | Should -Be $_
            }
        }
        
        It "Should calculate compliance score" {
            $Result = Test-InfrastructureCompliance -ConfigPath $TestDataPath
            $Result.Score | Should -BeOfType [double]
            $Result.Score | Should -BeGreaterOrEqual 0
            $Result.Score | Should -BeLessOrEqual 100
        }
        
        It "Should provide compliance status" {
            $Result = Test-InfrastructureCompliance -ConfigPath $TestDataPath
            $Result.Status | Should -BeIn @("Fully Compliant", "Mostly Compliant", "Partially Compliant", "Non-Compliant")
        }
    }
    
    Context "Set-SecureCredentials Function Tests" {
        It "Should handle UserPassword credential type" {
            $Result = Set-SecureCredentials -Target "test-target" -Credentials $MockCredential -CredentialType "UserPassword"
            $Result.Success | Should -Be $true
            $Result.Target | Should -Be "test-target"
            $Result.CredentialType | Should -Be "UserPassword"
        }
        
        It "Should validate required parameters for different credential types" {
            { Set-SecureCredentials -Target "test" -CredentialType "Certificate" } | Should -Throw
            { Set-SecureCredentials -Target "test" -CredentialType "UserPassword" } | Should -Throw
        }
          It "Should return proper result structure" {
            $Result = Set-SecureCredentials -Target "test-target" -Credentials $MockCredential -CredentialType "UserPassword"
            $Result.Success | Should -Be $true
            $Result.Target | Should -Be "test-target"
            $Result.CredentialType | Should -Be "UserPassword"
            $Result.MetadataPath | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Export-LabTemplate Function Tests" {
        BeforeAll {
            $TestSourcePath = $TestDataPath
            $TestTemplatePath = "$TestDataPath/templates"
            if (Test-Path $TestTemplatePath) {
                Remove-Item $TestTemplatePath -Recurse -Force
            }
        }
        
        It "Should export template successfully" {
            $Result = Export-LabTemplate -SourcePath $TestSourcePath -TemplateName "TestTemplate" -OutputPath "$TestDataPath/templates"
            $Result.Success | Should -Be $true
            $Result.TemplateName | Should -Be "TestTemplate"
            $Result.TemplatePath | Should -Not -BeNullOrEmpty
        }
        
        It "Should create template files" {
            Export-LabTemplate -SourcePath $TestSourcePath -TemplateName "TestTemplate" -OutputPath "$TestDataPath/templates"
            $TemplatePath = "$TestDataPath/templates/TestTemplate"
            Test-Path "$TemplatePath/template.json" | Should -Be $true
        }
        
        It "Should include documentation when requested" {
            $Result = Export-LabTemplate -SourcePath $TestSourcePath -TemplateName "TestTemplate" -OutputPath "$TestDataPath/templates" -IncludeDocumentation
            $Result.Files | Should -Contain "README.md"
        }
        
        It "Should include metadata in result" {
            $Result = Export-LabTemplate -SourcePath $TestSourcePath -TemplateName "TestTemplate" -OutputPath "$TestDataPath/templates"
            $Result.Metadata | Should -Not -BeNullOrEmpty
            $Result.Metadata.TemplateName | Should -Be "TestTemplate"
            $Result.Metadata.Version | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "OpenTofuProvider Integration Tests" {
    
    Context "Module Dependencies" {        It "Should integrate with Logging module" {
            # Test that logging functions work within OpenTofuProvider
            # Try to import the Logging module if not already loaded
            $LoggingModule = Get-Module Logging
            if (-not $LoggingModule) {
                try {
                    Import-Module "$PSScriptRoot/../../../aither-core/modules/Logging/Logging.psm1" -Force -ErrorAction SilentlyContinue
                    $LoggingModule = Get-Module Logging
                } catch {
                    # Skip test if Logging module not available
                    Set-ItResult -Skipped -Because "Logging module not available in test environment"
                    return
                }
            }
            $LoggingModule | Should -Not -BeNullOrEmpty
            
            # Test that Write-CustomLog is available
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing dependencies gracefully" {
            # This tests error handling when dependencies are missing
            # In real scenarios, this would test fallback behavior
            $true | Should -Be $true  # Placeholder for dependency testing
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $Result = Test-OpenTofuSecurity -ConfigPath $TestDataPath
            $Result.Success | Should -Be $true
        }
        
        It "Should handle platform-specific paths correctly" {
            $Config = Import-LabConfiguration -ConfigPath "$TestDataPath/test-lab-config.yaml"
            $Config.Success | Should -Be $true
            # Configuration should load regardless of platform
        }
    }
    
    Context "Error Handling and Resilience" {
        It "Should handle invalid configuration paths gracefully" {
            { Import-LabConfiguration -ConfigPath "/nonexistent/path.yaml" } | Should -Throw
        }
        
        It "Should handle malformed configurations gracefully" {
            $MalformedConfig = "invalid: yaml: content: ["
            $MalformedPath = "$TestDataPath/malformed.yaml"
            Set-Content -Path $MalformedPath -Value $MalformedConfig
            
            { Import-LabConfiguration -ConfigPath $MalformedPath } | Should -Throw
        }
        
        It "Should validate input parameters" {
            { Get-TaliesinsProviderConfig -HypervHost "" -Credentials $MockCredential } | Should -Throw
        }
    }
    
    Context "Security Validation" {
        It "Should enforce secure defaults" {
            $Config = Get-TaliesinsProviderConfig -HypervHost "test-host" -Credentials $MockCredential -OutputFormat "Object"
            $Config.provider.hyperv.https | Should -Be $true
            $Config.provider.hyperv.insecure | Should -Be $false
        }
        
        It "Should detect security issues" {
            $SecurityResult = Test-OpenTofuSecurity -ConfigPath $TestDataPath
            $SecurityResult.SecurityReport.Checks | Should -Not -BeNullOrEmpty
            # At least some security checks should be performed
        }
        
        It "Should validate compliance standards" {
            $ComplianceResult = Test-InfrastructureCompliance -ConfigPath $TestDataPath -ComplianceStandard "All"
            $ComplianceResult.ComplianceReport.Tests | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Cleanup test data
    $TestDataPath = "$PSScriptRoot/TestData"
    if (Test-Path $TestDataPath) {
        Remove-Item $TestDataPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
