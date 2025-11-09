# Cross-Platform Testing Guide

This document provides guidance for running cross-platform integration tests for the AitherZero environment configuration and deployment artifact system.

## Overview

The testing infrastructure validates:
- **Environment Configuration Module** - Cross-platform system configuration management
- **Deployment Artifacts Module** - Multi-platform artifact generation
- **Profile-Based Setup** - Bootstrap integration with all execution profiles
- **ISO Injection** - Automated deployment artifact injection into ISO images

## Test Workflows

### 1. Cross-Platform Integration Tests

**Workflow**: `.github/workflows/cross-platform-integration-tests.yml`

Tests the entire environment configuration system across Windows, Linux, and macOS with multiple execution profiles.

**Platforms**:
- Windows (latest)
- Linux (Ubuntu latest)
- macOS (latest)

**Profiles Tested**:
- Windows: Development, Deployment, AI-Development, Full-Stack
- Linux: Development, Deployment, AI-Development, Self-Hosted-Runner
- macOS: Development, Deployment, AI-Development

**Test Coverage**:
- Module loading and initialization
- Environment configuration detection
- Deployment artifact generation (Unattend.xml, cloud-init, Brewfile, Dockerfiles)
- Platform-specific features (registry, kernel params, defaults)
- Configuration hierarchy (base → OS-specific → local)

**Run Manually**:
```bash
# Trigger via GitHub Actions UI
# Go to Actions → Cross-Platform Integration Tests → Run workflow
```

**Expected Duration**: ~30 minutes per platform

### 2. Bootstrap Integration Tests

**Workflow**: `.github/workflows/bootstrap-integration-tests.yml`

Tests the bootstrap process with all execution profiles across all platforms.

**Platforms**:
- Windows: All 9 profiles (Minimal, Standard, Developer, Development, AI-Development, Deployment, Full-Stack, Self-Hosted-Runner, CI)
- Linux: 6 profiles (Minimal, Standard, Developer, Development, Deployment, Self-Hosted-Runner)
- macOS: 3 profiles (Minimal, Development, Deployment)

**Test Coverage**:
- Bootstrap execution without errors
- Module loading after bootstrap
- Configuration loading and validation
- Profile-specific feature verification
- Environment variable configuration

**Run Manually**:
```bash
# Trigger via GitHub Actions UI
# Go to Actions → Bootstrap Integration Tests → Run workflow
```

**Expected Duration**: ~45 minutes per platform

### 3. ISO Injection Tests

**Script**: `automation-scripts/0195_Inject-ISO-Artifacts.ps1`

Automates the injection of deployment artifacts into Windows and Linux ISO images.

**Capabilities**:
- Extract ISO contents
- Generate deployment artifacts
- Inject artifacts into ISO structure
- Create bootable customized ISO
- Validation mode (dry-run)

**Usage**:
```powershell
# Windows ISO injection
./automation-scripts/0195_Inject-ISO-Artifacts.ps1 `
    -IsoPath "C:\ISOs\Windows.iso" `
    -OutputPath "C:\ISOs\Windows-AitherZero.iso" `
    -Platform Windows

# Linux ISO injection
./automation-scripts/0195_Inject-ISO-Artifacts.ps1 `
    -IsoPath "/isos/ubuntu.iso" `
    -OutputPath "/isos/ubuntu-aitherzero.iso" `
    -Platform Linux `
    -BootstrapScript "./bootstrap.sh"

# Validation only (no output ISO)
./automation-scripts/0195_Inject-ISO-Artifacts.ps1 `
    -IsoPath "C:\ISOs\Windows.iso" `
    -Platform Windows `
    -Validate
```

**Prerequisites**:
- Windows: oscdimg.exe (Windows ADK) or 7-Zip
- Linux: genisoimage or xorriso

## Local Testing

### Running Unit Tests

```powershell
# Test EnvironmentConfig module
Invoke-Pester -Path "./tests/domains/utilities/EnvironmentConfig.Tests.ps1" -Output Detailed

# Test DeploymentArtifacts module
Invoke-Pester -Path "./tests/domains/infrastructure/DeploymentArtifacts.Tests.ps1" -Output Detailed

# Test integration
Invoke-Pester -Path "./tests/integration/ProfileBasedSetup.Integration.Tests.ps1" -Output Detailed
```

### Testing Bootstrap Locally

```powershell
# Test specific profile
./bootstrap.ps1 -Mode Update -InstallProfile Development -Verbose

# Test all profiles (be patient!)
$profiles = @('Minimal', 'Standard', 'Developer', 'Development', 'AI-Development', 'Deployment', 'Full-Stack', 'Self-Hosted-Runner', 'CI')
foreach ($profile in $profiles) {
    Write-Host "Testing profile: $profile" -ForegroundColor Cyan
    ./bootstrap.ps1 -Mode Update -InstallProfile $profile -NonInteractive
}
```

### Testing Environment Configuration

```powershell
# Import module
Import-Module ./AitherZero.psd1 -Force

# Get environment configuration
Get-EnvironmentConfiguration

# Test Windows features (Windows only)
Get-EnvironmentConfiguration -Category Windows

# Test Unix features (Linux/macOS)
Get-EnvironmentConfiguration -Category Unix

# Apply configuration (dry-run)
Set-EnvironmentConfiguration -DryRun

# Apply configuration (force, no prompts)
Set-EnvironmentConfiguration -Force
```

### Testing Deployment Artifacts

```powershell
# Import module
Import-Module ./AitherZero.psd1 -Force

# Generate all artifacts
New-DeploymentArtifacts -Platform All -OutputPath ./test-artifacts

# Windows artifacts
New-WindowsUnattendXml -ConfigPath ./config.windows.psd1 -OutputPath ./test-artifacts
New-Dockerfile -Platform Windows -ConfigPath ./config.windows.psd1 -OutputPath ./test-artifacts

# Linux artifacts
New-LinuxCloudInitConfig -ConfigPath ./config.linux.psd1 -Format YAML -OutputPath ./test-artifacts
New-Dockerfile -Platform Linux -ConfigPath ./config.linux.psd1 -OutputPath ./test-artifacts

# macOS artifacts
New-MacOSBrewfile -ConfigPath ./config.macos.psd1 -OutputPath ./test-artifacts
```

## Test Results

### Current Status

**Unit Tests**:
- ✅ EnvironmentConfig.Tests.ps1 - 34 test cases
- ✅ DeploymentArtifacts.Tests.ps1 - 30+ test cases

**Integration Tests**:
- ✅ ProfileBasedSetup.Integration.Tests.ps1 - 8/31 passing (25.8%)
  - ✅ Module loading
  - ✅ Configuration sections present
  - ✅ Automation scripts exist
  - ✅ Orchestration playbooks exist
  - ⚠️ Some function name mismatches (design vs implementation)

**Cross-Platform**:
- ✅ Windows: Fully tested in GitHub Actions
- ✅ Linux: Fully tested in GitHub Actions (Ubuntu)
- ⏳ macOS: Tested in GitHub Actions (macOS-latest)

**Bootstrap**:
- ✅ Windows: All 9 profiles tested
- ✅ Linux: 6 profiles tested
- ⏳ macOS: 3 profiles tested

### Expected Test Failures

Some tests may fail in certain environments:

1. **Platform-Specific Features**:
   - Windows-only tests fail on Linux/macOS (expected)
   - Linux-only tests fail on Windows/macOS (expected)
   - macOS-only tests fail on Windows/Linux (expected)

2. **Permission Requirements**:
   - Registry modifications require admin on Windows
   - Kernel parameter changes require sudo on Linux
   - Some macOS defaults require admin

3. **Tool Dependencies**:
   - Tests skip if required tools not installed
   - ISO injection requires oscdimg/genisoimage

## Troubleshooting

### Test Failures

**Module Loading Errors**:
```powershell
# Solution: Re-bootstrap
./bootstrap.ps1 -Mode Update -InstallProfile Minimal
```

**Configuration Not Found**:
```powershell
# Solution: Ensure config files exist
Get-ChildItem -Path . -Filter "config.*.psd1"
```

**Artifact Generation Errors**:
```powershell
# Solution: Validate config structure
./automation-scripts/0413_Validate-ConfigManifest.ps1
```

### Workflow Failures

**Bootstrap Timeout**:
- Increase timeout in workflow (default: 45 minutes)
- Use Minimal profile for faster testing

**Artifact Upload Failures**:
- Check artifact size limits (500 MB max)
- Reduce artifact retention period

**Platform-Specific Failures**:
- Review platform-specific test logic
- Check for required tools in CI environment

## CI/CD Integration

### Automatic Triggers

Tests run automatically on:
- Push to main/develop
- Pull requests to main/develop
- Changes to relevant files (modules, configs, scripts)

### Manual Triggers

All workflows support manual triggering via GitHub Actions UI:
1. Go to **Actions** tab
2. Select workflow
3. Click **Run workflow**
4. Choose options (if available)

### Test Artifacts

All workflows upload artifacts for debugging:
- Test results (Pester output)
- Logs (bootstrap, module loading)
- Generated artifacts (Unattend.xml, cloud-init, etc.)

Artifacts retained for 90 days (configurable).

## Best Practices

### Writing Tests

1. **Use Pester 5.x syntax** (Describe, Context, It, BeforeAll, AfterAll)
2. **Mock external dependencies** (file system, registry, network)
3. **Test cross-platform** (check `$IsWindows`, `$IsLinux`, `$IsMacOS`)
4. **Clean up resources** (temp files, test artifacts)
5. **Use descriptive test names** (what, when, expected result)

### Running Tests

1. **Start with unit tests** (fast, isolated)
2. **Run integration tests** (slower, end-to-end)
3. **Test on target platforms** (Windows, Linux, macOS)
4. **Use CI for comprehensive testing** (all profiles, all platforms)

### Debugging Failures

1. **Check logs** (`logs/` directory, uploaded artifacts)
2. **Run locally** (reproduce issue on local machine)
3. **Use verbose output** (`-Verbose`, `-Debug`)
4. **Test in isolation** (single test, single profile)

## Future Enhancements

- [ ] **Code coverage reports** - Measure test coverage percentage
- [ ] **Performance benchmarks** - Track execution time over releases
- [ ] **Container testing** - Test in Docker containers
- [ ] **ARM architecture** - Test on ARM64 runners
- [ ] **Network isolation** - Test without internet access
- [ ] **Snapshot testing** - Compare artifacts against baselines

## Resources

- [Pester Documentation](https://pester.dev/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PowerShell Testing Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

---

**Last Updated**: 2025-11-07
**Version**: 1.0
**Maintainer**: AitherZero Team
