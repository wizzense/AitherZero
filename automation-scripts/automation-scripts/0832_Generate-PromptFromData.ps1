#Requires -Version 7.0
<#
.SYNOPSIS
    Generates AI prompts from structured data
.DESCRIPTION
    Converts various types of structured data (JSON, XML, CSV, PowerShell objects) into
    contextual AI prompts with intelligent formatting and compression
.PARAMETER InputPath
    Path to data file or directory
.PARAMETER DataType
    Type of data to process
.PARAMETER PromptTemplate
    Template for prompt generation
.PARAMETER OutputPath
    Path to save generated prompt
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$inputValuePath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'JSON', 'XML', 'CSV', 'YAML', 'Tanium', 'TestResults', 'Configuration', 'Orchestration')]
    [string]$DataType = 'Auto',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Analysis', 'Implementation', 'Conversion', 'Documentation', 'Testing', 'Custom')]
    [string]$PromptTemplate = 'Analysis',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./.claude/generated-prompt.md",

    [Parameter(Mandatory = $false)]
    [string]$CustomTemplate = $null,

    [Parameter(Mandatory = $false)]
    [int]$MaxTokens = 4000,

    [Parameter(Mandatory = $false)]
    [hashtable]$Context = @{},

    [switch]$IncludeExamples,

    [switch]$GenerateCode,

    [switch]$Interactive,

    [switch]$CopyToClipboard
)

# Script metadata
$scriptInfo = @{
    Stage = 'Development'
    Number = '0830'
    Name = 'Generate-PromptFromData'
    Description = 'Generates AI prompts from structured data'
    Dependencies = @()
    Tags = @('ai', 'prompt', 'data', 'conversion')
    RequiresAdmin = $false
}

# Import required modules
$modulePath = Join-Path $PSScriptRoot ".." "Initialize-AitherModules.ps1"
if (Test-Path $modulePath) {
    . $modulePath
}

# Helper function to detect data type
function Get-DataType {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue | Select-Object -First 1000

    # Check by extension first
    switch ($extension) {
        '.json' {
            # Check if it's a Tanium export
            if ($content -match '"object_list".*"package_specs"') {
                return 'Tanium'
            }
            # Check if it's test results
            if ($content -match '"Tests"|"TestResult"|"FailedCount"') {
                return 'TestResults'
            }
            # Check if it's orchestration
            if ($content -match '"stages"|"playbook"|"sequence"') {
                return 'Orchestration'
            }
            return 'JSON'
        }
        '.xml' { return 'XML' }
        '.csv' { return 'CSV' }
        '.yaml' { return 'YAML' }
        '.yml' { return 'YAML' }
        '.ps1' {
            if ($content -match 'seq |Invoke-OrchestrationSequence') {
                return 'Orchestration'
            }
            return 'PowerShell'
        }
        '.psd1' { return 'Configuration' }
    }

    # Try to detect by content
    if ($content -match '^\s*<\?xml') { return 'XML' }
    if ($content -match '^\s*\{[\s\S]*\}\s*$') { return 'JSON' }
    if ($content -match '^\s*---\s*$') { return 'YAML' }
    if ($content -contains ',') { return 'CSV' }

    return 'Unknown'
}

# Parse different data formats
function Parse-StructuredData {
    param(
        [string]$Path,
        [string]$Type
    )

    $data = @{
        Type = $Type
        Source = $Path
        Content = $null
        Metadata = @{}
    }

    switch ($Type) {
        'JSON' {
            $data.Content = Get-Content $Path | ConvertFrom-Json
        }

        'Tanium' {
            $json = Get-Content $Path | ConvertFrom-Json
            $data.Content = $json
            $data.Metadata = @{
                ExportDate = $json.comment -replace '.*at\s+', ''
                Version = $json.version
                PackageCount = $json.object_list.package_specs.Count
            }
        }

        'XML' {
            [xml]$data.Content = Get-Content $Path
        }

        'CSV' {
            $data.Content = Import-Csv $Path
        }

        'YAML' {
            # Would need a YAML parser module
            $data.Content = Get-Content $Path -Raw
            $data.Metadata.Format = 'YAML'
        }

        'TestResults' {
            $json = Get-Content $Path | ConvertFrom-Json
            $data.Content = $json
            $data.Metadata = @{
                TotalTests = $json.TotalCount ?? $json.Tests.Count
                Passed = $json.PassedCount ?? ($json.Tests | Where-Object Result -eq 'Passed').Count
                Failed = $json.FailedCount ?? ($json.Tests | Where-Object Result -eq 'Failed').Count
            }
        }

        'Configuration' {
            if ($Path -match '\.psd1$') {
                $data.Content = Import-PowerShellDataFile $Path
            } else {
                $data.Content = Get-Content $Path | ConvertFrom-Json
            }
        }

        'Orchestration' {
            $content = Get-Content $Path -Raw
            if ($Path -match '\.json$') {
                $data.Content = $content | ConvertFrom-Json
            } else {
                # Parse PowerShell orchestration examples
                $sequences = @()
                $content -split '\n' | ForEach-Object {
                    if ($_ -match 'seq\s+([^\s]+)') {
                        $sequences += $Matches[1]
                    }
                }
                $data.Content = @{ Sequences = $sequences }
            }
        }

        default {
            $data.Content = Get-Content $Path -Raw
        }
    }

    return $data
}

# Generate analysis prompt
function New-AnalysisPrompt {
    param($Data)

    $prompt = @()
    $prompt += "# Data Analysis Request"
    $prompt += ""
    $prompt += "Please analyze the following $($Data.Type) data and provide insights:"
    $prompt += ""

    if ($Data.Type -eq 'Tanium') {
        $prompt += "## Tanium Package Export Analysis"
        $prompt += ""
        $prompt += "**Export Information:**"
        $prompt += "- Date: $($Data.Metadata.ExportDate)"
        $prompt += "- Version: $($Data.Metadata.Version)"
        $prompt += "- Packages: $($Data.Metadata.PackageCount)"
        $prompt += ""
        $prompt += "## Package Details"

        foreach ($package in $Data.Content.object_list.package_specs | Select-Object -First 5) {
            $prompt += ""
            $prompt += "### $($package.display_name)"
            $prompt += "- **Name:** $($package.name)"
            $prompt += "- **Content Set:** $($package.content_set.name)"
            $prompt += "- **Files:** $($package.files.Count)"
            $prompt += "- **Command Timeout:** $($package.command_timeout) seconds"

            if ($package.parameter_definition) {
                $paramDef = $package.parameter_definition | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($paramDef.parameters) {
                    $prompt += "- **Parameters:** $($paramDef.parameters.Count)"
                }
            }
        }

        $prompt += ""
        $prompt += "## Analysis Tasks"
        $prompt += "1. Review the package configuration for security concerns"
        $prompt += "2. Identify optimization opportunities"
        $prompt += "3. Suggest PowerShell equivalents for the command execution"
        $prompt += "4. Recommend parameter validation improvements"
    }
    elseif ($Data.Type -eq 'TestResults') {
        $prompt += "## Test Results Analysis"
        $prompt += ""
        $prompt += "**Summary:**"
        $prompt += "- Total Tests: $($Data.Metadata.TotalTests)"
        $prompt += "- Passed: $($Data.Metadata.Passed)"
        $prompt += "- Failed: $($Data.Metadata.Failed)"
        $prompt += ""

        if ($Data.Content.Tests) {
            $failedTests = $Data.Content.Tests | Where-Object Result -eq 'Failed' | Select-Object -First 5
            if ($failedTests) {
                $prompt += "## Failed Tests"
                foreach ($test in $failedTests) {
                    $prompt += "- $($test.Name): $($test.ErrorRecord ?? $test.Message)"
                }
            }
        }

        $prompt += ""
        $prompt += "## Analysis Tasks"
        $prompt += "1. Identify patterns in test failures"
        $prompt += "2. Suggest fixes for failing tests"
        $prompt += "3. Recommend additional test coverage"
    }
    elseif ($Data.Type -eq 'Orchestration') {
        $prompt += "## Orchestration Analysis"
        $prompt += ""

        if ($Data.Content.stages) {
            $prompt += "**Stages:** $($Data.Content.stages.Count)"
            foreach ($stage in $Data.Content.stages | Select-Object -First 3) {
                $prompt += "- $($stage.name): $($stage.description)"
            }
        }

        if ($Data.Content.Sequences) {
            $prompt += "**Sequences Found:** $($Data.Content.Sequences.Count)"
            $prompt += '```'
            $Data.Content.Sequences | Select-Object -First 5 | ForEach-Object {
                $prompt += $_
            }
            $prompt += '```'
        }

        $prompt += ""
        $prompt += "## Analysis Tasks"
        $prompt += "1. Review orchestration flow for efficiency"
        $prompt += "2. Identify potential parallelization opportunities"
        $prompt += "3. Suggest error handling improvements"
    }
    else {
        # Generic analysis
        $prompt += "## Data Structure"
        $prompt += '```json'
        $prompt += ($Data.Content | ConvertTo-Json -Depth 3 -Compress | Select-Object -First 2000)
        $prompt += '```'
        $prompt += ""
        $prompt += "## Analysis Tasks"
        $prompt += "1. Identify key patterns and relationships"
        $prompt += "2. Suggest optimizations"
        $prompt += "3. Highlight potential issues"
    }

    return $prompt -join "`n"
}

# Generate implementation prompt
function New-ImplementationPrompt {
    param($Data)

    $prompt = @()
    $prompt += "# Implementation Request"
    $prompt += ""
    $prompt += "Based on the following $($Data.Type) data, please implement the required functionality:"
    $prompt += ""

    if ($Data.Type -eq 'Tanium') {
        $prompt += "## Convert Tanium Package to PowerShell"
        $prompt += ""
        $prompt += "Convert the following Tanium packages to native PowerShell implementations:"
        $prompt += ""

        foreach ($package in $Data.Content.object_list.package_specs | Select-Object -First 3) {
            $prompt += "### Package: $($package.display_name)"
            $prompt += ""
            $prompt += "**Original Command:**"
            $prompt += '```cmd'
            $prompt += $package.command
            $prompt += '```'
            $prompt += ""

            if ($package.files) {
                $prompt += "**Required Files:**"
                foreach ($file in $package.files) {
                    $prompt += "- $($file.name) ($('{0:N0}' -f $file.size) bytes)"
                }
                $prompt += ""
            }

            $prompt += "**Requirements:**"
            $prompt += "1. Convert to pure PowerShell 7+"
            $prompt += "2. Add proper error handling"
            $prompt += "3. Include parameter validation"
            $prompt += "4. Make cross-platform compatible"
            $prompt += "5. Add progress reporting"
            $prompt += ""
        }
    }
    elseif ($Data.Type -eq 'Orchestration') {
        $prompt += "## Implement Orchestration Workflow"
        $prompt += ""

        if ($Data.Content.stages) {
            $prompt += "Create PowerShell functions to implement these stages:"
            $prompt += ""
            foreach ($stage in $Data.Content.stages) {
                $prompt += "### Stage: $($stage.name)"
                $prompt += "- Description: $($stage.description)"
                $prompt += "- Scripts: $($stage.scripts -join ', ')"
                $prompt += "- Parallel: $($stage.parallel ?? $false)"
                $prompt += ""
            }
        }

        $prompt += "**Implementation Requirements:**"
        $prompt += "1. Use AitherZero orchestration patterns"
        $prompt += "2. Support both parallel and sequential execution"
        $prompt += "3. Include proper logging with Write-CustomLog"
        $prompt += "4. Handle errors gracefully"
        $prompt += "5. Return structured results"
    }
    elseif ($Data.Type -eq 'Configuration') {
        $prompt += "## Implement Configuration Management"
        $prompt += ""
        $prompt += "Create a PowerShell module to manage this configuration:"
        $prompt += ""
        $prompt += '```json'
        $prompt += ($Data.Content | ConvertTo-Json -Depth 2 -Compress | Select-Object -First 1000)
        $prompt += '```'
        $prompt += ""
        $prompt += "**Requirements:**"
        $prompt += "1. Create Get-Configuration function"
        $prompt += "2. Create Set-Configuration function"
        $prompt += "3. Add validation for all settings"
        $prompt += "4. Support configuration profiles"
        $prompt += "5. Include configuration export/import"
    }
    else {
        $prompt += "## Generic Implementation"
        $prompt += ""
        $prompt += "Implement PowerShell functions to work with this data:"
        $prompt += ""
        $prompt += '```json'
        $prompt += ($Data.Content | ConvertTo-Json -Depth 2 -Compress | Select-Object -First 1000)
        $prompt += '```'
    }

    return $prompt -join "`n"
}

# Generate conversion prompt
function New-ConversionPrompt {
    param($Data)

    $prompt = @()
    $prompt += "# Data Conversion Request"
    $prompt += ""
    $prompt += "Convert the following $($Data.Type) data to the requested format:"
    $prompt += ""

    $prompt += "## Source Data"
    $prompt += '```' + $Data.Type.ToLower()

    if ($Data.Type -eq 'Tanium') {
        # Show first package as example
        $firstPackage = $Data.Content.object_list.package_specs | Select-Object -First 1
        $prompt += ($firstPackage | ConvertTo-Json -Depth 4)
    } else {
        $prompt += ($Data.Content | ConvertTo-Json -Depth 3 -Compress | Select-Object -First 2000)
    }

    $prompt += '```'
    $prompt += ""
    $prompt += "## Conversion Requirements"
    $prompt += "1. Convert to AitherZero automation script format (0XXX series)"
    $prompt += "2. Maintain all functionality"
    $prompt += "3. Add appropriate metadata headers"
    $prompt += "4. Include error handling"
    $prompt += "5. Make idempotent"
    $prompt += ""

    if ($IncludeExamples) {
        $prompt += "## Example Output Format"
        $prompt += '```powershell'
        $prompt += @'
#Requires -Version 7.0
<#
.SYNOPSIS
    Converted from: [original source]
.DESCRIPTION
    [Detailed description]
#>
[CmdletBinding()]
param(
    # Parameters from original
)

# Script metadata
$scriptInfo = @{
    Stage = 'Automation'
    Number = '0XXX'
    Name = 'Script-Name'
    Description = 'Description'
    Dependencies = @()
    Tags = @()
}

# Main execution
try {
    # Implementation here
}
catch {
    Write-Error "Failed: $_"
    exit 1
}
'@
        $prompt += '```'
    }

    return $prompt -join "`n"
}

# Generate documentation prompt
function New-DocumentationPrompt {
    param($Data)

    $prompt = @()
    $prompt += "# Documentation Generation Request"
    $prompt += ""
    $prompt += "Generate comprehensive documentation for the following $($Data.Type) data:"
    $prompt += ""

    if ($Data.Type -eq 'Tanium') {
        $prompt += "## Tanium Package Documentation"
        $prompt += ""
        $prompt += "Create documentation for these Tanium packages including:"
        $prompt += "1. **Purpose and Overview**"
        $prompt += "2. **Parameters and Usage**"
        $prompt += "3. **Prerequisites and Dependencies**"
        $prompt += "4. **Security Considerations**"
        $prompt += "5. **Examples and Best Practices**"
        $prompt += ""

        foreach ($package in $Data.Content.object_list.package_specs | Select-Object -First 2) {
            $prompt += "### $($package.display_name)"
            $prompt += "- Command: ``$($package.command.Substring(0, [Math]::Min(100, $package.command.Length)))...``"
            $prompt += "- Timeout: $($package.command_timeout)s"
            $prompt += "- Files: $($package.files.Count)"
            $prompt += ""
        }
    }
    elseif ($Data.Type -eq 'Orchestration') {
        $prompt += "## Orchestration Workflow Documentation"
        $prompt += ""
        $prompt += "Document the orchestration workflow including:"
        $prompt += "1. **Workflow Overview**"
        $prompt += "2. **Stage Descriptions**"
        $prompt += "3. **Dependencies and Prerequisites**"
        $prompt += "4. **Error Handling**"
        $prompt += "5. **Usage Examples**"
        $prompt += ""

        if ($Data.Content.stages) {
            $prompt += "### Stages"
            foreach ($stage in $Data.Content.stages | Select-Object -First 5) {
                $prompt += "- **$($stage.name)**: $($stage.description)"
            }
        }
    }
    else {
        $prompt += "## Documentation Requirements"
        $prompt += "1. **Overview**: What this data represents"
        $prompt += "2. **Structure**: Key fields and relationships"
        $prompt += "3. **Usage**: How to work with this data"
        $prompt += "4. **Examples**: Common use cases"
        $prompt += "5. **API Reference**: If applicable"
    }

    $prompt += ""
    $prompt += "## Documentation Format"
    $prompt += "Please generate documentation in Markdown format with:"
    $prompt += "- Clear section headers"
    $prompt += "- Code examples"
    $prompt += "- Tables for parameters/options"
    $prompt += "- Diagrams where helpful (Mermaid format)"

    return $prompt -join "`n"
}

# Generate testing prompt
function New-TestingPrompt {
    param($Data)

    $prompt = @()
    $prompt += "# Test Generation Request"
    $prompt += ""
    $prompt += "Generate comprehensive tests for the following $($Data.Type) data/implementation:"
    $prompt += ""

    $prompt += "## Test Requirements"
    $prompt += "1. **Unit Tests**: Test individual functions/components"
    $prompt += "2. **Integration Tests**: Test component interactions"
    $prompt += "3. **Edge Cases**: Handle unusual inputs"
    $prompt += "4. **Error Conditions**: Test failure scenarios"
    $prompt += "5. **Performance Tests**: If applicable"
    $prompt += ""

    $prompt += "## Data to Test"
    $prompt += '```json'
    $prompt += ($Data.Content | ConvertTo-Json -Depth 2 -Compress | Select-Object -First 1000)
    $prompt += '```'
    $prompt += ""

    $prompt += "## Test Framework"
    $prompt += "Use Pester 5.0+ with:"
    $prompt += "- Proper test structure (Describe/Context/It)"
    $prompt += "- Mock external dependencies"
    $prompt += "- Assert all critical paths"
    $prompt += "- Include performance benchmarks"
    $prompt += "- Generate code coverage"

    return $prompt -join "`n"
}

# Apply custom template
function Apply-CustomTemplate {
    param(
        $Data,
        [string]$Template
    )

    # Replace tokens in template
    $result = $Template

    # Standard replacements
    $result = $result -replace '\{DataType\}', $Data.Type
    $result = $result -replace '\{Source\}', $Data.Source
    $result = $result -replace '\{Timestamp\}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    # Data content as JSON
    $jsonContent = $Data.Content | ConvertTo-Json -Depth 3 -Compress
    $result = $result -replace '\{Content\}', $jsonContent

    # Metadata replacements
    foreach ($key in $Data.Metadata.Keys) {
        $result = $result -replace "\{Metadata\.$key\}", $Data.Metadata[$key]
    }

    # Context replacements
    foreach ($key in $Context.Keys) {
        $result = $result -replace "\{Context\.$key\}", $Context[$key]
    }

    return $result
}

# Compress prompt to fit token limit
function Compress-Prompt {
    param(
        [string]$Prompt,
        [int]$MaxTokens
    )

    $tokens = [math]::Ceiling($Prompt.Length / 4)

    if ($tokens -le $MaxTokens) {
        return $Prompt
    }

    Write-Warning "Prompt exceeds token limit ($tokens > $MaxTokens). Compressing..."

    # Compression strategies
    # 1. Remove code examples
    $compressed = $Prompt -replace '```[\s\S]*?```', '[Code removed for brevity]'

    # 2. Truncate long lists
    $compressed = $compressed -replace '(\n- [^\n]+){6,}', '$1`n- ... [Additional items truncated]'

    # 3. Remove extra whitespace
    $compressed = $compressed -replace '\n{3,}', "`n`n"

    $newTokens = [math]::Ceiling($compressed.Length / 4)
    Write-Host "Compressed from $tokens to $newTokens tokens" -ForegroundColor Gray

    return $compressed
}

# Main execution
try {
    Write-Host "🤖 Generating AI prompt from data..." -ForegroundColor Cyan

    # Validate input
    if (-not (Test-Path $inputValuePath)) {
        throw "Input path not found: $inputValuePath"
    }

    # Detect or validate data type
    if ($DataType -eq 'Auto') {
        $DataType = Get-DataType -Path $inputValuePath
        Write-Host "   Detected data type: $DataType" -ForegroundColor Gray
    }

    # Parse the data
    Write-Host "   Parsing $DataType data..." -ForegroundColor Gray
    $parsedData = Parse-StructuredData -Path $inputValuePath -Type $DataType

    # Add context
    $parsedData.Context = $Context

    # Generate prompt based on template
    Write-Host "   Generating $PromptTemplate prompt..." -ForegroundColor Gray

    $generatedPrompt = switch ($PromptTemplate) {
        'Analysis' { New-AnalysisPrompt -Data $parsedData }
        'Implementation' { New-ImplementationPrompt -Data $parsedData }
        'Conversion' { New-ConversionPrompt -Data $parsedData }
        'Documentation' { New-DocumentationPrompt -Data $parsedData }
        'Testing' { New-TestingPrompt -Data $parsedData }
        'Custom' {
            if (-not $CustomTemplate) {
                throw "Custom template required when using Custom prompt type"
            }
            Apply-CustomTemplate -Data $parsedData -Template $CustomTemplate
        }
    }

    # Add footer with metadata
    $generatedPrompt += "`n`n---`n"
    $generatedPrompt += "*Generated from: $inputValuePath*`n"
    $generatedPrompt += "*Data Type: $DataType*`n"
    $generatedPrompt += "*Template: $PromptTemplate*`n"
    $generatedPrompt += "*Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*"

    # Compress if needed
    $generatedPrompt = Compress-Prompt -Prompt $generatedPrompt -MaxTokens $MaxTokens

    # Interactive mode - allow editing
    if ($Interactive) {
        Write-Host "`n📝 Generated Prompt Preview:" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor DarkGray
        Write-Host ($generatedPrompt | Select-Object -First 50)
        Write-Host ("=" * 80) -ForegroundColor DarkGray

        $response = Read-Host "`nEdit prompt before saving? (Y/N)"
        if ($response -eq 'Y') {
            # Open in default editor
            $tempFile = [System.IO.Path]::GetTempFileName() + ".md"
            if ($PSCmdlet.ShouldProcess($tempFile, 'Create Temporary File')) {
                $generatedPrompt | Set-Content $tempFile
            }

            if ($IsWindows) {
                Start-Process notepad.exe -ArgumentList $tempFile -Wait
            } else {
                Start-Process ${env:EDITOR:-nano} -ArgumentList $tempFile -Wait
            }

            $generatedPrompt = Get-Content $tempFile -Raw
            Remove-Item $tempFile
        }
    }

    # Save prompt
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        if ($PSCmdlet.ShouldProcess($outputDir, 'Create Directory')) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
    }

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Save Generated Prompt')) {
        $generatedPrompt | Set-Content $OutputPath -Encoding UTF8
    }

    # Copy to clipboard if requested
    if ($CopyToClipboard) {
        if ($IsWindows) {
            $generatedPrompt | Set-Clipboard
            Write-Host "   📋 Copied to clipboard!" -ForegroundColor Green
        }
        elseif ($IsMacOS) {
            $generatedPrompt | pbcopy
            Write-Host "   📋 Copied to clipboard!" -ForegroundColor Green
        }
        elseif ($IsLinux -and (Get-Command xclip -ErrorAction SilentlyContinue)) {
            $generatedPrompt | xclip -selection clipboard
            Write-Host "   📋 Copied to clipboard!" -ForegroundColor Green
        }
    }

    # Summary
    Write-Host "`n✅ Prompt generated successfully!" -ForegroundColor Green
    Write-Host "   Output: $OutputPath" -ForegroundColor Gray
    Write-Host "   Size: $('{0:N0}' -f (Get-Item $OutputPath).Length) bytes" -ForegroundColor Gray
    Write-Host "   Tokens: ~$([math]::Ceiling($generatedPrompt.Length / 4))" -ForegroundColor Gray

    # Show usage examples
    if ($GenerateCode) {
        Write-Host "`n📌 Example Usage:" -ForegroundColor Cyan
        Write-Host "   # Use with Claude Code:" -ForegroundColor Gray
        Write-Host "   Get-Content '$OutputPath' | Set-Clipboard" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   # Chain with other tools:" -ForegroundColor Gray
        Write-Host "   seq 0830 -InputPath ./data.json | seq 0821" -ForegroundColor DarkGray
    }

    exit 0
}
catch {
    Write-Error "Failed to generate prompt: $_"
    exit 1
}