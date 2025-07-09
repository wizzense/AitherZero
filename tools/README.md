# AitherZero Tools Directory

This directory contains development tools and utilities for AitherZero development, testing, and maintenance.

## Directory Structure

```
tools/
└── development/
    ├── check-syntax.ps1
    ├── create-ps7-pr.ps1
    ├── create-release.ps1
    ├── debug-braces.ps1
    ├── minimal-test.ps1
    ├── test-function-structure.ps1
    ├── test-patchmanager-integration.ps1
    └── test-patchmanager.ps1
```

## Development Tools

### Syntax and Code Quality

#### `check-syntax.ps1`
**Purpose**: Check PowerShell syntax and code quality
**Usage**:
```powershell
./tools/development/check-syntax.ps1 -Path "./aither-core"
```
**Features**:
- PowerShell syntax validation
- PSScriptAnalyzer integration
- Code style checking
- Error reporting

#### `debug-braces.ps1`
**Purpose**: Debug brace matching issues in PowerShell scripts
**Usage**:
```powershell
./tools/development/debug-braces.ps1 -ScriptPath "./problematic-script.ps1"
```
**Features**:
- Brace matching validation
- Syntax error detection
- Code structure analysis
- Fix suggestions

#### `test-function-structure.ps1`
**Purpose**: Test function structure and validation
**Usage**:
```powershell
./tools/development/test-function-structure.ps1 -ModulePath "./aither-core/domains"
```
**Features**:
- Function signature validation
- Parameter validation
- Documentation completeness
- Best practice compliance

### Testing Tools

#### `minimal-test.ps1`
**Purpose**: Run minimal test suite for quick validation
**Usage**:
```powershell
./tools/development/minimal-test.ps1
```
**Features**:
- Essential function testing
- Quick validation
- Error detection
- Performance measurement

#### `test-patchmanager.ps1`
**Purpose**: Test PatchManager functionality
**Usage**:
```powershell
./tools/development/test-patchmanager.ps1
```
**Features**:
- PatchManager workflow testing
- Git operation validation
- Branch management testing
- PR creation testing

#### `test-patchmanager-integration.ps1`
**Purpose**: Test PatchManager integration with other components
**Usage**:
```powershell
./tools/development/test-patchmanager-integration.ps1
```
**Features**:
- Integration testing
- End-to-end workflow testing
- Cross-component validation
- Performance testing

### Release Tools

#### `create-release.ps1`
**Purpose**: Create release with automated validation
**Usage**:
```powershell
./tools/development/create-release.ps1 -Version "1.2.3" -Message "Release notes"
```
**Features**:
- Version validation
- Release preparation
- Automated testing
- Release creation

#### `create-ps7-pr.ps1`
**Purpose**: Create PowerShell 7 specific pull request
**Usage**:
```powershell
./tools/development/create-ps7-pr.ps1 -Branch "feature/ps7-update"
```
**Features**:
- PowerShell 7 compatibility
- PR creation
- Automated testing
- Documentation updates

## Tool Usage Examples

### Quick Development Workflow

```powershell
# 1. Check syntax before committing
./tools/development/check-syntax.ps1 -Path "./aither-core/domains/infrastructure"

# 2. Run minimal tests
./tools/development/minimal-test.ps1

# 3. Test function structure
./tools/development/test-function-structure.ps1 -ModulePath "./aither-core/domains"

# 4. If all tests pass, create PR using PatchManager
Import-Module ./aither-core/modules/PatchManager -Force
New-Feature -Description "Add new feature" -Changes {
    # Your implementation
}
```

### Debugging Workflow

```powershell
# 1. Debug brace issues
./tools/development/debug-braces.ps1 -ScriptPath "./problematic-script.ps1"

# 2. Test function structure
./tools/development/test-function-structure.ps1 -ModulePath "./aither-core/domains"

# 3. Run comprehensive tests
./tests/Run-Tests.ps1 -All

# 4. Check PatchManager integration
./tools/development/test-patchmanager-integration.ps1
```

### Release Workflow

```powershell
# 1. Test all components
./tools/development/minimal-test.ps1
./tools/development/test-patchmanager.ps1

# 2. Check syntax and structure
./tools/development/check-syntax.ps1 -Path "./aither-core"
./tools/development/test-function-structure.ps1 -ModulePath "./aither-core/domains"

# 3. Create release
./tools/development/create-release.ps1 -Version "1.2.3" -Message "Bug fixes and improvements"
```

## Tool Configuration

### Environment Variables

Some tools use environment variables for configuration:

```powershell
# Set development environment
$env:AITHER_DEV_MODE = "true"
$env:AITHER_TEST_MODE = "true"
$env:AITHER_DEBUG_MODE = "true"

# Tool-specific settings
$env:SYNTAX_CHECK_LEVEL = "Strict"
$env:FUNCTION_CHECK_LEVEL = "Comprehensive"
$env:TEST_TIMEOUT = "300"
```

### Configuration Files

Tools may use configuration files in:
- `./tools/development/config/`
- `./configs/development/`
- Project-specific `.toolsconfig`

## Best Practices

### Tool Usage Guidelines

1. **Run Tools Before Committing**
   ```powershell
   # Always run syntax check
   ./tools/development/check-syntax.ps1 -Path "./modified-files"
   
   # Run minimal tests
   ./tools/development/minimal-test.ps1
   ```

2. **Use Appropriate Tool for Task**
   - Syntax issues: `check-syntax.ps1`
   - Brace problems: `debug-braces.ps1`
   - Function validation: `test-function-structure.ps1`
   - Quick testing: `minimal-test.ps1`

3. **Integrate with Development Workflow**
   ```powershell
   # Example pre-commit script
   ./tools/development/check-syntax.ps1 -Path "."
   ./tools/development/minimal-test.ps1
   if ($LASTEXITCODE -eq 0) {
       Write-Host "All checks passed - ready to commit"
   }
   ```

### Performance Considerations

1. **Tool Selection**
   - Use `minimal-test.ps1` for quick validation
   - Use full test suite for comprehensive validation
   - Use specific tools for targeted issues

2. **Parallel Execution**
   ```powershell
   # Run tools in parallel when possible
   $jobs = @()
   $jobs += Start-Job { ./tools/development/check-syntax.ps1 -Path "./aither-core" }
   $jobs += Start-Job { ./tools/development/minimal-test.ps1 }
   $jobs | Wait-Job | Receive-Job
   ```

3. **Caching**
   - Tools may cache results for performance
   - Use `-Force` to bypass cache when needed
   - Clear cache with `-ClearCache` parameter

## Adding New Tools

### Tool Development Guidelines

1. **Follow PowerShell Best Practices**
   ```powershell
   #Requires -Version 7.0
   
   param(
       [Parameter(Mandatory = $true)]
       [string]$Parameter,
       
       [Parameter(Mandatory = $false)]
       [switch]$Force
   )
   
   try {
       # Tool logic
   } catch {
       Write-Error "Tool failed: $($_.Exception.Message)"
       exit 1
   }
   ```

2. **Include Help Documentation**
   ```powershell
   <#
   .SYNOPSIS
       Brief description of the tool
   .DESCRIPTION
       Detailed description of the tool
   .PARAMETER Parameter
       Description of parameter
   .EXAMPLE
       ./tool.ps1 -Parameter "value"
   #>
   ```

3. **Use Consistent Output Format**
   ```powershell
   # Use structured output
   $result = @{
       Status = "Success"
       Message = "Operation completed"
       Details = @{
           ItemsProcessed = 10
           Errors = 0
       }
   }
   
   $result | ConvertTo-Json -Depth 3
   ```

### Tool Integration

1. **Add to VS Code Tasks**
   ```json
   {
       "label": "Check Syntax",
       "type": "shell",
       "command": "pwsh",
       "args": ["-File", "./tools/development/check-syntax.ps1", "-Path", "."]
   }
   ```

2. **Add to GitHub Actions**
   ```yaml
   - name: Run Development Tools
     run: |
       ./tools/development/check-syntax.ps1 -Path "./aither-core"
       ./tools/development/minimal-test.ps1
   ```

3. **Add to Pre-commit Hooks**
   ```bash
   #!/bin/bash
   # .githooks/pre-commit
   pwsh -File ./tools/development/check-syntax.ps1 -Path "."
   ```

## Tool Maintenance

### Regular Maintenance Tasks

1. **Update Tool Dependencies**
   ```powershell
   # Update PowerShell modules used by tools
   Update-Module Pester -Force
   Update-Module PSScriptAnalyzer -Force
   ```

2. **Validate Tool Functionality**
   ```powershell
   # Test all tools
   Get-ChildItem "./tools/development" -Filter "*.ps1" | ForEach-Object {
       Write-Host "Testing: $($_.Name)"
       & $_.FullName -WhatIf
   }
   ```

3. **Performance Optimization**
   - Profile tool execution time
   - Optimize slow operations
   - Implement caching where appropriate

### Documentation Updates

1. **Keep README Current**
   - Update when new tools are added
   - Document new parameters and features
   - Include usage examples

2. **Update Help Documentation**
   - Ensure all functions have proper help
   - Update examples as needed
   - Validate help completeness

## Troubleshooting

### Common Issues

1. **Tool Execution Failures**
   ```powershell
   # Check PowerShell version
   $PSVersionTable.PSVersion
   
   # Check execution policy
   Get-ExecutionPolicy
   
   # Check module availability
   Get-Module -ListAvailable
   ```

2. **Path Issues**
   ```powershell
   # Use absolute paths
   $toolPath = Resolve-Path "./tools/development/check-syntax.ps1"
   & $toolPath -Path "."
   ```

3. **Permission Issues**
   ```powershell
   # Check file permissions
   Get-Acl "./tools/development/check-syntax.ps1"
   
   # On Linux/macOS, ensure execute permissions
   chmod +x ./tools/development/check-syntax.ps1
   ```

### Debug Mode

Enable debug mode for troubleshooting:

```powershell
# Enable debug mode
$env:AITHER_DEBUG_MODE = "true"
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

# Run tool with debug output
./tools/development/check-syntax.ps1 -Path "." -Debug -Verbose
```

## Contributing

### Adding New Tools

1. **Create Tool Script**
   - Follow PowerShell best practices
   - Include proper documentation
   - Add error handling

2. **Test Tool Thoroughly**
   - Test with various inputs
   - Test error conditions
   - Test cross-platform compatibility

3. **Update Documentation**
   - Add to this README
   - Update usage examples
   - Document configuration options

4. **Integration Testing**
   - Test with development workflow
   - Test with CI/CD pipeline
   - Test with other tools

### Tool Improvement

1. **Performance Optimization**
   - Profile execution time
   - Optimize slow operations
   - Implement caching

2. **Feature Enhancement**
   - Add new parameters
   - Improve output format
   - Add configuration options

3. **Bug Fixes**
   - Fix reported issues
   - Improve error handling
   - Enhance error messages

## Support

For issues with development tools:

1. **Check Documentation**: Review tool-specific help
2. **Test Manually**: Run tools with debug output
3. **Check Dependencies**: Ensure all required modules are available
4. **Report Issues**: Create GitHub issues for bugs
5. **Request Features**: Suggest new tools or features

---

The tools directory provides essential development utilities for AitherZero. These tools help maintain code quality, automate testing, and streamline the development workflow.