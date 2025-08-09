# AitherZero Domains

This directory contains all domain modules for the AitherZero platform, organized by functional area.

## Domain Architecture

AitherZero follows a domain-driven design where related functionality is grouped into logical domains:

### 🏗️ Infrastructure Domain
**Status**: ✅ Active

Manages all infrastructure provisioning and virtual machine lifecycle operations.
- OpenTofu/Terraform integration
- Virtual machine management
- Resource lifecycle operations

### ⚙️ Configuration Domain
**Status**: ✅ Active

Provides centralized configuration management with environment support.
- Unified configuration store
- Environment switching
- Validation and schemas
- Hot-reload capabilities

### 🛠️ Utilities Domain
**Status**: ✅ Active

Common services and helpers used across all domains.
- Unified logging service
- Performance monitoring
- Cross-platform utilities

### 🔒 Security Domain
**Status**: 📋 Planned

Will handle security operations and credential management.
- Credential storage
- Certificate management
- Encryption services

### 🎨 Experience Domain
**Status**: 📋 Planned

Will manage user interfaces and experience enhancements.
- Interactive menus
- Progress indicators
- Help systems

### 🤖 Automation Domain
**Status**: 📋 Planned

Will provide workflow automation and orchestration.
- Workflow engine
- Scheduling
- Event handling

## Using Domains

All domains are automatically loaded when you import the core module:

```powershell
Import-Module ./AitherZeroCore.psm1
```

To load only essential domains:

```powershell
Import-Module ./AitherZeroCore.psm1
Initialize-AitherZeroCore -Minimal
```

## Adding New Domains

1. Create a new directory under `domains/`
2. Add your `.psm1` files to the directory
3. Create a `README.md` documenting the domain
4. Add tests under `tests/domains/<domain-name>/`
5. Update `Initialize-AitherZeroCore` to include your domain

## Best Practices

1. **Single Responsibility**: Each domain should have a clear, focused purpose
2. **Minimal Dependencies**: Domains should minimize cross-dependencies
3. **Public Interface**: Expose only necessary functions via `Export-ModuleMember`
4. **Documentation**: Every domain must have a README explaining its purpose
5. **Testing**: All public functions should have corresponding tests

## Domain Communication

Domains communicate through:
- The configuration domain for settings
- The utilities domain for logging
- Well-defined public interfaces

Avoid direct cross-domain dependencies where possible.