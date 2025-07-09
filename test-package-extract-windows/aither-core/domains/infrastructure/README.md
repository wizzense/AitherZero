# Infrastructure Domain

This domain handles all infrastructure-related operations in AitherCore.

## Consolidated Modules

### LabRunner
**Original Module**: `aither-core/modules/LabRunner/`  
**Status**: Consolidated  
**Key Functions**:
- `Start-LabAutomation`
- `Invoke-LabStep`
- `Get-LabStatus`
- `Start-EnhancedLabDeployment`

### OpenTofuProvider
**Original Module**: `aither-core/modules/OpenTofuProvider/`  
**Status**: Consolidated  
**Key Functions**:
- `Start-InfrastructureDeployment`
- `Initialize-OpenTofuProvider`
- `New-LabInfrastructure`

### ISOManager
**Original Module**: `aither-core/modules/ISOManager/`  
**Status**: Consolidated  
**Key Functions**:
- `Get-ISODownload`
- `New-CustomISO`
- `New-ISORepository`
- `Get-ISOInventory`

### SystemMonitoring
**Original Module**: `aither-core/modules/SystemMonitoring/`  
**Status**: Consolidated  
**Key Functions**:
- `Get-SystemPerformance`
- `Start-SystemMonitoring`
- `Get-SystemDashboard`

## Implementation Structure

```
infrastructure/
├── LabRunner.ps1           # Lab automation functions
├── OpenTofuProvider.ps1    # Infrastructure deployment functions
├── ISOManager.ps1          # ISO management functions
├── SystemMonitoring.ps1    # System monitoring functions
└── README.md              # This file
```

## Usage Examples

```powershell
# Start lab automation
Start-LabAutomation -Configuration $config -ShowProgress

# Deploy infrastructure
Start-InfrastructureDeployment -ConfigurationPath "./lab-config.yaml"

# Download and customize ISO
$iso = Get-ISODownload -ISOName "Windows11"
New-CustomISO -SourceISO $iso.FilePath -AutounattendPath $autounattend

# Monitor system performance
Start-SystemMonitoring -Interval 60 -Dashboard
```

## Testing

Infrastructure domain tests are located in:
- `tests/domains/infrastructure/`
- Integration tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Find-ProjectRoot**: Shared utility for project root detection
- **Configuration Services**: Uses unified configuration management