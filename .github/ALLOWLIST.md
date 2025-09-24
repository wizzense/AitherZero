# GitHub Copilot Coding Agent Allowlist Requirements

## Overview
This file documents the external URLs and domains that need to be added to the GitHub Copilot coding agent's allowlist for AitherZero to function properly.

## Required URLs

### PowerShell Gallery Access
- **URL**: `www.powershellgallery.com`
- **Purpose**: Required for installing PowerShell modules, specifically the `powershell-yaml` module needed for workflow validation
- **Used by**: 
  - `automation-scripts/0440_Validate-Workflows.ps1`
  - `automation-scripts/0443_Install-PowerShellYaml.ps1`
- **Impact if blocked**: Workflow validation scripts will fall back to basic validation without full YAML parsing capabilities

### PowerShell Gallery API
- **URL**: `api.powershellgallery.com`
- **Purpose**: PowerShell module metadata and download API
- **Used by**: PowerShell module installation scripts
- **Impact if blocked**: Module installation will fail

## Configuration Instructions

To add these URLs to the allowlist:

1. Go to your repository's Copilot coding agent settings
2. Navigate to the custom allowlist section
3. Add the following URLs:
   ```
   www.powershellgallery.com
   api.powershellgallery.com
   ```

## Alternative Solutions

If allowlist access cannot be granted:

1. **Manual Module Installation**: Manually install required modules in the environment
2. **Offline Module Cache**: Pre-cache required modules in the repository
3. **Fallback Mode**: Scripts will use basic validation without full YAML parsing

## Testing

After adding URLs to the allowlist, test with:
```bash
pwsh automation-scripts/0443_Install-PowerShellYaml.ps1 -CI
```

## Related Files

- `automation-scripts/0440_Validate-Workflows.ps1` - Main workflow validation script
- `automation-scripts/0443_Install-PowerShellYaml.ps1` - PowerShell YAML module installer
- `PSScriptAnalyzerSettings.psd1` - PowerShell script analysis configuration