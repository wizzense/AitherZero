#Requires -Version 7.0
<#
.SYNOPSIS
    Generate comprehensive interactive code map visualizer
.DESCRIPTION
    Creates a fully-featured interactive code map showing all PowerShell modules,
    functions, scripts, their relationships, usage patterns, and integration points.
    
    This generates a separate standalone HTML page with advanced visualization
    capabilities including call graphs, dependency trees, and usage analysis.

.PARAMETER ProjectPath
    Path to the project root directory
.PARAMETER OutputPath
    Path where code map will be generated
.PARAMETER Open
    Automatically open the code map in the default browser after generation

.EXAMPLE
    ./0514_Generate-CodeMap.ps1
.EXAMPLE
    ./0514_Generate-CodeMap.ps1 -Open

.NOTES
    Stage: Reporting
    Category: Visualization
    Order: 0514
    Dependencies: 0510, 0512
    Tags: reporting, visualization, code-map, dependency-graph
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$OutputPath = (Join-Path $ProjectPath "reports"),
    [switch]$Open
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import modules
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0514_Generate-CodeMap" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function Get-AllPowerShellFiles {
    <#
    .SYNOPSIS
        Get all PowerShell files in the project
    #>
    param([string]$Path)
    
    Write-ScriptLog -Message "Scanning for PowerShell files in: $Path"
    
    $files = @{
        Scripts = @()
        Modules = @()
        Data = @()
        Tests = @()
    }
    
    # Get scripts (.ps1)
    $scripts = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '(node_modules|\.git|legacy)' }
    
    foreach ($script in $scripts) {
        $relativePath = $script.FullName.Replace($Path, '').TrimStart('\', '/')
        $isTest = $relativePath -match 'tests/'
        
        if ($isTest) {
            $files.Tests += @{
                Path = $relativePath
                Name = $script.Name
                FullPath = $script.FullName
                Type = 'Test'
            }
        } else {
            $files.Scripts += @{
                Path = $relativePath
                Name = $script.Name
                FullPath = $script.FullName
                Type = 'Script'
            }
        }
    }
    
    # Get modules (.psm1)
    $modules = Get-ChildItem -Path $Path -Filter "*.psm1" -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '(node_modules|\.git|legacy)' }
    
    foreach ($module in $modules) {
        $relativePath = $module.FullName.Replace($Path, '').TrimStart('\', '/')
        $files.Modules += @{
            Path = $relativePath
            Name = $module.Name
            FullPath = $module.FullName
            Type = 'Module'
        }
    }
    
    # Get data files (.psd1)
    $dataFiles = Get-ChildItem -Path $Path -Filter "*.psd1" -Recurse -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch '(node_modules|\.git|legacy)' }
    
    foreach ($dataFile in $dataFiles) {
        $relativePath = $dataFile.FullName.Replace($Path, '').TrimStart('\', '/')
        $files.Data += @{
            Path = $relativePath
            Name = $dataFile.Name
            FullPath = $dataFile.FullName
            Type = 'Data'
        }
    }
    
    Write-ScriptLog -Message "Found files: $($files.Scripts.Count) scripts, $($files.Modules.Count) modules, $($files.Data.Count) data files, $($files.Tests.Count) tests"
    
    return $files
}

function Get-FunctionDefinitions {
    <#
    .SYNOPSIS
        Extract all function definitions from PowerShell files
    #>
    param(
        [string]$FilePath,
        [string]$RelativePath
    )
    
    $functions = @()
    
    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        
        # Match function definitions
        $pattern = '^\s*function\s+([A-Za-z0-9\-_]+)\s*(?:\{|$)'
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        
        foreach ($match in $matches) {
            $functionName = $match.Groups[1].Value
            
            # Get line number
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            
            # Try to extract synopsis
            $synopsisPattern = "(?s)\.SYNOPSIS\s+(.+?)(?:\.DESCRIPTION|\.PARAMETER|\.EXAMPLE|\.NOTES|#>|$)"
            $synopsisMatch = [regex]::Match($content, $synopsisPattern)
            $synopsis = if ($synopsisMatch.Success) { 
                $synopsisMatch.Groups[1].Value.Trim() 
            } else { 
                "" 
            }
            
            $functions += @{
                Name = $functionName
                File = $RelativePath
                Line = $lineNumber
                Synopsis = $synopsis
            }
        }
    } catch {
        Write-ScriptLog -Level Warning -Message "Failed to parse file: $RelativePath - $_"
    }
    
    return $functions
}

function Get-FunctionCalls {
    <#
    .SYNOPSIS
        Find all function calls in a file
    #>
    param(
        [string]$FilePath,
        [string[]]$KnownFunctions
    )
    
    $calls = @()
    
    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        
        foreach ($funcName in $KnownFunctions) {
            # Match function calls
            $pattern = "\b$funcName\b\s*(?:-|\()"
            if ($content -match $pattern) {
                $calls += $funcName
            }
        }
    } catch {
        # Silently skip files that can't be read
    }
    
    return $calls
}

function Build-CodeMap {
    <#
    .SYNOPSIS
        Build comprehensive code map with all relationships
    #>
    param([string]$ProjectPath)
    
    Write-ScriptLog -Message "Building comprehensive code map..."
    
    # Get all files
    $allFiles = Get-AllPowerShellFiles -Path $ProjectPath
    
    # Extract all functions
    Write-ScriptLog -Message "Extracting function definitions..."
    $allFunctions = @()
    $functionsByFile = @{}
    
    foreach ($module in $allFiles.Modules) {
        $functions = Get-FunctionDefinitions -FilePath $module.FullPath -RelativePath $module.Path
        $allFunctions += $functions
        $functionsByFile[$module.Path] = $functions
    }
    
    foreach ($script in $allFiles.Scripts) {
        $functions = Get-FunctionDefinitions -FilePath $script.FullPath -RelativePath $script.Path
        $allFunctions += $functions
        $functionsByFile[$script.Path] = $functions
    }
    
    Write-ScriptLog -Message "Found $($allFunctions.Count) function definitions"
    
    # Build usage map
    Write-ScriptLog -Message "Analyzing function usage across codebase..."
    $usageMap = @{}
    $knownFunctionNames = $allFunctions | ForEach-Object { $_.Name }
    
    # Analyze all files for function calls
    $allFilesToAnalyze = $allFiles.Scripts + $allFiles.Modules + $allFiles.Tests
    
    foreach ($file in $allFilesToAnalyze) {
        $calls = Get-FunctionCalls -FilePath $file.FullPath -KnownFunctions $knownFunctionNames
        
        if ($calls -and @($calls).Count -gt 0) {
            $usageMap[$file.Path] = $calls
        }
    }
    
    Write-ScriptLog -Message "Analyzed usage in $($allFilesToAnalyze.Count) files"
    
    # Build reverse index (function -> files that use it)
    $functionUsage = @{}
    foreach ($file in $usageMap.Keys) {
        foreach ($funcName in $usageMap[$file]) {
            if (-not $functionUsage.ContainsKey($funcName)) {
                $functionUsage[$funcName] = @()
            }
            $functionUsage[$funcName] += $file
        }
    }
    
    # Build domain structure
    Write-ScriptLog -Message "Organizing by domains..."
    $domains = @{}
    
    foreach ($module in $allFiles.Modules) {
        if ($module.Path -match '^domains/([^/]+)/') {
            $domainName = $matches[1]
            if (-not $domains.ContainsKey($domainName)) {
                $domains[$domainName] = @{
                    Modules = @()
                    Functions = @()
                }
            }
            $domains[$domainName].Modules += $module
            if ($functionsByFile.ContainsKey($module.Path)) {
                $domains[$domainName].Functions += $functionsByFile[$module.Path]
            }
        }
    }
    
    return @{
        Files = $allFiles
        Functions = $allFunctions
        FunctionsByFile = $functionsByFile
        UsageMap = $usageMap
        FunctionUsage = $functionUsage
        Domains = $domains
        Statistics = @{
            TotalFiles = ($allFiles.Scripts.Count + $allFiles.Modules.Count + $allFiles.Data.Count + $allFiles.Tests.Count)
            TotalFunctions = $allFunctions.Count
            TotalDomains = $domains.Count
            TotalUsageEdges = ($usageMap.Values | Measure-Object -Sum -Property Count).Sum
        }
    }
}

function New-CodeMapHTML {
    <#
    .SYNOPSIS
        Generate interactive HTML code map
    #>
    param(
        [hashtable]$CodeMap,
        [string]$OutputPath,
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Generating interactive code map HTML from templates..."
    
    # Load template files
    $templatePath = Join-Path $ProjectPath "templates/code-map"
    $htmlTemplate = Get-Content (Join-Path $templatePath "code-map.html") -Raw
    $cssContent = Get-Content (Join-Path $templatePath "code-map.css") -Raw
    $jsContent = Get-Content (Join-Path $templatePath "code-map.js") -Raw
    
    # Convert data to JSON for JavaScript
    $filesJson = $CodeMap.Files | ConvertTo-Json -Depth 10 -Compress
    $functionsJson = $CodeMap.Functions | ConvertTo-Json -Depth 10 -Compress
    $usageMapJson = $CodeMap.UsageMap | ConvertTo-Json -Depth 10 -Compress
    $functionUsageJson = $CodeMap.FunctionUsage | ConvertTo-Json -Depth 10 -Compress
    $domainsJson = $CodeMap.Domains | ConvertTo-Json -Depth 10 -Compress
    
    # Build data injection
    $dataScript = @"
const codeMapData = {
    files: $filesJson,
    functions: $functionsJson,
    usageMap: $usageMapJson,
    functionUsage: $functionUsageJson,
    domains: $domainsJson,
    stats: {
        totalFiles: $($CodeMap.Statistics.TotalFiles),
        totalFunctions: $($CodeMap.Statistics.TotalFunctions),
        totalDomains: $($CodeMap.Statistics.TotalDomains),
        totalUsageEdges: $($CodeMap.Statistics.TotalUsageEdges)
    }
};
"@
    
    # Replace placeholders in template
    $html = $htmlTemplate -replace '{{CSS}}', "<style>`n$cssContent`n</style>"
    $html = $html -replace '{{DATA}}', $dataScript
    $html = $html -replace '{{JAVASCRIPT}}', "<script>`n$jsContent`n</script>"
    
    $codeMapPath = Join-Path $OutputPath "code-map.html"
    if ($PSCmdlet.ShouldProcess($codeMapPath, "Create code map HTML")) {
        $html | Set-Content -Path $codeMapPath -Encoding UTF8
        Write-ScriptLog -Message "Code map created: $codeMapPath"
    }
    
    return $codeMapPath
}

try {
    Write-ScriptLog -Message "Starting comprehensive code map generation"
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Build code map
    $codeMap = Build-CodeMap -ProjectPath $ProjectPath
    
    # Generate HTML
    $codeMapPath = New-CodeMapHTML -CodeMap $codeMap -OutputPath $OutputPath -ProjectPath $ProjectPath
    
    # Summary
    Write-Host "`n🎉 Code Map Generation Complete!" -ForegroundColor Green
    Write-Host "📁 Output: $codeMapPath" -ForegroundColor Cyan
    Write-Host "`n📊 Code Map Statistics:" -ForegroundColor Cyan
    Write-Host "  Total Files: $($codeMap.Statistics.TotalFiles)" -ForegroundColor White
    Write-Host "  Total Functions: $($codeMap.Statistics.TotalFunctions)" -ForegroundColor White
    Write-Host "  Total Domains: $($codeMap.Statistics.TotalDomains)" -ForegroundColor White
    Write-Host "  Usage Relationships: $($codeMap.Statistics.TotalUsageEdges)" -ForegroundColor White
    
    # Open in browser if requested
    if ($Open) {
        if ($PSCmdlet.ShouldProcess($codeMapPath, "Open code map in browser")) {
            Write-Host "`n🌐 Opening code map in browser..." -ForegroundColor Cyan
            if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
                Start-Process $codeMapPath
            } elseif ($IsMacOS) {
                & open $codeMapPath
            } elseif ($IsLinux) {
                if (Get-Command xdg-open -ErrorAction SilentlyContinue) {
                    & xdg-open $codeMapPath
                }
            }
        }
    }
    
    Write-ScriptLog -Message "Code map generation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog -Level Error -Message "Code map generation failed: $_"
    exit 1
}
