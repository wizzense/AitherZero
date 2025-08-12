#Requires -Version 7.0

BeforeAll {
    # Mock the GitAutomation module
    $script:MockCalls = @{}
    
    # Create mock GitAutomation module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Get-GitStatus {
            return @{
                Clean = $true
                Branch = 'feature/test-branch'
                Modified = @()
                Untracked = @()
            }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock git { 
        switch -Regex ($arguments -join ' ') {
            'branch -r' { 
                return @('  origin/main', '  origin/develop')
            }
            'push.*--dry-run' { 
                return 'To https://github.com/test/repo.git'
            }
            'push' { 
                $output = @(
                    'Enumerating objects: 5, done.',
                    'To https://github.com/test/repo.git',
                    '   abc123..def456  feature/test-branch -> feature/test-branch'
                )
                $script:MockCalls['git_push'] += @{ Args = $arguments }
                return $output
            }
            'rev-parse HEAD' { return 'abc123456' }
            'rev-parse origin/.*' { return 'abc123456' }
            'tag --contains HEAD' { return '' }
            default { return '' }
        }
    }
    
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'y' }
    
    # Initialize mock calls tracking
    $script:MockCalls = @{
        'git_push' = @()
    }
}

Describe "0705_Push-Branch" {
    BeforeEach {
        $script:MockCalls = @{
            'git_push' = @()
        }
        
        # Reset to default clean state
        New-Module -Name 'MockGitAutomation' -ScriptBlock {
            function Get-GitStatus {
                return @{
                    Clean = $true
                    Branch = 'feature/test-branch'
                    Modified = @()
                    Untracked = @()
                }
            }
            
            Export-ModuleMember -Function *
        } | Import-Module -Force
    }
    
    Context "Parameter Validation" {
        It "Should accept Branch parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Branch "feature/custom" -DryRun } | Should -Not -Throw
        }
        
        It "Should accept Remote parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Remote "upstream" -DryRun } | Should -Not -Throw
        }
        
        It "Should accept various switches" {
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -SetUpstream -Force -ForceWithLease -Tags -All -DryRun -Verbose -NonInteractive } | Should -Not -Throw
        }
        
        It "Should default Remote to 'origin'" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Remote: origin*" }
        }
    }
    
    Context "Branch Detection" {
        It "Should use current branch when no Branch parameter provided" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Branch: feature/test-branch*" }
        }
        
        It "Should use specified branch when Branch parameter provided" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Branch "develop" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Branch: develop*" }
        }
        
        It "Should handle missing current branch" {
            New-Module -Name 'MockGitAutomationNoBranch' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $true
                        Branch = $null
                        Modified = @()
                        Untracked = @()
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
            
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun } | Should -Throw -ExpectedMessage "*Could not determine current branch*"
        }
    }
    
    Context "Remote Branch Detection" {
        It "Should detect when branch doesn't exist on remote" {
            Mock git { return @() } -ParameterFilter { $arguments -contains '-r' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Will set upstream tracking*" }
        }
        
        It "Should detect when branch exists on remote" {
            Mock git { return @('  origin/feature/test-branch') } -ParameterFilter { $arguments -contains '-r' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*Will set upstream tracking*" }
        }
        
        It "Should set upstream when SetUpstream switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -SetUpstream -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Will set upstream tracking*" }
        }
    }
    
    Context "Uncommitted Changes Handling" {
        BeforeAll {
            # Mock dirty repository state
            New-Module -Name 'MockGitAutomationDirty' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Branch = 'feature/test-branch'
                        Modified = @(@{ Path = 'file1.txt' })
                        Untracked = @(@{ Path = 'file2.txt' })
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }
        
        It "Should warn about uncommitted changes in interactive mode" {
            Mock Read-Host { return 'n' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*uncommitted changes*" }
            Should -Invoke Read-Host
        }
        
        It "Should proceed with Force when repository is dirty" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Force -DryRun -WhatIf
            
            $script:MockCalls['git_push'] | Should -HaveCount 1
        }
        
        It "Should proceed with NonInteractive when repository is dirty" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -NonInteractive -DryRun -WhatIf
            
            $script:MockCalls['git_push'] | Should -HaveCount 1
        }
    }
    
    Context "Push Command Building" {
        It "Should include --set-upstream when needed" {
            Mock git { return @() } -ParameterFilter { $arguments -contains '-r' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--set-upstream' 
            }
        }
        
        It "Should include --force when Force switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Force -DryRun -WhatIf
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*force push*" }
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--force' 
            }
        }
        
        It "Should include --force-with-lease when ForceWithLease switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -ForceWithLease -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*force-with-lease*" }
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--force-with-lease' 
            }
        }
        
        It "Should include --tags when Tags switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Tags -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Including tags*" }
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--tags' 
            }
        }
        
        It "Should include --all when All switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -All -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Pushing all branches*" }
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--all' 
            }
        }
        
        It "Should include --verbose when Verbose switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -Verbose -DryRun -WhatIf
            
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--verbose' 
            }
        }
        
        It "Should include --dry-run when DryRun switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*DRY RUN MODE*" }
            Should -Invoke git -ParameterFilter { 
                $arguments -contains 'push' -and $arguments -contains '--dry-run' 
            }
        }
    }
    
    Context "Push Execution" {
        It "Should execute git push with correct arguments" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            $script:MockCalls['git_push'] | Should -HaveCount 1
            $pushCall = $script:MockCalls['git_push'] | Select-Object -First 1
            $pushCall.Args | Should -Contain 'push'
            $pushCall.Args | Should -Contain 'origin'
        }
        
        It "Should not include branch name when All switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -All -DryRun -WhatIf
            
            $pushCall = $script:MockCalls['git_push'] | Select-Object -First 1
            $pushCall.Args | Should -Not -Contain 'feature/test-branch'
        }
        
        It "Should include branch name when not using All switch" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            $pushCall = $script:MockCalls['git_push'] | Select-Object -First 1
            $pushCall.Args | Should -Contain 'feature/test-branch'
        }
        
        It "Should display command being executed" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Executing: git push*" }
        }
    }
    
    Context "Push Output Parsing" {
        It "Should detect 'Everything up-to-date' message" {
            Mock git { return 'Everything up-to-date' } -ParameterFilter { $arguments[0] -eq 'push' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Already up-to-date*" }
        }
        
        It "Should detect new branch creation" {
            Mock git { return ' * [new branch]      feature/test -> feature/test' } -ParameterFilter { $arguments[0] -eq 'push' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Created new branch on remote*" }
        }
        
        It "Should detect rejected pushes" {
            Mock git { return 'rejected' } -ParameterFilter { $arguments[0] -eq 'push' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Warning
        }
    }
    
    Context "Success Handling" {
        It "Should show success message after push" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully pushed*" }
        }
        
        It "Should show upstream tracking message when setting upstream" {
            Mock git { return @() } -ParameterFilter { $arguments -contains '-r' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*set up to track*" }
        }
        
        It "Should show commit sync status" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Local and remote are in sync*" }
        }
    }
    
    Context "Next Steps Suggestions" {
        It "Should suggest creating PR for feature branches" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Create a pull request*" }
        }
        
        It "Should not suggest PR for main branch" {
            New-Module -Name 'MockGitAutomationMain' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $true
                        Branch = 'main'
                        Modified = @()
                        Untracked = @()
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*Create a pull request*" }
        }
        
        It "Should suggest pushing tags when unpushed tags exist" {
            Mock git { return 'v1.0.0' } -ParameterFilter { $arguments -contains 'tag' -and $arguments -contains '--contains' }
            
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Push tags*" }
        }
    }
    
    Context "Error Handling" {
        It "Should handle push failures with helpful messages" {
            Mock git { throw "failed to push" } -ParameterFilter { $arguments[0] -eq 'push' }
            
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" } | Should -Throw
            Should -Invoke Write-Error -ParameterFilter { $Message -like "*Push failed*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Try:*" }
        }
        
        It "Should handle authentication failures" {
            Mock git { throw "Permission denied" } -ParameterFilter { $arguments[0] -eq 'push' }
            
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" } | Should -Throw
            Should -Invoke Write-Error -ParameterFilter { $Message -like "*Authentication failed*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*gh auth login*" }
        }
        
        It "Should suggest force-with-lease for failed pushes" {
            Mock git { throw "failed to push" } -ParameterFilter { $arguments[0] -eq 'push' }
            
            { & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" } | Should -Throw
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*ForceWithLease*" }
        }
    }
    
    Context "DryRun Mode" {
        It "Should not show next steps in dry run mode" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            # Should not show "Next steps:" section in dry run
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*Next steps:*" }
        }
        
        It "Should show dry run indicator" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*DRY RUN MODE*" }
        }
    }
    
    Context "WhatIf Support" {
        It "Should show push operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0705_Push-Branch.ps1" -WhatIf
            
            # Should execute git push with dry-run for validation
            $script:MockCalls['git_push'] | Should -HaveCount 1
        }
    }
}
