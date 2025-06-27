BeforeAll {
    # Ensure we're using the correct module path - tests directory is one level down from project root
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $env:PWSH_MODULES_PATH = Join-Path $projectRoot "aither-core/modules"
}

Describe "Module Structure Validation" {
    
    Context "Duplicate File Check" {        It "Should not have duplicate ErrorHandling files" {
            $errorHandlingFiles = Get-ChildItem -Path $env:PWSH_MODULES_PATH -Recurse -Name "ErrorHandling.ps1"
            $errorHandlingFiles.Count | Should -Be 1
            $errorHandlingFiles | Should -Be "PatchManager\Public\ErrorHandling.ps1"
        }
          It "Should not have src/aither-core/modules directory" {
            $projectRoot = Split-Path $PSScriptRoot -Parent
            $srcModulesPath = Join-Path $projectRoot "src/aither-core/modules"
            Test-Path $srcModulesPath | Should -Be $false
        }
    }
    
    Context "Active Module Structure" {
        It "Should have the correct active modules directory" {
            Test-Path $env:PWSH_MODULES_PATH | Should -Be $true
        }
        
        It "Should have PatchManager module with ErrorHandling" {
            $errorHandlingPath = Join-Path $env:PWSH_MODULES_PATH "PatchManager\Public\ErrorHandling.ps1"
            Test-Path $errorHandlingPath | Should -Be $true
        }
        
        It "Should have PatchManager module with BranchCleanup" {
            $branchCleanupPath = Join-Path $env:PWSH_MODULES_PATH "PatchManager\Public\Invoke-BranchCleanup.ps1"
            Test-Path $branchCleanupPath | Should -Be $true
        }
        
        It "Should load PatchManager module successfully" {
            $patchManagerPath = Join-Path $env:PWSH_MODULES_PATH "PatchManager"
            { Import-Module $patchManagerPath -Force } | Should -Not -Throw
        }
    }
    
    Context "Test Configuration" {
        It "Should have updated test files pointing to correct module path" {
            $dynamicTestsContent = Get-Content "tests\Invoke-DynamicTests.ps1" -Raw
            $dynamicTestsContent | Should -Match 'aither-core/modules'
            $dynamicTestsContent | Should -Not -Match 'src/aither-core/modules'
        }
        
        It "Should have updated master tests pointing to correct module path" {
            $masterTestsContent = Get-Content "tests\Run-MasterTests.ps1" -Raw
            $masterTestsContent | Should -Match 'aither-core/modules'
            $masterTestsContent | Should -Not -Match 'src/aither-core/modules'
        }
    }
}
