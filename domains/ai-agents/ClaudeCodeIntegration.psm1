#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Claude Code Integration Module
.DESCRIPTION
    Provides integration with Claude Code CLI and API for AI-assisted development workflows
.NOTES
    This module enables direct integration with Claude Code for automated AI assistance
#>

# Module variables
$script:ClaudeCodePath = $null
$script:ClaudeCodeConfig = $null
$script:APIEndpoint = "https://api.anthropic.com/v1"
$script:SessionContext = @{}

# Import required modules
if (Test-Path "$PSScriptRoot/../utilities/Logging.psm1") {
    Import-Module "$PSScriptRoot/../utilities/Logging.psm1" -Force
}

function Write-ClaudeLog {
    <#
    .SYNOPSIS
        Write log entry for Claude Code operations
    #>
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "ClaudeCodeIntegration"
    } else {
        Write-Host "[$Level] Claude: $Message"
    }
}

function Initialize-ClaudeCodeIntegration {
    <#
    .SYNOPSIS
        Initialize Claude Code integration
    .DESCRIPTION
        Sets up Claude Code CLI and API integration with proper authentication
    .PARAMETER ConfigPath
        Path to Claude Code configuration file
    .PARAMETER APIKey
        Anthropic API key for direct API access
    .PARAMETER CLIPath
        Path to Claude Code CLI executable
    .EXAMPLE
        Initialize-ClaudeCodeIntegration -ConfigPath "~/.claude/config.psd1"
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "~/.claude/settings.json",
        [string]$APIKey,
        [string]$CLIPath
    )
    
    Write-ClaudeLog "Initializing Claude Code integration" -Level Information
    
    try {
        # Auto-detect Claude Code CLI
        if (-not $CLIPath) {
            $CLIPath = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
            if (-not $CLIPath) {
                Write-ClaudeLog "Claude Code CLI not found in PATH" -Level Warning
            }
        }
        
        $script:ClaudeCodePath = $CLIPath
        
        # Load configuration
        $configPathExpanded = [Environment]::ExpandEnvironmentVariables($ConfigPath)
        if (Test-Path $configPathExpanded) {
            $script:ClaudeCodeConfig = Import-PowerShellDataFile $configPathExpanded
            Write-ClaudeLog "Configuration loaded from: $configPathExpanded" -Level Success
        } else {
            Write-ClaudeLog "Configuration not found: $configPathExpanded" -Level Warning
            $script:ClaudeCodeConfig = @{
                project = @{
                    name = "AitherZero"
                    type = "infrastructure-automation"
                }
            }
        }
        
        # Set up API key
        if ($APIKey) {
            $env:ANTHROPIC_API_KEY = $APIKey
            Write-ClaudeLog "API key configured for direct API access" -Level Information
        } elseif ($env:ANTHROPIC_API_KEY) {
            Write-ClaudeLog "Using API key from environment variable" -Level Information
        } else {
            Write-ClaudeLog "No API key configured - CLI-only mode" -Level Warning
        }
        
        # Initialize session context
        $script:SessionContext = @{
            ProjectRoot = $env:CLAUDE_PROJECT_DIR ?? (Get-Location).Path
            InitializedAt = Get-Date
            Configuration = $script:ClaudeCodeConfig
        }
        
        Write-ClaudeLog "Claude Code integration initialized successfully" -Level Success
        return $true
        
    } catch {
        Write-ClaudeLog "Failed to initialize Claude Code integration: $_" -Level Error
        return $false
    }
}

function Invoke-ClaudeCodeCLI {
    <#
    .SYNOPSIS
        Execute Claude Code CLI command
    .DESCRIPTION
        Executes Claude Code CLI with proper error handling and logging
    .PARAMETER Command
        CLI command to execute
    .PARAMETER Arguments
        Arguments for the CLI command
    .PARAMETER WorkingDirectory
        Working directory for command execution
    .EXAMPLE
        Invoke-ClaudeCodeCLI -Command "ask" -Arguments @("Explain this code", "--file", "script.ps1")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $script:SessionContext.ProjectRoot
    )
    
    if (-not $script:ClaudeCodePath) {
        Write-ClaudeLog "Claude Code CLI not available" -Level Error
        throw "Claude Code CLI not initialized"
    }
    
    Write-ClaudeLog "Executing CLI command: $Command $($Arguments -join ' ')" -Level Information
    
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $script:ClaudeCodePath
        $startInfo.Arguments = "$Command $($Arguments -join ' ')"
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        
        $stdout = New-Object System.Text.StringBuilder
        $stderr = New-Object System.Text.StringBuilder
        
        $process.add_OutputDataReceived({
            if ($_.Data) { [void]$stdout.AppendLine($_.Data) }
        })
        $process.add_ErrorDataReceived({
            if ($_.Data) { [void]$stderr.AppendLine($_.Data) }
        })
        
        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        if (-not $process.WaitForExit(30000)) {  # 30 second timeout
            $process.Kill()
            throw "CLI command timed out"
        }
        
        $result = @{
            ExitCode = $process.ExitCode
            Output = $stdout.ToString().Trim()
            Error = $stderr.ToString().Trim()
            Success = $process.ExitCode -eq 0
        }
        
        if ($result.Success) {
            Write-ClaudeLog "CLI command completed successfully" -Level Success
        } else {
            Write-ClaudeLog "CLI command failed with exit code: $($result.ExitCode)" -Level Error
            if ($result.Error) {
                Write-ClaudeLog "CLI error: $($result.Error)" -Level Error
            }
        }
        
        return $result
        
    } catch {
        Write-ClaudeLog "CLI execution failed: $_" -Level Error
        throw
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill()
        }
        $process?.Dispose()
    }
}

function Invoke-ClaudeCodeAPI {
    <#
    .SYNOPSIS
        Make direct API call to Claude
    .DESCRIPTION
        Makes direct API calls to Anthropic's Claude API with proper authentication
    .PARAMETER Endpoint
        API endpoint to call
    .PARAMETER Method
        HTTP method (GET, POST, etc.)
    .PARAMETER Body
        Request body as hashtable
    .PARAMETER Headers
        Additional headers
    .EXAMPLE
        Invoke-ClaudeCodeAPI -Endpoint "messages" -Method "POST" -Body @{
            model = "claude-3-sonnet-20240229"
            messages = @(@{ role = "user"; content = "Hello" })
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        [string]$Method = "POST",
        [hashtable]$Body = @{},
        [hashtable]$Headers = @{}
    )
    
    if (-not $env:ANTHROPIC_API_KEY) {
        Write-ClaudeLog "Anthropic API key not available" -Level Error
        throw "API key not configured"
    }
    
    Write-ClaudeLog "Making API call to: $Endpoint" -Level Information
    
    try {
        $uri = "$script:APIEndpoint/$Endpoint"
        
        $defaultHeaders = @{
            "Content-Type" = "application/json"
            "x-api-key" = $env:ANTHROPIC_API_KEY
            "anthropic-version" = "2023-06-01"
        }
        
        $allHeaders = $defaultHeaders + $Headers
        
        $requestParams = @{
            Uri = $uri
            Method = $Method
            Headers = $allHeaders
            UseBasicParsing = $true
        }
        
        if ($Body.Count -gt 0 -and $Method -in @("POST", "PUT", "PATCH")) {
            $requestParams.Body = $Body | ConvertTo-Json -Depth 10
        }
        
        $response = Invoke-RestMethod @requestParams
        
        Write-ClaudeLog "API call completed successfully" -Level Success
        return $response
        
    } catch {
        Write-ClaudeLog "API call failed: $_" -Level Error
        throw
    }
}

function Send-ClaudeMessage {
    <#
    .SYNOPSIS
        Send message to Claude using best available method
    .DESCRIPTION
        Sends a message to Claude using either CLI or API, with automatic fallback
    .PARAMETER Message
        Message to send to Claude
    .PARAMETER SystemPrompt
        System prompt to provide context
    .PARAMETER Model
        Claude model to use (for API calls)
    .PARAMETER MaxTokens
        Maximum tokens for response
    .PARAMETER UseAPI
        Force API usage instead of CLI
    .EXAMPLE
        Send-ClaudeMessage -Message "Explain this PowerShell function" -SystemPrompt "You are a PowerShell expert"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$SystemPrompt,
        [string]$Model = "claude-3-sonnet-20240229",
        [int]$MaxTokens = 4096,
        [switch]$UseAPI
    )
    
    Write-ClaudeLog "Sending message to Claude (length: $($Message.Length))" -Level Information
    
    try {
        if ($UseAPI -or (-not $script:ClaudeCodePath -and $env:ANTHROPIC_API_KEY)) {
            # Use API
            Write-ClaudeLog "Using Claude API" -Level Information
            
            $messages = @(
                @{
                    role = "user"
                    content = $Message
                }
            )
            
            $requestBody = @{
                model = $Model
                max_tokens = $MaxTokens
                messages = $messages
            }
            
            if ($SystemPrompt) {
                $requestBody.system = $SystemPrompt
            }
            
            $response = Invoke-ClaudeCodeAPI -Endpoint "messages" -Body $requestBody
            
            return @{
                Content = $response.content[0].text
                Model = $response.model
                Usage = $response.usage
                Success = $true
            }
            
        } elseif ($script:ClaudeCodePath) {
            # Use CLI
            Write-ClaudeLog "Using Claude Code CLI" -Level Information
            
            $arguments = @("ask", $Message)
            if ($SystemPrompt) {
                $arguments += @("--system", $SystemPrompt)
            }
            
            $result = Invoke-ClaudeCodeCLI -Command "" -Arguments $arguments
            
            return @{
                Content = $result.Output
                Success = $result.Success
                Error = $result.Error
            }
            
        } else {
            throw "No Claude Code integration available (neither CLI nor API)"
        }
        
    } catch {
        Write-ClaudeLog "Failed to send message to Claude: $_" -Level Error
        throw
    }
}

function Get-ClaudeCodeAnalysis {
    <#
    .SYNOPSIS
        Get AI analysis of code or text
    .DESCRIPTION
        Uses Claude to analyze code, files, or text content with specific prompts
    .PARAMETER Content
        Content to analyze
    .PARAMETER FilePath
        Path to file to analyze
    .PARAMETER AnalysisType
        Type of analysis to perform
    .PARAMETER IncludeContext
        Include project context in analysis
    .EXAMPLE
        Get-ClaudeCodeAnalysis -FilePath "script.ps1" -AnalysisType "security"
    #>
    [CmdletBinding()]
    param(
        [string]$Content,
        [string]$FilePath,
        [ValidateSet("security", "performance", "quality", "documentation", "testing", "refactoring")]
        [string]$AnalysisType = "quality",
        [switch]$IncludeContext
    )
    
    Write-ClaudeLog "Performing $AnalysisType analysis" -Level Information
    
    try {
        # Get content to analyze
        if ($FilePath -and (Test-Path $FilePath)) {
            $Content = Get-Content $FilePath -Raw
            Write-ClaudeLog "Analyzing file: $FilePath" -Level Information
        }
        
        if (-not $Content) {
            throw "No content provided for analysis"
        }
        
        # Build analysis prompt based on type
        $prompts = @{
            security = @"
Analyze this PowerShell code for security vulnerabilities and issues:

1. Credential handling and secrets exposure
2. Input validation and sanitization
3. Execution safety and injection risks
4. Permission and privilege escalation
5. Network security considerations

Provide specific recommendations for improvement.
"@
            performance = @"
Analyze this PowerShell code for performance optimization opportunities:

1. Execution efficiency and bottlenecks
2. Memory usage patterns
3. Loop and iteration optimizations
4. Pipeline usage improvements
5. Caching and memoization opportunities

Suggest specific performance improvements.
"@
            quality = @"
Analyze this PowerShell code for quality and maintainability:

1. Code structure and organization
2. Naming conventions and clarity
3. Error handling completeness
4. PowerShell best practices adherence
5. Modularity and reusability

Provide improvement recommendations.
"@
            documentation = @"
Analyze this PowerShell code for documentation completeness:

1. Comment-based help completeness
2. Parameter descriptions and examples
3. Function purpose and usage clarity
4. Code comment quality
5. README and usage documentation needs

Suggest documentation improvements.
"@
            testing = @"
Analyze this PowerShell code and suggest comprehensive testing approach:

1. Unit test scenarios and edge cases
2. Mocking requirements and strategies
3. Integration test considerations
4. Performance test needs
5. Error condition testing

Provide Pester test examples where applicable.
"@
            refactoring = @"
Analyze this PowerShell code for refactoring opportunities:

1. Code duplication elimination
2. Function extraction possibilities
3. Complexity reduction strategies
4. Design pattern applications
5. Modularity improvements

Suggest specific refactoring steps.
"@
        }
        
        $systemPrompt = @"
You are an expert PowerShell developer and DevOps engineer working with the AitherZero infrastructure automation platform. 

Context:
- This is part of a comprehensive PowerShell-based automation system
- The platform uses domain-driven architecture with numbered automation scripts
- Cross-platform compatibility (Windows, Linux, macOS) is important
- Security and reliability are critical requirements

Focus on practical, actionable advice that fits the AitherZero architecture and patterns.
"@
        
        if ($IncludeContext -and $script:SessionContext.ProjectRoot) {
            # Add project context
            $contextInfo = @()
            
            # Recent files
            try {
                $recentFiles = Get-ChildItem $script:SessionContext.ProjectRoot -Recurse -Filter "*.ps1" |
                              Sort-Object LastWriteTime -Descending |
                              Select-Object -First 5 |
                              ForEach-Object { $_.FullName.Replace($script:SessionContext.ProjectRoot, ".") }
                if ($recentFiles) {
                    $contextInfo += "Recent PowerShell files: $($recentFiles -join ', ')"
                }
            } catch {
                # Ignore context gathering errors
            }
            
            if ($contextInfo.Count -gt 0) {
                $systemPrompt += "`n`nProject Context: $($contextInfo -join '; ')"
            }
        }
        
        $analysisPrompt = $prompts[$AnalysisType]
        $fullMessage = "$analysisPrompt`n`nCode to analyze:`n```powershell`n$Content`n```"
        
        $response = Send-ClaudeMessage -Message $fullMessage -SystemPrompt $systemPrompt
        
        if ($response.Success) {
            Write-ClaudeLog "$($AnalysisType) analysis completed successfully" -Level Success
            return @{
                Analysis = $response.Content
                AnalysisType = $AnalysisType
                FilePath = $FilePath
                Success = $true
                Timestamp = Get-Date
            }
        } else {
            throw "Analysis failed: $($response.Error)"
        }
        
    } catch {
        Write-ClaudeLog "$AnalysisType analysis failed: $_" -Level Error
        throw
    }
}

function Get-ClaudeCodeSuggestions {
    <#
    .SYNOPSIS
        Get AI suggestions for development tasks
    .DESCRIPTION
        Gets Claude's suggestions for implementation, problem-solving, or optimization
    .PARAMETER Task
        Description of the development task
    .PARAMETER Context
        Additional context about the task
    .PARAMETER ProjectType
        Type of project for better suggestions
    .EXAMPLE
        Get-ClaudeCodeSuggestions -Task "Implement retry logic for API calls" -ProjectType "infrastructure"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Task,
        [string]$Context,
        [string]$ProjectType = "infrastructure-automation"
    )
    
    Write-ClaudeLog "Getting suggestions for task: $Task" -Level Information
    
    try {
        $systemPrompt = @'
You are an expert software architect and PowerShell developer working with AitherZero, a comprehensive infrastructure automation platform.

Project characteristics:
- PowerShell-based automation scripts (0000-9999 numbering)
- Domain-driven architecture with modular design
- Cross-platform compatibility (Windows, Linux, macOS)
- Orchestration and workflow automation
- Testing with Pester, validation with PSScriptAnalyzer
- GitHub Actions CI/CD integration
- Security and compliance focus

Provide practical, implementable suggestions that fit the AitherZero patterns and architecture.
'@
        
        $contextLine = if ($Context) { "Additional Context: $Context`n" } else { "" }
        $message = @"
Development Task: $Task

$($contextLine)Please provide:

1. **Implementation Approach**: Recommended strategy and methodology
2. **Code Structure**: How to organize the code within AitherZero's architecture
3. **Key Considerations**: Important factors to consider (security, performance, maintainability)
4. **Testing Strategy**: How to test the implementation effectively
5. **Integration Points**: How this connects with existing AitherZero components
6. **Best Practices**: PowerShell and automation-specific recommendations

Format your response with clear sections and actionable advice.
"@
        
        $response = Send-ClaudeMessage -Message $message -SystemPrompt $systemPrompt
        
        if ($response.Success) {
            Write-ClaudeLog "Development suggestions generated successfully" -Level Success
            return @{
                Suggestions = $response.Content
                Task = $Task
                Success = $true
                Timestamp = Get-Date
            }
        } else {
            throw "Failed to get suggestions: $($response.Error)"
        }
        
    } catch {
        Write-ClaudeLog "Failed to get development suggestions: $_" -Level Error
        throw
    }
}

function Start-ClaudeCodeSession {
    <#
    .SYNOPSIS
        Start an interactive Claude Code session
    .DESCRIPTION
        Starts an interactive session with Claude Code, maintaining context
    .PARAMETER InitialPrompt
        Initial prompt to send
    .PARAMETER ProjectContext
        Include project context in session
    .EXAMPLE
        Start-ClaudeCodeSession -InitialPrompt "Help me implement user authentication"
    #>
    [CmdletBinding()]
    param(
        [string]$InitialPrompt,
        [switch]$ProjectContext
    )
    
    Write-ClaudeLog "Starting Claude Code interactive session" -Level Information
    
    try {
        if (-not $script:ClaudeCodePath) {
            Write-ClaudeLog "Interactive sessions require Claude Code CLI" -Level Warning
            throw "Claude Code CLI not available for interactive sessions"
        }
        
        $sessionArgs = @("chat")
        
        if ($ProjectContext -and $script:SessionContext.ProjectRoot) {
            $sessionArgs += @("--project", $script:SessionContext.ProjectRoot)
        }
        
        if ($InitialPrompt) {
            $sessionArgs += @("--initial", $InitialPrompt)
        }
        
        Write-ClaudeLog "Starting interactive session with Claude Code CLI" -Level Information
        
        # Start interactive process
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $script:ClaudeCodePath
        $processInfo.Arguments = $sessionArgs -join " "
        $processInfo.WorkingDirectory = $script:SessionContext.ProjectRoot
        $processInfo.UseShellExecute = $true
        
        [System.Diagnostics.Process]::Start($processInfo)
        
        Write-ClaudeLog "Interactive session started" -Level Success
        
    } catch {
        Write-ClaudeLog "Failed to start interactive session: $_" -Level Error
        throw
    }
}

function Get-ClaudeCodeStatus {
    <#
    .SYNOPSIS
        Get status of Claude Code integration
    .DESCRIPTION
        Returns current status and configuration of Claude Code integration
    .EXAMPLE
        Get-ClaudeCodeStatus
    #>
    [CmdletBinding()]
    param()
    
    return @{
        CLIAvailable = $null -ne $script:ClaudeCodePath
        CLIPath = $script:ClaudeCodePath
        APIAvailable = $null -ne $env:ANTHROPIC_API_KEY
        ConfigLoaded = $null -ne $script:ClaudeCodeConfig
        ProjectRoot = $script:SessionContext.ProjectRoot
        InitializedAt = $script:SessionContext.InitializedAt
        Version = if ($script:ClaudeCodePath) {
            try {
                $versionResult = Invoke-ClaudeCodeCLI -Command "--version"
                $versionResult.Output
            } catch {
                "Unknown"
            }
        } else {
            "Not available"
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ClaudeCodeIntegration',
    'Invoke-ClaudeCodeCLI',
    'Invoke-ClaudeCodeAPI',
    'Send-ClaudeMessage',
    'Get-ClaudeCodeAnalysis', 
    'Get-ClaudeCodeSuggestions',
    'Start-ClaudeCodeSession',
    'Get-ClaudeCodeStatus'
)