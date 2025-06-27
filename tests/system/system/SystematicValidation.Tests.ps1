#Requires -Version 7.0
#Requires -Module Pester
#Requires -Module PSScriptAnalyzer

<#
.SYNOPSIS
Systematic validation of all PowerShell scripts in the project

.DESCRIPTION
This comprehensive Pester test validates all PowerShell scripts for:
- Syntax errors
- PSScriptAnalyzer compliance
- Import statement correctness
- Function declarations
- Missing dependencies
- Parallel processing compatibility
#>

BeforeAll {
    # Set up project paths
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:PwshPath = Join-Path $ProjectRoot "pwsh"
    $script:SrcPath = Join-Path $ProjectRoot "src"
    $script:TestsPath = Join-Path $ProjectRoot "tests"
    
    # Get all PowerShell files
    $script:AllPowerShellFiles = @()
    $script:AllPowerShellFiles += Get-ChildItem -Path $script:PwshPath -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
    $script:AllPowerShellFiles += Get-ChildItem -Path $script:PwshPath -Filter "*.psm1" -Recurse -ErrorAction SilentlyContinue
    $script:AllPowerShellFiles += Get-ChildItem -Path $script:SrcPath -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
    $script:AllPowerShellFiles += Get-ChildItem -Path $script:SrcPath -Filter "*.psm1" -Recurse -ErrorAction SilentlyContinue
    
    # Exclude test files from validation (they have different requirements)
    $script:AllPowerShellFiles = $script:AllPowerShellFiles | Where-Object { 
        $_.FullName -notlike "*\tests\*" -and 
        $_.FullName -notlike "*Test*" -and
        $_.Name -notlike "*.Tests.ps1"
    }
    
    Write-Host "Found $($script:AllPowerShellFiles.Count) PowerShell files to validate" -ForegroundColor Green
}

Describe "Systematic PowerShell Validation" {
    
    Context "Syntax Validation" {
        It "Should validate syntax for <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            { 
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
            } | Should -Not -Throw -Because "File $($file.FullName) should have valid PowerShell syntax"
        }
    }
    
    Context "PSScriptAnalyzer Validation" {
        It "Should pass PSScriptAnalyzer rules for <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error
            $results | Should -BeNullOrEmpty -Because "File $($file.FullName) should not have PSScriptAnalyzer errors"
        }
        
        It "Should have minimal PSScriptAnalyzer warnings for <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Warning
            $results.Count | Should -BeLessThan 5 -Because "File $($file.FullName) should have minimal warnings"
        }
    }
    
    Context "Import Statement Validation" {
        It "Should have valid import statements in <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $content = Get-Content $file.FullName -Raw
            
            # Check for problematic import patterns
            $content | Should -Not -Match 'Import-Module.*\$PSScriptRoot.*\.\.' -Because "Should use absolute paths or environment variables"
            $content | Should -Not -Match 'Import-Module.*CodeFixer' -Because "CodeFixer references should be removed"
            
            # If file has Import-Module statements, they should follow standards
            if ($content -match 'Import-Module') {
                # Should use either $env:PWSH_MODULES_PATH or absolute paths
                $validImportPattern = '(Import-Module.*\$env:PWSH_MODULES_PATH|Import-Module.*Join-Path|Import-Module\s+[A-Za-z][A-Za-z0-9]*$)'
                $content | Should -Match $validImportPattern -Because "Import statements should follow project standards"
            }
        }
    }
    
    Context "Function Declaration Validation" {
        It "Should have proper function declarations in <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $content = Get-Content $file.FullName -Raw
            
            # Check for function declarations
            $functionMatches = [regex]::Matches($content, 'function\s+([A-Za-z][\w-]*)')
            
            foreach ($match in $functionMatches) {
                $functionName = $match.Groups[1].Value
                
                # Function names should follow PowerShell conventions
                $functionName | Should -Match '^[A-Z][a-zA-Z0-9]*(-[A-Z][a-zA-Z0-9]*)*$' -Because "Function names should follow PowerShell naming conventions"
                
                # Functions should have CmdletBinding if they're advanced
                if ($content -match "function\s+$functionName\s*\{[^}]*\[CmdletBinding") {
                    $content | Should -Match "function\s+$functionName[^{]*\[CmdletBinding" -Because "Advanced functions should have CmdletBinding attribute"
                }
            }
        }
    }
    
    Context "Dependency Validation" {
        It "Should not reference deprecated dependencies in <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $content = Get-Content $file.FullName -Raw
            
            # Check for deprecated references
            $content | Should -Not -Match 'CodeFixer' -Because "CodeFixer references should be removed"
            $content | Should -Not -Match 'emoji|🎯|✅|❌|⚠️|🔄|📝' -Because "Emojis should be removed per project policy"
            $content | Should -Not -Match 'ValidationOnly' -Because "ValidationOnly mode should be removed"
        }
        
        It "Should have proper #Requires statements in <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $content = Get-Content $file.FullName -Raw
            
            # All PowerShell files should specify minimum version
            $content | Should -Match '#Requires -Version 7\.0' -Because "All files should require PowerShell 7.0+"
        }
    }
    
    Context "Parallel Processing Compatibility" {
        It "Should be compatible with parallel processing for <_.Name>" -ForEach $script:AllPowerShellFiles {
            $file = $_
            $content = Get-Content $file.FullName -Raw
            
            # Check for parallel processing incompatibilities
            $content | Should -Not -Match '\$global:' -Because "Global variables can cause issues in parallel processing"
            $content | Should -Not -Match 'cd\s+' -Because "Use Set-Location or Push-Location instead of cd for parallel safety"
            
            # If using Write-Host, should consider using Write-Output or logging
            if ($content -match 'Write-Host') {
                # This is a warning, not a failure - but we should track it
                Write-Warning "File $($file.Name) uses Write-Host which may not be ideal for parallel processing"
            }
        }
    }
    
    Context "Module Structure Validation" {
        It "Should have proper module structure" {
            # Check PatchManager module structure
            $patchManagerPath = Join-Path $script:PwshPath "modules\PatchManager"
            $patchManagerPath | Should -Exist
            
            Join-Path $patchManagerPath "PatchManager.psd1" | Should -Exist
            Join-Path $patchManagerPath "PatchManager.psm1" | Should -Exist
            Join-Path $patchManagerPath "Public" | Should -Exist
            Join-Path $patchManagerPath "Private" | Should -Exist
        }
        
        It "Should have proper Logging module structure" {
            $loggingPath = Join-Path $script:PwshPath "modules\Logging"
            $loggingPath | Should -Exist
            
            Join-Path $loggingPath "Logging.psd1" | Should -Exist
            Join-Path $loggingPath "Logging.psm1" | Should -Exist
        }
        
        It "Should have ParallelExecution module" {
            $parallelPath = Join-Path $script:PwshPath "modules\ParallelExecution"
            $parallelPath | Should -Exist
            
            # Module should not be empty
            $moduleFiles = Get-ChildItem $parallelPath -Filter "*.ps*"
            $moduleFiles.Count | Should -BeGreaterThan 0 -Because "ParallelExecution module should not be empty"
        }
    }
}

Describe "Parallel Processing Infrastructure" {
    
    Context "ParallelExecution Module" {
        BeforeAll {
            $script:ParallelModulePath = Join-Path $script:PwshPath "modules\ParallelExecution"
        }
        
        It "Should have a manifest file" {
            $manifestPath = Join-Path $script:ParallelModulePath "ParallelExecution.psd1"
            $manifestPath | Should -Exist
        }
        
        It "Should have a module file" {
            $modulePath = Join-Path $script:ParallelModulePath "ParallelExecution.psm1"
            $modulePath | Should -Exist
        }
        
        It "Should export parallel processing functions" {
            $modulePath = Join-Path $script:ParallelModulePath "ParallelExecution.psm1"
            if (Test-Path $modulePath) {
                $content = Get-Content $modulePath -Raw
                $content | Should -Match 'function.*Parallel|ForEach-Object.*Parallel|Start-Job' -Because "Module should contain parallel processing functionality"
            }
        }
    }
    
    Context "Multiprocessing Test Infrastructure" {
        It "Should have multiprocessing test files" {
            $multiprocessingTests = Get-ChildItem $script:TestsPath -Filter "*Parallel*" -Recurse
            $multiprocessingTests.Count | Should -BeGreaterThan 0 -Because "Should have tests for parallel processing"
        }
        
        It "Should have test framework for parallel execution" {
            $testFrameworkPath = Join-Path $script:TestsPath "helpers\TestFramework.ps1"
            if (Test-Path $testFrameworkPath) {
                $content = Get-Content $testFrameworkPath -Raw
                $content | Should -Match 'parallel|multiprocess' -Because "Test framework should support parallel testing"
            }
        }
    }
}

Describe "Test Infrastructure Validation" {
    
    Context "Test Coverage" {
        It "Should have test files for major scripts" {
            $majorScripts = $script:AllPowerShellFiles | Where-Object { 
                $_.FullName -like "*\scripts\*" -or 
                $_.FullName -like "*\Public\*" 
            }
            
            $testFiles = Get-ChildItem $script:TestsPath -Filter "*.Tests.ps1" -Recurse
            
            foreach ($script in $majorScripts) {
                $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($script.Name)
                $expectedTestName = "$scriptName.Tests.ps1"
                
                $hasTest = $testFiles | Where-Object { $_.Name -eq $expectedTestName }
                $hasTest | Should -Not -BeNullOrEmpty -Because "Script $($script.Name) should have a corresponding test file"
            }
        }
    }
    
    Context "Test Helper Validation" {
        It "Should have test helpers" {
            $helpersPath = Join-Path $script:TestsPath "helpers"
            $helpersPath | Should -Exist
            
            Join-Path $helpersPath "TestHelpers.ps1" | Should -Exist
            Join-Path $helpersPath "TestFramework.ps1" | Should -Exist
        }
        
        It "Should have standardized test templates" {
            $templatesPath = Join-Path $script:TestsPath "helpers\TestTemplates.ps1"
            if (Test-Path $templatesPath) {
                $content = Get-Content $templatesPath -Raw
                $content | Should -Match 'template|pattern' -Because "Should contain test templates"
            }
        }
    }
}
