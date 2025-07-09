# Utilities Domain

This domain provides shared utility services for AitherCore.

## Consolidated Modules

### UtilityServices
**Original Module**: `aither-core/modules/UtilityServices/`  
**Status**: Consolidated  
**Key Functions**:
- Common utility functions
- Cross-platform helpers
- Shared service implementations

## Utilities Architecture

The utilities domain provides shared services:

```
Utilities Domain
├── UtilityServices (Core Service)
│   ├── Cross-Platform Helpers
│   ├── Common Utilities
│   ├── Service Implementations
│   └── Shared Resources
```

## Implementation Structure

```
utilities/
├── UtilityServices.ps1         # Common utility functions
└── README.md                  # This file
```

## Usage Examples

```powershell
# Cross-platform path operations
$path = Get-CrossPlatformPath -Path "configs/app-config.json"

# Common utility functions
$result = Invoke-UtilityFunction -Function "ValidateInput" -Parameters @{Input = $userInput}

# Service implementations
$service = Get-UtilityService -ServiceName "FileProcessor"
```

## Features

### Cross-Platform Helpers
- Path manipulation and validation
- File system operations
- Platform-specific implementations

### Common Utilities
- Input validation and sanitization
- Data transformation functions
- Error handling utilities

### Service Implementations
- Shared service patterns
- Common business logic
- Reusable components

### Shared Resources
- Configuration templates
- Common data structures
- Utility constants

## Integration

The utilities domain is used by:
- **Infrastructure Domain**: For infrastructure utilities
- **Configuration Domain**: For configuration utilities
- **Security Domain**: For security utilities
- **Automation Domain**: For automation utilities
- **Experience Domain**: For user experience utilities

## Testing

Utilities domain tests are located in:
- `tests/domains/utilities/`
- Integration tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Platform Services**: Cross-platform compatibility
- **Configuration Services**: Uses unified configuration management