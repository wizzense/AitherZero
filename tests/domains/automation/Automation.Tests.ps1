# Automation Domain Tests - Comprehensive Coverage
# Tests for Automation domain functions (ScriptManager)
# Total Expected Functions: 15

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
    
    # Import automation domain
    $AutomationDomainPath = Join-Path $DomainsPath "automation/Automation.ps1"
    if (Test-Path $AutomationDomainPath) {
        . $AutomationDomainPath
    }
    
    # Create test data directory
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
    
    # Test script data
    $script:TestScriptPath = Join-Path $TestDataPath "test-script.ps1"
    $script:TestScriptContent = @"
# Test Script
param([string]`$TestParam = "default")
Write-Host "Test script executed with parameter: `$TestParam"
return "Success"
"@
    
    $script:TestScriptRepository = Join-Path $TestDataPath "script-repository"
    $script:TestScriptRegistry = Join-Path $TestDataPath "script-registry.json"
}

Describe "Automation Domain - Script Repository Functions" {
    Context "Script Repository Management" {
        It "Initialize-ScriptRepository should initialize script repository" {
            Mock Write-CustomLog { }
            Mock New-Item { }
            Mock Test-Path { return $false }
            
            { Initialize-ScriptRepository -RepositoryPath $TestScriptRepository } | Should -Not -Throw
        }
        
        It "Initialize-ScriptTemplates should initialize script templates" {
            Mock Write-CustomLog { }
            Mock New-Item { }
            Mock Set-Content { }
            Mock Test-Path { return $false }
            
            { Initialize-ScriptTemplates -TemplatesPath (Join-Path $TestDataPath "templates") } | Should -Not -Throw
        }
        
        It "Get-ScriptRepository should return repository information" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-ChildItem { return @(@{ Name = "script1.ps1"; FullName = "path/script1.ps1" }) }
            
            $result = Get-ScriptRepository -RepositoryPath $TestScriptRepository
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Backup-ScriptRepository should backup repository" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Copy-Item { }
            Mock Compress-Archive { }
            
            { Backup-ScriptRepository -RepositoryPath $TestScriptRepository -BackupPath (Join-Path $TestDataPath "backup") } | Should -Not -Throw
        }
    }
}

Describe "Automation Domain - Script Registration Functions" {
    Context "Script Registration Management" {
        It "Register-OneOffScript should register script" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return $TestScriptContent }
            Mock Set-Content { }
            
            Set-Content -Path $TestScriptPath -Value $TestScriptContent
            
            { Register-OneOffScript -ScriptPath $TestScriptPath -Name "TestScript" -Description "Test script" } | Should -Not -Throw
        }
        
        It "Get-RegisteredScripts should return registered scripts" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestScript": {"Name": "TestScript", "Description": "Test script"}}' }
            
            $result = Get-RegisteredScripts
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Remove-ScriptFromRegistry should remove script from registry" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestScript": {"Name": "TestScript"}}' }
            Mock Set-Content { }
            
            { Remove-ScriptFromRegistry -ScriptName "TestScript" } | Should -Not -Throw
        }
        
        It "Get-ScriptExecutionHistory should return execution history" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"TestScript": [{"ExecutionTime": "2023-01-01T00:00:00", "Result": "Success"}]}' }
            
            $result = Get-ScriptExecutionHistory -ScriptName "TestScript"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-ScriptMetrics should return script metrics" {
            Mock Write-CustomLog { }
            Mock Get-RegisteredScripts { return @{ TestScript = @{} } }
            Mock Get-ScriptExecutionHistory { return @(@{ Result = "Success" }) }
            
            $result = Get-ScriptMetrics
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Automation Domain - Script Validation Functions" {
    Context "Script Validation" {
        It "Test-ModernScript should validate modern script syntax" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return $TestScriptContent }
            
            Set-Content -Path $TestScriptPath -Value $TestScriptContent
            
            $result = Test-ModernScript -ScriptPath $TestScriptPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
        
        It "Test-OneOffScript should validate one-off script" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return $TestScriptContent }
            Mock Test-ModernScript { return $true }
            
            $result = Test-OneOffScript -ScriptPath $TestScriptPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
    }
}

Describe "Automation Domain - Script Execution Functions" {
    Context "Script Execution Management" {
        It "Invoke-OneOffScript should execute script" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-RegisteredScripts { return @{ TestScript = @{ ScriptPath = $TestScriptPath } } }
            Mock Start-Job { return @{ Id = 1; Name = "TestJob" } }
            Mock Receive-Job { return "Success" }
            Mock Get-Job { return @{ State = "Completed" } }
            
            $result = Invoke-OneOffScript -ScriptName "TestScript" -Parameters @{ TestParam = "test" }
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Start-ScriptExecution should start script execution" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return $TestScriptContent }
            Mock Start-Job { return @{ Id = 1; Name = "TestJob" } }
            
            $result = Start-ScriptExecution -ScriptPath $TestScriptPath -Parameters @{ TestParam = "test" }
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Automation Domain - Script Template Functions" {
    Context "Script Template Management" {
        It "Get-ScriptTemplate should return script template" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return "# Template Script`nWrite-Host 'Template'" }
            
            $result = Get-ScriptTemplate -TemplateName "basic"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "New-ScriptFromTemplate should create script from template" {
            Mock Write-CustomLog { }
            Mock Get-ScriptTemplate { return "# Template Script`nWrite-Host 'Template'" }
            Mock Set-Content { }
            Mock Test-Path { return $true }
            
            { New-ScriptFromTemplate -TemplateName "basic" -ScriptName "NewScript" -OutputPath $TestScriptPath } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $TestDataPath) {
        Remove-Item -Path $TestDataPath -Recurse -Force
    }
}