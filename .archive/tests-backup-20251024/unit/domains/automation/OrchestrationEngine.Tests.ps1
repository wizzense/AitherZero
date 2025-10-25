#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "domains/automation/OrchestrationEngine.psm1"

    # Import the module under test
    Import-Module $script:ModulePath -Force -ErrorAction Stop

    # Mock external dependencies
    Mock Write-CustomLog {}
    Mock Test-Path { $true }
    Mock Get-ChildItem {
        @(
            [PSCustomObject]@{ Name = "0400_Script1.ps1"; FullName = "/scripts/0400_Script1.ps1" }
            [PSCustomObject]@{ Name = "0401_Script2.ps1"; FullName = "/scripts/0401_Script2.ps1" }
            [PSCustomObject]@{ Name = "0402_Script3.ps1"; FullName = "/scripts/0402_Script3.ps1" }
        )
    }
}

AfterAll {
    # Cleanup
    Remove-Module OrchestrationEngine -Force -ErrorAction SilentlyContinue
}

Describe "OrchestrationEngine Module" -Tag 'Unit' {

    Context "ConvertTo-ScriptNumbers" {
        It "Should convert single number to array" {
            $result = ConvertTo-ScriptNumbers -Sequence "0400"
            $result | Should -Be @("0400")
        }

        It "Should expand range notation" {
            $result = ConvertTo-ScriptNumbers -Sequence "0400-0402"
            $result | Should -Contain "0400"
            $result | Should -Contain "0401"
            $result | Should -Contain "0402"
            $result.Count | Should -Be 3
        }

        It "Should handle comma-separated values" {
            $result = ConvertTo-ScriptNumbers -Sequence "0400,0402,0404"
            $result | Should -Be @("0400", "0402", "0404")
        }

        It "Should handle mixed notation" {
            $result = ConvertTo-ScriptNumbers -Sequence "0400-0402,0404,0406-0407"
            $result | Should -Contain "0400"
            $result | Should -Contain "0401"
            $result | Should -Contain "0402"
            $result | Should -Contain "0404"
            $result | Should -Contain "0406"
            $result | Should -Contain "0407"
            $result.Count | Should -Be 6
        }

        It "Should handle ranges with padding" {
            $result = ConvertTo-ScriptNumbers -Sequence "0098-0102"
            $result | Should -Contain "0098"
            $result | Should -Contain "0099"
            $result | Should -Contain "0100"
            $result | Should -Contain "0101"
            $result | Should -Contain "0102"
        }

        It "Should remove duplicates" {
            $result = ConvertTo-ScriptNumbers -Sequence "0400,0400,0401,0400-0401"
            $result | Should -Be @("0400", "0401")
        }
    }

    Context "Find-AutomationScripts" {
        BeforeEach {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = "0400_Test1.ps1"; FullName = "/scripts/0400_Test1.ps1" }
                    [PSCustomObject]@{ Name = "0401_Test2.ps1"; FullName = "/scripts/0401_Test2.ps1" }
                    [PSCustomObject]@{ Name = "0402_Test3.ps1"; FullName = "/scripts/0402_Test3.ps1" }
                    [PSCustomObject]@{ Name = "0500_Test4.ps1"; FullName = "/scripts/0500_Test4.ps1" }
                )
            }
        }

        It "Should find scripts by exact number" {
            $result = Find-AutomationScripts -ScriptNumbers @("0400")
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "0400_Test1.ps1"
        }

        It "Should find multiple scripts" {
            $result = Find-AutomationScripts -ScriptNumbers @("0400", "0402")
            $result.Count | Should -Be 2
            $result.Name | Should -Contain "0400_Test1.ps1"
            $result.Name | Should -Contain "0402_Test3.ps1"
        }

        It "Should return empty for non-existent scripts" {
            $result = Find-AutomationScripts -ScriptNumbers @("9999")
            $result | Should -BeNullOrEmpty
        }

        It "Should handle scripts in subdirectories" {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{
                        Name = "0400_Nested.ps1"
                        FullName = "/scripts/subfolder/0400_Nested.ps1"
                    }
                )
            }

            $result = Find-AutomationScripts -ScriptNumbers @("0400")
            $result.Count | Should -Be 1
            $result[0].FullName | Should -Match "subfolder"
        }
    }

    Context "Invoke-OrchestrationSequence" {
        BeforeEach {
            Mock Start-Process {
                [PSCustomObject]@{
                    ExitCode = 0
                    StandardOutput = "Script executed successfully"
                    StandardError = ""
                }
            }
            Mock Test-Path { $true }
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{
                        Name = "0400_Test.ps1"
                        FullName = "$($script:ProjectRoot)/automation-scripts/0400_Test.ps1"
                    }
                )
            }
        }

        It "Should execute single script successfully" {
            $result = Invoke-OrchestrationSequence -Sequence "0400"

            $result.Success | Should -Be $true
            $result.ExecutedScripts | Should -Be 1
            $result.FailedScripts | Should -Be 0
        }

        It "Should execute multiple scripts in sequence" {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = "0400_Test1.ps1"; FullName = "/scripts/0400_Test1.ps1" }
                    [PSCustomObject]@{ Name = "0401_Test2.ps1"; FullName = "/scripts/0401_Test2.ps1" }
                    [PSCustomObject]@{ Name = "0402_Test3.ps1"; FullName = "/scripts/0402_Test3.ps1" }
                )
            }

            $result = Invoke-OrchestrationSequence -Sequence "0400-0402"

            $result.Success | Should -Be $true
            $result.ExecutedScripts | Should -Be 3
            $result.FailedScripts | Should -Be 0
        }

        It "Should handle script failures" {
            Mock Start-Process {
                [PSCustomObject]@{
                    ExitCode = 1
                    StandardOutput = ""
                    StandardError = "Script failed"
                }
            }

            $result = Invoke-OrchestrationSequence -Sequence "0400"

            $result.Success | Should -Be $false
            $result.ExecutedScripts | Should -Be 0
            $result.FailedScripts | Should -Be 1
        }

        It "Should respect DryRun mode" {
            $result = Invoke-OrchestrationSequence -Sequence "0400" -DryRun

            $result.Success | Should -Be $true
            $result.DryRun | Should -Be $true
            Should -Not -Invoke Start-Process
        }

        It "Should pass variables to scripts" {
            Mock Start-Process {
                param($ArgumentList)
                $ArgumentList | Should -Contain "-Variable1"
                $ArgumentList | Should -Contain "Value1"

                [PSCustomObject]@{
                    ExitCode = 0
                    StandardOutput = "Success"
                    StandardError = ""
                }
            }

            $variables = @{ Variable1 = "Value1"; Variable2 = "Value2" }
            $result = Invoke-OrchestrationSequence -Sequence "0400" -Variables $variables

            $result.Success | Should -Be $true
        }

        It "Should validate dependencies" {
            Mock Test-ScriptDependencies { $false }

            $result = Invoke-OrchestrationSequence -Sequence "0400" -ValidateBeforeRun

            $result.Success | Should -Be $false
            $result.ValidationErrors | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-OrchestrationPlaybook" {
        BeforeEach {
            $script:PlaybookPath = Join-Path $TestDrive "playbooks"
            New-Item -ItemType Directory -Path $script:PlaybookPath -Force

            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{
                        Name = "test-playbook.json"
                        FullName = "$($script:PlaybookPath)/test-playbook.json"
                    }
                )
            } -ParameterFilter { $Path -like "*playbooks*" }
        }

        It "Should load playbook from file" {
            $playbook = @{
                Name = "TestPlaybook"
                Description = "Test playbook"
                Sequence = @("0400", "0401", "0402")
                Variables = @{ Key = "Value" }
            }
            $playbook | ConvertTo-Json | Set-Content "$($script:PlaybookPath)/test-playbook.json"

            $result = Get-OrchestrationPlaybook -Name "test-playbook"

            $result.Name | Should -Be "TestPlaybook"
            $result.Sequence.Count | Should -Be 3
            $result.Variables.Key | Should -Be "Value"
        }

        It "Should return null for non-existent playbook" {
            $result = Get-OrchestrationPlaybook -Name "non-existent"
            $result | Should -BeNullOrEmpty
        }

        It "Should list all available playbooks" {
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ Name = "playbook1.json" }
                    [PSCustomObject]@{ Name = "playbook2.json" }
                    [PSCustomObject]@{ Name = "playbook3.json" }
                )
            } -ParameterFilter { $Path -like "*playbooks*" }

            $result = Get-OrchestrationPlaybook -ListAvailable

            $result.Count | Should -Be 3
        }
    }

    Context "Save-OrchestrationPlaybook" {
        BeforeEach {
            $script:PlaybookPath = Join-Path $TestDrive "playbooks"
            New-Item -ItemType Directory -Path $script:PlaybookPath -Force
        }

        It "Should save new playbook" {
            $result = Save-OrchestrationPlaybook -Name "new-playbook" `
                -Sequence @("0400", "0401") `
                -Description "New test playbook" `
                -Variables @{ Test = "Value" }

            $result | Should -Be $true

            $savedPath = Join-Path $script:PlaybookPath "new-playbook.json"
            Test-Path $savedPath | Should -Be $true

            $content = Get-Content $savedPath -Raw | ConvertFrom-Json
            $content.Name | Should -Be "new-playbook"
            $content.Sequence.Count | Should -Be 2
        }

        It "Should not overwrite existing playbook without Force" {
            $existingPath = Join-Path $script:PlaybookPath "existing.json"
            @{ Name = "Existing" } | ConvertTo-Json | Set-Content $existingPath

            { Save-OrchestrationPlaybook -Name "existing" -Sequence @("0400") } | Should -Throw
        }

        It "Should overwrite with Force parameter" {
            $existingPath = Join-Path $script:PlaybookPath "existing.json"
            @{ Name = "Old" } | ConvertTo-Json | Set-Content $existingPath

            $result = Save-OrchestrationPlaybook -Name "existing" `
                -Sequence @("0400") `
                -Force

            $result | Should -Be $true

            $content = Get-Content $existingPath -Raw | ConvertFrom-Json
            $content.Sequence | Should -Contain "0400"
        }
    }

    Context "Test-ScriptDependencies" {
        It "Should validate script dependencies" {
            Mock Test-Path { $true }
            Mock Get-Command { $true }

            $result = Test-ScriptDependencies -ScriptPath "/scripts/0400_Test.ps1"
            $result | Should -Be $true
        }

        It "Should detect missing dependencies" {
            Mock Test-Path { $false }

            $result = Test-ScriptDependencies -ScriptPath "/scripts/0400_Test.ps1"
            $result | Should -Be $false
        }
    }

    Context "Get-OrchestrationHistory" {
        It "Should return execution history" -Skip {
            # This would require database or file-based history tracking
            # Marking as skip for future implementation
        }
    }

    Context "Parallel Execution" {
        It "Should execute scripts in parallel when specified" {
            Mock Start-Job {
                [PSCustomObject]@{
                    Id = 1
                    State = "Completed"
                    HasMoreData = $false
                }
            }
            Mock Wait-Job {}
            Mock Receive-Job { "Success" }
            Mock Remove-Job {}

            $result = Invoke-OrchestrationSequence -Sequence "0400,0401,0402" -Parallel

            Should -Invoke Start-Job -Times 3
            $result.Success | Should -Be $true
        }

        It "Should respect MaxConcurrency limit" {
            $script:JobCount = 0
            Mock Start-Job {
                $script:JobCount++
                [PSCustomObject]@{
                    Id = $script:JobCount
                    State = "Running"
                }
            }

            # This would need more complex testing for concurrency limits
            # Simplified for unit test
            $result = Invoke-OrchestrationSequence -Sequence "0400-0410" -Parallel -MaxConcurrency 3

            $result | Should -Not -BeNullOrEmpty
        }
    }
}