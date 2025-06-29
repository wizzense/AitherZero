#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Automated API documentation generator for AitherZero PowerShell modules
    
.DESCRIPTION
    This script generates comprehensive API documentation for all AitherZero modules using
    comment-based help and module metadata. It creates markdown documentation files that
    can be published as API reference documentation.
    
.PARAMETER OutputPath
    Directory where generated documentation will be saved
    
.PARAMETER ModulePath
    Path to the modules directory (defaults to aither-core/modules)
    
.PARAMETER Format
    Output format for documentation (Markdown, HTML, JSON)
    
.PARAMETER IncludePrivate
    Include private/internal functions in documentation
    
.PARAMETER GenerateIndex
    Generate a master index of all functions and modules
    
.PARAMETER ValidateHelp
    Validate that all public functions have complete help documentation
    
.EXAMPLE
    ./Generate-APIDocumentation.ps1
    # Generates markdown documentation for all modules
    
.EXAMPLE
    ./Generate-APIDocumentation.ps1 -OutputPath "./docs/api" -GenerateIndex -ValidateHelp
    # Generates documentation with index and validation
    
.EXAMPLE
    ./Generate-APIDocumentation.ps1 -Format HTML,JSON -IncludePrivate
    # Generates multiple formats including private functions
    
.NOTES
    Version: 1.0.0
    Author: AitherZero Development Team
    Purpose: Automated API documentation generation for enterprise integration
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./docs/api",
    
    [Parameter(Mandatory = $false)]
    [string]$ModulePath = "./aither-core/modules",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Markdown", "HTML", "JSON")]
    [string[]]$Format = @("Markdown"),
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludePrivate,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateIndex,
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidateHelp
)

# Import required modules and utilities
try {
    $scriptRoot = $PSScriptRoot
    if (-not $scriptRoot) {
        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    
    # Import shared utilities
    . (Join-Path $scriptRoot "aither-core/shared/Find-ProjectRoot.ps1")
    $projectRoot = Find-ProjectRoot
    
    # Import logging if available
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Warning "Could not import shared utilities: $($_.Exception.Message)"
    $projectRoot = $scriptRoot
}

# Logging function
function Write-DocLog {
    param($Message, $Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $prefix = switch ($Level) {
            "ERROR" { "[ERROR]" }
            "WARN" { "[WARN]" }
            "SUCCESS" { "[SUCCESS]" }
            default { "[INFO]" }
        }
        Write-Host "$prefix $Message"
    }
}

# Function to discover all modules
function Get-AitherModules {
    param([string]$ModulesPath)
    
    Write-DocLog "Discovering modules in: $ModulesPath"
    
    $modules = @()
    $moduleDirectories = Get-ChildItem -Path $ModulesPath -Directory -ErrorAction SilentlyContinue
    
    foreach ($moduleDir in $moduleDirectories) {
        $manifestPath = Join-Path $moduleDir.FullName "$($moduleDir.Name).psd1"
        $modulePath = Join-Path $moduleDir.FullName "$($moduleDir.Name).psm1"
        
        if (Test-Path $manifestPath) {
            try {
                $manifest = Import-PowerShellDataFile -Path $manifestPath
                
                $moduleInfo = [PSCustomObject]@{
                    Name = $moduleDir.Name
                    Path = $moduleDir.FullName
                    ManifestPath = $manifestPath
                    ModulePath = $modulePath
                    Manifest = $manifest
                    Version = $manifest.ModuleVersion
                    Description = $manifest.Description
                    Functions = @()
                    PublicFunctions = @()
                    PrivateFunctions = @()
                }
                
                $modules += $moduleInfo
                Write-DocLog "Found module: $($moduleDir.Name) v$($manifest.ModuleVersion)"
            } catch {
                Write-DocLog "Failed to read manifest for $($moduleDir.Name): $($_.Exception.Message)" -Level "WARN"
            }
        }
    }
    
    Write-DocLog "Discovered $($modules.Count) modules"
    return $modules
}

# Function to get all functions from a module
function Get-ModuleFunctions {
    param(
        [PSCustomObject]$Module,
        [switch]$IncludePrivate
    )
    
    Write-DocLog "Analyzing functions in module: $($Module.Name)"
    
    $functions = @()
    
    # Get public functions
    $publicPath = Join-Path $Module.Path "Public"
    if (Test-Path $publicPath) {
        $publicFiles = Get-ChildItem -Path $publicPath -Filter "*.ps1" -Recurse
        foreach ($file in $publicFiles) {
            $functionInfo = Get-FunctionInfo -FilePath $file.FullName -FunctionType "Public"
            if ($functionInfo) {
                $functions += $functionInfo
                $Module.PublicFunctions += $functionInfo
            }
        }
    }
    
    # Get private functions if requested
    if ($IncludePrivate) {
        $privatePath = Join-Path $Module.Path "Private"
        if (Test-Path $privatePath) {
            $privateFiles = Get-ChildItem -Path $privatePath -Filter "*.ps1" -Recurse
            foreach ($file in $privateFiles) {
                $functionInfo = Get-FunctionInfo -FilePath $file.FullName -FunctionType "Private"
                if ($functionInfo) {
                    $functions += $functionInfo
                    $Module.PrivateFunctions += $functionInfo
                }
            }
        }
    }
    
    # Check for functions in root module file
    if (Test-Path $Module.ModulePath) {
        $rootFunctions = Get-FunctionInfo -FilePath $Module.ModulePath -FunctionType "Module"
        if ($rootFunctions) {
            $functions += $rootFunctions
        }
    }
    
    $Module.Functions = $functions
    Write-DocLog "Found $($functions.Count) functions in $($Module.Name)"
    
    return $functions
}

# Function to extract function information including help
function Get-FunctionInfo {
    param(
        [string]$FilePath,
        [string]$FunctionType = "Public"
    )
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    try {
        $content = Get-Content -Path $FilePath -Raw
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        
        $functionDefinitions = $ast.FindAll({
            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)
        
        $functions = @()
        
        foreach ($funcDef in $functionDefinitions) {
            # Extract comment-based help
            $help = Get-CommentBasedHelp -FunctionDefinition $funcDef -FileContent $content
            
            $functionInfo = [PSCustomObject]@{
                Name = $funcDef.Name
                FilePath = $FilePath
                Type = $FunctionType
                Parameters = @()
                Synopsis = $help.Synopsis
                Description = $help.Description
                Examples = $help.Examples
                Notes = $help.Notes
                HelpParameters = $help.Parameters
                Outputs = $help.Outputs
                Links = $help.Links
                Syntax = $funcDef.Body.ParamBlock.ToString()
            }
            
            # Extract parameter information
            if ($funcDef.Body.ParamBlock) {
                foreach ($param in $funcDef.Body.ParamBlock.Parameters) {
                    $paramInfo = [PSCustomObject]@{
                        Name = $param.Name.VariablePath.UserPath
                        Type = if ($param.StaticType) { $param.StaticType.Name } else { "Object" }
                        Mandatory = $param.Attributes | Where-Object { $_.TypeName.Name -eq "Parameter" } | ForEach-Object { $_.NamedArguments | Where-Object { $_.ArgumentName -eq "Mandatory" } | Select-Object -ExpandProperty Argument -First 1 }
                        DefaultValue = if ($param.DefaultValue) { $param.DefaultValue.ToString() } else { $null }
                        ValidateSet = $param.Attributes | Where-Object { $_.TypeName.Name -eq "ValidateSet" } | ForEach-Object { $_.PositionalArguments | ForEach-Object { $_.Value } }
                    }
                    $functionInfo.Parameters += $paramInfo
                }
            }
            
            $functions += $functionInfo
        }
        
        return $functions
    } catch {
        Write-DocLog "Error parsing ${FilePath}: $($_.Exception.Message)" -Level "WARN"
        return $null
    }
}

# Function to extract comment-based help
function Get-CommentBasedHelp {
    param(
        [System.Management.Automation.Language.FunctionDefinitionAst]$FunctionDefinition,
        [string]$FileContent
    )
    
    $help = [PSCustomObject]@{
        Synopsis = ""
        Description = ""
        Parameters = @{}
        Examples = @()
        Notes = ""
        Outputs = ""
        Links = @()
    }
    
    # Find comment-based help before the function
    $lines = $FileContent -split "`n"
    $functionStart = $FunctionDefinition.Extent.StartLineNumber - 1
    
    # Look backwards for comment block
    $helpLines = @()
    for ($i = $functionStart - 1; $i -ge 0; $i--) {
        $line = $lines[$i].Trim()
        if ($line -match "^#>$") {
            break
        }
        if ($line -match "^#" -or $line -match "^<#") {
            $helpLines = @($line) + $helpLines
        } elseif ($line -eq "" -and $helpLines.Count -gt 0) {
            continue
        } else {
            break
        }
    }
    
    # Parse help content
    $currentSection = ""
    $currentContent = @()
    
    foreach ($line in $helpLines) {
        $cleanLine = $line -replace "^#\s*" -replace "^<#\s*" -replace "^#>$"
        
        if ($cleanLine -match "^\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|NOTES|OUTPUTS|LINK)(\s+.*)?$") {
            # Process previous section
            if ($currentSection -and $currentContent.Count -gt 0) {
                Set-HelpSection -Help $help -Section $currentSection -Content $currentContent
            }
            
            $currentSection = $matches[1]
            $currentContent = @()
            
            if ($matches[2]) {
                $currentContent += $matches[2].Trim()
            }
        } elseif ($currentSection -and $cleanLine) {
            $currentContent += $cleanLine
        }
    }
    
    # Process final section
    if ($currentSection -and $currentContent.Count -gt 0) {
        Set-HelpSection -Help $help -Section $currentSection -Content $currentContent
    }
    
    return $help
}

# Function to set help section content
function Set-HelpSection {
    param(
        [PSCustomObject]$Help,
        [string]$Section,
        [string[]]$Content
    )
    
    switch ($Section) {
        "SYNOPSIS" { $Help.Synopsis = ($Content -join " ").Trim() }
        "DESCRIPTION" { $Help.Description = ($Content -join "`n").Trim() }
        "NOTES" { $Help.Notes = ($Content -join "`n").Trim() }
        "OUTPUTS" { $Help.Outputs = ($Content -join "`n").Trim() }
        "EXAMPLE" { 
            $Help.Examples += [PSCustomObject]@{
                Title = if ($Content[0] -match "^\s*(.+)$") { $matches[1] } else { "Example" }
                Code = ($Content[1..($Content.Count-1)] -join "`n").Trim()
            }
        }
        "PARAMETER" {
            if ($Content[0] -match "^(\w+)\s*(.*)$") {
                $paramName = $matches[1]
                $paramDesc = if ($matches[2]) { $matches[2] } else { "" }
                if ($Content.Count -gt 1) {
                    $paramDesc += "`n" + (($Content[1..($Content.Count-1)] -join "`n").Trim())
                }
                $Help.Parameters[$paramName] = $paramDesc.Trim()
            }
        }
        "LINK" { $Help.Links += ($Content -join " ").Trim() }
    }
}

# Function to generate markdown documentation
function New-MarkdownDocumentation {
    param(
        [PSCustomObject[]]$Modules,
        [string]$OutputPath
    )
    
    Write-DocLog "Generating markdown documentation..."
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Generate documentation for each module
    foreach ($module in $Modules) {
        Write-DocLog "Generating documentation for module: $($module.Name)"
        
        $moduleDoc = @"
# $($module.Name) Module

**Version:** $($module.Version)  
**Description:** $($module.Description)

## Overview

$(if ($module.Description) { $module.Description } else { "PowerShell module for $($module.Name) functionality." })

## Functions

"@
        
        foreach ($function in $module.PublicFunctions) {
            $moduleDoc += @"

### $($function.Name)

**Synopsis:** $($function.Synopsis)

**Description:**
$($function.Description)

#### Syntax
``````powershell
$($function.Syntax)
``````

"@
            
            if ($function.Parameters.Count -gt 0) {
                $moduleDoc += "`n#### Parameters`n`n"
                foreach ($param in $function.Parameters) {
                    $moduleDoc += "- **$($param.Name)** [$($param.Type)]"
                    if ($param.Mandatory) { $moduleDoc += " *(Required)*" }
                    if ($param.DefaultValue) { $moduleDoc += " *(Default: $($param.DefaultValue))*" }
                    $moduleDoc += "`n"
                    
                    if ($function.HelpParameters[$param.Name]) {
                        $moduleDoc += "  $($function.HelpParameters[$param.Name])`n"
                    }
                    
                    if ($param.ValidateSet) {
                        $moduleDoc += "  Valid values: $($param.ValidateSet -join ', ')`n"
                    }
                    $moduleDoc += "`n"
                }
            }
            
            if ($function.Examples.Count -gt 0) {
                $moduleDoc += "`n#### Examples`n`n"
                $exampleNum = 1
                foreach ($example in $function.Examples) {
                    $moduleDoc += "**Example ${exampleNum}:**`n"
                    $moduleDoc += "``````powershell`n$($example.Code)`n```````n`n"
                    $exampleNum++
                }
            }
            
            if ($function.Notes) {
                $moduleDoc += "`n#### Notes`n$($function.Notes)`n"
            }
        }
        
        # Add private functions section if included
        if ($IncludePrivate -and $module.PrivateFunctions.Count -gt 0) {
            $moduleDoc += "`n## Private Functions`n`n"
            foreach ($function in $module.PrivateFunctions) {
                $moduleDoc += "- **$($function.Name)**: $($function.Synopsis)`n"
            }
        }
        
        # Write module documentation
        $moduleFile = Join-Path $OutputPath "$($module.Name).md"
        $moduleDoc | Out-File -FilePath $moduleFile -Encoding UTF8
        Write-DocLog "Generated: $moduleFile" -Level "SUCCESS"
    }
}

# Function to generate API index
function New-APIIndex {
    param(
        [PSCustomObject[]]$Modules,
        [string]$OutputPath
    )
    
    Write-DocLog "Generating API index..."
    
    $indexDoc = @"
# AitherZero API Reference

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")  
**Version:** 1.0.0

## Modules Overview

| Module | Version | Functions | Description |
|--------|---------|-----------|-------------|
"@
    
    foreach ($module in $Modules) {
        $indexDoc += "| [$($module.Name)](./$($module.Name).md) | $($module.Version) | $($module.PublicFunctions.Count) | $($module.Description) |`n"
    }
    
    $indexDoc += @"

## All Functions

"@
    
    $allFunctions = @()
    foreach ($module in $Modules) {
        foreach ($function in $module.PublicFunctions) {
            $allFunctions += [PSCustomObject]@{
                Module = $module.Name
                Function = $function.Name
                Synopsis = $function.Synopsis
            }
        }
    }
    
    $sortedFunctions = $allFunctions | Sort-Object Function
    
    foreach ($func in $sortedFunctions) {
        $indexDoc += "- **[$($func.Function)](./$($func.Module).md#$($func.Function.ToLower()))** ($($func.Module)) - $($func.Synopsis)`n"
    }
    
    $indexDoc += @"

## Integration Patterns

### Module Dependencies
- **Core Modules**: Logging, SharedUtilities
- **Infrastructure**: OpenTofuProvider, SystemMonitoring
- **Development**: PatchManager, TestingFramework
- **Operations**: BackupManager, RemoteConnection

### Common Usage Patterns
- **Development Workflow**: PatchManager → TestingFramework → DevEnvironment
- **Infrastructure Deployment**: OpenTofuProvider → SystemMonitoring → RemoteConnection
- **Operations Management**: BackupManager → SystemMonitoring → SecureCredentials

## API Standards

### Common Parameters
All functions support standard PowerShell parameters:
- `-Verbose`: Detailed operation logging
- `-WhatIf`: Preview operations without execution
- `-Confirm`: Request confirmation for destructive operations

### Return Value Patterns
Functions return structured objects with consistent properties:
- `Success`: Boolean indicating operation success
- `Message`: Human-readable status message
- `Data`: Operation-specific result data
- `Error`: Error details if operation failed

### Error Handling
All functions implement comprehensive error handling:
- Try-catch blocks for external operations
- Detailed error logging via Write-CustomLog
- Graceful fallbacks for non-critical failures
- Consistent error object structure

"@
    
    $indexFile = Join-Path $OutputPath "README.md"
    $indexDoc | Out-File -FilePath $indexFile -Encoding UTF8
    Write-DocLog "Generated API index: $indexFile" -Level "SUCCESS"
}

# Function to validate help documentation
function Test-HelpDocumentation {
    param([PSCustomObject[]]$Modules)
    
    Write-DocLog "Validating help documentation..."
    
    $validationResults = @()
    $totalFunctions = 0
    $functionsWithHelp = 0
    
    foreach ($module in $Modules) {
        foreach ($function in $module.PublicFunctions) {
            $totalFunctions++
            
            $validation = [PSCustomObject]@{
                Module = $module.Name
                Function = $function.Name
                HasSynopsis = -not [string]::IsNullOrWhiteSpace($function.Synopsis)
                HasDescription = -not [string]::IsNullOrWhiteSpace($function.Description)
                HasExamples = $function.Examples.Count -gt 0
                HasParameters = $function.Parameters.Count -eq 0 -or ($function.HelpParameters.Count -gt 0)
                Score = 0
            }
            
            $validation.Score = ($validation.HasSynopsis -as [int]) + 
                               ($validation.HasDescription -as [int]) + 
                               ($validation.HasExamples -as [int]) + 
                               ($validation.HasParameters -as [int])
            
            if ($validation.Score -ge 3) {
                $functionsWithHelp++
            }
            
            $validationResults += $validation
        }
    }
    
    $coverage = [math]::Round(($functionsWithHelp / $totalFunctions) * 100, 1)
    
    Write-DocLog "Documentation coverage: $coverage% ($functionsWithHelp/$totalFunctions functions)"
    
    # Report functions with poor documentation
    $poorDocumentation = $validationResults | Where-Object { $_.Score -lt 3 }
    if ($poorDocumentation.Count -gt 0) {
        Write-DocLog "Functions needing documentation improvement:" -Level "WARN"
        foreach ($poor in $poorDocumentation) {
            Write-DocLog "  $($poor.Module)::$($poor.Function) (Score: $($poor.Score)/4)" -Level "WARN"
        }
    }
    
    return $validationResults
}

# Main execution
try {
    Write-DocLog "Starting API documentation generation" -Level "INFO"
    Write-DocLog "Output Path: $OutputPath"
    Write-DocLog "Module Path: $ModulePath"
    Write-DocLog "Formats: $($Format -join ', ')"
    
    # Resolve paths
    $ModulePath = Resolve-Path $ModulePath
    
    # Discover modules
    $modules = Get-AitherModules -ModulesPath $ModulePath
    
    if ($modules.Count -eq 0) {
        Write-DocLog "No modules found in $ModulePath" -Level "ERROR"
        exit 1
    }
    
    # Analyze functions in each module
    foreach ($module in $modules) {
        Get-ModuleFunctions -Module $module -IncludePrivate:$IncludePrivate
    }
    
    # Validate help documentation if requested
    if ($ValidateHelp) {
        $validationResults = Test-HelpDocumentation -Modules $modules
    }
    
    # Generate documentation in requested formats
    foreach ($fmt in $Format) {
        switch ($fmt) {
            "Markdown" {
                New-MarkdownDocumentation -Modules $modules -OutputPath $OutputPath
                if ($GenerateIndex) {
                    New-APIIndex -Modules $modules -OutputPath $OutputPath
                }
            }
            "HTML" {
                Write-DocLog "HTML generation not yet implemented" -Level "WARN"
            }
            "JSON" {
                Write-DocLog "JSON generation not yet implemented" -Level "WARN"
            }
        }
    }
    
    Write-DocLog "API documentation generation completed successfully" -Level "SUCCESS"
    Write-DocLog "Generated documentation for $($modules.Count) modules with $($modules.PublicFunctions.Count) total functions"
    
} catch {
    Write-DocLog "Failed to generate API documentation: $($_.Exception.Message)" -Level "ERROR"
    Write-DocLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}