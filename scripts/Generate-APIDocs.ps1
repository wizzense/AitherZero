#Requires -Version 7.0
<#
.SYNOPSIS
    Generates comprehensive API documentation for AitherZero modules
.DESCRIPTION
    Scans all PowerShell modules in the AitherZero project and generates
    detailed API documentation including functions, parameters, examples,
    and module dependencies.
.PARAMETER OutputPath
    Path where documentation files will be generated
.PARAMETER Format
    Output format: Markdown, HTML, or JSON
.PARAMETER ModuleFilter
    Optional filter to generate docs for specific modules only
.PARAMETER IncludePrivate
    Include private/internal functions in documentation
.EXAMPLE
    ./Generate-APIDocs.ps1 -OutputPath "./docs/api" -Format "Markdown"
.EXAMPLE
    ./Generate-APIDocs.ps1 -ModuleFilter "PatchManager,Logging" -IncludePrivate
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./docs/api",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Markdown", "HTML", "JSON")]
    [string]$Format = "Markdown",
    
    [Parameter(Mandatory = $false)]
    [string[]]$ModuleFilter = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludePrivate
)

# Initialize logging for this script
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

function Find-ProjectRoot {
    $currentPath = $PSScriptRoot
    while ($currentPath -and -not (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1"))) {
        $currentPath = Split-Path $currentPath -Parent
    }
    if (-not $currentPath) {
        throw "Could not find project root (looking for Start-AitherZero.ps1)"
    }
    return $currentPath
}

function Get-ModuleInfo {
    param(
        [string]$ModulePath,
        [string]$ModuleName
    )
    
    $moduleInfo = @{
        Name = $ModuleName
        Path = $ModulePath
        ManifestPath = $null
        ModulePath = $null
        Functions = @()
        Description = ""
        Version = ""
        Author = ""
        Dependencies = @()
    }
    
    # Find manifest file
    $manifestPath = Join-Path $ModulePath "$ModuleName.psd1"
    if (Test-Path $manifestPath) {
        $moduleInfo.ManifestPath = $manifestPath
        try {
            $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
            if ($manifest) {
                $moduleInfo.Description = $manifest.Description ?? ""
                $moduleInfo.Version = $manifest.ModuleVersion ?? "1.0.0"
                $moduleInfo.Author = $manifest.Author ?? ""
                $moduleInfo.Dependencies = $manifest.RequiredModules ?? @()
            }
        } catch {
            Write-Warning "Could not parse manifest for $ModuleName`: $($_.Exception.Message)"
        }
    }
    
    # Find module file
    $modulePsm1Path = Join-Path $ModulePath "$ModuleName.psm1"
    if (Test-Path $modulePsm1Path) {
        $moduleInfo.ModulePath = $modulePsm1Path
    }
    
    return $moduleInfo
}

function Get-FunctionInfo {
    param(
        [string]$FunctionPath,
        [string]$FunctionName
    )
    
    $functionInfo = @{
        Name = $FunctionName
        Path = $FunctionPath
        Synopsis = ""
        Description = ""
        Parameters = @()
        Examples = @()
        Notes = ""
        IsPrivate = $FunctionPath -match "Private"
    }
    
    try {
        $content = Get-Content -Path $FunctionPath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            # Extract help comment
            if ($content -match '(?s)<#(.*?)#>') {
                $helpBlock = $Matches[1]
                
                # Extract synopsis
                if ($helpBlock -match '\.SYNOPSIS\s*(.*?)(?=\.|$)') {
                    $functionInfo.Synopsis = $Matches[1].Trim()
                }
                
                # Extract description
                if ($helpBlock -match '\.DESCRIPTION\s*(.*?)(?=\.(?:PARAMETER|EXAMPLE|NOTES)|$)') {
                    $functionInfo.Description = $Matches[1].Trim()
                }
                
                # Extract examples
                $exampleMatches = [regex]::Matches($helpBlock, '\.EXAMPLE\s*(.*?)(?=\.(?:PARAMETER|EXAMPLE|NOTES|SYNOPSIS|DESCRIPTION)|$)')
                foreach ($match in $exampleMatches) {
                    $functionInfo.Examples += $match.Groups[1].Value.Trim()
                }
                
                # Extract notes
                if ($helpBlock -match '\.NOTES\s*(.*?)(?=\.(?:PARAMETER|EXAMPLE|SYNOPSIS|DESCRIPTION)|$)') {
                    $functionInfo.Notes = $Matches[1].Value.Trim()
                }
            }
            
            # Extract function parameters
            if ($content -match 'param\s*\((.*?)\)') {
                $paramBlock = $Matches[1]
                $paramMatches = [regex]::Matches($paramBlock, '\[Parameter[^\]]*\]\s*(?:\[[^\]]+\])?\s*\$(\w+)')
                foreach ($match in $paramMatches) {
                    $functionInfo.Parameters += $match.Groups[1].Value
                }
            }
        }
    } catch {
        Write-Warning "Could not analyze function $FunctionName`: $($_.Exception.Message)"
    }
    
    return $functionInfo
}

function Generate-MarkdownDocs {
    param(
        [hashtable[]]$ModuleData,
        [string]$OutputPath
    )
    
    Write-Verbose "Generating Markdown documentation to $OutputPath"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Generate index file
    $indexContent = @"
# AitherZero API Documentation

This documentation was automatically generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').

## Available Modules

"@
    
    foreach ($module in $ModuleData | Sort-Object Name) {
        $indexContent += "`n- [$($module.Name)](./$($module.Name).md) - $($module.Description)"
    }
    
    $indexContent += @"

## Module Overview

| Module | Version | Functions | Description |
|--------|---------|-----------|-------------|
"@
    
    foreach ($module in $ModuleData | Sort-Object Name) {
        $publicFunctions = ($module.Functions | Where-Object { -not $_.IsPrivate }).Count
        $indexContent += "`n| $($module.Name) | $($module.Version) | $publicFunctions | $($module.Description) |"
    }
    
    Set-Content -Path (Join-Path $OutputPath "README.md") -Value $indexContent -Encoding UTF8
    
    # Generate individual module documentation
    foreach ($module in $ModuleData) {
        $moduleContent = @"
# $($module.Name) Module

**Version:** $($module.Version)  
**Author:** $($module.Author)

## Description
$($module.Description)

"@
        
        if ($module.Dependencies.Count -gt 0) {
            $moduleContent += @"
## Dependencies
$($module.Dependencies | ForEach-Object { "- $_" } | Out-String)

"@
        }
        
        # Public functions
        $publicFunctions = $module.Functions | Where-Object { -not $_.IsPrivate }
        if ($publicFunctions.Count -gt 0) {
            $moduleContent += @"
## Public Functions

"@
            foreach ($func in $publicFunctions | Sort-Object Name) {
                $moduleContent += @"
### $($func.Name)

**Synopsis:** $($func.Synopsis)

**Description:** $($func.Description)

"@
                if ($func.Parameters.Count -gt 0) {
                    $moduleContent += @"
**Parameters:**
$($func.Parameters | ForEach-Object { "- ``$_``" } | Out-String)
"@
                }
                
                if ($func.Examples.Count -gt 0) {
                    $moduleContent += @"
**Examples:**
``````powershell
$($func.Examples -join "`n")
``````

"@
                }
                
                if ($func.Notes) {
                    $moduleContent += @"
**Notes:** $($func.Notes)

"@
                }
            }
        }
        
        # Private functions (if requested)
        if ($IncludePrivate) {
            $privateFunctions = $module.Functions | Where-Object { $_.IsPrivate }
            if ($privateFunctions.Count -gt 0) {
                $moduleContent += @"
## Private Functions

"@
                foreach ($func in $privateFunctions | Sort-Object Name) {
                    $moduleContent += "- $($func.Name): $($func.Synopsis)`n"
                }
            }
        }
        
        Set-Content -Path (Join-Path $OutputPath "$($module.Name).md") -Value $moduleContent -Encoding UTF8
    }
}

function Generate-JSONDocs {
    param(
        [hashtable[]]$ModuleData,
        [string]$OutputPath
    )
    
    Write-Verbose "Generating JSON documentation to $OutputPath"
    
    $jsonData = @{
        GeneratedAt = (Get-Date -Format 'o')
        AitherZeroVersion = (Get-Content (Join-Path (Find-ProjectRoot) "VERSION") -ErrorAction SilentlyContinue)
        Modules = $ModuleData
    }
    
    $jsonOutput = $jsonData | ConvertTo-Json -Depth 10
    Set-Content -Path (Join-Path $OutputPath "api.json") -Value $jsonOutput -Encoding UTF8
}

# Main execution
try {
    Write-Verbose "Starting API documentation generation..."
    
    $projectRoot = Find-ProjectRoot
    $modulesPath = Join-Path $projectRoot "aither-core" "modules"
    
    if (-not (Test-Path $modulesPath)) {
        throw "Modules directory not found at $modulesPath"
    }
    
    # Discover all modules
    $modules = Get-ChildItem -Path $modulesPath -Directory | Where-Object { 
        $_.Name -notin @('packages-microsoft-prod.deb') -and
        ($ModuleFilter.Count -eq 0 -or $_.Name -in $ModuleFilter)
    }
    
    Write-Verbose "Found $($modules.Count) modules to document"
    
    $moduleData = @()
    
    foreach ($module in $modules) {
        Write-Verbose "Processing module: $($module.Name)"
        
        $moduleInfo = Get-ModuleInfo -ModulePath $module.FullName -ModuleName $module.Name
        
        # Scan for functions in Public directory
        $publicPath = Join-Path $module.FullName "Public"
        if (Test-Path $publicPath) {
            $functions = Get-ChildItem -Path $publicPath -Filter "*.ps1" -Recurse
            foreach ($function in $functions) {
                $functionName = [System.IO.Path]::GetFileNameWithoutExtension($function.Name)
                $functionInfo = Get-FunctionInfo -FunctionPath $function.FullName -FunctionName $functionName
                $moduleInfo.Functions += $functionInfo
            }
        }
        
        # Scan for functions in Private directory (if requested)
        if ($IncludePrivate) {
            $privatePath = Join-Path $module.FullName "Private"
            if (Test-Path $privatePath) {
                $functions = Get-ChildItem -Path $privatePath -Filter "*.ps1" -Recurse
                foreach ($function in $functions) {
                    $functionName = [System.IO.Path]::GetFileNameWithoutExtension($function.Name)
                    $functionInfo = Get-FunctionInfo -FunctionPath $function.FullName -FunctionName $functionName
                    $moduleInfo.Functions += $functionInfo
                }
            }
        }
        
        $moduleData += $moduleInfo
    }
    
    # Generate documentation based on format
    switch ($Format) {
        "Markdown" { Generate-MarkdownDocs -ModuleData $moduleData -OutputPath $OutputPath }
        "JSON" { Generate-JSONDocs -ModuleData $moduleData -OutputPath $OutputPath }
        "HTML" { 
            # For now, generate Markdown and note HTML support coming soon
            Generate-MarkdownDocs -ModuleData $moduleData -OutputPath $OutputPath
            Write-Warning "HTML format not yet implemented. Generated Markdown instead."
        }
    }
    
    Write-Host "✅ API documentation generated successfully!" -ForegroundColor Green
    Write-Host "📁 Output location: $OutputPath" -ForegroundColor Cyan
    Write-Host "📊 Modules documented: $($moduleData.Count)" -ForegroundColor Cyan
    Write-Host "🔧 Total functions: $(($moduleData.Functions | Where-Object { -not $_.IsPrivate }).Count) public, $(($moduleData.Functions | Where-Object { $_.IsPrivate }).Count) private" -ForegroundColor Cyan
    
} catch {
    Write-Error "Failed to generate API documentation: $($_.Exception.Message)"
    exit 1
}