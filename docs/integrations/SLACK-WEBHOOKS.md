# Slack Webhook Integration

This document describes how to configure and use Slack webhook integrations in AitherZero for automated notifications.

## Overview

AitherZero supports Slack webhook notifications for key events such as container builds, deployments, and releases. Notifications are fully configurable via the `config.psd1` manifest.

## Features

- ✅ **Configurable webhooks** - All webhook URLs managed in `config.psd1`
- ✅ **Container build notifications** - Automatic notifications when containers are built
- ✅ **Graceful degradation** - Falls back to defaults if config unavailable
- ✅ **Rich notifications** - Includes image tags, digests, package URLs, and pull commands
- ✅ **Enable/disable per webhook** - Fine-grained control over notifications
- ✅ **Template for extensions** - Easy to add new webhook types

## Configuration

### Location

All Slack webhook configurations are in `config.psd1` under the `Integrations.Slack` section.

**🔒 Security Note**: The `Url` field in `config.psd1` is intentionally empty. Set your webhook URL using:
- **GitHub Secrets**: `SLACK_WEBHOOK_URL` (for CI/CD workflows)
- **Local Override**: `config.local.psd1` (for local development, gitignored)

```powershell
Integrations = @{
    Slack = @{
        Enabled = $true
        Webhooks = @{
            ContainerBuilds = @{
                Enabled = $true
                Url = ''  # Set via SLACK_WEBHOOK_URL secret or config.local.psd1
                PayloadKey = 'aitherzero_new_build'
                NotifyOnSuccess = $true
                NotifyOnFailure = $false
                IncludeDetails = $true
            }
            General = @{
                Enabled = $false
                Url = ''
                PayloadKey = 'message'
            }
        }
    }
}
```

### Configuration Options

#### Slack Level Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Enabled` | Boolean | `$true` | Master switch for all Slack integrations |

#### Webhook Settings

Each webhook type (e.g., `ContainerBuilds`, `General`) supports:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Enabled` | Boolean | Varies | Enable/disable this specific webhook |
| `Url` | String | Required | Slack webhook URL (trigger or incoming webhook) |
| `PayloadKey` | String | Required | JSON key for the message payload |
| `NotifyOnSuccess` | Boolean | `$true` | Send notification on successful events |
| `NotifyOnFailure` | Boolean | `$false` | Send notification on failed events |
| `IncludeDetails` | Boolean | `$true` | Include detailed information in notifications |

## Available Webhook Types

### Container Builds

**Purpose**: Notifies when Docker containers are built and published

**Trigger**: Automatically triggered by `.github/workflows/deploy-pr-environment.yml` after successful container builds

**Notification Content**:
- Build type (PR or Release)
- Version/PR number
- Container image tag
- Image digest
- Package URL (GitHub Container Registry)
- Commit SHA
- Docker pull command

**Example Message**:
```
New AitherZero container build completed!

**Type:** PR
**Version:** PR #123
**Image:** `ghcr.io/wizzense/aitherzero:pr-123`
**Digest:** `sha256:abc123...`
**Package:** https://github.com/wizzense/AitherZero/pkgs/container/aitherzero
**Commit:** abc123def456

Pull command: `docker pull ghcr.io/wizzense/aitherzero:pr-123`
```

### General (Template)

**Purpose**: Template for general-purpose notifications

**Status**: Disabled by default - configure as needed

## Setting Up Slack Webhooks

### Security Best Practice

**⚠️ IMPORTANT**: Never commit webhook URLs to version control. Use one of these secure methods:

#### Method 1: GitHub Secrets (Recommended for CI/CD)

1. Go to your repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `SLACK_WEBHOOK_URL`
4. Value: Your Slack webhook URL
5. The workflow will automatically use this secret

#### Method 2: Local Config Override (For Local Development)

1. Copy `config.local.psd1.example` to `config.local.psd1`
2. Edit `config.local.psd1` and set your webhook URL
3. This file is gitignored and won't be committed

### Option 1: Slack Workflow Builder (Recommended)

1. Go to your Slack workspace
2. Open **Workflow Builder** (Tools → Workflow Builder)
3. Click **Create** → **From Webhook**
4. Configure the webhook:
   - Name: "AitherZero Container Builds"
   - Add variable: `aitherzero_new_build` (text)
5. Add a **Send a message** step
6. Configure the message template using the variable
7. Save and get the webhook URL
8. Copy the URL to `config.psd1`

### Option 2: Incoming Webhooks App

1. Go to your Slack workspace
2. Navigate to **Apps** → **Incoming Webhooks**
3. Click **Add to Slack**
4. Select a channel for notifications
5. Copy the webhook URL
6. Update `config.psd1` with the URL and set `PayloadKey = 'text'`

## Usage in Workflows

The Slack webhook integration is automatically used in GitHub Actions workflows. Here's how it works:

### In `deploy-pr-environment.yml`

The workflow securely accesses the webhook URL from GitHub Secrets:

```yaml
- name: 📢 Notify Slack of New Build
  if: success()
  shell: pwsh
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}  # Secure secret
  run: |
    # Load configuration
    Import-Module ./AitherZero.psd1
    $config = Get-Configuration
    
    # Get webhook URL from environment (GitHub secret)
    $webhookUrl = $env:SLACK_WEBHOOK_URL
    
    # Get other settings from config
    $webhookConfig = $config.Integrations.Slack.Webhooks.ContainerBuilds
    
    # Send notification if enabled
    if ($webhookConfig.Enabled -and $webhookUrl) {
      Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload
    }
```

**Priority Order**:
1. GitHub Secret (`SLACK_WEBHOOK_URL`) - Used in CI/CD
2. Local config (`config.local.psd1`) - Used for local testing
3. Disabled if neither is set

### In PowerShell Scripts

You can also use the webhook integration in your automation scripts:

```powershell
# Load configuration
$config = Get-Configuration

# Check if Slack is enabled
if ($config.Integrations.Slack.Enabled) {
    $webhook = $config.Integrations.Slack.Webhooks.ContainerBuilds
    
    if ($webhook.Enabled) {
        $payload = @{
            $webhook.PayloadKey = "Your notification message here"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $webhook.Url -Method Post -Body $payload -ContentType 'application/json'
    }
}
```

## Disabling Notifications

### Disable All Slack Notifications

Set `Integrations.Slack.Enabled = $false` in `config.psd1`:

```powershell
Integrations = @{
    Slack = @{
        Enabled = $false  # Disables all Slack integrations
        # ...
    }
}
```

### Disable Specific Webhook

Set the webhook's `Enabled = $false`:

```powershell
Integrations = @{
    Slack = @{
        Enabled = $true
        Webhooks = @{
            ContainerBuilds = @{
                Enabled = $false  # Disables only container build notifications
                # ...
            }
        }
    }
}
```

## Troubleshooting

### Notifications Not Sending

1. **Check configuration**:
   ```powershell
   $config = Get-Configuration
   $config.Integrations.Slack.Enabled
   $config.Integrations.Slack.Webhooks.ContainerBuilds.Enabled
   ```

2. **Verify webhook URL**:
   - Ensure URL is valid
   - Test with `curl` or `Invoke-RestMethod`
   - Check Slack workspace settings

3. **Check workflow logs**:
   - View GitHub Actions workflow run
   - Look for "📢 Notify Slack of New Build" step
   - Check for error messages

### Message Format Issues

1. **Wrong payload key**: Ensure `PayloadKey` matches your Slack webhook configuration
2. **Special characters**: Markdown formatting may need escaping
3. **Message length**: Very long messages may be truncated

### Webhook URL Expired

1. Regenerate webhook in Slack Workflow Builder
2. Update URL in `config.psd1`
3. Commit and push changes
4. Next build will use new URL

## Extending the Integration

### Adding a New Webhook Type

1. **Add configuration** in `config.psd1`:
   ```powershell
   Webhooks = @{
       # ... existing webhooks ...
       
       MyNewWebhook = @{
           Enabled = $true
           Url = 'https://hooks.slack.com/triggers/...'
           PayloadKey = 'my_notification'
           NotifyOnSuccess = $true
           NotifyOnFailure = $true
       }
   }
   ```

2. **Use in workflow** or script:
   ```powershell
   $webhook = $config.Integrations.Slack.Webhooks.MyNewWebhook
   if ($webhook.Enabled) {
       $payload = @{
           $webhook.PayloadKey = "Your message"
       } | ConvertTo-Json
       
       Invoke-RestMethod -Uri $webhook.Url -Method Post -Body $payload -ContentType 'application/json'
   }
   ```

### Adding Message Templates

Create reusable message templates in your scripts:

```powershell
function New-SlackBuildNotification {
    param(
        [string]$BuildType,
        [string]$Version,
        [string]$ImageTag,
        [string]$Commit
    )
    
    return @"
    New AitherZero build completed!
    
    **Type:** $BuildType
    **Version:** $Version
    **Image:** ``$ImageTag``
    **Commit:** $Commit
    "@
}

# Usage
$message = New-SlackBuildNotification -BuildType "Release" -Version "v1.0.0" -ImageTag "..." -Commit "..."
```

## Security Considerations

**🔒 Critical Security Requirements**

1. **Never commit webhook URLs** - These are credentials that provide access to your Slack workspace
2. **Use GitHub Secrets for CI/CD** - Set `SLACK_WEBHOOK_URL` in repository secrets
3. **Use local config for development** - Create `config.local.psd1` (gitignored) for local testing
4. **Rotate webhooks regularly** - Regenerate webhook URLs every 90 days
5. **Limit webhook permissions** - Use webhooks with minimal required access
6. **Monitor webhook usage** - Review Slack audit logs for unexpected activity
7. **Don't share URLs** - Each environment should have its own webhook

### Secure Setup Methods

#### For CI/CD (GitHub Actions):
```bash
# Repository Settings → Secrets → New secret
# Name: SLACK_WEBHOOK_URL
# Value: https://hooks.slack.com/triggers/...
```

#### For Local Development:
```powershell
# Copy the example file
cp config.local.psd1.example config.local.psd1

# Edit config.local.psd1 (gitignored)
# Set Integrations.Slack.Webhooks.ContainerBuilds.Url
```

### What NOT to Do

❌ **DON'T**: Commit webhook URLs in `config.psd1`
❌ **DON'T**: Share webhook URLs in public channels
❌ **DON'T**: Use the same webhook across multiple projects
❌ **DON'T**: Hardcode URLs in scripts

### What TO Do

✅ **DO**: Use GitHub Secrets for CI/CD
✅ **DO**: Use `config.local.psd1` for local development
✅ **DO**: Rotate webhooks regularly
✅ **DO**: Use separate webhooks per environment

## Examples

### Example 1: Container Build Success

When a PR container builds successfully:

```
New AitherZero container build completed!

**Type:** PR
**Version:** PR #1677
**Image:** `ghcr.io/wizzense/aitherzero:pr-1677`
**Digest:** `sha256:1234567890abcdef...`
**Package:** https://github.com/wizzense/AitherZero/pkgs/container/aitherzero
**Commit:** abc123def456789

Pull command: `docker pull ghcr.io/wizzense/aitherzero:pr-1677`
```

### Example 2: Release Build

When a release is published:

```
New AitherZero container build completed!

**Type:** Release
**Version:** v2.0.0
**Image:** `ghcr.io/wizzense/aitherzero:v2.0.0`
**Digest:** `sha256:fedcba0987654321...`
**Package:** https://github.com/wizzense/AitherZero/pkgs/container/aitherzero
**Commit:** def456abc789012

Pull command: `docker pull ghcr.io/wizzense/aitherzero:v2.0.0`
```

## Related Documentation

- [Container Deployment Guide](../PR-DEPLOYMENT-QUICKREF.md)
- [Configuration Management](../guides/CONFIGURATION-MANAGEMENT.md)
- [GitHub Actions Workflows](../../.github/workflows/README.md)
- [Other Integrations](./README.md)

## Support

For issues or questions:
- **Repository**: https://github.com/wizzense/AitherZero/issues
- **Configuration**: Check `config.psd1` validation with `./automation-scripts/0413_Validate-ConfigManifest.ps1`
- **Slack Setup**: Refer to Slack's [Workflow Builder documentation](https://slack.com/help/articles/360035692513-Guide-to-Workflow-Builder)
