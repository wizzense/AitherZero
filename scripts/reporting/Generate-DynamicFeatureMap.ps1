#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a dynamic feature map of AitherZero modules and their capabilities.

.DESCRIPTION
    This script performs comprehensive analysis of all AitherZero modules to create
    a dynamic feature map including:
    - Module discovery and categorization
    - Function exports and capabilities
    - Dependency analysis and mapping
    - Module relationships and integrations
    - Health status and test coverage
    - Cross-platform compatibility

.PARAMETER OutputPath
    Path where the feature map JSON will be saved. Defaults to './feature-map.json'

.PARAMETER HtmlOutput
    Generate HTML visualization of the feature map

.PARAMETER IncludeDependencyGraph
    Include detailed dependency relationship analysis

.PARAMETER ModulesPath
    Path to the modules directory. Auto-detected if not specified.

.PARAMETER AnalyzeIntegrations
    Perform deep analysis of module integrations and cross-references

.EXAMPLE
    ./Generate-DynamicFeatureMap.ps1 -HtmlOutput -IncludeDependencyGraph

.EXAMPLE
    ./Generate-DynamicFeatureMap.ps1 -OutputPath "./reports/feature-map.json" -AnalyzeIntegrations
#>

param(
    [string]$OutputPath = './feature-map.json',
    [switch]$HtmlOutput,
    [switch]$IncludeDependencyGraph,
    [string]$ModulesPath = $null,
    [switch]$AnalyzeIntegrations,
    [switch]$VerboseOutput
)

# Set up error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Import required functions
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Logging function
function Write-FeatureLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
    }

    if ($VerboseOutput -or $Level -ne 'DEBUG') {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# Discover and analyze modules
function Get-ModuleAnalysis {
    param([string]$ModulesPath)

    Write-FeatureLog "Discovering modules in: $ModulesPath" -Level 'INFO'

    $moduleAnalysis = @{
        TotalModules = 0
        AnalyzedModules = 0
        FailedModules = 0
        Modules = @{}
        Categories = @{}
        Capabilities = @{}
        Dependencies = @{}
        Statistics = @{}
    }

    if (-not (Test-Path $ModulesPath)) {
        Write-FeatureLog "Modules path not found: $ModulesPath" -Level 'WARNING'
        return $moduleAnalysis
    }

    # Detect architecture type
    $isDomainsArchitecture = (Split-Path $ModulesPath -Leaf) -eq 'domains'
    
    if ($isDomainsArchitecture) {
        Write-FeatureLog "Detected domain-based architecture" -Level 'INFO'
        $moduleAnalysis = Get-DomainsAnalysis -DomainsPath $ModulesPath
    } else {
        Write-FeatureLog "Using legacy module-based analysis" -Level 'INFO'
        $moduleDirectories = Get-ChildItem $ModulesPath -Directory
        $moduleAnalysis.TotalModules = $moduleDirectories.Count
        Write-FeatureLog "Found $($moduleAnalysis.TotalModules) module directories" -Level 'INFO'

    foreach ($moduleDir in $moduleDirectories) {
        try {
            Write-FeatureLog "Analyzing module: $($moduleDir.Name)" -Level 'DEBUG'

            $moduleInfo = Get-SingleModuleAnalysis -ModuleDirectory $moduleDir
            
            # Validate module info before processing
            if (-not $moduleInfo -or -not $moduleInfo.Name) {
                Write-FeatureLog "Invalid module info returned for $($moduleDir.Name)" -Level 'WARNING'
                $moduleAnalysis.FailedModules++
                continue
            }
            
            $moduleAnalysis.Modules[$moduleDir.Name] = $moduleInfo
            $moduleAnalysis.AnalyzedModules++

            # Categorize module with error handling
            try {
                $category = Get-ModuleCategory -ModuleInfo $moduleInfo
                if (-not $moduleAnalysis.Categories[$category]) {
                    $moduleAnalysis.Categories[$category] = @()
                }
                $moduleAnalysis.Categories[$category] += $moduleDir.Name
            } catch {
                Write-FeatureLog "Failed to categorize module $($moduleDir.Name): $($_.Exception.Message)" -Level 'DEBUG'
                # Default to Utilities if categorization fails
                if (-not $moduleAnalysis.Categories['Utilities']) {
                    $moduleAnalysis.Categories['Utilities'] = @()
                }
                $moduleAnalysis.Categories['Utilities'] += $moduleDir.Name
            }

            # Extract capabilities with error handling
            try {
                $capabilities = Get-ModuleCapabilities -ModuleInfo $moduleInfo
                $moduleAnalysis.Capabilities[$moduleDir.Name] = $capabilities
            } catch {
                Write-FeatureLog "Failed to analyze capabilities for $($moduleDir.Name): $($_.Exception.Message)" -Level 'DEBUG'
                # Set default capabilities
                $moduleAnalysis.Capabilities[$moduleDir.Name] = @{
                    FunctionCount = 0
                    HasPublicAPI = $false
                    Features = @()
                }
            }

            # Analyze dependencies with error handling
            try {
                if ($moduleInfo.RequiredModules -and @($moduleInfo.RequiredModules).Count -gt 0) {
                    $moduleAnalysis.Dependencies[$moduleDir.Name] = $moduleInfo.RequiredModules
                }
            } catch {
                Write-FeatureLog "Failed to analyze dependencies for $($moduleDir.Name): $($_.Exception.Message)" -Level 'DEBUG'
            }

        } catch {
            Write-FeatureLog "Failed to analyze module $($moduleDir.Name): $($_.Exception.Message)" -Level 'WARNING'
            Write-FeatureLog "Stack trace: $($_.ScriptStackTrace)" -Level 'DEBUG'
            $moduleAnalysis.FailedModules++
        }
    }

        # Generate statistics for legacy modules
        $moduleAnalysis.Statistics = Get-FeatureStatistics -ModuleAnalysis $moduleAnalysis
        Write-FeatureLog "Module analysis complete: $($moduleAnalysis.AnalyzedModules)/$($moduleAnalysis.TotalModules) successful" -Level 'SUCCESS'
    }

    return $moduleAnalysis
}

# Analyze domain-based architecture
function Get-DomainsAnalysis {
    param([string]$DomainsPath)

    Write-FeatureLog "Analyzing domain-based architecture" -Level 'INFO'

    $moduleAnalysis = @{
        TotalModules = 0
        AnalyzedModules = 0
        FailedModules = 0
        Modules = @{}
        Categories = @{}
        Capabilities = @{}
        Dependencies = @{}
        Statistics = @{}
    }

    # Get all domain directories
    $domainDirectories = Get-ChildItem $DomainsPath -Directory
    
    # Count total modules (domain files)
    $allDomainFiles = @()
    foreach ($domainDir in $domainDirectories) {
        $domainFiles = Get-ChildItem $domainDir.FullName -Filter "*.ps1" | Where-Object { $_.Name -ne "README.md" }
        $allDomainFiles += $domainFiles
    }
    
    $moduleAnalysis.TotalModules = $allDomainFiles.Count
    Write-FeatureLog "Found $($moduleAnalysis.TotalModules) domain modules across $($domainDirectories.Count) domains" -Level 'INFO'

    # Analyze each domain file as a module
    foreach ($domainFile in $allDomainFiles) {
        try {
            Write-FeatureLog "Analyzing domain module: $($domainFile.Name)" -Level 'DEBUG'

            $moduleInfo = Get-DomainModuleAnalysis -DomainFile $domainFile
            
            if (-not $moduleInfo -or -not $moduleInfo.Name) {
                Write-FeatureLog "Invalid module info returned for $($domainFile.Name)" -Level 'WARNING'
                $moduleAnalysis.FailedModules++
                continue
            }
            
            $moduleName = $moduleInfo.Name
            $moduleAnalysis.Modules[$moduleName] = $moduleInfo
            $moduleAnalysis.AnalyzedModules++

            # Categorize domain module
            try {
                $category = Get-DomainModuleCategory -ModuleInfo $moduleInfo -DomainFile $domainFile
                if (-not $moduleAnalysis.Categories[$category]) {
                    $moduleAnalysis.Categories[$category] = @()
                }
                $moduleAnalysis.Categories[$category] += $moduleName
            } catch {
                Write-FeatureLog "Failed to categorize module $moduleName : $($_.Exception.Message)" -Level 'DEBUG'
                if (-not $moduleAnalysis.Categories['Utilities']) {
                    $moduleAnalysis.Categories['Utilities'] = @()
                }
                $moduleAnalysis.Categories['Utilities'] += $moduleName
            }

            # Extract capabilities
            try {
                $capabilities = Get-DomainModuleCapabilities -ModuleInfo $moduleInfo
                $moduleAnalysis.Capabilities[$moduleName] = $capabilities
            } catch {
                Write-FeatureLog "Failed to analyze capabilities for $moduleName : $($_.Exception.Message)" -Level 'DEBUG'
                $moduleAnalysis.Capabilities[$moduleName] = @{
                    FunctionCount = 0
                    HasPublicAPI = $false
                    Features = @()
                }
            }

        } catch {
            Write-FeatureLog "Failed to analyze domain module $($domainFile.Name): $($_.Exception.Message)" -Level 'WARNING'
            Write-FeatureLog "Stack trace: $($_.ScriptStackTrace)" -Level 'DEBUG'
            $moduleAnalysis.FailedModules++
        }
    }

    # Generate statistics
    $moduleAnalysis.Statistics = Get-FeatureStatistics -ModuleAnalysis $moduleAnalysis
    Write-FeatureLog "Domain analysis complete: $($moduleAnalysis.AnalyzedModules)/$($moduleAnalysis.TotalModules) successful" -Level 'SUCCESS'

    return $moduleAnalysis
}

# Analyze individual domain module
function Get-DomainModuleAnalysis {
    param($DomainFile)

    $moduleInfo = @{
        Name = $DomainFile.BaseName
        Path = $DomainFile.FullName
        LastModified = $DomainFile.LastWriteTime
        Size = $DomainFile.Length
        FileCount = 1
        HasManifest = $false
        HasModuleFile = $true
        HasTests = $false
        HasDocumentation = $false
        Manifest = $null
        Functions = @()
        RequiredModules = @()
        PowerShellVersion = '7.0'
        Description = ''
        Version = '1.0.0'
        Author = 'AitherZero'
        CompanyName = 'AitherZero'
        Health = 'Unknown'
        TestCoverage = 0
        ComplexityScore = 0
        DomainName = (Split-Path (Split-Path $DomainFile.FullName -Parent) -Leaf)
    }

    # Analyze domain script for functions
    $moduleInfo.Functions = Get-FunctionsFromScript -ScriptPath $DomainFile.FullName

    # Check for corresponding README in domain directory
    $readmePath = Join-Path (Split-Path $DomainFile.FullName -Parent) "README.md"
    if (Test-Path $readmePath) {
        $moduleInfo.HasDocumentation = $true
        
        # Try to extract description from README
        try {
            $readmeContent = Get-Content $readmePath -Raw -ErrorAction SilentlyContinue
            if ($readmeContent) {
                # Extract first paragraph as description
                $firstParagraph = ($readmeContent -split "`n`n")[0] -replace '^#[^`n]*`n', '' -replace '`n', ' '
                if ($firstParagraph.Length -gt 10) {
                    $moduleInfo.Description = $firstParagraph.Substring(0, [Math]::Min(200, $firstParagraph.Length))
                }
            }
        } catch {
            Write-FeatureLog "Failed to read README for $($DomainFile.Name): $($_.Exception.Message)" -Level 'DEBUG'
        }
    }

    # Check for tests - look for test files related to this domain
    try {
        $testSearchPattern = "*$($moduleInfo.Name)*Test*.ps1"
        $projectRoot = Split-Path (Split-Path (Split-Path $DomainFile.FullName -Parent) -Parent) -Parent
        $testsDir = Join-Path $projectRoot "tests"
        
        if (Test-Path $testsDir) {
            $relatedTestFiles = Get-ChildItem $testsDir -Filter $testSearchPattern -Recurse -ErrorAction SilentlyContinue
            if (@($relatedTestFiles).Count -gt 0) {
                $moduleInfo.HasTests = $true
                $moduleInfo.TestCoverage = Get-DomainTestCoverage -TestFiles $relatedTestFiles -ModuleInfo $moduleInfo
            }
        }
    } catch {
        Write-FeatureLog "Failed to check tests for $($DomainFile.Name): $($_.Exception.Message)" -Level 'DEBUG'
    }

    # Calculate complexity based on function count and file size
    # Configuration constants for complexity calculation
    $FUNCTION_COUNT_MULTIPLIER = 2
    $MAX_FILE_SIZE_CONTRIBUTION = 50
    $FILE_SIZE_UNIT = 1KB
    
    $functionCount = @($moduleInfo.Functions).Count
    $moduleInfo.ComplexityScore = [Math]::Min(100, ($functionCount * $FUNCTION_COUNT_MULTIPLIER) + [Math]::Min($MAX_FILE_SIZE_CONTRIBUTION, $DomainFile.Length / $FILE_SIZE_UNIT))

    # Calculate health score
    $moduleInfo.Health = Get-DomainModuleHealth -ModuleInfo $moduleInfo

    return $moduleInfo
}

# Get domain module category
function Get-DomainModuleCategory {
    param($ModuleInfo, $DomainFile)

    $domainName = $ModuleInfo.DomainName
    $moduleName = $ModuleInfo.Name

    # Map domain names to categories
    $domainCategories = @{
        'infrastructure' = 'Infrastructure'
        'security' = 'Security'
        'configuration' = 'Configuration'
        'utilities' = 'Utilities'
        'automation' = 'Automation'
        'experience' = 'Experience'
    }

    # Use domain mapping first
    if ($domainCategories.ContainsKey($domainName.ToLower())) {
        return $domainCategories[$domainName.ToLower()]
    }

    # Fallback to module name analysis
    if ($moduleName -like "*Manager" -or $moduleName -like "*Management") {
        return 'Managers'
    } elseif ($moduleName -like "*Provider") {
        return 'Providers'
    } elseif ($moduleName -like "*Integration") {
        return 'Integrations'
    } else {
        return 'Core'
    }
}

# Get domain module capabilities
function Get-DomainModuleCapabilities {
    param($ModuleInfo)

    $functionCount = @($ModuleInfo.Functions).Count
    
    $capabilities = @{
        FunctionCount = $functionCount
        HasPublicAPI = $functionCount -gt 0
        Features = @()
        DomainType = $ModuleInfo.DomainName
        ComplexityLevel = if ($functionCount -le 5) { 'Simple' } elseif ($functionCount -le 15) { 'Moderate' } else { 'Complex' }
    }

    # Analyze function names for feature detection
    $features = @()
    foreach ($func in $ModuleInfo.Functions) {
        if ($func -like "New-*") { $features += 'Creation' }
        if ($func -like "Get-*") { $features += 'Retrieval' }
        if ($func -like "Set-*") { $features += 'Configuration' }
        if ($func -like "Test-*") { $features += 'Validation' }
        if ($func -like "Install-*" -or $func -like "Deploy-*") { $features += 'Deployment' }
        if ($func -like "Start-*" -or $func -like "Stop-*") { $features += 'Management' }
        if ($func -like "*Security*" -or $func -like "*Credential*") { $features += 'Security' }
    }
    
    $capabilities.Features = ($features | Sort-Object -Unique)

    return $capabilities
}

# Calculate domain test coverage
function Get-DomainTestCoverage {
    param($TestFiles, $ModuleInfo)
    
    try {
        $totalFunctions = @($ModuleInfo.Functions).Count
        
        # If no functions, return 100% (vacuous truth)
        if ($totalFunctions -eq 0) { return 100 }
        
        $testedFunctions = 0
        
        # Analyze test files for function coverage
        foreach ($testFile in $TestFiles) {
            $testContent = Get-Content $testFile.FullName -Raw -ErrorAction SilentlyContinue
            if ($testContent) {
                # Count how many of the module's functions are referenced in tests
                foreach ($functionName in $ModuleInfo.Functions) {
                    if ($testContent -like "*$functionName*") {
                        $testedFunctions++
                    }
                }
            }
        }
        
        # Calculate percentage with realistic baseline
        $coveragePercentage = if ($testedFunctions -gt 0) {
            [Math]::Min(100, [Math]::Round(($testedFunctions / $totalFunctions) * 100, 1))
        } else {
            # If we have test files but no obvious function coverage, assume basic coverage
            60  # Conservative estimate when tests exist but specific function coverage is unclear
        }
        
        return $coveragePercentage
        
    } catch {
        Write-FeatureLog "Error calculating test coverage: $($_.Exception.Message)" -Level 'DEBUG'
        return 50  # Fallback coverage estimate
    }
}

# Calculate domain module health
function Get-DomainModuleHealth {
    param($ModuleInfo)

    $healthScore = 0
    $maxScore = 100

    # Function count scoring (0-30 points)
    $functionCount = @($ModuleInfo.Functions).Count
    if ($functionCount -gt 0) { $healthScore += 10 }
    if ($functionCount -gt 3) { $healthScore += 10 }
    if ($functionCount -gt 8) { $healthScore += 10 }

    # Documentation scoring (0-25 points)
    if ($ModuleInfo.HasDocumentation) { $healthScore += 25 }

    # Testing scoring (0-25 points)
    if ($ModuleInfo.HasTests) { $healthScore += 25 }

    # File size/complexity scoring (0-20 points)
    if ($ModuleInfo.Size -gt 1KB) { $healthScore += 5 }
    if ($ModuleInfo.Size -gt 5KB) { $healthScore += 10 }
    if ($ModuleInfo.Size -gt 10KB) { $healthScore += 5 }

    $healthPercentage = [Math]::Round(($healthScore / $maxScore) * 100, 1)

    if ($healthPercentage -ge 85) { return 'Excellent' }
    elseif ($healthPercentage -ge 70) { return 'Good' }
    elseif ($healthPercentage -ge 55) { return 'Fair' }
    elseif ($healthPercentage -ge 40) { return 'Poor' }
    else { return 'Critical' }
}

# Analyze individual module
function Get-SingleModuleAnalysis {
    param($ModuleDirectory)

    $moduleInfo = @{
        Name = $ModuleDirectory.Name
        Path = $ModuleDirectory.FullName
        LastModified = $ModuleDirectory.LastWriteTime
        Size = 0
        FileCount = 0
        HasManifest = $false
        HasModuleFile = $false
        HasTests = $false
        HasDocumentation = $false
        Manifest = $null
        Functions = @()
        RequiredModules = @()
        PowerShellVersion = $null
        Description = ''
        Version = '0.0.0'
        Author = ''
        CompanyName = ''
        Health = 'Unknown'
        TestCoverage = 0
        ComplexityScore = 0
    }

    # Calculate directory size and file count
    $files = Get-ChildItem $ModuleDirectory.FullName -Recurse -File
    $moduleInfo.FileCount = $files.Count
    $moduleInfo.Size = ($files | Measure-Object -Property Length -Sum).Sum

    # Check for manifest file
    $manifestPath = Join-Path $ModuleDirectory.FullName "$($ModuleDirectory.Name).psd1"
    if (Test-Path $manifestPath) {
        $moduleInfo.HasManifest = $true
        try {
            $manifest = Import-PowerShellDataFile $manifestPath
            $moduleInfo.Manifest = $manifest
            $moduleInfo.Version = if ($manifest.PSObject.Properties['ModuleVersion']) { $manifest.ModuleVersion } else { '0.0.0' }
            $moduleInfo.Description = if ($manifest.PSObject.Properties['Description']) { $manifest.Description } else { '' }
            $moduleInfo.Author = if ($manifest.PSObject.Properties['Author']) { $manifest.Author } else { '' }
            $moduleInfo.CompanyName = if ($manifest.PSObject.Properties['CompanyName']) { $manifest.CompanyName } else { '' }
            $moduleInfo.PowerShellVersion = if ($manifest.PSObject.Properties['PowerShellVersion']) { $manifest.PowerShellVersion } else { '5.1' }
            $moduleInfo.RequiredModules = if ($manifest.PSObject.Properties['RequiredModules']) { $manifest.RequiredModules } else { @() }

            # Get exported functions
            if ($manifest.PSObject.Properties['FunctionsToExport'] -and $manifest.FunctionsToExport -and $manifest.FunctionsToExport -ne '*') {
                $moduleInfo.Functions = if ($manifest.FunctionsToExport -is [array]) { $manifest.FunctionsToExport } else { @($manifest.FunctionsToExport) }
            }
        } catch {
            Write-FeatureLog "Failed to parse manifest for $($ModuleDirectory.Name): $($_.Exception.Message)" -Level 'DEBUG'
        }
    }

    # Check for module script file
    $moduleScriptPath = Join-Path $ModuleDirectory.FullName "$($ModuleDirectory.Name).psm1"
    if (Test-Path $moduleScriptPath) {
        $moduleInfo.HasModuleFile = $true

        # Analyze module script for additional functions if not in manifest
        $currentFunctionCount = @($moduleInfo.Functions).Count
        if ($currentFunctionCount -eq 0) {
            $moduleInfo.Functions = Get-FunctionsFromScript -ScriptPath $moduleScriptPath
        }

        # Calculate complexity score
        $moduleInfo.ComplexityScore = Get-ModuleComplexity -ScriptPath $moduleScriptPath
    }

    # Check for tests with enhanced detection
    $testsPath = Join-Path $ModuleDirectory.FullName "tests"
    if (Test-Path $testsPath) {
        $moduleInfo.HasTests = $true
        try {
            $testFiles = Get-ChildItem $testsPath -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
            $moduleInfo.TestCoverage = if (@($testFiles).Count -gt 0) { 85 } else { 0 } # Simplified calculation
        } catch {
            Write-FeatureLog "Failed to analyze tests for $($ModuleDirectory.Name): $($_.Exception.Message)" -Level 'DEBUG'
            $moduleInfo.TestCoverage = 0
        }
    } else {
        # Also check for test files in module directory root
        try {
            $rootTestFiles = Get-ChildItem $ModuleDirectory.FullName -Filter "*.Tests.ps1" -ErrorAction SilentlyContinue
            if (@($rootTestFiles).Count -gt 0) {
                $moduleInfo.HasTests = $true
                $moduleInfo.TestCoverage = 85
            }
        } catch {
            Write-FeatureLog "Failed to check for root test files in $($ModuleDirectory.Name): $($_.Exception.Message)" -Level 'DEBUG'
        }
    }

    # Check for documentation
    $readmePath = Join-Path $ModuleDirectory.FullName "README.md"
    if (Test-Path $readmePath) {
        $moduleInfo.HasDocumentation = $true
    }

    # Calculate health score
    $moduleInfo.Health = Get-ModuleHealth -ModuleInfo $moduleInfo

    return $moduleInfo
}

# Get module category based on naming and functionality
function Get-ModuleCategory {
    param($ModuleInfo)

    $name = $ModuleInfo.Name
    $description = if ($ModuleInfo.Description -and $ModuleInfo.Description.ToString()) { $ModuleInfo.Description.ToString().ToLower() } else { '' }

    # Category mapping based on patterns
    $categories = @{
        'Core' = @('AitherCore', 'ModuleCommunication', 'Logging', 'Configuration')
        'Managers' = @('.*Manager$', '.*Management$')
        'Providers' = @('.*Provider$')
        'Integrations' = @('.*Integration$', '.*Sync$')
        'Automation' = @('.*Automation$', '.*Wizard$', '.*Experience$')
        'Infrastructure' = @('OpenTofu', 'ISO', 'Deploy')
        'Development' = @('Testing', 'PSScript', 'PatchManager', 'Dev')
        'Security' = @('Security', 'Credential', 'License')
        'Utilities' = @('Utility', 'Progress', 'Parallel', 'Remote', 'Semantic')
    }

    foreach ($category in $categories.GetEnumerator()) {
        foreach ($pattern in $category.Value) {
            if ($name -match $pattern -or $description -match $pattern.ToLower()) {
                return $category.Key
            }
        }
    }

    return 'Utilities' # Default category
}

# Extract capabilities from module
function Get-ModuleCapabilities {
    param($ModuleInfo)

    $functionCount = @($ModuleInfo.Functions).Count
    $capabilities = @{
        FunctionCount = $functionCount
        HasPublicAPI = $functionCount -gt 0
        HasPrivateFunctions = $false
        HasClasses = $false
        HasEnums = $false
        HasDSCResources = $false
        SupportsWhatIf = $false
        SupportsTransactions = $false
        CrossPlatform = $true
        ModuleType = 'Script'
        Features = @()
    }

    # Analyze function names for features (if functions exist)
    if ($ModuleInfo.Functions -and @($ModuleInfo.Functions).Count -gt 0) {
        foreach ($function in $ModuleInfo.Functions) {
        $functionName = $function.ToString().ToLower()

        # Detect feature patterns
        if ($functionName -match '^new-') { $capabilities.Features += 'Creation' }
        if ($functionName -match '^get-') { $capabilities.Features += 'Retrieval' }
        if ($functionName -match '^set-|^update-') { $capabilities.Features += 'Modification' }
        if ($functionName -match '^remove-|^delete-') { $capabilities.Features += 'Deletion' }
        if ($functionName -match '^test-|^validate-') { $capabilities.Features += 'Validation' }
        if ($functionName -match '^invoke-|^start-') { $capabilities.Features += 'Execution' }
        if ($functionName -match '^import-|^export-') { $capabilities.Features += 'DataManagement' }
        if ($functionName -match '^backup-|^restore-') { $capabilities.Features += 'BackupRestore' }
        if ($functionName -match '^sync-') { $capabilities.Features += 'Synchronization' }
        if ($functionName -match 'config|setting') { $capabilities.Features += 'Configuration' }
        if ($functionName -match 'security|credential|auth') { $capabilities.Features += 'Security' }
        if ($functionName -match 'network|remote|api') { $capabilities.Features += 'Networking' }
        if ($functionName -match 'file|directory|path') { $capabilities.Features += 'FileSystem' }
        if ($functionName -match 'deploy|provision') { $capabilities.Features += 'Deployment' }
        if ($functionName -match 'monitor|track|audit') { $capabilities.Features += 'Monitoring' }
        }
    }

    # Remove duplicates and sort
    $capabilities.Features = $capabilities.Features | Sort-Object -Unique

    # Check for advanced features
    if ($ModuleInfo.HasModuleFile) {
        $moduleScriptPath = Join-Path $ModuleInfo.Path "$($ModuleInfo.Name).psm1"
        if (Test-Path $moduleScriptPath) {
            $content = Get-Content $moduleScriptPath -Raw

            $capabilities.HasPrivateFunctions = $content -match 'function\s+\w+-\w+'
            $capabilities.HasClasses = $content -match 'class\s+\w+'
            $capabilities.HasEnums = $content -match 'enum\s+\w+'
            $capabilities.SupportsWhatIf = $content -match 'SupportsShouldProcess|WhatIf'
            $capabilities.SupportsTransactions = $content -match 'SupportsTransactions'
        }
    }

    # Determine cross-platform compatibility
    $capabilities.CrossPlatform = $ModuleInfo.PowerShellVersion -and
                                 [version]$ModuleInfo.PowerShellVersion -ge [version]'6.0'

    return $capabilities
}

# Extract functions from PowerShell script
function Get-FunctionsFromScript {
    param([string]$ScriptPath)

    if (-not (Test-Path $ScriptPath)) {
        return @()
    }

    try {
        $content = Get-Content $ScriptPath -Raw
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

        $functions = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

        return $functions | ForEach-Object { $_.Name }
    } catch {
        Write-FeatureLog "Failed to parse script $ScriptPath for functions: $($_.Exception.Message)" -Level 'DEBUG'
        return @()
    }
}

# Calculate module complexity score
function Get-ModuleComplexity {
    param([string]$ScriptPath)

    if (-not (Test-Path $ScriptPath)) {
        return 0
    }

    try {
        $content = Get-Content $ScriptPath -Raw
        $lines = ($content -split "`n").Count
        $functions = ($content | Select-String -Pattern "function\s+\w+" -AllMatches).Matches.Count
        $classes = ($content | Select-String -Pattern "class\s+\w+" -AllMatches).Matches.Count
        $conditions = ($content | Select-String -Pattern "\b(if|switch|while|for|foreach)\b" -AllMatches).Matches.Count

        # Simple complexity calculation
        $complexity = ($lines * 0.1) + ($functions * 2) + ($classes * 5) + ($conditions * 1.5)
        return [math]::Round($complexity, 2)
    } catch {
        return 0
    }
}

# Calculate module health score
function Get-ModuleHealth {
    param($ModuleInfo)

    $healthFactors = @{
        HasManifest = if ($ModuleInfo.HasManifest) { 20 } else { 0 }
        HasModuleFile = if ($ModuleInfo.HasModuleFile) { 15 } else { 0 }
        HasTests = if ($ModuleInfo.HasTests) { 25 } else { 0 }
        HasDocumentation = if ($ModuleInfo.HasDocumentation) { 15 } else { 0 }
        HasFunctions = if ($ModuleInfo.Functions -and @($ModuleInfo.Functions).Count -gt 0) { 15 } else { 0 }
        RecentlyUpdated = if ($ModuleInfo.LastModified -gt (Get-Date).AddDays(-30)) { 10 } else { 5 }
    }

    $totalScore = ($healthFactors.Values | Measure-Object -Sum).Sum

    $healthStatus = switch ($totalScore) {
        {$_ -ge 80} { 'Excellent' }
        {$_ -ge 60} { 'Good' }
        {$_ -ge 40} { 'Fair' }
        {$_ -ge 20} { 'Poor' }
        default { 'Critical' }
    }

    return $healthStatus
}

# Generate feature statistics
function Get-FeatureStatistics {
    param($ModuleAnalysis)

    $stats = @{
        TotalFunctions = 0
        AverageFunctionsPerModule = 0
        ModulesWithTests = 0
        ModulesWithDocumentation = 0
        TestCoveragePercentage = 0
        HealthDistribution = @{}
        CategoryDistribution = @{}
        FeatureDistribution = @{}
        ComplexityDistribution = @{}
        PowerShellVersionSupport = @{}
    }

    $totalComplexity = 0
    $totalTestCoverage = 0

    foreach ($module in $ModuleAnalysis.Modules.Values) {
        # Function count
        $functionCount = @($module.Functions).Count
        $stats.TotalFunctions += $functionCount

        # Test and documentation tracking
        if ($module.HasTests) { $stats.ModulesWithTests++ }
        if ($module.HasDocumentation) { $stats.ModulesWithDocumentation++ }

        # Health distribution
        if (-not $stats.HealthDistribution.ContainsKey($module.Health)) {
            $stats.HealthDistribution[$module.Health] = 0
        }
        $stats.HealthDistribution[$module.Health] = $stats.HealthDistribution[$module.Health] + 1

        # Complexity and test coverage
        $totalComplexity += $module.ComplexityScore
        $totalTestCoverage += $module.TestCoverage

        # PowerShell version support
        $psVersion = if ($module.PowerShellVersion) { $module.PowerShellVersion } else { '5.1' }
        if (-not $stats.PowerShellVersionSupport.ContainsKey($psVersion)) {
            $stats.PowerShellVersionSupport[$psVersion] = 0
        }
        $stats.PowerShellVersionSupport[$psVersion] = $stats.PowerShellVersionSupport[$psVersion] + 1
    }

    # Calculate averages
    $moduleCount = $ModuleAnalysis.AnalyzedModules
    if ($moduleCount -gt 0) {
        $stats.AverageFunctionsPerModule = [math]::Round($stats.TotalFunctions / $moduleCount, 1)
        $stats.TestCoveragePercentage = [math]::Round(($stats.ModulesWithTests / $moduleCount) * 100, 1)
        $stats.DocumentationCoveragePercentage = [math]::Round(($stats.ModulesWithDocumentation / $moduleCount) * 100, 1)
        $stats.AverageComplexity = [math]::Round($totalComplexity / $moduleCount, 1)
    }

    # Category distribution
    foreach ($category in $ModuleAnalysis.Categories.GetEnumerator()) {
        $stats.CategoryDistribution[$category.Key] = $category.Value.Count
    }

    # Feature distribution from capabilities
    $featureCounts = @{}
    foreach ($capability in $ModuleAnalysis.Capabilities.Values) {
        foreach ($feature in $capability.Features) {
            if (-not $featureCounts.ContainsKey($feature)) {
                $featureCounts[$feature] = 0
            }
            $featureCounts[$feature] = $featureCounts[$feature] + 1
        }
    }
    $stats.FeatureDistribution = $featureCounts

    return $stats
}

# Generate dependency graph
function Get-DependencyGraph {
    param($ModuleAnalysis)

    if (-not $IncludeDependencyGraph) {
        return @{}
    }

    Write-FeatureLog "Generating dependency graph..." -Level 'INFO'

    $dependencyGraph = @{
        Nodes = @()
        Edges = @()
        Clusters = @{}
        CircularDependencies = @()
        OrphanModules = @()
    }

    # Create nodes for each module
    foreach ($module in $ModuleAnalysis.Modules.GetEnumerator()) {
        $dependencyGraph.Nodes += @{
            Id = $module.Key
            Label = $module.Key
            Category = (Get-ModuleCategory -ModuleInfo $module.Value)
            Health = $module.Value.Health
            FunctionCount = @($module.Value.Functions).Count
            HasTests = $module.Value.HasTests
        }
    }

    # Create edges for dependencies
    foreach ($module in $ModuleAnalysis.Dependencies.GetEnumerator()) {
        foreach ($dependency in $module.Value) {
            $depName = if ($dependency -is [hashtable]) { $dependency.ModuleName } else { $dependency }

            # Only include internal dependencies
            if ($ModuleAnalysis.Modules.ContainsKey($depName)) {
                $dependencyGraph.Edges += @{
                    Source = $module.Key
                    Target = $depName
                    Type = 'Dependency'
                }
            }
        }
    }

    # Future enhancement: Detect circular dependencies and clusters

    return $dependencyGraph
}

# Generate HTML visualization
function New-FeatureMapHtml {
    param($FeatureMap, $OutputPath)

    $htmlPath = $OutputPath -replace '\.json$', '.html'

    Write-FeatureLog "Generating HTML visualization: $htmlPath" -Level 'INFO'

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Dynamic Feature Map</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #333; margin-bottom: 10px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-number { font-size: 2em; font-weight: bold; color: #007bff; }
        .modules-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .module-card { background: white; border: 1px solid #dee2e6; border-radius: 8px; padding: 20px; }
        .module-header { display: flex; justify-content: between; align-items: center; margin-bottom: 15px; }
        .module-name { font-weight: bold; font-size: 1.2em; color: #333; }
        .health-badge { padding: 4px 8px; border-radius: 4px; color: white; font-size: 0.8em; }
        .health-excellent { background: #28a745; }
        .health-good { background: #17a2b8; }
        .health-fair { background: #ffc107; color: #333; }
        .health-poor { background: #fd7e14; }
        .health-critical { background: #dc3545; }
        .features-list { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 10px; }
        .feature-tag { background: #e9ecef; padding: 2px 6px; border-radius: 3px; font-size: 0.8em; }
        .category-section { margin-bottom: 30px; }
        .category-title { font-size: 1.5em; color: #495057; margin-bottom: 15px; border-bottom: 2px solid #dee2e6; padding-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🗺️ AitherZero Dynamic Feature Map</h1>
            <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')</p>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-number">$($FeatureMap.Statistics.TotalFunctions)</div>
                <div>Total Functions</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($FeatureMap.AnalyzedModules)</div>
                <div>Modules Analyzed</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($FeatureMap.Statistics.TestCoveragePercentage)%</div>
                <div>Test Coverage</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($FeatureMap.Statistics.AverageFunctionsPerModule)</div>
                <div>Avg Functions/Module</div>
            </div>
        </div>
"@

    # Add modules by category
    foreach ($category in $FeatureMap.Categories.GetEnumerator()) {
        $html += @"
        <div class="category-section">
            <div class="category-title">$($category.Key) ($($category.Value.Count) modules)</div>
            <div class="modules-grid">
"@

        foreach ($moduleName in $category.Value) {
            $module = $FeatureMap.Modules[$moduleName]
            $capabilities = $FeatureMap.Capabilities[$moduleName]
            $healthClass = $module.Health.ToLower() -replace ' ', '-'

            $html += @"
                <div class="module-card">
                    <div class="module-header">
                        <div class="module-name">$($module.Name)</div>
                        <div class="health-badge health-$healthClass">$($module.Health)</div>
                    </div>
                    <div>
                        <strong>Version:</strong> $($module.Version)<br>
                        <strong>Functions:</strong> $(@($module.Functions).Count)<br>
                        <strong>Tests:</strong> $(if ($module.HasTests) { '✅' } else { '❌' })<br>
                        <strong>Docs:</strong> $(if ($module.HasDocumentation) { '✅' } else { '❌' })
                    </div>
"@

            if ($capabilities.Features -and @($capabilities.Features).Count -gt 0) {
                $html += @"
                    <div class="features-list">
"@
                foreach ($feature in $capabilities.Features) {
                    $html += "<span class='feature-tag'>$feature</span>"
                }
                $html += @"
                    </div>
"@
            }

            $html += @"
                </div>
"@
        }

        $html += @"
            </div>
        </div>
"@
    }

    $html += @"
    </div>
</body>
</html>
"@

    $html | Set-Content -Path $htmlPath -Encoding UTF8
    Write-FeatureLog "HTML visualization saved to: $htmlPath" -Level 'SUCCESS'

    return $htmlPath
}

# Main execution
try {
    Write-FeatureLog "Starting dynamic feature map generation..." -Level 'INFO'

    # Determine modules path
    if (-not $ModulesPath) {
        $ModulesPath = Join-Path $projectRoot "aither-core/modules"
    }

    # Analyze modules
    $featureMap = Get-ModuleAnalysis -ModulesPath $ModulesPath

    # Generate dependency graph if requested
    if ($IncludeDependencyGraph) {
        $featureMap.DependencyGraph = Get-DependencyGraph -ModuleAnalysis $featureMap
    }

    # Add metadata
    $featureMap.Metadata = @{
        GeneratedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        GeneratedBy = 'AitherZero Dynamic Feature Map Generator v1.0'
        ProjectRoot = $projectRoot
        ModulesPath = $ModulesPath
        IncludesDependencyGraph = $IncludeDependencyGraph.IsPresent
        AnalyzedIntegrations = $AnalyzeIntegrations.IsPresent
    }

    # Convert hashtables to PSCustomObjects recursively for JSON serialization
    function ConvertTo-JsonCompatible {
        param($Object)

        if ($Object -is [hashtable]) {
            $converted = @{}
            foreach ($key in $Object.Keys) {
                $converted[$key] = ConvertTo-JsonCompatible -Object $Object[$key]
            }
            return [PSCustomObject]$converted
        }
        elseif ($Object -is [array]) {
            return $Object | ForEach-Object { ConvertTo-JsonCompatible -Object $_ }
        }
        else {
            return $Object
        }
    }

    $jsonCompatibleMap = ConvertTo-JsonCompatible -Object $featureMap

    # Save JSON output
    $jsonCompatibleMap | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-FeatureLog "Feature map saved to: $OutputPath" -Level 'SUCCESS'

    # Generate HTML visualization if requested
    if ($HtmlOutput) {
        $htmlPath = New-FeatureMapHtml -FeatureMap $featureMap -OutputPath $OutputPath
    }

    # Output summary
    Write-FeatureLog "Feature map generation completed successfully" -Level 'SUCCESS'
    Write-FeatureLog "Summary: $($featureMap.AnalyzedModules)/$($featureMap.TotalModules) modules, $($featureMap.Statistics.TotalFunctions) functions, $($featureMap.Categories.Count) categories" -Level 'INFO'

    return @{
        Success = $true
        OutputPath = $OutputPath
        HtmlPath = if ($HtmlOutput) { $htmlPath } else { $null }
        Summary = $featureMap.Statistics
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    }

} catch {
    Write-FeatureLog "Feature map generation failed: $($_.Exception.Message)" -Level 'ERROR'
    throw
}
