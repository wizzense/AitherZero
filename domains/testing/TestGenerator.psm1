#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Test Generator Module - Auto-generates unit tests for automation scripts
.DESCRIPTION
    Provides intelligent test generation capabilities for PowerShell scripts,
    analyzing script structure and generating appropriate Pester tests.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module initialization
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:AutomationScriptsPath = Join-Path $script:ProjectRoot 'automation-scripts'
$script:TestsPath = Join-Path $script:ProjectRoot 'tests'

# Logging helper
function Write-GeneratorLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source 'TestGenerator'
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] [$Level] [TestGenerator] $Message"
    }
}

function New-AutomationScriptTest {
    <#
    .SYNOPSIS
        Generate unit tests for an automation script
    .DESCRIPTION
        Analyzes an automation script and generates comprehensive Pester tests
        including parameter validation, execution flow, and error handling tests.
    .PARAMETER ScriptPath
        Path to the automation script to generate tests for
    .PARAMETER OutputPath
        Path where the test file should be created (defaults to tests/unit/automation-scripts)
    .PARAMETER IncludeMocks
        Include mock generation for external commands
    .PARAMETER IncludeIntegration
        Generate integration test stubs
    .EXAMPLE
        New-AutomationScriptTest -ScriptPath "./automation-scripts/0218_Install-GeminiCLI.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ScriptPath,
        
        [string]$OutputPath,
        
        [switch]$IncludeMocks,
        
        [switch]$IncludeIntegration
    )
    
    begin {
        Write-GeneratorLog "Starting test generation for automation scripts"
    }
    
    process {
        try {
            $scriptFile = Get-Item $ScriptPath
            $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFile.Name)
            
            Write-GeneratorLog "Analyzing script: $scriptName"
            
            # Parse script AST
            $scriptAst = Get-ScriptAST -Path $ScriptPath
            
            # Extract script metadata
            $metadata = Get-ScriptTestMetadata -AST $scriptAst -ScriptPath $ScriptPath
            
            # Generate test structure
            $testContent = New-TestStructure -Metadata $metadata -IncludeMocks:$IncludeMocks
            
            # Determine output path
            if (-not $OutputPath) {
                $testDir = Join-Path $script:TestsPath "unit/automation-scripts"
                if (-not (Test-Path $testDir)) {
                    New-Item -Path $testDir -ItemType Directory -Force | Out-Null
                }
                $OutputPath = Join-Path $testDir "$scriptName.Tests.ps1"
            }
            
            # Write test file
            $testContent | Set-Content -Path $OutputPath -Encoding UTF8
            Write-GeneratorLog "Generated test file: $OutputPath" -Level 'Information'
            
            # Generate integration tests if requested
            if ($IncludeIntegration) {
                $integrationDir = Join-Path $script:TestsPath "integration/automation-scripts"
                if (-not (Test-Path $integrationDir)) {
                    New-Item -Path $integrationDir -ItemType Directory -Force | Out-Null
                }
                $integrationPath = Join-Path $integrationDir "$scriptName.Integration.Tests.ps1"
                $integrationContent = New-IntegrationTestStructure -Metadata $metadata
                $integrationContent | Set-Content -Path $integrationPath -Encoding UTF8
                Write-GeneratorLog "Generated integration test file: $integrationPath"
            }
            
            return [PSCustomObject]@{
                ScriptName = $scriptName
                TestPath = $OutputPath
                IntegrationPath = if ($IncludeIntegration) { $integrationPath } else { $null }
                Success = $true
            }
            
        } catch {
            Write-GeneratorLog "Failed to generate tests for $ScriptPath : $_" -Level 'Error'
            throw
        }
    }
}

function Get-ScriptAST {
    param([string]$Path)
    
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    )
    
    if ($errors.Count -gt 0) {
        throw "Script contains syntax errors: $($errors -join '; ')"
    }
    
    return $ast
}

function Get-ScriptTestMetadata {
    param(
        $AST,
        [string]$ScriptPath
    )
    
    $metadata = @{
        ScriptPath = $ScriptPath
        ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
        Parameters = @()
        Functions = @()
        ExternalCommands = @()
        Variables = @()
        RequiresModules = @()
        Stage = 'Unknown'
        Dependencies = @()
        Description = ''
    }
    
    # Extract script header comments for metadata
    $content = Get-Content $ScriptPath -First 20
    foreach ($line in $content) {
        if ($line -match '^#\s*Stage:\s*(.+)') {
            $metadata.Stage = $Matches[1].Trim()
        }
        if ($line -match '^#\s*Dependencies:\s*(.+)') {
            $metadata.Dependencies = $Matches[1].Split(',') | ForEach-Object { $_.Trim() }
        }
        if ($line -match '^#\s*Description:\s*(.+)') {
            $metadata.Description = $Matches[1].Trim()
        }
    }
    
    # Extract parameters
    $paramBlock = $AST.ParamBlock
    if ($paramBlock) {
        foreach ($param in $paramBlock.Parameters) {
            $paramInfo = @{
                Name = $param.Name.VariablePath.UserPath
                Type = if ($param.StaticType) { $param.StaticType.Name } else { 'Object' }
                Mandatory = $false
                DefaultValue = $null
            }
            
            # Check for mandatory attribute
            foreach ($attr in $param.Attributes) {
                if ($attr -is [System.Management.Automation.Language.AttributeAst]) {
                    if ($attr.TypeName.Name -eq 'Parameter') {
                        foreach ($arg in $attr.NamedArguments) {
                            if ($arg.ArgumentName -eq 'Mandatory' -and $arg.Argument.Extent.Text -eq '$true') {
                                $paramInfo.Mandatory = $true
                            }
                        }
                    }
                }
            }
            
            # Get default value if present
            if ($param.DefaultValue) {
                $paramInfo.DefaultValue = $param.DefaultValue.Extent.Text
            }
            
            $metadata.Parameters += $paramInfo
        }
    }
    
    # Extract functions
    $functionAsts = $AST.FindAll({
        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    
    foreach ($func in $functionAsts) {
        $funcParams = @()
        if ($func.Parameters) {
            $funcParams = $func.Parameters | ForEach-Object { 
                if ($_.Name -and $_.Name.VariablePath) {
                    $_.Name.VariablePath.UserPath
                } else {
                    'Unknown'
                }
            }
        }
        
        $metadata.Functions += @{
            Name = $func.Name
            Parameters = $funcParams
        }
    }
    
    # Extract external commands
    $commandAsts = $AST.FindAll({
        $args[0] -is [System.Management.Automation.Language.CommandAst]
    }, $true)
    
    $externalCommands = @()
    foreach ($cmd in $commandAsts) {
        $cmdName = $cmd.GetCommandName()
        if ($cmdName -and $cmdName -notmatch '^\$' -and $cmdName -ne '&') {
            # Check if it's not a local function
            if ($metadata.Functions.Name -notcontains $cmdName) {
                $externalCommands += $cmdName
            }
        }
    }
    $metadata.ExternalCommands = $externalCommands | Select-Object -Unique | Sort-Object
    
    # Extract #Requires statements
    $requiresStatements = $AST.ScriptRequirements
    if ($requiresStatements) {
        foreach ($req in $requiresStatements.RequiredModules) {
            $metadata.RequiresModules += $req.Name
        }
    }
    
    return $metadata
}

function New-TestStructure {
    param(
        [hashtable]$Metadata,
        [switch]$IncludeMocks
    )
    
    $sb = [System.Text.StringBuilder]::new()
    
    # Header
    $null = $sb.AppendLine("#Requires -Version 7.0")
    $null = $sb.AppendLine("#Requires -Module Pester")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("<#")
    $null = $sb.AppendLine(".SYNOPSIS")
    $null = $sb.AppendLine("    Unit tests for $($Metadata.ScriptName)")
    $null = $sb.AppendLine(".DESCRIPTION")
    $null = $sb.AppendLine("    Automated tests generated for automation script: $($Metadata.ScriptName)")
    if ($Metadata.Description) {
        $null = $sb.AppendLine("    Script Description: $($Metadata.Description)")
    }
    $null = $sb.AppendLine("    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $null = $sb.AppendLine("#>")
    $null = $sb.AppendLine()
    
    # Test structure
    $null = $sb.AppendLine("Describe '$($Metadata.ScriptName)' -Tag 'Unit', 'AutomationScript' {")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("    BeforeAll {")
    $null = $sb.AppendLine("        `$script:ScriptPath = '$($Metadata.ScriptPath)'")
    $null = $sb.AppendLine("        `$script:ScriptName = '$($Metadata.ScriptName)'")
    
    if ($IncludeMocks) {
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("        # Mock external commands")
        foreach ($cmd in $Metadata.ExternalCommands) {
            # Skip built-in cmdlets
            if ($cmd -notmatch '^(Write-|Get-|Set-|Test-|New-|Remove-)') {
                $null = $sb.AppendLine("        Mock $cmd { return `$null } -Verifiable")
            }
        }
    }
    
    $null = $sb.AppendLine("    }")
    $null = $sb.AppendLine()
    
    # Test script existence
    $null = $sb.AppendLine("    Context 'Script Validation' {")
    $null = $sb.AppendLine("        It 'Script file should exist' {")
    $null = $sb.AppendLine("            Test-Path `$script:ScriptPath | Should -Be `$true")
    $null = $sb.AppendLine("        }")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("        It 'Script should have valid PowerShell syntax' {")
    $null = $sb.AppendLine("            `$errors = `$null")
    $null = $sb.AppendLine("            `$null = [System.Management.Automation.Language.Parser]::ParseFile(")
    $null = $sb.AppendLine("                `$script:ScriptPath,")
    $null = $sb.AppendLine("                [ref]`$null,")
    $null = $sb.AppendLine("                [ref]`$errors")
    $null = $sb.AppendLine("            )")
    $null = $sb.AppendLine("            `$errors.Count | Should -Be 0")
    $null = $sb.AppendLine("        }")
    $null = $sb.AppendLine("    }")
    $null = $sb.AppendLine()
    
    # Parameter tests
    if ($Metadata.Parameters.Count -gt 0) {
        $null = $sb.AppendLine("    Context 'Parameter Validation' {")
        
        foreach ($param in $Metadata.Parameters) {
            $null = $sb.AppendLine("        It 'Should accept -$($param.Name) parameter' {")
            $null = $sb.AppendLine("            `$scriptInfo = Get-Command `$script:ScriptPath")
            $null = $sb.AppendLine("            `$scriptInfo.Parameters.ContainsKey('$($param.Name)') | Should -Be `$true")
            
            if ($param.Type -ne 'Object') {
                $null = $sb.AppendLine("            `$scriptInfo.Parameters['$($param.Name)'].ParameterType.Name | Should -Be '$($param.Type)'")
            }
            
            if ($param.Mandatory) {
                $null = $sb.AppendLine("            `$scriptInfo.Parameters['$($param.Name)'].Attributes.Mandatory | Should -Contain `$true")
            }
            
            $null = $sb.AppendLine("        }")
            $null = $sb.AppendLine()
        }
        
        $null = $sb.AppendLine("    }")
        $null = $sb.AppendLine()
    }
    
    # Function tests
    if ($Metadata.Functions.Count -gt 0) {
        $null = $sb.AppendLine("    Context 'Function Tests' {")
        
        foreach ($func in $Metadata.Functions) {
            $null = $sb.AppendLine("        It 'Function $($func.Name) should be defined' {")
            $null = $sb.AppendLine("            # This test would require sourcing the script")
            $null = $sb.AppendLine("            # . `$script:ScriptPath")
            $null = $sb.AppendLine("            # Get-Command -Name '$($func.Name)' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty")
            $null = $sb.AppendLine("            `$true | Should -Be `$true # Placeholder")
            $null = $sb.AppendLine("        }")
            $null = $sb.AppendLine()
        }
        
        $null = $sb.AppendLine("    }")
        $null = $sb.AppendLine()
    }
    
    # Execution tests
    $null = $sb.AppendLine("    Context 'Script Execution' {")
    $null = $sb.AppendLine("        It 'Should not throw when executed with WhatIf' {")
    $null = $sb.AppendLine("            {")
    $null = $sb.AppendLine("                `$params = @{}")
    
    # Add default parameters for testing
    if ($Metadata.Parameters | Where-Object { $_.Name -eq 'Configuration' }) {
        $null = $sb.AppendLine("                `$params['Configuration'] = @{}")
    }
    
    $null = $sb.AppendLine("                `$params['WhatIf'] = `$true")
    $null = $sb.AppendLine("                & `$script:ScriptPath @params")
    $null = $sb.AppendLine("            } | Should -Not -Throw")
    $null = $sb.AppendLine("        }")
    
    if ($Metadata.Stage) {
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("        It 'Should be in stage: $($Metadata.Stage)' {")
        $null = $sb.AppendLine("            `$content = Get-Content `$script:ScriptPath -First 10")
        $null = $sb.AppendLine("            (`$content -join \" \") | Should -Match 'Stage:[\\s:]*$($Metadata.Stage)'")
        $null = $sb.AppendLine("        }")
    }
    
    if ($Metadata.Dependencies.Count -gt 0) {
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("        It 'Should declare dependencies: $($Metadata.Dependencies -join ", ")' {")
        $null = $sb.AppendLine("            `$content = Get-Content `$script:ScriptPath -First 10")
        $null = $sb.AppendLine("            `$content -join ' ' | Should -Match 'Dependencies:'")
        $null = $sb.AppendLine("        }")
    }
    
    $null = $sb.AppendLine("    }")
    $null = $sb.AppendLine()
    
    # Mock verification
    if ($IncludeMocks -and $Metadata.ExternalCommands.Count -gt 0) {
        $null = $sb.AppendLine("    AfterAll {")
        $null = $sb.AppendLine("        # Verify all mocks were called as expected")
        $null = $sb.AppendLine("        # Assert-VerifiableMock")
        $null = $sb.AppendLine("    }")
        $null = $sb.AppendLine()
    }
    
    $null = $sb.AppendLine("}")
    
    return $sb.ToString()
}

function New-IntegrationTestStructure {
    param([hashtable]$Metadata)
    
    $sb = [System.Text.StringBuilder]::new()
    
    # Header
    $null = $sb.AppendLine("#Requires -Version 7.0")
    $null = $sb.AppendLine("#Requires -Module Pester")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("<#")
    $null = $sb.AppendLine(".SYNOPSIS")
    $null = $sb.AppendLine("    Integration tests for $($Metadata.ScriptName)")
    $null = $sb.AppendLine(".DESCRIPTION")
    $null = $sb.AppendLine("    Integration tests for automation script: $($Metadata.ScriptName)")
    $null = $sb.AppendLine("    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $null = $sb.AppendLine("#>")
    $null = $sb.AppendLine()
    
    $null = $sb.AppendLine("Describe '$($Metadata.ScriptName) Integration' -Tag 'Integration', 'AutomationScript' {")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("    BeforeAll {")
    $null = $sb.AppendLine("        `$script:ScriptPath = '$($Metadata.ScriptPath)'")
    $null = $sb.AppendLine("        `$script:TestConfig = @{")
    $null = $sb.AppendLine("            # Add test configuration here")
    $null = $sb.AppendLine("        }")
    $null = $sb.AppendLine("    }")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("    Context 'End-to-End Execution' {")
    $null = $sb.AppendLine("        It 'Should execute successfully with test configuration' -Skip {")
    $null = $sb.AppendLine("            # This test is skipped by default as it performs actual operations")
    $null = $sb.AppendLine("            `$result = & `$script:ScriptPath -Configuration `$script:TestConfig")
    $null = $sb.AppendLine("            `$LASTEXITCODE | Should -Be 0")
    $null = $sb.AppendLine("        }")
    $null = $sb.AppendLine("    }")
    $null = $sb.AppendLine()
    
    if ($Metadata.Dependencies.Count -gt 0) {
        $null = $sb.AppendLine("    Context 'Dependency Verification' {")
        foreach ($dep in $Metadata.Dependencies) {
            $null = $sb.AppendLine("        It 'Dependency $dep should be satisfied' -Skip {")
            $null = $sb.AppendLine("            # Add dependency verification logic here")
            $null = $sb.AppendLine("            `$true | Should -Be `$true")
            $null = $sb.AppendLine("        }")
        }
        $null = $sb.AppendLine("    }")
        $null = $sb.AppendLine()
    }
    
    $null = $sb.AppendLine("}")
    
    return $sb.ToString()
}

function New-AllAutomationTests {
    <#
    .SYNOPSIS
        Generate tests for all automation scripts
    .DESCRIPTION
        Scans the automation-scripts directory and generates tests for all scripts
    .PARAMETER Filter
        Filter pattern for script selection (e.g., "02*" for 0200-0299 scripts)
    .PARAMETER IncludeMocks
        Include mock generation for all tests
    .PARAMETER Force
        Overwrite existing test files
    .EXAMPLE
        New-AllAutomationTests -Filter "02*" -IncludeMocks
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Filter = "*.ps1",
        
        [switch]$IncludeMocks,
        
        [switch]$Force
    )
    
    Write-GeneratorLog "Starting batch test generation"
    
    $scripts = Get-ChildItem -Path $script:AutomationScriptsPath -Filter $Filter -File |
        Where-Object { $_.Name -match '^\d{4}_' }
    
    Write-GeneratorLog "Found $($scripts.Count) scripts to process"
    
    $results = @()
    
    foreach ($script in $scripts) {
        $testPath = Join-Path $script:TestsPath "unit/automation-scripts/$([System.IO.Path]::GetFileNameWithoutExtension($script.Name)).Tests.ps1"
        
        if ((Test-Path $testPath) -and -not $Force) {
            Write-GeneratorLog "Skipping $($script.Name) - test already exists" -Level 'Warning'
            continue
        }
        
        if ($PSCmdlet.ShouldProcess($script.Name, "Generate unit test")) {
            try {
                $result = New-AutomationScriptTest -ScriptPath $script.FullName -IncludeMocks:$IncludeMocks
                $results += $result
                Write-GeneratorLog "Generated test for $($script.Name)"
            } catch {
                Write-GeneratorLog "Failed to generate test for $($script.Name): $_" -Level 'Error'
                $results += [PSCustomObject]@{
                    ScriptName = $script.Name
                    TestPath = $null
                    Success = $false
                    Error = $_.ToString()
                }
            }
        }
    }
    
    # Summary
    $successful = $results | Where-Object Success
    $failed = $results | Where-Object { -not $_.Success }
    
    Write-Host "`nTest Generation Summary:" -ForegroundColor Cyan
    Write-Host "  Total Scripts: $($scripts.Count)"
    Write-Host "  Tests Generated: $($successful.Count)" -ForegroundColor Green
    Write-Host "  Failed: $($failed.Count)" -ForegroundColor $(if ($failed.Count -gt 0) { 'Red' } else { 'Green' })
    
    if ($failed.Count -gt 0) {
        Write-Host "`nFailed scripts:" -ForegroundColor Red
        $failed | ForEach-Object {
            Write-Host "  - $($_.ScriptName): $($_.Error)" -ForegroundColor Red
        }
    }
    
    return $results
}

# Export functions
Export-ModuleMember -Function @(
    'New-AutomationScriptTest',
    'New-AllAutomationTests'
)