# AitherZero Mocking Framework

## Overview

The AitherZero Mocking Framework provides comprehensive mocking capabilities for testing PowerShell modules without requiring external dependencies. This framework ensures tests are isolated, predictable, and fast by mocking:

- **Git Operations**: Branch management, commits, status checks
- **File System Operations**: File/directory creation, reading, writing, deletion
- **Network Operations**: REST API calls, web requests, connectivity tests
- **System Services**: Service status, start/stop operations, process management
- **External Tools**: Terraform, Docker, cloud CLIs, and other external executables

## Key Features

### 🎯 **Comprehensive Coverage**
- Mocks all major external dependencies
- Supports cross-platform testing scenarios
- Handles both success and failure scenarios

### 🔒 **Isolated Testing**
- Each test runs in a clean, isolated environment
- No interference between tests
- Predictable and repeatable results

### ⚡ **Performance**
- Tests run without external network calls
- No file system I/O to real paths
- Significantly faster test execution

### 🧪 **Easy Integration**
- Simple setup with `BeforeEach` and `AfterEach` hooks
- Comprehensive test templates
- Consistent API across all mock types

## Quick Start

### Basic Setup

```powershell
# Import mock helpers
. "$PSScriptRoot/tests/shared/MockHelpers.ps1"

# In your test file
BeforeEach {
    # Set up comprehensive mocking
    Set-TestMockEnvironment -MockTypes @("Git", "FileSystem", "Network", "SystemServices")
}

AfterEach {
    # Clean up mocks
    Clear-TestMockEnvironment
}
```

### Git Operations Mocking

```powershell
# Initialize git mocking
Initialize-GitMocking -CurrentBranch "main" -RemoteUrl "https://github.com/test/repo.git"

# Test git operations
$branch = git branch --show-current  # Returns "main"
$status = git status                  # Returns mocked status
git checkout -b "feature/test"        # Creates mock branch
git commit -m "Test commit"           # Creates mock commit

# Set repository state
Set-GitRepositoryState -Branch "develop" -IsDirty
git status  # Shows uncommitted changes

# Add conflict markers for testing
$conflictContent = Add-GitConflictMarkers -Content "Base" -HeadContent "HEAD" -BranchContent "Feature"
```

### File System Operations Mocking

```powershell
# Initialize file system mocking
Initialize-FileSystemMocking

# Create virtual files and directories
Add-VirtualPath -Path "/config/app.json" -Content '{"setting": "value"}'
Add-VirtualPath -Path "/data" -IsDirectory
Add-VirtualPath -Path "/data/file.txt" -Content "file content"

# Use standard PowerShell commands
Test-Path "/config/app.json"           # Returns true
$content = Get-Content "/config/app.json"  # Returns JSON content
Set-Content "/config/app.json" -Value '{"setting": "modified"}'
Remove-Item "/data/file.txt"
$files = Get-ChildItem "/data"
```

### Network Operations Mocking

```powershell
# Initialize network mocking
Initialize-NetworkMocking

# Set up mock responses
Add-MockResponse -Url "https://api.github.com/user" -Response @{
    login = "testuser"
    id = 12345
    type = "User"
}

# Add failing URLs
Add-FailingUrl -Url "https://api.failing.com/endpoint"

# Use standard PowerShell commands
$response = Invoke-RestMethod -Uri "https://api.github.com/user"
$webResponse = Invoke-WebRequest -Uri "https://api.github.com/user"

# Test failure handling
try {
    Invoke-RestMethod -Uri "https://api.failing.com/endpoint"
} catch {
    # Handle expected failure
}
```

### System Services Mocking

```powershell
# Initialize system services mocking
Initialize-SystemServicesMocking

# Add mock services
Add-MockService -Name "TestService" -Status "Running" -StartType "Automatic"
Add-MockProcess -Name "TestProcess" -Id 1234

# Use standard PowerShell commands
$service = Get-Service -Name "TestService"
$process = Get-Process -Name "TestProcess"
Start-Service -Name "TestService"
Stop-Service -Name "TestService"
```

### External Tools Mocking

```powershell
# Initialize external tools mocking
Initialize-ExternalToolsMocking

# Mock specific tools with custom responses
Initialize-ExternalToolsMocking -ToolResponses @{
    terraform = "Terraform v1.0.0"
    docker = "Docker version 20.10.0"
}

# Use tools normally
$terraformVersion = terraform version
$dockerVersion = docker version
$processResult = Start-Process -FilePath "custom-tool.exe" -ArgumentList "arg1"
```

## Advanced Usage

### Comprehensive Mocking Setup

```powershell
# Initialize all mocking systems at once
Initialize-ComprehensiveMocking -IncludeGit -IncludeFileSystem -IncludeNetwork -IncludeSystemServices -IncludeExternalTools

# Or use the convenient helper for tests
Set-TestMockEnvironment -MockTypes @("Git", "FileSystem", "Network", "SystemServices", "ExternalTools")
```

### Mock State Management

```powershell
# Get current mock configuration
$config = Get-MockConfiguration

# Reset all mocks to clean state
Reset-MockConfiguration

# Test mock isolation
$isIsolated = Test-MockIsolation  # Returns true if properly isolated
```

### Cross-Platform Testing

```powershell
# Mock platform detection
Mock -CommandName Get-Variable -MockWith {
    param($Name)
    switch ($Name) {
        "IsWindows" { return [PSCustomObject]@{ Value = $true } }
        "IsLinux" { return [PSCustomObject]@{ Value = $false } }
        "IsMacOS" { return [PSCustomObject]@{ Value = $false } }
    }
}

# Your cross-platform tests here
```

## Test Templates

### Module Test Template

Use the provided template for consistent testing:

```powershell
# Copy and customize the template
Copy-Item "TEST-TEMPLATES/MODULE-ENHANCED-TEMPLATE.Tests.ps1" "YourModule.Enhanced.Tests.ps1"

# Follow the customization checklist in the template
# Update module name, add specific tests, etc.
```

### Example Test Structure

```powershell
Describe "MyModule Tests with Mocking" {
    BeforeEach {
        Set-TestMockEnvironment -MockTypes @("Git", "FileSystem", "Network")
        
        # Module-specific setup
        Add-VirtualPath -Path "/config/module.json" -Content '{"enabled": true}'
        Add-MockResponse -Url "https://api.myservice.com/status" -Response @{ status = "ok" }
    }
    
    AfterEach {
        Clear-TestMockEnvironment
    }
    
    Context "Module Functionality" {
        It "Should work with mocked dependencies" {
            # Your test logic here
            $result = Get-MyModuleFunction
            $result.Success | Should -Be $true
        }
    }
}
```

## Best Practices

### 1. Mock Isolation
- Always use `BeforeEach` and `AfterEach` for setup/cleanup
- Don't rely on state from previous tests
- Use `Test-MockIsolation` to verify isolation

### 2. Realistic Mock Data
- Use realistic URLs, file paths, and data structures
- Mock both success and failure scenarios
- Test edge cases with appropriate mock responses

### 3. Performance Testing
- Mock external calls for consistent performance tests
- Use mocked data for load testing scenarios
- Verify operations complete within expected time limits

### 4. Error Handling
- Mock failure scenarios to test error handling
- Use `Add-FailingUrl` for network failure testing
- Test with invalid mock data to verify validation

### 5. Cross-Platform Compatibility
- Mock platform-specific operations
- Test with different platform configurations
- Use conditional tests with `-Skip` for platform-specific scenarios

## API Reference

### Git Mocking Functions

| Function | Purpose |
|----------|---------|
| `Initialize-GitMocking` | Set up git command mocking |
| `Set-GitRepositoryState` | Change repository state (branch, dirty status) |
| `Add-GitConflictMarkers` | Generate conflict markers for testing |

### File System Mocking Functions

| Function | Purpose |
|----------|---------|
| `Initialize-FileSystemMocking` | Set up file system operation mocking |
| `Add-VirtualPath` | Add virtual file or directory |
| `Remove-VirtualPath` | Remove virtual file or directory |

### Network Mocking Functions

| Function | Purpose |
|----------|---------|
| `Initialize-NetworkMocking` | Set up network operation mocking |
| `Add-MockResponse` | Add mock response for specific URL |
| `Add-FailingUrl` | Add URL to failure simulation list |

### System Services Mocking Functions

| Function | Purpose |
|----------|---------|
| `Initialize-SystemServicesMocking` | Set up system services mocking |
| `Add-MockService` | Add mock service |
| `Add-MockProcess` | Add mock process |

### External Tools Mocking Functions

| Function | Purpose |
|----------|---------|
| `Initialize-ExternalToolsMocking` | Set up external tool mocking |

### Management Functions

| Function | Purpose |
|----------|---------|
| `Initialize-ComprehensiveMocking` | Initialize all mocking systems |
| `Set-TestMockEnvironment` | Set up test environment (BeforeEach) |
| `Clear-TestMockEnvironment` | Clean up test environment (AfterEach) |
| `Reset-MockConfiguration` | Reset all mocks to clean state |
| `Get-MockConfiguration` | Get current mock configuration |
| `Test-MockIsolation` | Verify mock isolation |

## Troubleshooting

### Common Issues

#### Mock Not Working
```powershell
# Check if mock is enabled
$config = Get-MockConfiguration
if (-not $config.Git.Enabled) {
    Initialize-GitMocking
}
```

#### State Leaking Between Tests
```powershell
# Ensure proper cleanup
AfterEach {
    Clear-TestMockEnvironment
}

# Verify isolation
It "Should have clean state" {
    Test-MockIsolation | Should -Be $true
}
```

#### Performance Issues
```powershell
# Check for real external calls
# Use -Verbose to see what's being called
Describe "Tests" -Tag "Unit" {
    # Unit tests should never call external services
}
```

### Validation

Run the validation script to verify the mocking framework:

```powershell
# Validate all mocking systems
./tests/Validate-MockingFramework.ps1

# Validate specific system
./tests/Validate-MockingFramework.ps1 -TestType Git -Verbose
```

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Run Tests with Mocking
  run: |
    # Install Pester
    Install-Module -Name Pester -Force -Scope CurrentUser
    
    # Validate mocking framework
    ./tests/Validate-MockingFramework.ps1
    
    # Run actual tests
    Invoke-Pester -Path ./tests -Output Detailed
```

### Local Development

```powershell
# Quick validation
./tests/Validate-MockingFramework.ps1

# Run specific module tests
Invoke-Pester -Path ./tests/unit/modules/YourModule.Enhanced.Tests.ps1 -Output Detailed
```

## Contributing

### Adding New Mock Types

1. Add mock configuration to `$script:MockConfig` in `MockHelpers.ps1`
2. Create initialization function (`Initialize-YourMocking`)
3. Add management functions as needed
4. Update test templates and documentation
5. Add validation tests to `Validate-MockingFramework.ps1`

### Testing Your Mocks

```powershell
# Create test for your mock
Test-MockFunction -TestName "Your Mock Test" -TestScript {
    Initialize-YourMocking
    # Test your mock functionality
    $result = Your-MockedFunction
    if ($result -ne "expected") {
        throw "Mock not working correctly"
    }
}
```

## Migration Guide

### From Real Dependencies to Mocks

1. **Identify Dependencies**: Find external calls in your tests
2. **Add Mock Setup**: Use `BeforeEach` to set up appropriate mocks
3. **Update Assertions**: Adjust test assertions for mocked behavior
4. **Add Cleanup**: Use `AfterEach` to clean up mock state
5. **Validate**: Run tests to ensure they work with mocks

### Example Migration

```powershell
# Before (real git calls)
It "Should get git status" {
    $status = git status
    $status | Should -Contain "working tree clean"
}

# After (mocked git calls)
BeforeEach {
    Initialize-GitMocking
}

It "Should get git status" {
    $status = git status
    $status | Should -Contain "working tree clean"
}

AfterEach {
    Clear-TestMockEnvironment
}
```

## Performance Metrics

With the mocking framework, you can expect:

- **90%+ faster test execution** compared to real external calls
- **100% consistent test results** regardless of external service availability
- **No network dependencies** for unit tests
- **Parallel test execution** without conflicts
- **Predictable test duration** for CI/CD pipelines

## Security Considerations

- Mocks don't expose real credentials or sensitive data
- No real network traffic during tests
- File system operations are isolated to virtual paths
- No modifications to real system services or processes

## License

This mocking framework is part of the AitherZero project and follows the same licensing terms.