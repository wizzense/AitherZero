# Automation Domain Tests

This directory contains tests for the Automation domain, which consolidates script management and workflow orchestration functionality.

## Domain Overview

The Automation domain consolidates the following legacy modules:
- **ScriptManager** - One-off script execution and management
- **OrchestrationEngine** - Workflow and playbook execution

**Total Functions: 16**

## Function Reference

### Script Repository Management
- `Initialize-ScriptRepository` - Initialize script repository with proper directory structure
- `Initialize-ScriptTemplates` - Initialize default script templates (Basic, Module, Lab, Parallel)
- `Get-ScriptRepository` - Get comprehensive repository information and statistics
- `Backup-ScriptRepository` - Create timestamped backups of script repository
- `Get-ScriptMetrics` - Generate comprehensive repository metrics and analytics

### Script Registration and Management
- `Register-OneOffScript` - Register scripts in the registry with metadata and validation
- `Get-RegisteredScripts` - Retrieve information about registered scripts
- `Remove-ScriptFromRegistry` - Remove scripts from registry with optional file deletion
- `Test-ModernScript` - Validate scripts against modern PowerShell practices
- `Test-OneOffScript` - Comprehensive script compliance testing with detailed scoring

### Script Execution
- `Invoke-OneOffScript` - Execute registered scripts with timeout and monitoring
- `Start-ScriptExecution` - Advanced script execution with retry logic and background support
- `Get-ScriptExecutionHistory` - Retrieve execution history with filtering options

### Script Templates
- `Get-ScriptTemplate` - Retrieve available script templates
- `New-ScriptFromTemplate` - Create new scripts from templates with customization

## Test Categories

### Unit Tests
- **Script Repository Tests** - Test repository initialization and management
- **Script Registration Tests** - Test script registration and metadata handling
- **Script Execution Tests** - Test script execution with various scenarios
- **Template Tests** - Test template management and script creation
- **Validation Tests** - Test script validation and compliance checking

### Integration Tests
- **End-to-End Workflow Tests** - Test complete script lifecycle
- **Cross-Platform Tests** - Test functionality across Windows, Linux, macOS
- **Error Handling Tests** - Test error recovery and rollback scenarios
- **Performance Tests** - Test execution performance and resource usage

### Security Tests
- **Script Security Tests** - Test security validation and safe execution
- **Path Traversal Tests** - Test protection against path traversal attacks
- **Execution Context Tests** - Test isolated execution environments

## Test Data

### Mock Scripts
- `test-basic-script.ps1` - Basic script for testing
- `test-module-script.ps1` - Module-based script for testing
- `test-parallel-script.ps1` - Parallel execution script for testing
- `test-invalid-script.ps1` - Invalid script for error testing

### Test Templates
- Custom templates for testing template functionality
- Malformed templates for error testing
- Platform-specific templates for cross-platform testing

## Test Execution

### Run All Automation Domain Tests
```powershell
# Run all automation tests
./tests/Run-Tests.ps1 -Domain automation

# Run specific test categories
./tests/Run-Tests.ps1 -Domain automation -Category unit
./tests/Run-Tests.ps1 -Domain automation -Category integration
./tests/Run-Tests.ps1 -Domain automation -Category security
```

### Run Individual Test Files
```powershell
# Run main automation tests
Invoke-Pester ./tests/domains/automation/Automation.Tests.ps1

# Run with coverage
Invoke-Pester ./tests/domains/automation/Automation.Tests.ps1 -CodeCoverage
```

## Test Structure

```powershell
Describe "Automation Domain Tests" {
    BeforeAll {
        # Import AitherCore for domain functions
        Import-Module ./aither-core/AitherCore.psm1 -Force
        
        # Initialize test environment
        $testContext = Initialize-TestEnvironment -Domain "automation"
    }
    
    Context "Script Repository Management" {
        It "Should initialize script repository" {
            # Test Initialize-ScriptRepository
        }
        
        It "Should create script templates" {
            # Test Initialize-ScriptTemplates
        }
        
        It "Should provide repository information" {
            # Test Get-ScriptRepository
        }
    }
    
    Context "Script Registration" {
        It "Should register scripts with metadata" {
            # Test Register-OneOffScript
        }
        
        It "Should retrieve registered scripts" {
            # Test Get-RegisteredScripts
        }
        
        It "Should validate script compliance" {
            # Test Test-ModernScript
        }
    }
    
    Context "Script Execution" {
        It "Should execute scripts with monitoring" {
            # Test Invoke-OneOffScript
        }
        
        It "Should support advanced execution options" {
            # Test Start-ScriptExecution
        }
        
        It "Should track execution history" {
            # Test Get-ScriptExecutionHistory
        }
    }
    
    Context "Template Management" {
        It "Should provide script templates" {
            # Test Get-ScriptTemplate
        }
        
        It "Should create scripts from templates" {
            # Test New-ScriptFromTemplate
        }
    }
    
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -Context $testContext
    }
}
```

## Expected Test Results

### Coverage Targets
- **Function Coverage**: 95% (15/16 functions)
- **Line Coverage**: 90%
- **Branch Coverage**: 85%

### Performance Targets
- **Script Registration**: < 100ms
- **Script Execution**: < 5 seconds (for test scripts)
- **Repository Operations**: < 500ms
- **Template Operations**: < 200ms

### Compatibility Targets
- **Windows**: 100% pass rate
- **Linux**: 100% pass rate
- **macOS**: 100% pass rate

## Legacy Module Compatibility

### Migration from ScriptManager
The automation domain maintains backward compatibility with ScriptManager functions:
- All existing ScriptManager functions are available
- Legacy function names are preserved
- Configuration and data formats remain compatible

### Migration from OrchestrationEngine
Orchestration functionality is integrated into the automation domain:
- Workflow execution capabilities
- Playbook management
- Advanced orchestration features

## Common Test Scenarios

### 1. Script Lifecycle Testing
```powershell
# Test complete script lifecycle
$script = Register-OneOffScript -ScriptPath "test-script.ps1" -Name "TestScript"
$result = Invoke-OneOffScript -Name "TestScript"
$history = Get-ScriptExecutionHistory -ScriptName "TestScript"
Remove-ScriptFromRegistry -Name "TestScript"
```

### 2. Template-Based Script Creation
```powershell
# Test script creation from template
$template = Get-ScriptTemplate -TemplateName "Basic"
$script = New-ScriptFromTemplate -TemplateName "Basic" -ScriptName "NewScript"
Test-ModernScript -ScriptPath $script.ScriptPath
```

### 3. Advanced Execution Testing
```powershell
# Test advanced execution features
$execution = Start-ScriptExecution -ScriptName "TestScript" -Background -MaxRetries 3
# Test timeout and retry scenarios
```

## Troubleshooting

### Common Test Issues
1. **Script Path Issues** - Ensure test scripts are in correct locations
2. **Permission Issues** - Verify script execution permissions on Unix systems
3. **Template Issues** - Check template file integrity and accessibility
4. **Repository Issues** - Ensure repository directories are properly initialized

### Debug Commands
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check script repository status
Get-ScriptRepository -IncludeStatistics

# Validate script compliance
Test-OneOffScript -ScriptPath "test-script.ps1" -Detailed
```

## Contributing

### Adding New Tests
1. Follow the existing test structure
2. Add appropriate test data files
3. Update test documentation
4. Ensure cross-platform compatibility

### Test Guidelines
- Test all function parameters and variations
- Include both positive and negative test cases
- Test error conditions and edge cases
- Verify cross-platform compatibility
- Test performance and resource usage