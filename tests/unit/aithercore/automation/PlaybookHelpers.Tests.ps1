#Requires -Modules Pester

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "aithercore/automation/PlaybookHelpers.psm1"
    
    # Import the module
    Import-Module $script:ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module PlaybookHelpers -Force -ErrorAction SilentlyContinue
}

Describe "PlaybookHelpers Module" -Tag 'Unit', 'PlaybookHelpers' {
    
    Context "Module Loading" {
        It "Should export New-PlaybookTemplate function" {
            Get-Command New-PlaybookTemplate -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-PlaybookDefinition function" {
            Get-Command Test-PlaybookDefinition -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-PlaybookScriptInfo function" {
            Get-Command Get-PlaybookScriptInfo -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export ConvertTo-NormalizedParameter function" {
            Get-Command ConvertTo-NormalizedParameter -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "New-PlaybookTemplate" {
        BeforeEach {
            $script:TempPath = Join-Path ([System.IO.Path]::GetTempPath()) "test-playbook-$(Get-Random).psd1"
        }
        
        AfterEach {
            if (Test-Path $script:TempPath) {
                Remove-Item $script:TempPath -Force
            }
        }
        
        It "Should create a simple template" {
            $result = New-PlaybookTemplate -Name 'test-simple' -Scripts @('0407') -Type Simple -OutputPath $script:TempPath -WhatIf:$false
            
            Test-Path $script:TempPath | Should -Be $true
            $content = Get-Content $script:TempPath -Raw
            $content | Should -Match "Name = 'test-simple'"
            $content | Should -Match "Script = '0407'"
        }
        
        It "Should create a testing template with correct variables" {
            $result = New-PlaybookTemplate -Name 'test-testing' -Scripts @('0407') -Type Testing -OutputPath $script:TempPath -WhatIf:$false
            
            $content = Get-Content $script:TempPath -Raw
            $content | Should -Match "TestMode = "
            $content | Should -Match "FailFast = "
        }
        
        It "Should create a CI template with CI variables" {
            $result = New-PlaybookTemplate -Name 'test-ci' -Scripts @('0407') -Type CI -OutputPath $script:TempPath -WhatIf:$false
            
            $content = Get-Content $script:TempPath -Raw
            $content | Should -Match "CI = "
            $content | Should -Match "AITHERZERO_CI = "
        }
        
        It "Should create a deployment template" {
            $result = New-PlaybookTemplate -Name 'test-deploy' -Scripts @('0407') -Type Deployment -OutputPath $script:TempPath -WhatIf:$false
            
            $content = Get-Content $script:TempPath -Raw
            $content | Should -Match "Environment = "
            $content | Should -Match "DryRun = "
        }
        
        It "Should handle multiple scripts" {
            $result = New-PlaybookTemplate -Name 'test-multi' -Scripts @('0407', '0413') -Type Simple -OutputPath $script:TempPath -WhatIf:$false
            
            $content = Get-Content $script:TempPath -Raw
            $content | Should -Match "Script = '0407'"
            $content | Should -Match "Script = '0413'"
        }
        
        It "Should validate playbook name pattern" {
            { New-PlaybookTemplate -Name 'Invalid Name!' -Scripts @('0407') -Type Simple -OutputPath $script:TempPath } | Should -Throw
        }
        
        It "Should validate script number pattern" {
            { New-PlaybookTemplate -Name 'test' -Scripts @('407') -Type Simple -OutputPath $script:TempPath } | Should -Throw
        }
    }
    
    Context "Test-PlaybookDefinition" {
        BeforeEach {
            $script:TempPlaybook = Join-Path ([System.IO.Path]::GetTempPath()) "test-validate-$(Get-Random).psd1"
        }
        
        AfterEach {
            if (Test-Path $script:TempPlaybook) {
                Remove-Item $script:TempPlaybook -Force
            }
        }
        
        It "Should validate a correct playbook" {
            # Create a valid playbook
            $validPlaybook = @"
@{
    Name = 'test-valid'
    Description = 'Test playbook'
    Version = '1.0.0'
    Sequence = @(
        @{
            Script = '0407'
            Description = 'Test script'
            Parameters = @{}
            Timeout = 60
        }
    )
}
"@
            $validPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.IsValid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }
        
        It "Should detect missing Name property" {
            $invalidPlaybook = @"
@{
    Sequence = @(
        @{ Script = '0407' }
    )
}
"@
            $invalidPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Missing required property: 'Name'"
        }
        
        It "Should detect missing Sequence property" {
            $invalidPlaybook = @"
@{
    Name = 'test'
}
"@
            $invalidPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Missing required property: 'Sequence'"
        }
        
        It "Should detect empty Sequence" {
            $invalidPlaybook = @"
@{
    Name = 'test'
    Sequence = @()
}
"@
            $invalidPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Sequence is empty - at least one script required"
        }
        
        It "Should detect missing Script property in sequence item" {
            $invalidPlaybook = @"
@{
    Name = 'test'
    Sequence = @(
        @{
            Description = 'No script'
            Parameters = @{}
        }
    )
}
"@
            $invalidPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match "Script #1.*Missing 'Script' property"
        }
        
        It "Should detect invalid timeout values" {
            $invalidPlaybook = @"
@{
    Name = 'test'
    Sequence = @(
        @{
            Script = '0407'
            Timeout = -30
        }
    )
}
"@
            $invalidPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match "Timeout must be positive"
        }
        
        It "Should warn about very high timeout values" {
            $invalidPlaybook = @"
@{
    Name = 'test'
    Sequence = @(
        @{
            Script = '0407'
            Timeout = 10000
        }
    )
}
"@
            $invalidPlaybook | Set-Content -Path $script:TempPlaybook
            
            $result = Test-PlaybookDefinition -Path $script:TempPlaybook
            $result.Warnings | Should -Match "Timeout is very high"
        }
        
        It "Should handle playbook data hashtable directly" {
            $playbookData = @{
                Name = 'test-direct'
                Sequence = @(
                    @{
                        Script = '0407'
                        Parameters = @{}
                    }
                )
            }
            
            $result = Test-PlaybookDefinition -PlaybookData $playbookData
            $result.IsValid | Should -Be $true
        }
    }
    
    Context "Get-PlaybookScriptInfo" {
        It "Should display info for existing playbook" {
            $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
            $playbookPath = Join-Path $projectRoot "library/playbooks/test-orchestration.psd1"
            
            if (Test-Path $playbookPath) {
                { Get-PlaybookScriptInfo -Path $playbookPath } | Should -Not -Throw
            }
        }
        
        It "Should handle non-existent playbook gracefully" {
            { Get-PlaybookScriptInfo -PlaybookName 'non-existent-playbook-xyz' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
    
    Context "ConvertTo-NormalizedParameter" {
        It "Should convert string 'true' to switch parameter" {
            $result = ConvertTo-NormalizedParameter -Value 'true' -ParameterType ([System.Management.Automation.SwitchParameter])
            $result | Should -Be $true
        }
        
        It "Should convert string 'false' to switch parameter" {
            $result = ConvertTo-NormalizedParameter -Value 'false' -ParameterType ([System.Management.Automation.SwitchParameter])
            $result | Should -Be $false
        }
        
        It "Should convert integer 1 to switch parameter" {
            $result = ConvertTo-NormalizedParameter -Value 1 -ParameterType ([System.Management.Automation.SwitchParameter])
            $result | Should -Be $true
        }
        
        It "Should convert integer 0 to switch parameter" {
            $result = ConvertTo-NormalizedParameter -Value 0 -ParameterType ([System.Management.Automation.SwitchParameter])
            $result | Should -Be $false
        }
        
        It "Should convert string to boolean" {
            $result = ConvertTo-NormalizedParameter -Value 'true' -ParameterType ([bool])
            $result | Should -Be $true
        }
        
        It "Should convert string to integer" {
            $result = ConvertTo-NormalizedParameter -Value '300' -ParameterType ([int])
            $result | Should -Be 300
        }
        
        It "Should convert value to string" {
            $result = ConvertTo-NormalizedParameter -Value 42 -ParameterType ([string])
            $result | Should -Be '42'
        }
        
        It "Should handle PowerShell boolean strings" {
            $result = ConvertTo-NormalizedParameter -Value '$true' -ParameterType ([bool])
            $result | Should -Be $true
        }
    }
    
    Context "Pipeline Support" {
        It "Should support pipeline input for playbook validation" {
            $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
            $playbooksPath = Join-Path $projectRoot "library/playbooks"
            
            if (Test-Path $playbooksPath) {
                $playbookFiles = Get-ChildItem -Path $playbooksPath -Filter "*.psd1" -File | Select-Object -First 1
                
                if ($playbookFiles) {
                    { $playbookFiles | ForEach-Object { Test-PlaybookDefinition -Path $_.FullName } } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Error Handling" {
        It "Should handle corrupted playbook files gracefully" {
            $tempCorrupt = Join-Path ([System.IO.Path]::GetTempPath()) "corrupt-$(Get-Random).psd1"
            "This is not valid PowerShell @{" | Set-Content -Path $tempCorrupt
            
            try {
                $result = Test-PlaybookDefinition -Path $tempCorrupt
                $result.IsValid | Should -Be $false
                $result.Errors.Count | Should -BeGreaterThan 0
            }
            finally {
                Remove-Item $tempCorrupt -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
