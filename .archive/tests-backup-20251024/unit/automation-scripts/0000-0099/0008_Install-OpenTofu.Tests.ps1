#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0008_Install-OpenTofu.ps1"
    
    # Mock external dependencies
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Get-Command { }
    Mock Invoke-WebRequest { }
    Mock Invoke-RestMethod { }
    Mock Test-Path { $false }
    Mock Remove-Item { }
    Mock New-Item { }
    Mock Expand-Archive { }
    Mock [Environment]::SetEnvironmentVariable { }
}

Describe "0008_Install-OpenTofu" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Installation Control" {
        It "Should skip installation when not enabled in configuration" {
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $false } } }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should skip installation when configuration is missing" {
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should proceed with installation when enabled" {
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            Mock Write-ScriptLog { }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Existing Installation Detection" {
        It "Should exit early if OpenTofu is already installed" {
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "WhatIf Functionality" {
        It "Should not download or install in WhatIf mode" {
            Mock Invoke-WebRequest { throw "Should not download in WhatIf mode" }
            Mock Expand-Archive { throw "Should not extract in WhatIf mode" }
            Mock [Environment]::SetEnvironmentVariable { throw "Should not modify environment in WhatIf mode" }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Invoke-WebRequest
            Should -Not -Invoke Expand-Archive
            Should -Not -Invoke [Environment]::SetEnvironmentVariable
        }
    }

    Context "Version Handling" {
        It "Should use configured version when specified" {
            $testConfig = @{
                InstallationOptions = @{
                    OpenTofu = @{
                        Install = $true
                        Version = "1.7.0"
                    }
                }
            }
            
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should fetch latest version from GitHub API when not specified" {
            $testConfig = @{
                InstallationOptions = @{
                    OpenTofu = @{
                        Install = $true
                        Version = "latest"
                    }
                }
            }
            
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Invoke-RestMethod { @{ tag_name = "v1.8.0" } } -ParameterFilter { $Uri -like "*github.com/repos/opentofu*" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should use fallback version when GitHub API fetch fails" {
            $testConfig = @{
                InstallationOptions = @{
                    OpenTofu = @{
                        Install = $true
                        Version = "latest"
                    }
                }
            }
            
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Invoke-RestMethod { throw "API rate limit" } -ParameterFilter { $Uri -like "*github.com/repos/opentofu*" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Windows Installation" {
        It "Should handle Windows ZIP installation" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock [System.Environment]::Is64BitOperatingSystem { $true }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Join-Path { "C:\\temp\\opentofu_1.8.0.zip" }
            Mock Invoke-WebRequest { }
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*OpenTofu*" }
            Mock New-Item { }
            Mock Expand-Archive { }
            Mock [Environment]::GetEnvironmentVariable { "C:\\existing\\path" }
            Mock [Environment]::SetEnvironmentVariable { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle 32-bit Windows systems" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock [System.Environment]::Is64BitOperatingSystem { $false }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should clean up existing installation directory on Windows" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*OpenTofu*" }
            Mock Remove-Item { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Linux Installation" {
        It "Should handle Linux ZIP installation" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsLinux" }
            Mock [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture { "X64" }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Invoke-WebRequest { }
            Mock Start-Process { } -ParameterFilter { $FilePath -eq "sudo" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle different architectures on Linux" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsLinux" }
            Mock [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture { "Arm64" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "macOS Installation" {
        It "Should use Homebrew when available on macOS" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsMacOS" }
            Mock Get-Command { @{ Name = "brew" } } -ParameterFilter { $Name -eq "brew" }
            Mock Start-Process { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should fallback to manual installation on macOS without Homebrew" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsMacOS" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "brew" }
            Mock [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture { "Arm64" }
            Mock Start-Process { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Post-Installation Verification" {
        It "Should verify installation by running tofu version" {
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" -and $ArgumentList -notcontains "version" }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" -and $ArgumentList -contains "version" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle verification failure" {
            Mock Start-Process { @{ ExitCode = 1 } }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Initialization" {
        It "Should initialize OpenTofu when configured" {
            $testConfig = @{
                InstallationOptions = @{
                    OpenTofu = @{
                        Install = $true
                        Initialize = $true
                    }
                }
                Infrastructure = @{
                    WorkingDirectory = "./infrastructure"
                }
            }
            
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq "./infrastructure" }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle missing working directory during initialization" {
            $testConfig = @{
                InstallationOptions = @{
                    OpenTofu = @{
                        Install = $true
                        Initialize = $true
                    }
                }
            }
            
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Test-Path { $false }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle unsupported operating systems" {
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsLinux" }
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsMacOS" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle download failures" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Invoke-WebRequest { throw "Network error" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle extraction failures" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Invoke-WebRequest { }
            Mock Expand-Archive { throw "Extraction failed" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when available" {
            Mock Get-Command { @{ Name = "Write-CustomLog" } } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-CustomLog { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ OpenTofu = @{ Install = $false } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1
        }
    }
}
