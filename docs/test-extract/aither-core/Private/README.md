# AitherCore Private Functions

## Directory Structure

The `Private` directory contains internal functions that are not directly exposed to users but provide critical infrastructure for the AitherCore module. These functions follow PowerShell module best practices where private functions are only accessible within the module scope.

```
Private/
├── New-AitherPlatformAPI.ps1    # Internal API factory for platform services
└── New-LabAPI.ps1               # Internal API factory for lab automation
```

## Overview

Private functions in AitherCore serve as the backbone for internal operations, providing:

- **API Construction**: Factory functions for creating internal APIs
- **Infrastructure Abstraction**: Low-level platform interactions
- **Module Internals**: Core functionality that supports public-facing APIs

These functions are intentionally kept separate from public functions to:
1. Maintain a clean public API surface
2. Allow internal refactoring without breaking changes
3. Provide implementation flexibility
4. Encapsulate complex logic

## Core Components

### New-AitherPlatformAPI.ps1

Creates internal API instances for platform-level operations:
- Initializes platform service interfaces
- Configures internal communication channels
- Sets up error handling contexts
- Establishes logging pipelines

**Key Responsibilities:**
- Platform service initialization
- Internal API routing
- Cross-module communication setup
- Performance monitoring hooks

### New-LabAPI.ps1

Constructs lab automation APIs for internal use:
- Creates lab infrastructure interfaces
- Manages script execution contexts
- Handles lab resource allocation
- Provides lab state management

**Key Responsibilities:**
- Lab environment abstraction
- Script execution coordination
- Resource lifecycle management
- State synchronization

## Module System Integration

Private functions integrate with the module system through:

1. **Module Scope Variables**: Access to `$script:` scoped variables
2. **Internal Pipelines**: Direct access to module internals
3. **Event Handlers**: Internal event subscription and publishing
4. **State Management**: Module-level state coordination

## Usage Patterns

Private functions are typically called from public functions or during module initialization:

```powershell
# Example from a public function
function Initialize-AitherPlatform {
    # Create internal API instance
    $platformAPI = New-AitherPlatformAPI -Configuration $config
    
    # Use API for platform operations
    $platformAPI.Initialize()
}
```

## Development Guidelines

### Function Naming Conventions

- Use approved PowerShell verbs (New-, Get-, Set-, etc.)
- Descriptive noun phrases indicating internal use
- Avoid generic names that could conflict with public functions

### Error Handling Patterns

```powershell
function New-InternalResource {
    [CmdletBinding()]
    param()
    
    try {
        # Core logic
    }
    catch {
        # Log error internally
        Write-Error -Message "Internal error: $_" -ErrorRecord $_
        throw
    }
}
```

### Logging Standards

- Use module-level logging functions
- Include context information
- Log at appropriate verbosity levels
- Never expose sensitive internal data

### Parameter Validation

- Validate all inputs even from internal callers
- Use parameter attributes for type safety
- Provide meaningful error messages
- Consider performance implications

## Security Considerations

Private functions often handle sensitive operations:

- **Credential Handling**: Never log credentials or secrets
- **API Keys**: Store securely using SecureString
- **Internal State**: Protect module state from external access
- **Validation**: Always validate inputs to prevent injection

## Testing Private Functions

While private functions aren't directly testable from outside the module, they should still be tested:

1. **Unit Tests**: Test through public function interfaces
2. **Integration Tests**: Verify behavior in module context
3. **Mock Support**: Design for testability with dependency injection
4. **Coverage**: Ensure all code paths are exercised

## Best Practices

1. **Keep It Simple**: Private functions should do one thing well
2. **Document Intent**: Clear comments explaining why, not just what
3. **Avoid Side Effects**: Minimize global state modifications
4. **Performance First**: These are often called frequently
5. **Consistent Patterns**: Follow module-wide conventions

## Common Patterns

### Factory Pattern
```powershell
function New-InternalObject {
    param($Type, $Configuration)
    
    $object = [PSCustomObject]@{
        Type = $Type
        Config = $Configuration
        Methods = @{}
    }
    
    # Add methods
    $object.Methods.Initialize = { ... }
    
    return $object
}
```

### Builder Pattern
```powershell
function Build-InternalConfiguration {
    param($BaseConfig)
    
    $config = $BaseConfig.Clone()
    $config | Add-Member -MemberType NoteProperty -Name 'Internal' -Value @{}
    
    # Build configuration
    return $config
}
```

## Maintenance Notes

- Private functions can be refactored freely without versioning concerns
- Always update unit tests when modifying private functions
- Consider promoting to public if external modules need access
- Document any assumptions about module state