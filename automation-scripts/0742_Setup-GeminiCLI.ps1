#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Setup and configure Google Gemini CLI for AitherZero development

.DESCRIPTION
    Configures Google Gemini API integration, sets up authentication,
    creates helpful aliases, and integrates with AitherZero workflows.

.PARAMETER ConfigureAuth
    Setup Google API authentication for Gemini

.PARAMETER CreateAliases
    Create helpful Gemini aliases for AitherZero development

.PARAMETER SetupContext
    Configure Gemini context management

.PARAMETER ValidateOnly
    Only validate existing Gemini configuration

.EXAMPLE
    ./0742_Setup-GeminiCLI.ps1 -ConfigureAuth -CreateAliases
    
.EXAMPLE
    ./0742_Setup-GeminiCLI.ps1 -ValidateOnly
    
.NOTES
    This script sets up Gemini integration for AitherZero development.
    Requires GOOGLE_API_KEY environment variable for authentication.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$ConfigureAuth,
    [switch]$CreateAliases,
    [switch]$SetupContext,
    [switch]$ValidateOnly
)

#region Metadata
$script:Stage = "DevelopmentTools"
$script:Dependencies = @('0001', '0730')
$script:Tags = @('gemini', 'google', 'ai', 'cli', 'development')
$script:Condition = '$true'
$script:Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
#endregion

#region Module Imports
$projectRoot = Split-Path $PSScriptRoot -Parent
$modulePaths = @(
    "$projectRoot/domains/utilities/Logging.psm1"
    "$projectRoot/domains/configuration/Configuration.psm1"
    "$projectRoot/domains/ai-agents/GeminiIntegration.psm1"
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}
#endregion

function Write-GeminiLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "GeminiCLI"
    } else {
        Write-Host "[$Level] Gemini CLI: $Message"
    }
}

function Test-GoogleAPIKey {
    <#
    .SYNOPSIS
        Test Google API key validity for Gemini
    #>
    [CmdletBinding()]
    param(
        [string]$ApiKey = $env:GOOGLE_API_KEY
    )
    
    try {
        if (-not $ApiKey) {
            Write-GeminiLog "GOOGLE_API_KEY environment variable not set" -Level Warning
            return $false
        }
        
        # Test API connectivity with models endpoint
        $uri = "https://generativelanguage.googleapis.com/v1beta/models?key=$ApiKey"
        $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        
        if ($response.models) {
            Write-GeminiLog "Google API key is valid and working" -Level Information
            Write-GeminiLog "Available models: $($response.models.Count)" -Level Information
            return $true
        } else {
            Write-GeminiLog "Unexpected API response format" -Level Warning
            return $false
        }
    }
    catch {
        Write-GeminiLog "Failed to validate Google API key: $_" -Level Error
        return $false
    }
}

function Setup-GeminiAuthentication {
    <#
    .SYNOPSIS
        Setup Gemini authentication configuration
    #>
    [CmdletBinding()]
    param()
    
    Write-GeminiLog "Setting up Gemini authentication" -Level Information
    
    try {
        $apiKey = $env:GOOGLE_API_KEY
        
        if (-not $apiKey) {
            Write-GeminiLog "GOOGLE_API_KEY not found in environment" -Level Warning
            
            if (-not $ValidateOnly) {
                Write-GeminiLog "To get a Google API key:" -Level Information
                Write-GeminiLog "1. Go to https://aistudio.google.com/app/apikey" -Level Information
                Write-GeminiLog "2. Create a new API key" -Level Information
                Write-GeminiLog "3. Copy the key and set it as GOOGLE_API_KEY environment variable" -Level Information
                
                $secureKey = Read-Host -Prompt "Enter your Google API key" -AsSecureString
                if ($secureKey.Length -gt 0) {
                    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
                    )
                    
                    # Set environment variable for current session
                    $env:GOOGLE_API_KEY = $apiKey
                    
                    # Set persistent environment variable
                    if ($PSCmdlet.ShouldProcess("User environment variable 'GOOGLE_API_KEY'", "Set API key")) {
                        [Environment]::SetEnvironmentVariable('GOOGLE_API_KEY', $apiKey, [EnvironmentVariableTarget]::User)
                        Write-GeminiLog "API key stored in user environment variables" -Level Information
                    }
                } else {
                    Write-GeminiLog "No API key provided" -Level Warning
                    return $false
                }
            }
        }
        
        # Test the API key
        if (-not (Test-GoogleAPIKey -ApiKey $apiKey)) {
            Write-GeminiLog "API key validation failed" -Level Error
            return $false
        }
        
        # Create Gemini configuration directory
        $geminiDir = "$projectRoot/.gemini"
        if (-not (Test-Path $geminiDir)) {
            New-Item -Path $geminiDir -ItemType Directory -Force | Out-Null
        }
        
        # Create authentication config
        $authConfig = @{
            api_key = "env:GOOGLE_API_KEY"
            api_url = "https://generativelanguage.googleapis.com/v1beta"
            model = "gemini-pro"
            max_tokens = 2048
            temperature = 0.9
            top_p = 0.8
            top_k = 10
        }
        
        $authConfigPath = "$geminiDir/auth.json"
        $authConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $authConfigPath
        
        Write-GeminiLog "Gemini authentication configured successfully" -Level Information
        return $true
    }
    catch {
        Write-GeminiLog "Failed to setup Gemini authentication: $_" -Level Error
        return $false
    }
}

function Setup-GeminiContext {
    <#
    .SYNOPSIS
        Setup Gemini context management for AitherZero
    #>
    [CmdletBinding()]
    param()
    
    Write-GeminiLog "Setting up Gemini context management" -Level Information
    
    try {
        $geminiDir = "$projectRoot/.gemini"
        if (-not (Test-Path $geminiDir)) {
            New-Item -Path $geminiDir -ItemType Directory -Force | Out-Null
        }
        
        # Create context configuration optimized for Gemini's large context window
        $contextConfig = @{
            version = "1.0"
            project = @{
                name = "AitherZero"
                type = "infrastructure-automation"
                description = "PowerShell-based cross-platform infrastructure automation platform"
                specialties = @("code-generation", "optimization", "analysis", "large-context-processing")
                root_path = $projectRoot
            }
            context_strategy = @{
                max_context_tokens = 1000000  # Gemini's large context window
                context_compression = $false   # Can handle large contexts natively
                prioritize_recent = $true
                include_full_files = $true     # Take advantage of large context
            }
            context_files = @(
                @{
                    path = ".github/copilot-instructions.md"
                    type = "instructions"
                    priority = "critical"
                    include_full = $true
                    description = "Complete project instructions and development patterns"
                }
                @{
                    path = "README.md"
                    type = "documentation"
                    priority = "high"
                    include_full = $true
                    description = "Project overview and architecture"
                }
                @{
                    path = "config.psd1"
                    type = "configuration"
                    priority = "high"
                    include_full = $true
                    description = "Main configuration with AI agent settings"
                }
                @{
                    path = "config.example.psd1"
                    type = "configuration"
                    priority = "high"
                    include_full = $true
                    description = "Comprehensive configuration template"
                }
                @{
                    path = "AitherZero.psd1"
                    type = "manifest"
                    priority = "high"
                    include_full = $true
                    description = "Module manifest and structure"
                }
            )
            bulk_include_patterns = @(
                @{
                    pattern = "domains/**/*.psm1"
                    type = "modules"
                    description = "All domain modules for full context understanding"
                    max_files = 50
                }
                @{
                    pattern = "automation-scripts/**/*.ps1"
                    type = "scripts"
                    description = "Automation scripts showing platform patterns"
                    max_files = 100
                }
                @{
                    pattern = "tests/**/*.ps1"
                    type = "tests"
                    description = "Test files showing expected behavior"
                    max_files = 50
                }
                @{
                    pattern = "orchestration/**/*.json"
                    type = "orchestration"
                    description = "Workflow and playbook definitions"
                    max_files = 25
                }
            )
            exclude_patterns = @(
                "logs/**"
                "backups/**"
                "archive/**"
                "temp-*/**"
                "*.log"
                ".terraform/**"
                "node_modules/**"
                "__pycache__/**"
                "*.cache"
                "*.tmp"
            )
            gemini_specialization = @{
                code_generation = @{
                    focus = @("powershell", "infrastructure", "automation", "cross-platform")
                    patterns = @("aitherzero-standards", "module-architecture", "error-handling")
                    output_format = "complete-implementations"
                }
                optimization = @{
                    targets = @("performance", "memory", "readability", "maintainability")
                    analysis_depth = "comprehensive"
                    include_alternatives = $true
                }
                analysis = @{
                    scope = "full-codebase"
                    cross_reference = $true
                    dependency_tracking = $true
                    pattern_recognition = $true
                }
            }
        }
        
        $contextConfigPath = "$geminiDir/context.json"
        $contextConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $contextConfigPath
        
        # Create Gemini-specific prompt templates
        $promptTemplates = @{
            code_generation = @"
You are Gemini, an expert AI assistant specializing in PowerShell development for the AitherZero infrastructure automation platform.

## Your Expertise
- PowerShell 7+ cross-platform development (Windows, Linux, macOS)
- Infrastructure automation and orchestration
- AitherZero architecture and patterns
- Code generation and optimization
- Large-scale codebase analysis

## AitherZero Context
{context_summary}

## Current Task
Generate high-quality PowerShell code following AitherZero standards:

REQUIREMENTS:
{requirements}

CONSTRAINTS:
- PowerShell 7+ compatibility
- Cross-platform support
- AitherZero coding patterns
- Comprehensive error handling
- Proper logging with Write-CustomLog
- Comment-based help documentation

OUTPUT FORMAT:
Provide complete, production-ready code with:
1. Full implementation
2. Comment-based help
3. Error handling
4. Cross-platform considerations
5. Integration points with existing AitherZero components
"@

            optimization = @"
You are Gemini, an expert AI assistant specializing in PowerShell optimization for the AitherZero platform.

## Your Expertise
- Performance analysis and optimization
- Memory usage optimization
- Code quality improvement
- Architecture pattern recognition
- Cross-platform PowerShell best practices

## AitherZero Context
{context_summary}

## Optimization Task
Analyze and optimize this PowerShell code:

CODE:
{code}

OPTIMIZATION TARGETS:
{optimization_targets}

ANALYSIS REQUIREMENTS:
1. Performance bottlenecks identification
2. Memory usage analysis
3. Cross-platform compatibility check
4. AitherZero pattern compliance
5. Security considerations
6. Maintainability improvements

OUTPUT FORMAT:
Provide:
1. Optimized code with improvements highlighted
2. Performance analysis and expected gains
3. Memory usage improvements
4. Cross-platform considerations
5. Security enhancements
6. Detailed explanation of changes
"@

            analysis = @"
You are Gemini, an expert AI assistant specializing in comprehensive code analysis for the AitherZero platform.

## Your Expertise
- Deep codebase analysis
- Architecture pattern recognition
- Dependency tracking
- Security vulnerability assessment
- Performance impact analysis
- Cross-platform compatibility assessment

## AitherZero Context
{context_summary}

## Analysis Task
Perform comprehensive analysis of:

TARGET:
{analysis_target}

ANALYSIS SCOPE:
{analysis_scope}

REQUIRED ANALYSIS:
1. Code quality assessment
2. Architecture compliance
3. Security vulnerability scan
4. Performance implications
5. Cross-platform compatibility
6. Dependency analysis
7. Integration impact
8. Maintainability assessment

OUTPUT FORMAT:
Provide detailed analysis with:
1. Executive summary
2. Detailed findings by category
3. Risk assessment (Critical/High/Medium/Low)
4. Specific recommendations
5. Code examples for improvements
6. Integration considerations
"@
        }
        
        $templatesPath = "$geminiDir/prompt-templates.json"
        $promptTemplates | ConvertTo-Json -Depth 10 | Set-Content -Path $templatesPath
        
        Write-GeminiLog "Gemini context management configured successfully" -Level Information
        return $true
    }
    catch {
        Write-GeminiLog "Failed to setup Gemini context: $_" -Level Error
        return $false
    }
}

function New-GeminiAliases {
    <#
    .SYNOPSIS
        Create helpful Gemini CLI aliases
    #>
    [CmdletBinding()]
    param()
    
    Write-GeminiLog "Creating Gemini CLI aliases" -Level Information
    
    try {
        # Create PowerShell functions for Gemini integration
        $aliasContent = @"
# AitherZero Gemini CLI Integration

function gemini-chat {
    param([string]`$Message)
    if (Get-Command Invoke-GeminiChat -ErrorAction SilentlyContinue) {
        Invoke-GeminiChat -Message `$Message
    } else {
        Write-Warning "Gemini integration not available. Run az 0730 to setup AI agents."
    }
}

function gemini-generate {
    param(
        [string]`$Requirements,
        [ValidateSet('Domain', 'Script', 'Function', 'Class', 'Configuration')]
        [string]`$Type = 'Function',
        [switch]`$IncludeTests
    )
    if (Get-Command Invoke-GeminiCodeGeneration -ErrorAction SilentlyContinue) {
        Invoke-GeminiCodeGeneration -Requirements `$Requirements -ModuleType `$Type -IncludeTests:`$IncludeTests
    } else {
        Write-Warning "Gemini integration not available. Run az 0730 to setup AI agents."
    }
}

function gemini-optimize {
    param(
        [string]`$FilePath,
        [ValidateSet('Speed', 'Memory', 'Readability', 'Security', 'All')]
        [string]`$Target = 'All'
    )
    if (Get-Command Invoke-GeminiCodeOptimization -ErrorAction SilentlyContinue) {
        if (Test-Path `$FilePath) {
            `$code = Get-Content `$FilePath -Raw
            Invoke-GeminiCodeOptimization -Code `$code -OptimizationTarget `$Target
        } else {
            Write-Error "File not found: `$FilePath"
        }
    } else {
        Write-Warning "Gemini integration not available. Run az 0730 to setup AI agents."
    }
}

function gemini-analyze {
    param(
        [string]`$Path,
        [ValidateSet('File', 'Directory', 'Module', 'Project')]
        [string]`$Scope = 'File'
    )
    
    if (-not (Get-Command Invoke-GeminiChat -ErrorAction SilentlyContinue)) {
        Write-Warning "Gemini integration not available. Run az 0730 to setup AI agents."
        return
    }
    
    switch (`$Scope) {
        'File' {
            if (Test-Path `$Path -PathType Leaf) {
                `$code = Get-Content `$Path -Raw
                `$prompt = "Analyze this AitherZero PowerShell file comprehensively:`n`n```powershell`n`$code`n```"
                Invoke-GeminiChat -Message `$prompt -MaxTokens 4000
            } else {
                Write-Error "File not found: `$Path"
            }
        }
        'Directory' {
            if (Test-Path `$Path -PathType Container) {
                `$files = Get-ChildItem `$Path -Recurse -Include "*.ps1", "*.psm1", "*.psd1" | Select-Object -First 10
                `$fileList = `$files | ForEach-Object { "`$(`$_.Name): `$(`$_.FullName)" } | Out-String
                `$prompt = "Analyze this AitherZero directory structure and key files:`n`nDirectory: `$Path`n`nKey Files:`n`$fileList"
                Invoke-GeminiChat -Message `$prompt -MaxTokens 4000
            } else {
                Write-Error "Directory not found: `$Path"
            }
        }
        'Module' {
            if (Test-Path `$Path) {
                `$code = Get-Content `$Path -Raw
                `$prompt = "Perform comprehensive module analysis for this AitherZero PowerShell module:`n`n```powershell`n`$code`n```"
                Invoke-GeminiChat -Message `$prompt -MaxTokens 4000
            } else {
                Write-Error "Module file not found: `$Path"
            }
        }
        'Project' {
            `$prompt = "Analyze the entire AitherZero project structure, focusing on:`n1. Architecture patterns`n2. Module dependencies`n3. Automation script organization`n4. AI integration points`n5. Cross-platform considerations`n6. Overall code quality"
            Invoke-GeminiChat -Message `$prompt -MaxTokens 4000
        }
    }
}

function gemini-explain {
    param([string]`$FilePath, [switch]`$Detailed)
    if (Get-Command Invoke-GeminiChat -ErrorAction SilentlyContinue) {
        if (Test-Path `$FilePath) {
            `$code = Get-Content `$FilePath -Raw
            `$detailLevel = if (`$Detailed) { "comprehensive and detailed" } else { "clear and concise" }
            `$prompt = "Provide a `$detailLevel explanation of this AitherZero PowerShell code, including:`n1. Purpose and functionality`n2. How it fits into AitherZero architecture`n3. Key patterns and techniques used`n4. Dependencies and integration points`n`n```powershell`n`$code`n```"
            Invoke-GeminiChat -Message `$prompt -MaxTokens 4000
        } else {
            Write-Error "File not found: `$FilePath"
        }
    } else {
        Write-Warning "Gemini integration not available. Run az 0730 to setup AI agents."
    }
}

function gemini-context {
    param([switch]`$Update, [switch]`$Show, [switch]`$Compress)
    `$contextPath = "./.gemini/context.json"
    
    if (`$Update) {
        Write-Host "Updating Gemini context with full project state..." -ForegroundColor Yellow
        # Gemini can handle large contexts, so include comprehensive information
        `$context = @{
            updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            git_status = (git status --porcelain 2>`$null)
            recent_commits = (git log --oneline -10 2>`$null)
            current_branch = (git branch --show-current 2>`$null)
            modified_files = (git diff --name-only HEAD~5 2>`$null)
            project_stats = @{
                ps1_files = (Get-ChildItem -Recurse -Include "*.ps1" | Measure-Object).Count
                psm1_files = (Get-ChildItem -Recurse -Include "*.psm1" | Measure-Object).Count
                test_files = (Get-ChildItem -Path "tests" -Recurse -Include "*.ps1" -ErrorAction SilentlyContinue | Measure-Object).Count
            }
        }
        
        if (Test-Path `$contextPath) {
            `$existingContext = Get-Content `$contextPath | ConvertFrom-Json
            `$existingContext.last_update = `$context
            `$existingContext | ConvertTo-Json -Depth 10 | Set-Content `$contextPath
        }
        
        Write-Host "Gemini context updated with comprehensive project state." -ForegroundColor Green
    }
    
    if (`$Show) {
        if (Test-Path `$contextPath) {
            Get-Content `$contextPath | ConvertFrom-Json | ConvertTo-Json -Depth 10
        } else {
            Write-Warning "Gemini context file not found. Run az 0742 to setup Gemini CLI."
        }
    }
    
    if (`$Compress) {
        Write-Host "Note: Gemini handles large contexts natively. Compression not typically needed." -ForegroundColor Yellow
    }
}

function gemini-usage {
    if (Get-Command Get-GeminiUsage -ErrorAction SilentlyContinue) {
        Get-GeminiUsage
    } else {
        Write-Warning "Gemini integration not available. Run az 0730 to setup AI agents."
    }
}
"@
        
        # Add to PowerShell profile
        $profilePath = $PROFILE.CurrentUserAllHosts
        if (-not (Test-Path (Split-Path $profilePath -Parent))) {
            New-Item -Path (Split-Path $profilePath -Parent) -ItemType Directory -Force | Out-Null
        }
        
        if (Test-Path $profilePath) {
            $existingContent = Get-Content $profilePath -Raw
            if ($existingContent -notlike "*AitherZero Gemini CLI Integration*") {
                Add-Content -Path $profilePath -Value "`n$aliasContent"
                Write-GeminiLog "Added Gemini aliases to PowerShell profile" -Level Information
            } else {
                Write-GeminiLog "Gemini aliases already exist in PowerShell profile" -Level Information
            }
        } else {
            Set-Content -Path $profilePath -Value $aliasContent
            Write-GeminiLog "Created PowerShell profile with Gemini aliases" -Level Information
        }
        
        return $true
    }
    catch {
        Write-GeminiLog "Failed to create Gemini aliases: $_" -Level Error
        return $false
    }
}

function Test-GeminiIntegration {
    <#
    .SYNOPSIS
        Validate complete Gemini integration
    #>
    [CmdletBinding()]
    param()
    
    Write-GeminiLog "Validating Gemini integration" -Level Information
    
    $results = @{
        APIKey = Test-GoogleAPIKey
        AuthConfig = Test-Path "$projectRoot/.gemini/auth.json"
        ContextConfig = Test-Path "$projectRoot/.gemini/context.json"
        PromptTemplates = Test-Path "$projectRoot/.gemini/prompt-templates.json"
        GeminiModule = Test-Path "$projectRoot/domains/ai-agents/GeminiIntegration.psm1"
    }
    
    $allPassed = $true
    foreach ($test in $results.Keys) {
        $status = if ($results[$test]) { "✓ PASS" } else { "✗ FAIL"; $allPassed = $false }
        Write-GeminiLog "$test : $status" -Level Information
    }
    
    if ($allPassed) {
        Write-GeminiLog "All Gemini integration tests passed" -Level Information
        Write-GeminiLog "Use 'gemini-chat', 'gemini-generate', 'gemini-optimize', 'gemini-analyze' commands" -Level Information
        Write-GeminiLog "Gemini's large context window (1M tokens) enables comprehensive analysis" -Level Information
        return $true
    } else {
        Write-GeminiLog "Some Gemini integration tests failed" -Level Warning
        return $false
    }
}

# Main execution
function Main {
    Write-GeminiLog "Starting Gemini CLI setup for AitherZero (Platform: $script:Platform)" -Level Information
    
    try {
        if ($ValidateOnly) {
            return Test-GeminiIntegration
        }
        
        $success = $true
        
        # Setup authentication
        if ($ConfigureAuth) {
            $success = $success -and (Setup-GeminiAuthentication)
        }
        
        # Setup context management
        if ($SetupContext) {
            $success = $success -and (Setup-GeminiContext)
        }
        
        # Create aliases
        if ($CreateAliases) {
            $success = $success -and (New-GeminiAliases)
        }
        
        # Final validation
        if ($success) {
            $success = Test-GeminiIntegration
        }
        
        if ($success) {
            Write-GeminiLog "Gemini CLI setup completed successfully" -Level Information
            Write-GeminiLog "Restart your terminal to use the new aliases" -Level Information
            Write-GeminiLog "Run 'gemini-context -Update' to initialize context" -Level Information
            Write-GeminiLog "Gemini excels at code generation and large-scale analysis" -Level Information
        } else {
            Write-GeminiLog "Gemini CLI setup completed with issues" -Level Warning
        }
        
        return $success
    }
    catch {
        Write-GeminiLog "Failed to setup Gemini CLI: $_" -Level Error
        return $false
    }
}

# Run main function
if (-not $MyInvocation.ScriptName) {
    # Running interactively
    Main
} else {
    # Running as script
    $result = Main
    exit if ($result) { 0 } else { 1 }
}