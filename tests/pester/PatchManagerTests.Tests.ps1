Describe 'PatchManager Function Tests' {
    BeforeAll {
        $PatchManagerPath = './src/aither-core/modules/PatchManager/Public'
    }

    Context 'Function Files Exist' {
        It 'Should have Test-PatchingRequirements.ps1' {
            Test-Path "$PatchManagerPath/Test-PatchingRequirements.ps1" | Should -Be $true
        }

        It 'Should have Invoke-UnifiedMaintenance.ps1' {
            Test-Path "$PatchManagerPath/Invoke-UnifiedMaintenance.ps1" | Should -Be $true
        }

        It 'Should have Invoke-QuickRollback.ps1' {
            Test-Path "$PatchManagerPath/Invoke-QuickRollback.ps1" | Should -Be $true
        }

        It 'Should have Invoke-PatchValidation.ps1' {
            Test-Path "$PatchManagerPath/Invoke-PatchValidation.ps1" | Should -Be $true
        }

        It 'Should have Invoke-PatchRollback.ps1' {
            Test-Path "$PatchManagerPath/Invoke-PatchRollback.ps1" | Should -Be $true
        }

        It 'Should have Invoke-MassFileFix.ps1' {
            Test-Path "$PatchManagerPath/Invoke-MassFileFix.ps1" | Should -Be $true
        }

        It 'Should have Git-related functions' {
            Test-Path "$PatchManagerPath/Invoke-GitHubIssueResolution.ps1" | Should -Be $true
            Test-Path "$PatchManagerPath/Invoke-GitHubIssueIntegration.ps1" | Should -Be $true
            Test-Path "$PatchManagerPath/Invoke-GitControlledPatch.ps1" | Should -Be $true
        }
    }

    Context 'Function Content Validation' {
        It 'Should have non-empty function files' {
            Get-ChildItem "$PatchManagerPath/*.ps1" | ForEach-Object {
                $content = Get-Content $_.FullName -Raw
                $content | Should -Not -BeNullOrEmpty
                $content.Length | Should -BeGreaterThan 10
            }
        }

        It 'Should contain function definitions' {
            Get-ChildItem "$PatchManagerPath/*.ps1" | ForEach-Object {
                $content = Get-Content $_.FullName -Raw
                # Check if file contains 'function' keyword or 'param' block
                ($content -match 'function\s+\w+' -or $content -match 'param\s*\(') | Should -Be $true
            }
        }
    }

    Context 'Syntax Validation' {
        It 'Should have valid PowerShell syntax in all function files' {
            Get-ChildItem "$PatchManagerPath/*.ps1" | ForEach-Object {
                {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$null)
                } | Should -Not -Throw
            }
        }
    }
}