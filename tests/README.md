# Extensible Cross-Platform Testing Framework

This directory contains an extensible testing framework for Aitherium Infrastructure Automation that provides standardized, cross-platform testing capabilities.

## Features

- PASS **Cross-Platform Compatibility**: Automatic platform detection and platform-specific mocking
- PASS **Extensible Templates**: Pre-built templates for common script patterns
- PASS **Automatic Test Generation**: Generate tests from existing scripts
- PASS **Comprehensive Mocking**: Standardized mocks for Windows, Linux, and macOS
- PASS **Test Discovery**: Automatic categorization and discovery of tests
- PASS **Parallel Execution**: Optional parallel test execution for faster results
- PASS **Detailed Reporting**: HTML and JSON reports with categorization
- PASS **Integration Testing**: Support for multi-script integration tests

## Quick Start

### 1. Generate a Test for a New Script

```powershell
# For an installer script
./tests/helpers/New-TestFile.ps1 -ScriptName "0025_Install-Docker.ps1" -TestType "Installer"

# For a feature enablement script 
./tests/helpers/New-TestFile.ps1 -ScriptName "0050_Enable-Hyper-V.ps1" -TestType "Feature"

# For a service management script
./tests/helpers/New-TestFile.ps1 -ScriptName "0100_Enable-WinRM.ps1" -TestType "Service"

# For a configuration script
./tests/helpers/New-TestFile.ps1 -ScriptName "0200_Config-DNS.ps1" -TestType "Configuration"
```

### 2. Run Tests by Category

```powershell
# Run all installer tests
./tests/helpers/Invoke-ExtensibleTests.ps1 -Category "Installer"

# Run tests for specific platform
./tests/helpers/Invoke-ExtensibleTests.ps1 -Platform "Windows"

# Run tests matching a pattern
./tests/helpers/Invoke-ExtensibleTests.ps1 -ScriptPattern "*Install*"

# Run tests in parallel with coverage and reporting
./tests/helpers/Invoke-ExtensibleTests.ps1 -Parallel -EnableCodeCoverage -GenerateReport
```

### 3. Write a Custom Test Using Templates

```powershell
# Simple installer test
. (Join-Path $PSScriptRoot 'helpers' 'TestTemplates.ps1')

New-InstallerScriptTest -ScriptName '0007_Install-Go.ps1' -EnabledProperty 'InstallGo' -InstallerCommand 'Start-Process' -RequiredPlatforms @('Windows')
```

## Framework Components

### TestFramework.ps1
Core framework providing:
- `TestScenario` class for test definition
- `Invoke-ScriptTest` for standardized test execution
- Platform-specific mock generation
- Cross-platform compatibility helpers

### TestTemplates.ps1
Pre-built templates for common patterns:
- `New-InstallerScriptTest` - For software installation scripts
- `New-FeatureScriptTest` - For Windows feature enablement
- `New-ServiceScriptTest` - For service management
- `New-ConfigurationScriptTest` - For configuration scripts
- `New-CrossPlatformScriptTest` - For cross-platform validation
- `New-IntegrationTest` - For multi-script workflows

### New-TestFile.ps1
Automated test generation:
- Analyzes existing scripts
- Detects configuration properties and commands
- Generates appropriate test templates
- Provides customization guidance

### Invoke-ExtensibleTests.ps1
Enhanced test runner:
- Automatic test discovery and categorization
- Platform filtering
- Parallel execution
- Performance monitoring
- HTML and JSON reporting

## Test Categories

Tests are automatically categorized based on content analysis:

- **Installer**: Scripts that install software packages
- **Feature**: Scripts that enable Windows features or capabilities
- **Service**: Scripts that manage system services
- **Configuration**: Scripts that modify system configuration
- **Integration**: End-to-end workflow tests
- **Windows**: Windows-specific functionality
- **CrossPlatform**: Multi-platform compatibility tests

## Platform Support

### Windows
- Full mock support for Windows-specific cmdlets
- Hyper-V, networking, registry, and service mocks
- Certificate and PowerShell remoting mocks

### Linux
- Package manager mocks (apt-get, yum)
- systemd service mocks
- Standard POSIX command mocks

### macOS
- Homebrew package manager mocks
- launchctl service mocks
- macOS-specific command mocks

## Writing Custom Tests

### Basic Template Usage

```powershell
# Load the framework
. (Join-Path $PSScriptRoot 'helpers' 'TestTemplates.ps1')

# Use a template
New-InstallerScriptTest -ScriptName 'MyScript.ps1' -EnabledProperty 'InstallMyApp' -InstallerCommand 'Start-Process'
```

### Advanced Custom Scenarios

```powershell
# Create custom scenarios
$scenarios = @()

$scenarios += New-TestScenario -Name 'Custom scenario' -Description 'Tests custom behavior' -Config @{ CustomProp = $true } -Mocks @{
 'Get-CustomCommand' = { PSCustomObject@{ Status = 'Ready' } }
} -ExpectedInvocations @{
 'Get-CustomCommand' = 1
} -CustomValidation {
 param($Result, $Error)
 # Custom validation logic
 $Result  Should -Not -BeNull
}

Test-RunnerScript -ScriptName 'MyScript.ps1' -Scenarios $scenarios -IncludeStandardTests
```

### Integration Tests

```powershell
New-IntegrationTest -TestName 'Full Lab Setup' -ScriptSequence @(
 '0001_Reset-Git.ps1',
 '0002_Setup-Directories.ps1', 
 '0007_Install-Go.ps1'
) -Config @{
 InstallGo = $true
 Go = @{ InstallerUrl = 'https://example.com/go.msi' }
} -Validation {
 param($Results)
 $Results.Count  Should -Be 3
 # Additional validation
}
```

## Migration Guide

### Converting Existing Tests

1. **Identify the test pattern** (installer, feature, service, etc.)
2. **Use the appropriate template** from TestTemplates.ps1
3. **Move custom logic** to the AdditionalMocks parameter
4. **Add platform requirements** if needed

#### Before (Manual Test)
```powershell
Describe 'Install-Go' {
 BeforeAll {
 $script:ScriptPath = Get-RunnerScriptPath '0007_Install-Go.ps1'
 }
 
 It 'installs when enabled' {
 $cfg = @{ InstallGo = $true }
 Mock Get-Command { $null }
 Mock Start-Process {}
 Mock Invoke-LabDownload {}
 
 & $script:ScriptPath -Config $cfg
 
 Should -Invoke Start-Process -Times 1
 }
}
```

#### After (Template-Based)
```powershell
. (Join-Path $PSScriptRoot 'helpers' 'TestTemplates.ps1')

New-InstallerScriptTest -ScriptName '0007_Install-Go.ps1' -EnabledProperty 'InstallGo' -InstallerCommand 'Start-Process'
```

## Best Practices

### 1. Use Templates When Possible
Templates provide consistent, tested patterns and reduce boilerplate code.

### 2. Platform-Specific Requirements
Always specify platform requirements for platform-specific functionality:
```powershell
-RequiredPlatforms @('Windows')
-ExcludedPlatforms @('Linux', 'macOS')
```

### 3. Mock Strategy
- Use `New-StandardTestMocks` for common operations
- Add script-specific mocks in `AdditionalMocks`
- Mock external dependencies, not internal logic

### 4. Custom Validation
Use custom validation blocks for complex verification:
```powershell
-CustomValidation {
 param($Result, $Error)
 # Verify specific behavior
 Test-Path $expectedFile  Should -BeTrue
}
```

### 5. Test Organization
- Group related tests in the same file
- Use descriptive test names
- Include both positive and negative test cases

## Troubleshooting

### Common Issues

**Mock not working**: Ensure you're using the correct module scope:
```powershell
Mock CommandName {} -ModuleName 'LabRunner'
```

**Platform skipping**: Check platform requirements match your target platform:
```powershell
$script:CurrentPlatform # Shows detected platform
```

**Test discovery fails**: Ensure test files follow naming convention:
```
ScriptName.Tests.ps1
```

### Debugging

Enable verbose logging:
```powershell
./tests/helpers/Invoke-ExtensibleTests.ps1 -Verbose -GenerateReport
```

Check the generated HTML report for detailed failure information.

## Examples

See the `examples/` directory for sample tests using the new framework:
- `Install-Go.Modern.Tests.ps1` - Modern installer test
- Integration test examples
- Cross-platform test examples

## Contributing

When adding new scripts to the project:

1. **Generate a test** using `New-TestFile.ps1`
2. **Customize the generated test** for specific requirements
3. **Run the test** to ensure it passes
4. **Update templates** if you identify new patterns

The framework is designed to be extended. Add new templates to `TestTemplates.ps1` for new patterns you discover.
