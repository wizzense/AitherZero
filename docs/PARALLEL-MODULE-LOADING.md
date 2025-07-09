# Parallel Module Loading in AitherCore

## Overview

AitherCore now supports parallel module loading to significantly improve startup performance. This feature intelligently groups modules by their dependency depth and loads independent modules concurrently while respecting dependencies.

## How It Works

### Dependency Analysis
1. **Module Discovery**: The system scans all module manifests (.psd1 files) to extract dependency information
2. **Dependency Graph**: A complete dependency graph is built showing which modules depend on others
3. **Topological Sorting**: Modules are sorted into dependency levels using Kahn's algorithm

### Parallel Loading Strategy
1. **Depth Grouping**: Modules are grouped by their dependency depth
   - Depth 0: Modules with no dependencies (e.g., Logging)
   - Depth 1: Modules that only depend on depth 0 modules
   - Depth 2: Modules that depend on depth 0 or 1 modules, etc.
2. **Parallel Execution**: All modules at the same depth level are loaded in parallel
3. **Synchronization**: The system waits for all modules at a depth level to complete before proceeding to the next level

### Example Loading Sequence
```
Depth 0 (Sequential): Logging
Depth 1 (Parallel):   ConfigurationCore, ProgressTracking, ModuleCommunication
Depth 2 (Parallel):   ConfigurationManager, ConfigurationCarousel, ParallelExecution
Depth 3 (Parallel):   PatchManager, TestingFramework, BackupManager
```

## Performance Benefits

- **Reduced Loading Time**: Typically 40-60% faster than sequential loading
- **Scalable**: Performance improvement scales with the number of CPU cores
- **Safe**: Respects all module dependencies to prevent loading errors

## Usage

### Default Behavior
By default, parallel loading is enabled:
```powershell
# This uses parallel loading automatically
Import-Module ./aither-core/AitherCore.psm1
Initialize-CoreApplication
```

### Explicit Control
You can control the loading behavior:
```powershell
# Force parallel loading
Import-CoreModules -UseParallelLoading $true

# Force sequential loading (for debugging)
Import-CoreModules -UseParallelLoading $false

# Load only required modules in parallel
Import-CoreModules -RequiredOnly -UseParallelLoading $true
```

### Performance Testing
Run the benchmark script to see the performance improvement:
```powershell
./tests/Test-ParallelModuleLoading.ps1

# With detailed output
./tests/Test-ParallelModuleLoading.ps1 -Detailed
```

## Configuration

### Module Manifest Requirements
Modules must properly declare their dependencies in their .psd1 manifest:
```powershell
@{
    ModuleVersion = '1.0.0'
    RequiredModules = @('Logging', 'ConfigurationCore')
    # ... other manifest properties
}
```

### Circular Dependencies
The system detects and handles circular dependencies gracefully by:
1. Warning about the circular dependency
2. Loading the affected modules sequentially
3. Continuing with the rest of the modules

## Technical Details

### Implementation
- **Location**: `/aither-core/Private/Import-CoreModulesParallel.ps1`
- **Dependencies**: Uses native PowerShell 7 `ForEach-Object -Parallel` or the ParallelExecution module
- **Error Handling**: Falls back to sequential loading if parallel loading fails

### Safety Features
1. **Dependency Validation**: Ensures all dependencies are satisfied before loading
2. **Error Isolation**: Failures in one module don't affect others at the same depth
3. **Fallback Mode**: Automatically switches to sequential loading if issues occur
4. **Module Tracking**: Maintains proper module state tracking throughout the process

## Troubleshooting

### Module Not Loading
- Check module manifest for correct dependency declarations
- Verify module path is correct
- Look for circular dependencies in the logs

### Performance Not Improved
- Ensure you have multiple CPU cores available
- Check if most modules are in a dependency chain (limits parallelism)
- Verify ParallelExecution module is available

### Debugging
Enable detailed logging:
```powershell
$VerbosePreference = 'Continue'
Import-CoreModules -UseParallelLoading $true -Verbose
```

## Best Practices

1. **Minimize Dependencies**: Keep module dependencies to a minimum for maximum parallelism
2. **Declare All Dependencies**: Always declare dependencies in module manifests
3. **Test Both Modes**: Test your modules in both parallel and sequential modes
4. **Monitor Performance**: Use the benchmark script to track loading performance

## Future Enhancements

- [ ] Lazy loading for non-critical modules
- [ ] Module preloading cache
- [ ] Dynamic throttling based on system load
- [ ] Module dependency visualization tool