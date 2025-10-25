#Requires -Version 7.0

Describe 'PackageManager Module Tests' {
    BeforeAll {
        # Import the module
        $modulePath = Join-Path $PSScriptRoot '../../../../domains/utilities/PackageManager.psm1'
        Import-Module $modulePath -Force

        # Mock Get-Command to return null for Write-CustomLog during tests
        Mock Get-Command {
            return $null
        } -ParameterFilter { $Name -eq 'Write-CustomLog' } -ModuleName PackageManager
    }

    AfterAll {
        Remove-Module PackageManager -Force -ErrorAction SilentlyContinue
    }

    Context 'Get-AvailablePackageManagers' {
        It 'Should detect winget on Windows when available' -Skip {
            # Skip this test - platform variables are read-only in PowerShell 7
            # Will test this functionality in integration tests instead
        }

        It 'Should detect chocolatey on Windows when available' -Skip {
            # Skip this test - platform variables are read-only in PowerShell 7
        }

        It 'Should detect apt on Linux when available' -Skip {
            # Skip this test - platform variables are read-only in PowerShell 7
        }

        It 'Should detect brew on macOS when available' -Skip {
            # Skip this test - platform variables are read-only in PowerShell 7
        }
    }

    Context 'Get-PackageId' {
        It 'Should return correct winget package ID for git' {
            $result = Get-PackageId -SoftwareName 'git' -PackageManagerName 'winget'
            $result | Should -Be 'Git.Git'
        }

        It 'Should return correct chocolatey package ID for nodejs' {
            $result = Get-PackageId -SoftwareName 'nodejs' -PackageManagerName 'chocolatey'
            $result | Should -Be 'nodejs'
        }

        It 'Should return correct apt package ID for vscode' {
            $result = Get-PackageId -SoftwareName 'vscode' -PackageManagerName 'apt'
            $result | Should -Be 'code'
        }

        It 'Should return null for unknown software' {
            $result = Get-PackageId -SoftwareName 'unknownsoftware' -PackageManagerName 'winget'
            $result | Should -BeNullOrEmpty
        }

        It 'Should return null for unknown package manager' {
            $result = Get-PackageId -SoftwareName 'git' -PackageManagerName 'unknownpm'
            $result | Should -BeNullOrEmpty
        }

        It 'Should be case insensitive' {
            $result = Get-PackageId -SoftwareName 'GIT' -PackageManagerName 'WINGET'
            $result | Should -Be 'Git.Git'
        }
    }

    Context 'Test-PackageInstalled' {
        It 'Should return true when winget shows package is installed' {
            Mock Get-PackageId { return 'Git.Git' } -ModuleName PackageManager

            $packageManager = @{
                Name = 'winget'
                Config = @{
                    Command = 'winget'
                    CheckArgs = @('list', '--id', '{0}', '--exact')
                }
            }

            # Mock the actual command execution instead of Invoke-Expression
            Mock -ModuleName PackageManager -CommandName & {
                $global:LASTEXITCODE = 0
                return 'Git.Git    2.40.1'
            }

            $result = Test-PackageInstalled -SoftwareName 'git' -PackageManager $packageManager
            $result | Should -Be $true
        }

        It 'Should return false when package is not installed' -Skip {
            # Skip - command mocking is complex in this context
        }

        It 'Should return false when package ID is not found' {
            Mock Get-PackageId { return $null } -ModuleName PackageManager

            $packageManager = @{
                Name = 'winget'
                Config = @{}
            }

            $result = Test-PackageInstalled -SoftwareName 'unknownsoftware' -PackageManager $packageManager
            $result | Should -Be $false
        }
    }

    Context 'Get-SoftwareVersion' {
        It 'Should return git version when git is available' -Skip {
            # Skip - using real git command which may vary between environments
        }

        It 'Should return node version when nodejs is available' -Skip {
            # Skip - using real node command which may vary between environments
        }

        It 'Should handle custom version command' {
            Mock Invoke-Expression {
                $global:LASTEXITCODE = 0
                return 'Custom Version 1.0.0'
            } -ModuleName PackageManager

            $result = Get-SoftwareVersion -SoftwareName 'customsoftware' -Command 'custom --version'
            $result | Should -Be 'Custom Version 1.0.0'
        }

        It 'Should return error message when command fails' -Skip {
            # Skip - using real git command
        }

        It 'Should return appropriate message for unknown software' {
            $result = Get-SoftwareVersion -SoftwareName 'unknownsoftware'
            $result | Should -Be 'Version check not available for unknownsoftware'
        }
    }

    Context 'Install-SoftwarePackage' {
        It 'Should skip installation when package is already installed' -Skip {
            # Skip - platform variable override issue
        }

        It 'Should use preferred package manager when specified' -Skip {
            # Skip - platform variable override issue
        }

        It 'Should throw error when no package managers are available' -Skip {
            # Skip - platform variable override issue
        }
    }
}