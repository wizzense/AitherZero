# AitherZero Go Modules

Performance-optimized Go implementations of AitherZero core functionality.

## Overview

This directory contains Go modules that provide high-performance alternatives to PowerShell implementations for CPU-intensive operations. These modules are called from PowerShell through the `GoInterop` module.

## Modules

- **config-parser**: High-performance PSD1 configuration parser (~20x faster)
- **test-parser**: NUnit XML and Pester JSON parser (~25x faster)
- **validator**: Code validation engine, PSScriptAnalyzer alternative (~30x faster)
- **utils**: Data processing and string manipulation utilities (~15x faster)

## Building

```bash
# Build all binaries
make build

# Run tests
make test

# Install to bin directory
make install

# Clean build artifacts
make clean
```

## Usage from PowerShell

```powershell
# Import interop module
Import-Module ./domains/utilities/GoInterop.psm1

# Parse configuration
$config = Invoke-GoModule -ModuleName 'config-parser' -Arguments @('--file', 'config.psd1')

# Parse test results
$results = Invoke-GoModule -ModuleName 'test-parser' -Arguments @('--file', 'testResults.xml')

# Validate scripts
$issues = Invoke-GoModule -ModuleName 'validator' -Arguments @('--path', './domains', '--recursive')
```

## Development

See [GO-CONVERSION-IMPLEMENTATION-GUIDE.md](../docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md) for detailed development instructions.

## Architecture

```
go-modules/
├── cmd/              # CLI binaries (entry points)
│   ├── config-parser/
│   ├── test-parser/
│   ├── validator/
│   └── utils/
├── pkg/              # Public packages (reusable libraries)
│   ├── config/
│   ├── testing/
│   ├── utils/
│   └── common/
└── internal/         # Private packages (implementation details)
    ├── interop/
    └── parser/
```

## Performance Benchmarks

See [POWERSHELL-TO-GO-FEASIBILITY.md](../docs/POWERSHELL-TO-GO-FEASIBILITY.md) for detailed benchmarks.

Expected performance improvements:
- Configuration parsing: 15-20x faster
- Test result parsing: 20-30x faster
- Code validation: 25-35x faster
- Data utilities: 10-15x faster

## Testing

```bash
# Run all tests
make test

# Run tests with coverage
make coverage

# View coverage report
open coverage.html  # macOS
xdg-open coverage.html  # Linux
start coverage.html  # Windows
```

## Contributing

1. Write tests first (TDD approach)
2. Maintain >90% code coverage
3. Follow Go best practices and idioms
4. Update documentation
5. Run `make quality` before committing

## License

MIT License - see LICENSE file for details.
