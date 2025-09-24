#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Google Gemini API Integration for AitherZero

.DESCRIPTION
    Provides integration with Google's Gemini AI model for code generation, 
    optimization, and analysis within the AitherZero platform.

.NOTES
    This module handles Gemini API calls, context management, and response processing
    for AI-powered development workflows.
#>

# Module variables
$script:GeminiConfig = $null
$script:ApiKey = $null
$script:BaseUrl = "https://generativelanguage.googleapis.com/v1beta"
$script:RateLimiter = @{
    RequestsPerMinute = 60
    TokensPerMinute = 120000
    LastRequest = $null
    RequestCount = 0
    TokenCount = 0
}

# Import required modules
if (Test-Path "$PSScriptRoot/../utilities/Logging.psm1") {
    Import-Module "$PSScriptRoot/../utilities/Logging.psm1" -Force
}

function Write-GeminiLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "GeminiIntegration"
    } else {
        Write-Output "[$Level] Gemini: $Message"
    }
}

function Initialize-GeminiIntegration {
    <#
    .SYNOPSIS
        Initialize Gemini API integration
        
    .DESCRIPTION
        Sets up the Gemini API client with authentication and configuration
        
    .PARAMETER Configuration
        Configuration hashtable containing Gemini settings
        
    .PARAMETER ApiKey
        Google API key for Gemini access
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{},
        [string]$ApiKey = $env:GOOGLE_API_KEY
    )
    
    Write-GeminiLog "Initializing Gemini integration" -Level Information
    
    try {
        if (-not $ApiKey) {
            $ApiKey = $env:GOOGLE_API_KEY
            if (-not $ApiKey) {
                throw "Google API key not found. Set GOOGLE_API_KEY environment variable."
            }
        }
        
        $script:ApiKey = $ApiKey
        $script:GeminiConfig = $Configuration
        
        # Test connection
        $testResult = Test-GeminiConnection
        if (-not $testResult) {
            throw "Failed to connect to Gemini API"
        }
        
        Write-GeminiLog "Gemini integration initialized successfully" -Level Information
        return $true
    }
    catch {
        Write-GeminiLog "Failed to initialize Gemini integration: $_" -Level Error
        return $false
    }
}

function Test-GeminiConnection {
    <#
    .SYNOPSIS
        Test connection to Gemini API
        
    .DESCRIPTION
        Validates API key and connection to Google's Gemini service
    #>
    [CmdletBinding()]
    param()
    
    try {
        $uri = "$script:BaseUrl/models?key=$script:ApiKey"
        $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        
        Write-GeminiLog "Connection to Gemini API successful" -Level Information
        return $true
    }
    catch {
        Write-GeminiLog "Failed to connect to Gemini API: $_" -Level Error
        return $false
    }
}

function Invoke-GeminiChat {
    <#
    .SYNOPSIS
        Send a chat request to Gemini
        
    .DESCRIPTION
        Sends a message to Gemini and returns the AI response
        
    .PARAMETER Message
        The message/prompt to send to Gemini
        
    .PARAMETER SystemContext
        System context or role definition for the conversation
        
    .PARAMETER MaxTokens
        Maximum tokens to generate in the response
        
    .PARAMETER Temperature
        Controls randomness in the response (0.0 to 1.0)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$SystemContext = "You are an expert PowerShell developer working with the AitherZero infrastructure automation platform.",
        
        [int]$MaxTokens = 2048,
        
        [decimal]$Temperature = 0.9
    )
    
    Write-GeminiLog "Sending chat request to Gemini" -Level Information
    
    try {
        # Rate limiting check
        if (-not (Test-RateLimit)) {
            throw "Rate limit exceeded. Please wait before making another request."
        }
        
        $uri = "$script:BaseUrl/models/gemini-pro:generateContent?key=$script:ApiKey"
        
        $requestBody = @{
            contents = @(
                @{
                    parts = @(
                        @{
                            text = "$SystemContext`n`n$Message"
                        }
                    )
                }
            )
            generationConfig = @{
                temperature = [float]$Temperature
                maxOutputTokens = $MaxTokens
                topP = 0.8
                topK = 10
            }
            safetySettings = @(
                @{
                    category = "HARM_CATEGORY_HARASSMENT"
                    threshold = "BLOCK_MEDIUM_AND_ABOVE"
                },
                @{
                    category = "HARM_CATEGORY_HATE_SPEECH" 
                    threshold = "BLOCK_MEDIUM_AND_ABOVE"
                },
                @{
                    category = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
                    threshold = "BLOCK_MEDIUM_AND_ABOVE"
                },
                @{
                    category = "HARM_CATEGORY_DANGEROUS_CONTENT"
                    threshold = "BLOCK_MEDIUM_AND_ABOVE"
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $headers = @{
            'Content-Type' = 'application/json'
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $requestBody -ErrorAction Stop
        
        # Update rate limiter
        Update-RateLimit -TokensUsed ($Message.Length + ($response.candidates[0].content.parts[0].text.Length))
        
        Write-GeminiLog "Received response from Gemini" -Level Information
        
        return @{
            Success = $true
            Response = $response.candidates[0].content.parts[0].text
            Usage = @{
                PromptTokens = $Message.Length
                CompletionTokens = $response.candidates[0].content.parts[0].text.Length
                TotalTokens = $Message.Length + $response.candidates[0].content.parts[0].text.Length
            }
            Model = "gemini-pro"
        }
    }
    catch {
        Write-GeminiLog "Failed to get response from Gemini: $_" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
            Response = $null
        }
    }
}

function Invoke-GeminiCodeOptimization {
    <#
    .SYNOPSIS
        Optimize PowerShell code using Gemini
        
    .DESCRIPTION
        Sends PowerShell code to Gemini for optimization suggestions and improvements
        
    .PARAMETER Code
        The PowerShell code to optimize
        
    .PARAMETER OptimizationTarget
        Focus area for optimization (Speed, Memory, Readability, Security)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        
        [ValidateSet('Speed', 'Memory', 'Readability', 'Security', 'All')]
        [string]$OptimizationTarget = 'All'
    )
    
    $systemContext = @"
You are an expert PowerShell developer specializing in the AitherZero infrastructure automation platform. 

Analyze the provided PowerShell code and provide optimization suggestions focused on: $OptimizationTarget

Consider these AitherZero patterns:
- Use Write-CustomLog instead of Write-Host
- Implement [CmdletBinding()] for advanced functions
- Check platform variables (\$IsWindows, \$IsLinux, \$IsMacOS) for cross-platform compatibility
- Use hierarchical configuration loading patterns
- Implement proper error handling with try/catch blocks
- Follow PowerShell approved verbs and naming conventions
- Support -WhatIf and -Confirm for state-changing functions

Provide:
1. Optimized code with improvements
2. Explanation of changes made
3. Performance impact analysis
4. Security considerations if applicable

Format your response as:
## Optimized Code
[optimized code here]

## Changes Made
[explanation of improvements]

## Performance Impact
[analysis of performance improvements]

## Additional Recommendations
[any other suggestions]
"@
    
    $prompt = @"
Please optimize this PowerShell code for the AitherZero platform:

```powershell
$Code
```

Focus on: $OptimizationTarget optimization
"@
    
    return Invoke-GeminiChat -Message $prompt -SystemContext $systemContext -MaxTokens 4000 -Temperature 0.3
}

function Invoke-GeminiCodeGeneration {
    <#
    .SYNOPSIS
        Generate PowerShell code using Gemini
        
    .DESCRIPTION
        Uses Gemini to generate PowerShell code based on requirements
        
    .PARAMETER Requirements
        Description of the code to generate
        
    .PARAMETER ModuleType
        Type of module (Domain, Script, Function, Class)
        
    .PARAMETER IncludeTests
        Whether to include Pester tests in the generation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Requirements,
        
        [ValidateSet('Domain', 'Script', 'Function', 'Class', 'Configuration')]
        [string]$ModuleType = 'Function',
        
        [switch]$IncludeTests
    )
    
    $systemContext = @"
You are an expert PowerShell developer specializing in the AitherZero infrastructure automation platform.

Generate high-quality PowerShell code following AitherZero conventions:

ARCHITECTURE PATTERNS:
- Domain modules in /domains/ directory
- Number-based scripts (0000-9999) in /automation-scripts/
- Hierarchical configuration loading from config.psd1
- Cross-platform compatibility (Windows, Linux, macOS)

CODING STANDARDS:
- PowerShell 7+ compatibility
- [CmdletBinding()] for advanced functions
- Comment-based help (.SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE)
- Write-CustomLog for logging (not Write-Host)
- Platform checks: \$IsWindows, \$IsLinux, \$IsMacOS
- Proper error handling with try/catch
- Export-ModuleMember for module exports
- Approved PowerShell verbs (Get-Verb)
- Support -WhatIf and -Confirm for state-changing functions

MODULE STRUCTURE:
- Header with #requires -version 7
- Proper module imports
- Script variables for module state
- Helper functions (private)
- Public functions with full documentation
- Export-ModuleMember at the end

TESTING (if requested):
- Pester v5+ syntax
- BeforeAll/AfterAll setup/teardown
- Context blocks for logical grouping
- Mock external dependencies
- Test both success and failure scenarios
"@
    
    $prompt = @"
Generate a PowerShell $ModuleType for the AitherZero platform based on these requirements:

$Requirements

Requirements:
- Follow AitherZero coding standards and patterns
- Include comprehensive comment-based help
- Implement proper error handling
- Support cross-platform execution
- Use appropriate logging with Write-CustomLog
$(if ($IncludeTests) { "- Include comprehensive Pester tests" })

Provide complete, production-ready code with proper structure and documentation.
"@
    
    return Invoke-GeminiChat -Message $prompt -SystemContext $systemContext -MaxTokens 4000 -Temperature 0.4
}

function Test-RateLimit {
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
        Write-GeminiLog "Request rate limit exceeded" -Level Warning
        return $false
    }
    
    if ($script:RateLimiter.TokenCount -ge $script:RateLimiter.TokensPerMinute) {
        Write-GeminiLog "Token rate limit exceeded" -Level Warning
        return $false
    }
    
    return $true
}

function Update-RateLimit {
    <#
    .SYNOPSIS
        Update rate limiting counters
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$TokensUsed = 0
    )
    
    if ($PSCmdlet.ShouldProcess("Rate limiter", "Update counters")) {
        $script:RateLimiter.LastRequest = Get-Date
        $script:RateLimiter.RequestCount++
        $script:RateLimiter.TokenCount += $TokensUsed
    }
}

function Get-GeminiUsage {
    <#
    .SYNOPSIS
        Get current usage statistics for Gemini API
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
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-GeminiIntegration',
    'Test-GeminiConnection',
    'Invoke-GeminiChat',
    'Invoke-GeminiCodeOptimization',
    'Invoke-GeminiCodeGeneration',
    'Get-GeminiUsage'
)