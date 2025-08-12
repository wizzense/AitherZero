#Requires -Version 7.0

Describe "0218_Install-GeminiCLI" {
    BeforeAll {
        Import-Module Pester -Force
        
        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0218_Install-GeminiCLI.ps1"
        
        # Mock external commands
        Mock Start-Process { return @{ ExitCode = 0 } }
        Mock Invoke-WebRequest { }
        Mock Remove-Item { }
        Mock Test-Path { return $false }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'npm' -or $Name -eq 'python' -or $Name -eq 'python3' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'winget' -or $Name -eq 'apt-get' -or $Name -eq 'brew' }
        Mock Invoke-Expression { }
        Mock Get-EnvironmentVariable { return "C:\Windows\System32" }
        Mock Set-EnvironmentVariable { }
        Mock New-Item { }
        Mock Add-Content { }
        Mock Get-Content { return @() }
        
        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
        $Global:LASTEXITCODE = 0
        
        # Mock environment variables
        $env:TEMP = "C:\Temp"
        $env:PATH = "C:\Windows\System32"
        $env:GEMINI_API_KEY = $null
    }
    
    Context "Configuration Validation" {
        It "Should exit early when Gemini CLI installation is not enabled" {
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $false }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should handle empty configuration gracefully" {
            $config = @{}
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should handle null configuration gracefully" {
            $result = & $scriptPath -Configuration $null -WhatIf
        }
    }
    
    Context "Prerequisites Check" {
        It "Should check for Node.js prerequisite" {
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should check for Python prerequisite when Python method is used" {
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        InstallMethod = "python"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should fail when required prerequisites are missing" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'npm' -or $Name -eq 'python' -or $Name -eq 'python3' }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Existing Installation Detection" {
        It "Should detect already installed Gemini CLI" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/gemini" } } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 0
                return "Gemini CLI version 1.0.0"
            } -ParameterFilter { $Command -like "*gemini --version*" -or $Command -like "*gemini version*" }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should proceed with installation when Gemini CLI is not found" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "NPM Installation Method" {
        It "Should install Gemini CLI using npm when Node.js is available" {
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { 
                if ($Command -like "*npm install*") { 
                    $Global:LASTEXITCODE = 0
                    return "Successfully installed @google-ai/generativelanguage"
                }
                if ($Command -like "*gemini*version*") { 
                    return "Gemini CLI version 1.0.0" 
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        InstallMethod = "npm"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle npm installation failure gracefully" {
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { 
                if ($Command -like "*npm install*") { 
                    $Global:LASTEXITCODE = 1
                    throw "npm installation failed"
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        InstallMethod = "npm"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Python Installation Method" {
        It "Should install Gemini CLI using pip when Python is available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { 
                if ($Command -like "*pip install*") { 
                    $Global:LASTEXITCODE = 0
                    return "Successfully installed google-generativeai"
                }
                if ($Command -like "*gemini*version*") { 
                    return "Gemini CLI version 1.0.0" 
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        InstallMethod = "python"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle pip installation failure gracefully" {
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { 
                if ($Command -like "*pip install*") { 
                    $Global:LASTEXITCODE = 1
                    throw "pip installation failed"
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        InstallMethod = "python"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "API Key Configuration" {
        It "Should configure API key when provided" {
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*profile*" -or $Path -like "*bashrc*" -or $Path -like "*zshrc*" }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        ApiKey = "test-api-key-12345"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should create profile files if they don't exist" {
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            Mock Test-Path { return $false }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                        ApiKey = "test-api-key-12345"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip API key configuration when not provided" {
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{
                        Install = $true
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Add-Content -Times 0 -Scope It # No API key to configure
        }
    }
    
    Context "Installation Verification" {
        It "Should verify Gemini CLI installation after successful install" {
            Mock Get-Command { 
                param($Name)
                if ($Name -eq 'npm') { return @{ Source = "/usr/bin/npm" } }
                if ($Name -eq 'gemini') {
                    # First call returns null (not installed), second call returns installed
                    if ($script:GeminiCallCount -eq $null) { $script:GeminiCallCount = 0 }
                    $script:GeminiCallCount++
                    if ($script:GeminiCallCount -le 1) { return $null }
                    else { return @{ Source = "/usr/local/bin/gemini" } }
                }
                return $null
            }
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 0
                if ($Command -like "*npm install*") { return "Successfully installed" }
                if ($Command -like "*gemini*version*") { return "Gemini CLI version 1.0.0" }
            }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should fail when Gemini CLI verification fails" {
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { 
                if ($Command -like "*npm install*") { 
                    $Global:LASTEXITCODE = 0
                    return "Successfully installed" 
                }
                if ($Command -like "*gemini*version*") { 
                    $Global:LASTEXITCODE = 1
                    throw "Gemini command not found"
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Cross-Platform Support" {
        It "Should handle Linux installation" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            Mock Get-Command { return @{ Source = "/usr/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle macOS installation" {
            $Global:IsWindows = $false
            $Global:IsMacOS = $true
            Mock Get-Command { return @{ Source = "/usr/local/bin/npm" } } -ParameterFilter { $Name -eq 'npm' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gemini' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-Expression -Times 0 -Scope It
            Should -Invoke New-Item -Times 0 -Scope It
            Should -Invoke Add-Content -Times 0 -Scope It
        }
    }
    
    Context "Logging" {
        It "Should use custom logging when available" {
            Mock Get-Command { return @{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }
        
        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            $config = @{
                DevelopmentTools = @{
                    GeminiCLI = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
