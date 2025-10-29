#Requires -Version 7.0

<#
.SYNOPSIS
    Integration test to validate the validate-manifests workflow configuration
.DESCRIPTION
    This test ensures that the validate-manifests.yml workflow file is properly
    configured without invalid action parameters or unnecessary setup steps.
#>

BeforeAll {
    $script:WorkflowFile = Join-Path $PSScriptRoot "../../.github/workflows/validate-manifests.yml"
}

Describe "Validate Manifests Workflow Configuration" {
    BeforeAll {
        $script:Content = Get-Content -Path $script:WorkflowFile -Raw
    }

    Context "Workflow file existence and structure" {
        It "Should have validate-manifests.yml workflow file" {
            Test-Path $script:WorkflowFile | Should -Be $true
        }

        It "Should have valid YAML structure" {
            { 
                # Use Python to validate YAML if available
                $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } 
                            elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                            else { $null }
                
                if ($pythonCmd) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $script:Content | Set-Content -Path $tempFile -Encoding UTF8
                        $pythonScript = "import yaml; yaml.safe_load(open(r'$tempFile'))"
                        & $pythonCmd -c $pythonScript 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            throw "YAML validation failed"
                        }
                    } finally {
                        if (Test-Path $tempFile) {
                            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            } | Should -Not -Throw
        }
    }

    Context "Action configuration" {
        It "Should not use azure/powershell action with invalid pwsh parameter" {
            # Check that we don't have the problematic azure/powershell@v2 with pwsh parameter
            $script:Content -match 'azure/powershell@v\d+' | Should -Be $false -Because "azure/powershell action is not needed on ubuntu-latest runners"
        }

        It "Should not have a Setup PowerShell step" {
            # The setup step was removed because PowerShell is pre-installed on ubuntu-latest
            $script:Content -match 'Setup PowerShell' | Should -Be $false -Because "PowerShell is pre-installed on ubuntu-latest runners"
        }

        It "Should use shell pwsh for PowerShell execution" {
            # Verify that the workflow uses the correct approach to run PowerShell
            $script:Content -match 'shell:\s+pwsh' | Should -Be $true -Because "Steps should use shell: pwsh to execute PowerShell code"
        }
    }

    Context "Workflow steps" {
        It "Should have checkout step" {
            $script:Content -match 'uses:\s*actions/checkout@v\d+' | Should -Be $true
        }

        It "Should have manifest validation step" {
            $script:Content -match 'Validate All Module Manifests' | Should -Be $true
        }

        It "Should have validation tools test step" {
            $script:Content -match 'Test Validation Tools' | Should -Be $true
        }

        It "Should call the validation script" {
            $script:Content -match '0405_Validate-ModuleManifests\.ps1' | Should -Be $true
        }

        It "Should run Pester tests for validation tools" {
            $script:Content -match 'Invoke-Pester.*0405_Validate-ModuleManifests\.Tests\.ps1' | Should -Be $true
        }
    }

    Context "Workflow triggers" {
        It "Should trigger on push to main and develop branches" {
            $script:Content -match 'branches:\s*\[main,\s*develop\]' | Should -Be $true
        }

        It "Should trigger on pull request" {
            $script:Content -match 'pull_request:' | Should -Be $true
        }

        It "Should support manual workflow dispatch" {
            $script:Content -match 'workflow_dispatch:' | Should -Be $true
        }

        It "Should trigger on manifest file changes" {
            $script:Content -match '\*\*\/\*\.psd1' | Should -Be $true
        }
    }

    Context "Runner configuration" {
        It "Should run on ubuntu-latest" {
            $script:Content -match 'runs-on:\s*ubuntu-latest' | Should -Be $true -Because "ubuntu-latest has PowerShell 7 pre-installed"
        }
    }
}
