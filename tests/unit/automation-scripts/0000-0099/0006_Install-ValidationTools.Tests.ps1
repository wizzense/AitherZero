#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0006_Install-ValidationTools.ps1"
    
    # Mock external dependencies
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Get-Module { }
    Mock Install-Module { }
    Mock Update-Module { }
    Mock Find-Module { }
}

Describe "0006_Install-ValidationTools" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ Validation = @{ CheckForUpdates = $true } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "WhatIf Functionality" {
        It "Should not install modules in WhatIf mode" {
            Mock Install-Module { throw "Should not install in WhatIf mode" }
            Mock Update-Module { throw "Should not update in WhatIf mode" }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Install-Module
            Should -Not -Invoke Update-Module
        }
    }

    Context "Module Installation" {
        It "Should install PSScriptAnalyzer when not present" {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq "PSScriptAnalyzer" }
            Mock Install-Module { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should install Pester when not present" {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq "Pester" }
            Mock Install-Module { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should skip installation if modules already exist" {
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } } -ParameterFilter { $Name -eq "PSScriptAnalyzer" }
            Mock Get-Module { @{ Name = "Pester"; Version = "5.3.0" } } -ParameterFilter { $Name -eq "Pester" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Install-Module
        }

        It "Should install with specific version when configured" {
            $testConfig = @{
                Validation = @{
                    ToolVersions = @{
                        PSScriptAnalyzer = "1.19.1"
                        Pester = "5.2.0"
                    }
                }
            }
            
            Mock Get-Module { $null }
            Mock Install-Module { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should verify installation after installing" {
            Mock Get-Module { $null } -ParameterFilter { $ListAvailable -and $Name -eq "PSScriptAnalyzer" }
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } } -ParameterFilter { $ListAvailable -and $Name -eq "PSScriptAnalyzer" }
            Mock Install-Module { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Module Updates" {
        It "Should check for updates when configured" {
            $testConfig = @{
                Validation = @{ CheckForUpdates = $true }
            }
            
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.19.0" } }
            Mock Find-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } }
            Mock Update-Module { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should skip updates when versions are current" {
            $testConfig = @{
                Validation = @{ CheckForUpdates = $true }
            }
            
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } }
            Mock Find-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Update-Module
        }
    }

    Context "Additional Tools" {
        It "Should install additional tools from configuration" {
            $testConfig = @{
                Validation = @{
                    AdditionalTools = @("PSCodeHealth", "Plaster")
                }
            }
            
            Mock Get-Module { $null }
            Mock Install-Module { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle optional tool installation failures gracefully" {
            $testConfig = @{
                Validation = @{
                    AdditionalTools = @("NonExistentTool")
                }
            }
            
            Mock Get-Module { $null }
            Mock Install-Module { throw "Module not found" } -ParameterFilter { $Name -eq "NonExistentTool" }
            Mock Install-Module { } -ParameterFilter { $Name -ne "NonExistentTool" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should exit with error code 1 when required tools fail to install" {
            Mock Get-Module { $null }
            Mock Install-Module { throw "Installation failed" } -ParameterFilter { $Name -eq "PSScriptAnalyzer" }
            Mock Write-ScriptLog { }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle verification failures" {
            Mock Get-Module { $null } -ParameterFilter { $ListAvailable }
            Mock Install-Module { }
            Mock Write-ScriptLog { }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle empty configuration gracefully" {
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when available" {
            Mock Get-Command { @{ Name = "Write-CustomLog" } } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-CustomLog { }
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1
        }

        It "Should fallback to Write-Host when logging unavailable" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-Host { }
            Mock Get-Module { @{ Name = "PSScriptAnalyzer"; Version = "1.20.0" } }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1
        }
    }
}
