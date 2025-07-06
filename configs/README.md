# AitherZero Configuration Directory

This directory contains all configuration files for the AitherZero automation framework. The configuration system provides flexible, environment-specific settings for infrastructure automation, tool installation, and system management.

## Directory Structure

```
configs/
├── carousel/                    # Configuration carousel for multi-environment support
│   └── carousel-registry.json   # Registry of configurations and environments
├── labs/                        # Lab-specific configurations (currently empty)
├── core-runner-config.json      # Core runner configuration
├── default-config.json          # Default configuration with all available options
├── dynamic-repo-config.json     # Dynamic repository configuration
├── feature-registry.json        # Feature tiers and module registry
├── full-config.json            # Full configuration with all features enabled
├── integration-certification-config.json  # Integration certification requirements
├── iso-management-config.psd1   # ISO management PowerShell data file
└── recommended-config.json      # Recommended configuration for quick start
```

## Overview

The AitherZero configuration system uses a layered approach:

1. **Base Configuration**: `default-config.json` provides all available options with sensible defaults
2. **Profile-Based Configurations**: Pre-defined profiles for different use cases
3. **Environment-Specific Settings**: Carousel system enables switching between environments
4. **Dynamic Updates**: Configuration can be updated at runtime based on repository context

## Configuration Files

### default-config.json

The master configuration template containing all available options:

```json
{
  "UIPreferences": {
    "Mode": "auto",              # UI mode: auto, enhanced, classic
    "DefaultUI": "enhanced",     # Default UI to use
    "ShowUISelector": true       # Show UI selection dialog
  },
  "ComputerName": "default-lab",
  "SetComputerName": false,      # Whether to apply computer name
  "DNSServers": "8.8.8.8,1.1.1.1",
  "InstallGit": true,            # Install Git
  "InstallOpenTofu": false,      # Install OpenTofu/Terraform
  "HyperV": { ... },            # Hyper-V configuration
  "Node_Dependencies": { ... }   # Node.js and AI tools configuration
}
```

### core-runner-config.json

Simplified configuration for the core runner module. Similar structure to default-config.json but focused on essential settings for automated execution.

### full-config.json

Complete configuration with all features enabled. Ideal for:
- Development environments
- Full lab setups
- Testing all features

Key differences from default:
- All installation flags set to `true`
- System configuration changes enabled
- Additional tools like Sysinternals included

### recommended-config.json

Minimal configuration focusing on recommended tools:
```json
{
  "InstallGo": true,
  "InstallOpenTofu": true,
  "InstallHyperV": true,
  "InstallClaudeCode": true,
  "InstallGeminiCLI": true
}
```

### feature-registry.json

Defines feature tiers and module availability:
```json
{
  "tiers": {
    "free": { "features": ["core", "development"] },
    "pro": { "features": ["core", "development", "infrastructure", "ai"] },
    "enterprise": { "features": ["all"] }
  }
}
```

### integration-certification-config.json

Comprehensive certification requirements for third-party integrations:
- Certification levels: Basic, Standard, Enterprise
- Test categories: API compatibility, Security, Performance, Reliability
- Compliance frameworks: SOC2, ISO27001, NIST

### iso-management-config.psd1

PowerShell data file for ISO management configuration:
- ISO repository settings
- Download configurations for Windows/Linux ISOs
- Customization settings for unattended installations
- Integration with AitherCore modules

### dynamic-repo-config.json

Repository fork chain configuration:
```json
{
  "repository": {
    "owner": "wizzense",
    "name": "AitherZero",
    "type": "Development"
  }
}
```

## Usage

### Loading Configuration

```powershell
# Load default configuration
$config = Get-Content "configs/default-config.json" | ConvertFrom-Json

# Load with profile
./Start-AitherZero.ps1 -Setup -InstallationProfile full

# Use specific configuration
./Start-AitherZero.ps1 -ConfigFile "configs/recommended-config.json"
```

### Creating Custom Configurations

1. Copy `default-config.json` as a template
2. Modify settings as needed
3. Save with descriptive name (e.g., `production-config.json`)

Example custom configuration:
```json
{
  "ComputerName": "PROD-INFRA-01",
  "SetComputerName": true,
  "InstallOpenTofu": true,
  "OpenTofuVersion": "1.5.7",
  "HyperV": {
    "Host": "hyperv-cluster.domain.com",
    "Port": 5986,
    "UseNtlm": false
  }
}
```

### Configuration Precedence

1. Command-line parameters (highest priority)
2. Specified configuration file
3. Environment variables
4. Default configuration (lowest priority)

## Configuration Options

### System Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| ComputerName | string | "default-lab" | Computer name to set |
| SetComputerName | boolean | false | Apply computer name change |
| DNSServers | string | "8.8.8.8,1.1.1.1" | DNS servers (comma-separated) |
| SetDNSServers | boolean | false | Apply DNS configuration |
| DisableTCPIP6 | boolean | false | Disable IPv6 |
| AllowRemoteDesktop | boolean | false | Enable RDP |

### Tool Installation

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| InstallGit | boolean | true | Install Git |
| InstallPwsh | boolean | true | Install PowerShell 7 |
| InstallOpenTofu | boolean | false | Install OpenTofu |
| InstallHyperV | boolean | false | Install Hyper-V |
| InstallDockerDesktop | boolean | false | Install Docker Desktop |
| InstallVSCode | boolean | false | Install VS Code |

### AI Tools Integration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| InstallClaudeCode | boolean | false | Install Claude Code CLI |
| ClaudeCodeWSLUsername | string | "" | WSL username for Claude |
| InstallGeminiCLI | boolean | false | Install Gemini CLI |
| GeminiCLIWSLUsername | string | "" | WSL username for Gemini |

### Infrastructure Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| HyperV.Host | string | "" | Hyper-V host address |
| HyperV.Port | integer | 5986 | WinRM port |
| HyperV.Https | boolean | true | Use HTTPS |
| HyperV.Insecure | boolean | true | Skip certificate validation |

## Best Practices

### Configuration Naming Conventions

- Use descriptive names: `production-azure-config.json`
- Include environment: `dev-`, `staging-`, `prod-`
- Version configurations: `config-v2.json`

### Environment-Specific Configurations

Create separate configurations for each environment:
```
configs/
├── environments/
│   ├── dev-config.json
│   ├── staging-config.json
│   └── production-config.json
```

### Security Considerations

1. **Sensitive Data**: Never store passwords or secrets in configuration files
   - Use environment variables
   - Use secure credential management modules
   
2. **File Permissions**: Restrict access to configuration files
   ```powershell
   # Windows
   icacls "configs\production-config.json" /inheritance:r /grant:r "$env:USERNAME:(R)"
   
   # Linux/macOS
   chmod 600 configs/production-config.json
   ```

3. **Validation**: Always validate configuration before use
   ```powershell
   Test-ConfigurationFile -Path "configs/custom-config.json"
   ```

### Configuration Templates

Use templates for consistent configurations:

**Minimal Template**:
```json
{
  "InstallGit": true,
  "InstallPwsh": true,
  "InstallOpenTofu": true
}
```

**Development Template**:
```json
{
  "InstallGit": true,
  "InstallPwsh": true,
  "InstallOpenTofu": true,
  "InstallVSCode": true,
  "InstallDockerDesktop": true,
  "InstallClaudeCode": true,
  "Node_Dependencies": {
    "InstallNode": true,
    "GlobalPackages": ["yarn", "vite", "nodemon"]
  }
}
```

**Production Template**:
```json
{
  "SetComputerName": true,
  "SetDNSServers": true,
  "ConfigureFirewall": true,
  "InstallOpenTofu": true,
  "OpenTofuVersion": "1.5.7",
  "InstallCA": true,
  "HyperV": {
    "Https": true,
    "Insecure": false,
    "UseNtlm": false
  }
}
```

## Integration with AitherZero Modules

Configuration files are used by various AitherZero modules:

- **SetupWizard**: Uses installation profiles based on configurations
- **ConfigurationCarousel**: Manages switching between configurations
- **AIToolsIntegration**: Reads AI tool settings
- **ISOManager**: Uses iso-management-config.psd1
- **LicenseManager**: Checks feature-registry.json for tier access

## Troubleshooting

### Common Issues

1. **Invalid JSON**: Use a JSON validator
   ```powershell
   Test-Json -Path "configs/custom-config.json"
   ```

2. **Missing Required Fields**: Check against default-config.json

3. **Type Mismatches**: Ensure boolean/string/number types match

### Validation Script

```powershell
# Validate all configuration files
Get-ChildItem -Path "configs" -Filter "*.json" | ForEach-Object {
    try {
        $config = Get-Content $_.FullName | ConvertFrom-Json
        Write-Host "✓ $($_.Name) is valid" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($_.Name) has errors: $_" -ForegroundColor Red
    }
}
```

## See Also

- [Configuration Carousel Documentation](./carousel/README.md)
- [Lab Configurations Documentation](./labs/README.md)
- [AitherZero Setup Guide](../docs/setup-guide.md)