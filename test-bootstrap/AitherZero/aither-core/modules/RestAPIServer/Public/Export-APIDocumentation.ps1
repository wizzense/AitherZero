<#
.SYNOPSIS
    Exports API documentation for all registered endpoints.

.DESCRIPTION
    Export-APIDocumentation generates comprehensive API documentation
    including endpoint details, authentication requirements, parameters,
    and examples in various formats.

.PARAMETER OutputPath
    The path to save the documentation file.

.PARAMETER Format
    Output format: Markdown, HTML, JSON, or OpenAPI.

.PARAMETER IncludeExamples
    Include usage examples in the documentation.

.PARAMETER IncludeBuiltIn
    Include built-in system endpoints in the documentation.

.PARAMETER IncludeWebhooks
    Include webhook documentation.

.PARAMETER Template
    Custom template file for formatting (for HTML/Markdown formats).

.EXAMPLE
    Export-APIDocumentation -OutputPath "api-docs.md" -Format Markdown -IncludeExamples
    Exports documentation as Markdown with examples.

.EXAMPLE
    Export-APIDocumentation -OutputPath "api-spec.json" -Format OpenAPI -IncludeBuiltIn
    Exports OpenAPI specification including built-in endpoints.

.EXAMPLE
    Export-APIDocumentation -OutputPath "docs.html" -Format HTML -IncludeWebhooks
    Exports HTML documentation including webhook information.
#>
function Export-APIDocumentation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [ValidateSet('Markdown', 'HTML', 'JSON', 'OpenAPI')]
        [string]$Format = 'Markdown',
        
        [Parameter()]
        [switch]$IncludeExamples,
        
        [Parameter()]
        [switch]$IncludeBuiltIn,
        
        [Parameter()]
        [switch]$IncludeWebhooks,
        
        [Parameter()]
        [string]$Template
    )

    begin {
        Write-CustomLog -Message "Exporting API documentation to: $OutputPath" -Level "INFO"
    }

    process {
        try {
            # Get all endpoints
            $endpoints = Get-APIEndpoints -IncludeBuiltIn:$IncludeBuiltIn -Format List
            
            # Get API configuration
            $config = Get-APIConfiguration -Format List
            
            # Get webhook information if requested
            $webhookInfo = $null
            if ($IncludeWebhooks) {
                $webhookInfo = @{
                    Enabled = $script:APIConfiguration.WebhookConfig.Enabled
                    SupportedEvents = $script:APIConfiguration.WebhookConfig.Events
                    SubscriptionCount = $script:WebhookSubscriptions.Count
                    Subscriptions = if ($script:WebhookSubscriptions.Count -gt 0) {
                        Get-WebhookSubscriptions -Format List
                    } else { @() }
                }
            }
            
            # Generate documentation based on format
            $documentation = $null
            
            switch ($Format) {
                'Markdown' {
                    $documentation = @"
# AitherZero REST API Documentation

Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Overview

This document describes the REST API endpoints available in the AitherZero automation platform.

### Base Configuration

- **Server Status**: $(if (Test-APIServerRunning) { "Running" } else { "Stopped" })
- **Port**: $($config.Port)
- **Protocol**: $($config.Protocol)
- **Authentication**: $($config.Authentication)
- **CORS Enabled**: $($config.CorsEnabled)
- **Rate Limiting**: $($config.RateLimiting)

## Authentication

$(if ($config.Authentication -ne 'None') {
    "API requests require authentication. Include the Authorization header with your requests:"
    ""
    "```"
    "Authorization: Bearer YOUR_API_TOKEN"
    "```"
} else {
    "No authentication required for API requests."
})

## Endpoints

"@
                    
                    foreach ($endpoint in $endpoints) {
                        $documentation += @"

### $($endpoint.Method) $($endpoint.Path)

**Description**: $($endpoint.Description)

**Authentication Required**: $(if ($endpoint.Authentication) { "Yes" } else { "No" })

$(if ($endpoint.AllowedRoles.Count -gt 0) {
    "**Required Roles**: $($endpoint.AllowedRoles -join ', ')"
})

$(if ($endpoint.Parameters.Count -gt 0) {
    "**Parameters**:"
    ""
    foreach ($param in $endpoint.Parameters) {
        "- `$param`: Parameter description"
    }
    ""
})

$(if ($IncludeExamples) {
    "**Example Request**:"
    ""
    "```bash"
    "curl -X $($endpoint.Method) http://localhost:$($config.Port)$($endpoint.Path) \"
    if ($endpoint.Authentication) {
        "  -H 'Authorization: Bearer YOUR_TOKEN' \"
    }
    if ($endpoint.Method -in @('POST', 'PUT', 'PATCH')) {
        "  -H 'Content-Type: application/json' \"
        "  -d '{\"parameter\": \"value\"}'"
    }
    "```"
    ""
})

"@
                    }
                    
                    if ($IncludeWebhooks -and $webhookInfo) {
                        $documentation += @"

## Webhooks

Webhooks allow external systems to receive real-time notifications about events in AitherZero.

### Configuration

- **Enabled**: $($webhookInfo.Enabled)
- **Active Subscriptions**: $($webhookInfo.SubscriptionCount)

### Supported Events

$(foreach ($event in $webhookInfo.SupportedEvents) {
    "- `$event`"
})

### Webhook Payload Format

```json
{
  "event": "event.name",
  "timestamp": "2023-01-01T12:00:00Z",
  "data": {
    // Event-specific data
  },
  "source": "AitherZero-RestAPI",
  "priority": "Normal",
  "version": "1.0.0",
  "delivery_id": "uuid"
}
```

### Security

Webhook payloads can be signed using HMAC-SHA256. The signature is included in the `X-Webhook-Signature` header.

"@
                    }
                }
                
                'HTML' {
                    $documentation = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero REST API Documentation</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1, h2, h3 { color: #333; }
        code { background: #f4f4f4; padding: 2px 5px; border-radius: 3px; }
        pre { background: #f4f4f4; padding: 10px; border-radius: 5px; overflow-x: auto; }
        .endpoint { border: 1px solid #ddd; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .method { font-weight: bold; color: #fff; padding: 2px 8px; border-radius: 3px; }
        .get { background: #61affe; }
        .post { background: #49cc90; }
        .put { background: #fca130; }
        .delete { background: #f93e3e; }
        .patch { background: #50e3c2; }
    </style>
</head>
<body>
    <h1>AitherZero REST API Documentation</h1>
    <p><strong>Generated on:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    
    <h2>Overview</h2>
    <ul>
        <li><strong>Server Status:</strong> $(if (Test-APIServerRunning) { "Running" } else { "Stopped" })</li>
        <li><strong>Port:</strong> $($config.Port)</li>
        <li><strong>Protocol:</strong> $($config.Protocol)</li>
        <li><strong>Authentication:</strong> $($config.Authentication)</li>
    </ul>
    
    <h2>Endpoints</h2>
"@
                    
                    foreach ($endpoint in $endpoints) {
                        $methodClass = $endpoint.Method.ToLower()
                        $documentation += @"
    <div class="endpoint">
        <h3><span class="method $methodClass">$($endpoint.Method)</span> $($endpoint.Path)</h3>
        <p><strong>Description:</strong> $($endpoint.Description)</p>
        <p><strong>Authentication Required:</strong> $(if ($endpoint.Authentication) { "Yes" } else { "No" })</p>
        $(if ($endpoint.AllowedRoles.Count -gt 0) {
            "<p><strong>Required Roles:</strong> $($endpoint.AllowedRoles -join ', ')</p>"
        })
    </div>
"@
                    }
                    
                    $documentation += "</body></html>"
                }
                
                'JSON' {
                    $docData = @{
                        metadata = @{
                            title = "AitherZero REST API Documentation"
                            version = "1.0.0"
                            generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                            serverStatus = if (Test-APIServerRunning) { "running" } else { "stopped" }
                        }
                        configuration = $config
                        endpoints = $endpoints
                    }
                    
                    if ($IncludeWebhooks) {
                        $docData.webhooks = $webhookInfo
                    }
                    
                    $documentation = $docData | ConvertTo-Json -Depth 10
                }
                
                'OpenAPI' {
                    $openApiSpec = @{
                        openapi = "3.0.0"
                        info = @{
                            title = "AitherZero REST API"
                            version = "1.0.0"
                            description = "REST API for AitherZero automation platform"
                        }
                        servers = @(
                            @{
                                url = "$($config.Protocol.ToLower())://localhost:$($config.Port)"
                                description = "Local AitherZero API server"
                            }
                        )
                        paths = @{}
                        components = @{
                            securitySchemes = @{}
                        }
                    }
                    
                    # Add security schemes
                    if ($config.Authentication -eq 'Bearer') {
                        $openApiSpec.components.securitySchemes.bearerAuth = @{
                            type = "http"
                            scheme = "bearer"
                        }
                    }
                    
                    # Add paths
                    foreach ($endpoint in $endpoints) {
                        if (-not $openApiSpec.paths.ContainsKey($endpoint.Path)) {
                            $openApiSpec.paths[$endpoint.Path] = @{}
                        }
                        
                        $pathItem = @{
                            summary = $endpoint.Description
                            description = $endpoint.Description
                            responses = @{
                                "200" = @{
                                    description = "Successful response"
                                    content = @{
                                        "application/json" = @{
                                            schema = @{
                                                type = "object"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ($endpoint.Authentication) {
                            $pathItem.security = @(
                                @{ bearerAuth = @() }
                            )
                        }
                        
                        $openApiSpec.paths[$endpoint.Path][$endpoint.Method.ToLower()] = $pathItem
                    }
                    
                    $documentation = $openApiSpec | ConvertTo-Json -Depth 10
                }
            }
            
            # Save documentation to file
            $documentation | Out-File -FilePath $OutputPath -Encoding UTF8
            
            $fileSizeKB = [math]::Round((Get-Item $OutputPath).Length / 1KB, 2)
            
            Write-CustomLog -Message "API documentation exported successfully: $OutputPath ($fileSizeKB KB)" -Level "SUCCESS"
            
            return @{
                Success = $true
                OutputPath = $OutputPath
                Format = $Format
                FileSizeKB = $fileSizeKB
                EndpointCount = $endpoints.Count
                IncludedBuiltIn = $IncludeBuiltIn.IsPresent
                IncludedWebhooks = $IncludeWebhooks.IsPresent
                IncludedExamples = $IncludeExamples.IsPresent
                Message = "Documentation exported successfully"
            }
            
        } catch {
            $errorMessage = "Failed to export API documentation: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                OutputPath = $OutputPath
                Format = $Format
            }
        }
    }
}

Export-ModuleMember -Function Export-APIDocumentation