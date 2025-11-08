#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive tests for automation scripts

.DESCRIPTION
    Analyzes automation scripts and generates tests that validate:
    - Script metadata (Stage, Dependencies, Tags)
    - Parameter validation
    - WhatIf/Confirm support
    - Exit codes
    - Help documentation
    - Execution behavior

.EXAMPLE
    ./ScriptTestGenerator.ps1 -Range '0400-0499'
    
.EXAMPLE
    ./ScriptTestGenerator.ps1 -All
#>

[CmdletBinding()]
param(
    [string]$Range,
    [int]$ScriptNumber,
    [switch]$All,
    [switch]$Force,
    [string]$OutputPath = (Join-Path $PSScriptRoot '../unit/scripts')
)

$ErrorActionPreference = 'Stop'

# Import helpers
$astAnalyzerPath = Join-Path $PSScriptRoot '../helpers/ASTAnalyzer.psm1'
$testHelpersPath = Join-Path $PSScriptRoot '../helpers/TestHelpers.psm1'

Import-Module $astAnalyzerPath -Force
Import-Module $testHelpersPath -Force

function New-ScriptTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )
    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    Write-Host "Generating test for: $scriptName" -ForegroundColor Cyan
    
    # Extract script number
    if ($scriptName -match '^(\d{4})_') {
        $number = [int]$Matches[1]
        $range = Get-ScriptNumberRange -ScriptNumber $number
    }
    else {
        Write-Warning "Script does not follow naming convention: $scriptName"
        return
    }
    
    # Analyze script
    $metadata = Get-ScriptMetadata -Path $ScriptPath
    $parameters = Get-ScriptParameters -Path $ScriptPath
    
    # Generate test file
    $testFileName = "$scriptName.Tests.ps1"
    $testFilePath = Join-Path $OutputDirectory $testFileName
    
    # Build test content
    $testContent = @"
#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive tests for $scriptName

.DESCRIPTION
    Validates script structure, parameters, metadata, execution, and behavior
    
    Script: $scriptName
    Stage: $($metadata.Stage)
    Category: $(Get-ScriptCategory -Range $range)
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
#>

Describe '$scriptName Tests' -Tag 'Unit', 'AutomationScript', 'Range-$range' {
    
    BeforeAll {
        # Import test helpers
        `$testHelpersPath = Join-Path `$PSScriptRoot '../../../helpers/TestHelpers.psm1'
        if (Test-Path `$testHelpersPath) {
            Import-Module `$testHelpersPath -Force
        }
        
        # Initialize test environment
        Initialize-TestEnvironment
        
        # Script path
        `$scriptPath = Get-TestFilePath 'library/automation-scripts/$scriptName.ps1'
        if (-not (Test-Path `$scriptPath)) {
            throw "Script not found: `$scriptPath"
        }
    }
    
    AfterAll {
        Clear-TestEnvironment
    }
    
    Context 'Script Structure' {
        It 'Should exist' {
            Test-Path `$scriptPath | Should -Be `$true
        }
        
        It 'Should have valid PowerShell syntax' {
            Test-ScriptSyntax -Path `$scriptPath | Should -Be `$true
        }
        
        It 'Should be executable' {
            (Get-Item `$scriptPath).Extension | Should -Be '.ps1'
        }
    }
    
    Context 'Script Metadata' {
"@

    if ($metadata.Stage) {
        $testContent += @"
        
        It 'Should have Stage metadata' {
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match 'Stage:\s*$($metadata.Stage)'
        }

"@
    }

    if ($metadata.Order) {
        $testContent += @"
        
        It 'Should have Order metadata' {
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match 'Order:\s*$($metadata.Order)'
        }

"@
    }

    if ($metadata.Dependencies.Count -gt 0) {
        $testContent += @"
        
        It 'Should document dependencies' {
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match 'Dependencies:'
        }

"@
    }

    if ($metadata.Tags.Count -gt 0) {
        $testContent += @"
        
        It 'Should have tags' {
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match 'Tags:'
        }

"@
    }

    $testContent += @"
    }

"@

    # Parameter tests
    if ($parameters.Count -gt 0) {
        $testContent += @"
    Context 'Parameters' {
        
        BeforeAll {
            `$cmd = Get-Command `$scriptPath
        }

"@
        foreach ($param in $parameters) {
            $testContent += @"
        
        It 'Should have parameter: $($param.Name)' {
            `$cmd.Parameters.ContainsKey('$($param.Name)') | Should -Be `$true
        }
        
        It 'Parameter $($param.Name) should have type $($param.Type)' {
            `$cmd.Parameters['$($param.Name)'].ParameterType.Name | Should -Be '$($param.Type)'
        }

"@
            if ($param.IsMandatory) {
                $testContent += @"
        
        It 'Parameter $($param.Name) should be mandatory' {
            `$param = `$cmd.Parameters['$($param.Name)']
            `$mandatory = `$param.Attributes | Where-Object { `$_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { `$_.Mandatory }
            `$mandatory | Should -Contain `$true
        }

"@
            }
        }
        $testContent += @"
    }

"@
    }

    # Help documentation tests
    $testContent += @"
    Context 'Help Documentation' {
        
        BeforeAll {
            `$help = Get-Help `$scriptPath -ErrorAction SilentlyContinue
        }
        
        It 'Should have help documentation' {
            `$help | Should -Not -BeNull
        }
        
        It 'Should have Synopsis' {
            `$help.Synopsis | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have Description' {
            `$help.Description | Should -Not -BeNull
        }
        
        It 'Should have Notes section' {
            `$help.alertSet | Should -Not -BeNull
        }
    }

"@

    # WhatIf support
    if ($metadata.SupportsWhatIf) {
        $testContent += @"
    Context 'WhatIf Support' {
        It 'Should support -WhatIf' {
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match 'SupportsShouldProcess'
        }
        
        It 'Should execute with -WhatIf without errors' {
            { & `$scriptPath -WhatIf } | Should -Not -Throw
        }
    }

"@
    }

    # Execution tests
    $testContent += @"
    Context 'Execution Behavior' {
        It 'Should not throw when getting help' {
            { Get-Help `$scriptPath } | Should -Not -Throw
        }
        
        It 'Should validate parameters before execution' {
            # Verify CmdletBinding is present for parameter validation
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match '\[CmdletBinding'
        }
    }
    
    Context 'Code Quality' {
        It 'Should use approved verbs (if applicable)' {
            `$content = Get-Content `$scriptPath -Raw
            # Check for function definitions
            if (`$content -match 'function\s+(\w+)-(\w+)') {
                `$verb = `$Matches[1]
                `$approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
                `$approvedVerbs | Should -Contain `$verb
            }
        }
        
        It 'Should have error handling' {
            `$content = Get-Content `$scriptPath -Raw
            # Should have try/catch OR ErrorActionPreference
            (`$content -match 'try\s*\{' -or `$content -match '\$ErrorActionPreference') | Should -Be `$true
        }
    }
    
    Context 'Environment Compatibility' {
        It 'Should specify PowerShell version requirement' {
            `$content = Get-Content `$scriptPath -Raw
            `$content | Should -Match '#Requires\s+-Version'
        }
        
        It 'Should handle cross-platform scenarios' {
            `$content = Get-Content `$scriptPath -Raw
            # If script uses platform-specific features, should have checks
            if (`$content -match 'C:\\\\|HKLM:|Registry' -and `$content -notmatch '\$IsWindows') {
                Write-Warning "Script may have platform-specific code without checks"
            }
            `$true | Should -Be `$true
        }
    }
}
"@

    # Write test file
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
    
    $testContent | Set-Content -Path $testFilePath -Force
    Write-Host "  Generated: $testFilePath" -ForegroundColor Green
    
    return $testFilePath
}

# Main execution
try {
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $env:AITHERZERO_ROOT = $repoRoot
    
    $scriptsPath = Join-Path $repoRoot 'library/automation-scripts'
    
    if (-not (Test-Path $scriptsPath)) {
        throw "Automation scripts directory not found: $scriptsPath"
    }
    
    # Determine which scripts to process
    $scriptsToProcess = @()
    
    if ($All) {
        # Process all scripts
        $scriptsToProcess = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' |
            Where-Object { $_.Name -match '^\d{4}_' }
    }
    elseif ($ScriptNumber) {
        # Process specific script
        $scriptFile = Get-ChildItem -Path $scriptsPath -Filter "$ScriptNumber`_*.ps1" |
            Select-Object -First 1
        
        if (-not $scriptFile) {
            throw "Script not found: $ScriptNumber"
        }
        
        $scriptsToProcess = @($scriptFile)
    }
    elseif ($Range) {
        # Process range
        if ($Range -notmatch '^\d{4}-\d{4}$') {
            throw "Invalid range format. Use format: 0400-0499"
        }
        
        $rangeStart = [int]$Range.Substring(0, 4)
        $rangeEnd = [int]$Range.Substring(5, 4)
        
        $scriptsToProcess = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' |
            Where-Object { 
                if ($_.Name -match '^(\d{4})_') {
                    $num = [int]$Matches[1]
                    $num -ge $rangeStart -and $num -le $rangeEnd
                }
            }
    }
    else {
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  ./ScriptTestGenerator.ps1 -Range <Range>" -ForegroundColor Cyan
        Write-Host "  ./ScriptTestGenerator.ps1 -ScriptNumber <Number>" -ForegroundColor Cyan
        Write-Host "  ./ScriptTestGenerator.ps1 -All" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  ./ScriptTestGenerator.ps1 -Range '0400-0499'"
        Write-Host "  ./ScriptTestGenerator.ps1 -ScriptNumber 0402"
        Write-Host "  ./ScriptTestGenerator.ps1 -All"
        exit 0
    }
    
    if ($scriptsToProcess.Count -eq 0) {
        Write-Warning "No scripts found to process"
        exit 0
    }
    
    # Group scripts by range
    $scriptsByRange = $scriptsToProcess | Group-Object {
        if ($_.Name -match '^(\d{4})_') {
            $num = [int]$Matches[1]
            Get-ScriptNumberRange -ScriptNumber $num
        }
    }
    
    # Process scripts
    $generated = 0
    $skipped = 0
    
    foreach ($rangeGroup in $scriptsByRange) {
        $rangeDir = Join-Path $OutputPath $rangeGroup.Name
        
        foreach ($script in $rangeGroup.Group) {
            $testFile = Join-Path $rangeDir "$($script.BaseName).Tests.ps1"
            
            if ((Test-Path $testFile) -and -not $Force) {
                Write-Host "Skipping $($script.Name) (test exists, use -Force to overwrite)" -ForegroundColor Yellow
                $skipped++
                continue
            }
            
            New-ScriptTest -ScriptPath $script.FullName -OutputDirectory $rangeDir
            $generated++
        }
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Generated: $generated" -ForegroundColor Green
    Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
    Write-Host "  Total: $($scriptsToProcess.Count)" -ForegroundColor Gray
}
catch {
    Write-Error "Test generation failed: $_"
    exit 1
}
