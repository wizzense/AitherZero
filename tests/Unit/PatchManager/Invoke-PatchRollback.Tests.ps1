#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'Invoke-PatchRollback'
}

Describe 'PatchManager.Invoke-PatchRollback' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Import-Module { } -ModuleName $script:ModuleName
        Mock Test-Path { $true } -ModuleName $script:ModuleName
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        
        # Mock git operations
        Mock git {
            if ($args -contains 'status') {
                return ''  # Clean working tree
            }
            if ($args -contains 'log' -and $args -contains '--oneline') {
                return @(
                    'abc123 Latest commit',
                    'def456 Previous commit',
                    'ghi789 Even older commit'
                )
            }
            if ($args -contains 'reset') {
                $script:LASTEXITCODE = 0
                return 'HEAD is now at def456 Previous commit'
            }
            if ($args -contains 'checkout') {
                $script:LASTEXITCODE = 0
                return 'Switched to branch main'
            }
            if ($args -contains 'branch' -and $args -contains '--show-current') {
                return 'patch/test-branch'
            }
            if ($args -contains 'stash') {
                $script:LASTEXITCODE = 0
                return 'Saved working directory'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock progress tracking functions
        Mock Start-PatchProgress { return 100 } -ModuleName $script:ModuleName
        Mock Update-PatchProgress { } -ModuleName $script:ModuleName
        Mock Complete-PatchProgress { } -ModuleName $script:ModuleName
        
        # Mock backup functions
        Mock New-PatchBackup {
            @{
                Success = $true
                BackupPath = '/path/to/backup'
                BackupId = 'backup-123'
            }
        } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'PatchManagerRollbackTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should use LastCommit as default RollbackType' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Starting patch rollback: LastCommit"
            }
        }
        
        It 'Should validate RollbackType parameter values' {
            { Invoke-PatchRollback -RollbackType "Invalid" } | Should -Throw
        }
        
        It 'Should accept valid RollbackType values' {
            $validTypes = @('LastCommit', 'PreviousBranch', 'SpecificCommit')
            
            foreach ($type in $validTypes) {
                if ($type -eq 'SpecificCommit') {
                    { Invoke-PatchRollback -RollbackType $type -CommitHash "abc123" -Force -DryRun } | Should -Not -Throw
                } else {
                    { Invoke-PatchRollback -RollbackType $type -Force -DryRun } | Should -Not -Throw
                }
            }
        }
        
        It 'Should require CommitHash for SpecificCommit type' {
            { Invoke-PatchRollback -RollbackType "SpecificCommit" } | Should -Throw "*CommitHash*required*"
        }
        
        It 'Should accept CommitHash with SpecificCommit type' {
            { Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123" -Force -DryRun } | Should -Not -Throw
        }
    }
    
    Context 'Dependencies and Initialization' {
        It 'Should import Logging module' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $Name -match "Logging"
            }
        }
        
        It 'Should check for progress tracking functions' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Test-Path -ModuleName $script:ModuleName -ParameterFilter {
                $Path -match "Initialize-ProgressTracking"
            }
        }
        
        It 'Should log rollback start' {
            Invoke-PatchRollback -RollbackType "PreviousBranch" -Force -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Starting patch rollback: PreviousBranch" -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Progress Tracking' {
        It 'Should start progress tracking when available' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Start-PatchProgress -ModuleName $script:ModuleName -ParameterFilter {
                $OperationName -match "Rollback: LastCommit"
            }
        }
        
        It 'Should calculate correct steps with backup' {
            Invoke-PatchRollback -CreateBackup -Force -DryRun
            
            Should -Invoke Start-PatchProgress -ModuleName $script:ModuleName -ParameterFilter {
                $TotalSteps -eq 4  # 3 base steps + 1 for backup
            }
        }
        
        It 'Should calculate correct steps without backup' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Start-PatchProgress -ModuleName $script:ModuleName -ParameterFilter {
                $TotalSteps -eq 3  # Base steps only
            }
        }
    }
    
    Context 'Working Tree Validation' {
        It 'Should check working tree status' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'status' -and
                $args -contains '--porcelain'
            }
        }
        
        It 'Should handle dirty working tree' {
            Mock git {
                if ($args -contains 'status' -and $args -contains '--porcelain') {
                    return 'M file1.ps1'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Working tree has uncommitted changes" -and
                $Level -eq 'WARN'
            }
        }
        
        It 'Should stash changes when working tree is dirty' {
            Mock git {
                if ($args -contains 'status' -and $args -contains '--porcelain') {
                    return 'M file1.ps1'
                }
                if ($args -contains 'stash') {
                    $script:LASTEXITCODE = 0
                    return 'Saved working directory'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchRollback -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'stash' -and
                $args -contains 'save'
            }
        }
    }
    
    Context 'Backup Creation' {
        It 'Should create backup when CreateBackup switch is used' {
            Invoke-PatchRollback -CreateBackup -Force -DryRun
            
            Should -Invoke New-PatchBackup -ModuleName $script:ModuleName -ParameterFilter {
                $BackupType -eq 'Rollback'
            }
        }
        
        It 'Should not create backup by default' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke New-PatchBackup -ModuleName $script:ModuleName -Times 0
        }
        
        It 'Should handle backup failure gracefully' {
            Mock New-PatchBackup { 
                @{ Success = $false; Error = 'Backup failed' }
            } -ModuleName $script:ModuleName
            
            Invoke-PatchRollback -CreateBackup -Force -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Backup creation failed" -and
                $Level -eq 'WARN'
            }
        }
    }
    
    Context 'LastCommit Rollback' {
        It 'Should perform git reset for LastCommit rollback' {
            Invoke-PatchRollback -RollbackType "LastCommit" -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'reset' -and
                $args -contains '--hard' -and
                $args -contains 'HEAD~1'
            }
        }
        
        It 'Should log LastCommit rollback operation' {
            Invoke-PatchRollback -RollbackType "LastCommit" -Force -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Rolling back to previous commit" -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'PreviousBranch Rollback' {
        It 'Should checkout previous branch for PreviousBranch rollback' {
            Mock git {
                if ($args -contains 'checkout') {
                    $script:LASTEXITCODE = 0
                    return 'Switched to branch main'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchRollback -RollbackType "PreviousBranch" -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'checkout' -and
                $args -contains '-'
            }
        }
        
        It 'Should log PreviousBranch rollback operation' {
            Invoke-PatchRollback -RollbackType "PreviousBranch" -Force -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Switching to previous branch" -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'SpecificCommit Rollback' {
        It 'Should reset to specific commit hash' {
            Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123def" -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'reset' -and
                $args -contains '--hard' -and
                $args -contains 'abc123def'
            }
        }
        
        It 'Should validate commit hash exists' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains '--verify') {
                    $script:LASTEXITCODE = 0
                    return 'abc123def456'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123def" -Force -DryRun
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'rev-parse' -and
                $args -contains '--verify' -and
                $args -contains 'abc123def^{commit}'
            }
        }
        
        It 'Should handle invalid commit hash' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains '--verify') {
                    $script:LASTEXITCODE = 1
                    throw "fatal: bad revision"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "invalid" -Force } | Should -Throw "*Invalid commit hash*"
        }
    }
    
    Context 'Dry Run Mode' {
        It 'Should not perform actual git operations in dry run' {
            Invoke-PatchRollback -RollbackType "LastCommit" -DryRun
            
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'reset' -and $args -contains '--hard'
            }
        }
        
        It 'Should log dry run information' {
            Invoke-PatchRollback -RollbackType "LastCommit" -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "DRY RUN" -and $Level -eq 'WARN'
            }
        }
        
        It 'Should show what would be done in dry run' {
            Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123" -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Would reset to commit: abc123" -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle git reset failure' {
            Mock git {
                if ($args -contains 'reset') {
                    $script:LASTEXITCODE = 1
                    throw "fatal: Could not reset"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchRollback -RollbackType "LastCommit" -Force } | Should -Throw "*Could not reset*"
        }
        
        It 'Should handle git checkout failure' {
            Mock git {
                if ($args -contains 'checkout') {
                    $script:LASTEXITCODE = 1
                    throw "error: pathspec did not match"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchRollback -RollbackType "PreviousBranch" -Force } | Should -Throw "*pathspec*"
        }
        
        It 'Should log errors appropriately' {
            Mock git {
                if ($args -contains 'reset') {
                    throw "Reset failed"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            try {
                Invoke-PatchRollback -RollbackType "LastCommit" -Force
            } catch {
                # Expected to throw
            }
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Rollback operation failed" -and
                $Level -eq 'ERROR'
            }
        }
    }
    
    Context 'Confirmation Prompts' {
        It 'Should skip confirmation when Force is used' {
            # Force should bypass confirmation
            { Invoke-PatchRollback -RollbackType "LastCommit" -Force -DryRun } | Should -Not -Throw
        }
        
        It 'Should use ShouldProcess for confirmation' {
            # Test with WhatIf
            $result = Invoke-PatchRollback -RollbackType "LastCommit" -WhatIf
            
            # WhatIf should prevent actual execution
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'reset'
            }
        }
    }
    
    Context 'Progress Completion' {
        It 'Should complete progress tracking on success' {
            Invoke-PatchRollback -Force -DryRun
            
            Should -Invoke Complete-PatchProgress -ModuleName $script:ModuleName
        }
        
        It 'Should complete progress tracking on failure' {
            Mock git { throw "Rollback failed" } -ModuleName $script:ModuleName
            
            try {
                Invoke-PatchRollback -Force
            } catch {
                # Expected to throw
            }
            
            Should -Invoke Complete-PatchProgress -ModuleName $script:ModuleName
        }
    }
}