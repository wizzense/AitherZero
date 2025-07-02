BeforeDiscovery {
    $script:APIModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/RestAPIServer'
    $script:LauncherPath = Join-Path $PSScriptRoot '../../Start-AitherZero.ps1'
    $script:CoreAppPath = Join-Path $PSScriptRoot '../../aither-core/aither-core.ps1'
    $script:TestAppName = 'API-NonInteractive-Modes'
    
    # Verify key components exist
    if (-not (Test-Path $script:APIModulePath)) {
        throw "RestAPIServer module not found at: $script:APIModulePath"
    }
    
    if (-not (Test-Path $script:LauncherPath)) {
        throw "Launcher not found at: $script:LauncherPath"
    }
    
    if (-not (Test-Path $script:CoreAppPath)) {
        throw "Core application not found at: $script:CoreAppPath"
    }
}

Describe 'API and Non-Interactive Modes - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'API', 'NonInteractive', 'Automation') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'api-noninteractive-tests'
        
        # Save original environment
        $script:OriginalEnv = @{
            PROJECT_ROOT = $env:PROJECT_ROOT
            PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
            LAB_CONSOLE_LEVEL = $env:LAB_CONSOLE_LEVEL
            PESTER_RUN = $env:PESTER_RUN
            APPDATA = $env:APPDATA
            HOME = $env:HOME
            USERPROFILE = $env:USERPROFILE
            HTTP_PROXY = $env:HTTP_PROXY
            HTTPS_PROXY = $env:HTTPS_PROXY
        }
        
        # Create comprehensive test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestScriptsDir = Join-Path $script:TestProjectRoot 'aither-core' 'scripts'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestLogsDir = Join-Path $script:TestProjectRoot 'logs'
        $script:TestAppDataDir = Join-Path $script:TestWorkspace 'AppData' 'Roaming' 'AitherZero'
        $script:TestAPIWorkDir = Join-Path $script:TestWorkspace 'api-workspace'
        
        @($script:TestProjectRoot, $script:TestModulesDir, $script:TestSharedDir, $script:TestScriptsDir,
          $script:TestConfigsDir, $script:TestLogsDir, $script:TestAppDataDir, $script:TestAPIWorkDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:PWSH_MODULES_PATH = $script:TestModulesDir
        $env:APPDATA = (Split-Path $script:TestAppDataDir -Parent)
        $env:HOME = $script:TestWorkspace
        $env:USERPROFILE = $script:TestWorkspace
        $env:PESTER_RUN = 'true'
        
        # Create mock configuration files
        $defaultConfig = @{
            version = "1.0.0"
            UIPreferences = @{
                Mode = "classic"
                DefaultUI = "enhanced"
            }
            automation = @{
                enableAutoMode = $true
                defaultModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
                timeouts = @{
                    scriptExecution = 300
                    moduleLoading = 60
                }
            }
            api = @{
                defaultPort = 8080
                authentication = "ApiKey"
                enableCORS = $true
                enableRateLimit = $true
                enableSSL = $false
            }
        } | ConvertTo-Json -Depth 5
        
        $defaultConfig | Out-File -FilePath (Join-Path $script:TestConfigsDir 'default-config.json') -Encoding UTF8
        
        # Copy and create mock modules for comprehensive testing
        $coreModules = @('RestAPIServer', 'ModuleCommunication', 'Logging', 'SetupWizard', 'SystemMonitoring', 'BackupManager', 'StartupExperience', 'LicenseManager')
        foreach ($module in $coreModules) {
            $modulePath = Join-Path $script:TestModulesDir $module
            New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
            
            # Create comprehensive module manifest
            @"
@{
    ModuleVersion = '2.0.0'
    RootModule = '$module.psm1'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Start-$module', 'Get-$module', 'Test-$module', 'Stop-$module')
    CompatiblePSEditions = @('Core', 'Desktop')
    RequiredModules = @('Logging')
    Description = 'Mock $module module for testing'
}
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psd1") -Encoding UTF8
            
            # Create mock module implementation
            @"
# Mock $module Module for Testing

`$script:ModuleStarted = `$false
`$script:ModuleConfig = @{}
`$script:ModuleMetrics = @{
    StartTime = `$null
    RequestCount = 0
    ErrorCount = 0
}

function Start-$module {
    param(
        [switch]`$Auto,
        [string]`$ConfigFile,
        [hashtable]`$Config,
        [string]`$Profile
    )
    
    `$script:ModuleStarted = `$true
    `$script:ModuleMetrics.StartTime = Get-Date
    `$script:ModuleConfig = if (`$Config) { `$Config } else { @{} }
    
    Write-Host "$module started successfully" -ForegroundColor Green
    
    if (`$Auto) {
        Write-Host "Running $module in automatic mode" -ForegroundColor Cyan
        # Simulate auto operations
        Start-Sleep -Milliseconds 100
    }
    
    return @{
        Success = `$true
        Module = '$module'
        Mode = if (`$Auto) { 'Automatic' } else { 'Interactive' }
        StartTime = `$script:ModuleMetrics.StartTime
        Config = `$script:ModuleConfig
    }
}

function Get-$module {
    param([switch]`$IncludeMetrics)
    
    `$result = @{
        Success = `$true
        Module = '$module'
        IsStarted = `$script:ModuleStarted
        Config = `$script:ModuleConfig
    }
    
    if (`$IncludeMetrics) {
        `$result.Metrics = `$script:ModuleMetrics
    }
    
    return `$result
}

function Test-$module {
    param([string]`$TestType = 'Basic')
    
    `$script:ModuleMetrics.RequestCount++
    
    try {
        switch (`$TestType) {
            'Basic' {
                return @{ Success = `$true; Test = 'Basic'; Module = '$module' }
            }
            'Advanced' {
                # Simulate complex operation
                Start-Sleep -Milliseconds 50
                return @{ Success = `$true; Test = 'Advanced'; Module = '$module'; Duration = 50 }
            }
            'Error' {
                `$script:ModuleMetrics.ErrorCount++
                throw "Simulated error in $module module"
            }
            default {
                return @{ Success = `$true; Test = `$TestType; Module = '$module' }
            }
        }
    } catch {
        `$script:ModuleMetrics.ErrorCount++
        return @{ Success = `$false; Error = `$_.Exception.Message; Module = '$module' }
    }
}

function Stop-$module {
    `$script:ModuleStarted = `$false
    Write-Host "$module stopped" -ForegroundColor Yellow
    return @{ Success = `$true; Module = '$module'; Action = 'Stopped' }
}

Export-ModuleMember -Function Start-$module, Get-$module, Test-$module, Stop-$module
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psm1") -Encoding UTF8
        }
        
        # Create specialized RestAPIServer module with full API functionality
        $restAPIPath = Join-Path $script:TestModulesDir 'RestAPIServer'
        Copy-Item -Path "$script:APIModulePath\*" -Destination $restAPIPath -Recurse -Force -ErrorAction SilentlyContinue
        
        # Create specialized mock for API testing that doesn't require actual HTTP server
        @'
# Mock RestAPIServer Module for Testing

$script:APIConfiguration = @{
    Port = 8080
    Protocol = 'HTTP'
    SSLEnabled = $false
    Authentication = 'ApiKey'
    CorsEnabled = $true
    RateLimiting = $true
    LoggingEnabled = $true
}

$script:RegisteredEndpoints = @{}
$script:APIServer = $null
$script:APIServerJob = $null
$script:APIStartTime = $null
$script:APIMetrics = @{
    RequestCount = 0
    ErrorCount = 0
    UpTime = 0
    LastRequest = $null
}
$script:WebhookSubscriptions = @{}
$script:ProjectRoot = $env:PROJECT_ROOT

function Write-CustomLog {
    param([string]$Message, [string]$Level = "INFO")
    Write-Host "[$Level] $Message"
}

function Start-AitherZeroAPI {
    [CmdletBinding()]
    param(
        [int]$Port = 8080,
        [string]$Protocol = 'HTTP',
        [switch]$EnableSSL,
        [string]$CertificatePath,
        [string]$AuthenticationMethod = 'ApiKey',
        [switch]$EnableCORS = $true,
        [switch]$EnableRateLimit = $true,
        [switch]$BackgroundMode = $true
    )
    
    Write-CustomLog "Starting mock AitherZero REST API server on port $Port" "INFO"
    
    # Update configuration
    $script:APIConfiguration.Port = $Port
    $script:APIConfiguration.Protocol = if ($EnableSSL) { 'HTTPS' } else { $Protocol }
    $script:APIConfiguration.SSLEnabled = $EnableSSL
    $script:APIConfiguration.Authentication = $AuthenticationMethod
    $script:APIConfiguration.CorsEnabled = $EnableCORS
    $script:APIConfiguration.RateLimiting = $EnableRateLimit
    
    # Initialize mock endpoints
    Initialize-DefaultEndpoints
    
    # Mock server startup
    $script:APIServer = @{
        JobId = [System.Guid]::NewGuid().ToString()
        Port = $Port
        Protocol = $script:APIConfiguration.Protocol
        StartTime = Get-Date
        Configuration = $script:APIConfiguration
    }
    
    $script:APIServerJob = [PSCustomObject]@{
        Id = $script:APIServer.JobId
        State = 'Running'
        StartTime = Get-Date
    }
    
    $script:APIStartTime = Get-Date
    
    Write-CustomLog "Mock REST API server started successfully on $($script:APIConfiguration.Protocol) port $Port" "SUCCESS"
    
    return Get-APIStatus
}

function Stop-AitherZeroAPI {
    if ($script:APIServerJob -and $script:APIServerJob.State -eq 'Running') {
        $script:APIServerJob.State = 'Completed'
        $script:APIServer = $null
        Write-CustomLog "Mock API server stopped" "INFO"
        return @{ Success = $true; Message = "API server stopped" }
    } else {
        return @{ Success = $false; Message = "API server was not running" }
    }
}

function Get-APIStatus {
    [CmdletBinding()]
    param(
        [switch]$IncludeMetrics,
        [switch]$IncludeEndpoints,
        [switch]$IncludeConfiguration
    )
    
    $status = @{
        Success = $true
        IsRunning = $false
        Status = "Stopped"
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        Version = "2.0.0-Mock"
    }
    
    if ($script:APIServer -and $script:APIServerJob -and $script:APIServerJob.State -eq 'Running') {
        $status.IsRunning = $true
        $status.Status = "Running"
        
        if ($script:APIStartTime) {
            $uptime = (Get-Date) - $script:APIStartTime
            $status.UpTime = @{
                TotalSeconds = [math]::Round($uptime.TotalSeconds, 2)
                TotalMinutes = [math]::Round($uptime.TotalMinutes, 2)
                Display = "{0:dd\.hh\:mm\:ss}" -f $uptime
            }
        }
        
        $status.Server = @{
            JobId = $script:APIServerJob.Id
            Port = $script:APIServer.Port
            Protocol = $script:APIServer.Protocol
            StartTime = $script:APIServer.StartTime
            URL = "$($script:APIServer.Protocol.ToLower())://localhost:$($script:APIServer.Port)"
        }
    }
    
    if ($IncludeMetrics) {
        $status.Metrics = @{
            RequestCount = $script:APIMetrics.RequestCount
            ErrorCount = $script:APIMetrics.ErrorCount
            LastRequest = $script:APIMetrics.LastRequest
            UpTimeSeconds = if ($script:APIStartTime) { ((Get-Date) - $script:APIStartTime).TotalSeconds } else { 0 }
            ErrorRate = if ($script:APIMetrics.RequestCount -gt 0) {
                [math]::Round(($script:APIMetrics.ErrorCount / $script:APIMetrics.RequestCount) * 100, 2)
            } else { 0 }
        }
        
        $status.Health = @{
            Status = if ($status.Metrics.ErrorRate -lt 5) { "Healthy" } else { "Warning" }
        }
    }
    
    if ($IncludeEndpoints) {
        $status.Endpoints = @{
            Count = $script:RegisteredEndpoints.Count
            Registered = $script:RegisteredEndpoints.Keys | Sort-Object
        }
    }
    
    if ($IncludeConfiguration) {
        $status.Configuration = $script:APIConfiguration
        $status.Webhooks = @{
            Enabled = $script:WebhookSubscriptions.Count -gt 0
            SubscriptionCount = $script:WebhookSubscriptions.Count
        }
    }
    
    return $status
}

function Register-APIEndpoint {
    param(
        [string]$Path,
        [string]$Method,
        [string]$Handler,
        [string]$Description,
        [bool]$Authentication = $true
    )
    
    $script:RegisteredEndpoints[$Path] = @{
        Method = $Method
        Handler = $Handler
        Description = $Description
        Authentication = $Authentication
    }
    
    Write-CustomLog "Registered endpoint: $Method $Path -> $Handler" "DEBUG"
    return @{ Success = $true; Path = $Path; Method = $Method }
}

function Test-APIConnection {
    param([int]$Port, [int]$Timeout = 5)
    
    # Mock connection test
    Start-Sleep -Milliseconds 100
    return @{
        Success = $true
        Port = $Port
        ResponseTime = 50
        Status = "Connected"
    }
}

function Initialize-DefaultEndpoints {
    $script:RegisteredEndpoints = @{
        '/health' = @{
            Method = 'GET'
            Handler = 'Get-HealthStatus'
            Description = 'API server health check'
            Authentication = $false
        }
        '/status' = @{
            Method = 'GET'
            Handler = 'Get-APIStatus'
            Description = 'API server status'
            Authentication = $true
        }
        '/modules' = @{
            Method = 'GET'
            Handler = 'Get-ModuleInformation'
            Description = 'List modules'
            Authentication = $true
        }
        '/execute' = @{
            Method = 'POST'
            Handler = 'Invoke-PowerShellCommand'
            Description = 'Execute commands'
            Authentication = $true
        }
    }
}

function Invoke-APIRequest {
    param(
        [string]$Endpoint,
        [string]$Method = 'GET',
        [hashtable]$Headers = @{},
        [string]$Body,
        [int]$Port = 8080
    )
    
    $script:APIMetrics.RequestCount++
    $script:APIMetrics.LastRequest = Get-Date
    
    if (-not $script:RegisteredEndpoints.ContainsKey($Endpoint)) {
        $script:APIMetrics.ErrorCount++
        return @{
            StatusCode = 404
            Success = $false
            Error = "Endpoint not found: $Endpoint"
            Body = @{ error = "Not Found"; message = "Endpoint $Endpoint not found" } | ConvertTo-Json
        }
    }
    
    $endpointConfig = $script:RegisteredEndpoints[$Endpoint]
    
    if ($endpointConfig.Method -ne $Method) {
        $script:APIMetrics.ErrorCount++
        return @{
            StatusCode = 405
            Success = $false
            Error = "Method not allowed"
            Body = @{ error = "Method Not Allowed"; allowed = $endpointConfig.Method } | ConvertTo-Json
        }
    }
    
    # Mock endpoint responses
    $response = switch ($Endpoint) {
        '/health' {
            @{
                StatusCode = 200
                Success = $true
                Body = @{ status = "Healthy"; timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" } | ConvertTo-Json
            }
        }
        '/status' {
            @{
                StatusCode = 200
                Success = $true
                Body = (Get-APIStatus -IncludeMetrics) | ConvertTo-Json -Depth 5
            }
        }
        '/modules' {
            @{
                StatusCode = 200
                Success = $true
                Body = @{
                    modules = @('Logging', 'RestAPIServer', 'SystemMonitoring')
                    count = 3
                } | ConvertTo-Json
            }
        }
        '/execute' {
            if ($Method -eq 'POST' -and $Body) {
                $command = ($Body | ConvertFrom-Json).command
                @{
                    StatusCode = 200
                    Success = $true
                    Body = @{ result = "Executed: $command"; timestamp = Get-Date } | ConvertTo-Json
                }
            } else {
                $script:APIMetrics.ErrorCount++
                @{
                    StatusCode = 400
                    Success = $false
                    Body = @{ error = "Bad Request"; message = "Command required" } | ConvertTo-Json
                }
            }
        }
        default {
            @{
                StatusCode = 200
                Success = $true
                Body = @{ endpoint = $Endpoint; method = $Method; handler = $endpointConfig.Handler } | ConvertTo-Json
            }
        }
    }
    
    return $response
}

Export-ModuleMember -Function Start-AitherZeroAPI, Stop-AitherZeroAPI, Get-APIStatus, Register-APIEndpoint, Test-APIConnection, Invoke-APIRequest
'@ | Out-File -FilePath (Join-Path $restAPIPath 'RestAPIServer.psm1') -Encoding UTF8 -Force
        
        # Create mock Logging module
        $loggingPath = Join-Path $script:TestModulesDir 'Logging'
        @'
$script:LogLevel = 'INFO'
$script:LogHistory = @()

function Write-CustomLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $logEntry = @{
        Timestamp = Get-Date
        Level = $Level
        Message = $Message
    }
    
    $script:LogHistory += $logEntry
    
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
        default { 'White' }
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Initialize-LoggingSystem {
    param([string]$ConsoleLevel = 'INFO', [string]$LogLevel = 'DEBUG', [switch]$Force)
    
    $script:LogLevel = $LogLevel
    Write-CustomLog "Logging system initialized with level: $LogLevel" "INFO"
    return @{ Success = $true; ConsoleLevel = $ConsoleLevel; LogLevel = $LogLevel }
}

function Get-LogHistory {
    return $script:LogHistory
}

Export-ModuleMember -Function Write-CustomLog, Initialize-LoggingSystem, Get-LogHistory
'@ | Out-File -FilePath (Join-Path $loggingPath 'Logging.psm1') -Encoding UTF8 -Force
        
        # Create Find-ProjectRoot utility
        $findProjectRootContent = @"
function Find-ProjectRoot {
    param([string]`$StartPath, [switch]`$Force)
    return '$script:TestProjectRoot'
}
"@
        $findProjectRootPath = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        $findProjectRootContent | Out-File -FilePath $findProjectRootPath -Encoding UTF8
        
        # Mock external commands for testing
        Mock pwsh {
            param($File, $ArgumentList)
            
            # Simulate launching different modes
            $exitCode = 0
            $output = @()
            
            if ($File -and $File.EndsWith('Start-AitherZero.ps1')) {
                $output += "AitherZero launched with parameters: $($ArgumentList -join ' ')"
                if ($ArgumentList -contains '-Auto') {
                    $output += "Running in automatic mode"
                }
                if ($ArgumentList -contains '-NonInteractive') {
                    $output += "Running in non-interactive mode"
                }
            } elseif ($File -and $File.EndsWith('aither-core.ps1')) {
                $output += "Core application started"
                if ($ArgumentList -contains '-Auto') {
                    $output += "Auto mode enabled"
                    $exitCode = 0
                } elseif ($ArgumentList -contains '-Scripts') {
                    $output += "Script mode enabled"
                }
            }
            
            $output | ForEach-Object { Write-Host $_ }
            return $exitCode
        }
        
        Mock Start-Job {
            param($Name, $ScriptBlock, $ArgumentList)
            
            $job = [PSCustomObject]@{
                Id = Get-Random -Minimum 1000 -Maximum 9999
                Name = $Name
                State = 'Running'
                StartTime = Get-Date
                ScriptBlock = $ScriptBlock
                ArgumentList = $ArgumentList
            }
            
            return $job
        }
        
        Mock Receive-Job {
            param($Job)
            return @("Mock job output from $($Job.Name)", "Job completed successfully")
        }
        
        Mock Remove-Job {
            param($Job)
            # Mock job removal
        }
        
        Mock Test-NetConnection {
            param($ComputerName, $Port)
            return @{
                TcpTestSucceeded = $true
                RemoteAddress = $ComputerName
                RemotePort = $Port
            }
        }
        
        # Initialize test variables
        $script:TestResults = @{}
        $script:APITestResults = @{}
        $script:NonInteractiveTestResults = @{}
    }
    
    AfterAll {
        # Clean up any running mock API servers
        if ($script:APIServerJob -and $script:APIServerJob.State -eq 'Running') {
            Stop-AitherZeroAPI
        }
        
        # Restore original environment
        foreach ($key in $script:OriginalEnv.Keys) {
            if ($script:OriginalEnv[$key]) {
                Set-Item -Path "env:$key" -Value $script:OriginalEnv[$key] -ErrorAction SilentlyContinue
            } else {
                Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
            }
        }
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context 'REST API Server Functionality' {
        
        BeforeEach {
            # Import RestAPIServer module for each test
            Import-Module (Join-Path $script:TestModulesDir 'RestAPIServer') -Force
            Import-Module (Join-Path $script:TestModulesDir 'Logging') -Force
        }
        
        AfterEach {
            # Clean up API server after each test
            if (Get-Command Stop-AitherZeroAPI -ErrorAction SilentlyContinue) {
                Stop-AitherZeroAPI | Out-Null
            }
        }
        
        It 'Should start API server with default configuration' {
            $result = Start-AitherZeroAPI
            
            $result.Success | Should -Be $true
            $result.IsRunning | Should -Be $true
            $result.Server.Port | Should -Be 8080
            $result.Server.Protocol | Should -Be 'HTTP'
        }
        
        It 'Should start API server with custom configuration' {
            $result = Start-AitherZeroAPI -Port 9090 -AuthenticationMethod 'Bearer' -EnableSSL -EnableRateLimit:$false
            
            $result.Success | Should -Be $true
            $result.IsRunning | Should -Be $true
            $result.Server.Port | Should -Be 9090
            $result.Server.Protocol | Should -Be 'HTTPS'
        }
        
        It 'Should get comprehensive API status information' {
            Start-AitherZeroAPI | Out-Null
            
            $status = Get-APIStatus -IncludeMetrics -IncludeEndpoints -IncludeConfiguration
            
            $status.Success | Should -Be $true
            $status.IsRunning | Should -Be $true
            $status.UpTime | Should -Not -BeNullOrEmpty
            $status.Metrics | Should -Not -BeNullOrEmpty
            $status.Endpoints | Should -Not -BeNullOrEmpty
            $status.Configuration | Should -Not -BeNullOrEmpty
            $status.Endpoints.Count | Should -BeGreaterThan 0
        }
        
        It 'Should register custom API endpoints' {
            $result = Register-APIEndpoint -Path '/custom' -Method 'POST' -Handler 'Custom-Handler' -Description 'Custom endpoint'
            
            $result.Success | Should -Be $true
            $result.Path | Should -Be '/custom'
            $result.Method | Should -Be 'POST'
        }
        
        It 'Should handle API requests to default endpoints' {
            Start-AitherZeroAPI | Out-Null
            
            # Test health endpoint
            $healthResponse = Invoke-APIRequest -Endpoint '/health' -Method 'GET'
            $healthResponse.Success | Should -Be $true
            $healthResponse.StatusCode | Should -Be 200
            
            # Test status endpoint
            $statusResponse = Invoke-APIRequest -Endpoint '/status' -Method 'GET'
            $statusResponse.Success | Should -Be $true
            $statusResponse.StatusCode | Should -Be 200
            
            # Test modules endpoint
            $modulesResponse = Invoke-APIRequest -Endpoint '/modules' -Method 'GET'
            $modulesResponse.Success | Should -Be $true
            $modulesResponse.StatusCode | Should -Be 200
        }
        
        It 'Should handle API authentication correctly' {
            Start-AitherZeroAPI -AuthenticationMethod 'ApiKey' | Out-Null
            
            # Test with valid API key
            $validResponse = Invoke-APIRequest -Endpoint '/status' -Method 'GET' -Headers @{ 'X-API-Key' = 'valid-key' }
            $validResponse.StatusCode | Should -Be 200
            
            # Test endpoints that don't require authentication
            $healthResponse = Invoke-APIRequest -Endpoint '/health' -Method 'GET'
            $healthResponse.StatusCode | Should -Be 200
        }
        
        It 'Should handle POST requests with JSON body' {
            Start-AitherZeroAPI | Out-Null
            
            $requestBody = @{ command = 'Get-Process' } | ConvertTo-Json
            $response = Invoke-APIRequest -Endpoint '/execute' -Method 'POST' -Body $requestBody
            
            $response.Success | Should -Be $true
            $response.StatusCode | Should -Be 200
            $response.Body | Should -Match 'Get-Process'
        }
        
        It 'Should handle invalid endpoints gracefully' {
            Start-AitherZeroAPI | Out-Null
            
            $response = Invoke-APIRequest -Endpoint '/nonexistent' -Method 'GET'
            
            $response.Success | Should -Be $false
            $response.StatusCode | Should -Be 404
            $response.Error | Should -Match 'not found'
        }
        
        It 'Should handle invalid HTTP methods gracefully' {
            Start-AitherZeroAPI | Out-Null
            
            $response = Invoke-APIRequest -Endpoint '/health' -Method 'POST'
            
            $response.Success | Should -Be $false
            $response.StatusCode | Should -Be 405
        }
        
        It 'Should track API metrics correctly' {
            Start-AitherZeroAPI | Out-Null
            
            # Make several requests
            Invoke-APIRequest -Endpoint '/health' -Method 'GET' | Out-Null
            Invoke-APIRequest -Endpoint '/status' -Method 'GET' | Out-Null
            Invoke-APIRequest -Endpoint '/nonexistent' -Method 'GET' | Out-Null  # This should error
            
            $status = Get-APIStatus -IncludeMetrics
            
            $status.Metrics.RequestCount | Should -BeGreaterThan 0
            $status.Metrics.ErrorCount | Should -BeGreaterThan 0
            $status.Metrics.ErrorRate | Should -BeGreaterThan 0
            $status.Health.Status | Should -BeIn @('Healthy', 'Warning', 'Critical')
        }
        
        It 'Should test API connection successfully' {
            $connectionTest = Test-APIConnection -Port 8080 -Timeout 5
            
            $connectionTest.Success | Should -Be $true
            $connectionTest.Port | Should -Be 8080
            $connectionTest.Status | Should -Be 'Connected'
        }
        
        It 'Should stop API server cleanly' {
            Start-AitherZeroAPI | Out-Null
            
            $stopResult = Stop-AitherZeroAPI
            
            $stopResult.Success | Should -Be $true
            $stopResult.Message | Should -Match 'stopped'
            
            $status = Get-APIStatus
            $status.IsRunning | Should -Be $false
        }
    }
    
    Context 'Non-Interactive Mode Testing' {
        
        It 'Should detect non-interactive mode automatically' {
            # Test various non-interactive scenarios
            $nonInteractiveScenarios = @(
                @{ Env = @{ PESTER_RUN = 'true' }; Description = 'Pester test environment' }
                @{ Env = @{ CI = 'true' }; Description = 'CI environment' }
                @{ Params = @{ Auto = $true }; Description = 'Auto mode parameter' }
                @{ Params = @{ NonInteractive = $true }; Description = 'Explicit non-interactive' }
                @{ Params = @{ WhatIf = $true }; Description = 'WhatIf mode' }
            )
            
            foreach ($scenario in $nonInteractiveScenarios) {
                # Set environment variables if specified
                if ($scenario.Env) {
                    foreach ($envVar in $scenario.Env.Keys) {
                        Set-Item -Path "env:$envVar" -Value $scenario.Env[$envVar]
                    }
                }
                
                # Test non-interactive detection logic
                $hostCheck = ($Host.Name -eq 'Default Host')
                $userInteractiveCheck = ([Environment]::UserInteractive -eq $false)
                $pesterCheck = ($env:PESTER_RUN -eq 'true')
                $autoCheck = if ($scenario.Params -and $scenario.Params.Auto) { $true } else { $false }
                $whatIfCheck = if ($scenario.Params -and $scenario.Params.WhatIf) { $true } else { $false }
                $nonInteractiveParam = if ($scenario.Params -and $scenario.Params.NonInteractive) { $true } else { $false }
                
                $shouldBeNonInteractive = $hostCheck -or $userInteractiveCheck -or $pesterCheck -or $autoCheck -or $whatIfCheck -or $nonInteractiveParam
                
                $shouldBeNonInteractive | Should -Be $true -Because $scenario.Description
                
                # Clean up environment variables
                if ($scenario.Env) {
                    foreach ($envVar in $scenario.Env.Keys) {
                        Remove-Item -Path "env:$envVar" -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        It 'Should handle automatic mode execution' {
            # Test auto mode with different modules
            $autoModeTests = @(
                @{ Scripts = 'SetupWizard'; Expected = 'SetupWizard started successfully' }
                @{ Scripts = 'SystemMonitoring'; Expected = 'SystemMonitoring started successfully' }
                @{ Scripts = 'BackupManager'; Expected = 'BackupManager started successfully' }
                @{ Scripts = 'SetupWizard,SystemMonitoring'; Expected = @('SetupWizard started', 'SystemMonitoring started') }
            )
            
            foreach ($test in $autoModeTests) {
                # Import required modules
                if ($test.Scripts -match 'SetupWizard') {
                    Import-Module (Join-Path $script:TestModulesDir 'SetupWizard') -Force
                }
                if ($test.Scripts -match 'SystemMonitoring') {
                    Import-Module (Join-Path $script:TestModulesDir 'SystemMonitoring') -Force
                }
                if ($test.Scripts -match 'BackupManager') {
                    Import-Module (Join-Path $script:TestModulesDir 'BackupManager') -Force
                }
                
                # Test auto execution
                $scriptNames = $test.Scripts -split ','
                foreach ($scriptName in $scriptNames) {
                    $scriptName = $scriptName.Trim()
                    $result = & "Start-$scriptName" -Auto
                    
                    $result.Success | Should -Be $true
                    $result.Mode | Should -Be 'Automatic'
                    $result.Module | Should -Be $scriptName
                }
            }
        }
        
        It 'Should propagate errors correctly in non-interactive mode' {
            Import-Module (Join-Path $script:TestModulesDir 'SystemMonitoring') -Force
            
            # Test error propagation
            $errorResult = Test-SystemMonitoring -TestType 'Error'
            
            $errorResult.Success | Should -Be $false
            $errorResult.Error | Should -Not -BeNullOrEmpty
            $errorResult.Module | Should -Be 'SystemMonitoring'
        }
        
        It 'Should handle timeout scenarios in automation' {
            # Test timeout handling
            $timeoutTest = {
                param($TimeoutSeconds)
                
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Start-Sleep -Seconds 1  # Simulate work
                $stopwatch.Stop()
                
                return @{
                    Success = $stopwatch.ElapsedMilliseconds -lt ($TimeoutSeconds * 1000)
                    ElapsedMs = $stopwatch.ElapsedMilliseconds
                    Timeout = $TimeoutSeconds
                }
            }
            
            # Test with adequate timeout
            $adequateResult = & $timeoutTest -TimeoutSeconds 5
            $adequateResult.Success | Should -Be $true
            
            # Test with insufficient timeout
            $insufficientResult = & $timeoutTest -TimeoutSeconds 0.5
            $insufficientResult.Success | Should -Be $false
        }
        
        It 'Should handle configuration loading in non-interactive mode' {
            $configPath = Join-Path $script:TestConfigsDir 'default-config.json'
            Test-Path $configPath | Should -Be $true
            
            # Test configuration loading
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            
            $config.version | Should -Be '1.0.0'
            $config.automation.enableAutoMode | Should -Be $true
            $config.automation.defaultModules | Should -Contain 'SetupWizard'
            $config.api.defaultPort | Should -Be 8080
        }
        
        It 'Should validate environment prerequisites in automation' {
            # Test environment validation
            $envValidationTests = @(
                @{ Variable = 'PROJECT_ROOT'; Expected = $script:TestProjectRoot }
                @{ Variable = 'PWSH_MODULES_PATH'; Expected = $script:TestModulesDir }
                @{ Variable = 'PESTER_RUN'; Expected = 'true' }
            )
            
            foreach ($test in $envValidationTests) {
                $actualValue = Get-Item -Path "env:$($test.Variable)" -ErrorAction SilentlyContinue
                if ($actualValue) {
                    $actualValue.Value | Should -Be $test.Expected
                } else {
                    $false | Should -Be $true -Because "Environment variable $($test.Variable) should be set"
                }
            }
        }
        
        It 'Should handle module loading failures gracefully in automation' {
            # Test with non-existent module
            $nonExistentModulePath = Join-Path $script:TestModulesDir 'NonExistentModule'
            
            { Import-Module $nonExistentModulePath -ErrorAction Stop } | Should -Throw
            
            # Test graceful handling
            $moduleLoadResult = try {
                Import-Module $nonExistentModulePath -ErrorAction SilentlyContinue
                @{ Success = $true; Message = 'Module loaded' }
            } catch {
                @{ Success = $false; Error = $_.Exception.Message }
            }
            
            $moduleLoadResult.Success | Should -Be $false
            $moduleLoadResult.Error | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Automation Scenarios and CI/CD Integration' {
        
        It 'Should support headless execution for CI/CD pipelines' {
            # Test headless execution simulation
            $env:CI = 'true'
            $env:AUTOMATED_TESTING = 'true'
            
            try {
                # Simulate CI/CD pipeline execution
                $ciExecutionResult = @{
                    Success = $true
                    Environment = 'CI'
                    NonInteractive = $true
                    Modules = @()
                }
                
                # Test multiple module execution in CI mode
                $testModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
                foreach ($moduleName in $testModules) {
                    Import-Module (Join-Path $script:TestModulesDir $moduleName) -Force
                    $moduleResult = & "Start-$moduleName" -Auto
                    
                    if ($moduleResult.Success) {
                        $ciExecutionResult.Modules += @{
                            Name = $moduleName
                            Status = 'Success'
                            Mode = $moduleResult.Mode
                        }
                    } else {
                        $ciExecutionResult.Success = $false
                        $ciExecutionResult.Modules += @{
                            Name = $moduleName
                            Status = 'Failed'
                            Error = $moduleResult.Error
                        }
                    }
                }
                
                $ciExecutionResult.Success | Should -Be $true
                $ciExecutionResult.Modules.Count | Should -Be $testModules.Count
                
                foreach ($moduleResult in $ciExecutionResult.Modules) {
                    $moduleResult.Status | Should -Be 'Success'
                }
                
            } finally {
                Remove-Item -Path 'env:CI' -ErrorAction SilentlyContinue
                Remove-Item -Path 'env:AUTOMATED_TESTING' -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should handle batch processing scenarios' {
            # Test batch processing of multiple operations
            $batchOperations = @(
                @{ Operation = 'Health Check'; Module = 'SystemMonitoring'; Test = 'Basic' }
                @{ Operation = 'Config Validation'; Module = 'SetupWizard'; Test = 'Basic' }
                @{ Operation = 'Backup Verification'; Module = 'BackupManager'; Test = 'Basic' }
                @{ Operation = 'API Status'; Module = 'RestAPIServer'; Test = 'Basic' }
            )
            
            $batchResults = @()
            
            foreach ($operation in $batchOperations) {
                Import-Module (Join-Path $script:TestModulesDir $operation.Module) -Force
                
                $operationResult = try {
                    $result = & "Test-$($operation.Module)" -TestType $operation.Test
                    @{
                        Operation = $operation.Operation
                        Module = $operation.Module
                        Success = $result.Success
                        Result = $result
                        Duration = if ($result.Duration) { $result.Duration } else { 0 }
                    }
                } catch {
                    @{
                        Operation = $operation.Operation
                        Module = $operation.Module
                        Success = $false
                        Error = $_.Exception.Message
                        Duration = 0
                    }
                }
                
                $batchResults += $operationResult
            }
            
            # Validate batch processing results
            $batchResults.Count | Should -Be $batchOperations.Count
            
            $successfulOperations = $batchResults | Where-Object { $_.Success -eq $true }
            $successfulOperations.Count | Should -Be $batchOperations.Count
        }
        
        It 'Should support parallel automation execution' {
            # Test parallel execution simulation
            $parallelModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
            $jobs = @()
            
            # Start parallel jobs
            foreach ($moduleName in $parallelModules) {
                $job = Start-Job -Name "Test-$moduleName" -ScriptBlock {
                    param($ModulePath, $ModuleName)
                    
                    Import-Module $ModulePath -Force
                    $result = & "Test-$ModuleName" -TestType 'Basic'
                    
                    return @{
                        Module = $ModuleName
                        Success = $result.Success
                        StartTime = Get-Date
                        Result = $result
                    }
                } -ArgumentList (Join-Path $script:TestModulesDir $moduleName), $moduleName
                
                $jobs += $job
            }
            
            # Wait for all jobs to complete (with timeout)
            $timeout = 30  # seconds
            $completed = Wait-Job -Job $jobs -Timeout $timeout
            
            # Collect results
            $parallelResults = @()
            foreach ($job in $jobs) {
                if ($job.State -eq 'Completed') {
                    $jobResult = Receive-Job -Job $job
                    $parallelResults += $jobResult
                } else {
                    $parallelResults += @{
                        Module = $job.Name
                        Success = $false
                        Error = "Job did not complete within timeout"
                    }
                }
                Remove-Job -Job $job -Force
            }
            
            # Validate parallel execution
            $parallelResults.Count | Should -Be $parallelModules.Count
            
            $successfulJobs = $parallelResults | Where-Object { $_.Success -eq $true }
            $successfulJobs.Count | Should -Be $parallelModules.Count
        }
        
        It 'Should handle API automation workflows' {
            Import-Module (Join-Path $script:TestModulesDir 'RestAPIServer') -Force
            
            # Start API server
            Start-AitherZeroAPI -Port 8080 -BackgroundMode | Out-Null
            
            # Automated API workflow
            $apiWorkflow = @(
                @{ Step = 'Health Check'; Endpoint = '/health'; Method = 'GET' }
                @{ Step = 'Get Status'; Endpoint = '/status'; Method = 'GET' }
                @{ Step = 'List Modules'; Endpoint = '/modules'; Method = 'GET' }
                @{ Step = 'Execute Command'; Endpoint = '/execute'; Method = 'POST'; Body = @{ command = 'Get-Date' } }
            )
            
            $workflowResults = @()
            
            foreach ($step in $apiWorkflow) {
                $stepResult = try {
                    $requestParams = @{
                        Endpoint = $step.Endpoint
                        Method = $step.Method
                    }
                    
                    if ($step.Body) {
                        $requestParams.Body = $step.Body | ConvertTo-Json
                    }
                    
                    $response = Invoke-APIRequest @requestParams
                    
                    @{
                        Step = $step.Step
                        Success = $response.Success
                        StatusCode = $response.StatusCode
                        Endpoint = $step.Endpoint
                        Method = $step.Method
                    }
                } catch {
                    @{
                        Step = $step.Step
                        Success = $false
                        Error = $_.Exception.Message
                        Endpoint = $step.Endpoint
                        Method = $step.Method
                    }
                }
                
                $workflowResults += $stepResult
            }
            
            # Validate API automation workflow
            $workflowResults.Count | Should -Be $apiWorkflow.Count
            
            foreach ($result in $workflowResults) {
                $result.Success | Should -Be $true -Because "Step '$($result.Step)' should succeed"
                $result.StatusCode | Should -Be 200 -Because "Step '$($result.Step)' should return 200"
            }
            
            # Clean up
            Stop-AitherZeroAPI | Out-Null
        }
        
        It 'Should handle error propagation in automation chains' {
            # Test error propagation through automation chain
            $automationChain = @(
                @{ Step = 'Initialize'; Module = 'SetupWizard'; TestType = 'Basic'; Critical = $true }
                @{ Step = 'Monitor'; Module = 'SystemMonitoring'; TestType = 'Basic'; Critical = $false }
                @{ Step = 'Error Step'; Module = 'BackupManager'; TestType = 'Error'; Critical = $true }
                @{ Step = 'Final Step'; Module = 'SetupWizard'; TestType = 'Basic'; Critical = $false }
            )
            
            $chainResults = @()
            $chainFailed = $false
            
            foreach ($step in $automationChain) {
                if ($chainFailed -and $step.Critical) {
                    # Skip critical steps if chain already failed
                    $chainResults += @{
                        Step = $step.Step
                        Success = $false
                        Skipped = $true
                        Reason = 'Previous critical step failed'
                    }
                    continue
                }
                
                Import-Module (Join-Path $script:TestModulesDir $step.Module) -Force
                
                $stepResult = try {
                    $result = & "Test-$($step.Module)" -TestType $step.TestType
                    
                    if (-not $result.Success -and $step.Critical) {
                        $chainFailed = $true
                    }
                    
                    @{
                        Step = $step.Step
                        Module = $step.Module
                        Success = $result.Success
                        Critical = $step.Critical
                        Error = if ($result.Error) { $result.Error } else { $null }
                    }
                } catch {
                    if ($step.Critical) {
                        $chainFailed = $true
                    }
                    
                    @{
                        Step = $step.Step
                        Module = $step.Module
                        Success = $false
                        Critical = $step.Critical
                        Error = $_.Exception.Message
                    }
                }
                
                $chainResults += $stepResult
            }
            
            # Validate error propagation
            $chainResults.Count | Should -Be $automationChain.Count
            
            # Should have at least one failed step (the error step)
            $failedSteps = $chainResults | Where-Object { $_.Success -eq $false -and -not $_.Skipped }
            $failedSteps.Count | Should -BeGreaterThan 0
            
            # Critical failure should stop subsequent critical steps
            $errorStep = $chainResults | Where-Object { $_.Step -eq 'Error Step' }
            $errorStep.Success | Should -Be $false
            $errorStep.Critical | Should -Be $true
        }
        
        It 'Should support integration with external monitoring systems' {
            # Test integration with external monitoring
            $monitoringIntegration = @{
                MetricsEndpoint = '/metrics'
                HealthEndpoint = '/health'
                StatusCodes = @()
                ResponseTimes = @()
                Errors = @()
            }
            
            Import-Module (Join-Path $script:TestModulesDir 'RestAPIServer') -Force
            Import-Module (Join-Path $script:TestModulesDir 'SystemMonitoring') -Force
            
            # Start API server for monitoring
            Start-AitherZeroAPI -Port 8080 | Out-Null
            
            # Simulate monitoring system checks
            $monitoringChecks = 5
            for ($i = 1; $i -le $monitoringChecks; $i++) {
                $startTime = Get-Date
                
                # Health check
                $healthResponse = Invoke-APIRequest -Endpoint '/health' -Method 'GET'
                $responseTime = ((Get-Date) - $startTime).TotalMilliseconds
                
                $monitoringIntegration.StatusCodes += $healthResponse.StatusCode
                $monitoringIntegration.ResponseTimes += $responseTime
                
                if (-not $healthResponse.Success) {
                    $monitoringIntegration.Errors += "Health check failed: $($healthResponse.Error)"
                }
                
                # System monitoring check
                $systemCheck = Test-SystemMonitoring -TestType 'Basic'
                if (-not $systemCheck.Success) {
                    $monitoringIntegration.Errors += "System monitoring failed: $($systemCheck.Error)"
                }
                
                Start-Sleep -Milliseconds 100  # Simulate monitoring interval
            }
            
            # Validate monitoring integration
            $monitoringIntegration.StatusCodes.Count | Should -Be $monitoringChecks
            $monitoringIntegration.ResponseTimes.Count | Should -Be $monitoringChecks
            
            # All health checks should return 200
            $monitoringIntegration.StatusCodes | ForEach-Object { $_ | Should -Be 200 }
            
            # Response times should be reasonable (under 1000ms for mock)
            $monitoringIntegration.ResponseTimes | ForEach-Object { $_ | Should -BeLessThan 1000 }
            
            # Should have minimal errors
            $monitoringIntegration.Errors.Count | Should -BeLessOrEqual 1
            
            # Clean up
            Stop-AitherZeroAPI | Out-Null
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should handle high-frequency API requests efficiently' {
            Import-Module (Join-Path $script:TestModulesDir 'RestAPIServer') -Force
            
            Start-AitherZeroAPI -Port 8080 | Out-Null
            
            # Simulate high-frequency requests
            $requestCount = 50
            $responses = @()
            $startTime = Get-Date
            
            for ($i = 1; $i -le $requestCount; $i++) {
                $response = Invoke-APIRequest -Endpoint '/health' -Method 'GET'
                $responses += $response
            }
            
            $totalTime = ((Get-Date) - $startTime).TotalMilliseconds
            $averageResponseTime = $totalTime / $requestCount
            
            # Validate performance
            $responses.Count | Should -Be $requestCount
            $averageResponseTime | Should -BeLessThan 100  # Average under 100ms for mock
            
            # All requests should succeed
            $successfulResponses = $responses | Where-Object { $_.Success -eq $true }
            $successfulResponses.Count | Should -Be $requestCount
            
            # Check API metrics
            $finalStatus = Get-APIStatus -IncludeMetrics
            $finalStatus.Metrics.RequestCount | Should -BeGreaterOrEqual $requestCount
            
            Stop-AitherZeroAPI | Out-Null
        }
        
        It 'Should manage memory efficiently during automation' {
            # Test memory efficiency during automation
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform intensive automation operations
            $modules = @('SetupWizard', 'SystemMonitoring', 'BackupManager', 'RestAPIServer')
            
            foreach ($module in $modules) {
                Import-Module (Join-Path $script:TestModulesDir $module) -Force
                
                # Perform multiple operations
                for ($i = 1; $i -le 10; $i++) {
                    $result = & "Test-$module" -TestType 'Basic'
                    $result | Out-Null  # Process result to simulate real usage
                }
                
                # Remove module to free memory
                Remove-Module $module -Force -ErrorAction SilentlyContinue
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            $finalMemory = [GC]::GetTotalMemory($true)
            
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Memory increase should be reasonable (less than 100MB for mock operations)
            $memoryIncrease | Should -BeLessThan (100 * 1024 * 1024)
        }
        
        It 'Should handle concurrent automation workflows efficiently' {
            # Test concurrent workflow handling
            $concurrentWorkflows = 3
            $workflowJobs = @()
            
            for ($i = 1; $i -le $concurrentWorkflows; $i++) {
                $job = Start-Job -Name "Workflow-$i" -ScriptBlock {
                    param($ModulesPath, $WorkflowId)
                    
                    $workflowResult = @{
                        WorkflowId = $WorkflowId
                        Success = $true
                        Operations = @()
                        StartTime = Get-Date
                    }
                    
                    # Simulate workflow operations
                    $operations = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
                    
                    foreach ($operation in $operations) {
                        $modulePath = Join-Path $ModulesPath $operation
                        Import-Module $modulePath -Force
                        
                        $operationResult = & "Test-$operation" -TestType 'Basic'
                        
                        $workflowResult.Operations += @{
                            Operation = $operation
                            Success = $operationResult.Success
                            Duration = if ($operationResult.Duration) { $operationResult.Duration } else { 50 }
                        }
                        
                        if (-not $operationResult.Success) {
                            $workflowResult.Success = $false
                        }
                    }
                    
                    $workflowResult.EndTime = Get-Date
                    $workflowResult.TotalDuration = ($workflowResult.EndTime - $workflowResult.StartTime).TotalMilliseconds
                    
                    return $workflowResult
                } -ArgumentList $script:TestModulesDir, $i
                
                $workflowJobs += $job
            }
            
            # Wait for all workflows to complete
            $completed = Wait-Job -Job $workflowJobs -Timeout 60
            
            # Collect and validate results
            $workflowResults = @()
            foreach ($job in $workflowJobs) {
                if ($job.State -eq 'Completed') {
                    $result = Receive-Job -Job $job
                    $workflowResults += $result
                }
                Remove-Job -Job $job -Force
            }
            
            # Validate concurrent execution
            $workflowResults.Count | Should -Be $concurrentWorkflows
            
            foreach ($result in $workflowResults) {
                $result.Success | Should -Be $true
                $result.Operations.Count | Should -Be 3
                $result.TotalDuration | Should -BeLessThan 10000  # Should complete within 10 seconds
            }
        }
    }
}