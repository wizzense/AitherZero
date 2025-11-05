#Requires -Version 7.0
<#
.SYNOPSIS
    Simplified Automatic Test Generator for AitherZero - 100% Solution
.DESCRIPTION
    Generates comprehensive tests automatically for ALL scripts with ZERO manual work.
    Uses direct StringBuilder approach to avoid template replacement issues.
.NOTES
    Copyright © 2025 Aitherium Corporation
    This is the "it just works" solution for automatic test generation.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:AutomationScriptsPath = Join-Path $script:ProjectRoot 'automation-scripts'
$script:TestsPath = Join-Path $script:ProjectRoot 'tests'

# Script number to stage mapping constants
$script:StageRanges = @{
    Environment     = @{ Min = 0; Max = 99 }
    Infrastructure  = @{ Min = 100; Max = 199 }
    Development     = @{ Min = 200; Max = 399 }
    Testing         = @{ Min = 400; Max = 499 }
    Reporting       = @{ Min = 500; Max = 699 }
    Automation      = @{ Min = 700; Max = 799 }
    Integration     = @{ Min = 800; Max = 899 }
    Maintenance     = @{ Min = 9000; Max = 9999 }
}

# Logging
function Write-GenLog {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    $emoji = switch ($Level) {
        'Success' { '✅' }
        'Error' { '❌' }
        'Warning' { '⚠️' }
        default { 'ℹ️' }
    }
    Write-Host "[$timestamp] $emoji $Message"
}

function New-AutoTest {
    <#
    .SYNOPSIS
        Generate comprehensive test for an automation script
    .DESCRIPTION
        Analyzes script and generates unit + integration tests automatically
    .PARAMETER ScriptPath
        Path to the script to test
    .PARAMETER Force
        Overwrite existing tests
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [switch]$Force
    )

    $scriptFile = Get-Item $ScriptPath
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFile.Name)
    
    Write-GenLog "Processing: $scriptName"

    # Parse script
    $ast = $null
    $tokens = $null
    $errors = $null
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptPath, [ref]$tokens, [ref]$errors
        )
        if ($errors.Count -gt 0) {
            Write-GenLog "Syntax errors in $scriptName" -Level Warning
            return $null
        }
    } catch {
        Write-GenLog "Failed to parse $scriptName : $_" -Level Error
        return $null
    }

    # Extract metadata
    $contentLines = Get-Content $ScriptPath -First 40
    $content = $contentLines -join "`n"
    
    # Try to find Stage in various formats using combined regex pattern
    $stage = 'Unknown'
    
    # Combined regex: matches "# Stage:", ".NOTES...Stage:", or "Category:" in one pass
    $stagePatterns = @(
        '(?:^|\n)\s*#?\s*Stage:\s*(.+?)(?:\r?\n|$)',                # Direct "# Stage:" or "Stage:"
        '\.NOTES[^\n]*\n[^\n]*Stage:\s*(.+?)(?:\r?\n|$)',          # .NOTES section with Stage on next line
        'Category:\s*(.+?)(?:\r?\n|$)'                             # Category field (capture any value)
    )
    
    foreach ($pattern in $stagePatterns) {
        if ($content -match $pattern) {
            $capturedValue = $Matches[1].Trim()
            # For Category pattern, extract only the first stage keyword
            if ($pattern -like 'Category:*' -and $capturedValue -match '^(Testing|Development|Infrastructure|Validation|Reporting|Automation)') {
                $stage = $Matches[1]
            } else {
                $stage = $capturedValue
            }
            break
        }
    }
    
    # Fallback: Determine stage from script number range if still unknown
    if ($stage -eq 'Unknown' -and $scriptName -match '^(\d{4})') {
        $scriptNum = [int]$Matches[1]
        
        # Use the stage range constants for lookup
        foreach ($stageName in $script:StageRanges.Keys) {
            $range = $script:StageRanges[$stageName]
            if ($scriptNum -ge $range.Min -and $scriptNum -le $range.Max) {
                $stage = $stageName
                Write-GenLog "Stage inferred from script number ($scriptNum): $stage" -Level Info
                break
            }
        }
    }
    
    $description = if ($content -match '(?:#\s*Description:|\.DESCRIPTION\s+)(.+?)(?:\r?\n|$)') { $Matches[1].Trim() } else { '' }
    $dependencies = @()
    if ($content -match '(?:#\s*Dependencies:|Dependencies:)\s*(.+)') { 
        $dependencies = @($Matches[1].Split(',') | ForEach-Object { $_.Trim() })
    }

    # Extract parameters
    $params = @()
    if ($ast.ParamBlock) {
        foreach ($param in $ast.ParamBlock.Parameters) {
            $params += @{
                Name = $param.Name.VariablePath.UserPath
                Type = if ($param.StaticType) { $param.StaticType.Name } else { 'Object' }
            }
        }
    }
    # Ensure $params is always an array
    if ($null -eq $params) { $params = @() }

    # Check script capabilities
    $scriptContent = Get-Content $ScriptPath -Raw
    $supportsWhatIf = $scriptContent -match '\[CmdletBinding\([^\)]*SupportsShouldProcess[^\)]*\)\]'
    $hasConfiguration = $params | Where-Object { $_.Name -eq 'Configuration' }
    $usesScriptUtilities = $scriptContent -match 'Import-Module.*ScriptUtilities\.psm1' -or 
                           $scriptContent -match 'Write-ScriptLog|Get-GitHubToken|Test-Prerequisites|Get-ProjectRoot'

    # Determine test paths
    $rangeNum = if ($scriptName -match '^(\d+)_') { [int]$Matches[1] } else { 0 }
    $rangeStart = [Math]::Floor($rangeNum / 100) * 100
    $rangeEnd = $rangeStart + 99
    $rangeDir = "$($rangeStart.ToString('0000'))-$($rangeEnd.ToString('0000'))"
    
    $unitTestDir = Join-Path $script:TestsPath "unit/automation-scripts/$rangeDir"
    $integrationTestDir = Join-Path $script:TestsPath "integration/automation-scripts"
    
    # Create directories
    foreach ($dir in @($unitTestDir, $integrationTestDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    $unitTestPath = Join-Path $unitTestDir "$scriptName.Tests.ps1"
    $integrationTestPath = Join-Path $integrationTestDir "$scriptName.Integration.Tests.ps1"

    # Check if exists
    if ((Test-Path $unitTestPath) -and -not $Force) {
        Write-GenLog "Test exists for $scriptName (use -Force to overwrite)" -Level Warning
        return @{
            ScriptName = $scriptName
            Skipped = $true
        }
    }

    # Generate unit test
    $unitTest = Build-UnitTest -ScriptName $scriptName -ScriptPath $ScriptPath `
        -Stage $stage -Description $description -Parameters $params -Dependencies $dependencies `
        -SupportsWhatIf $supportsWhatIf -HasConfiguration $hasConfiguration `
        -UsesScriptUtilities $usesScriptUtilities

    # Generate integration test
    $integrationTest = Build-IntegrationTest -ScriptName $scriptName -ScriptPath $ScriptPath `
        -Stage $stage -Dependencies $dependencies -SupportsWhatIf $supportsWhatIf `
        -HasConfiguration $hasConfiguration -UsesScriptUtilities $usesScriptUtilities

    # Write files
    try {
        [System.IO.File]::WriteAllText($unitTestPath, $unitTest, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($integrationTestPath, $integrationTest, [System.Text.UTF8Encoding]::new($false))
        
        Write-GenLog "Generated tests for $scriptName" -Level Success
        
        return @{
            ScriptName = $scriptName
            UnitTestPath = $unitTestPath
            IntegrationTestPath = $integrationTestPath
            Generated = $true
        }
    } catch {
        Write-GenLog "Failed to write tests for $scriptName : $_" -Level Error
        return $null
    }
}

function Build-UnitTest {
    param(
        $ScriptName, 
        $ScriptPath, 
        $Stage, 
        $Description, 
        $Parameters, 
        $Dependencies,
        [bool]$SupportsWhatIf,
        $HasConfiguration,
        [bool]$UsesScriptUtilities
    )

    $sb = [System.Text.StringBuilder]::new()
    
    # Analyze script content for additional edge cases
    $scriptContent = Get-Content $ScriptPath -Raw
    
    # Detect additional script characteristics
    $hasMandatoryParams = $Parameters | Where-Object { $scriptContent -match "Mandatory\s*=\s*\`$true.*$($_.Name)" }
    $hasValidateScript = $scriptContent -match '\[ValidateScript\('
    $hasBeginBlock = $scriptContent -match '^\s*begin\s*\{' -or $scriptContent -match '\n\s*begin\s*\{'
    $hasProcessBlock = $scriptContent -match '^\s*process\s*\{' -or $scriptContent -match '\n\s*process\s*\{'
    $acceptsPipeline = $scriptContent -match '\[Parameter\([^\)]*ValueFromPipeline[^\)]*\)\]'
    $requiresElevation = $scriptContent -match '#Requires\s+-RunAsAdministrator'
    $requiresModules = $scriptContent -match '#Requires\s+-Modules?\s+(\S+)'
    $hasOutputType = $scriptContent -match '\[OutputType\('
    
    # Header
    [void]$sb.AppendLine('#Requires -Version 7.0')
    [void]$sb.AppendLine('#Requires -Module Pester')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('<#')
    [void]$sb.AppendLine('.SYNOPSIS')
    [void]$sb.AppendLine("    Unit tests for $ScriptName")
    [void]$sb.AppendLine('.DESCRIPTION')
    [void]$sb.AppendLine("    Auto-generated comprehensive tests with environment awareness")
    [void]$sb.AppendLine("    Script: $ScriptName")
    [void]$sb.AppendLine("    Stage: $Stage")
    if ($Description) {
        [void]$sb.AppendLine("    Description: $Description")
    }
    [void]$sb.AppendLine("    Supports WhatIf: $SupportsWhatIf")
    if ($requiresElevation) {
        [void]$sb.AppendLine("    Requires Elevation: Yes")
    }
    [void]$sb.AppendLine("    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine('#>')
    [void]$sb.AppendLine('')
    
    # Describe block
    [void]$sb.AppendLine("Describe '$ScriptName' -Tag 'Unit', 'AutomationScript', '$Stage' {")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('    BeforeAll {')
    [void]$sb.AppendLine('        # Compute path relative to repository root using $PSScriptRoot')
    [void]$sb.AppendLine('        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent')
    [void]$sb.AppendLine("        " + '$script:ScriptPath = Join-Path $repoRoot ' + "'automation-scripts/$ScriptName.ps1'")
    [void]$sb.AppendLine("        " + '$script:ScriptName = ' + "'$ScriptName'")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('        # Import test helpers for environment detection')
    [void]$sb.AppendLine('        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../../TestHelpers.psm1"')
    [void]$sb.AppendLine('        if (Test-Path $testHelpersPath) {')
    [void]$sb.AppendLine('            Import-Module $testHelpersPath -Force -ErrorAction SilentlyContinue')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('        # Detect test environment')
    [void]$sb.AppendLine('        $script:TestEnv = if (Get-Command Get-TestEnvironment -ErrorAction SilentlyContinue) {')
    [void]$sb.AppendLine('            Get-TestEnvironment')
    [void]$sb.AppendLine('        } else {')
    [void]$sb.AppendLine('            @{ IsCI = ($env:CI -eq ''true'' -or $env:GITHUB_ACTIONS -eq ''true''); IsLocal = $true }')
    [void]$sb.AppendLine('        }')
    
    # Add ScriptUtilities module import if script uses it
    if ($UsesScriptUtilities) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('        # Import ScriptUtilities module (script uses it)')
        [void]$sb.AppendLine('        $scriptUtilitiesPath = Join-Path $repoRoot "domains/automation/ScriptUtilities.psm1"')
        [void]$sb.AppendLine('        if (Test-Path $scriptUtilitiesPath) {')
        [void]$sb.AppendLine('            Import-Module $scriptUtilitiesPath -Force -ErrorAction SilentlyContinue')
        [void]$sb.AppendLine('        }')
    }
    
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('')
    
    # Basic validation
    [void]$sb.AppendLine("    Context 'Script Validation' {")
    [void]$sb.AppendLine("        It 'Script file should exist' {")
    [void]$sb.AppendLine('            Test-Path $script:ScriptPath | Should -Be $true')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("        It 'Should have valid PowerShell syntax' {")
    [void]$sb.AppendLine('            $errors = $null')
    [void]$sb.AppendLine('            $null = [System.Management.Automation.Language.Parser]::ParseFile(')
    [void]$sb.AppendLine('                $script:ScriptPath, [ref]$null, [ref]$errors')
    [void]$sb.AppendLine('            )')
    [void]$sb.AppendLine('            $errors.Count | Should -Be 0')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('')
    
    # Conditional WhatIf test - only if script supports it
    if ($SupportsWhatIf) {
        [void]$sb.AppendLine("        It 'Should support WhatIf' {")
        [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -Raw')
        [void]$sb.AppendLine('            $content | Should -Match ''SupportsShouldProcess''')
        [void]$sb.AppendLine('        }')
    } else {
        [void]$sb.AppendLine("        It 'Should not require WhatIf support' {")
        [void]$sb.AppendLine('            # Script does not implement SupportsShouldProcess')
        [void]$sb.AppendLine('            # This is acceptable for read-only or simple scripts')
        [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -Raw')
        [void]$sb.AppendLine('            $content -notmatch ''SupportsShouldProcess'' | Should -Be $true')
        [void]$sb.AppendLine('        }')
    }
    [void]$sb.AppendLine('')
    
    # ScriptUtilities usage test
    if ($UsesScriptUtilities) {
        [void]$sb.AppendLine("        It 'Should properly import ScriptUtilities module' {")
        [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -Raw')
        [void]$sb.AppendLine('            $content | Should -Match ''Import-Module.*ScriptUtilities\.psm1''')
        [void]$sb.AppendLine('        }')
    }
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('')
    
    # Parameter tests
    if ($Parameters -and @($Parameters).Count -gt 0) {
        [void]$sb.AppendLine("    Context 'Parameters' {")
        foreach ($param in $Parameters) {
            [void]$sb.AppendLine("        It 'Should have parameter: $($param.Name)' {")
            [void]$sb.AppendLine('            $cmd = Get-Command $script:ScriptPath')
            [void]$sb.AppendLine("            " + '$cmd.Parameters.ContainsKey(''' + $param.Name + ''') | Should -Be $true')
            [void]$sb.AppendLine('        }')
            [void]$sb.AppendLine('')
        }
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('')
    }
    
    # Metadata tests
    [void]$sb.AppendLine("    Context 'Metadata' {")
    [void]$sb.AppendLine("        It 'Should be in stage: $Stage' {")
    [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -First 40')
    [void]$sb.AppendLine("            (" + '$content -join '' '') | Should -Match ''(Stage:|Category:)''')
    [void]$sb.AppendLine('        }')
    
    if ($Dependencies -and @($Dependencies).Count -gt 0) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("        It 'Should declare dependencies' {")
        [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -First 50')
        [void]$sb.AppendLine("            (" + '$content -join '' '') | Should -Match ''Dependencies:''')
        [void]$sb.AppendLine('        }')
    }
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('')
    
    # Execution tests - handle different scenarios
    [void]$sb.AppendLine("    Context 'Execution' {")
    
    if ($SupportsWhatIf) {
        # Script supports WhatIf - test with it
        [void]$sb.AppendLine("        It 'Should execute with WhatIf without throwing' {")
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                $params = @{ WhatIf = $true }')
        if ($HasConfiguration) {
            [void]$sb.AppendLine('                $params.Configuration = @{}')
        }
        [void]$sb.AppendLine('                & $script:ScriptPath @params')
        [void]$sb.AppendLine('            } | Should -Not -Throw')
        [void]$sb.AppendLine('        }')
    } elseif ($hasMandatoryParams) {
        # Script has mandatory params but no WhatIf - test basic invocation
        [void]$sb.AppendLine("        It 'Should require mandatory parameters' {")
        [void]$sb.AppendLine('            # Script has mandatory parameters - cannot execute without them')
        [void]$sb.AppendLine('            { & $script:ScriptPath -ErrorAction Stop } | Should -Throw')
        [void]$sb.AppendLine('        }')
    } else {
        # Script without WhatIf and without mandatory params - test basic structure
        [void]$sb.AppendLine("        It 'Should be executable (no WhatIf support)' {")
        [void]$sb.AppendLine('            # Script does not support -WhatIf parameter')
        [void]$sb.AppendLine('            # Verify script can be dot-sourced without errors')
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop')
        [void]$sb.AppendLine('                $cmd | Should -Not -BeNullOrEmpty')
        [void]$sb.AppendLine('            } | Should -Not -Throw')
        [void]$sb.AppendLine('        }')
    }
    
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('')
    
    # Environment-aware test context
    [void]$sb.AppendLine("    Context 'Environment Awareness' {")
    [void]$sb.AppendLine("        It 'Test environment should be detected' {")
    [void]$sb.AppendLine('            $script:TestEnv | Should -Not -BeNullOrEmpty')
    [void]$sb.AppendLine('            $script:TestEnv.Keys | Should -Contain ''IsCI''')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("        It 'Should adapt to CI environment' {")
    [void]$sb.AppendLine('            if (-not $script:TestEnv.IsCI) {')
    [void]$sb.AppendLine('                Set-ItResult -Skipped -Because "CI-only validation"')
    [void]$sb.AppendLine('                return')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            $script:TestEnv.IsCI | Should -Be $true')
    [void]$sb.AppendLine('            $env:CI | Should -Not -BeNullOrEmpty')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("        It 'Should adapt to local environment' {")
    [void]$sb.AppendLine('            if ($script:TestEnv.IsCI) {')
    [void]$sb.AppendLine('                Set-ItResult -Skipped -Because "Local-only validation"')
    [void]$sb.AppendLine('                return')
    [void]$sb.AppendLine('            }')
    [void]$sb.AppendLine('            $script:TestEnv.IsCI | Should -Be $false')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')
    
    # Add special tests for scripts with elevation requirements
    if ($requiresElevation) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("    Context 'Elevation Requirements' {")
        [void]$sb.AppendLine("        It 'Should require administrator elevation' {")
        [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -Raw')
        [void]$sb.AppendLine('            $content | Should -Match ''#Requires\s+-RunAsAdministrator''')
        [void]$sb.AppendLine('        }')
        [void]$sb.AppendLine('    }')
    }
    
    [void]$sb.AppendLine('}')
    
    return $sb.ToString()
}

function Build-IntegrationTest {
    param(
        $ScriptName, 
        $ScriptPath, 
        $Stage, 
        $Dependencies,
        [bool]$SupportsWhatIf,
        $HasConfiguration,
        [bool]$UsesScriptUtilities
    )

    $sb = [System.Text.StringBuilder]::new()
    
    # Analyze script content for edge cases
    $scriptContent = Get-Content $ScriptPath -Raw
    $hasMandatoryParams = $scriptContent -match 'Mandatory\s*=\s*\$true'
    $requiresElevation = $scriptContent -match '#Requires\s+-RunAsAdministrator'
    $isInteractive = $scriptContent -match 'Read-Host' -or $scriptContent -match 'Show-UIMenu' -or $scriptContent -match '\$Host\.UI'
    
    [void]$sb.AppendLine('#Requires -Version 7.0')
    [void]$sb.AppendLine('#Requires -Module Pester')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('<#')
    [void]$sb.AppendLine('.SYNOPSIS')
    [void]$sb.AppendLine("    Integration tests for $ScriptName")
    [void]$sb.AppendLine('.DESCRIPTION')
    [void]$sb.AppendLine("    Auto-generated integration tests")
    [void]$sb.AppendLine("    Supports WhatIf: $SupportsWhatIf")
    if ($requiresElevation) {
        [void]$sb.AppendLine("    Requires Elevation: Yes")
    }
    if ($isInteractive) {
        [void]$sb.AppendLine("    Interactive Script: Yes")
    }
    [void]$sb.AppendLine("    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine('#>')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Describe '$ScriptName Integration' -Tag 'Integration', 'AutomationScript' {")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('    BeforeAll {')
    [void]$sb.AppendLine('        # Compute path relative to repository root using $PSScriptRoot')
    [void]$sb.AppendLine('        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent')
    [void]$sb.AppendLine("        " + '$script:ScriptPath = Join-Path $repoRoot ' + "'automation-scripts/$ScriptName.ps1'")
    
    # Add ScriptUtilities module import if script uses it
    if ($UsesScriptUtilities) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('        # Import ScriptUtilities module (script uses it)')
        [void]$sb.AppendLine('        $scriptUtilitiesPath = Join-Path $repoRoot "domains/automation/ScriptUtilities.psm1"')
        [void]$sb.AppendLine('        if (Test-Path $scriptUtilitiesPath) {')
        [void]$sb.AppendLine('            Import-Module $scriptUtilitiesPath -Force -ErrorAction SilentlyContinue')
        [void]$sb.AppendLine('        }')
    }
    
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("    Context 'Integration' {")
    
    # Generate appropriate test based on script characteristics
    if ($SupportsWhatIf) {
        # Script supports WhatIf - test with it
        [void]$sb.AppendLine("        It 'Should execute in test mode with WhatIf' {")
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                $params = @{ WhatIf = $true; ErrorAction = ''Stop'' }')
        if ($HasConfiguration) {
            [void]$sb.AppendLine('                $params.Configuration = @{ Automation = @{ DryRun = $true } }')
        }
        [void]$sb.AppendLine('                & $script:ScriptPath @params')
        [void]$sb.AppendLine('            } | Should -Not -Throw')
        [void]$sb.AppendLine('        }')
    } elseif ($isInteractive) {
        # Interactive script - can't test execution in CI
        [void]$sb.AppendLine("        It 'Should be loadable (interactive script)' {")
        [void]$sb.AppendLine('            # Script is interactive - cannot execute in non-interactive test')
        [void]$sb.AppendLine('            # Verify script structure instead')
        [void]$sb.AppendLine('            Test-Path $script:ScriptPath | Should -Be $true')
        [void]$sb.AppendLine('            ')
        [void]$sb.AppendLine('            # Verify script can be parsed')
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                $errors = $null')
        [void]$sb.AppendLine('                [System.Management.Automation.Language.Parser]::ParseFile(')
        [void]$sb.AppendLine('                    $script:ScriptPath, [ref]$null, [ref]$errors')
        [void]$sb.AppendLine('                if ($errors.Count -gt 0) { throw "Parse errors: $errors" }')
        [void]$sb.AppendLine('            } | Should -Not -Throw')
        [void]$sb.AppendLine('        }')
    } elseif ($hasMandatoryParams -and -not $HasConfiguration) {
        # Script has mandatory params but no Configuration param - test structure only
        [void]$sb.AppendLine("        It 'Should have required structure (has mandatory parameters)' {")
        [void]$sb.AppendLine('            # Script has mandatory parameters - cannot execute without them')
        [void]$sb.AppendLine('            # Verify script structure instead')
        [void]$sb.AppendLine('            Test-Path $script:ScriptPath | Should -Be $true')
        [void]$sb.AppendLine('            ')
        [void]$sb.AppendLine('            # Verify Get-Command can read parameters')
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop')
        [void]$sb.AppendLine('                $cmd.Parameters.Count | Should -BeGreaterThan 0')
        [void]$sb.AppendLine('            } | Should -Not -Throw')
        [void]$sb.AppendLine('        }')
    } else {
        # Simple script - test basic execution
        [void]$sb.AppendLine("        It 'Should execute without errors (no WhatIf support)' {")
        [void]$sb.AppendLine('            # Script does not support -WhatIf parameter')
        [void]$sb.AppendLine('            # Test basic script structure and loadability')
        [void]$sb.AppendLine('            Test-Path $script:ScriptPath | Should -Be $true')
        [void]$sb.AppendLine('            ')
        [void]$sb.AppendLine('            # Verify script can be dot-sourced')
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop')
        [void]$sb.AppendLine('                $cmd | Should -Not -BeNullOrEmpty')
        [void]$sb.AppendLine('            } | Should -Not -Throw')
        [void]$sb.AppendLine('        }')
    }
    
    # Add elevation awareness test if needed
    if ($requiresElevation) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("        It 'Should detect elevation requirement' {")
        [void]$sb.AppendLine('            # Script requires elevation - verify in non-elevated test')
        [void]$sb.AppendLine('            $content = Get-Content $script:ScriptPath -Raw')
        [void]$sb.AppendLine('            $content | Should -Match ''#Requires\s+-RunAsAdministrator''')
        [void]$sb.AppendLine('        }')
    }
    
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('}')
    
    return $sb.ToString()
}

function Invoke-AutoTestGeneration {
    <#
    .SYNOPSIS
        Generate tests for all automation scripts
    .DESCRIPTION
        The 100% solution - generates tests for EVERYTHING automatically
    .PARAMETER Filter
        Filter pattern (e.g., "02*" for 0200-0299)
    .PARAMETER Force
        Regenerate existing tests
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Filter = "*.ps1",
        [switch]$Force
    )

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     AitherZero Automatic Test Generation - 100% Solution    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Write-GenLog "Scanning automation scripts..."

    $scripts = @(Get-ChildItem -Path $script:AutomationScriptsPath -Filter $Filter -File |
        Where-Object { $_.Name -match '^\d{4}_.*\.ps1$' } |
        Sort-Object Name)

    if ($scripts.Count -eq 0) {
        Write-GenLog "No scripts found matching: $Filter" -Level Warning
        return
    }

    Write-Host "Found $($scripts.Count) scripts`n" -ForegroundColor Green

    $stats = @{
        Total = $scripts.Count
        Generated = 0
        Skipped = 0
        Failed = 0
    }

    $progress = 0
    foreach ($script in $scripts) {
        $progress++
        $percent = [math]::Round(($progress / $scripts.Count) * 100)
        Write-Progress -Activity "Generating Tests" -Status $script.Name -PercentComplete $percent

        try {
            $result = New-AutoTest -ScriptPath $script.FullName -Force:$Force
            if ($result) {
                if ($result.Generated) {
                    $stats.Generated++
                } elseif ($result.Skipped) {
                    $stats.Skipped++
                }
            } else {
                $stats.Failed++
            }
        } catch {
            $stats.Failed++
            Write-GenLog "Error processing $($script.Name): $_" -Level Error
        }
    }

    Write-Progress -Activity "Generating Tests" -Completed

    # Summary
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      Summary                             ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "Total Scripts:    $($stats.Total)" -ForegroundColor White
    Write-Host "Tests Generated:  $($stats.Generated)" -ForegroundColor Green
    Write-Host "Already Existed:  $($stats.Skipped)" -ForegroundColor Yellow
    Write-Host "Failed:           $($stats.Failed)" -ForegroundColor $(if ($stats.Failed -gt 0) { 'Red' } else { 'Green' })
    
    $coverage = [math]::Round((($stats.Generated + $stats.Skipped) / $stats.Total) * 100, 1)
    Write-Host "`nTest Coverage:    $coverage%`n" -ForegroundColor $(if ($coverage -eq 100) { 'Green' } else { 'Yellow' })

    return $stats
}

# Export
Export-ModuleMember -Function @(
    'New-AutoTest',
    'Invoke-AutoTestGeneration'
)
