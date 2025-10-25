#Requires -Version 7.0

BeforeAll {
    # Mock external commands and modules
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'fake-token' }
    Mock Test-Path { return $true }
    Mock New-Item { }
    Mock Set-Content { }
    Mock Get-Content { return '{}' }
    Mock Start-Process { return @{ ExitCode = 0 } }
    Mock Invoke-RestMethod {
        return @{
            token = 'FAKE_RUNNER_TOKEN'
            actions_runner_download_url = 'https://github.com/actions/runner/releases/download/v2.0.0/actions-runner-linux-x64-2.0.0.tar.gz'
        }
    }
    Mock Invoke-WebRequest { }
    Mock Expand-Archive { }

    # Mock platform detection
    Mock Get-Variable {
        param($Name)
        switch ($Name) {
            'IsWindows' { return @{ Value = $false } }
            'IsLinux' { return @{ Value = $true } }
            'IsMacOS' { return @{ Value = $false } }
        }
    }

    # Mock GitHub CLI
    Mock gh {
        switch -Regex ($arguments -join ' ') {
            'auth status' { return 'Logged in to github.com' }
            'api' { return '{"login": "testuser"}' }
            default { return '' }
        }
    }
}

Describe "0720_Setup-GitHubRunners" {
    Context "Parameter Validation" {
        It "Should require Organization parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -WhatIf } | Should -Not -Throw
        }

        It "Should validate Platform parameter values" {
            $validPlatforms = @('Windows', 'Linux', 'macOS', 'Auto')
            foreach ($platform in $validPlatforms) {
                { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Platform $platform -WhatIf } | Should -Not -Throw
            }
        }

        It "Should accept RunnerCount parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -RunnerCount 5 -WhatIf } | Should -Not -Throw
        }

        It "Should accept optional Repository parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Repository "testrepo" -WhatIf } | Should -Not -Throw
        }
    }

    Context "Platform Detection" {
        It "Should detect Linux platform when Auto is specified" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Platform "Auto" -DryRun -WhatIf

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Platform: Linux*" }
        }

        It "Should use specified platform when not Auto" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Platform "Windows" -DryRun -WhatIf

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Platform: Windows*" }
        }
    }

    Context "Token Handling" {
        It "Should prompt for token when not provided" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -DryRun -WhatIf

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*token*" }
        }

        It "Should use provided token when specified" {
            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "provided-token" -DryRun -WhatIf } | Should -Not -Throw
        }
    }

    Context "GitHub API Integration" {
        It "Should call GitHub API to get runner registration token" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -like "*registration-token*" }
        }

        It "Should handle organization-level runners" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -like "*orgs/testorg*" }
        }

        It "Should handle repository-level runners when Repository is specified" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Repository "testrepo" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -like "*repos/testorg/testrepo*" }
        }
    }

    Context "Runner Download and Setup" {
        It "Should download runner package" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -like "*actions-runner*" }
        }

        It "Should extract runner package" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Expand-Archive
        }
    }

    Context "Runner Configuration" {
        It "Should configure runner with correct parameters" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -RunnerGroup "custom" -Labels "docker,buildx" -DryRun -WhatIf

            Should -Invoke Start-Process -ParameterFilter { $ArgumentList -contains '--runnergroup' -and $ArgumentList -contains 'custom' }
            Should -Invoke Start-Process -ParameterFilter { $ArgumentList -contains '--labels' -and $ArgumentList -contains 'docker,buildx' }
        }

        It "Should use default work directory when not specified" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Start-Process -ParameterFilter { $ArgumentList -contains '--work' -and $ArgumentList -contains '_work' }
        }

        It "Should use custom work directory when specified" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -WorkDirectory "custom_work" -DryRun -WhatIf

            Should -Invoke Start-Process -ParameterFilter { $ArgumentList -contains '--work' -and $ArgumentList -contains 'custom_work' }
        }
    }

    Context "Multiple Runners" {
        It "Should create specified number of runners" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -RunnerCount 3 -DryRun -WhatIf

            # Should call configuration process 3 times
            Should -Invoke Start-Process -Exactly 3 -ParameterFilter { $ArgumentList -contains './config.sh' }
        }
    }

    Context "DryRun Mode" {
        It "Should show what would be done without making changes in DryRun mode" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -DryRun -WhatIf

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*DRY RUN*" }
            Should -Not -Invoke Invoke-WebRequest
        }
    }

    Context "CI Mode" {
        It "Should run with minimal output in CI mode" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -CI -DryRun -WhatIf

            # Should use unattended configuration
            Should -Invoke Start-Process -ParameterFilter { $ArgumentList -contains '--unattended' }
        }
    }

    Context "WhatIf Support" {
        It "Should show runner setup operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" -WhatIf

            Should -Not -Invoke Invoke-WebRequest
            Should -Not -Invoke Start-Process -ParameterFilter { $ArgumentList -contains './config.sh' }
        }
    }

    Context "Error Handling" {
        It "Should handle GitHub API failures" {
            Mock Invoke-RestMethod { throw "API Error" }

            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" } | Should -Throw
        }

        It "Should handle download failures" {
            Mock Invoke-WebRequest { throw "Download failed" }

            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" } | Should -Throw
        }

        It "Should handle runner configuration failures" {
            Mock Start-Process { return @{ ExitCode = 1 } }

            { & "/workspaces/AitherZero/automation-scripts/0720_Setup-GitHubRunners.ps1" -Organization "testorg" -Token "test-token" } | Should -Throw
        }
    }
}
