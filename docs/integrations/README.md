# AitherZero External Integrations

This directory contains documentation for integrating AitherZero with external services and platforms.

## Overview

AitherZero supports various external integrations to extend its functionality and enable automated notifications, reporting, and workflow automation. All integrations are configured through the `config.psd1` manifest under the `Integrations` section.

## Available Integrations

### 🔔 Notification Services

#### Slack Webhooks
**Status**: ✅ Active  
**Documentation**: [SLACK-WEBHOOKS.md](./SLACK-WEBHOOKS.md)  
**Use Cases**: Container build notifications, deployment alerts, release announcements

Configure Slack webhooks for automated notifications:
- Container builds (PR and release)
- General purpose notifications (customizable)
- Fully configurable via `config.psd1`

#### Microsoft Teams (Planned)
**Status**: 📋 Placeholder  
**Configuration**: `Integrations.Teams` in `config.psd1`  
**Use Cases**: Deployment notifications, team alerts

#### Discord (Planned)
**Status**: 📋 Placeholder  
**Configuration**: `Integrations.Discord` in `config.psd1`  
**Use Cases**: Release announcements, community notifications

### 🔧 Custom Webhooks

**Status**: 📋 Template Available  
**Configuration**: `Integrations.CustomWebhooks` in `config.psd1`

Create custom webhook integrations for any service:
```powershell
CustomWebhooks = @{
    Enabled = $true
    Endpoints = @(
        @{
            Name = 'MyService'
            Url = 'https://example.com/webhook'
            Events = @('build', 'deploy', 'release')
            Enabled = $true
        }
    )
}
```

### 🏢 Enterprise Integrations

#### Tanium
**Status**: 📚 Documented  
**Documentation**: [tanium/](./tanium/)  
**Use Cases**: Security compliance, endpoint management

## Configuration

All integrations are configured in `config.psd1` under the `Integrations` section:

```powershell
# Location: config.psd1
Integrations = @{
    # Slack integration
    Slack = @{
        Enabled = $true
        Webhooks = @{
            ContainerBuilds = @{ ... }
            General = @{ ... }
        }
    }
    
    # Microsoft Teams (placeholder)
    Teams = @{
        Enabled = $false
        Webhooks = @{ ... }
    }
    
    # Discord (placeholder)
    Discord = @{
        Enabled = $false
        Webhooks = @{ ... }
    }
    
    # Custom webhooks
    CustomWebhooks = @{
        Enabled = $false
        Endpoints = @()
    }
}
```

### Validation

After modifying integration configurations, validate with:

```powershell
./automation-scripts/0413_Validate-ConfigManifest.ps1
```

## Quick Start

### 1. Enable an Integration

Edit `config.psd1` and set `Enabled = $true` for the desired integration:

```powershell
Integrations = @{
    Slack = @{
        Enabled = $true  # Enable Slack
        # ...
    }
}
```

### 2. Configure Webhook URL

Add your webhook URL:

```powershell
Webhooks = @{
    ContainerBuilds = @{
        Enabled = $true
        Url = 'https://hooks.slack.com/triggers/YOUR/WEBHOOK/URL'
        PayloadKey = 'aitherzero_new_build'
    }
}
```

### 3. Test the Integration

Push a change to trigger the workflow, or manually test:

```powershell
$config = Get-Configuration
$webhook = $config.Integrations.Slack.Webhooks.ContainerBuilds

$payload = @{
    $webhook.PayloadKey = "Test message from AitherZero"
} | ConvertTo-Json

Invoke-RestMethod -Uri $webhook.Url -Method Post -Body $payload -ContentType 'application/json'
```

## Integration Patterns

### Workflow Integration

Use in GitHub Actions workflows:

```yaml
- name: Send Notification
  shell: pwsh
  run: |
    Import-Module ./AitherZero.psd1
    $config = Get-Configuration
    
    $webhook = $config.Integrations.Slack.Webhooks.ContainerBuilds
    if ($webhook.Enabled) {
        # Send notification
        Invoke-RestMethod -Uri $webhook.Url -Method Post -Body $payload
    }
```

### Script Integration

Use in automation scripts:

```powershell
# Load configuration
$config = Get-Configuration

# Check if integration is enabled
if ($config.Integrations.Slack.Enabled) {
    $webhook = $config.Integrations.Slack.Webhooks.General
    
    if ($webhook.Enabled) {
        # Send notification
        $payload = @{
            $webhook.PayloadKey = "Your message here"
        } | ConvertTo-Json
        
        try {
            Invoke-RestMethod -Uri $webhook.Url -Method Post -Body $payload -ContentType 'application/json'
            Write-Host "✅ Notification sent"
        } catch {
            Write-Warning "Failed to send notification: $_"
        }
    }
}
```

## Security Best Practices

1. **Don't commit secrets** - Use local config overrides for webhook URLs
2. **Use environment variables** - Override URLs with `$env:AITHERZERO_SLACK_WEBHOOK`
3. **Rotate webhooks** - Regenerate webhook URLs periodically
4. **Limit permissions** - Use least-privilege webhook configurations
5. **Monitor usage** - Track webhook calls and failures

## Adding New Integrations

To add a new integration service:

1. **Update config.psd1**:
   ```powershell
   Integrations = @{
       # ... existing integrations ...
       
       NewService = @{
           Enabled = $false
           ApiKey = ''
           Endpoints = @{
               Notifications = @{
                   Enabled = $false
                   Url = ''
               }
           }
       }
   }
   ```

2. **Create documentation**: Add `docs/integrations/NEW-SERVICE.md`

3. **Implement in workflows**: Add notification steps to relevant workflows

4. **Add helper functions**: Create PowerShell functions for common operations

5. **Test thoroughly**: Validate configuration and test notifications

6. **Update this README**: Document the new integration

## Troubleshooting

### Common Issues

**Integration not working**:
1. Check `Enabled = $true` at both service and webhook levels
2. Validate webhook URL
3. Test with `curl` or `Invoke-RestMethod`
4. Check workflow logs for errors

**Configuration errors**:
1. Validate syntax: `./automation-scripts/0413_Validate-ConfigManifest.ps1`
2. Check for typos in section names
3. Ensure proper PowerShell hashtable syntax

**Notification not received**:
1. Verify webhook URL is current
2. Check service-specific logs (Slack, Teams, etc.)
3. Ensure network connectivity
4. Review payload format

### Getting Help

- **Configuration validation**: `./automation-scripts/0413_Validate-ConfigManifest.ps1`
- **GitHub Issues**: https://github.com/wizzense/AitherZero/issues
- **Workflow logs**: Check GitHub Actions run details
- **Integration docs**: See service-specific documentation

## Examples

### Slack Container Build Notification

```powershell
# Automatically sent by deploy-pr-environment.yml
New AitherZero container build completed!

**Type:** PR
**Version:** PR #123
**Image:** `ghcr.io/wizzense/aitherzero:pr-123`
**Package:** https://github.com/.../pkgs/container/aitherzero
```

### Custom Webhook for Monitoring

```powershell
# Add to config.psd1
CustomWebhooks = @{
    Enabled = $true
    Endpoints = @(
        @{
            Name = 'Datadog'
            Url = 'https://api.datadoghq.com/api/v1/events'
            Events = @('build', 'deploy')
            Enabled = $true
            Headers = @{
                'DD-API-KEY' = $env:DATADOG_API_KEY
            }
        }
    )
}
```

## Roadmap

### Planned Integrations

- [ ] **Microsoft Teams** - Deployment notifications
- [ ] **Discord** - Release announcements
- [ ] **PagerDuty** - Incident management
- [ ] **Datadog** - Metrics and monitoring
- [ ] **Splunk** - Log aggregation
- [ ] **Jira** - Issue tracking
- [ ] **Email** - SMTP notifications

### Enhancement Ideas

- [ ] Integration health monitoring
- [ ] Retry logic for failed webhooks
- [ ] Message templating system
- [ ] Rate limiting configuration
- [ ] Batch notification support
- [ ] Integration testing framework

## Contributing

To contribute new integrations:

1. Create integration documentation
2. Update `config.psd1` with configuration schema
3. Implement in relevant workflows/scripts
4. Add tests for configuration validation
5. Submit PR with examples and documentation

## Related Documentation

- [Configuration Management](../guides/CONFIGURATION-MANAGEMENT.md)
- [GitHub Actions Workflows](../../.github/workflows/README.md)
- [PR Deployment Guide](../PR-DEPLOYMENT-QUICKREF.md)
- [Automation Scripts](../../automation-scripts/README.md)

## Support

For questions or issues with integrations:
- **GitHub Issues**: https://github.com/wizzense/AitherZero/issues
- **Documentation**: Check service-specific docs in this directory
- **Validation**: Run `./automation-scripts/0413_Validate-ConfigManifest.ps1`

---

*Last updated: 2025-11-03*
