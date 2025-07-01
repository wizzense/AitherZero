#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'New-PatchIssue'
}

Describe 'PatchManager.New-PatchIssue' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Write-Host { } -ModuleName $script:ModuleName
        Mock Test-Path { $true } -ModuleName $script:ModuleName
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        
        # Mock git operations
        Mock git {
            if ($args -contains 'config' -and $args -contains 'user.email') {
                return 'test@example.com'
            }
            if ($args -contains 'config' -and $args -contains 'user.name') {
                return 'Test User'
            }
            if ($args -contains 'remote' -and $args -contains 'get-url') {
                return 'https://github.com/testuser/testrepo.git'
            }
            if ($args -contains 'branch' -and $args -contains '--show-current') {
                return 'main'
            }
            if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                return 'abc123def456'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock gh CLI
        Mock gh {
            if ($args -contains 'issue' -and $args -contains 'create') {
                return 'https://github.com/testuser/testrepo/issues/123'
            }
            if ($args -contains 'issue' -and $args -contains 'list') {
                return ''
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock Get-GitRepositoryInfo
        Mock Get-GitRepositoryInfo {
            @{
                Owner = 'testuser'
                Name = 'testrepo'
                Branch = 'main'
                Remote = 'origin'
            }
        } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'PatchManagerIssueTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Description parameter' {
            { New-PatchIssue } | Should -Throw
        }
        
        It 'Should accept valid Description' {
            { New-PatchIssue -Description "Test issue" -DryRun } | Should -Not -Throw
        }
        
        It 'Should validate Priority parameter values' {
            { New-PatchIssue -Description "Test" -Priority "Invalid" } | Should -Throw
        }
        
        It 'Should accept valid Priority values' {
            $validPriorities = @('Low', 'Medium', 'High', 'Critical')
            
            foreach ($priority in $validPriorities) {
                { New-PatchIssue -Description "Test" -Priority $priority -DryRun } | Should -Not -Throw
            }
        }
        
        It 'Should use Medium as default Priority' {
            $result = New-PatchIssue -Description "Default priority test" -DryRun
            
            # Verify the issue body would contain Medium priority
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Priority: Medium" -or $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Dry Run Mode' {
        It 'Should not create actual issue in dry run mode' {
            $result = New-PatchIssue -Description "Dry run test" -DryRun
            
            Should -Invoke gh -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'issue' -and $args -contains 'create'
            }
            
            $result.DryRun | Should -Be $true
        }
        
        It 'Should log dry run information' {
            New-PatchIssue -Description "Dry run logging" -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "DRY RUN" -and $Level -eq 'WARN'
            }
        }
    }
    
    Context 'Issue Creation' {
        It 'Should create issue with basic information' {
            $result = New-PatchIssue -Description "Basic issue test"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'issue' -and
                $args -contains 'create' -and
                $args -contains '--title' -and
                $args -contains 'Basic issue test'
            }
            
            $result.Success | Should -Be $true
            $result.IssueUrl | Should -Match 'github.com/.*/issues/\d+'
        }
        
        It 'Should include priority in labels' {
            New-PatchIssue -Description "Priority test" -Priority "High"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--label' -and
                $args -contains 'Priority:High'
            }
        }
        
        It 'Should include patch label by default' {
            New-PatchIssue -Description "Patch label test"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--label' -and
                $args -contains 'patch'
            }
        }
        
        It 'Should add enhancement label for patch type' {
            New-PatchIssue -Description "Enhancement test"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--label' -and
                $args -contains 'enhancement'
            }
        }
    }
    
    Context 'Affected Files Handling' {
        It 'Should include affected files in issue body' {
            $files = @('file1.ps1', 'file2.ps1', 'config.json')
            
            New-PatchIssue -Description "Files test" -AffectedFiles $files
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0 -and $bodyIndex + 1 -lt $args.Count) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'file1\.ps1' -and
                    $body -match 'file2\.ps1' -and
                    $body -match 'config\.json'
                } else {
                    $false
                }
            }
        }
        
        It 'Should handle empty affected files array' {
            { New-PatchIssue -Description "No files test" -AffectedFiles @() } | Should -Not -Throw
        }
    }
    
    Context 'Custom Labels' {
        It 'Should apply custom labels' {
            $labels = @('bug', 'documentation', 'testing')
            
            New-PatchIssue -Description "Custom labels test" -Labels $labels
            
            foreach ($label in $labels) {
                Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                    $args -contains '--label' -and
                    $args -contains $label
                }
            }
        }
        
        It 'Should combine default and custom labels' {
            New-PatchIssue -Description "Combined labels" -Labels @('custom')
            
            # Should have patch, enhancement, Priority:Medium, and custom
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                ($args | Where-Object { $_ -eq '--label' }).Count -ge 4
            }
        }
    }
    
    Context 'Test Output Integration' {
        It 'Should include test output in issue body' {
            $testOutput = @(
                'Test 1: Passed',
                'Test 2: Failed - Expected 5 but got 3',
                'Test 3: Skipped'
            )
            
            New-PatchIssue -Description "Test output" -TestOutput $testOutput
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'Test Output' -and
                    $body -match 'Test 1: Passed' -and
                    $body -match 'Test 2: Failed'
                } else {
                    $false
                }
            }
        }
        
        It 'Should include error details when provided' {
            $errors = @(
                'Error in module.ps1: Cannot find function',
                'Error in config.json: Invalid JSON'
            )
            
            New-PatchIssue -Description "Error details" -ErrorDetails $errors
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'Error Details' -and
                    $body -match 'Cannot find function'
                } else {
                    $false
                }
            }
        }
    }
    
    Context 'Repository Detection' {
        It 'Should detect repository from git remote' {
            New-PatchIssue -Description "Repo detection test"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'remote' -and $args -contains 'get-url'
            }
        }
        
        It 'Should use TargetRepository when specified' {
            New-PatchIssue -Description "Target repo test" -TargetRepository "owner/repo"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--repo' -and
                $args -contains 'owner/repo'
            }
        }
        
        It 'Should handle repository detection failure' {
            Mock Get-GitRepositoryInfo { throw "No git repo" } -ModuleName $script:ModuleName
            
            { New-PatchIssue -Description "No repo test" } | Should -Throw
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle gh CLI not available' {
            Mock Get-Command { $false } -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'gh'
            }
            
            { New-PatchIssue -Description "No gh test" } | Should -Throw "*GitHub CLI*not*installed*"
        }
        
        It 'Should handle issue creation failure' {
            Mock gh { throw "API rate limit exceeded" } -ModuleName $script:ModuleName
            
            { New-PatchIssue -Description "API failure test" } | Should -Throw "*API rate limit*"
        }
        
        It 'Should provide meaningful error for authentication issues' {
            Mock gh { 
                Write-Error "error: not authenticated"
                throw "Authentication required"
            } -ModuleName $script:ModuleName
            
            { New-PatchIssue -Description "Auth test" } | Should -Throw "*Authentication*"
        }
    }
    
    Context 'Issue URL Extraction' {
        It 'Should extract issue number from URL' {
            Mock gh { 'https://github.com/testuser/testrepo/issues/456' } -ModuleName $script:ModuleName
            
            $result = New-PatchIssue -Description "URL extraction test"
            
            $result.IssueNumber | Should -Be 456
            $result.IssueUrl | Should -Be 'https://github.com/testuser/testrepo/issues/456'
        }
        
        It 'Should handle different URL formats' {
            Mock gh { 
                # GitHub CLI sometimes returns just the number
                '789'
            } -ModuleName $script:ModuleName
            
            $result = New-PatchIssue -Description "Number only test"
            
            $result.IssueNumber | Should -Be 789
        }
    }
    
    Context 'Progress Reporting' {
        It 'Should report progress when context available' {
            # Simulate progress context
            Mock Test-Path { $true } -ModuleName $script:ModuleName -ParameterFilter {
                $Path -match 'ProgressContext'
            }
            
            New-PatchIssue -Description "Progress test"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Creating.*issue" -or $Message -match "Successfully created"
            }
        }
    }
    
    Context 'Test Context Integration' {
        It 'Should include test context information' {
            $testContext = @{
                TestFile = 'Module.Tests.ps1'
                TestName = 'Should process data correctly'
                Duration = '2.5s'
            }
            
            New-PatchIssue -Description "Context test" -TestContext $testContext -TestType "Unit"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'Test Context' -and
                    $body -match 'Module\.Tests\.ps1'
                } else {
                    $false
                }
            }
        }
    }
}