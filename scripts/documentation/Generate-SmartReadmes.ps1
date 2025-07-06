# Generate-SmartReadmes.ps1 - Smart README Generation with Templates
# Part of AitherZero Smart Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/documentation-state.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),
    
    [Parameter(Mandatory = $false)]
    [string[]]$TargetDirectories = @(),
    
    [Parameter(Mandatory = $false)]
    [int]$MaxGenerations = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$OverwriteExisting,
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateDirectory = "./scripts/documentation/templates"
)

# Find project root if not specified
if (-not (Test-Path $ProjectRoot)) {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
}

# Import required modules
if (Test-Path "$ProjectRoot/aither-core/modules/Logging") {
    Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARN"){"Yellow"} else{"Green"})
    }
}

function Get-AutoGenerationCandidates {
    <#
    .SYNOPSIS
    Identifies directories that are good candidates for automatic README generation
    
    .DESCRIPTION
    Analyzes the documentation state to find directories that can be safely
    auto-generated without requiring complex human review
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,
        
        [Parameter(Mandatory = $false)]
        [string[]]$TargetDirectories = @(),
        
        [Parameter(Mandatory = $false)]
        [int]$MaxCandidates = 10
    )
    
    $candidates = @()
    $config = $State.configuration
    
    $directoriesToCheck = if ($TargetDirectories.Count -gt 0) {
        $TargetDirectories | Where-Object { $State.directories.ContainsKey($_) }
    } else {
        $State.directories.Keys
    }
    
    Write-Log "Evaluating $($directoriesToCheck.Count) directories for auto-generation..." -Level "INFO"
    
    foreach ($dirPath in $directoriesToCheck) {
        $dirState = $State.directories[$dirPath]
        $isCandidate = $false
        $confidence = 0
        $reasons = @()
        $priority = "low"
        
        # Skip if README already exists (unless overwrite is requested)
        if ($dirState.readmeExists -and -not $OverwriteExisting) {
            continue
        }
        
        # Missing README is a clear candidate
        if (-not $dirState.readmeExists) {
            $isCandidate = $true
            $confidence += 40
            $reasons += "Missing README file"
            $priority = "medium"
        }
        
        # Directories with content but no documentation are good candidates
        if ($dirState.fileCount -gt 0 -and -not $dirState.readmeExists) {
            $confidence += 30
            $reasons += "Directory has $($dirState.fileCount) files but no documentation"
        }
        
        # Well-defined directory types are easier to generate
        $directoryTypeConfidence = switch ($dirState.directoryType) {
            "powershell-module" { 50 }
            "infrastructure" { 40 }
            "configuration" { 35 }
            "scripts" { 30 }
            "tests" { 25 }
            "build" { 25 }
            default { 10 }
        }
        $confidence += $directoryTypeConfidence
        
        # Structured directories (with Public/Private folders) are great candidates
        $fullPath = Join-Path $ProjectRoot $dirPath.TrimStart('/')
        if (Test-Path (Join-Path $fullPath "Public") -or Test-Path (Join-Path $fullPath "Private")) {
            $confidence += 25
            $reasons += "Structured module directory detected"
            $priority = "high"
        }
        
        # Directories with manifest files are excellent candidates
        $manifestFiles = Get-ChildItem -Path $fullPath -Filter "*.psd1" -ErrorAction SilentlyContinue
        if ($manifestFiles.Count -gt 0) {
            $confidence += 30
            $reasons += "PowerShell module manifest found"
            $priority = "high"
        }
        
        # Infrastructure directories with .tf files
        $terraformFiles = Get-ChildItem -Path $fullPath -Filter "*.tf" -ErrorAction SilentlyContinue
        if ($terraformFiles.Count -gt 0) {
            $confidence += 25
            $reasons += "Terraform/OpenTofu configuration detected"
        }
        
        # Configuration directories with structured config files
        $configFiles = Get-ChildItem -Path $fullPath -Filter "*.json" -ErrorAction SilentlyContinue
        $configFiles += Get-ChildItem -Path $fullPath -Filter "*.yaml" -ErrorAction SilentlyContinue
        $configFiles += Get-ChildItem -Path $fullPath -Filter "*.yml" -ErrorAction SilentlyContinue
        if ($configFiles.Count -gt 0) {
            $confidence += 20
            $reasons += "Configuration files detected"
        }
        
        # Reduce confidence for complex scenarios
        if ($dirState.contentDeltaPercent -gt 50) {
            $confidence -= 20
            $reasons += "High content variability may require human review"
        }
        
        # Only consider if confidence is reasonable
        if ($isCandidate -and $confidence -gt 50) {
            $candidates += @{
                path = $dirPath
                directoryType = $dirState.directoryType
                confidence = $confidence
                reasons = $reasons
                priority = $priority
                fileCount = $dirState.fileCount
                charCount = $dirState.totalCharCount
                hasManifest = $manifestFiles.Count -gt 0
                hasStructure = (Test-Path (Join-Path $fullPath "Public")) -or (Test-Path (Join-Path $fullPath "Private"))
            }
            
            Write-Log "Auto-generation candidate: $dirPath (confidence: $confidence%, type: $($dirState.directoryType))" -Level "INFO"
        }
    }
    
    # Sort by confidence and priority, limit results
    $sortedCandidates = $candidates | 
        Sort-Object @{Expression = "confidence"; Descending = $true}, @{Expression = "priority"; Descending = $false} |
        Select-Object -First $MaxCandidates
    
    Write-Log "Found $($sortedCandidates.Count) auto-generation candidates (from $($candidates.Count) total)" -Level "SUCCESS"
    
    return $sortedCandidates
}

function Analyze-DirectoryContent {
    <#
    .SYNOPSIS
    Analyzes directory content to extract information for template generation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        
        [Parameter(Mandatory = $true)]
        [string]$DirectoryType
    )
    
    $analysis = @{
        files = @()
        subdirectories = @()
        codeFiles = @()
        configFiles = @()
        documentationFiles = @()
        manifestFiles = @()
        terraformFiles = @()
        primaryLanguage = "powershell"
        hasTests = $false
        hasPublicPrivateStructure = $false
        moduleInfo = @{}
        estimatedComplexity = "simple"
    }
    
    try {
        # Get directory contents
        $files = Get-ChildItem -Path $DirectoryPath -File -ErrorAction SilentlyContinue
        $subdirs = Get-ChildItem -Path $DirectoryPath -Directory -ErrorAction SilentlyContinue
        
        $analysis.files = $files | ForEach-Object { 
            @{ 
                name = $_.Name
                extension = $_.Extension.ToLower()
                size = $_.Length
                lastModified = $_.LastWriteTime
            } 
        }
        $analysis.subdirectories = $subdirs | ForEach-Object { 
            @{ 
                name = $_.Name 
                fileCount = (Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue).Count
            } 
        }
        
        # Categorize files
        foreach ($file in $files) {
            switch ($file.Extension.ToLower()) {
                { $_ -in @('.ps1', '.psm1', '.psd1') } { 
                    $analysis.codeFiles += $file.Name
                    if ($_.Extension -eq '.psd1') {
                        $analysis.manifestFiles += $file.Name
                    }
                }
                { $_ -in @('.json', '.yaml', '.yml', '.xml', '.config') } { 
                    $analysis.configFiles += $file.Name 
                }
                { $_ -in @('.md', '.txt', '.rst') } { 
                    $analysis.documentationFiles += $file.Name 
                }
                { $_ -in @('.tf', '.tfvars') } { 
                    $analysis.terraformFiles += $file.Name 
                }
                { $_ -in @('.py', '.js', '.ts', '.go', '.rs') } { 
                    $analysis.codeFiles += $file.Name
                    # Update primary language if not PowerShell
                    if ($file.Extension -eq '.py') { $analysis.primaryLanguage = "python" }
                    elseif ($file.Extension -in @('.js', '.ts')) { $analysis.primaryLanguage = "javascript" }
                }
            }
        }
        
        # Check for common structures
        $analysis.hasPublicPrivateStructure = (Test-Path (Join-Path $DirectoryPath "Public")) -and (Test-Path (Join-Path $DirectoryPath "Private"))
        $analysis.hasTests = (Test-Path (Join-Path $DirectoryPath "tests")) -or (Test-Path (Join-Path $DirectoryPath "Tests"))
        
        # Analyze module information if it's a PowerShell module
        if ($DirectoryType -eq "powershell-module" -and $analysis.manifestFiles.Count -gt 0) {
            try {
                $manifestPath = Join-Path $DirectoryPath $analysis.manifestFiles[0]
                $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
                if ($manifest) {
                    $analysis.moduleInfo = @{
                        moduleVersion = $manifest.ModuleVersion
                        description = $manifest.Description
                        author = $manifest.Author
                        functionsToExport = $manifest.FunctionsToExport
                        requiredModules = $manifest.RequiredModules
                        powershellVersion = $manifest.PowerShellVersion
                    }
                }
            } catch {
                Write-Log "Could not parse manifest file: $_" -Level "WARN"
            }
        }
        
        # Estimate complexity
        $complexityFactors = 0
        if ($files.Count -gt 10) { $complexityFactors++ }
        if ($subdirs.Count -gt 3) { $complexityFactors++ }
        if ($analysis.codeFiles.Count -gt 5) { $complexityFactors++ }
        if ($analysis.configFiles.Count -gt 3) { $complexityFactors++ }
        
        $analysis.estimatedComplexity = switch ($complexityFactors) {
            { $_ -gt 3 } { "complex" }
            { $_ -gt 1 } { "moderate" }
            default { "simple" }
        }
        
    } catch {
        Write-Log "Error analyzing directory content: $_" -Level "ERROR"
    }
    
    return $analysis
}

function Get-TemplateData {
    <#
    .SYNOPSIS
    Generates template data for README generation based on directory analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DirectoryInfo,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ContentAnalysis,
        
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )
    
    $templateData = @{
        # Basic information
        DIRECTORY_NAME = Split-Path $RelativePath -Leaf
        RELATIVE_PATH = $RelativePath.Replace('\', '/')
        MODULE_NAME = Split-Path $RelativePath -Leaf
        
        # Content statistics
        FILE_COUNT = $ContentAnalysis.files.Count
        SUBDIRECTORY_COUNT = $ContentAnalysis.subdirectories.Count
        CODE_FILE_COUNT = $ContentAnalysis.codeFiles.Count
        CONFIG_FILE_COUNT = $ContentAnalysis.configFiles.Count
        DOC_FILE_COUNT = $ContentAnalysis.documentationFiles.Count
        
        # Flags for content types
        HAS_CODE_FILES = $ContentAnalysis.codeFiles.Count -gt 0
        HAS_CONFIG_FILES = $ContentAnalysis.configFiles.Count -gt 0
        HAS_DOC_FILES = $ContentAnalysis.documentationFiles.Count -gt 0
        HAS_TESTS = $ContentAnalysis.hasTests
        HAS_PUBLIC = Test-Path (Join-Path $ProjectRoot $RelativePath.TrimStart('/') "Public")
        HAS_PRIVATE = Test-Path (Join-Path $ProjectRoot $RelativePath.TrimStart('/') "Private")
        HAS_RESOURCES = Test-Path (Join-Path $ProjectRoot $RelativePath.TrimStart('/') "Resources")
        
        # Files and directories for structure display
        FILES = $ContentAnalysis.files | ForEach-Object { 
            @{ 
                name = $_.name
                description = Get-FileDescription -FileName $_.name -DirectoryType $DirectoryInfo.directoryType
            } 
        }
        SUBDIRECTORIES = $ContentAnalysis.subdirectories | ForEach-Object { 
            @{ 
                name = $_.name
                description = Get-SubdirectoryDescription -DirName $_.name -DirectoryType $DirectoryInfo.directoryType
            } 
        }
        
        # Module-specific data
        POWERSHELL_VERSION = $ContentAnalysis.moduleInfo.powershellVersion ?? "7.0"
        FUNCTION_COUNT = if ($ContentAnalysis.moduleInfo.functionsToExport) { $ContentAnalysis.moduleInfo.functionsToExport.Count } else { "multiple" }
        PUBLIC_FUNCTION_COUNT = if ($ContentAnalysis.hasPublicPrivateStructure) { (Get-ChildItem -Path (Join-Path $ProjectRoot $RelativePath.TrimStart('/') "Public") -Filter "*.ps1" -ErrorAction SilentlyContinue).Count } else { 0 }
        PRIVATE_FUNCTION_COUNT = if ($ContentAnalysis.hasPublicPrivateStructure) { (Get-ChildItem -Path (Join-Path $ProjectRoot $RelativePath.TrimStart('/') "Private") -Filter "*.ps1" -ErrorAction SilentlyContinue).Count } else { 0 }
        
        # Configuration
        HAS_CONFIGURATION = $ContentAnalysis.configFiles.Count -gt 0
        CONFIG_FORMAT = Get-PrimaryConfigFormat -ConfigFiles $ContentAnalysis.configFiles
        
        # Type-specific descriptions
        PRIMARY_PURPOSE = Get-PrimaryPurpose -DirectoryType $DirectoryInfo.directoryType -DirectoryName (Split-Path $RelativePath -Leaf)
        DIRECTORY_SCOPE = Get-DirectoryScope -DirectoryType $DirectoryInfo.directoryType
        USAGE_CONTEXT = Get-UsageContext -DirectoryType $DirectoryInfo.directoryType
    }
    
    # Add type-specific template data
    switch ($DirectoryInfo.directoryType) {
        "powershell-module" {
            $templateData.MODULE_DESCRIPTION = Get-ModuleDescription -ModuleName $templateData.MODULE_NAME -ModuleInfo $ContentAnalysis.moduleInfo
            $templateData.ARCHITECTURE_NOTES = "Modular PowerShell architecture with separation of public and private functions"
            $templateData.INTEGRATION_NOTES = "Full integration with AitherZero logging, configuration, and event systems"
            $templateData.BASIC_USAGE_EXAMPLE = Get-ModuleUsageExample -ModuleName $templateData.MODULE_NAME
            $templateData.FEATURES = Get-ModuleFeatures -ContentAnalysis $ContentAnalysis
        }
        
        "infrastructure" {
            $templateData.INFRASTRUCTURE_TYPE = Get-InfrastructureType -TerraformFiles $ContentAnalysis.terraformFiles
            $templateData.INFRASTRUCTURE_SCOPE = "Infrastructure provisioning and management using OpenTofu/Terraform"
            $templateData.DEPLOYMENT_MODEL = Get-DeploymentModel -ContentAnalysis $ContentAnalysis
        }
        
        "configuration" {
            $templateData.CONFIGURATION_TYPE = Get-ConfigurationType -ConfigFiles $ContentAnalysis.configFiles
            $templateData.CONFIGURATION_SCOPE = "Configuration management for AitherZero components"
            $templateData.ENVIRONMENT_SUPPORT = "Multi-environment configuration support"
        }
    }
    
    return $templateData
}

function Get-FileDescription {
    param([string]$FileName, [string]$DirectoryType)
    
    $extension = [System.IO.Path]::GetExtension($FileName).ToLower()
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    
    switch ($extension) {
        ".psd1" { "PowerShell module manifest" }
        ".psm1" { "PowerShell module implementation" }
        ".ps1" { 
            if ($baseName -match "test") { "Test script" }
            else { "PowerShell script" }
        }
        ".json" { "JSON configuration file" }
        ".yaml" { "YAML configuration file" }
        ".yml" { "YAML configuration file" }
        ".tf" { "Terraform configuration" }
        ".tfvars" { "Terraform variables" }
        ".md" { "Documentation file" }
        default { "Project file" }
    }
}

function Get-SubdirectoryDescription {
    param([string]$DirName, [string]$DirectoryType)
    
    switch ($DirName.ToLower()) {
        "public" { "Exported functions" }
        "private" { "Internal functions" }
        "tests" { "Test files" }
        "resources" { "Templates and resources" }
        "templates" { "File templates" }
        "config" { "Configuration files" }
        "docs" { "Documentation" }
        "examples" { "Usage examples" }
        default { "Subdirectory" }
    }
}

function Get-PrimaryPurpose {
    param([string]$DirectoryType, [string]$DirectoryName)
    
    switch ($DirectoryType) {
        "powershell-module" { "PowerShell module providing $DirectoryName functionality" }
        "infrastructure" { "Infrastructure as Code configuration for deployment automation" }
        "configuration" { "Configuration management and settings for AitherZero components" }
        "scripts" { "Automation and utility scripts for development and operations" }
        "tests" { "Test suites and validation scripts" }
        "build" { "Build and packaging automation" }
        default { "Component supporting AitherZero automation framework" }
    }
}

function Get-DirectoryScope {
    param([string]$DirectoryType)
    
    switch ($DirectoryType) {
        "powershell-module" { "Module functionality with comprehensive API surface" }
        "infrastructure" { "Cloud and on-premises infrastructure provisioning" }
        "configuration" { "Multi-environment configuration management" }
        "scripts" { "Development and operational automation" }
        "tests" { "Quality assurance and validation" }
        "build" { "Package creation and distribution" }
        default { "Supporting functionality for the automation framework" }
    }
}

function Get-UsageContext {
    param([string]$DirectoryType)
    
    switch ($DirectoryType) {
        "powershell-module" { "Import and use within PowerShell automation workflows" }
        "infrastructure" { "Deploy using OpenTofu/Terraform or AitherZero automation" }
        "configuration" { "Load and apply via AitherZero configuration management" }
        "scripts" { "Execute directly or integrate into automation pipelines" }
        "tests" { "Run via testing framework or CI/CD validation" }
        "build" { "Execute during build and release processes" }
        default { "Integrate with AitherZero framework components" }
    }
}

function Get-ModuleDescription {
    param([string]$ModuleName, [hashtable]$ModuleInfo)
    
    if ($ModuleInfo.description) {
        return $ModuleInfo.description
    }
    
    # Generate description based on module name
    switch -Regex ($ModuleName) {
        ".*Manager" { "management and orchestration capabilities" }
        ".*Provider" { "provider integration and abstraction" }
        ".*Core" { "core functionality and utilities" }
        ".*Integration" { "integration services and connectors" }
        ".*Automation" { "automation workflows and processes" }
        ".*Framework" { "framework components and infrastructure" }
        default { "specialized functionality for AitherZero automation" }
    }
}

function Get-ModuleUsageExample {
    param([string]$ModuleName)
    
    return @"
# Import the module
Import-Module ./aither-core/modules/$ModuleName -Force

# Use module functionality
Get-Command -Module $ModuleName
"@
}

function Get-ModuleFeatures {
    param([hashtable]$ContentAnalysis)
    
    $features = @("Cross-platform PowerShell 7.0+ compatibility")
    
    if ($ContentAnalysis.hasPublicPrivateStructure) {
        $features += "Structured module architecture with public/private separation"
    }
    
    if ($ContentAnalysis.hasTests) {
        $features += "Comprehensive test coverage with Pester framework"
    }
    
    if ($ContentAnalysis.configFiles.Count -gt 0) {
        $features += "Configurable behavior via JSON/YAML configuration"
    }
    
    $features += "Integration with AitherZero logging and error handling"
    $features += "Event-driven architecture support"
    
    return $features
}

function Get-InfrastructureType {
    param([array]$TerraformFiles)
    
    if ($TerraformFiles -contains "main.tf") {
        return "Complete infrastructure stack"
    } elseif ($TerraformFiles.Count -gt 3) {
        return "Multi-component infrastructure"
    } else {
        return "Focused infrastructure component"
    }
}

function Get-DeploymentModel {
    param([hashtable]$ContentAnalysis)
    
    if ($ContentAnalysis.configFiles -contains "variables.tf" -or $ContentAnalysis.configFiles -like "*tfvars*") {
        return "Parameterized deployment with variable configuration"
    } else {
        return "Standard deployment configuration"
    }
}

function Get-ConfigurationType {
    param([array]$ConfigFiles)
    
    $jsonFiles = $ConfigFiles | Where-Object { $_ -like "*.json" }
    $yamlFiles = $ConfigFiles | Where-Object { $_ -like "*.yaml" -or $_ -like "*.yml" }
    
    if ($jsonFiles.Count -gt $yamlFiles.Count) {
        return "JSON-based configuration"
    } elseif ($yamlFiles.Count -gt 0) {
        return "YAML-based configuration" 
    } else {
        return "Multi-format configuration"
    }
}

function Get-PrimaryConfigFormat {
    param([array]$ConfigFiles)
    
    $jsonCount = ($ConfigFiles | Where-Object { $_ -like "*.json" }).Count
    $yamlCount = ($ConfigFiles | Where-Object { $_ -like "*.yaml" -or $_ -like "*.yml" }).Count
    
    if ($jsonCount -gt $yamlCount) { "json" }
    elseif ($yamlCount -gt 0) { "yaml" }
    else { "json" }
}

function Generate-ReadmeFromTemplate {
    <#
    .SYNOPSIS
    Generates README content using template and data substitution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateFile,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$TemplateData
    )
    
    if (-not (Test-Path $TemplateFile)) {
        Write-Log "Template file not found: $TemplateFile" -Level "ERROR"
        return $null
    }
    
    try {
        $template = Get-Content -Path $TemplateFile -Raw -Encoding UTF8
        
        # Simple template substitution (replace {{VARIABLE}} with values)
        $content = $template
        foreach ($key in $TemplateData.Keys) {
            $value = $TemplateData[$key]
            
            # Handle different data types
            if ($value -is [array]) {
                $value = $value -join ", "
            } elseif ($value -is [hashtable]) {
                $value = ($value.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "; "
            } elseif ($null -eq $value) {
                $value = ""
            }
            
            $content = $content -replace "\{\{$key\}\}", $value
        }
        
        # Clean up any remaining placeholders
        $content = $content -replace "\{\{[^}]+\}\}", ""
        
        # Remove empty sections (basic cleanup)
        $content = $content -replace "(?m)^###[^\r\n]*\r?\n\r?\n(?=###|\r?\n|$)", ""
        $content = $content -replace "(?m)^\r?\n\r?\n\r?\n", "`n`n"
        
        return $content
        
    } catch {
        Write-Log "Error processing template: $_" -Level "ERROR"
        return $null
    }
}

function Generate-ReadmeContent {
    <#
    .SYNOPSIS
    Main function to generate README content for a directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DirectoryInfo,
        
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TemplateDirectory
    )
    
    Write-Log "Generating README content for $RelativePath ($($DirectoryInfo.directoryType))" -Level "INFO"
    
    # Analyze directory content
    $contentAnalysis = Analyze-DirectoryContent -DirectoryPath $DirectoryPath -DirectoryType $DirectoryInfo.directoryType
    
    # Select appropriate template
    $templateFile = switch ($DirectoryInfo.directoryType) {
        "powershell-module" { Join-Path $TemplateDirectory "module-template.md" }
        "infrastructure" { Join-Path $TemplateDirectory "infrastructure-template.md" }
        "configuration" { Join-Path $TemplateDirectory "configuration-template.md" }
        default { Join-Path $TemplateDirectory "generic-template.md" }
    }
    
    if (-not (Test-Path $templateFile)) {
        Write-Log "Template file not found: $templateFile, using generic template" -Level "WARN"
        $templateFile = Join-Path $TemplateDirectory "generic-template.md"
    }
    
    # Generate template data
    $templateData = Get-TemplateData -DirectoryInfo $DirectoryInfo -ContentAnalysis $contentAnalysis -RelativePath $RelativePath
    
    # Generate content from template
    $content = Generate-ReadmeFromTemplate -TemplateFile $templateFile -TemplateData $templateData
    
    if ($content) {
        # Add generation metadata
        $content += "`n`n---`n*Auto-generated documentation - please review and enhance as needed*`n"
        $content += "*Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*"
    }
    
    return $content
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath
    $templateDir = Join-Path $ProjectRoot $TemplateDirectory
    
    # Load current state
    if (-not (Test-Path $stateFilePath)) {
        Write-Log "State file not found: $stateFilePath" -Level "ERROR"
        Write-Log "Run Track-DocumentationState.ps1 -Initialize first" -Level "ERROR"
        exit 1
    }
    
    $content = Get-Content -Path $stateFilePath -Raw -Encoding UTF8
    $state = $content | ConvertFrom-Json -AsHashtable
    
    # Ensure template directory exists
    if (-not (Test-Path $templateDir)) {
        Write-Log "Template directory not found: $templateDir" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Starting smart README generation..." -Level "INFO"
    
    # Get auto-generation candidates
    $candidates = Get-AutoGenerationCandidates -State $state -TargetDirectories $TargetDirectories -MaxCandidates $MaxGenerations
    
    if ($candidates.Count -eq 0) {
        Write-Log "No auto-generation candidates found" -Level "INFO"
        exit 0
    }
    
    $generatedCount = 0
    $errors = @()
    
    foreach ($candidate in $candidates) {
        $dirPath = $candidate.path
        $fullPath = Join-Path $ProjectRoot $dirPath.TrimStart('/')
        $readmePath = Join-Path $fullPath "README.md"
        
        Write-Log "Generating README for: $dirPath (confidence: $($candidate.confidence)%)" -Level "INFO"
        
        if ($DryRun) {
            Write-Log "DRY RUN: Would generate $readmePath" -Level "INFO"
            continue
        }
        
        try {
            # Generate README content
            $readmeContent = Generate-ReadmeContent -DirectoryInfo $candidate -DirectoryPath $fullPath -RelativePath $dirPath -TemplateDirectory $templateDir
            
            if ($readmeContent) {
                # Write README file
                Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
                
                # Update state
                $state.directories[$dirPath].readmeExists = $true
                $state.directories[$dirPath].readmeLastModified = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                $state.directories[$dirPath].lastAutoGenerated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                $state.directories[$dirPath].flaggedForReview = $false
                $state.directories[$dirPath].reviewStatus = "current"
                
                $generatedCount++
                Write-Log "Generated README for $dirPath" -Level "SUCCESS"
            } else {
                $errors += "Failed to generate content for $dirPath"
                Write-Log "Failed to generate content for $dirPath" -Level "ERROR"
            }
            
        } catch {
            $error = "Error generating README for $dirPath : $($_.Exception.Message)"
            $errors += $error
            Write-Log $error -Level "ERROR"
        }
    }
    
    # Save updated state
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFilePath -Encoding UTF8
    
    # Output summary
    Write-Host "`n📝 Smart README Generation Summary:" -ForegroundColor Cyan
    Write-Host "  Candidates Evaluated: $($candidates.Count)" -ForegroundColor White
    Write-Host "  READMEs Generated: $generatedCount" -ForegroundColor $(if($generatedCount -gt 0){"Green"}else{"Yellow"})
    Write-Host "  Errors: $($errors.Count)" -ForegroundColor $(if($errors.Count -gt 0){"Red"}else{"Green"})
    
    if ($generatedCount -gt 0) {
        Write-Host "`n✅ Generated READMEs:" -ForegroundColor Green
        foreach ($candidate in ($candidates | Select-Object -First $generatedCount)) {
            Write-Host "  - $($candidate.path) ($($candidate.directoryType), $($candidate.confidence)% confidence)" -ForegroundColor Gray
        }
    }
    
    if ($errors.Count -gt 0) {
        Write-Host "`n❌ Errors:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  - $error" -ForegroundColor Gray
        }
    }
    
    Write-Log "Smart README generation completed: $generatedCount READMEs generated" -Level "SUCCESS"
    
} catch {
    Write-Log "Smart README generation failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}