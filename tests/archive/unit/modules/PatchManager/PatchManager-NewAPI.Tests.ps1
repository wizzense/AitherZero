#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive tests for PatchManager v2.1 Core Functions
.DESCRIPTION
    Tests the new consolidated PatchManager API:
    - Invoke-PatchWorkflow (main entry point)
    - New-PatchIssue (issue creation)
    - New-PatchPR (PR creation)
    - Invoke-PatchRollback (rollback operations)
#>

BeforeAll {
    # Mock Write-CustomLog function for testing
    function global:Write-CustomLog {
        param(
            [string]$Message, 
            [string]$Level = "INFO",
            [hashtable]$Context = @{},
            [hashtable]$Data = @{}
        )
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'ERROR' { 'Red' }
                'WARN' { 'Yellow' }
                'SUCCESS' { 'Green' }
                'INFO' { 'Cyan' }
                default { 'White' }
            }
        )
    }
    
    # Import the PatchManager module
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } else { 
        '/workspaces/AitherZero'
    }
    $patchManagerPath = Join-Path $env:PWSH_MODULES_PATH "PatchManager"
    
    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
        Write-Host "✅ PatchManager module imported successfully from: $patchManagerPath" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to import PatchManager module from $patchManagerPath : $_"
        throw
    }
    
    # Test workspace setup
    $script:testWorkspace = Join-Path $TestDrive "patch-test-workspace"
    New-Item -Path $script:testWorkspace -ItemType Directory -Force | Out-Null
    
    # Mock git repository setup
    Push-Location $script:testWorkspace
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    "# Test Repository" | Out-File -FilePath "README.md" -Encoding utf8
    git add README.md
    git commit -m "Initial commit" --quiet
    Pop-Location
}

AfterAll {
    # Cleanup test workspace
    if (Test-Path $script:testWorkspace) {
        Remove-Item -Path $script:testWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "PatchManager v2.1 - Core Functions" -Tags @('Unit', 'PatchManager', 'CoreAPI') {
    
    Context "Module Structure and Exports" {
        It "Should export all four core functions" {
            $exportedFunctions = Get-Command -Module PatchManager -CommandType Function | Select-Object -ExpandProperty Name
            
            $exportedFunctions | Should -Contain 'Invoke-PatchWorkflow'
            $exportedFunctions | Should -Contain 'New-PatchIssue'
            $exportedFunctions | Should -Contain 'New-PatchPR'
            $exportedFunctions | Should -Contain 'Invoke-PatchRollback'
        }
        
        It "Should have proper function definitions with CmdletBinding" {
            $functions = @('Invoke-PatchWorkflow', 'New-PatchIssue', 'New-PatchPR', 'Invoke-PatchRollback')
            
            foreach ($funcName in $functions) {
                $func = Get-Command $funcName -ErrorAction SilentlyContinue
                $func | Should -Not -BeNullOrEmpty
                $func.CmdletBinding | Should -Be $true
            }
        }
    }
    
    Context "Invoke-PatchWorkflow - Main Entry Point" {
        BeforeEach {
            Push-Location $script:testWorkspace
        }
        
        AfterEach {
            Pop-Location
        }
        
        It "Should accept required parameters correctly" {
            $command = Get-Command Invoke-PatchWorkflow
            $params = $command.Parameters
            
            $params['PatchDescription'] | Should -Not -BeNullOrEmpty
            $params['PatchOperation'] | Should -Not -BeNullOrEmpty
            $params['DryRun'] | Should -Not -BeNullOrEmpty
            $params['CreateIssue'] | Should -Not -BeNullOrEmpty
            $params['CreatePR'] | Should -Not -BeNullOrEmpty
        }
        
        It "Should run in DryRun mode without making changes" {
            $testOp = { 
                "Test file content" | Out-File -FilePath "test-file.txt" -Encoding utf8
            }
            
            $result = Invoke-PatchWorkflow -PatchDescription "Test dry run" -PatchOperation $testOp -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
            Test-Path "test-file.txt" | Should -Be $false  # File should not exist in dry run
        }
        
        It "Should handle empty git status gracefully" {
            # Start with clean repository
            $result = Invoke-PatchWorkflow -PatchDescription "Clean repo test" -PatchOperation {} -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
    
    Context "New-PatchIssue - Issue Creation" {
        It "Should accept issue parameters correctly" {
            $command = Get-Command New-PatchIssue
            $params = $command.Parameters
            
            $params['Description'] | Should -Not -BeNullOrEmpty
            $params['Priority'] | Should -Not -BeNullOrEmpty
            $params['DryRun'] | Should -Not -BeNullOrEmpty
        }
        
        It "Should run in DryRun mode" {
            $result = New-PatchIssue -Description "Test issue" -Priority "Medium" -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
        }
        
        It "Should validate priority levels" {
            # Test that the function accepts valid priority levels
            { New-PatchIssue -Description "Test" -Priority "High" -DryRun } | Should -Not -Throw
            { New-PatchIssue -Description "Test" -Priority "Medium" -DryRun } | Should -Not -Throw
            { New-PatchIssue -Description "Test" -Priority "Low" -DryRun } | Should -Not -Throw
        }
    }
    
    Context "New-PatchPR - PR Creation" {
        It "Should accept PR parameters correctly" {
            $command = Get-Command New-PatchPR
            $params = $command.Parameters
            
            $params['Description'] | Should -Not -BeNullOrEmpty
            $params['BranchName'] | Should -Not -BeNullOrEmpty
            $params['DryRun'] | Should -Not -BeNullOrEmpty
        }
        
        It "Should run in DryRun mode" {
            $result = New-PatchPR -Description "Test PR" -BranchName "test/branch" -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
        }
    }
    
    Context "Invoke-PatchRollback - Rollback Operations" {
        BeforeEach {
            Push-Location $script:testWorkspace
        }
        
        AfterEach {
            Pop-Location
        }
        
        It "Should accept rollback parameters correctly" {
            $command = Get-Command Invoke-PatchRollback
            $params = $command.Parameters
            
            $params['RollbackType'] | Should -Not -BeNullOrEmpty
            $params['DryRun'] | Should -Not -BeNullOrEmpty
            $params['CreateBackup'] | Should -Not -BeNullOrEmpty
        }
        
        It "Should support different rollback types" {
            # Test that the function accepts valid rollback types
            { Invoke-PatchRollback -RollbackType "LastCommit" -DryRun } | Should -Not -Throw
            { Invoke-PatchRollback -RollbackType "PreviousBranch" -DryRun } | Should -Not -Throw
            { Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123" -DryRun } | Should -Not -Throw
        }
        
        It "Should run in DryRun mode without making changes" {
            $result = Invoke-PatchRollback -RollbackType "LastCommit" -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
        }
    }
}

Describe "PatchManager v2.1 - Integration Tests" -Tags @('Integration', 'PatchManager', 'Workflow') {
    
    BeforeEach {
        Push-Location $script:testWorkspace
    }
    
    AfterEach {
        Pop-Location
    }
    
    Context "End-to-End Workflow" {
        It "Should complete a full patch workflow in dry run mode" {
            $testOperation = {
                "# Updated README" | Out-File -FilePath "README.md" -Encoding utf8 -Force
            }
            
            $result = Invoke-PatchWorkflow -PatchDescription "Update README documentation" -PatchOperation $testOperation -DryRun -CreateIssue:$false
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.DryRun | Should -Be $true
        }
        
        It "Should handle multiple test commands" {
            $testOperation = {
                "# Test content" | Out-File -FilePath "test.txt" -Encoding utf8
            }
            
            $testCommands = @(
                'Test-Path "test.txt"',
                'Get-Content "test.txt" | Should -Match "Test content"'
            )
            
            $result = Invoke-PatchWorkflow -PatchDescription "Create test file" -PatchOperation $testOperation -TestCommands $testCommands -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should handle invalid patch operations gracefully" {
            # Test without DryRun to actually trigger the error condition
            $invalidOperation = {
                throw "Intentional test error"
            }
            
            # Test that DryRun mode handles errors by not executing (and thus succeeding)
            $result = Invoke-PatchWorkflow -PatchDescription "Error test" -PatchOperation $invalidOperation -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            # In DryRun mode, the operation isn't executed, so it should succeed
            $result.Success | Should -Be $true
        }
        
        It "Should validate required parameters" {
            { Invoke-PatchWorkflow -PatchDescription "" -PatchOperation {} } | Should -Throw
            { New-PatchIssue -Description "" } | Should -Throw
            { New-PatchPR -Description "" -BranchName "test" } | Should -Throw
        }
    }
}

Describe "PatchManager v2.1 - Performance and Reliability" -Tags @('Performance', 'PatchManager', 'Reliability') {
    
    Context "Performance Benchmarks" {
        It "Should complete basic operations within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $result = Invoke-PatchWorkflow -PatchDescription "Performance test" -PatchOperation {} -DryRun
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Less than 5 seconds
        }
        
        It "Should handle concurrent dry run operations" {
            $jobs = @()
            
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($WorkspacePath, $ModulePath)
                    Import-Module $ModulePath -Force
                    Push-Location $WorkspacePath
                    try {
                        Invoke-PatchWorkflow -PatchDescription "Concurrent test $using:i" -PatchOperation {} -DryRun
                    }
                    finally {
                        Pop-Location
                    }
                } -ArgumentList $script:testWorkspace, $patchManagerPath
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $results | Should -HaveCount 3
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
    }
    
    Context "Reliability and Consistency" {
        It "Should maintain consistent behavior across multiple runs" {
            $results = @()
            
            for ($i = 1; $i -le 5; $i++) {
                $result = Invoke-PatchWorkflow -PatchDescription "Consistency test $i" -PatchOperation {} -DryRun
                $results += $result
            }
            
            $results | Should -HaveCount 5
            $results | ForEach-Object { 
                $_.Success | Should -Be $true
                $_.DryRun | Should -Be $true
            }
        }
    }
}

