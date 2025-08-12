#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0009_Initialize-OpenTofu.ps1"
    
    # Mock external dependencies
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Get-Command { }
    Mock Test-Path { $false }
    Mock Get-ChildItem { @() }
    Mock Push-Location { }
    Mock Pop-Location { }
    Mock Join-Path { param($Path, $ChildPath) "$Path/$ChildPath" }
    Mock Split-Path { "/workspaces/AitherZero" }
}

Describe "0009_Initialize-OpenTofu" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ Infrastructure = @{ WorkingDirectory = "./infrastructure" } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "OpenTofu Availability Check" {
        It "Should check if OpenTofu is available" {
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should exit with error if OpenTofu is not available" {
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle tofu command not found" {
            Mock Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq "tofu" }
            Mock Write-ScriptLog { }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "WhatIf Functionality" {
        It "Should not run tofu commands in WhatIf mode" {
            Mock Start-Process { throw "Should not run tofu in WhatIf mode" }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Start-Process
        }
    }

    Context "Directory Discovery" {
        It "Should find Terraform files in configured working directory" {
            $testConfig = @{
                Infrastructure = @{
                    WorkingDirectory = "./infrastructure"
                }
            }
            
            Mock Test-Path { $true } -ParameterFilter { $Path -eq "./infrastructure" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) } -ParameterFilter { $Filter -eq "*.tf" -and $File }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should search subdirectories for Terraform files" {
            Mock Test-Path { $true } -ParameterFilter { $Path -eq "./infrastructure" }
            Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq "*.tf" -and $File -and $Path -eq "./infrastructure" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/modules"; IsContainer = $true }) } -ParameterFilter { $Directory -and $Path -eq "./infrastructure" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/modules/vpc.tf" }) } -ParameterFilter { $Filter -eq "*.tf" -and $File -and $Path -like "*modules*" }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should check legacy infrastructure path" {
            $testConfig = @{
                Infrastructure = @{
                    Directories = @{
                        InfraRepoPath = "%TEMP%\\base-infra"
                    }
                }
            }
            
            Mock Test-Path { $false } -ParameterFilter { $Path -eq "./infrastructure" }
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*base-infra*opentofu*" }
            Mock [System.Environment]::ExpandEnvironmentVariables { param($Path) $Path -replace "%TEMP%", "C:\\temp" }
            Mock Get-ChildItem { @(@{ FullName = "C:\\temp\\base-infra\\opentofu\\main.tf" }) }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should exit gracefully when no Terraform files are found" {
            Mock Test-Path { $false }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should use default infrastructure directory when none configured" {
            Mock [System.IO.Path]::IsPathRooted { $false }
            Mock Join-Path { "./infrastructure" }
            Mock Split-Path { "/workspaces/AitherZero" }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq "./infrastructure" }
            Mock Get-ChildItem { @() }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Initialization Process" {
        It "Should initialize directory that has not been initialized" {
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" -and $ArgumentList -contains "init" }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should run init with upgrade for already initialized directories" {
            Mock Test-Path { $true }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" -and $ArgumentList -contains "-upgrade" }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle backend configuration" {
            $testConfig = @{
                Infrastructure = @{
                    Backend = @{
                        Type = "s3"
                        Bucket = "terraform-state"
                        Key = "infrastructure/terraform.tfstate"
                        Region = "us-west-2"
                    }
                }
            }
            
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle initialization failure" {
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $ArgumentList -contains "init" }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Configuration Validation" {
        It "Should run tofu validate after successful initialization" {
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $ArgumentList -contains "init" }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $ArgumentList -contains "validate" }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle validation failure" {
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $ArgumentList -contains "init" }
            Mock Start-Process { @{ ExitCode = 1 } } -ParameterFilter { $ArgumentList -contains "validate" }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle validation errors gracefully" {
            Mock Start-Process { throw "Validation error" } -ParameterFilter { $ArgumentList -contains "validate" }
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Multiple Directory Handling" {
        It "Should initialize multiple directories containing Terraform files" {
            Mock Test-Path { $true }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) } -ParameterFilter { $Path -eq "./infrastructure" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/modules"; IsContainer = $true }) } -ParameterFilter { $Directory }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/modules/vpc.tf" }) } -ParameterFilter { $Path -like "*modules*" }
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle directory access errors" {
            Mock Test-Path { throw "Access denied" }
            Mock Write-ScriptLog { }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle tofu command execution errors in try-catch" {
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Start-Process { throw "Command execution failed" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should always pop location even on errors" {
            Mock Test-Path { $true } -ParameterFilter { $Path -ne ".terraform" }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq ".terraform" }
            Mock Get-ChildItem { @(@{ FullName = "./infrastructure/main.tf" }) }
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Start-Process { throw "Error during execution" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Pop-Location
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when available" {
            Mock Get-Command { @{ Name = "Write-CustomLog" } } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-CustomLog { }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1
        }

        It "Should fallback to Write-Host when logging unavailable" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-Host { }
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "tofu" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1
        }
    }
}
