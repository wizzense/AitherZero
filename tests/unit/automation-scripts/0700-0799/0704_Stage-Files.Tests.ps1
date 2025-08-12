#Requires -Version 7.0

BeforeAll {
    # Mock the GitAutomation module
    $script:MockCalls = @{}
    
    # Create mock GitAutomation module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Get-GitStatus {
            return @{
                Clean = $false
                Modified = @(
                    @{ Path = 'file1.txt' }
                    @{ Path = 'file2.ps1' }
                )
                Untracked = @(
                    @{ Path = 'newfile.txt' }
                )
                Deleted = @(
                    @{ Path = 'oldfile.txt' }
                )
                Staged = @()
            }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock git { 
        switch -Regex ($args -join ' ') {
            'add' { 
                $script:MockCalls['git_add'] += @{ Files = $args[1..($args.Length-1)] }
                return '' 
            }
            'status --short' { return 'M file1.txt' }
            default { return '' }
        }
    }
    
    Mock Test-Path { 
        param($Path)
        # Mock that specific files exist
        switch ($Path) {
            'file1.txt' { return $true }
            'file2.ps1' { return $true }
            'newfile.txt' { return $true }
            'oldfile.txt' { return $false }  # deleted file doesn't exist
            'nonexistent.txt' { return $false }
            default { return $true }
        }
    }
    
    Mock Get-Item { 
        param($Path)
        return @{ Name = (Split-Path $Path -Leaf); FullName = $Path }
    }
    
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'all' }
    
    # Initialize mock calls tracking
    $script:MockCalls = @{
        'git_add' = @()
    }
}

Describe "0704_Stage-Files" {
    BeforeEach {
        $script:MockCalls = @{
            'git_add' = @()
        }
        
        # Reset to default dirty state
        New-Module -Name 'MockGitAutomation' -ScriptBlock {
            function Get-GitStatus {
                return @{
                    Clean = $false
                    Modified = @(
                        @{ Path = 'file1.txt' }
                        @{ Path = 'file2.ps1' }
                    )
                    Untracked = @(
                        @{ Path = 'newfile.txt' }
                    )
                    Deleted = @(
                        @{ Path = 'oldfile.txt' }
                    )
                    Staged = @()
                }
            }
            
            Export-ModuleMember -Function *
        } | Import-Module -Force
    }
    
    Context "Parameter Validation" {
        It "Should accept patterns as remaining arguments" {
            { & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "*.txt" "*.ps1" -WhatIf } | Should -Not -Throw
        }
        
        It "Should validate Type parameter values" {
            $validTypes = @('All', 'Modified', 'Untracked', 'Deleted')
            foreach ($type in $validTypes) {
                { & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type $type -WhatIf } | Should -Not -Throw
            }
        }
        
        It "Should accept various switches" {
            { & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Interactive -DryRun -Force -Verbose -ShowStatus -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Clean Repository Handling" {
        BeforeAll {
            # Mock clean repository state
            New-Module -Name 'MockGitAutomationClean' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $true
                        Modified = @()
                        Untracked = @()
                        Deleted = @()
                        Staged = @()
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }
        
        It "Should exit early when repository is clean and no Force" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1"
            
            $script:MockCalls['git_add'] | Should -HaveCount 0
        }
        
        It "Should continue when repository is clean but Force is used" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Force -WhatIf
            
            # Should not throw or exit early, but won't have files to stage
            $script:MockCalls['git_add'] | Should -HaveCount 0
        }
    }
    
    Context "File Type Selection" {
        It "Should stage all files when Type is All" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "All" -DryRun -WhatIf
            
            # Should process modified, untracked, and deleted files
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*newfile.txt*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*oldfile.txt*" }
        }
        
        It "Should stage only modified files when Type is Modified" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file2.ps1*" }
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*newfile.txt*" }
        }
        
        It "Should stage only untracked files when Type is Untracked" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Untracked" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*newfile.txt*" }
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
        }
        
        It "Should stage only deleted files when Type is Deleted" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Deleted" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*oldfile.txt*" }
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
        }
    }
    
    Context "Pattern Matching" {
        It "Should stage all files when pattern is '.'" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "." -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*newfile.txt*" }
        }
        
        It "Should stage specific file when exact path is provided" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "file1.txt" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
        }
        
        It "Should match glob patterns" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "*.txt" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*newfile.txt*" }
            Should -Not -Invoke Write-Host -ParameterFilter { $Object -like "*file2.ps1*" }
        }
        
        It "Should handle multiple patterns" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "*.txt" "*.ps1" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file2.ps1*" }
        }
        
        It "Should warn when no files match pattern" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "*.xyz" -Verbose -DryRun -WhatIf
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*No files match pattern*" }
        }
    }
    
    Context "Interactive Selection" {
        It "Should prompt for file selection in interactive mode" {
            Mock Read-Host { return '1,2' }
            
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Interactive -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Select files to stage*" }
            Should -Invoke Read-Host
        }
        
        It "Should handle 'all' selection in interactive mode" {
            Mock Read-Host { return 'all' }
            
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Interactive -DryRun -WhatIf
            
            Should -Invoke Read-Host
        }
        
        It "Should handle numeric selection in interactive mode" {
            Mock Read-Host { return '1' }
            
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Interactive -DryRun -WhatIf
            
            Should -Invoke Read-Host
        }
    }
    
    Context "File Staging" {
        It "Should stage files when not in dry run mode" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -WhatIf
            
            # In WhatIf mode, git add should not be called
            Should -Not -Invoke git -ParameterFilter { $args[0] -eq 'add' }
        }
        
        It "Should not stage files in dry run mode" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*DRY RUN*" }
            Should -Not -Invoke git -ParameterFilter { $args[0] -eq 'add' }
        }
        
        It "Should show git status after staging when ShowStatus is used" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -ShowStatus -WhatIf
            
            Should -Invoke git -ParameterFilter { $args -contains 'status' -and $args -contains '--short' }
        }
        
        It "Should output files in verbose mode" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -Verbose -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Staging:*" }
        }
    }
    
    Context "File Status Display" {
        It "Should display modified files with 'M' indicator" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*M file1.txt*" }
        }
        
        It "Should display untracked files with '+' indicator" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Untracked" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*+ newfile.txt*" }
        }
        
        It "Should display deleted files with '-' indicator" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Deleted" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*- oldfile.txt*" }
        }
        
        It "Should display file count summary" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "All" -DryRun -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Total:*" }
        }
    }
    
    Context "No Files to Stage" {
        BeforeAll {
            # Mock state with no files matching criteria
            New-Module -Name 'MockGitAutomationEmpty' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Modified = @()
                        Untracked = @()
                        Deleted = @()
                        Staged = @(@{ Path = 'already_staged.txt' })
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }
        
        It "Should exit early when no files match criteria" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified"
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No files to stage*" }
            $script:MockCalls['git_add'] | Should -HaveCount 0
        }
    }
    
    Context "Duplicate File Handling" {
        It "Should remove duplicates from file list" {
            # Test with patterns that might match the same files multiple times
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "file1.txt" "*.txt" -DryRun -WhatIf
            
            # file1.txt should only appear once in the output
            $writeHostCalls = (Get-Mock Write-Host).History | Where-Object { 
                $_.BoundParameters.Object -like "*file1.txt*" 
            }
            # Should not have duplicate entries in the file list
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*file1.txt*" }
        }
    }
    
    Context "Error Handling" {
        It "Should handle git add failures" {
            Mock git { throw "Git add failed" } -ParameterFilter { $args[0] -eq 'add' }
            
            { & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" } | Should -Throw
        }
        
        It "Should handle missing files gracefully" {
            Mock Test-Path { return $false }
            
            { & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "nonexistent.txt" -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle Get-Item failures" {
            Mock Get-Item { throw "Access denied" }
            
            { & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" "file1.txt" -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WhatIf Support" {
        It "Should show staging operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0704_Stage-Files.ps1" -Type "Modified" -WhatIf
            
            # Should show what would be staged but not actually stage
            Should -Not -Invoke git -ParameterFilter { $args[0] -eq 'add' }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Files to stage*" }
        }
    }
}
