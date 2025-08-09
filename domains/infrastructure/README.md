# Infrastructure Domain

The Infrastructure domain manages all aspects of lab provisioning, virtual machine lifecycle, and infrastructure-as-code operations.

## Responsibilities

- Virtual machine creation and management
- OpenTofu/Terraform infrastructure provisioning
- Resource lifecycle management (create, update, destroy)
- Infrastructure state management
- Lab environment orchestration

## Key Modules

### Lab.psm1
Manages virtual machine operations for lab environments.

**Public Functions:**
- `Get-LabVMs` - List all registered lab VMs
- `New-LabVM` - Create a new lab VM
- `Start-LabVM` - Start a lab VM
- `Stop-LabVM` - Stop a lab VM
- `Remove-LabVM` - Remove a lab VM

### Infrastructure.psm1
Handles infrastructure-as-code operations using OpenTofu/Terraform.

**Public Functions:**
- `Test-OpenTofu` - Check if OpenTofu/Terraform is available
- `Invoke-InfrastructurePlan` - Plan infrastructure changes
- `Invoke-InfrastructureApply` - Apply infrastructure changes
- `Invoke-InfrastructureDestroy` - Destroy infrastructure

## Usage Examples

```powershell
# Import the core module
Import-Module ./AitherZeroCore.psm1

# Create a new lab VM
New-LabVM -Name "TestVM" -Memory "4GB" -CPU 4 -OS "Windows"

# List all VMs
Get-LabVMs

# Plan infrastructure changes
Invoke-InfrastructurePlan -WorkingDirectory "./infrastructure"

# Apply infrastructure
Invoke-InfrastructureApply -AutoApprove
```

## Dependencies

- PowerShell 7.0+
- OpenTofu or Terraform (for infrastructure operations)

## Configuration

Infrastructure operations use the configuration from the Configuration domain. Key settings include:
- Default infrastructure directory
- Provider configurations
- Resource naming conventions