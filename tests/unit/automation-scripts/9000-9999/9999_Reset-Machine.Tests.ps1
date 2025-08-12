#Requires -Modules Pester

Describe "9999_Reset-Machine" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/9999_Reset-Machine.ps1"
        
        # Mock dangerous external commands that could cause damage
        Mock -CommandName Start-Process
        Mock -CommandName Checkpoint-Computer
        Mock -CommandName Set-ItemProperty
        Mock -CommandName Enable-NetFirewallRule  
        Mock -CommandName New-NetFirewallRule
        Mock -CommandName Get-ChildItem { @() }
        Mock -CommandName Remove-Item
        Mock -CommandName Get-Command { $null }
        Mock -CommandName Import-Module
        
        # Mock Write-Host to capture logging output
        Mock -CommandName Write-Host
        
        # Mock platform detection variables
        $script:OriginalIsWindows = $global:IsWindows
        $script:OriginalIsLinux = $global:IsLinux  
        $script:OriginalIsMacOS = $global:IsMacOS
    }
    
    AfterAll {
        # Restore original platform variables if they were set
        if ($null -ne $script:OriginalIsWindows) { $global:IsWindows = $script:OriginalIsWindows }
        if ($null -ne $script:OriginalIsLinux) { $global:IsLinux = $script:OriginalIsLinux }
        if ($null -ne $script:OriginalIsMacOS) { $global:IsMacOS = $script:OriginalIsMacOS }
    }

    Context "Parameter Validation and Configuration" {
        It "Should accept Configuration parameter" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $false }
            
            # This should not throw for parameter binding
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should exit gracefully when reset is not enabled" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $false
                        AllowReset = $false
                    }
                }
            }
            
            Mock -CommandName Test-Path { $false }
            Mock -CommandName Write-Host
            
            $result = & $scriptPath -Configuration $config -WhatIf 2>$null
            $LASTEXITCODE | Should -Be 0
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Machine reset is not enabled*" 
            }
        }
        
        It "Should apply configuration overrides correctly" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        PrepareForRemoteAccess = $false
                        WindowsSysprepMode = 'audit'
                        CreateRestorePoint = $false
                        BackupUserData = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $false }
            Mock -CommandName Write-Host
            
            # Should not throw and should process configuration
            { & $scriptPath -Configuration $config -WhatIf 2>$null } | Should -Not -Throw
        }
    }

    Context "Windows Platform Tests" {
        BeforeEach {
            $global:IsWindows = $true
            $global:IsLinux = $false
            $global:IsMacOS = $false
        }
        
        It "Should detect Windows platform correctly" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $false }  # No sysprep found
            Mock -CommandName Write-Host
            
            { & $scriptPath -Configuration $config -WhatIf 2>$null } | Should -Throw "*Sysprep not found*"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Detected Windows platform*" 
            }
        }
        
        It "Should create restore point when configured" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        CreateRestorePoint = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { 
                param($Path)
                if ($Path -like "*Sysprep.exe") { $true } else { $false }
            }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Checkpoint-Computer -Times 0 -Exactly  # WhatIf should not execute
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Creating system restore point*" 
            }
        }
        
        It "Should configure remote access when enabled" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        PrepareForRemoteAccess = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { 
                param($Path)
                if ($Path -like "*Sysprep.exe") { $true } else { $false }
            }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            # WhatIf should not execute dangerous operations
            Should -Invoke Set-ItemProperty -Times 0 -Exactly
            Should -Invoke Enable-NetFirewallRule -Times 0 -Exactly
            Should -Invoke New-NetFirewallRule -Times 0 -Exactly
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Preparing for remote access*" 
            }
        }
        
        It "Should handle sysprep OOBE mode correctly" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        WindowsSysprepMode = 'oobe'
                    }
                }
            }
            
            Mock -CommandName Test-Path { 
                param($Path)
                if ($Path -like "*Sysprep.exe") { $true } else { $false }
            }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Start-Process -Times 0 -Exactly  # WhatIf should not execute
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Sysprep will generalize and shutdown for OOBE*" 
            }
        }
        
        It "Should handle sysprep audit mode correctly" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        WindowsSysprepMode = 'audit'
                    }
                }
            }
            
            Mock -CommandName Test-Path { 
                param($Path)
                if ($Path -like "*Sysprep.exe") { $true } else { $false }
            }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Sysprep will generalize and reboot to audit mode*" 
            }
        }
        
        It "Should respect WhatIf for sysprep execution" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $true }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            # WhatIf should prevent actual execution
            Should -Invoke Start-Process -Times 0 -Exactly
        }
    }

    Context "Linux Platform Tests" {
        BeforeEach {
            $global:IsWindows = $false
            $global:IsLinux = $true
            $global:IsMacOS = $false
        }
        
        It "Should detect Linux platform correctly" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            Mock -CommandName Get-Command { $null }  # No package managers found
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Detected Linux platform*" 
            }
        }
        
        It "Should clear temporary files on Linux" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            Mock -CommandName Get-ChildItem { @() }  # Empty temp directory
            Mock -CommandName Get-Command { $null }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            # WhatIf should not execute Remove-Item
            Should -Invoke Remove-Item -Times 0 -Exactly
        }
        
        It "Should handle apt package manager cleanup" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            Mock -CommandName Get-Command { 
                param($Name)
                if ($Name -eq 'apt-get') { [PSCustomObject]@{} } else { $null }
            }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Clean package cache*" 
            }
        }
        
        It "Should schedule reboot with proper warning" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            Mock -CommandName Get-Command { $null }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*System will reboot in 1 minute*" 
            }
        }
    }

    Context "macOS Platform Tests" {
        BeforeEach {
            $global:IsWindows = $false
            $global:IsLinux = $false
            $global:IsMacOS = $true
        }
        
        It "Should detect macOS platform correctly" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            Mock -CommandName Get-Command { $null }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Detected macOS platform*" 
            }
        }
        
        It "Should handle Homebrew cleanup on macOS" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            Mock -CommandName Get-Command { 
                param($Name)
                if ($Name -eq 'brew') { [PSCustomObject]@{} } else { $null }
            }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Clean package cache*" 
            }
        }
    }

    Context "Unsupported Platform Tests" {
        BeforeEach {
            $global:IsWindows = $false
            $global:IsLinux = $false
            $global:IsMacOS = $false
        }
        
        It "Should fail gracefully on unsupported platforms" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                    }
                }
            }
            
            Mock -CommandName Write-Host
            
            { & $scriptPath -Configuration $config -WhatIf 2>$null } | Should -Throw "*Unsupported platform*"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Unknown platform*" 
            }
        }
    }

    Context "WhatIf Parameter Tests" {
        BeforeEach {
            $global:IsWindows = $true
            $global:IsLinux = $false
            $global:IsMacOS = $false
        }
        
        It "Should respect WhatIf for registry changes" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        PrepareForRemoteAccess = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $true }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            # WhatIf should prevent registry modifications
            Should -Invoke Set-ItemProperty -Times 0 -Exactly
        }
        
        It "Should respect WhatIf for firewall changes" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        PrepareForRemoteAccess = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $true }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            # WhatIf should prevent firewall modifications
            Should -Invoke Enable-NetFirewallRule -Times 0 -Exactly
            Should -Invoke New-NetFirewallRule -Times 0 -Exactly
        }
        
        It "Should respect WhatIf for restore point creation" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        CreateRestorePoint = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $true }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            # WhatIf should prevent restore point creation
            Should -Invoke Checkpoint-Computer -Times 0 -Exactly
        }
    }

    Context "Error Handling" {
        BeforeEach {
            $global:IsWindows = $true
            $global:IsLinux = $false
            $global:IsMacOS = $false
        }
        
        It "Should handle restore point creation failure gracefully" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        CreateRestorePoint = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $true }
            Mock -CommandName Checkpoint-Computer { throw "Access denied" }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -Confirm:$false 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Failed to create restore point*" 
            }
        }
        
        It "Should handle remote desktop configuration failure gracefully" {
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $true
                        AllowReset = $true
                        PrepareForRemoteAccess = $true
                    }
                }
            }
            
            Mock -CommandName Test-Path { $true }
            Mock -CommandName Set-ItemProperty { throw "Registry error" }
            Mock -CommandName Write-Host
            
            & $scriptPath -Configuration $config -Confirm:$false 2>$null
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -like "*Failed to enable Remote Desktop*" 
            }
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when Logging module is available" {
            Mock -CommandName Test-Path { 
                param($Path)
                if ($Path -like "*Logging.psm1") { $true } else { $false }
            }
            Mock -CommandName Import-Module
            Mock -CommandName Get-Command { 
                param($Name)
                if ($Name -eq 'Write-CustomLog') { [PSCustomObject]@{} } else { $null }
            }
            Mock -CommandName Write-CustomLog
            
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $false
                        AllowReset = $false
                    }
                }
            }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Import-Module -ParameterFilter { 
                $Name -like "*Logging.psm1*" 
            }
        }
        
        It "Should fall back to Write-Host when Logging module is not available" {
            Mock -CommandName Test-Path { $false }
            Mock -CommandName Write-Host
            
            $config = @{
                Maintenance = @{
                    MachineReset = @{
                        Enable = $false
                        AllowReset = $false
                    }
                }
            }
            
            & $scriptPath -Configuration $config -WhatIf 2>$null
            
            Should -Invoke Write-Host -Times 1 -AtLeast
        }
    }
}
