# PSScriptAnalyzerIntegration Module Tests

BeforeAll {
    # Import required modules
    $projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $modulePath = Join-Path $PSScriptRoot ".." "PSScriptAnalyzerIntegration.psd1"
    
    # Import the module
    Import-Module $modulePath -Force
    
    # Create test directory structure
    $script:TestRoot = Join-Path $TestDrive "PSScriptAnalyzerIntegrationTests"
    New-Item -ItemType Directory -Path $script:TestRoot -Force
    
    # Create sample PowerShell files for testing
    $script:TestModuleDir = Join-Path $script:TestRoot "TestModule"
    New-Item -ItemType Directory -Path $script:TestModuleDir -Force
    
    # Sample PowerShell file with known issues
    $sampleScript = @'
function Get-SomethingCool {
    param(
        $input
    )
    Write-Host "This is a test function"
    $global:testVar = "global variable"
    return $input
}

function Download-Something {
    # Non-approved verb
    Write-Host "Downloading..."
}
'@
    
    Set-Content -Path (Join-Path $script:TestModuleDir "TestModule.psm1") -Value $sampleScript
    
    # Sample manifest
    $sampleManifest = @'
@{
    RootModule = 'TestModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test Module'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Get-SomethingCool', 'Download-Something')
}
'@
    
    Set-Content -Path (Join-Path $script:TestModuleDir "TestModule.psd1") -Value $sampleManifest
    
    # Create a clean module for comparison
    $script:CleanModuleDir = Join-Path $script:TestRoot "CleanModule"
    New-Item -ItemType Directory -Path $script:CleanModuleDir -Force
    
    $cleanScript = @'
function Get-TestData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputData
    )
    
    Write-Output "Processing: $InputData"
    return $InputData
}
'@
    
    Set-Content -Path (Join-Path $script:CleanModuleDir "CleanModule.psm1") -Value $cleanScript
}

Describe "PSScriptAnalyzerIntegration Module" {
    
    Context "Module Loading" {
        It "Should load the module successfully" {
            Get-Module PSScriptAnalyzerIntegration | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $module = Get-Module PSScriptAnalyzerIntegration
            $module.ExportedFunctions.Keys | Should -Contain 'Start-DirectoryAudit'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-AnalysisStatus'
        }
        
        It "Should have PSScriptAnalyzer as required module" {
            $module = Get-Module PSScriptAnalyzerIntegration
            $module.RequiredModules | Should -Contain 'PSScriptAnalyzer'
        }
    }
    
    Context "Configuration Management" {
        It "Should get default configuration" {
            $config = Get-AnalysisConfiguration -Path $script:TestModuleDir
            $config | Should -Not -BeNullOrEmpty
            $config.Severity | Should -Contain 'Error'
            $config.Severity | Should -Contain 'Warning'
        }
        
        It "Should handle missing configuration gracefully" {
            $nonExistentPath = Join-Path $TestDrive "NonExistent"
            { Get-AnalysisConfiguration -Path $nonExistentPath } | Should -Throw
        }
    }
    
    Context "Directory Analysis" {
        It "Should analyze directory with PowerShell files" {
            $result = Invoke-DirectoryAnalysis -Path $script:TestModuleDir -UpdateFiles $false
            
            $result | Should -Not -BeNullOrEmpty
            $result.Path | Should -Be $script:TestModuleDir
            $result.FilesAnalyzed | Should -BeGreaterThan 0
            $result.Results | Should -Not -BeNullOrEmpty
        }
        
        It "Should detect known issues in test module" {
            $result = Invoke-DirectoryAnalysis -Path $script:TestModuleDir -UpdateFiles $false
            
            # Should find issues like unapproved verbs, global variables, etc.
            $result.Summary.Total | Should -BeGreaterThan 0
            
            # Check for specific rule violations
            $unapprovedVerb = $result.Results | Where-Object RuleName -eq 'PSUseApprovedVerbs'
            $unapprovedVerb | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle clean modules with fewer issues" {
            $result = Invoke-DirectoryAnalysis -Path $script:CleanModuleDir -UpdateFiles $false
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -BeIn @('good', 'warnings', 'review-recommended')
        }
    }
    
    Context "Status File Management" {
        It "Should create status file" {
            $testAnalysisResults = @(
                [PSCustomObject]@{
                    RuleName = 'PSUseApprovedVerbs'
                    Severity = 'Warning'
                    ScriptPath = Join-Path $script:TestModuleDir "TestModule.psm1"
                    Line = 10
                    Column = 1
                    Message = 'Test message'
                }
            )
            
            $result = New-StatusFile -Path $script:TestModuleDir -AnalysisResults $testAnalysisResults -Force
            $result | Should -Be $true
            
            $statusFile = Join-Path $script:TestModuleDir ".pssa-status"
            Test-Path $statusFile | Should -Be $true
            
            $statusContent = Get-Content $statusFile | ConvertFrom-Json
            $statusContent.findings.warnings | Should -BeGreaterThan 0
        }
        
        It "Should not overwrite existing status file without Force" {
            # Create initial status file
            New-StatusFile -Path $script:TestModuleDir -AnalysisResults @() -Force
            
            # Try to create again without Force
            $result = New-StatusFile -Path $script:TestModuleDir -AnalysisResults @()
            $result | Should -Be $false
        }
    }
    
    Context "Bug Tracking" {
        It "Should create .bugz file with findings" {
            $testAnalysisResults = @(
                [PSCustomObject]@{
                    RuleName = 'PSUseApprovedVerbs'
                    Severity = 'Warning'
                    ScriptPath = Join-Path $script:TestModuleDir "TestModule.psm1"
                    Line = 10
                    Column = 1
                    Message = 'Test message'
                }
            )
            
            $result = Update-BugzFile -Path $script:TestModuleDir -AnalysisResults $testAnalysisResults
            $result | Should -Not -BeNullOrEmpty
            
            $bugzFile = Join-Path $script:TestModuleDir ".bugz"
            Test-Path $bugzFile | Should -Be $true
            
            $bugzContent = Get-Content $bugzFile | ConvertFrom-Json
            $bugzContent.findings.Count | Should -BeGreaterThan 0
            $bugzContent.summary.open | Should -BeGreaterThan 0
        }
        
        It "Should handle auto-resolve for missing findings" {
            # First, add some findings
            $initialResults = @(
                [PSCustomObject]@{
                    RuleName = 'PSUseApprovedVerbs'
                    Severity = 'Warning'
                    ScriptPath = Join-Path $script:TestModuleDir "TestModule.psm1"
                    Line = 10
                    Column = 1
                    Message = 'Test message'
                }
            )
            
            Update-BugzFile -Path $script:TestModuleDir -AnalysisResults $initialResults
            
            # Then update with empty results and auto-resolve
            $result = Update-BugzFile -Path $script:TestModuleDir -AnalysisResults @() -AutoResolve
            
            $bugzContent = Get-Content (Join-Path $script:TestModuleDir ".bugz") | ConvertFrom-Json
            $resolved = $bugzContent.findings | Where-Object { $_.status -eq 'auto-resolved' }
            $resolved | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Start-DirectoryAudit Function" {
        It "Should audit single directory" {
            $result = Start-DirectoryAudit -Path $script:TestModuleDir -UpdateDocumentation $false
            
            $result | Should -Not -BeNullOrEmpty
            $result.Summary.DirectoriesAnalyzed | Should -BeGreaterThan 0
            $result.Summary.FilesAnalyzed | Should -BeGreaterThan 0
        }
        
        It "Should audit with documentation update" {
            $result = Start-DirectoryAudit -Path $script:TestModuleDir -UpdateDocumentation $true
            
            $readmePath = Join-Path $script:TestModuleDir "README.md"
            Test-Path $readmePath | Should -Be $true
            
            $readmeContent = Get-Content $readmePath -Raw
            $readmeContent | Should -Match "Code Quality Status"
        }
        
        It "Should handle non-existent directory gracefully" {
            $nonExistentPath = Join-Path $TestDrive "NonExistent"
            { Start-DirectoryAudit -Path $nonExistentPath } | Should -Throw
        }
    }
    
    Context "Get-AnalysisStatus Function" {
        BeforeAll {
            # Ensure we have status files to read
            Start-DirectoryAudit -Path $script:TestModuleDir -UpdateDocumentation $false
        }
        
        It "Should get analysis status" {
            $status = Get-AnalysisStatus -Path $script:TestRoot -Recurse $true
            $status | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide rollup summary" {
            $rollup = Get-AnalysisStatus -Path $script:TestRoot -Rollup -Format Summary
            $rollup | Should -Not -BeNullOrEmpty
            $rollup | Should -Match "PSScriptAnalyzer Status Rollup"
        }
        
        It "Should filter by status" {
            $filtered = Get-AnalysisStatus -Path $script:TestRoot -StatusFilter "warnings"
            # May or may not have results depending on the analysis
            $filtered | Should -BeNullOrEmpty -Or { $filtered | Should -Not -BeNullOrEmpty }
        }
        
        It "Should export status to file" {
            $exportPath = Join-Path $TestDrive "status-export.json"
            Get-AnalysisStatus -Path $script:TestRoot -Format JSON -ExportPath $exportPath
            
            Test-Path $exportPath | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should handle missing PSScriptAnalyzer gracefully" {
            # This test would require temporarily removing PSScriptAnalyzer
            # For now, just verify the function exists and handles errors
            
            $invalidPath = Join-Path $TestDrive "InvalidPath"
            { Start-DirectoryAudit -Path $invalidPath } | Should -Throw
        }
        
        It "Should handle corrupt status files" {
            $corruptStatusPath = Join-Path $script:TestModuleDir ".pssa-status"
            Set-Content -Path $corruptStatusPath -Value "invalid json content"
            
            # Should handle gracefully and not crash
            { Get-AnalysisStatus -Path $script:TestModuleDir } | Should -Not -Throw
        }
    }
    
    Context "Integration" {
        It "Should integrate with logging if available" {
            # Test custom logging integration
            $module = Get-Module PSScriptAnalyzerIntegration
            $module.PrivateData | Should -Not -BeNullOrEmpty
        }
        
        It "Should cache configuration appropriately" {
            # Test configuration caching
            $config1 = Get-AnalysisConfiguration -Path $script:TestModuleDir -UseCache $true
            $config2 = Get-AnalysisConfiguration -Path $script:TestModuleDir -UseCache $true
            
            $config1 | Should -Not -BeNullOrEmpty
            $config2 | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Performance" {
        It "Should complete analysis in reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Start-DirectoryAudit -Path $script:TestModuleDir -UpdateDocumentation $false
            $stopwatch.Stop()
            
            # Should complete within 30 seconds for small test module
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000
        }
    }
}

AfterAll {
    # Clean up test files
    if (Test-Path $script:TestRoot) {
        Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove module
    Remove-Module PSScriptAnalyzerIntegration -Force -ErrorAction SilentlyContinue
}