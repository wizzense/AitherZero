# Runtime Feature Prompting

## Overview

AitherZero now supports **runtime feature prompting** - when you try to run a script that requires a disabled feature, the system will prompt you to enable it on the spot. Your choice is automatically saved to your local configuration.

## The Problem This Solves

Previously, if you tried to run a script with a disabled feature:

```
PS> ./automation-scripts/0201_Install-Node.ps1
Node.js installation is not enabled for current profile/platform
```

You'd have to:
1. Open config.psd1
2. Find the Features section
3. Navigate to Development.Node
4. Change `Enabled = $false` to `Enabled = $true`
5. Save the file
6. Re-run the script

This was tedious and error-prone, especially for new users.

## The Solution

Now when you run the same script:

```
PS> ./automation-scripts/0201_Install-Node.ps1

Feature Required: Development.Node
Reason: Script 0201 requires Node.js to install the Node runtime and npm packages

Description: Node.js runtime with npm
Install Script: 0201

Enable this feature now? (y/n): y

✓ Feature Development.Node enabled and saved to config.local.psd1
[Installing Node.js...]
```

The feature is enabled and saved automatically to `config.local.psd1` (which is gitignored), so your choice persists across sessions.

## For Script Authors

### Quick Start

Use the `Test-FeatureOrPrompt` helper function from ScriptUtilities:

```powershell
#Requires -Version 7.0
param()

# Import ScriptUtilities
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1") -Force

# Check feature and prompt if needed
if (-not (Test-FeatureOrPrompt -FeatureName 'Python' -Category 'Development' -Reason 'Required to run Python scripts')) {
    Write-Warning "Python feature is not enabled"
    exit 0
}

# Feature is enabled - continue with script logic
Write-Host "Installing Python..."
```

That's it! The function handles everything:
- Checks if feature is enabled
- Prompts user if disabled
- Saves the setting if user approves
- Returns true/false based on result

### Advanced Usage

For more control, use `Request-FeatureEnable` directly:

```powershell
# Import Configuration module
$configModule = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/configuration/Configuration.psm1"
Import-Module $configModule -Force

# Check if feature is enabled first
if (Test-FeatureEnabled -FeatureName 'Docker' -Category 'Development') {
    # Feature already enabled, proceed
    Write-Host "Docker is enabled"
} else {
    # Feature disabled - prompt user
    $enabled = Request-FeatureEnable `
        -FeatureName 'Docker' `
        -Category 'Development' `
        -Reason "Script 0208 requires Docker to build and run containers"
    
    if ($enabled) {
        Write-Host "Docker was enabled by user"
    } else {
        Write-Host "User declined to enable Docker"
        exit 0
    }
}
```

### Parameters

**Test-FeatureOrPrompt:**
- `FeatureName` (required): Name of the feature (e.g., 'Node', 'Python', 'Docker')
- `Category` (required): Feature category (e.g., 'Development', 'Infrastructure')
- `Reason` (optional): Description shown to user explaining why the feature is needed
- `ExitOnDisabled` (switch): If set, exits the script with code 0 if feature is disabled

**Request-FeatureEnable:**
- `FeatureName` (required): Name of the feature
- `Category` (required): Feature category
- `Reason` (optional): Description shown to user
- `NonInteractive` (switch): Skip prompting and return false (for CI/batch scenarios)

### Example Prompt Output

When a feature is requested, users see:

```
Feature Required: Development.Python
Reason: Script 0206 requires Python to install packages and create virtual environments

Description: Python programming language runtime
Install Script: 0206

Enable this feature now? (y/n): 
```

## For Users

### Enabling Features

When prompted to enable a feature:
- Type `y` or `yes` to enable and save the setting
- Type `n` or `no` to decline (script will exit)

Your choice is saved to `config.local.psd1` in your repository root (this file is gitignored, so it's personal to your machine).

### Viewing Your Local Settings

Check your local configuration overrides:

```powershell
PS> Get-Content config.local.psd1
```

### Disabling Features

To disable a feature you previously enabled:

1. Edit `config.local.psd1`
2. Find the feature and set `Enabled = $false`
3. Save the file

Or delete the entire `config.local.psd1` file to reset all local overrides.

## CI/CD Integration

The prompting system automatically detects CI/CD environments and **skips prompts**:

- Checks `$env:CI`, `$env:GITHUB_ACTIONS`, etc.
- Returns `false` without prompting
- Logs a warning message

This ensures your CI/CD pipelines don't hang waiting for user input.

You can also explicitly skip prompts using the `-NonInteractive` parameter:

```powershell
$enabled = Request-FeatureEnable -FeatureName 'Node' -Category 'Development' -NonInteractive
```

## Configuration Hierarchy

Settings are checked in this order (highest priority first):

1. **Command-line parameters** - Direct parameters passed to scripts
2. **Environment variables** - `AITHERZERO_*` variables
3. **config.local.psd1** - Your local overrides (gitignored) ← **This is where prompts save**
4. **config.psd1** - Master configuration file
5. **Module defaults** - Fallback values in code

So your prompted choices (saved in config.local.psd1) override the master config but can be overridden by environment variables or parameters.

## Best Practices

### For Script Authors

1. **Always include a reason** - Help users understand why the feature is needed
2. **Use descriptive feature names** - Match the names in config.psd1
3. **Check early** - Verify features at the start of your script
4. **Provide alternatives** - If possible, suggest workarounds when features are disabled

### For Users

1. **Read prompts carefully** - Understand what you're enabling
2. **Review config.local.psd1** - Periodically check your local settings
3. **Use profiles** - Consider switching to a different profile (Minimal, Standard, Developer, Full) instead of enabling individual features

## Examples

### Example 1: Node.js Installation (0201)

```powershell
# Check if Node.js feature is enabled, prompt if not
if (-not (Test-FeatureOrPrompt -FeatureName 'Node' -Category 'Development' -Reason 'Required to install Node.js and npm packages')) {
    exit 0
}

# Get Node.js configuration
$nodeConfig = Get-FeatureConfiguration -FeatureName 'Node' -Category 'Development'

# Continue with installation
Write-Host "Installing Node.js..."
```

### Example 2: Hyper-V Setup (0105)

```powershell
# Hyper-V requires admin rights and Windows platform
if ($IsWindows -and (Test-IsAdministrator)) {
    if (-not (Test-FeatureOrPrompt -FeatureName 'HyperV' -Category 'Infrastructure' -Reason 'Required to set up Hyper-V host and create virtual machines')) {
        exit 0
    }
    
    # Proceed with Hyper-V setup
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
} else {
    Write-Warning "Hyper-V requires Windows and administrator privileges"
    exit 1
}
```

### Example 3: Python with Poetry (0204)

```powershell
# Check Python feature
if (-not (Test-FeatureOrPrompt -FeatureName 'Python' -Category 'Development' -Reason 'Required to install Poetry package manager')) {
    exit 0
}

# Get Python configuration
$pythonConfig = Get-FeatureConfiguration -FeatureName 'Python' -Category 'Development'

# Check if Poetry should be installed
if ($pythonConfig.Configuration.InstallPoetry) {
    Write-Host "Installing Poetry..."
    # Installation logic here
} else {
    Write-Host "Poetry installation is disabled in configuration"
}
```

## Troubleshooting

### Prompt doesn't appear

**Cause:** You're in a CI/CD environment or non-interactive mode

**Solution:** Set features in config.psd1 or environment variables instead of relying on prompts

### Changes aren't saved

**Cause:** Permission issues or config.local.psd1 is read-only

**Solution:** Check file permissions and ensure you have write access to the repository root

### Can't find my local settings

**Cause:** config.local.psd1 might not exist yet

**Solution:** The file is created automatically the first time you enable a feature via prompt

### Feature still shows as disabled after enabling

**Cause:** Configuration wasn't reloaded or error during save

**Solution:** 
1. Check logs for errors
2. Verify config.local.psd1 was created
3. Try restarting your PowerShell session
4. Manually reload: `Import-Module ./AitherZero.psd1 -Force`

## Implementation Details

### How It Works

1. **Detection**: Script calls `Test-FeatureOrPrompt` or `Request-FeatureEnable`
2. **Check**: System checks if feature is enabled via `Test-FeatureEnabled`
3. **Prompt**: If disabled and in interactive mode, user is prompted
4. **Save**: On approval, feature is enabled in config.local.psd1:
   ```powershell
   @{
       Features = @{
           Development = @{
               Node = @{
                   Enabled = $true
               }
           }
       }
   }
   ```
5. **Reload**: Configuration is automatically reloaded to pick up the change
6. **Return**: Function returns true (enabled) or false (disabled)

### Files Involved

- `domains/configuration/Configuration.psm1` - Contains `Request-FeatureEnable` function
- `domains/automation/ScriptUtilities.psm1` - Contains `Test-FeatureOrPrompt` helper
- `config.psd1` - Master configuration file (not modified by prompts)
- `config.local.psd1` - Local overrides file (created/modified by prompts, gitignored)

### Security Considerations

- Prompts only work in interactive mode (terminal with user input)
- CI/CD environments are automatically detected and skip prompts
- Local settings are stored in gitignored file (not committed to repo)
- No sensitive information is logged or stored

## Future Enhancements

Potential improvements for future versions:

- [ ] GUI prompt option for Windows users
- [ ] Bulk feature enablement (enable multiple features at once)
- [ ] Feature dependency resolution (auto-enable required dependencies)
- [ ] Undo last feature change
- [ ] Feature usage analytics (which features are most commonly enabled)

## Related Documentation

- [Configuration System](CONFIGURATION.md)
- [Features Documentation](FEATURES.md)
- [Automation Scripts Guide](AUTOMATION-SCRIPTS.md)
- [Script Utilities Reference](SCRIPT-UTILITIES.md)

---

**Version:** 1.0  
**Last Updated:** 2025-11-06  
**Author:** AitherZero Team
