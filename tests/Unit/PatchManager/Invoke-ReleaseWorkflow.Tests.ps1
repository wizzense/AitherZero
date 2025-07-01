#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'Invoke-ReleaseWorkflow'
}

Describe 'PatchManager.Invoke-ReleaseWorkflow' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Write-Host { } -ModuleName $script:ModuleName
        Mock Test-Path { $true } -ModuleName $script:ModuleName
        Mock Get-Content { '1.2.3' } -ModuleName $script:ModuleName
        Mock Set-Content { } -ModuleName $script:ModuleName
        
        # Mock Find-ProjectRoot
        Mock Find-ProjectRoot { '/test/project/root' } -ModuleName $script:ModuleName
        
        # Mock git operations
        Mock git {
            if ($args -contains 'status' -and $args -contains '--porcelain') {
                return ''  # Clean working tree
            }
            if ($args -contains 'branch' -and $args -contains '--show-current') {
                return 'main'
            }
            if ($args -contains 'add') {
                $script:LASTEXITCODE = 0
                return ''
            }
            if ($args -contains 'commit') {
                $script:LASTEXITCODE = 0
                return 'Version updated'
            }
            if ($args -contains 'push') {
                $script:LASTEXITCODE = 0
                return 'Pushed to origin'
            }
            if ($args -contains 'tag') {
                $script:LASTEXITCODE = 0
                return 'Tag created'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock PatchManager functions
        Mock Invoke-PatchWorkflow {
            @{
                Success = $true
                BranchName = 'release/v1.2.4'
                CommitCreated = $true
                PRCreated = $true
                PRNumber = 123
                PRUrl = 'https://github.com/test/repo/pull/123'
            }
        } -ModuleName $script:ModuleName
        
        # Mock GitHub CLI
        Mock gh {
            if ($args -contains 'pr' -and $args -contains 'view') {
                return 'merged'
            }
            if ($args -contains 'pr' -and $args -contains 'merge') {
                return 'Pull request merged'
            }
            if ($args -contains 'run' -and $args -contains 'list') {
                return '✓ CI/CD completed_successfully'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'ReleaseWorkflowTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require either ReleaseType or Version' {
            { Invoke-ReleaseWorkflow -Description "Test release" } | Should -Throw
        }
        
        It 'Should require Description parameter' {
            { Invoke-ReleaseWorkflow -ReleaseType "patch" } | Should -Throw
        }
        
        It 'Should validate ReleaseType values' {
            { Invoke-ReleaseWorkflow -ReleaseType "invalid" -Description "Test" } | Should -Throw
        }
        
        It 'Should accept valid ReleaseType values' {
            $validTypes = @('patch', 'minor', 'major')
            
            foreach ($type in $validTypes) {
                { Invoke-ReleaseWorkflow -ReleaseType $type -Description "Test" -DryRun } | Should -Not -Throw
            }
        }
        
        It 'Should validate Version format' {
            { Invoke-ReleaseWorkflow -Version "invalid" -Description "Test" } | Should -Throw
        }
        
        It 'Should accept valid Version format' {
            { Invoke-ReleaseWorkflow -Version "2.1.0" -Description "Test" -DryRun } | Should -Not -Throw
        }
    }
    
    Context 'Project Root Detection' {
        It 'Should find project root' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Test" -DryRun
            
            Should -Invoke Find-ProjectRoot -ModuleName $script:ModuleName -ParameterFilter {
                $StartPath -ne $null
            }
        }
        
        It 'Should throw error if project root not found' {
            Mock Find-ProjectRoot { $null } -ModuleName $script:ModuleName
            
            { Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Test" } | Should -Throw "*Could not find project root*"
        }
    }
    
    Context 'Version File Handling' {
        It 'Should read current version from VERSION file' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Test" -DryRun
            
            Should -Invoke Test-Path -ModuleName $script:ModuleName -ParameterFilter {
                $Path -match 'VERSION$'
            }
            
            Should -Invoke Get-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Path -match 'VERSION$'
            }
        }
        
        It 'Should throw error if VERSION file not found' {
            Mock Test-Path { $false } -ModuleName $script:ModuleName -ParameterFilter {
                $Path -match 'VERSION$'
            }
            
            { Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Test" } | Should -Throw "*VERSION file not found*"
        }
        
        It 'Should calculate patch version correctly' {
            Mock Get-Content { '1.2.3' } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Patch release" -DryRun
            
            $result.NewVersion | Should -Be '1.2.4'
        }
        
        It 'Should calculate minor version correctly' {
            Mock Get-Content { '1.2.3' } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "Minor release" -DryRun
            
            $result.NewVersion | Should -Be '1.3.0'
        }
        
        It 'Should calculate major version correctly' {
            Mock Get-Content { '1.2.3' } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "major" -Description "Major release" -DryRun
            
            $result.NewVersion | Should -Be '2.0.0'
        }
        
        It 'Should use specified version when provided' {
            $result = Invoke-ReleaseWorkflow -Version "3.0.0" -Description "Specific version" -DryRun
            
            $result.NewVersion | Should -Be '3.0.0'
        }
    }
    
    Context 'Dry Run Mode' {
        It 'Should not make actual changes in dry run mode' {
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Dry run test" -DryRun
            
            Should -Invoke Set-Content -ModuleName $script:ModuleName -Times 0
            Should -Invoke Invoke-PatchWorkflow -ModuleName $script:ModuleName -Times 0
            
            $result.DryRun | Should -Be $true
        }
        
        It 'Should log what would be done in dry run' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Dry run logging" -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "DRY RUN" -and $Level -eq 'WARN'
            }
        }
    }
    
    Context 'Release Process Execution' {
        It 'Should update VERSION file' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Update version test"
            
            Should -Invoke Set-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Path -match 'VERSION$' -and $Value -eq '1.2.4'
            }
        }
        
        It 'Should create release PR using PatchManager' {
            Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "Create PR test"
            
            Should -Invoke Invoke-PatchWorkflow -ModuleName $script:ModuleName -ParameterFilter {
                $PatchDescription -match "Release v1.3.0" -and
                $CreatePR -eq $true
            }
        }
        
        It 'Should wait for PR merge when WaitForMerge is true' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Wait for merge test" -WaitForMerge:$true
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'pr' -and $args -contains 'view'
            }
        }
        
        It 'Should not wait for PR merge when WaitForMerge is false' {
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "No wait test" -WaitForMerge:$false
            
            $result.TagCreated | Should -Be $false
            $result.WaitSkipped | Should -Be $true
        }
    }
    
    Context 'Auto Merge Handling' {
        It 'Should attempt auto-merge when AutoMerge is specified' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Auto merge test" -AutoMerge
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'pr' -and $args -contains 'merge'
            }
        }
        
        It 'Should not attempt auto-merge by default' {
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "No auto merge test"
            
            Should -Invoke gh -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'pr' -and $args -contains 'merge'
            }
        }
        
        It 'Should handle auto-merge failure gracefully' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'merge') {
                    throw "Auto-merge failed"
                }
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'open'  # Still open after failed merge
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Failed auto merge" -AutoMerge
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Auto-merge failed" -and $Level -eq 'WARN'
            }
            
            $result.AutoMergeFailed | Should -Be $true
        }
    }
    
    Context 'Tag Creation' {
        It 'Should create and push release tag after PR merge' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'merged'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Tag creation test"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'tag' -and $args -contains '-a' -and $args -contains 'v1.2.4'
            }
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'push' -and $args -contains 'origin' -and $args -contains 'v1.2.4'
            }
        }
        
        It 'Should not create tag if PR is not merged' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'open'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "No tag test" -MaxWaitMinutes 1
            
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'tag'
            }
            
            $result.TagCreated | Should -Be $false
            $result.PRMergeTimeout | Should -Be $true
        }
    }
    
    Context 'Pipeline Monitoring' {
        It 'Should monitor build pipeline after tag creation' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'merged'
                }
                if ($args -contains 'run' -and $args -contains 'list') {
                    return '✓ Build & Release Pipeline completed_successfully'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Pipeline monitoring test"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'run' -and $args -contains 'list'
            }
            
            $result.PipelineMonitored | Should -Be $true
        }
        
        It 'Should handle pipeline monitoring failure' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'merged'
                }
                if ($args -contains 'run' -and $args -contains 'list') {
                    throw "Pipeline monitoring failed"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Pipeline failure test"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Pipeline monitoring failed" -and $Level -eq 'WARN'
            }
            
            $result.PipelineMonitoringFailed | Should -Be $true
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle VERSION file update failure' {
            Mock Set-Content { throw "File write error" } -ModuleName $script:ModuleName
            
            { Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "File error test" } | Should -Throw "*File write error*"
        }
        
        It 'Should handle PatchWorkflow failure' {
            Mock Invoke-PatchWorkflow { 
                @{ Success = $false; Error = "PR creation failed" }
            } -ModuleName $script:ModuleName
            
            { Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Patch workflow error" } | Should -Throw "*PR creation failed*"
        }
        
        It 'Should handle git tag creation failure' {
            Mock git {
                if ($args -contains 'tag') {
                    $script:LASTEXITCODE = 1
                    throw "Tag creation failed"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'merged'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Tag error test" } | Should -Throw "*Tag creation failed*"
        }
    }
    
    Context 'Timeout Handling' {
        It 'Should respect MaxWaitMinutes parameter' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'open'  # Never merges
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Timeout test" -MaxWaitMinutes 1
            $stopwatch.Stop()
            
            # Should timeout within reasonable time (allow some overhead)
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 90000  # 1.5 minutes max
            $result.PRMergeTimeout | Should -Be $true
        }
    }
    
    Context 'ShouldProcess Support' {
        It 'Should support WhatIf for tag creation' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'merged'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "WhatIf test" -WhatIf
            
            # Should not actually create tag in WhatIf mode
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'tag'
            }
        }
    }
    
    Context 'Return Value Structure' {
        It 'Should return comprehensive result object' {
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Result test" -DryRun
            
            $result | Should -HaveProperty 'Success'
            $result | Should -HaveProperty 'NewVersion'
            $result | Should -HaveProperty 'PRCreated'
            $result | Should -HaveProperty 'TagCreated'
            $result | Should -HaveProperty 'Message'
        }
        
        It 'Should indicate success for successful release' {
            Mock gh {
                if ($args -contains 'pr' -and $args -contains 'view') {
                    return 'merged'
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Success test"
            
            $result.Success | Should -Be $true
            $result.TagCreated | Should -Be $true
        }
    }
}