#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Configures and initializes all AI agent integrations for AitherZero.

.DESCRIPTION
    Sets up API keys, validates connectivity, configures rate limiting, and initializes
    the AI workflow orchestrator with available agents.

.PARAMETER Provider
    The AI provider to configure (Claude, Gemini, Codex, All)

.PARAMETER ValidateOnly
    Only validate existing configuration without making changes

.PARAMETER ConfigPath
    Path to AI configuration file

.EXAMPLE
    ./0730_Setup-AIAgents.ps1 -Provider All
    
.EXAMPLE
    ./0730_Setup-AIAgents.ps1 -Provider Claude -ValidateOnly
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Claude', 'Gemini', 'Codex', 'All')]
    [string]$Provider = 'All',
    
    [switch]$ValidateOnly,
    
    [string]$ConfigPath = "$PSScriptRoot/../config.psd1"
)

#region Metadata
$script:Stage = "AIAutomation"
$script:Dependencies = @('0001', '0400')
$script:Tags = @('ai', 'automation', 'devops', 'setup')
$script:Condition = '$true'  # Always available for setup
$script:Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
#endregion

#region Module Imports
$projectRoot = Split-Path $PSScriptRoot -Parent
$modulePaths = @(
    "$projectRoot/domains/development/DevTools.psm1"
    "$projectRoot/domains/ai-agents/AIWorkflowOrchestrator.psm1"
    "$projectRoot/domains/core/Logging.psm1"
    "$projectRoot/domains/configuration/Configuration.psm1"
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}
#endregion

#region Helper Functions
function Get-AIConfig {
    param([string]$ConfigPath)
    
    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            return $config.AI
        } else {
            Write-Warning "Config file not found at $ConfigPath"
            return $null
        }
    } catch {
        Write-Error "Failed to load config: $_"
        return $null
    }
}

function Write-AILog {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "AI-Setup"
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Debug' { 'Gray' }
            default { 'White' }
        }
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Test-APIKey {
    param(
        [string]$Provider,
        [string]$ApiKey
    )
    
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        return $false
    }
    
    # Basic validation - check key format
    switch ($Provider) {
        'Claude' {
            return $ApiKey -match '^sk-ant-'
        }
        'Gemini' {
            return $ApiKey.Length -ge 39
        }
        'Codex' {
            return $ApiKey -match '^sk-'
        }
        default { return $false }
    }
}

function Test-AIConnectivity {
    param(
        [string]$Provider,
        [string]$ApiKey,
        [hashtable]$ProviderConfig
    )
    
    try {
        switch ($Provider) {
            'Claude' {
                $uri = "$($ProviderConfig.BaseUrl)/messages"
                $headers = @{
                    'x-api-key' = $ApiKey
                    'anthropic-version' = $ProviderConfig.Version
                    'content-type' = 'application/json'
                }
                $body = @{
                    model = $ProviderConfig.Model
                    max_tokens = 10
                    messages = @(@{role = "user"; content = "test"})
                } | ConvertTo-Json
                
                $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ErrorAction Stop
                return $true
            }
            'Gemini' {
                $uri = "$($ProviderConfig.BaseUrl)/models?key=$ApiKey"
                $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
                return $true
            }
            'Codex' {
                $uri = "$($ProviderConfig.BaseUrl)/models"
                $headers = @{
                    'Authorization' = "Bearer $ApiKey"
                }
                $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
                return $true
            }
            default { return $false }
        }
    } catch {
        Write-AILog "Connectivity test failed for $Provider : $_" -Level Error
        return $false
    }
}

function Set-SecureAPIKey {
    param(
        [string]$Provider,
        [string]$ApiKey
    )
    
    try {
        # Use SecureCredentials module if available
        if (Get-Command New-SecureCredential -ErrorAction SilentlyContinue) {
            $credential = New-SecureCredential -Name "AI_$Provider" -Value $ApiKey
            return $true
        } else {
            # Fallback to environment variable
            $envVar = switch ($Provider) {
                'Claude' { 'ANTHROPIC_API_KEY' }
                'Gemini' { 'GOOGLE_API_KEY' }
                'Codex' { 'OPENAI_API_KEY' }
            }
            if ($PSCmdlet.ShouldProcess("User environment variable '$envVar'", "Set API key")) {
                [Environment]::SetEnvironmentVariable($envVar, $ApiKey, [EnvironmentVariableTarget]::User)
            }
            return $true
        }
    } catch {
        Write-AILog "Failed to store API key for $Provider : $_" -Level Error
        return $false
    }
}

function Initialize-RateLimiting {
    param(
        [string]$Provider,
        [hashtable]$ProviderConfig
    )
    
    $rateLimits = $ProviderConfig.RateLimits
    
    if (-not $rateLimits) {
        Write-AILog "No rate limits configured for $Provider" -Level Warning
        return $false
    }
    
    # Store rate limiting configuration
    $configPath = "$projectRoot/config/ai-rate-limits.json"
    $configDir = Split-Path $configPath -Parent
    if (-not (Test-Path $configDir)) {
        if ($PSCmdlet.ShouldProcess($configDir, "Create directory")) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
    }
    
    if (Test-Path $configPath) {
        if ($PSCmdlet.ShouldProcess($configPath, "Update rate limits configuration")) {
            $existingConfig = Import-PowerShellDataFile $configPath -AsHashtable
            $existingConfig[$Provider] = $rateLimits
            $existingConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath
        }
    } else {
        if ($PSCmdlet.ShouldProcess($configPath, "Create rate limits configuration")) {
            @{$Provider = $rateLimits} | ConvertTo-Json -Depth 10 | Set-Content $configPath
        }
    }
    
    Write-AILog "Rate limiting configured for $Provider" -Level Information
    return $true
}

function Initialize-UsageTracking {
    param([string]$Provider)
    
    $trackingPath = "$projectRoot/logs/ai-usage.json"
    $trackingDir = Split-Path $trackingPath -Parent
    
    if (-not (Test-Path $trackingDir)) {
        if ($PSCmdlet.ShouldProcess($trackingDir, "Create directory")) {
            New-Item -ItemType Directory -Path $trackingDir -Force | Out-Null
        }
    }
    
    $tracking = @{
        Provider = $Provider
        Initialized = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Usage = @{
            TotalRequests = 0
            TotalTokens = 0
            TotalCost = 0
            LastReset = Get-Date -Format "yyyy-MM-dd"
        }
    }
    
    if (Test-Path $trackingPath) {
        if ($PSCmdlet.ShouldProcess($trackingPath, "Update usage tracking configuration")) {
            $existingTracking = Get-Content $trackingPath -Raw | ConvertFrom-Json -AsHashtable
            $existingTracking[$Provider] = $tracking
            $existingTracking | ConvertTo-Json -Depth 10 | Set-Content $trackingPath
        }
    } else {
        if ($PSCmdlet.ShouldProcess($trackingPath, "Create usage tracking configuration")) {
            @{$Provider = $tracking} | ConvertTo-Json -Depth 10 | Set-Content $trackingPath
        }
    }
    
    Write-AILog "Usage tracking initialized for $Provider" -Level Information
    return $true
}

function Set-FallbackChain {
    param(
        [string[]]$Providers,
        [hashtable]$FallbackConfig
    )
    
    $fallbackSettings = @{
        Primary = $Providers[0]
        Fallback = $Providers[1..$($Providers.Length - 1)]
        Strategy = $FallbackConfig.Strategy ?? 'Sequential'
        RetryCount = $FallbackConfig.RetryCount ?? 3
        RetryDelay = $FallbackConfig.RetryDelay ?? 2
    }
    
    $configPath = "$projectRoot/config/ai-fallback.json"
    if ($PSCmdlet.ShouldProcess($configPath, "Create fallback chain configuration")) {
        $fallbackSettings | ConvertTo-Json -Depth 10 | Set-Content $configPath
    }
    
    Write-AILog "Fallback chain configured: $($Providers -join ' -> ')" -Level Information
    return $true
}
#endregion

#region Main Execution
function Main {
    Write-AILog "Starting AI Agent Setup (Platform: $script:Platform)" -Level Information
    
    # Load configuration
    $aiConfig = Get-AIConfig -ConfigPath $ConfigPath
    if (-not $aiConfig) {
        Write-AILog "Failed to load AI configuration from $ConfigPath" -Level Error
        exit 1
    }
    
    if (-not $aiConfig.Enabled) {
        Write-AILog "AI features are disabled in configuration" -Level Warning
        exit 0
    }
    
    $providers = if ($Provider -eq 'All') {
        $aiConfig.Providers.PSObject.Properties.Name | Where-Object { $aiConfig.Providers.$_.Enabled }
    } else {
        @($Provider)
    }
    
    $results = @{}
    $availableProviders = @()
    
    foreach ($p in $providers) {
        $providerConfig = $aiConfig.Providers.$p
        
        if (-not $providerConfig -or -not $providerConfig.Enabled) {
            Write-AILog "$p is not enabled in configuration" -Level Warning
            continue
        }
        
        Write-AILog "Configuring $p ..." -Level Information
        
        # Check for API key
        $envVar = $providerConfig.ApiKeyEnvVar
        $apiKey = [Environment]::GetEnvironmentVariable($envVar)
        
        if (-not $apiKey -and -not $ValidateOnly) {
            Write-AILog "API key not found for $p. Please enter it now (or press Enter to skip):" -Level Warning
            $secureKey = Read-Host -AsSecureString
            if ($secureKey.Length -gt 0) {
                $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
                )
            }
        }
        
        if ($apiKey) {
            # Validate API key format
            if (Test-APIKey -Provider $p -ApiKey $apiKey) {
                Write-AILog "API key format valid for $p" -Level Information
                
                # Test connectivity
                if (Test-AIConnectivity -Provider $p -ApiKey $apiKey -ProviderConfig $providerConfig) {
                    Write-AILog "✓ Connectivity verified for $p" -Level Information
                    $availableProviders += $p
                    
                    if (-not $ValidateOnly) {
                        # Store API key securely
                        Set-SecureAPIKey -Provider $p -ApiKey $apiKey
                        
                        # Configure rate limiting
                        Initialize-RateLimiting -Provider $p -ProviderConfig $providerConfig
                        
                        # Initialize usage tracking
                        Initialize-UsageTracking -Provider $p
                    }
                    
                    $results[$p] = @{
                        Status = 'Success'
                        Connected = $true
                        RateLimitConfigured = $true
                        UsageTrackingEnabled = $true
                    }
                } else {
                    Write-AILog "✗ Connectivity test failed for $p" -Level Error
                    $results[$p] = @{
                        Status = 'Failed'
                        Connected = $false
                        Error = 'Connectivity test failed'
                    }
                }
            } else {
                Write-AILog "✗ Invalid API key format for $p" -Level Error
                $results[$p] = @{
                    Status = 'Failed'
                    Connected = $false
                    Error = 'Invalid API key format'
                }
            }
        } else {
            Write-AILog "⚠ Skipping $p (no API key)" -Level Warning
            $results[$p] = @{
                Status = 'Skipped'
                Connected = $false
                Error = 'No API key provided'
            }
        }
    }
    
    # Configure fallback chain if multiple providers available
    if ($availableProviders.Count -gt 1 -and -not $ValidateOnly -and $aiConfig.Fallback.Enabled) {
        # Sort providers by priority
        $sortedProviders = $availableProviders | Sort-Object { $aiConfig.Providers.$_.Priority }
        Set-FallbackChain -Providers $sortedProviders -FallbackConfig $aiConfig.Fallback
    }
    
    # Initialize AIWorkflowOrchestrator with available agents
    if ($availableProviders.Count -gt 0 -and -not $ValidateOnly) {
        if (Get-Command Initialize-AIWorkflowOrchestrator -ErrorAction SilentlyContinue) {
            $orchestratorConfig = @{
                AvailableProviders = $availableProviders
                PrimaryProvider = $availableProviders[0]
                EnableFallback = $availableProviders.Count -gt 1
                EnableUsageTracking = $true
                EnableRateLimiting = $true
            }
            
            Initialize-AIWorkflowOrchestrator @orchestratorConfig
            Write-AILog "AI Workflow Orchestrator initialized with $($availableProviders.Count) provider(s)" -Level Information
        }
    }
    
    # Display summary
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "           AI Agent Setup Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    
    foreach ($p in $results.Keys) {
        $result = $results[$p]
        $statusColor = switch ($result.Status) {
            'Success' { 'Green' }
            'Failed' { 'Red' }
            'Skipped' { 'Yellow' }
        }
        
        Write-Host "`n$p :" -NoNewline
        Write-Host " $($result.Status)" -ForegroundColor $statusColor
        
        if ($result.Status -eq 'Success') {
            Write-Host "  ✓ Connected" -ForegroundColor Green
            Write-Host "  ✓ Rate limiting configured" -ForegroundColor Green
            Write-Host "  ✓ Usage tracking enabled" -ForegroundColor Green
        } elseif ($result.Error) {
            Write-Host "  ✗ $($result.Error)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n═══════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($availableProviders.Count -gt 0) {
        Write-Host "`n✓ Setup complete. Available providers: $($availableProviders -join ', ')" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n✗ No AI providers configured successfully" -ForegroundColor Red
        exit 1
    }
}

# Execute main function
Main
#endregion
