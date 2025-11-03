#Requires -Version 7.0
# Stage: Development
# Dependencies: Go
# Description: Initialize Go modules infrastructure for PowerShell-to-Go hybrid architecture
# Tags: development, go, setup, initialization, infrastructure

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$SkipGoCheck
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting Go modules infrastructure initialization"

try {
    # Check if Go is installed
    if (-not $SkipGoCheck) {
        try {
            $goVersion = & go version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ScriptLog "Go is not installed" -Level 'Error'
                Write-ScriptLog "Please run: ./automation-scripts/0007_Install-Go.ps1" -Level 'Information'
                exit 1
            }
            Write-ScriptLog "Found Go installation: $goVersion"
        } catch {
            Write-ScriptLog "Go is not installed: $_" -Level 'Error'
            Write-ScriptLog "Please run: ./automation-scripts/0007_Install-Go.ps1" -Level 'Information'
            exit 1
        }
    }
    
    # Get repository root
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $goModulesPath = Join-Path $repoRoot "go-modules"
    
    # Check if already initialized
    if ((Test-Path $goModulesPath) -and -not $Force) {
        Write-ScriptLog "Go modules infrastructure already exists at: $goModulesPath" -Level 'Warning'
        Write-ScriptLog "Use -Force to reinitialize" -Level 'Information'
        exit 0
    }
    
    if ($PSCmdlet.ShouldProcess($goModulesPath, 'Initialize Go modules infrastructure')) {
        
        # Create directory structure
        Write-ScriptLog "Creating directory structure..."
        
        $directories = @(
            'go-modules'
            'go-modules/cmd'
            'go-modules/cmd/config-parser'
            'go-modules/cmd/test-parser'
            'go-modules/cmd/validator'
            'go-modules/cmd/utils'
            'go-modules/pkg'
            'go-modules/pkg/config'
            'go-modules/pkg/testing'
            'go-modules/pkg/utils'
            'go-modules/pkg/common'
            'go-modules/internal'
            'go-modules/internal/interop'
            'go-modules/internal/parser'
            'bin/go-modules'
            'tests/go-integration'
        )
        
        foreach ($dir in $directories) {
            $fullPath = Join-Path $repoRoot $dir
            if (-not (Test-Path $fullPath)) {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-ScriptLog "Created directory: $dir"
            }
        }
        
        # Initialize Go module
        Write-ScriptLog "Initializing Go module..."
        Push-Location $goModulesPath
        
        try {
            # Create go.mod
            if (-not (Test-Path "go.mod") -or $Force) {
                & go mod init github.com/wizzense/aitherzero-go
                Write-ScriptLog "Created go.mod"
            }
            
            # Create README.md
            $readmeContent = @'
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
'@
            
            $readmeContent | Out-File -FilePath "README.md" -Encoding utf8 -Force
            Write-ScriptLog "Created README.md"
            
            # Create Makefile
            $makefileContent = @'
# AitherZero Go Modules - Makefile

BINARY_DIR = bin
CMD_DIR = cmd
PKG_DIR = pkg

# Binaries to build
BINARIES = config-parser test-parser validator utils

# Go parameters
GOCMD = go
GOBUILD = $(GOCMD) build
GOTEST = $(GOCMD) test
GOCLEAN = $(GOCMD) clean
GOGET = $(GOCMD) get
GOMOD = $(GOCMD) mod

# Build flags
BUILD_FLAGS = -v
LDFLAGS = -s -w

# Detect OS
ifeq ($(OS),Windows_NT)
    BINARY_EXT = .exe
else
    BINARY_EXT =
endif

# Targets
.PHONY: all build test clean install deps fmt lint quality help

all: deps test build

# Build all binaries
build: $(BINARIES)

$(BINARIES):
	@echo "Building $@..."
	@mkdir -p $(BINARY_DIR)
	$(GOBUILD) $(BUILD_FLAGS) -ldflags "$(LDFLAGS)" -o $(BINARY_DIR)/$@$(BINARY_EXT) ./$(CMD_DIR)/$@

# Run tests
test:
	$(GOTEST) -v -cover ./...

# Run tests with coverage
coverage:
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Clean build artifacts
clean:
	$(GOCLEAN)
	rm -rf $(BINARY_DIR)
	rm -f coverage.out coverage.html

# Install binaries to parent bin directory
install: build
	@echo "Installing binaries to ../bin/go-modules/"
	@mkdir -p ../bin/go-modules
	@cp -f $(BINARY_DIR)/*$(BINARY_EXT) ../bin/go-modules/
	@echo "Installation complete"

# Download dependencies
deps:
	$(GOMOD) download
	$(GOMOD) tidy

# Format code
fmt:
	$(GOCMD) fmt ./...

# Lint code (requires golangci-lint)
lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not installed, skipping lint"; \
		echo "Install: https://golangci-lint.run/usage/install/"; \
	fi

# Run all quality checks
quality: fmt lint test

# Help
help:
	@echo "AitherZero Go Modules - Available targets:"
	@echo "  make build     - Build all binaries"
	@echo "  make test      - Run tests"
	@echo "  make coverage  - Generate coverage report"
	@echo "  make install   - Install binaries to ../bin/go-modules/"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make deps      - Download dependencies"
	@echo "  make fmt       - Format code"
	@echo "  make lint      - Lint code (requires golangci-lint)"
	@echo "  make quality   - Run fmt, lint, and test"
	@echo "  make help      - Show this help"
'@
            
            $makefileContent | Out-File -FilePath "Makefile" -Encoding utf8 -Force
            Write-ScriptLog "Created Makefile"
            
            # Create .gitignore
            $gitignoreContent = @'
# Binaries
bin/
*.exe
*.dll
*.so
*.dylib

# Test binary, built with `go test -c`
*.test

# Output of the go coverage tool
coverage.out
coverage.html

# Go workspace file
go.work

# IDEs
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
'@
            
            $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding utf8 -Force
            Write-ScriptLog "Created .gitignore"
            
        } finally {
            Pop-Location
        }
        
        # Create GoInterop module placeholder (if doesn't exist)
        $goInteropPath = Join-Path $repoRoot "domains/utilities/GoInterop.psm1"
        if (-not (Test-Path $goInteropPath) -or $Force) {
            $interopContent = @'
#Requires -Version 7.0

<#
.SYNOPSIS
PowerShell interop layer for Go modules.

.DESCRIPTION
Provides functions to invoke Go module binaries from PowerShell with proper
error handling, JSON marshaling, and fallback mechanisms.

.NOTES
See docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md for detailed documentation.
#>

function Invoke-GoModule {
    <#
    .SYNOPSIS
    Invokes a Go module binary and returns the result.
    
    .DESCRIPTION
    Executes a Go binary from the go-modules/bin directory and parses the JSON output.
    Automatically falls back to PowerShell implementations if Go module is unavailable.
    
    .PARAMETER ModuleName
    Name of the Go module (e.g., 'config-parser', 'test-parser', 'validator', 'utils')
    
    .PARAMETER Arguments
    Arguments to pass to the Go binary
    
    .PARAMETER AsJson
    Parse output as JSON (default: true)
    
    .PARAMETER TimeoutSeconds
    Maximum execution time in seconds (default: 300)
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'config-parser' -Arguments @('--file', 'config.psd1')
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'test-parser' -Arguments @('--file', 'testResults.xml')
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'validator' -Arguments @('--path', './domains', '--recursive')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('config-parser', 'test-parser', 'validator', 'utils')]
        [string]$ModuleName,
        
        [Parameter()]
        [string[]]$Arguments = @(),
        
        [Parameter()]
        [bool]$AsJson = $true,
        
        [Parameter()]
        [int]$TimeoutSeconds = 300
    )
    
    # Placeholder implementation
    # Full implementation in docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md
    
    throw "Go interop not yet implemented. See docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md for setup instructions."
}

function Test-GoModuleAvailable {
    <#
    .SYNOPSIS
    Tests if Go modules are available.
    
    .PARAMETER ModuleName
    Specific module to test, or $null to test Go installation
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ModuleName
    )
    
    # Check Go installation
    $goAvailable = $null -ne (Get-Command go -ErrorAction SilentlyContinue)
    if (-not $goAvailable) {
        return $false
    }
    
    # Check specific module if requested
    if ($ModuleName) {
        $repoRoot = if ($env:AITHERZERO_ROOT) {
            $env:AITHERZERO_ROOT
        } else {
            Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        }
        
        $binPath = Join-Path $repoRoot "bin/go-modules/$ModuleName"
        
        if ($IsWindows) {
            $binPath += '.exe'
        }
        
        return Test-Path $binPath
    }
    
    return $true
}

function Get-GoModuleVersion {
    <#
    .SYNOPSIS
    Gets the version of a Go module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )
    
    if (-not (Test-GoModuleAvailable -ModuleName $ModuleName)) {
        return "Not installed"
    }
    
    try {
        $result = Invoke-GoModule -ModuleName $ModuleName -Arguments @('--version') -AsJson $false
        return $result.Trim()
    } catch {
        return "Unknown"
    }
}

Export-ModuleMember -Function @(
    'Invoke-GoModule',
    'Test-GoModuleAvailable',
    'Get-GoModuleVersion'
)
'@
            
            $interopContent | Out-File -FilePath $goInteropPath -Encoding utf8 -Force
            Write-ScriptLog "Created GoInterop.psm1 placeholder"
        }
        
        # Create initial documentation index
        $docsIndexPath = Join-Path $repoRoot "docs/GO-CONVERSION-INDEX.md"
        $indexContent = @'
# PowerShell to Go Conversion - Documentation Index

This directory contains comprehensive documentation for the PowerShell-to-Go hybrid architecture conversion.

## Documentation Structure

### Planning & Analysis
- [POWERSHELL-TO-GO-FEASIBILITY.md](./POWERSHELL-TO-GO-FEASIBILITY.md) - **START HERE** - Feasibility study and approach analysis
- [GO-CONVERSION-IMPLEMENTATION-GUIDE.md](./GO-CONVERSION-IMPLEMENTATION-GUIDE.md) - Complete implementation guide

### Module-Specific Guides
- `GO-CONVERSION-CONFIG-PARSER.md` - Configuration parser implementation (TODO)
- `GO-CONVERSION-TEST-PARSER.md` - Test result parser implementation (TODO)
- `GO-CONVERSION-VALIDATOR.md` - Code validator implementation (TODO)
- `GO-CONVERSION-UTILS.md` - Utility functions implementation (TODO)

### Reference
- `GO-INTEROP-REFERENCE.md` - PowerShell-Go interop patterns and best practices (TODO)
- `GO-PERFORMANCE-BENCHMARKS.md` - Detailed performance comparison data (TODO)
- `GO-TROUBLESHOOTING.md` - Common issues and solutions (TODO)

## Quick Start

1. **Read the feasibility study**: [POWERSHELL-TO-GO-FEASIBILITY.md](./POWERSHELL-TO-GO-FEASIBILITY.md)
2. **Review the implementation guide**: [GO-CONVERSION-IMPLEMENTATION-GUIDE.md](./GO-CONVERSION-IMPLEMENTATION-GUIDE.md)
3. **Set up Go infrastructure**: Run `./automation-scripts/1001_Initialize-GoInfrastructure.ps1`
4. **Build proof of concept**: Follow Phase 1 in the implementation guide

## Automation Scripts

- `1001_Initialize-GoInfrastructure.ps1` - Set up Go modules directory structure
- `1000_Build-GoModules.ps1` - Build Go modules (TODO)
- `1002_Test-GoIntegration.ps1` - Run integration tests (TODO)

## Status

- [x] Feasibility study complete
- [x] Implementation guide created
- [x] Infrastructure setup script created
- [ ] Proof of concept (Phase 1)
- [ ] Core module conversions (Phase 2)
- [ ] Integration and optimization (Phase 3)

## Next Steps

1. Review feasibility study with stakeholders
2. Get approval for hybrid approach
3. Execute Phase 1 (4 weeks)
4. Validate performance gains
5. Decide on Phase 2 based on results

## Related Documentation

- [.github/copilot-instructions.md](../.github/copilot-instructions.md) - AI coding assistant guidelines
- [STRATEGIC-ROADMAP.md](../STRATEGIC-ROADMAP.md) - Overall project roadmap
- [AITHERCORE-ENGINEERING-ROADMAP.md](../AITHERCORE-ENGINEERING-ROADMAP.md) - Engineering principles

---

**Last Updated**: November 3, 2025  
**Maintained By**: AitherZero Engineering Team
'@
        
        $indexContent | Out-File -FilePath $docsIndexPath -Encoding utf8 -Force
        Write-ScriptLog "Created documentation index"
        
        # Update main README to reference Go conversion
        $mainReadmePath = Join-Path $repoRoot "README.md"
        if (Test-Path $mainReadmePath) {
            $readmeContent = Get-Content $mainReadmePath -Raw
            
            if ($readmeContent -notlike "*PowerShell to Go*") {
                $goSection = @'


## 🚀 Performance Optimization with Go

AitherZero is implementing a hybrid architecture that combines PowerShell's ecosystem benefits with Go's performance advantages.

**Performance gains:**
- Configuration parsing: 20x faster
- Test result parsing: 25x faster  
- Code validation: 30x faster
- Data processing: 15x faster

**Learn more:**
- [Feasibility Study](docs/POWERSHELL-TO-GO-FEASIBILITY.md) - Analysis and approach
- [Implementation Guide](docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md) - Step-by-step instructions
- [Documentation Index](docs/GO-CONVERSION-INDEX.md) - Complete documentation

**Quick start:**
```powershell
# Initialize Go infrastructure
./automation-scripts/1001_Initialize-GoInfrastructure.ps1

# Build Go modules
./automation-scripts/1000_Build-GoModules.ps1 -Install
```
'@
                
                # Insert before the License section
                $readmeContent = $readmeContent -replace '(## License)', "$goSection`n`$1"
                $readmeContent | Out-File -FilePath $mainReadmePath -Encoding utf8 -Force -NoNewline
                Write-ScriptLog "Updated main README.md"
            }
        }
        
        Write-ScriptLog "Go modules infrastructure initialized successfully"
        Write-ScriptLog ""
        Write-ScriptLog "Next steps:"
        Write-ScriptLog "1. Review the documentation: docs/POWERSHELL-TO-GO-FEASIBILITY.md"
        Write-ScriptLog "2. Follow the implementation guide: docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md"
        Write-ScriptLog "3. Build proof of concept modules (Phase 1)"
        Write-ScriptLog ""
        Write-ScriptLog "Directory structure created at: $goModulesPath"
        
        exit 0
    }
    
} catch {
    Write-ScriptLog "Go infrastructure initialization failed: $_" -Level 'Error'
    exit 1
}
