#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    OpenAI Codex/GPT Integration for AitherZero

.DESCRIPTION
    Provides integration with OpenAI's Codex and GPT models for code generation, 
    documentation, and analysis within the AitherZero platform.

.NOTES
    This module handles OpenAI API calls, context management, and response processing
    for AI-powered development workflows.
#>

# Module variables
$script:CodexConfig = $null
$script:ApiKey = $null
$script:BaseUrl = "https://api.openai.com/v1"
$script:RateLimiter = @{
    RequestsPerMinute = 60
    TokensPerMinute = 150000
    LastRequest = $null
    RequestCount = 0
    TokenCount = 0
}

# Import required modules
if (Test-Path "$PSScriptRoot/../utilities/Logging.psm1") {
    Import-Module "$PSScriptRoot/../utilities/Logging.psm1" -Force
}

function Write-CodexLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "CodexIntegration"
    } else {
        Write-Output "[$Level] Codex: $Message"
    }
}

function Initialize-CodexIntegration {
    <#
    .SYNOPSIS
        Initialize OpenAI Codex/GPT integration
        
    .DESCRIPTION
        Sets up the OpenAI API client with authentication and configuration
        
    .PARAMETER Configuration
        Configuration hashtable containing OpenAI settings
        
    .PARAMETER ApiKey
        OpenAI API key for access
        
    .PARAMETER Model
        OpenAI model to use (gpt-4, gpt-3.5-turbo, etc.)
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{},
        [string]$ApiKey = $env:OPENAI_API_KEY,
        [string]$Model = "gpt-4"
    )
    
    Write-CodexLog "Initializing OpenAI Codex integration" -Level Information
    
    try {
        if (-not $ApiKey) {
            $ApiKey = $env:OPENAI_API_KEY
            if (-not $ApiKey) {
                throw "OpenAI API key not found. Set OPENAI_API_KEY environment variable."
            }
        }
        
        $script:ApiKey = $ApiKey
        $script:CodexConfig = $Configuration
        $script:CodexConfig.Model = $Model
        
        # Test connection
        $testResult = Test-CodexConnection
        if (-not $testResult) {
            throw "Failed to connect to OpenAI API"
        }
        
        Write-CodexLog "OpenAI Codex integration initialized successfully" -Level Information
        return $true
    }
    catch {
        Write-CodexLog "Failed to initialize OpenAI Codex integration: $_" -Level Error
        return $false
    }
}

function Test-CodexConnection {
    <#
    .SYNOPSIS
        Test connection to OpenAI API
        
    .DESCRIPTION
        Validates API key and connection to OpenAI service
    #>
    [CmdletBinding()]
    param()
    
    try {
        $uri = "$script:BaseUrl/models"
        $headers = @{
            'Authorization' = "Bearer $script:ApiKey"
            'Content-Type' = 'application/json'
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
        
        Write-CodexLog "Connection to OpenAI API successful" -Level Information
        return $true
    }
    catch {
        Write-CodexLog "Failed to connect to OpenAI API: $_" -Level Error
        return $false
    }
}

function Invoke-CodexChat {
    <#
    .SYNOPSIS
        Send a chat request to OpenAI GPT
        
    .DESCRIPTION
        Sends a message to OpenAI GPT and returns the AI response
        
    .PARAMETER Message
        The message/prompt to send to GPT
        
    .PARAMETER SystemContext
        System context or role definition for the conversation
        
    .PARAMETER MaxTokens
        Maximum tokens to generate in the response
        
    .PARAMETER Temperature
        Controls randomness in the response (0.0 to 2.0)
        
    .PARAMETER Model
        OpenAI model to use (overrides configuration)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$SystemContext = "You are an expert PowerShell developer working with the AitherZero infrastructure automation platform.",
        
        [int]$MaxTokens = 4000,
        
        [decimal]$Temperature = 0.5,
        
        [string]$Model = $script:CodexConfig.Model
    )
    
    Write-CodexLog "Sending chat request to OpenAI GPT" -Level Information
    
    try {
        # Rate limiting check
        if (-not (Test-CodexRateLimit)) {
            throw "Rate limit exceeded. Please wait before making another request."
        }
        
        $uri = "$script:BaseUrl/chat/completions"
        
        $messages = @(
            @{
                role = "system"
                content = $SystemContext
            },
            @{
                role = "user"
                content = $Message
            }
        )
        
        $requestBody = @{
            model = $Model
            messages = $messages
            max_tokens = $MaxTokens
            temperature = [float]$Temperature
            top_p = 1
            frequency_penalty = 0
            presence_penalty = 0
        } | ConvertTo-Json -Depth 10
        
        $headers = @{
            'Authorization' = "Bearer $script:ApiKey"
            'Content-Type' = 'application/json'
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $requestBody -ErrorAction Stop
        
        # Update rate limiter
        Update-CodexRateLimit -TokensUsed $response.usage.total_tokens
        
        Write-CodexLog "Received response from OpenAI GPT" -Level Information
        
        return @{
            Success = $true
            Response = $response.choices[0].message.content
            Usage = @{
                PromptTokens = $response.usage.prompt_tokens
                CompletionTokens = $response.usage.completion_tokens
                TotalTokens = $response.usage.total_tokens
            }
            Model = $response.model
            FinishReason = $response.choices[0].finish_reason
        }
    }
    catch {
        Write-CodexLog "Failed to get response from OpenAI GPT: $_" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
            Response = $null
        }
    }
}

function Invoke-CodexDocumentation {
    <#
    .SYNOPSIS
        Generate documentation using OpenAI Codex
        
    .DESCRIPTION
        Uses OpenAI to generate comprehensive documentation for PowerShell code
        
    .PARAMETER Code
        The PowerShell code to document
        
    .PARAMETER DocumentationType
        Type of documentation to generate (Help, README, API, Architecture)
        
    .PARAMETER IncludeExamples
        Whether to include usage examples
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [ValidateSet('Help', 'README', 'API', 'Architecture', 'UserGuide')]
        [string]$DocumentationType = 'Help',
        
        [switch]$IncludeExamples
    )
    
    $systemContext = @"
You are an expert technical writer and PowerShell developer specializing in the AitherZero infrastructure automation platform.

Generate comprehensive $DocumentationType documentation following these standards:

AITHERZERO CONTEXT:
- Infrastructure automation platform with number-based script orchestration (0000-9999)
- Domain-based module architecture (/domains/ directory)
- Cross-platform PowerShell 7+ compatibility
- Hierarchical configuration system using .psd1 files
- AI-powered development workflows with multi-agent orchestration

DOCUMENTATION STANDARDS:
- Clear, concise, and accurate descriptions
- Include parameter details and types
- Provide practical examples relevant to AitherZero
- Document error conditions and troubleshooting
- Follow PowerShell comment-based help format for code documentation
- Use proper Markdown formatting for README/documentation files
- Include cross-references to related AitherZero components

FOR POWERSHELL HELP:
- Use .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE, .NOTES format
- Include .LINK for related functions
- Document pipeline input/output
- Include error handling information

FOR README/MARKDOWN:
- Use proper heading hierarchy (# ## ###)
- Include installation/setup instructions
- Provide usage examples with expected output
- Document configuration options
- Include troubleshooting section
- Add links to related documentation
"@
    
    $examplesInstruction = if ($IncludeExamples) { 
        "Include comprehensive examples showing real-world usage scenarios." 
    } else { 
        "Focus on clear descriptions without extensive examples." 
    }
    
    $prompt = @"
Generate $DocumentationType documentation for this AitherZero PowerShell code:

```powershell
$Code
```

Requirements:
- Follow AitherZero documentation standards
- $examplesInstruction
- Ensure accuracy and completeness
- Use appropriate formatting for $DocumentationType
- Include integration points with other AitherZero components

Provide complete, production-ready documentation.
"@
    
    return Invoke-CodexChat -Message $prompt -SystemContext $systemContext -MaxTokens 4000 -Temperature 0.3
}

function Invoke-CodexRefactoring {
    <#
    .SYNOPSIS
        Refactor PowerShell code using OpenAI Codex
        
    .DESCRIPTION
        Uses OpenAI to refactor and improve PowerShell code structure and quality
        
    .PARAMETER Code
        The PowerShell code to refactor
        
    .PARAMETER RefactoringGoals
        Specific goals for refactoring (Readability, Performance, Maintainability, Security)
        
    .PARAMETER PreserveFunctionality
        Ensure the refactored code maintains the same functionality
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [string[]]$RefactoringGoals = @('Readability', 'Maintainability'),
        
        [switch]$PreserveFunctionality = $true
    )
    
    $systemContext = @"
You are an expert PowerShell developer and code refactoring specialist working with the AitherZero infrastructure automation platform.

Refactor the provided PowerShell code focusing on: $($RefactoringGoals -join ', ')

AITHERZERO STANDARDS TO FOLLOW:
- PowerShell 7+ compatibility and cross-platform support
- Use Write-CustomLog instead of Write-Host for output
- Implement [CmdletBinding()] for advanced functions
- Include comprehensive comment-based help
- Support platform detection (\$IsWindows, \$IsLinux, \$IsMacOS)
- Use hierarchical configuration loading patterns
- Implement proper error handling with try/catch
- Follow approved PowerShell verbs and naming conventions
- Support -WhatIf and -Confirm for state-changing functions
- Use Export-ModuleMember for module exports

REFACTORING PRINCIPLES:
- Improve code structure and organization
- Enhance readability and maintainability
- Optimize performance where appropriate
- Strengthen error handling and validation
- Add appropriate logging and debugging support
- Ensure consistent naming and formatting
- Extract reusable functions and utilities
- Improve parameter validation and documentation

$(if ($PreserveFunctionality) { "CRITICAL: Maintain exact same functionality and behavior - only improve the implementation." })

Provide:
1. Refactored code with improvements
2. Summary of changes made
3. Justification for each major change
4. Any breaking changes or considerations
"@
    
    $prompt = @"
Please refactor this AitherZero PowerShell code:

```powershell
$Code
```

Refactoring goals: $($RefactoringGoals -join ', ')
$(if ($PreserveFunctionality) { "Preserve existing functionality exactly." })

Focus on improving code quality while maintaining AitherZero standards.
"@
    
    return Invoke-CodexChat -Message $prompt -SystemContext $systemContext -MaxTokens 4000 -Temperature 0.2
}

function Invoke-CodexCodeReview {
    <#
    .SYNOPSIS
        Perform code review using OpenAI Codex
        
    .DESCRIPTION
        Uses OpenAI to analyze PowerShell code and provide comprehensive review feedback
        
    .PARAMETER Code
        The PowerShell code to review
        
    .PARAMETER ReviewFocus
        Areas to focus the review on (Security, Performance, Quality, Architecture)
        
    .PARAMETER IncludeSuggestions
        Whether to include specific improvement suggestions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [string[]]$ReviewFocus = @('Quality', 'Security', 'Performance'),
        
        [switch]$IncludeSuggestions = $true
    )
    
    $systemContext = @"
You are a senior PowerShell architect and code reviewer specializing in the AitherZero infrastructure automation platform.

Perform a comprehensive code review focusing on: $($ReviewFocus -join ', ')

REVIEW CRITERIA FOR AITHERZERO:
- PowerShell 7+ best practices and cross-platform compatibility
- Adherence to AitherZero coding standards and patterns
- Proper use of Write-CustomLog for logging
- Implementation of [CmdletBinding()] and parameter validation
- Comment-based help completeness and accuracy  
- Error handling and exception management
- Security considerations and credential handling
- Performance implications and optimization opportunities
- Module loading and dependency management
- Platform compatibility checks
- Configuration handling patterns
- Testing considerations

SECURITY REVIEW:
- Credential and sensitive data handling
- Input validation and sanitization
- Execution policy and script signing considerations
- Network and API security practices
- File system access patterns

PERFORMANCE REVIEW:
- Resource usage and memory management
- Loop optimization and bulk operations
- Pipeline usage and streaming
- Concurrent execution opportunities
- Caching and memoization possibilities

ARCHITECTURE REVIEW:
- Function and module organization
- Separation of concerns
- Reusability and modularity
- Integration with AitherZero domains
- Configuration and dependency patterns

Provide detailed, actionable feedback with specific line references where possible.
"@
    
    $suggestionsInstruction = if ($IncludeSuggestions) {
        "Include specific code improvement suggestions and examples."
    } else {
        "Focus on identifying issues without providing implementation suggestions."
    }
    
    $prompt = @"
Please perform a comprehensive code review of this AitherZero PowerShell code:

```powershell
$Code
```

Review focus areas: $($ReviewFocus -join ', ')

$suggestionsInstruction

Provide detailed analysis covering:
1. Code quality and adherence to AitherZero standards
2. Security considerations and potential vulnerabilities
3. Performance optimization opportunities
4. Architecture and design patterns
5. Testing and maintainability aspects
6. Specific issues found with severity levels (Critical, High, Medium, Low)
7. Overall assessment and recommendations
"@
    
    return Invoke-CodexChat -Message $prompt -SystemContext $systemContext -MaxTokens 4000 -Temperature 0.1
}

function Test-CodexRateLimit {
    <#
    .SYNOPSIS
        Check if rate limits allow for another request
    #>
    [CmdletBinding()]
    param()
    
    $now = Get-Date
    
    if ($script:RateLimiter.LastRequest) {
        $timeDiff = ($now - $script:RateLimiter.LastRequest).TotalMinutes
        
        # Reset counters if more than a minute has passed
        if ($timeDiff -ge 1) {
            $script:RateLimiter.RequestCount = 0
            $script:RateLimiter.TokenCount = 0
        }
    }
    
    # Check rate limits
    if ($script:RateLimiter.RequestCount -ge $script:RateLimiter.RequestsPerMinute) {
        Write-CodexLog "Request rate limit exceeded" -Level Warning
        return $false
    }
    
    if ($script:RateLimiter.TokenCount -ge $script:RateLimiter.TokensPerMinute) {
        Write-CodexLog "Token rate limit exceeded" -Level Warning
        return $false
    }
    
    return $true
}

function Update-CodexRateLimit {
    <#
    .SYNOPSIS
        Update rate limiting counters
    #>
    [CmdletBinding()]
    param(
        [int]$TokensUsed = 0
    )
    
    $script:RateLimiter.LastRequest = Get-Date
    $script:RateLimiter.RequestCount++
    $script:RateLimiter.TokenCount += $TokensUsed
}

function Get-CodexUsage {
    <#
    .SYNOPSIS
        Get current usage statistics for OpenAI API
    #>
    [CmdletBinding()]
    param()
    
    return @{
        RequestsThisMinute = $script:RateLimiter.RequestCount
        TokensThisMinute = $script:RateLimiter.TokenCount
        RequestsPerMinuteLimit = $script:RateLimiter.RequestsPerMinute
        TokensPerMinuteLimit = $script:RateLimiter.TokensPerMinute
        LastRequestTime = $script:RateLimiter.LastRequest
        RemainingRequests = $script:RateLimiter.RequestsPerMinute - $script:RateLimiter.RequestCount
        RemainingTokens = $script:RateLimiter.TokensPerMinute - $script:RateLimiter.TokenCount
        CurrentModel = $script:CodexConfig.Model
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-CodexIntegration',
    'Test-CodexConnection',
    'Invoke-CodexChat',
    'Invoke-CodexDocumentation',
    'Invoke-CodexRefactoring', 
    'Invoke-CodexCodeReview',
    'Get-CodexUsage'
)