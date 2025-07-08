# Shared Utilities

This directory contains shared utility functions available to all modules, scripts, and tests in the project.

## Find-ProjectRoot.ps1

Robust project root detection that works from any location within the project structure.

### Usage in Modules

Add this to the top of any module file that needs project root detection:

```powershell
# Import shared utilities
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"

# Get project root in your function
function YourFunction {
    $projectRoot = Find-ProjectRoot
    # Use $projectRoot for reliable path operations
}
```

### Usage in Scripts

For scripts in various locations:

```powershell
# From aither-core directory
. "$PSScriptRoot/shared/Find-ProjectRoot.ps1"

# From module directories
. "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"

# From tests directory
. "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"

$projectRoot = Find-ProjectRoot
```

### Usage in Tests

For Pester tests:

```powershell
BeforeAll {
    # Import shared utilities
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $script:ProjectRoot = Find-ProjectRoot
}

Describe "My Tests" {
    It "Should find project files" {
        Test-Path (Join-Path $script:ProjectRoot "aither-core") | Should -Be $true
    }
}
```

### Detection Strategies

1. Environment variable `PROJECT_ROOT` (cached)
2. Characteristic files (aither-core, .git, README.md, go.ps1)
3. PSScriptRoot-based detection for modules
4. Git repository root detection
5. Known path patterns for AitherZero/AitherLabs/Aitherium
6. Common development locations

### Benefits

- **Reliable**: Works from any directory within the project
- **Cached**: Uses environment variable for performance
- **Cross-platform**: Works on Windows, Linux, macOS
- **Flexible**: Multiple fallback strategies
- **Standard**: Single approach for all modules and scripts

## Adding New Shared Utilities

When creating utilities that multiple modules need:

1. Add the function to this directory
2. Use the same import pattern as `Find-ProjectRoot.ps1`
3. Include proper documentation and examples
4. Update this README with usage instructions
5. Refactor existing modules to use the shared version

## Migration from Module-Specific Utilities

When moving utilities from modules to shared:

1. Copy the function to `aither-core/shared/`
2. Update all imports to use the shared version
3. Remove the module-specific version
4. Test all affected modules and scripts
5. Update documentation to reference the shared version
