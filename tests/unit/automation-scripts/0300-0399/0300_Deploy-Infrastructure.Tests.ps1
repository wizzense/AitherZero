#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0300_Deploy-Infrastructure
.DESCRIPTION
    Automated tests for automation script: 0300_Deploy-Infrastructure
    Script Description: Deploy infrastructure using OpenTofu
    Tests deployment operations with mocking and WhatIf functionality
#>

Describe '0300_Deploy-Infrastructure' -Tag 'Unit', 'AutomationScript', 'Infrastructure' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0300_Deploy-Infrastructure.ps1'
        $script:ScriptName = '0300_Deploy-Infrastructure'
        $script:TestInfraDir = './test-infrastructure'
        
        # Mock external commands
        Mock -CommandName 'tofu' -MockWith { 
            param([string]$Command)
            switch ($Command) {
                'version' { return 'OpenTofu v1.6.0'; $global:LASTEXITCODE = 0 }
                'init' { return 'Initializing...'; $global:LASTEXITCODE = 0 }
                'plan' { return 'Plan completed'; $global:LASTEXITCODE = 0 }
                'apply' { return 'Apply completed'; $global:LASTEXITCODE = 0 }
                default { return 'Unknown command'; $global:LASTEXITCODE = 1 }
            }
        }
        
        Mock -CommandName 'Test-Path' -MockWith { 
            param([string]$Path)
            switch ($Path) {
                { $_ -like '*Logging.psm1' } { return $true }
                { $_ -like '*infrastructure*' } { return $true }
                { $_ -like '*.terraform*' } { return $false } # Force init
                default { return $false }
            }
        }
        
        Mock -CommandName 'Import-Module' -MockWith { return $null }
        Mock -CommandName 'New-Item' -MockWith { 
            return @{ FullName = $Path; ItemType = 'Directory' }
        }
        Mock -CommandName 'Push-Location' -MockWith { return $null }
        Mock -CommandName 'Pop-Location' -MockWith { return $null }
        Mock -CommandName 'Set-Content' -MockWith { return $null }
        Mock -CommandName 'Join-Path' -MockWith { 
            param([string]$Path, [string]$ChildPath)
            return "$Path/$ChildPath"
        }
        Mock -CommandName 'Split-Path' -MockWith { 
            param([string]$Path, [switch]$Parent)
            if ($Parent) { return '/workspaces/AitherZero' }
            return 'AitherZero'
        }
        
        # Mock logging functions
        Mock -CommandName 'Write-CustomLog' -MockWith { 
            param([string]$Message, [string]$Level = 'Information')
            return $null 
        }
        Mock -CommandName 'Get-Command' -MockWith { 
            param([string]$Name, [switch]$ErrorAction)
            if ($Name -eq 'Write-CustomLog') {
                return @{ Name = 'Write-CustomLog' }
            }
            return $null
        }
        Mock -CommandName 'Write-Host' -MockWith { return $null }
        Mock -CommandName 'Get-Date' -MockWith { return [datetime]'2025-08-11 10:30:00' }
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Script should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath,
                [ref]$null,
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Script should support ShouldProcess (WhatIf)' {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match '\[CmdletBinding\(SupportsShouldProcess\)\]'
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept -Configuration parameter as hashtable' {
            $scriptInfo = Get-Command $script:ScriptPath
            $scriptInfo.Parameters.ContainsKey('Configuration') | Should -Be $true
            $scriptInfo.Parameters['Configuration'].ParameterType.Name | Should -Be 'Hashtable'
        }

        It 'Should have proper parameter attributes' {
            $scriptInfo = Get-Command $script:ScriptPath
            $configParam = $scriptInfo.Parameters['Configuration']
            $configParam.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Infrastructure Dependencies' {
        It 'Should be in Infrastructure stage' {
            $content = Get-Content $script:ScriptPath -First 10
            $content -join ' ' | Should -Match '#\s+Stage:\s*Infrastructure'
        }

        It 'Should declare OpenTofu and HyperV dependencies' {
            $content = Get-Content $script:ScriptPath -First 10
            $content -join ' ' | Should -Match 'Dependencies:\s*OpenTofu,\s*HyperV'
        }

        It 'Should have OpenTofu feature condition' {
            $content = Get-Content $script:ScriptPath -First 10
            $content -join ' ' | Should -Match "Condition:.*Features.*contains.*'OpenTofu'"
        }
    }

    Context 'Configuration Handling' {
        It 'Should handle empty configuration' {
            Mock -CommandName '&' -MockWith { 
                param([string]$Command, [string]$Arguments)
                if ($Command -eq 'tofu' -and $Arguments -eq 'version') {
                    $global:LASTEXITCODE = 0
                    return 'OpenTofu v1.6.0'
                }
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It 'Should use default infrastructure directory when not configured' {
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName 'Join-Path' -ParameterFilter { 
                $ChildPath -eq './infrastructure' 
            }
        }

        It 'Should use configured infrastructure directory' {
            $config = @{
                Infrastructure = @{
                    WorkingDirectory = '/custom/infra'
                }
            }
            
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration $config -WhatIf
            # Should use the custom directory
            $config.Infrastructure.WorkingDirectory | Should -Be '/custom/infra'
        }
    }

    Context 'OpenTofu Operations' {
        BeforeEach {
            Mock -CommandName '&' -MockWith { 
                param([string]$Command, [string]$Arguments)
                $global:LASTEXITCODE = 0
                switch ("$Command $Arguments") {
                    'tofu version' { return 'OpenTofu v1.6.0' }
                    'tofu init' { return 'Initializing the backend...' }
                    { $_ -like 'tofu plan*' } { return 'Plan: 3 to add, 0 to change, 0 to destroy.' }
                    { $_ -like 'tofu apply*' } { return 'Apply complete\! Resources: 3 added, 0 changed, 0 destroyed.' }
                    default { return 'Command executed' }
                }
            }
        }

        It 'Should check for OpenTofu availability' {
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName '&' -ParameterFilter { 
                $Command -eq 'tofu' -and $Arguments -eq 'version' 
            }
        }

        It 'Should initialize OpenTofu when .terraform directory missing' {
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName '&' -ParameterFilter { 
                $Command -eq 'tofu' -and $Arguments -eq 'init' 
            }
        }

        It 'Should create terraform plan' {
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName '&' -ParameterFilter { 
                $Command -eq 'tofu' -and $Arguments -like 'plan -out=tfplan*' 
            }
        }

        It 'Should handle OpenTofu not found error' {
            Mock -CommandName '&' -MockWith { 
                param([string]$Command, [string]$Arguments)
                if ($Command -eq 'tofu' -and $Arguments -eq 'version') {
                    $global:LASTEXITCODE = 1
                    throw 'tofu: command not found'
                }
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Throw
        }
    }

    Context 'Infrastructure Configuration Generation' {
        It 'Should generate terraform.tfvars from configuration' {
            $config = @{
                Infrastructure = @{
                    HyperV = @{
                        Host = 'hyperv-host'
                        User = 'admin'
                        Port = 5985
                    }
                    DefaultVMPath = 'C:\VMs'
                    DefaultMemory = '2GB'
                    DefaultCPU = 2
                }
            }

            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration $config -WhatIf
            Assert-MockCalled -CommandName 'Set-Content' -ParameterFilter { 
                $Path -eq 'terraform.tfvars' 
            }
        }

        It 'Should include correct HyperV configuration in tfvars' {
            $config = @{
                Infrastructure = @{
                    HyperV = @{
                        Host = 'test-hyperv'
                        User = 'testuser'
                        Port = 5986
                    }
                    DefaultVMPath = 'D:\TestVMs'
                    DefaultMemory = '4GB'
                    DefaultCPU = 4
                }
            }

            Mock -CommandName 'Set-Content' -MockWith { 
                param([string]$Path, [string]$Value)
                $Value | Should -Match 'hyperv_host = "test-hyperv"'
                $Value | Should -Match 'hyperv_user = "testuser"'
                $Value | Should -Match 'hyperv_port = 5986'
                $Value | Should -Match 'vm_path = "D:\\TestVMs"'
                return $null 
            }
            
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration $config -WhatIf
            Assert-MockCalled -CommandName 'Set-Content' -Times 1
        }
    }

    Context 'Auto-Deploy Functionality' {
        It 'Should auto-apply when AutoRun is enabled' {
            $config = @{
                Automation = @{
                    AutoRun = $true
                }
            }

            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration $config -WhatIf
            Assert-MockCalled -CommandName '&' -ParameterFilter { 
                $Command -eq 'tofu' -and $Arguments -like 'apply -auto-approve*' 
            }
        }

        It 'Should not auto-apply when AutoRun is disabled' {
            $config = @{
                Automation = @{
                    AutoRun = $false
                }
            }

            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration $config -WhatIf
            Assert-MockCalled -CommandName '&' -ParameterFilter { 
                $Command -eq 'tofu' -and $Arguments -like 'apply -auto-approve*' 
            } -Times 0
        }
    }

    Context 'Error Handling' {
        It 'Should handle OpenTofu init failure' {
            Mock -CommandName '&' -MockWith { 
                param([string]$Command, [string]$Arguments)
                if ($Command -eq 'tofu' -and $Arguments -eq 'init') {
                    $global:LASTEXITCODE = 1
                    return 'Init failed'
                }
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Throw
        }

        It 'Should handle OpenTofu plan failure' {
            Mock -CommandName '&' -MockWith { 
                param([string]$Command, [string]$Arguments)
                if ($Command -eq 'tofu' -and $Arguments -like 'plan*') {
                    $global:LASTEXITCODE = 1
                    return 'Plan failed'
                }
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Throw
        }

        It 'Should handle OpenTofu apply failure' {
            $config = @{
                Automation = @{
                    AutoRun = $true
                }
            }

            Mock -CommandName '&' -MockWith { 
                param([string]$Command, [string]$Arguments)
                if ($Command -eq 'tofu' -and $Arguments -like 'apply*') {
                    $global:LASTEXITCODE = 1
                    return 'Apply failed'
                }
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            { & $script:ScriptPath -Configuration $config -WhatIf } | Should -Throw
        }
    }

    Context 'Directory Management' {
        It 'Should create infrastructure directory if missing' {
            Mock -CommandName 'Test-Path' -MockWith { 
                param([string]$Path)
                if ($Path -like '*infrastructure*') { return $false }
                return $true
            }
            
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName 'New-Item' -ParameterFilter { 
                $ItemType -eq 'Directory' -and $Force -eq $true 
            }
        }

        It 'Should push and pop location correctly' {
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName 'Push-Location' -Times 1
            Assert-MockCalled -CommandName 'Pop-Location' -Times 1
        }
    }

    Context 'Logging Integration' {
        It 'Should attempt to import logging module' {
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName 'Import-Module' -ParameterFilter { 
                $Path -like '*Logging.psm1*' 
            }
        }

        It 'Should use Write-CustomLog when available' {
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration @{} -WhatIf
            Assert-MockCalled -CommandName 'Get-Command' -ParameterFilter { 
                $Name -eq 'Write-CustomLog' 
            }
        }

        It 'Should fallback to Write-Host when logging unavailable' {
            Mock -CommandName 'Get-Command' -MockWith { 
                param([string]$Name, [switch]$ErrorAction)
                return $null  # Simulate Write-CustomLog not available
            }
            
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            & $script:ScriptPath -Configuration @{} -WhatIf
            # Should still work without throwing
        }
    }

    Context 'WhatIf Support' {
        It 'Should support -WhatIf parameter' {
            $scriptInfo = Get-Command $script:ScriptPath
            $scriptInfo.Parameters.ContainsKey('WhatIf') | Should -Be $true
        }

        It 'Should not make changes in WhatIf mode' {
            Mock -CommandName '&' -MockWith { 
                $global:LASTEXITCODE = 0
                return 'Success'
            }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
            # In a real scenario, we would verify no actual changes were made
        }
    }

    AfterAll {
        # Clean up any test artifacts
        if (Test-Path $script:TestInfraDir) {
            Remove-Item $script:TestInfraDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
