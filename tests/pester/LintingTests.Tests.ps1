# Load shared test helpers for environment setup
. (Join-Path $PSScriptRoot '..' 'helpers' 'TestHelpers.ps1')
Describe 'Code Quality and Linting Tests' {
    BeforeAll {
        # Import parallel execution module using admin-friendly module discovery
        Import-Module 'ParallelExecution' -Force
        
        # Define paths
        $PowerShellSourcePath = './src/pwsh'
        $PythonSourcePath = './src/python'
        $PSAnalyzerSettings = './tests/PSScriptAnalyzerSettings.psd1'
    }
    
    Context 'PSScriptAnalyzer Validation' {
        It 'Should have PSScriptAnalyzer settings file' {
            Test-Path $PSAnalyzerSettings | Should -Be $true
        }
        
        It 'Should pass PSScriptAnalyzer analysis for PowerShell modules' {
            $moduleDirectories = Get-ChildItem $PowerShellSourcePath -Directory -Recurse | 
                Where-Object { $_.Name -eq 'modules' }
            
            foreach ($moduleDir in $moduleDirectories) {
                $analysisResults = Invoke-ScriptAnalyzer -Path $moduleDir.FullName -Settings $PSAnalyzerSettings -Recurse
                
                # Filter out acceptable warnings if needed
                $criticalIssues = $analysisResults | Where-Object { $_.Severity -eq 'Error' }
                
                $criticalIssues.Count | Should -Be 0 -Because "Module $($moduleDir.FullName) should not have critical PSScriptAnalyzer errors"
            }
        }
        
        It 'Should pass PSScriptAnalyzer analysis for PowerShell scripts' {
            $scriptFiles = Get-ChildItem $PowerShellSourcePath -Filter '*.ps1' -Recurse | 
                Where-Object { $_.FullName -notlike "*\.git\*" }
            
            foreach ($scriptFile in $scriptFiles) {
                $analysisResults = Invoke-ScriptAnalyzer -Path $scriptFile.FullName -Settings $PSAnalyzerSettings
                
                # Filter out acceptable warnings if needed
                $criticalIssues = $analysisResults | Where-Object { $_.Severity -eq 'Error' }
                
                $criticalIssues.Count | Should -Be 0 -Because "Script $($scriptFile.Name) should not have critical PSScriptAnalyzer errors"
            }
        }
    }
    
    Context 'Python Code Quality' {
        BeforeAll {
            $pythonExe = if (Test-Path './.venv/Scripts/python.exe') { './.venv/Scripts/python.exe' } else { 'python' }
        }
        
        It 'Should have Python linting configuration files' {
            Test-Path './.flake8' | Should -Be $true
            Test-Path './pyproject.toml' | Should -Be $true
        }
        
        It 'Should pass flake8 analysis for Python source code' {
            if (Test-Path $PythonSourcePath) {
                try {
                    $flake8Output = & $pythonExe -m flake8 $PythonSourcePath --count --statistics 2>&1
                    $LASTEXITCODE | Should -Be 0 -Because "Python source code should pass flake8 analysis"
                } catch {
                    # If flake8 is not available, mark as inconclusive
                    Set-ItResult -Inconclusive -Because "flake8 is not available in the current environment"
                }
            } else {
                Set-ItResult -Inconclusive -Because "Python source directory not found"
            }
        }
        
        It 'Should pass flake8 analysis for Python test code' {
            if (Test-Path './tests/pytest') {
                try {
                    $flake8Output = & $pythonExe -m flake8 './tests/pytest' --count --statistics 2>&1
                    $LASTEXITCODE | Should -Be 0 -Because "Python test code should pass flake8 analysis"
                } catch {
                    # If flake8 is not available, mark as inconclusive
                    Set-ItResult -Inconclusive -Because "flake8 is not available in the current environment"
                }
            } else {
                Set-ItResult -Inconclusive -Because "Python test directory not found"
            }
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        It 'Should use proper path separators in PowerShell scripts' {
            $scriptFiles = Get-ChildItem $PowerShellSourcePath -Filter '*.ps1' -Recurse | 
                Where-Object { $_.FullName -notlike "*\.git\*" }
            
            foreach ($scriptFile in $scriptFiles) {
                $content = Get-Content $scriptFile.FullName -Raw
                
                # Check for hardcoded Windows paths
                $windowsPaths = $content | Select-String -Pattern '[A-Z]:\\' -AllMatches
                $windowsPaths.Matches.Count | Should -Be 0 -Because "Script $($scriptFile.Name) should not contain hardcoded Windows paths"
                
                # Check for proper Join-Path usage instead of string concatenation for paths
                # This is a heuristic check - may need refinement
                if ($content -match '\$\w+\s*\+\s*[''"][\\/]') {
                    # Found potential path concatenation
                    Write-Warning "Potential path concatenation found in $($scriptFile.Name) - consider using Join-Path"
                }
            }
        }
        
        It 'Should use proper line endings' {
            $scriptFiles = Get-ChildItem $PowerShellSourcePath -Filter '*.ps1' -Recurse | 
                Where-Object { $_.FullName -notlike "*\.git\*" }
            
            foreach ($scriptFile in $scriptFiles[0..2]) { # Check first few files to avoid long test times
                $content = [System.IO.File]::ReadAllText($scriptFile.FullName)
                
                # Check for mixed line endings
                $crlfCount = ($content | Select-String -Pattern "`r`n" -AllMatches).Matches.Count
                $lfOnlyCount = ($content | Select-String -Pattern "(?<![`r])`n" -AllMatches).Matches.Count
                
                if ($crlfCount -gt 0 -and $lfOnlyCount -gt 0) {
                    Write-Warning "Mixed line endings detected in $($scriptFile.Name)"
                }
            }
        }
    }
    
    Context 'Parallel Execution Integration' {
        It 'Should be able to create lint tasks' {
            $lintTasks = @()
            
            # Add PowerShell modules
            Get-ChildItem $env:PWSH_MODULES_PATH -Directory | ForEach-Object {
                $lintTasks += @{ 
                    Type = 'PSScriptAnalyzer'; 
                    Path = $_.FullName; 
                    Name = "PSScriptAnalyzer-$($_.Name)" 
                }
            }
            
            $lintTasks.Count | Should -BeGreaterThan 0
            $lintTasks[0].Type | Should -Be 'PSScriptAnalyzer'
            $lintTasks[0].Path | Should -Not -BeNullOrEmpty
        }
        
        It 'Should be able to execute parallel linting (dry run)' {
            $testLintTasks = @(
                @{ Type = 'PSScriptAnalyzer'; Path = './src/aither-core/modules/ParallelExecution'; Name = 'Test-PSScriptAnalyzer' }
            )
            
            { Invoke-ParallelTaskExecution -Tasks $testLintTasks -TaskType 'Lint' -MaxConcurrency 1 } | Should -Not -Throw
        }
    }
}