# AitherZero Extension System

## Overview

The AitherZero Extension System makes the platform infinitely extensible. Extensions can add new CLI modes, automation scripts, commands, and entire domain modules.

**Key Design Goals:**
- **Easy to import** - Simple manifest-based loading
- **Modular** - Extensions are self-contained
- **Discoverable** - Auto-discovery from extension directories
- **CLI-integrated** - Extensions naturally extend the CLI
- **Testable** - Extensions bring their own tests

## Architecture

```
AitherZero Core
    ├─ CLI (Start-AitherZero.ps1)
    ├─ Domains (Built-in functionality)
    └─ Extension System
        ├─ Extension Loader
        ├─ Extension Registry
        └─ Extension Discovery
            ├─ extensions/ (Local)
            ├─ ~/.aitherzero/extensions/ (User)
            └─ Remote repositories (Future)

Extensions
    ├─ Extension Manifest (.extension.psd1)
    ├─ Modules (PowerShell .psm1 files)
    ├─ Scripts (Automation scripts)
    ├─ Tests (Pester tests)
    └─ Documentation (README.md)
```

## Quick Start

### Creating an Extension

```powershell
# Create extension template
New-ExtensionTemplate -Name "MyExtension" -Path "./extensions" -Author "Your Name"

# This creates:
extensions/MyExtension/
├── MyExtension.extension.psd1    # Manifest
├── modules/
│   └── MyExtension.psm1           # PowerShell module
├── scripts/
│   └── 8000_MyExtension-Example.ps1
├── tests/
├── Initialize.ps1
├── Cleanup.ps1
└── README.md
```

### Using an Extension

```powershell
# Option 1: Enable in config.psd1
Extensions = @{
    EnabledExtensions = @('MyExtension')
}

# Option 2: Import manually
Import-Extension -Name 'MyExtension'

# Use the extension
Invoke-MyExtensionCommand -Target "example"

# Or via CLI
./Start-AitherZero.ps1 -Mode MyExtensionMode -Target "example"
```

## Extension Manifest Format

Extensions are defined by a `.extension.psd1` manifest file:

```powershell
@{
    # Required fields
    Name = 'MyExtension'
    Version = '1.0.0'
    Description = 'My awesome AitherZero extension'
    Author = 'Your Name'
    
    # Modules to load (PowerShell .psm1 files)
    Modules = @(
        'modules/MyExtension.psm1'
    )
    
    # CLI modes this extension adds
    CLIModes = @(
        @{
            Name = 'CustomMode'
            Handler = 'Invoke-CustomMode'
            Description = 'Custom CLI mode'
            Parameters = @('Target', 'Option')
        }
    )
    
    # Commands this extension provides
    Commands = @(
        @{
            Name = 'Invoke-CustomCommand'
            Function = 'Invoke-CustomCommand'
            Description = 'Custom command'
            Alias = @('custom')
        }
    )
    
    # Automation scripts (8000-8999 range reserved for extensions)
    Scripts = @(
        @{
            Number = '8000'
            Name = 'My-Custom-Script'
            Path = 'scripts/8000_My-Custom-Script.ps1'
            Category = 'Extensions'
        }
    )
    
    # Dependencies on other extensions
    Dependencies = @()
    
    # Initialization script (run when extension loads)
    Initialize = 'Initialize.ps1'
    
    # Cleanup script (run when extension unloads)
    Cleanup = 'Cleanup.ps1'
}
```

## Extension Capabilities

### 1. Adding CLI Modes

Extensions can add new modes to the CLI:

```powershell
# In manifest
CLIModes = @(
    @{
        Name = 'Deploy'
        Handler = 'Invoke-DeployMode'
        Description = 'Deploy applications'
        Parameters = @('Target', 'Environment')
    }
)

# In module
function Invoke-DeployMode {
    param([hashtable]$Parameters)
    
    $target = $Parameters.Target
    $env = $Parameters.Environment
    
    Write-Host "Deploying $target to $env"
    # Deploy logic here
}
```

Usage:
```bash
./Start-AitherZero.ps1 -Mode Deploy -Target myapp -Environment production
```

### 2. Adding Commands

Extensions can provide new PowerShell commands:

```powershell
# In manifest
Commands = @(
    @{
        Name = 'Get-CustomData'
        Function = 'Get-CustomData'
        Description = 'Retrieves custom data'
        Alias = @('gcd')
    }
)

# In module
function Get-CustomData {
    [CmdletBinding()]
    param([string]$Source)
    
    # Implementation
}
```

### 3. Adding Automation Scripts

Extensions can add numbered automation scripts:

```powershell
# Use 8000-8999 range for extensions
Scripts = @(
    @{
        Number = '8100'
        Name = 'Setup-CustomEnvironment'
        Path = 'scripts/8100_Setup-CustomEnvironment.ps1'
        Category = 'Extensions'
    }
)
```

Usage:
```bash
./Start-AitherZero.ps1 -Mode Run -Target 8100
```

### 4. Adding Domain Modules

Extensions can add entire domain modules:

```
MyExtension/
├── modules/
│   ├── MyExtension.psm1
│   ├── CustomDomain.psm1
│   └── Utilities.psm1
```

## Extension System API

### Core Functions

```powershell
# Initialize the extension system
Initialize-ExtensionSystem

# Discover available extensions
Discover-Extensions

# Import/load an extension
Import-Extension -Name 'MyExtension'

# Unload an extension
Remove-Extension -Name 'MyExtension'

# List all extensions
Get-AvailableExtensions

# List loaded extensions only
Get-AvailableExtensions -LoadedOnly

# Create new extension template
New-ExtensionTemplate -Name 'MyExt' -Path './extensions'
```

### Extension Lifecycle

1. **Discovery** - Extension manifests are discovered from search paths
2. **Loading** - Extension is imported
3. **Initialization** - Initialize.ps1 is executed
4. **Registration** - Commands, modes, scripts are registered
5. **Usage** - Extension functionality is available
6. **Cleanup** - Cleanup.ps1 is executed (if unloaded)

## Extension Search Paths

Extensions are discovered from these locations (in order):

1. `<project>/extensions/` - Local project extensions
2. `~/.aitherzero/extensions/` - User extensions
3. Additional paths via `Initialize-ExtensionSystem -AdditionalPaths`

## Script Numbering Convention

AitherZero Core uses 0000-7999:
- 0000-0099: Environment
- 0100-0199: Infrastructure
- 0200-0299: Development
- 0400-0499: Testing
- 0500-0599: Reporting
- 0700-0799: Git automation
- 9000-9999: Maintenance

**Extensions use 8000-8999:**
- 8000-8099: Extension A
- 8100-8199: Extension B
- etc.

## Example Extensions

### Database Extension

```powershell
# DatabaseTools.extension.psd1
@{
    Name = 'DatabaseTools'
    Version = '1.0.0'
    Description = 'Database management and migration tools'
    Author = 'DBA Team'
    
    Modules = @('modules/DatabaseTools.psm1')
    
    CLIModes = @(
        @{
            Name = 'Database'
            Handler = 'Invoke-DatabaseMode'
            Parameters = @('Action', 'Connection')
        }
    )
    
    Scripts = @(
        @{ Number = '8000'; Name = 'Backup-Database'; Path = 'scripts/8000_Backup-Database.ps1' }
        @{ Number = '8001'; Name = 'Restore-Database'; Path = 'scripts/8001_Restore-Database.ps1' }
        @{ Number = '8002'; Name = 'Migrate-Schema'; Path = 'scripts/8002_Migrate-Schema.ps1' }
    )
}
```

### Cloud Provider Extension

```powershell
# AzureTools.extension.psd1
@{
    Name = 'AzureTools'
    Version = '2.0.0'
    Description = 'Azure cloud automation'
    Author = 'Cloud Team'
    
    Modules = @(
        'modules/AzureAuth.psm1'
        'modules/AzureResources.psm1'
    )
    
    CLIModes = @(
        @{
            Name = 'Azure'
            Handler = 'Invoke-AzureMode'
            Parameters = @('Action', 'ResourceGroup')
        }
    )
    
    Commands = @(
        @{ Name = 'Connect-AzureSubscription'; Function = 'Connect-AzureSubscription' }
        @{ Name = 'Deploy-AzureResource'; Function = 'Deploy-AzureResource' }
    )
}
```

## Best Practices

### 1. Naming Conventions
- **Extension names**: PascalCase (MyExtension)
- **Functions**: Verb-Noun format (Get-CustomData)
- **Scripts**: Number_Verb-Noun format (8000_Setup-Environment.ps1)

### 2. Dependencies
- Declare all dependencies in manifest
- Extensions load dependencies automatically
- Avoid circular dependencies

### 3. Testing
- Include tests in `tests/` directory
- Use Pester for testing
- Test extension loading/unloading

### 4. Documentation
- Include README.md with usage examples
- Document all public functions
- Provide examples

### 5. Versioning
- Use semantic versioning (X.Y.Z)
- Document breaking changes
- Maintain backward compatibility when possible

## Configuration

Add extension configuration to `config.psd1`:

```powershell
# config.psd1
@{
    Extensions = @{
        # Extensions to load on startup
        EnabledExtensions = @(
            'DatabaseTools'
            'AzureTools'
            'CustomExtension'
        )
        
        # Remote extension repositories (future)
        ExtensionRepositories = @(
            'https://github.com/AitherZero/extensions'
        )
        
        # Extension-specific configuration
        DatabaseTools = @{
            DefaultConnection = 'Server=localhost;Database=mydb'
        }
    }
}
```

## Security Considerations

1. **Code Review** - Review extension code before loading
2. **Trusted Sources** - Only load extensions from trusted sources
3. **Sandboxing** - Extensions run in the same PowerShell context (no sandboxing yet)
4. **Permissions** - Extensions have same permissions as AitherZero Core

## Future Enhancements

- [ ] Remote extension repositories
- [ ] Extension marketplace
- [ ] Extension signing/verification
- [ ] Extension sandboxing
- [ ] Extension GUI builder
- [ ] Hot-reload extensions
- [ ] Extension dependencies from PSGallery

## Troubleshooting

### Extension not loading

```powershell
# Check if extension is discovered
Get-AvailableExtensions

# Try loading with verbose output
Import-Extension -Name 'MyExtension' -Verbose

# Check extension manifest syntax
Import-PowerShellDataFile './extensions/MyExtension/MyExtension.extension.psd1'
```

### Extension conflicts

```powershell
# List loaded extensions
Get-AvailableExtensions -LoadedOnly

# Unload conflicting extension
Remove-Extension -Name 'ConflictingExtension'

# Reload extension
Import-Extension -Name 'MyExtension' -Force
```

## Contributing Extensions

To contribute an extension to AitherZero:

1. Create extension following this guide
2. Test thoroughly
3. Document usage
4. Submit PR to extensions repository
5. Include tests and README

## Support

For extension development support:
- Check documentation: `docs/EXTENSIONS.md`
- Example extensions: `extensions/examples/`
- Issues: GitHub Issues
- Discussions: GitHub Discussions

---

**Extension System Version**: 1.0.0  
**Last Updated**: 2025-11-05  
**Minimum AitherZero Version**: 2.0.0
