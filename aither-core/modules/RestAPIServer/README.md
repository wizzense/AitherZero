# RestAPIServer Module

## Test Status
- **Last Run**: 2025-07-08 18:34:12 UTC
- **Status**: ✅ PASSING (11/11 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The **RestAPIServer** module provides a comprehensive REST API server for external system integration, enabling third-party tools and services to interact with AitherZero automation capabilities through standardized HTTP endpoints. It serves as the primary gateway for external automation, monitoring, and management operations.

### Core Functionality and Purpose

- **HTTP API Server**: Full-featured REST API server with multiple authentication methods
- **External Integration**: Enable third-party tools to interact with AitherZero functionality
- **Webhook Support**: Real-time notifications and event-driven integrations
- **Secure Communication**: SSL/TLS support, API key authentication, and request validation
- **Modular Endpoints**: Extensible endpoint registration system for custom functionality
- **Background Operations**: Asynchronous job execution and monitoring

### Architecture and Design Patterns

The module implements a **microservices gateway pattern** with a modular endpoint architecture. It uses the **HTTP listener pattern** for request handling, **middleware pattern** for authentication and CORS, and **pub-sub pattern** for webhook notifications.

### Key Features

- **Multi-Protocol Support**: HTTP and HTTPS with configurable SSL
- **Authentication Methods**: API Key, Basic Auth, Bearer Token, and None
- **CORS Support**: Cross-origin resource sharing for web applications
- **Rate Limiting**: Configurable request rate limiting for API protection
- **Webhook System**: Event-driven notifications to external systems
- **OpenAPI Documentation**: Automatic API documentation generation
- **Health Monitoring**: Built-in health checks and metrics collection

## Directory Structure

```
RestAPIServer/
├── RestAPIServer.psd1           # Module manifest
├── RestAPIServer.psm1           # Main module loader and core functionality
├── Public/                      # Exported functions
│   ├── Add-WebhookSubscription.ps1
│   ├── Enable-APIWebhooks.ps1
│   ├── Get-APIStatus.ps1
│   ├── Get-WebhookSubscriptions.ps1
│   ├── Register-APIEndpoint.ps1
│   ├── Start-AitherZeroAPI.ps1
│   └── Stop-AitherZeroAPI.ps1
└── README.md                    # This documentation
```

### Module Files and Organization

#### Core Module Files
- **RestAPIServer.psd1**: Module manifest with exported functions and metadata
- **RestAPIServer.psm1**: Core implementation with HTTP listener and request processing

#### Public Functions
- **Start-AitherZeroAPI.ps1**: Start the REST API server
- **Stop-AitherZeroAPI.ps1**: Stop the running API server
- **Get-APIStatus.ps1**: Get server status and metrics
- **Register-APIEndpoint.ps1**: Register custom API endpoints
- **Enable-APIWebhooks.ps1**: Enable webhook functionality
- **Add-WebhookSubscription.ps1**: Subscribe to webhook notifications
- **Get-WebhookSubscriptions.ps1**: List webhook subscriptions

#### Resource Files
The module includes built-in endpoints for system integration and monitoring.

## Function Reference

### Start-AitherZeroAPI

Starts the AitherZero REST API server for external integrations.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Port | int | No | Port number for the API server (default: 8080) |
| Protocol | string | No | Protocol to use: HTTP or HTTPS (default: HTTP) |
| EnableSSL | switch | No | Enable SSL/TLS encryption for HTTPS |
| CertificatePath | string | No | Path to SSL certificate (required if EnableSSL is true) |
| AuthenticationMethod | string | No | Authentication: None, ApiKey, Basic, Bearer (default: ApiKey) |
| EnableCORS | switch | No | Enable Cross-Origin Resource Sharing (default: true) |
| EnableRateLimit | switch | No | Enable request rate limiting (default: true) |
| BackgroundMode | switch | No | Run API server in background (default: true) |

#### Returns

- **hashtable**: Server status with properties:
  - Success: Boolean indicating successful start
  - Port: Server port number
  - Protocol: HTTP or HTTPS
  - JobId: Background job ID (if BackgroundMode)
  - StartTime: Server start timestamp
  - Endpoints: Number of registered endpoints

#### Examples

```powershell
# Start with default settings (HTTP, port 8080, API key auth)
Start-AitherZeroAPI

# Start HTTPS server with SSL certificate
Start-AitherZeroAPI -Port 443 -EnableSSL -CertificatePath "C:\certs\api.pfx"

# Start with Bearer token authentication
Start-AitherZeroAPI -Port 8080 -AuthenticationMethod Bearer

# Start without authentication (development only)
Start-AitherZeroAPI -AuthenticationMethod None -EnableRateLimit:$false

# Start in foreground mode for debugging
Start-AitherZeroAPI -BackgroundMode:$false -AuthenticationMethod None
```

### Stop-AitherZeroAPI

Stops the running AitherZero REST API server.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Force | switch | No | Force stop without graceful shutdown |
| Timeout | int | No | Timeout in seconds for graceful shutdown (default: 30) |

#### Returns

- **hashtable**: Stop operation result

#### Examples

```powershell
# Graceful shutdown
Stop-AitherZeroAPI

# Force immediate shutdown
Stop-AitherZeroAPI -Force

# Custom timeout for shutdown
Stop-AitherZeroAPI -Timeout 60
```

### Get-APIStatus

Retrieves current status and metrics of the API server.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Detailed | switch | No | Include detailed metrics and endpoint information |

#### Returns

- **PSCustomObject**: API status with properties:
  - IsRunning: Boolean indicating if server is active
  - Port: Server port
  - Protocol: HTTP/HTTPS
  - Uptime: Server uptime in seconds
  - RequestCount: Total requests processed
  - ErrorCount: Total errors encountered
  - LastRequest: Timestamp of last request
  - Endpoints: Array of registered endpoints (if Detailed)

#### Examples

```powershell
# Basic status
$status = Get-APIStatus
Write-Host "API Server Running: $($status.IsRunning)"

# Detailed status with metrics
$detailedStatus = Get-APIStatus -Detailed
$detailedStatus | Format-Table -AutoSize

# Monitor status in real-time
while ($true) {
    Clear-Host
    Get-APIStatus -Detailed | Format-List
    Start-Sleep -Seconds 5
}
```

### Register-APIEndpoint

Registers a custom API endpoint with the server.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Path | string | Yes | URL path for the endpoint (e.g., "/api/custom") |
| Method | string | Yes | HTTP method: GET, POST, PUT, DELETE |
| Handler | string | Yes | Name of the handler function |
| Description | string | No | Description of the endpoint functionality |
| RequireAuthentication | bool | No | Whether endpoint requires authentication (default: true) |
| Parameters | string[] | No | Array of expected parameter names |

#### Returns

- **hashtable**: Registration result

#### Examples

```powershell
# Register a custom GET endpoint
Register-APIEndpoint -Path "/api/vm-status" `
    -Method "GET" `
    -Handler "Get-VMStatus" `
    -Description "Get virtual machine status"

# Register a POST endpoint with parameters
Register-APIEndpoint -Path "/api/deploy" `
    -Method "POST" `
    -Handler "Start-Deployment" `
    -Description "Start application deployment" `
    -Parameters @("Environment", "Version", "Config")

# Register public endpoint (no authentication)
Register-APIEndpoint -Path "/api/health" `
    -Method "GET" `
    -Handler "Get-SystemHealth" `
    -RequireAuthentication $false
```

### Enable-APIWebhooks

Enables webhook functionality for the API server.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| WebhookSecret | string | No | Secret key for webhook signature validation |
| MaxRetries | int | No | Maximum retry attempts for failed webhooks (default: 3) |
| RetryInterval | int | No | Interval between retries in seconds (default: 60) |

#### Returns

- **hashtable**: Webhook enablement result

#### Examples

```powershell
# Enable webhooks with default settings
Enable-APIWebhooks

# Enable with custom secret and retry settings
Enable-APIWebhooks -WebhookSecret "my-secret-key" `
    -MaxRetries 5 `
    -RetryInterval 30
```

### Add-WebhookSubscription

Subscribes to webhook notifications for specific events.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Url | string | Yes | Webhook endpoint URL to receive notifications |
| Events | string[] | Yes | Array of event types to subscribe to |
| Secret | string | No | Secret for webhook signature validation |
| Description | string | No | Description of the webhook subscription |
| Active | bool | No | Whether subscription is active (default: true) |

#### Returns

- **hashtable**: Subscription creation result with subscription ID

#### Examples

```powershell
# Subscribe to deployment events
Add-WebhookSubscription -Url "https://my-system.com/webhooks/aitherzero" `
    -Events @("deployment.started", "deployment.completed", "deployment.failed") `
    -Description "Deployment notifications"

# Subscribe to all events with secret
Add-WebhookSubscription -Url "https://monitoring.company.com/webhook" `
    -Events @("*") `
    -Secret "webhook-secret-123" `
    -Description "All AitherZero events"

# Subscribe to specific VM events
Add-WebhookSubscription -Url "https://vmware.internal.com/api/webhook" `
    -Events @("vm.created", "vm.deleted", "vm.state.changed") `
    -Description "VM lifecycle events"
```

### Get-WebhookSubscriptions

Retrieves current webhook subscriptions.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| SubscriptionId | string | No | Specific subscription ID to retrieve |
| Active | bool | No | Filter by active status |

#### Returns

- **PSCustomObject[]**: Array of webhook subscriptions

#### Examples

```powershell
# Get all subscriptions
$subscriptions = Get-WebhookSubscriptions

# Get only active subscriptions
$activeWebhooks = Get-WebhookSubscriptions -Active $true

# Get specific subscription
$webhook = Get-WebhookSubscriptions -SubscriptionId "12345-abcde"
```

### Additional Functions

#### Exported Functions
- **Unregister-APIEndpoint**: Remove a registered endpoint
- **Get-APIEndpoints**: List all registered endpoints
- **Set-APIConfiguration**: Update server configuration
- **Get-APIConfiguration**: Get current configuration
- **Test-APIConnection**: Test connectivity to the API server
- **Export-APIDocumentation**: Generate OpenAPI documentation
- **Disable-APIWebhooks**: Disable webhook functionality
- **Send-WebhookNotification**: Manually send webhook notification
- **Remove-WebhookSubscription**: Remove webhook subscription

## Key Features

### Authentication Methods

#### API Key Authentication
```powershell
# Start server with API key authentication
Start-AitherZeroAPI -AuthenticationMethod "ApiKey"

# Client request example
Invoke-RestMethod -Uri "http://localhost:8080/api/status" `
    -Headers @{"X-API-Key" = "aitherzero-admin"}
```

#### Bearer Token Authentication
```powershell
# Start server with Bearer token authentication
Start-AitherZeroAPI -AuthenticationMethod "Bearer"

# Client request example
Invoke-RestMethod -Uri "http://localhost:8080/api/status" `
    -Headers @{"Authorization" = "Bearer your-token-here"}
```

#### Basic Authentication
```powershell
# Start server with Basic authentication
Start-AitherZeroAPI -AuthenticationMethod "Basic"

# Client request example
$credential = Get-Credential
Invoke-RestMethod -Uri "http://localhost:8080/api/status" `
    -Credential $credential
```

### Built-in API Endpoints

#### Health Check Endpoint
```
GET /health
```
Returns server health status without authentication.

**Response:**
```json
{
    "Success": true,
    "Status": "Healthy",
    "Timestamp": "2025-07-06T14:30:22Z",
    "Version": "1.0.0"
}
```

#### Server Status Endpoint
```
GET /status
```
Returns detailed server status and metrics.

**Response:**
```json
{
    "Success": true,
    "IsRunning": true,
    "Port": 8080,
    "Protocol": "HTTP",
    "Uptime": 3600,
    "RequestCount": 150,
    "ErrorCount": 2,
    "LastRequest": "2025-07-06T14:30:15Z"
}
```

#### System Performance Endpoint
```
GET /performance?MetricType=CPU&Duration=5
```
Returns system performance metrics.

**Response:**
```json
{
    "Success": true,
    "Data": {
        "CPU": 25.5,
        "Memory": 65.2,
        "Disk": 45.8,
        "Timestamp": "2025-07-06T14:30:22Z"
    }
}
```

#### Module Information Endpoint
```
GET /modules
```
Lists available AitherZero modules.

**Response:**
```json
{
    "Success": true,
    "Data": [
        {
            "Name": "ProgressTracking",
            "Version": "1.0.0",
            "Description": "Visual progress tracking",
            "Functions": ["Start-ProgressOperation", "Update-ProgressOperation"]
        }
    ]
}
```

#### Command Execution Endpoint
```
POST /execute
Content-Type: application/json

{
    "Command": "Get-VM",
    "Module": "Hyper-V",
    "Arguments": ["VMName", "State"]
}
```

### Webhook System

#### Event Types
- **deployment.started**: Deployment process begins
- **deployment.completed**: Deployment successful
- **deployment.failed**: Deployment failed
- **vm.created**: Virtual machine created
- **vm.deleted**: Virtual machine deleted
- **vm.state.changed**: VM state changed
- **system.alert**: System alert generated
- **backup.completed**: Backup operation completed
- **maintenance.started**: Maintenance window started

#### Webhook Payload Example
```json
{
    "eventType": "deployment.completed",
    "timestamp": "2025-07-06T14:30:22Z",
    "source": "AitherZero",
    "data": {
        "deploymentId": "deploy-12345",
        "environment": "production",
        "version": "v2.1.0",
        "duration": 180,
        "success": true
    },
    "signature": "sha256=hash-of-payload-with-secret"
}
```

## Usage Examples

### Real-World Scenarios

#### External Monitoring Integration
```powershell
# Start API server for monitoring system integration
Start-AitherZeroAPI -Port 8080 -AuthenticationMethod "ApiKey"

# Register custom monitoring endpoints
Register-APIEndpoint -Path "/api/infrastructure/health" `
    -Method "GET" `
    -Handler "Get-InfrastructureHealth" `
    -Description "Complete infrastructure health check"

# Register deployment trigger endpoint
Register-APIEndpoint -Path "/api/deployment/trigger" `
    -Method "POST" `
    -Handler "Start-RemoteDeployment" `
    -Description "Trigger deployment from external CI/CD" `
    -Parameters @("Environment", "Version", "Branch")

# Set up webhook for monitoring alerts
Add-WebhookSubscription -Url "https://monitoring.company.com/api/alerts" `
    -Events @("system.alert", "deployment.failed", "backup.failed") `
    -Secret "monitoring-webhook-secret"

# Custom handler implementation
function Get-InfrastructureHealth {
    param($Request)
    
    try {
        # Check all infrastructure components
        $results = @{
            HyperV = Test-HyperVCluster
            Docker = Test-DockerSwarm
            Network = Test-NetworkConnectivity
            Storage = Test-StorageCapacity
        }
        
        $overallStatus = if ($results.Values | Where-Object { -not $_.Healthy }) {
            "Degraded"
        } else {
            "Healthy"
        }
        
        return @{
            Success = $true
            Status = $overallStatus
            Components = $results
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
```

#### CI/CD Pipeline Integration
```powershell
# Configure API for CI/CD integration
Start-AitherZeroAPI -Port 443 -EnableSSL -CertificatePath "C:\certs\api.pfx" `
    -AuthenticationMethod "Bearer"

# Register deployment endpoints
$deploymentEndpoints = @(
    @{Path = "/api/deploy/validate"; Method = "POST"; Handler = "Test-DeploymentPlan"},
    @{Path = "/api/deploy/execute"; Method = "POST"; Handler = "Start-Deployment"},
    @{Path = "/api/deploy/status"; Method = "GET"; Handler = "Get-DeploymentStatus"},
    @{Path = "/api/deploy/rollback"; Method = "POST"; Handler = "Start-Rollback"}
)

foreach ($endpoint in $deploymentEndpoints) {
    Register-APIEndpoint @endpoint -RequireAuthentication $true
}

# Set up webhooks for CI/CD notifications
Add-WebhookSubscription -Url "https://ci.company.com/api/webhooks/aitherzero" `
    -Events @("deployment.*") `
    -Description "CI/CD deployment notifications"

# Example client usage from CI/CD pipeline
function Invoke-AitherZeroDeployment {
    param(
        [string]$Environment,
        [string]$Version,
        [string]$ApiToken
    )
    
    $apiBase = "https://aitherzero-api.company.com"
    $headers = @{"Authorization" = "Bearer $ApiToken"}
    
    # Validate deployment plan
    $validationResult = Invoke-RestMethod -Uri "$apiBase/api/deploy/validate" `
        -Method POST `
        -Headers $headers `
        -Body (@{Environment=$Environment; Version=$Version} | ConvertTo-Json) `
        -ContentType "application/json"
    
    if (-not $validationResult.Success) {
        throw "Deployment validation failed: $($validationResult.Error)"
    }
    
    # Execute deployment
    $deployResult = Invoke-RestMethod -Uri "$apiBase/api/deploy/execute" `
        -Method POST `
        -Headers $headers `
        -Body (@{Environment=$Environment; Version=$Version} | ConvertTo-Json) `
        -ContentType "application/json"
    
    return $deployResult
}
```

#### Third-Party Tool Integration
```powershell
# Configure API for external tool integration
Start-AitherZeroAPI -Port 8080 -AuthenticationMethod "ApiKey" -EnableCORS

# Register custom endpoints for different tools
$toolEndpoints = @{
    # Ansible integration
    "/api/ansible/inventory" = @{Method="GET"; Handler="Get-AnsibleInventory"}
    "/api/ansible/execute" = @{Method="POST"; Handler="Run-AnsiblePlaybook"}
    
    # Terraform integration  
    "/api/terraform/plan" = @{Method="POST"; Handler="Get-TerraformPlan"}
    "/api/terraform/apply" = @{Method="POST"; Handler="Apply-TerraformConfig"}
    
    # Kubernetes integration
    "/api/k8s/deploy" = @{Method="POST"; Handler="Deploy-KubernetesApp"}
    "/api/k8s/status" = @{Method="GET"; Handler="Get-KubernetesStatus"}
}

foreach ($path in $toolEndpoints.Keys) {
    $endpoint = $toolEndpoints[$path]
    Register-APIEndpoint -Path $path -Method $endpoint.Method -Handler $endpoint.Handler
}
```

### Integration Patterns

#### Webhook Event Handling
```powershell
# Set up comprehensive webhook handling
function Initialize-WebhookSystem {
    Enable-APIWebhooks -WebhookSecret "aitherzero-webhook-secret"
    
    # Monitoring system webhooks
    Add-WebhookSubscription -Url "https://monitoring.company.com/webhook" `
        -Events @("system.alert", "performance.threshold") `
        -Description "System monitoring alerts"
    
    # Incident management webhooks
    Add-WebhookSubscription -Url "https://incidents.company.com/api/webhook" `
        -Events @("deployment.failed", "system.error") `
        -Description "Incident creation"
    
    # Slack notifications
    Add-WebhookSubscription -Url "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX" `
        -Events @("deployment.completed", "backup.completed") `
        -Description "Team notifications"
}

# Custom webhook sender
function Send-CustomWebhook {
    param(
        [string]$EventType,
        [hashtable]$EventData
    )
    
    # Send webhook to all subscribers of this event type
    $subscriptions = Get-WebhookSubscriptions | Where-Object { 
        $_.Events -contains $EventType -or $_.Events -contains "*" 
    }
    
    foreach ($subscription in $subscriptions) {
        try {
            $payload = @{
                eventType = $EventType
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                source = "AitherZero"
                data = $EventData
            }
            
            if ($subscription.Secret) {
                $payload.signature = New-WebhookSignature -Payload $payload -Secret $subscription.Secret
            }
            
            Invoke-RestMethod -Uri $subscription.Url `
                -Method POST `
                -Body ($payload | ConvertTo-Json -Depth 5) `
                -ContentType "application/json"
                
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Webhook delivery failed: $($_.Exception.Message)"
        }
    }
}
```

#### API Client SDK
```powershell
# PowerShell SDK for AitherZero API
class AitherZeroAPIClient {
    [string]$BaseUrl
    [hashtable]$Headers
    [int]$Timeout = 30
    
    AitherZeroAPIClient([string]$BaseUrl, [string]$ApiKey) {
        $this.BaseUrl = $BaseUrl.TrimEnd('/')
        $this.Headers = @{"X-API-Key" = $ApiKey}
    }
    
    [object] InvokeAPI([string]$Path, [string]$Method = "GET", [object]$Body = $null) {
        $uri = "$($this.BaseUrl)$Path"
        
        $params = @{
            Uri = $uri
            Method = $Method
            Headers = $this.Headers
            TimeoutSec = $this.Timeout
        }
        
        if ($Body) {
            $params.Body = $Body | ConvertTo-Json -Depth 5
            $params.ContentType = "application/json"
        }
        
        try {
            return Invoke-RestMethod @params
        } catch {
            throw "API request failed: $($_.Exception.Message)"
        }
    }
    
    # Convenience methods
    [object] GetStatus() { return $this.InvokeAPI("/status") }
    [object] GetHealth() { return $this.InvokeAPI("/health") }
    [object] GetModules() { return $this.InvokeAPI("/modules") }
    
    [object] ExecuteCommand([string]$Command, [string]$Module = $null, [array]$Arguments = @()) {
        $body = @{Command = $Command}
        if ($Module) { $body.Module = $Module }
        if ($Arguments) { $body.Arguments = $Arguments }
        
        return $this.InvokeAPI("/execute", "POST", $body)
    }
    
    [object] TriggerDeployment([string]$Environment, [string]$Version) {
        return $this.InvokeAPI("/api/deploy/execute", "POST", @{
            Environment = $Environment
            Version = $Version
        })
    }
}

# Usage example
$api = [AitherZeroAPIClient]::new("http://aitherzero-api:8080", "aitherzero-admin")
$status = $api.GetStatus()
$result = $api.ExecuteCommand("Get-VM", "Hyper-V")
```

### Code Snippets

#### Custom Endpoint Handler
```powershell
# Example custom endpoint handler
function Get-CustomSystemInfo {
    param($Request)
    
    try {
        # Parse query parameters
        $query = [System.Web.HttpUtility]::ParseQueryString($Request.Url.Query)
        $includeDetails = $query['details'] -eq 'true'
        
        # Gather system information
        $systemInfo = @{
            ComputerName = $env:COMPUTERNAME
            OS = (Get-CimInstance Win32_OperatingSystem).Caption
            Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        }
        
        if ($includeDetails) {
            $systemInfo.Memory = @{
                TotalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                AvailableGB = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB / 1024, 2)
            }
            
            $systemInfo.Processor = (Get-CimInstance Win32_Processor).Name
            $systemInfo.Disks = Get-CimInstance Win32_LogicalDisk | ForEach-Object {
                @{
                    Drive = $_.DeviceID
                    SizeGB = [math]::Round($_.Size / 1GB, 2)
                    FreeGB = [math]::Round($_.FreeSpace / 1GB, 2)
                }
            }
        }
        
        return @{
            Success = $true
            Data = $systemInfo
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        }
    }
}

# Register the custom endpoint
Register-APIEndpoint -Path "/api/system/info" `
    -Method "GET" `
    -Handler "Get-CustomSystemInfo" `
    -Description "Custom system information endpoint"
```

#### Middleware Implementation
```powershell
# Custom authentication middleware
function Invoke-CustomAuthentication {
    param($Request, $RequiredRole = "User")
    
    $authHeader = $Request.Headers["Authorization"]
    if (-not $authHeader -or -not $authHeader.StartsWith("Bearer ")) {
        return @{Success = $false; Message = "Bearer token required"}
    }
    
    $token = $authHeader.Substring(7)
    
    try {
        # Validate token with your authentication service
        $userInfo = Invoke-RestMethod -Uri "https://auth.company.com/validate" `
            -Headers @{"Authorization" = "Bearer $token"}
        
        # Check role authorization
        if ($userInfo.Role -ne $RequiredRole -and $RequiredRole -ne "User") {
            return @{Success = $false; Message = "Insufficient permissions"}
        }
        
        return @{
            Success = $true
            User = $userInfo
        }
        
    } catch {
        return @{Success = $false; Message = "Invalid token"}
    }
}
```

## Configuration

### Server Configuration

#### Default Configuration
```powershell
$script:APIConfiguration = @{
    Port = 8080
    Protocol = 'HTTP'
    SSLEnabled = $false
    Authentication = 'ApiKey'
    CorsEnabled = $true
    RateLimiting = $true
    LoggingEnabled = $true
    RequestTimeout = 30
    MaxConcurrentRequests = 100
}
```

#### SSL Configuration
```powershell
# Configure SSL certificate
$sslConfig = @{
    CertificatePath = "C:\Certificates\aitherzero-api.pfx"
    CertificatePassword = "certificate-password"
    Protocol = "TLS12"
    RequireClientCertificate = $false
}

Start-AitherZeroAPI -EnableSSL -CertificatePath $sslConfig.CertificatePath
```

### API Key Management

#### Default API Keys
- `aitherzero-admin`: Full administrative access
- `aitherzero-readonly`: Read-only access

#### Custom API Key Configuration
```powershell
# Configure custom API keys
$apiKeys = @{
    "monitoring-system" = @{Role = "Monitor"; Permissions = @("read", "health")}
    "ci-cd-pipeline" = @{Role = "Deploy"; Permissions = @("read", "write", "execute")}
    "backup-service" = @{Role = "Backup"; Permissions = @("read", "backup")}
}

# Store in secure configuration
$apiKeys | ConvertTo-Json | Set-Content -Path "$env:APPDATA\AitherZero\api-keys.json"
```

### CORS Configuration

#### Default CORS Settings
```powershell
$corsConfig = @{
    AllowedOrigins = @("*")
    AllowedMethods = @("GET", "POST", "PUT", "DELETE", "OPTIONS")
    AllowedHeaders = @("Content-Type", "Authorization", "X-API-Key")
    MaxAge = 86400  # 24 hours
}
```

#### Custom CORS for Production
```powershell
$productionCors = @{
    AllowedOrigins = @(
        "https://dashboard.company.com",
        "https://monitoring.company.com",
        "https://ci.company.com"
    )
    AllowedMethods = @("GET", "POST", "OPTIONS")
    AllowedHeaders = @("Content-Type", "Authorization")
    AllowCredentials = $true
}
```

## Security Considerations

### Authentication Methods

#### Secure API Key Storage
```powershell
# Store API keys securely using SecureCredentials module
function New-SecureAPIKey {
    param(
        [string]$KeyName,
        [string]$Role,
        [string[]]$Permissions
    )
    
    # Generate secure random key
    $keyBytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
    $apiKey = [Convert]::ToBase64String($keyBytes)
    
    # Store key metadata
    $keyData = @{
        Key = $apiKey
        Role = $Role
        Permissions = $Permissions
        Created = Get-Date
        LastUsed = $null
        Active = $true
    }
    
    # Store securely
    Import-Module SecureCredentials
    New-SecureCredential -CredentialName "API-Key-$KeyName" `
        -Username $KeyName `
        -Password (ConvertTo-SecureString ($keyData | ConvertTo-Json) -AsPlainText -Force)
    
    return $apiKey
}
```

#### JWT Token Support
```powershell
# JWT token validation
function Test-JWTToken {
    param([string]$Token, [string]$Secret)
    
    try {
        # Parse JWT token (simplified example)
        $tokenParts = $Token.Split('.')
        if ($tokenParts.Count -ne 3) {
            return @{Valid = $false; Message = "Invalid token format"}
        }
        
        # Decode header and payload
        $header = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($tokenParts[0]))
        $payload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($tokenParts[1]))
        
        $headerObj = $header | ConvertFrom-Json
        $payloadObj = $payload | ConvertFrom-Json
        
        # Check expiration
        $expiry = [DateTimeOffset]::FromUnixTimeSeconds($payloadObj.exp)
        if ($expiry -lt [DateTimeOffset]::Now) {
            return @{Valid = $false; Message = "Token expired"}
        }
        
        # Verify signature (implement proper HMAC verification)
        # This is a simplified example
        
        return @{
            Valid = $true
            User = $payloadObj.sub
            Role = $payloadObj.role
            Permissions = $payloadObj.permissions
        }
        
    } catch {
        return @{Valid = $false; Message = "Token validation failed"}
    }
}
```

### Encryption Options

#### Request/Response Encryption
```powershell
# Configure SSL/TLS encryption
$sslOptions = @{
    Protocol = [System.Security.Authentication.SslProtocols]::Tls12
    ClientCertificateRequired = $false
    CheckCertificateRevocation = $true
    EncryptionPolicy = [System.Net.Security.EncryptionPolicy]::RequireEncryption
}
```

#### Webhook Signature Validation
```powershell
function New-WebhookSignature {
    param(
        [hashtable]$Payload,
        [string]$Secret
    )
    
    $payloadJson = $Payload | ConvertTo-Json -Compress
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
    $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($secretBytes)
    $hash = $hmac.ComputeHash($payloadBytes)
    $signature = [Convert]::ToHexString($hash).ToLower()
    
    return "sha256=$signature"
}

function Test-WebhookSignature {
    param(
        [string]$Payload,
        [string]$Signature,
        [string]$Secret
    )
    
    $expectedSignature = New-WebhookSignature -Payload ($Payload | ConvertFrom-Json) -Secret $Secret
    return $Signature -eq $expectedSignature
}
```

### Best Practices

1. **Use HTTPS in production** with valid SSL certificates
2. **Implement proper authentication** - avoid "None" authentication mode
3. **Validate all input** to prevent injection attacks
4. **Use rate limiting** to prevent abuse
5. **Log all API requests** for audit purposes
6. **Rotate API keys regularly**
7. **Implement proper CORS** policies for web applications
8. **Use webhook signatures** to verify authenticity

### Security Example
```powershell
function Start-SecureAPI {
    param(
        [string]$CertificatePath,
        [string]$CertificatePassword,
        [switch]$ProductionMode
    )
    
    if ($ProductionMode) {
        # Production security settings
        $config = @{
            Port = 443
            EnableSSL = $true
            CertificatePath = $CertificatePath
            AuthenticationMethod = "Bearer"
            EnableCORS = $true
            EnableRateLimit = $true
        }
        
        # Restricted CORS for production
        $corsConfig = @{
            AllowedOrigins = @("https://dashboard.company.com")
            AllowedMethods = @("GET", "POST")
            AllowCredentials = $true
        }
        
        # Enable comprehensive logging
        $logConfig = @{
            LogLevel = "INFO"
            LogRequests = $true
            LogResponses = $false  # Don't log response bodies for security
            LogAuthentication = $true
        }
        
    } else {
        # Development security settings
        $config = @{
            Port = 8080
            AuthenticationMethod = "ApiKey"
            EnableCORS = $true
            EnableRateLimit = $false
        }
    }
    
    Start-AitherZeroAPI @config
    
    # Set up security monitoring
    Add-WebhookSubscription -Url "https://security.company.com/api/alerts" `
        -Events @("authentication.failed", "rate.limit.exceeded") `
        -Description "Security monitoring"
}
```

## Troubleshooting

### Common Issues

#### Port Already in Use
```powershell
# Check if port is in use
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

# Find process using the port
Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess

# Use alternative port
Start-AitherZeroAPI -Port 8081
```

#### SSL Certificate Issues
```powershell
# Verify SSL certificate
$cert = Get-PfxCertificate -FilePath "C:\certs\api.pfx"
$cert | Format-List Subject, NotAfter, HasPrivateKey

# Test certificate binding
netsh http show sslcert ipport=0.0.0.0:443

# Create self-signed certificate for testing
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My"
Export-PfxCertificate -Cert $cert -FilePath "C:\temp\test.pfx" -Password (ConvertTo-SecureString "password" -AsPlainText -Force)
```

#### Authentication Failures
```powershell
# Debug authentication issues
$VerbosePreference = 'Continue'
Start-AitherZeroAPI -AuthenticationMethod "ApiKey" -Verbose

# Test API key validation
$testKey = "aitherzero-admin"
$headers = @{"X-API-Key" = $testKey}
Invoke-RestMethod -Uri "http://localhost:8080/health" -Headers $headers

# Check authentication logs
Get-APIStatus -Detailed | Select-Object -ExpandProperty AuthenticationMetrics
```

### Diagnostic Commands

```powershell
# Comprehensive API diagnostics
function Get-APIDiagnostics {
    Write-Host "AitherZero API Server Diagnostics" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    
    # Server status
    Write-Host "`nServer Status:" -ForegroundColor Yellow
    try {
        $status = Get-APIStatus -Detailed
        $status | Format-List
    } catch {
        Write-Host "  API Server not running" -ForegroundColor Red
    }
    
    # Port availability
    Write-Host "`nPort Availability:" -ForegroundColor Yellow
    $commonPorts = @(8080, 443, 80, 8081, 8443)
    foreach ($port in $commonPorts) {
        $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($connection) {
            $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
            Write-Host "  Port $port`: In use by $($process.ProcessName)" -ForegroundColor Red
        } else {
            Write-Host "  Port $port`: Available" -ForegroundColor Green
        }
    }
    
    # Registered endpoints
    Write-Host "`nRegistered Endpoints:" -ForegroundColor Yellow
    try {
        $endpoints = Get-APIEndpoints
        $endpoints | Format-Table Path, Method, Description -AutoSize
    } catch {
        Write-Host "  No endpoints registered or server not running" -ForegroundColor Yellow
    }
    
    # Webhook subscriptions
    Write-Host "`nWebhook Subscriptions:" -ForegroundColor Yellow
    try {
        $webhooks = Get-WebhookSubscriptions
        if ($webhooks) {
            $webhooks | Format-Table Url, Events, Active -AutoSize
        } else {
            Write-Host "  No webhook subscriptions" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Cannot retrieve webhook subscriptions" -ForegroundColor Yellow
    }
    
    # Network connectivity
    Write-Host "`nNetwork Connectivity:" -ForegroundColor Yellow
    $testUrls = @("http://localhost:8080/health", "https://localhost:443/health")
    foreach ($url in $testUrls) {
        try {
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 5 -ErrorAction Stop
            Write-Host "  $url`: OK" -ForegroundColor Green
        } catch {
            Write-Host "  $url`: Failed ($($_.Exception.Message))" -ForegroundColor Red
        }
    }
    
    # System resources
    Write-Host "`nSystem Resources:" -ForegroundColor Yellow
    $cpu = Get-Counter "\Processor(_Total)\% Processor Time" | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
    $memory = Get-CimInstance Win32_OperatingSystem
    $memoryUsed = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
    
    Write-Host "  CPU Usage: $([math]::Round($cpu, 2))%" -ForegroundColor $(if ($cpu -gt 80) {"Red"} elseif ($cpu -gt 60) {"Yellow"} else {"Green"})
    Write-Host "  Memory Usage: $memoryUsed%" -ForegroundColor $(if ($memoryUsed -gt 80) {"Red"} elseif ($memoryUsed -gt 60) {"Yellow"} else {"Green"})
}

# Run diagnostics
Get-APIDiagnostics
```

### Recovery Procedures

#### Reset API Server
```powershell
function Reset-APIServer {
    param([switch]$Force)
    
    if (-not $Force) {
        $confirm = Read-Host "This will stop the API server and reset configuration. Continue? (y/N)"
        if ($confirm -ne 'y') { return }
    }
    
    Write-Host "Resetting API server..." -ForegroundColor Yellow
    
    # Stop server
    try {
        Stop-AitherZeroAPI -Force
        Write-Host "API server stopped" -ForegroundColor Green
    } catch {
        Write-Host "Failed to stop server: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Clear registered endpoints
    $script:RegisteredEndpoints.Clear()
    
    # Clear webhook subscriptions
    $script:WebhookSubscriptions.Clear()
    
    # Reset configuration to defaults
    $script:APIConfiguration = @{
        Port = 8080
        Protocol = 'HTTP'
        SSLEnabled = $false
        Authentication = 'ApiKey'
        CorsEnabled = $true
        RateLimiting = $true
        LoggingEnabled = $true
    }
    
    Write-Host "API server reset complete" -ForegroundColor Green
}
```

#### Emergency Stop
```powershell
function Stop-APIEmergency {
    Write-Host "Emergency API server shutdown..." -ForegroundColor Red
    
    # Force stop background job
    if ($script:APIServerJob) {
        Stop-Job -Job $script:APIServerJob -Force
        Remove-Job -Job $script:APIServerJob -Force
    }
    
    # Kill any remaining processes
    Get-Process | Where-Object ProcessName -Like "*AitherZero*" | Stop-Process -Force
    
    # Release port bindings
    $commonPorts = @(8080, 443, 80)
    foreach ($port in $commonPorts) {
        try {
            netsh http delete urlacl url="http://+:$port/"
            netsh http delete urlacl url="https://+:$port/"
        } catch {
            # Ignore errors
        }
    }
    
    Write-Host "Emergency shutdown complete" -ForegroundColor Yellow
}
```