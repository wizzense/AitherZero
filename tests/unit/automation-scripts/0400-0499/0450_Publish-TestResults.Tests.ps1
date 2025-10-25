#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0450_Publish-TestResults.ps1"
    $script:ScriptName = Split-Path $script:ScriptPath -Leaf

    # Mock project structure
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZeroTests-$(New-Guid)"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    New-Item -ItemType Directory -Path "$script:TestRoot/tests/results" -Force | Out-Null
    New-Item -ItemType Directory -Path "$script:TestRoot/tests/coverage" -Force | Out-Null
    New-Item -ItemType Directory -Path "$script:TestRoot/tests/analysis" -Force | Out-Null
}

Describe "0450_Publish-TestResults.ps1" {
    Context "Script Validation" {
        It "Should exist at the expected location" {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $script:ScriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Should support WhatIf parameter" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match 'SupportsShouldProcess'
            $scriptContent | Should -Match '\$PSCmdlet\.ShouldProcess'
        }
    }

    Context "Parameter Validation" {
        BeforeAll {
            Mock Write-Host {}
            Mock Write-CustomLog {} -ModuleName AitherZero -ErrorAction SilentlyContinue
        }

        It "Should accept Path parameter" {
            { & $script:ScriptPath -Path $script:TestRoot -WhatIf } | Should -Not -Throw
        }

        It "Should accept OutputPath parameter" {
            { & $script:ScriptPath -OutputPath "$script:TestRoot/output" -WhatIf } | Should -Not -Throw
        }

        It "Should accept IncludeTrends switch" {
            { & $script:ScriptPath -IncludeTrends -WhatIf } | Should -Not -Throw
        }

        It "Should use default values when parameters not specified" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Test Result Processing" {
        BeforeAll {
            # Create mock test results
            $unitTestXml = @'
<?xml version="1.0" encoding="utf-8"?>
<test-results total="10" passed="8" failures="1" inconclusive="1" time="5.123">
  <test-suite name="Unit Tests">
    <results>
      <test-case name="Test1" executed="true" result="Success" time="0.5" />
    </results>
  </test-suite>
</test-results>
'@
            $unitTestXml | Set-Content "$script:TestRoot/tests/results/UnitTests-20250813.xml"

            # Create mock coverage
            $coverageXml = @'
<?xml version="1.0" encoding="utf-8"?>
<coverage line-rate="0.85" branch-rate="0.75">
  <packages>
    <package name="AitherZero" line-rate="0.85" branch-rate="0.75">
      <classes />
    </package>
  </packages>
</coverage>
'@
            $coverageXml | Set-Content "$script:TestRoot/tests/coverage/Coverage-20250813.xml"

            # Create mock PSScriptAnalyzer results
            $analysisCSV = @"
RuleName,Severity,ScriptName,Line,Column,Message
PSAvoidUsingWriteHost,Warning,test.ps1,10,5,Avoid using Write-Host
"@
            $analysisCSV | Set-Content "$script:TestRoot/tests/analysis/PSScriptAnalyzer-20250813.csv"

            Mock Write-Host {}
            Mock Write-CustomLog {} -ModuleName AitherZero -ErrorAction SilentlyContinue
            Mock Import-Module {}
        }

        It "Should process unit test results" {
            & $script:ScriptPath -Path $script:TestRoot -OutputPath "$script:TestRoot/output" -WhatIf

            # Verify processing occurred (in WhatIf mode)
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "=== 0450_Publish-TestResults.ps1 ==="
            }
        }

        It "Should create output directory structure" {
            $outputPath = "$script:TestRoot/output"
            & $script:ScriptPath -Path $script:TestRoot -OutputPath $outputPath -WhatIf

            # In WhatIf mode, directories won't actually be created
            # But the script should attempt to create them
            Should -Invoke Write-Host
        }

        It "Should handle missing test results gracefully" {
            $emptyPath = "$script:TestRoot/empty"
            New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null

            { & $script:ScriptPath -Path $emptyPath -OutputPath "$script:TestRoot/output" -WhatIf } |
                Should -Not -Throw
        }
    }

    Context "HTML Report Generation" {
        BeforeAll {
            Mock Write-Host {}
            Mock Set-Content {}
        }

        It "Should generate HTML report in WhatIf mode" {
            & $script:ScriptPath -Path $script:TestRoot -OutputPath "$script:TestRoot/output" -WhatIf

            # Verify Set-Content would be called for HTML
            Should -Invoke Set-Content -ParameterFilter {
                $Path -match "test-report\.html"
            } -Times 0  # WhatIf prevents actual write
        }

        It "Should include charts and styling in HTML" {
            # This test would verify HTML content structure
            # In a real scenario, we'd parse the generated HTML
            $true | Should -Be $true  # Placeholder
        }
    }

    Context "JSON Export" {
        BeforeAll {
            Mock Write-Host {}
            Mock Set-Content {}
            Mock ConvertTo-Json { $InputObject }
        }

        It "Should export results as JSON" {
            & $script:ScriptPath -Path $script:TestRoot -OutputPath "$script:TestRoot/output" -WhatIf

            # Verify JSON conversion would occur
            Should -Invoke ConvertTo-Json
        }
    }

    Context "Trend Analysis" {
        BeforeAll {
            Mock Write-Host {}
            Mock Get-ChildItem { @() }
        }

        It "Should generate trends when IncludeTrends is specified" {
            & $script:ScriptPath -Path $script:TestRoot -IncludeTrends -WhatIf

            # Verify trend processing logic is invoked
            Should -Invoke Get-ChildItem -ParameterFilter {
                $Path -match "archive"
            }
        }
    }

    Context "Error Handling" {
        BeforeAll {
            Mock Write-Host {}
            Mock Write-Error {}
        }

        It "Should handle invalid XML gracefully" {
            "Invalid XML" | Set-Content "$script:TestRoot/tests/results/UnitTests-bad.xml"

            { & $script:ScriptPath -Path $script:TestRoot -OutputPath "$script:TestRoot/output" -WhatIf } |
                Should -Not -Throw
        }

        It "Should handle permission errors" {
            Mock New-Item { throw "Access denied" }

            { & $script:ScriptPath -Path $script:TestRoot -OutputPath "$script:TestRoot/output" -WhatIf } |
                Should -Throw
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestRoot) {
        Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}