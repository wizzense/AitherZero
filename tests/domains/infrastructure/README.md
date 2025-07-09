# Infrastructure Domain Tests

This directory contains tests for the consolidated infrastructure domain.

## Test Coverage

### LabRunner.Consolidated.Tests.ps1
Tests for lab automation functionality:
- Lab automation orchestration
- Script execution management
- Progress tracking integration
- Cross-platform compatibility

### OpenTofuProvider.Consolidated.Tests.ps1
Tests for infrastructure deployment:
- OpenTofu/Terraform integration
- Cloud provider adapters
- Infrastructure deployment workflows
- Security validation

### ISOManager.Consolidated.Tests.ps1
Tests for ISO management:
- ISO download and inventory
- ISO customization and automation
- Repository management
- Storage optimization

### SystemMonitoring.Consolidated.Tests.ps1
Tests for system monitoring:
- Performance monitoring
- System health checks
- Alert management
- Dashboard functionality

## Test Execution

```powershell
# Run all infrastructure tests
./tests/Run-Tests.ps1 -Modules @("infrastructure")

# Run specific infrastructure test
Invoke-Pester ./tests/domains/infrastructure/LabRunner.Consolidated.Tests.ps1
```

## Test Dependencies

- AitherCore module import
- Test isolation framework
- Mock infrastructure services
- Performance benchmarks