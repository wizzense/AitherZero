#Requires -Modules Pester

<#
.SYNOPSIS
    Validation tests for dashboard-generation-complete playbook parameters
.DESCRIPTION
    Ensures that playbook parameters match the actual parameter names expected by
    the metrics collection and dashboard generation scripts (0520-0525).
    
    This prevents the orchestration engine from silently dropping parameters when
    parameter names don't match, which would cause scripts to use default paths
    instead of the configured paths.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    # Load the playbook
    $playbookPath = Join-Path $script:ProjectRoot "library/playbooks/dashboard-generation-complete.psd1"
    $configContent = Get-Content -Path $playbookPath -Raw
    $scriptBlock = [scriptblock]::Create($configContent)
    $script:Playbook = & $scriptBlock
    
    # Define expected parameters for each script
    # Note: These are the specific "Collect" scripts, not the "Analyze" scripts with the same numbers
    $script:ExpectedParameters = @{
        '0520' = @{
            ScriptName = '0520_Collect-RingMetrics.ps1'
            ScriptPath = Join-Path $script:ProjectRoot "library/automation-scripts/0520_Collect-RingMetrics.ps1"
            ExpectedParams = @('OutputPath')
            Description = "Ring metrics collection"
        }
        '0521' = @{
            ScriptName = '0521_Collect-WorkflowHealth.ps1'
            ScriptPath = Join-Path $script:ProjectRoot "library/automation-scripts/0521_Collect-WorkflowHealth.ps1"
            ExpectedParams = @('OutputPath')
            Description = "Workflow health metrics collection"
        }
        '0522' = @{
            ScriptName = '0522_Collect-CodeMetrics.ps1'
            ScriptPath = Join-Path $script:ProjectRoot "library/automation-scripts/0522_Collect-CodeMetrics.ps1"
            ExpectedParams = @('OutputPath')
            Description = "Code metrics collection"
        }
        '0523' = @{
            ScriptName = '0523_Collect-TestMetrics.ps1'
            ScriptPath = Join-Path $script:ProjectRoot "library/automation-scripts/0523_Collect-TestMetrics.ps1"
            ExpectedParams = @('OutputPath')
            Description = "Test metrics collection"
        }
        '0524' = @{
            ScriptName = '0524_Collect-QualityMetrics.ps1'
            ScriptPath = Join-Path $script:ProjectRoot "library/automation-scripts/0524_Collect-QualityMetrics.ps1"
            ExpectedParams = @('OutputPath')
            Description = "Quality metrics collection"
        }
        '0525' = @{
            ScriptName = '0525_Generate-DashboardHTML.ps1'
            ScriptPath = Join-Path $script:ProjectRoot "library/automation-scripts/0525_Generate-DashboardHTML.ps1"
            ExpectedParams = @('OutputPath', 'MetricsPath')
            Description = "Dashboard HTML generation"
        }
    }
}

Describe "Dashboard Playbook Parameter Validation" -Tag 'Integration' {
    
    Context "Playbook structure validation" {
        It "Should load successfully" {
            $script:Playbook | Should -Not -BeNullOrEmpty
            $script:Playbook.Name | Should -Be 'dashboard-generation-complete'
        }
        
        It "Should have 6 sequence items" {
            $script:Playbook.Sequence.Count | Should -Be 6
        }
        
        It "Should accurately describe sequential execution" {
            $script:Playbook.Description | Should -Match 'sequential'
            $script:Playbook.Description | Should -Not -Match 'parallel'
        }
        
        It "Should have appropriate estimated duration for sequential execution" {
            # 5 collection scripts × 60s + 1 dashboard script × 120s = 420s minimum
            # EstimatedDuration should be >= 420s
            $duration = [int]($script:Playbook.Metadata.EstimatedDuration -replace '[^\d]','')
            $duration | Should -BeGreaterOrEqual 420
        }
        
        It "Should have Parallel set to false" {
            $script:Playbook.Options.Parallel | Should -Be $false
        }
    }
    
    Context "Parameter name validation for each script" {
        
        It "Should have correct parameters for script <ScriptNum> (<Description>)" -TestCases @(
            @{ ScriptNum = '0520'; Description = 'Ring metrics collection' }
            @{ ScriptNum = '0521'; Description = 'Workflow health metrics collection' }
            @{ ScriptNum = '0522'; Description = 'Code metrics collection' }
            @{ ScriptNum = '0523'; Description = 'Test metrics collection' }
            @{ ScriptNum = '0524'; Description = 'Quality metrics collection' }
            @{ ScriptNum = '0525'; Description = 'Dashboard HTML generation' }
        ) {
            param($ScriptNum, $Description)
            
            $scriptInfo = $script:ExpectedParameters[$ScriptNum]
            
            # Find the sequence item for this script
            $seqItem = $script:Playbook.Sequence | Where-Object { $_.Script -eq $ScriptNum }
            
            $seqItem | Should -Not -BeNullOrEmpty -Because "Script $ScriptNum should be in the sequence"
            
            # Verify all expected parameters are present
            foreach ($expectedParam in $scriptInfo.ExpectedParams) {
                $seqItem.Parameters.Keys | Should -Contain $expectedParam -Because "Script $ScriptNum requires parameter '$expectedParam'"
            }
        }
        
        It "Should NOT use deprecated OutputDir parameter for script <ScriptNum>" -TestCases @(
            @{ ScriptNum = '0520' }
            @{ ScriptNum = '0521' }
            @{ ScriptNum = '0522' }
            @{ ScriptNum = '0523' }
            @{ ScriptNum = '0524' }
            @{ ScriptNum = '0525' }
        ) {
            param($ScriptNum)
            
            $seqItem = $script:Playbook.Sequence | Where-Object { $_.Script -eq $ScriptNum }
            $seqItem.Parameters.Keys | Should -Not -Contain 'OutputDir' -Because "OutputDir is not a valid parameter (should be OutputPath)"
        }
        
        It "Should NOT use deprecated MetricsDir parameter for script 0525" {
            $seqItem = $script:Playbook.Sequence | Where-Object { $_.Script -eq '0525' }
            $seqItem.Parameters.Keys | Should -Not -Contain 'MetricsDir' -Because "MetricsDir is not a valid parameter (should be MetricsPath)"
        }
    }
    
    Context "Script parameter extraction from actual files" {
        
        It "Script <ScriptNum> actual parameters should match playbook" -TestCases @(
            @{ ScriptNum = '0520' }
            @{ ScriptNum = '0521' }
            @{ ScriptNum = '0522' }
            @{ ScriptNum = '0523' }
            @{ ScriptNum = '0524' }
            @{ ScriptNum = '0525' }
        ) {
            param($ScriptNum)
            
            $scriptInfo = $script:ExpectedParameters[$ScriptNum]
            
            if (Test-Path $scriptInfo.ScriptPath) {
                # Parse the script to extract actual param block
                $content = Get-Content $scriptInfo.ScriptPath -Raw
                
                # Extract param block using regex
                if ($content -match '(?s)param\s*\((.*?)\)') {
                    $paramBlock = $Matches[1]
                    
                    # Verify each expected parameter exists in the script
                    foreach ($expectedParam in $scriptInfo.ExpectedParams) {
                        $paramBlock | Should -Match "\[\w+\]\`$$expectedParam" -Because "Script $ScriptNum should define parameter $expectedParam"
                    }
                }
                else {
                    Set-ItResult -Skipped -Because "Could not parse param block for script $ScriptNum"
                }
            }
            else {
                Set-ItResult -Skipped -Because "Script file not found: $($scriptInfo.ScriptPath)"
            }
        }
    }
    
    Context "Common configuration validation" {
        
        It "Should have consistent timeout values for metrics collection scripts (0520-0524)" {
            $metricsScripts = $script:Playbook.Sequence | Where-Object { $_.Script -match '^052[0-4]$' }
            
            $metricsScripts | Should -HaveCount 5
            
            foreach ($script in $metricsScripts) {
                $script.Timeout | Should -Be 60 -Because "All metrics collection scripts should have 60s timeout"
            }
        }
        
        It "Should have consistent ContinueOnError setting for metrics collection scripts (0520-0524)" {
            $metricsScripts = $script:Playbook.Sequence | Where-Object { $_.Script -match '^052[0-4]$' }
            
            foreach ($script in $metricsScripts) {
                $script.ContinueOnError | Should -Be $true -Because "All metrics collection scripts should continue on error"
            }
        }
        
        It "Should have ContinueOnError=false for dashboard generation (0525)" {
            $dashboardScript = $script:Playbook.Sequence | Where-Object { $_.Script -eq '0525' }
            $dashboardScript.ContinueOnError | Should -Be $false -Because "Dashboard generation should fail fast if it encounters errors"
        }
        
        It "Should document why metrics scripts have identical configuration" {
            # Check if there's a comment explaining the identical configuration
            $playbookContent = Get-Content (Join-Path $script:ProjectRoot "library/playbooks/dashboard-generation-complete.psd1") -Raw
            
            $playbookContent | Should -Match 'Common configuration' -Because "Identical configuration should be documented"
            $playbookContent | Should -Match 'ContinueOnError' -Because "ContinueOnError rationale should be explained"
        }
    }
    
    Context "Output path consistency" {
        
        It "Should use consistent metrics directory across all collection scripts" {
            $metricsScripts = $script:Playbook.Sequence | Where-Object { $_.Script -match '^052[0-4]$' }
            
            foreach ($script in $metricsScripts) {
                $outputPath = $script.Parameters.OutputPath
                $outputPath | Should -Match '^reports/metrics/' -Because "All metrics should be written to reports/metrics/"
            }
        }
        
        It "Should configure dashboard script to read from metrics directory" {
            $dashboardScript = $script:Playbook.Sequence | Where-Object { $_.Script -eq '0525' }
            
            $dashboardScript.Parameters.MetricsPath | Should -Be 'reports/metrics' -Because "Dashboard should read from the same directory where metrics are written"
        }
        
        It "Should write dashboard to dedicated dashboard directory" {
            $dashboardScript = $script:Playbook.Sequence | Where-Object { $_.Script -eq '0525' }
            
            $dashboardScript.Parameters.OutputPath | Should -Match '^reports/dashboard/' -Because "Dashboard HTML should be written to reports/dashboard/"
        }
    }
}
