#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Documentation Engine - Automated, reactive documentation generation system
.DESCRIPTION
    Provides comprehensive documentation automation including:
    - Reactive documentation generation on code changes
    - Multi-format documentation export (Markdown, HTML, PDF)
    - Documentation quality validation and coverage analysis
    - Integration with CI/CD pipelines for continuous documentation
    - Template-based documentation generation
    - Cross-reference validation and link checking
.NOTES
    Copyright © 2025 Aitherium Corporation
    Part of AitherZero infrastructure automation platform
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state and configuration
$script:DocumentationState = @{
    Config = $null
    Templates = @{}
    WatchedPaths = @()
    LastGeneration = $null
    QualityMetrics = @{}
    ValidationRules = @()
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
$script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"

# Import required modules
if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force -ErrorAction SilentlyContinue
}
if (Test-Path $script:ConfigModule) {
    Import-Module $script:ConfigModule -Force -ErrorAction SilentlyContinue
}

$script:LoggingAvailable = $null -ne (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)

function Write-DocLog {
    param(
        [string]$Message,
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )
    
    if ($script:LoggingAvailable) {
        Write-CustomLog -Level $Level -Message $Message -Source "DocumentationEngine" -Data $Data
    } else {
        Write-Host "[$Level] [DocumentationEngine] $Message" -ForegroundColor $(
            switch ($Level) {
                'Debug' { 'Gray' }
                'Information' { 'White' }
                'Warning' { 'Yellow' }
                'Error' { 'Red' }
            }
        )
    }
}

#region Configuration Management

function Initialize-DocumentationEngine {
    <#
    .SYNOPSIS
        Initialize the documentation engine with configuration and templates
    .PARAMETER ConfigPath
        Path to documentation configuration file
    .PARAMETER TemplateDirectory
        Directory containing documentation templates
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = $null,
        [string]$TemplateDirectory = $null
    )
    
    Write-DocLog "Initializing Documentation Engine..." -Level Information
    Write-DocLog "ConfigPath: $ConfigPath, TemplateDirectory: $TemplateDirectory" -Level Debug
    
    # Load default configuration
    $script:DocumentationState.Config = Get-DefaultDocumentationConfig
    Write-DocLog "Loaded default configuration" -Level Debug
    
    # Override with file-based config if available
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            Write-DocLog "Loading configuration from: $ConfigPath" -Level Information
            $fileConfig = Get-Content $ConfigPath | ConvertFrom-Json -AsHashtable
            $script:DocumentationState.Config = Merge-Configuration $script:DocumentationState.Config $fileConfig
            Write-DocLog "Loaded configuration from $ConfigPath" -Level Information
        } catch {
            Write-DocLog "Failed to load configuration from ${ConfigPath}: $($_.Exception.Message)" -Level Warning
        }
    } else {
        Write-DocLog "No config file provided or file not found, using defaults" -Level Debug
    }
    
    # Load templates
    $templateDir = $TemplateDirectory ?? (Join-Path $script:ProjectRoot "docs/templates")
    Write-DocLog "Looking for templates in: $templateDir" -Level Debug
    if (Test-Path $templateDir) {
        Write-DocLog "Loading templates from: $templateDir" -Level Information
        Load-DocumentationTemplates -TemplateDirectory $templateDir
    } else {
        Write-DocLog "Template directory not found, initializing default templates" -Level Information
        Initialize-DefaultTemplates
    }
    
    # Initialize validation rules
    Write-DocLog "Initializing validation rules" -Level Debug
    Initialize-ValidationRules
    
    Write-DocLog "Documentation Engine initialized successfully" -Data @{
        Templates = $script:DocumentationState.Templates.Keys -join ', '
        ValidationRules = $script:DocumentationState.ValidationRules.Count
    }
}

function Get-DefaultDocumentationConfig {
    return @{
        ReactiveMode = @{
            Enabled = $true
            WatchPaths = @(
                "domains/**/*.psm1"
                "automation-scripts/**/*.ps1" 
                "*.psd1"
                "README.md"
            )
            ExcludePaths = @(
                ".git/**/*"
                "tests/**/*"
                "logs/**/*"
                "reports/**/*"
            )
            GenerateOnChange = $true
            DebounceSeconds = 30
        }
        OutputFormats = @('Markdown', 'HTML')
        OutputDirectory = "docs/generated"
        QualityGates = @{
            MinimumCoverage = 75
            RequireExamples = $true
            ValidateLinks = $true
            CheckSpelling = $false
        }
        Templates = @{
            ModuleDocumentation = "module-template.md"
            FunctionDocumentation = "function-template.md"
            ProjectOverview = "project-template.md"
            APIReference = "api-template.md"
        }
        Integration = @{
            UpdateREADME = $true
            GenerateIndexes = $true
            CreateNavigation = $true
            LinkValidation = $true
        }
    }
}

function Merge-Configuration {
    param(
        [hashtable]$Default,
        [hashtable]$Override
    )
    
    $merged = $Default.Clone()
    foreach ($key in $Override.Keys) {
        if ($merged.ContainsKey($key) -and $merged[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $merged[$key] = Merge-Configuration $merged[$key] $Override[$key]
        } else {
            $merged[$key] = $Override[$key]
        }
    }
    return $merged
}

#endregion

#region Template Management

function Load-DocumentationTemplates {
    param([string]$TemplateDirectory)
    
    Write-DocLog "Loading documentation templates from $TemplateDirectory"
    
    $templateFiles = Get-ChildItem -Path $TemplateDirectory -Filter "*.md" -ErrorAction SilentlyContinue
    
    foreach ($template in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($template.Name)
        $script:DocumentationState.Templates[$templateName] = Get-Content $template.FullName -Raw
        Write-DocLog "Loaded template: $templateName"
    }
}

function Initialize-DefaultTemplates {
    Write-DocLog "Initializing default documentation templates"
    
    # Module documentation template
    $script:DocumentationState.Templates['module'] = @'
# {{ModuleName}}

## Overview
{{ModuleDescription}}

## Functions

{{#Functions}}
### {{Name}}

**Synopsis:** {{Synopsis}}

**Description:** {{Description}}

#### Parameters
{{#Parameters}}
- **{{Name}}** ({{Type}}): {{Description}}
{{/Parameters}}

#### Examples
```powershell
{{Example}}
```

---
{{/Functions}}

## Installation

```powershell
Import-Module {{ModulePath}}
```

## Dependencies

{{#Dependencies}}
- {{Name}} ({{Version}})
{{/Dependencies}}

## Version History

{{VersionHistory}}

---
*Generated automatically by AitherZero Documentation Engine*
'@

    # Function documentation template  
    $script:DocumentationState.Templates['function'] = @'
## {{FunctionName}}

### Synopsis
{{Synopsis}}

### Description
{{Description}}

### Syntax
```powershell
{{Syntax}}
```

### Parameters
{{#Parameters}}
#### {{Name}}
- **Type:** {{Type}}
- **Required:** {{Required}}
- **Default:** {{DefaultValue}}
- **Description:** {{Description}}

{{/Parameters}}

### Examples
{{#Examples}}
#### Example {{Index}}
```powershell
{{Code}}
```
{{Description}}

{{/Examples}}

### Notes
{{Notes}}
'@

    # Project overview template
    $script:DocumentationState.Templates['project'] = @'
# {{ProjectName}}

{{ProjectDescription}}

## Quick Start

{{QuickStart}}

## Architecture

{{#Domains}}
### {{Name}}
{{Description}}

**Modules:** {{ModuleCount}}
**Functions:** {{FunctionCount}}

{{/Domains}}

## Installation

{{InstallationInstructions}}

## Usage Examples

{{UsageExamples}}

## API Reference

{{APIReference}}

## Contributing

{{ContributingGuidelines}}
'@
}

function Initialize-ValidationRules {
    $script:DocumentationState.ValidationRules = @(
        @{
            Name = "RequiredSections"
            Description = "Ensure all required documentation sections are present"
            Check = { param($content) $content -match "## Overview" -and $content -match "## Installation" }
        },
        @{
            Name = "NoEmptySections" 
            Description = "Ensure no documentation sections are empty"
            Check = { param($content) -not ($content -match "##\s+\w+\s*\n\s*\n##") }
        },
        @{
            Name = "ValidLinks"
            Description = "Ensure all internal links are valid"
            Check = { param($content, $basePath) Test-DocumentationLinks -Content $content -BasePath $basePath }
        }
    )
}

#endregion

#region Documentation Generation

function New-ModuleDocumentation {
    <#
    .SYNOPSIS
        Generate comprehensive documentation for a PowerShell module
    .PARAMETER ModulePath
        Path to the PowerShell module (.psm1 file)
    .PARAMETER OutputPath
        Output directory for generated documentation
    .PARAMETER Format
        Output format (Markdown, HTML, or Both)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath,
        
        [string]$OutputPath = $null,
        
        [ValidateSet('Markdown', 'HTML', 'Both')]
        [string]$Format = 'Markdown'
    )
    
    Write-DocLog "Generating documentation for module: $ModulePath"
    
    if (-not (Test-Path $ModulePath)) {
        throw "Module file not found: $ModulePath"
    }
    
    # Parse module content
    $moduleInfo = Get-ModuleAnalysis -ModulePath $ModulePath
    
    # Generate documentation data
    $docData = @{
        ModuleName = $moduleInfo.Name
        ModuleDescription = $moduleInfo.Description
        ModulePath = $ModulePath
        Functions = $moduleInfo.Functions
        Dependencies = $moduleInfo.Dependencies
        VersionHistory = $moduleInfo.VersionHistory
        GeneratedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    
    # Apply template
    $template = $script:DocumentationState.Templates['module']
    $documentation = Expand-Template -Template $template -Data $docData
    
    # Save documentation
    $outputDir = $OutputPath ?? (Join-Path $script:DocumentationState.Config.OutputDirectory "modules")
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    $fileName = "$($moduleInfo.Name).md"
    $outputFile = Join-Path $outputDir $fileName
    
    $documentation | Set-Content $outputFile -Encoding UTF8
    Write-DocLog "Module documentation saved to: $outputFile"
    
    # Generate HTML if requested
    if ($Format -in @('HTML', 'Both')) {
        $htmlFile = $outputFile -replace '\.md$', '.html'
        ConvertTo-Html -InputObject $documentation -OutputPath $htmlFile
        Write-DocLog "HTML documentation saved to: $htmlFile"
    }
    
    return $outputFile
}

function New-ProjectDocumentation {
    <#
    .SYNOPSIS
        Generate comprehensive project documentation including all modules and scripts
    .PARAMETER OutputPath
        Output directory for generated documentation
    .PARAMETER IncludePrivate
        Include private/internal modules in documentation
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = $null,
        [switch]$IncludePrivate
    )
    
    Write-DocLog "Generating comprehensive project documentation"
    
    $projectInfo = Get-ProjectAnalysis -IncludePrivate:$IncludePrivate
    
    # Generate main project documentation
    $docData = @{
        ProjectName = $projectInfo.Name
        ProjectDescription = $projectInfo.Description
        QuickStart = $projectInfo.QuickStart
        Domains = $projectInfo.Domains
        InstallationInstructions = $projectInfo.Installation
        UsageExamples = $projectInfo.Examples
        APIReference = "Generated API documentation available in the modules/ directory"
        ContributingGuidelines = $projectInfo.Contributing
        GeneratedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    
    $template = $script:DocumentationState.Templates['project']
    $documentation = Expand-Template -Template $template -Data $docData
    
    # Save main documentation
    $outputDir = $OutputPath ?? $script:DocumentationState.Config.OutputDirectory
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    $mainDocFile = Join-Path $outputDir "PROJECT-DOCUMENTATION.md"
    $documentation | Set-Content $mainDocFile -Encoding UTF8
    
    # Generate module documentation
    foreach ($domain in $projectInfo.Domains) {
        foreach ($module in $domain.Modules) {
            try {
                New-ModuleDocumentation -ModulePath $module.Path -OutputPath (Join-Path $outputDir "modules")
            } catch {
                Write-DocLog "Failed to generate documentation for module $($module.Name): $($_.Exception.Message)" -Level Warning
            }
        }
    }
    
    # Generate navigation index
    New-DocumentationIndex -OutputPath $outputDir -ProjectInfo $projectInfo
    
    $totalModules = if ($projectInfo.Domains -and $projectInfo.Domains.Count -gt 0) {
        $counts = $projectInfo.Domains | ForEach-Object { 
            if ($_.Modules) { $_.Modules.Count } else { 0 }
        }
        ($counts | Measure-Object -Sum).Sum
    } else { 0 }
    
    Write-DocLog "Project documentation generated successfully" -Data @{
        MainDoc = $mainDocFile
        Modules = $totalModules
    }
    
    return $mainDocFile
}

function New-DocumentationIndex {
    param(
        [string]$OutputPath,
        [hashtable]$ProjectInfo
    )
    
    $indexContent = @"
# Documentation Index

## Project Documentation
- [Main Project Documentation](PROJECT-DOCUMENTATION.md)

## Module Documentation
"@
    
    foreach ($domain in $ProjectInfo.Domains) {
        $indexContent += "`n### $($domain.Name)`n"
        foreach ($module in $domain.Modules) {
            $indexContent += "- [$($module.Name)](modules/$($module.Name).md)`n"
        }
    }
    
    $indexContent += @"

## Navigation
- [Installation Guide](../README.md#installation)
- [Quick Start](../README.md#quick-start)
- [Configuration](CONFIGURATION.md)
- [Development Guide](DEVELOPMENT-SETUP.md)

---
*Generated automatically on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*
"@
    
    $indexFile = Join-Path $OutputPath "index.md"
    $indexContent | Set-Content $indexFile -Encoding UTF8
    Write-DocLog "Documentation index created: $indexFile"
}

#endregion

#region Analysis Functions

function Get-ModuleAnalysis {
    param([string]$ModulePath)
    
    $content = Get-Content $ModulePath -Raw
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)
    
    # Parse AST for detailed analysis
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
    
    # Extract functions
    $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    
    $functionInfo = foreach ($function in $functions) {
        $help = Get-FunctionHelp -FunctionAst $function -Content $content
        @{
            Name = $function.Name
            Synopsis = $help.Synopsis
            Description = $help.Description
            Parameters = $help.Parameters
            Examples = $help.Examples
        }
    }
    
    # Extract module description from comment-based help
    $moduleHelp = Get-ModuleHelp -Content $content
    
    return @{
        Name = $moduleName
        Description = $moduleHelp.Description
        Path = $ModulePath
        Functions = $functionInfo
        Dependencies = Get-ModuleDependencies -Content $content
        VersionHistory = Get-ModuleVersionHistory -ModulePath $ModulePath
    }
}

function Get-ProjectAnalysis {
    param([switch]$IncludePrivate)
    
    $projectName = "AitherZero"
    $domainsPath = Join-Path $script:ProjectRoot "domains"
    
    $domains = if (Test-Path $domainsPath) {
        @(Get-ChildItem -Path $domainsPath -Directory | ForEach-Object {
            $domainPath = $_.FullName
            $moduleFiles = @(Get-ChildItem -Path $domainPath -Filter "*.psm1")
            $modules = @($moduleFiles | ForEach-Object {
                @{
                    Name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    Path = $_.FullName
                    LastModified = $_.LastWriteTime
                }
            })
            
            @{
                Name = $_.Name
                Description = Get-DomainDescription -DomainPath $domainPath
                ModuleCount = $moduleFiles.Count
                FunctionCount = (Get-DomainFunctionCount -DomainPath $domainPath)
                Modules = $modules
            }
        })
    } else {
        @()
    }
    
    try {
        $projectInfo = @{
            Name = $projectName
            Description = (Get-ProjectDescription)
            QuickStart = (Get-ProjectQuickStart)
            Domains = $domains
            Installation = (Get-InstallationInstructions)
            Examples = (Get-ProjectExamples)
            Contributing = (Get-ContributingGuidelines)
        }
    } catch {
        Write-DocLog "Error generating project info: $($_.Exception.Message)" -Level Warning
        $projectInfo = @{
            Name = $projectName
            Description = "AitherZero infrastructure automation platform"
            QuickStart = "See README.md for quick start instructions"
            Domains = $domains
            Installation = "See README.md for installation instructions"
            Examples = "See documentation for usage examples"
            Contributing = "See CONTRIBUTING.md for guidelines"
        }
    }
    
    return $projectInfo
}

function Get-FunctionHelp {
    param(
        [System.Management.Automation.Language.FunctionDefinitionAst]$FunctionAst,
        [string]$Content
    )
    
    # Extract comment-based help from function
    $functionStart = $FunctionAst.Extent.StartOffset
    $functionContent = $Content.Substring($functionStart, $FunctionAst.Extent.EndOffset - $functionStart)
    
    $synopsis = if ($functionContent -match '(?s)\.SYNOPSIS\s+(.*?)(?=\s*\.|\s*#>|\s*param)') {
        $Matches[1].Trim()
    } else {
        "No synopsis available"
    }
    
    $description = if ($functionContent -match '(?s)\.DESCRIPTION\s+(.*?)(?=\s*\.|\s*#>|\s*param)') {
        $Matches[1].Trim()
    } else {
        "No description available"
    }
    
    return @{
        Synopsis = $synopsis
        Description = $description
        Parameters = @()  # Simplified for now
        Examples = @()    # Simplified for now
    }
}

function Get-ModuleHelp {
    param([string]$Content)
    
    # Extract module-level comment-based help
    if ($Content -match '<#[\s\S]*?\.DESCRIPTION\s+(.*?)[\s\S]*?#>') {
        return @{
            Description = $Matches[1].Trim()
        }
    }
    
    return @{
        Description = "PowerShell module for AitherZero automation platform"
    }
}

function Get-ModuleDependencies {
    param([string]$Content)
    
    $dependencies = @()
    
    # Look for Import-Module statements
    $imports = [regex]::Matches($Content, 'Import-Module\s+(["\''](.*?)["\'']|\S+)')
    foreach ($import in $imports) {
        $moduleName = if ($import.Groups[2].Success) { $import.Groups[2].Value } else { $import.Groups[1].Value }
        $dependencies += @{
            Name = $moduleName
            Version = "Unknown"
        }
    }
    
    return $dependencies
}

function Get-ModuleVersionHistory {
    param([string]$ModulePath)
    
    # Simplified version history - could be enhanced to read from git or version files
    return "Version history not available"
}

function Get-DomainDescription {
    param([string]$DomainPath)
    
    $readmePath = Join-Path $DomainPath "README.md"
    if (Test-Path $readmePath) {
        $readmeContent = Get-Content $readmePath -Raw
        if ($readmeContent -match '^#[^#].*?\n(.*?)(?=\n#|\n```|\Z)') {
            return $Matches[1].Trim()
        }
    }
    
    return "Domain for $([System.IO.Path]::GetFileName($DomainPath)) functionality"
}

function Get-DomainFunctionCount {
    param([string]$DomainPath)
    
    $totalFunctions = 0
    $moduleFiles = Get-ChildItem -Path $DomainPath -Filter "*.psm1"
    
    foreach ($moduleFile in $moduleFiles) {
        try {
            $content = Get-Content $moduleFile.FullName -Raw
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
            $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
            $totalFunctions += $functions.Count
        } catch {
            Write-DocLog "Failed to parse module $($moduleFile.Name): $_" -Level Warning
        }
    }
    
    return $totalFunctions
}

function Get-ProjectDescription {
    $readmePath = Join-Path $script:ProjectRoot "README.md"
    if (Test-Path $readmePath) {
        $content = Get-Content $readmePath -Raw
        if ($content -match 'Infrastructure automation platform.*?\n(.*?)(?=\n##|\n```|\Z)') {
            return $Matches[0].Trim()
        }
    }
    
    return "AitherZero is an infrastructure automation platform with AI-powered orchestration"
}

function Get-ProjectQuickStart {
    return @"
```powershell
# Install and start AitherZero
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex
./Start-AitherZero.ps1

# Or use the command runner
./az 0511           # Show project dashboard
./az 0402           # Run unit tests  
./az 0510           # Generate project report
```
"@
}

function Get-InstallationInstructions {
    return @"
### One-Liner Installation (Recommended)

**Windows/Linux/macOS (PowerShell 5.1+)**
```powershell
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex
```

**Linux/macOS (Bash)**  
```bash
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
```

### Manual Installation

1. Clone the repository
2. Run the bootstrap script
3. Start AitherZero

See the main README.md for detailed installation instructions.
"@
}

function Get-ProjectExamples {
    return @"
```powershell
# Basic usage
Import-Module ./AitherZero.psd1
./Start-AitherZero.ps1

# Generate documentation
New-ProjectDocumentation -OutputPath "./docs/generated"

# Run automation scripts
./az 0402  # Unit tests
./az 0510  # Project report
./az 0701  # Create feature branch
```
"@
}

function Get-ContributingGuidelines {
    return @"
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Update documentation
7. Submit a pull request

See CONTRIBUTING.md for detailed guidelines.
"@
}

#endregion

#region Validation and Quality

function Test-DocumentationQuality {
    <#
    .SYNOPSIS
        Validate documentation quality and coverage
    .PARAMETER Path
        Path to documentation directory or specific file
    .PARAMETER Rules
        Validation rules to apply
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $null,
        [string[]]$Rules = @()
    )
    
    $Path = $Path ?? $script:DocumentationState.Config.OutputDirectory
    
    Write-DocLog "Validating documentation quality for: $Path"
    
    $validationResults = @{
        Coverage = @{}
        Quality = @{}
        Issues = @()
        Score = 0
        Passed = $false
    }
    
    # Coverage analysis
    $coverage = Get-DocumentationCoverage -Path $Path
    $validationResults.Coverage = $coverage
    
    # Content quality checks
    $contentResults = Test-DocumentationContent -Path $Path
    $validationResults.Quality.Content = $contentResults
    
    # Calculate overall score
    $score = Calculate-DocumentationScore -Results $validationResults
    $validationResults.Score = $score
    
    # Check quality gates
    $minCoverage = $script:DocumentationState.Config.QualityGates.MinimumCoverage
    $validationResults.Passed = $score -ge $minCoverage
    
    Write-DocLog "Documentation validation completed" -Data @{
        Score = $score
        Passed = $validationResults.Passed
        Issues = $validationResults.Issues.Count
    }
    
    return $validationResults
}

function Get-DocumentationCoverage {
    param([string]$Path)
    
    # Implementation of coverage analysis
    $totalModules = 0
    $documentedModules = 0
    
    $domainsPath = Join-Path $script:ProjectRoot "domains"
    if (Test-Path $domainsPath) {
        $moduleFiles = Get-ChildItem -Path $domainsPath -Filter "*.psm1" -Recurse
        $totalModules = $moduleFiles.Count
        
        # Check if documentation exists for each module
        foreach ($module in $moduleFiles) {
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($module.Name)
            $docPath = Join-Path $Path "modules/$moduleName.md"
            if (Test-Path $docPath) {
                $documentedModules++
            }
        }
    }
    
    $coveragePercentage = if ($totalModules -gt 0) {
        [math]::Round(($documentedModules / $totalModules) * 100, 2)
    } else { 0 }
    
    return @{
        TotalModules = $totalModules
        DocumentedModules = $documentedModules
        TotalFunctions = 0  # TODO: Implement function counting
        DocumentedFunctions = 0  # TODO: Implement function documentation checking
        CoveragePercentage = $coveragePercentage
    }
}

function Test-DocumentationContent {
    param([string]$Path)
    
    $issues = @()
    
    if (Test-Path $Path) {
        $docFiles = Get-ChildItem -Path $Path -Filter "*.md" -Recurse
        
        foreach ($file in $docFiles) {
            $content = Get-Content $file.FullName -Raw
            
            # Apply validation rules
            foreach ($rule in $script:DocumentationState.ValidationRules) {
                try {
                    $result = & $rule.Check $content $file.DirectoryName
                    if (-not $result) {
                        $issues += @{
                            File = $file.FullName
                            Rule = $rule.Name
                            Description = $rule.Description
                        }
                    }
                } catch {
                    Write-DocLog "Validation rule $($rule.Name) failed for $($file.Name): $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }
    
    return @{
        Issues = $issues
        FilesChecked = $docFiles.Count
    }
}

function Calculate-DocumentationScore {
    param([hashtable]$Results)
    
    $coverageScore = $Results.Coverage.CoveragePercentage ?? 0
    $qualityScore = if ($Results.Quality.Content.Issues.Count -eq 0) { 100 } else { 
        100 - [math]::Min(($Results.Quality.Content.Issues.Count * 10), 100)
    }
    
    # Weighted average: 70% coverage, 30% quality
    return [math]::Round(($coverageScore * 0.7) + ($qualityScore * 0.3), 2)
}

function Test-DocumentationLinks {
    param(
        [string]$Content,
        [string]$BasePath
    )
    
    # Simplified link validation - check if referenced files exist
    $links = [regex]::Matches($Content, '\[.*?\]\((.*?)\)')
    
    foreach ($link in $links) {
        $linkPath = $link.Groups[1].Value
        
        # Skip external links
        if ($linkPath -match '^https?://') {
            continue
        }
        
        # Check if internal file exists
        $fullPath = Join-Path $BasePath $linkPath
        if (-not (Test-Path $fullPath)) {
            return $false
        }
    }
    
    return $true
}

#endregion

#region Utility Functions

function Expand-Template {
    param(
        [string]$Template,
        [hashtable]$Data
    )
    
    $result = $Template
    
    # Simple template expansion - replace {{PropertyName}} with values
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($value -is [array]) {
            # Handle arrays (like functions, parameters)
            $sectionPattern = "{{#$key}}(.*?){{/$key}}"
            if ($result -match $sectionPattern) {
                $sectionTemplate = $Matches[1]
                $expandedSections = ""
                
                foreach ($item in $value) {
                    $itemContent = $sectionTemplate
                    if ($item -is [hashtable]) {
                        foreach ($itemKey in $item.Keys) {
                            $itemContent = $itemContent -replace "{{$itemKey}}", $item[$itemKey]
                        }
                    } else {
                        $itemContent = $itemContent -replace "{{\.}}", $item
                    }
                    $expandedSections += $itemContent
                }
                
                $result = $result -replace $sectionPattern, $expandedSections
            }
        } else {
            $result = $result -replace "{{$key}}", $value
        }
    }
    
    # Clean up any remaining template markers with proper matching
    $result = $result -replace '{{#(\w+)}}.*?{{/\1}}', ''
    $result = $result -replace '{{\w+}}', ''
    
    return $result
}

function ConvertTo-Html {
    param(
        [string]$InputObject,
        [string]$OutputPath
    )
    
    # Enhanced Markdown to HTML conversion with proper escaping
    $escapedContent = $InputObject -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
    
    # Convert Markdown elements to HTML
    $htmlContent = $escapedContent `
        -replace '(?m)^# (.*)', '<h1>$1</h1>' `
        -replace '(?m)^## (.*)', '<h2>$1</h2>' `
        -replace '(?m)^### (.*)', '<h3>$1</h3>' `
        -replace '(?m)^#### (.*)', '<h4>$1</h4>' `
        -replace '(?s)```(\w+)?\s*(.*?)```', '<pre><code class="language-$1">$2</code></pre>' `
        -replace '`([^`]+)`', '<code>$1</code>' `
        -replace '\*\*(.*?)\*\*', '<strong>$1</strong>' `
        -replace '\*(.*?)\*', '<em>$1</em>' `
        -replace '(?m)^- (.*)', '<li>$1</li>' `
        -replace '(?s)(<li>.*</li>)', '<ul>$1</ul>' `
        -replace '\n', '<br>'
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Documentation</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; margin: 40px; }
        h1, h2, h3, h4, h5, h6 { color: #333; margin-top: 2em; margin-bottom: 1em; }
        code { background-color: #f4f4f4; padding: 2px 4px; border-radius: 3px; font-family: 'Consolas', monospace; }
        pre { background-color: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        blockquote { border-left: 4px solid #ddd; margin: 0; padding-left: 20px; color: #666; }
        ul { margin: 1em 0; padding-left: 2em; }
        li { margin: 0.5em 0; }
        strong { font-weight: 600; }
        em { font-style: italic; }
    </style>
</head>
<body>
$htmlContent
</body>
</html>
"@
    
    $html | Set-Content $OutputPath -Encoding UTF8
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Initialize-DocumentationEngine',
    'New-ModuleDocumentation', 
    'New-ProjectDocumentation',
    'Test-DocumentationQuality',
    'Get-DocumentationCoverage'
)

# Initialize logging
Write-DocLog "Documentation Engine module loaded successfully"