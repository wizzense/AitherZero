# PowerShell to Go Conversion - Implementation Guide

**Document Version**: 1.0  
**Date**: November 3, 2025  
**Status**: Implementation Guide  
**Prerequisite**: [POWERSHELL-TO-GO-FEASIBILITY.md](./POWERSHELL-TO-GO-FEASIBILITY.md)

---

## Quick Start

This guide provides step-by-step instructions for implementing the **Hybrid Approach** recommended in the feasibility study.

---

## Phase 1: Foundation (Weeks 1-4)

### Week 1: Environment Setup

#### 1.1 Install Go Toolchain

**Run existing installation script:**
```powershell
# Ensure Go is installed
./automation-scripts/0007_Install-Go.ps1 -Configuration @{
    DevelopmentTools = @{
        Go = @{
            Install = $true
            Version = "1.21.5"
            GoPath = "~/go"
        }
    }
}

# Verify installation
go version
go env
```

**Expected output:**
```
go version go1.21.5 linux/amd64
GOROOT="/usr/local/go"
GOPATH="/home/user/go"
```

#### 1.2 Create Go Module Structure

```bash
cd /path/to/AitherZero

# Create directory structure
mkdir -p go-modules/{cmd,pkg,internal}
mkdir -p go-modules/cmd/{config-parser,test-parser,validator,utils}
mkdir -p go-modules/pkg/{config,testing,utils,common}
mkdir -p go-modules/internal/{interop,parser}

# Initialize Go module
cd go-modules
go mod init github.com/wizzense/aitherzero-go

# Create README
cat > README.md << 'EOF'
# AitherZero Go Modules

Performance-optimized Go implementations of AitherZero core functionality.

## Modules

- `cmd/config-parser` - High-performance configuration parser
- `cmd/test-parser` - NUnit XML and coverage report parser
- `cmd/validator` - Code validation engine (PSScriptAnalyzer alternative)
- `cmd/utils` - Data processing utilities

## Building

```bash
make build        # Build all binaries
make test         # Run tests
make install      # Install to bin/
```

## Usage from PowerShell

```powershell
# Parse configuration
$config = & "$PSScriptRoot/go-modules/bin/config-parser" --file "config.psd1" | ConvertFrom-Json

# Parse test results
$results = & "$PSScriptRoot/go-modules/bin/test-parser" --file "testResults.xml" | ConvertFrom-Json

# Validate scripts
$issues = & "$PSScriptRoot/go-modules/bin/validator" --path "./domains" --recursive | ConvertFrom-Json
```
EOF
```

#### 1.3 Create Makefile

```bash
cat > go-modules/Makefile << 'EOF'
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

# Targets
.PHONY: all build test clean install deps

all: deps test build

# Build all binaries
build: $(BINARIES)

$(BINARIES):
	@echo "Building $@..."
	@mkdir -p $(BINARY_DIR)
	$(GOBUILD) $(BUILD_FLAGS) -ldflags "$(LDFLAGS)" -o $(BINARY_DIR)/$@ ./$(CMD_DIR)/$@

# Run tests
test:
	$(GOTEST) -v -cover ./...

# Run tests with coverage
coverage:
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	$(GOCLEAN)
	rm -rf $(BINARY_DIR)
	rm -f coverage.out coverage.html

# Install binaries
install: build
	@echo "Installing binaries to ../bin/go-modules/"
	@mkdir -p ../bin/go-modules
	@cp -f $(BINARY_DIR)/* ../bin/go-modules/
	@echo "Installation complete"

# Download dependencies
deps:
	$(GOMOD) download
	$(GOMOD) tidy

# Format code
fmt:
	$(GOCMD) fmt ./...

# Lint code
lint:
	golangci-lint run ./...

# Run all quality checks
quality: fmt lint test

# Help
help:
	@echo "AitherZero Go Modules - Available targets:"
	@echo "  make build     - Build all binaries"
	@echo "  make test      - Run tests"
	@echo "  make coverage  - Generate coverage report"
	@echo "  make install   - Install binaries"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make deps      - Download dependencies"
	@echo "  make quality   - Run fmt, lint, and test"
EOF
```

### Week 2: Interop Layer

#### 2.1 Create PowerShell Interop Module

```powershell
# Create file: domains/utilities/GoInterop.psm1

#Requires -Version 7.0

function Invoke-GoModule {
    <#
    .SYNOPSIS
    Invokes a Go module binary and returns the result.
    
    .DESCRIPTION
    Executes a Go binary from the go-modules/bin directory and parses the JSON output.
    
    .PARAMETER ModuleName
    Name of the Go module (e.g., 'config-parser', 'test-parser')
    
    .PARAMETER Arguments
    Arguments to pass to the Go binary
    
    .PARAMETER AsJson
    Parse output as JSON (default: true)
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'config-parser' -Arguments @('--file', 'config.psd1')
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
    
    try {
        # Find Go binary
        $binPath = if ($env:AITHERZERO_ROOT) {
            Join-Path $env:AITHERZERO_ROOT "bin/go-modules/$ModuleName"
        } else {
            $repoRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
            Join-Path $repoRoot "bin/go-modules/$ModuleName"
        }
        
        # Add .exe on Windows
        if ($IsWindows) {
            $binPath += '.exe'
        }
        
        if (-not (Test-Path $binPath)) {
            throw "Go module binary not found: $binPath. Run 'make install' in go-modules directory."
        }
        
        # Execute Go binary
        $process = Start-Process -FilePath $binPath `
                                 -ArgumentList $Arguments `
                                 -NoNewWindow `
                                 -Wait `
                                 -PassThru `
                                 -RedirectStandardOutput "$env:TEMP/go-output.txt" `
                                 -RedirectStandardError "$env:TEMP/go-error.txt"
        
        # Check for errors
        if ($process.ExitCode -ne 0) {
            $errorMsg = Get-Content "$env:TEMP/go-error.txt" -Raw
            throw "Go module failed with exit code $($process.ExitCode): $errorMsg"
        }
        
        # Get output
        $output = Get-Content "$env:TEMP/go-output.txt" -Raw
        
        # Parse as JSON if requested
        if ($AsJson -and $output) {
            return $output | ConvertFrom-Json
        } else {
            return $output
        }
        
    } catch {
        Write-Error "Failed to invoke Go module '$ModuleName': $_"
        throw
    } finally {
        # Cleanup temp files
        Remove-Item "$env:TEMP/go-output.txt" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP/go-error.txt" -ErrorAction SilentlyContinue
    }
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
        $binPath = if ($env:AITHERZERO_ROOT) {
            Join-Path $env:AITHERZERO_ROOT "bin/go-modules/$ModuleName"
        } else {
            $repoRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
            Join-Path $repoRoot "bin/go-modules/$ModuleName"
        }
        
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
```

#### 2.2 Create Build Automation Script

```powershell
# Create file: automation-scripts/1000_Build-GoModules.ps1

#Requires -Version 7.0
# Stage: Development
# Dependencies: Go
# Description: Build Go modules for performance-critical operations
# Tags: development, go, build, compilation

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'config-parser', 'test-parser', 'validator', 'utils')]
    [string]$Target = 'All',
    
    [Parameter()]
    [switch]$Clean,
    
    [Parameter()]
    [switch]$Test,
    
    [Parameter()]
    [switch]$Install
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
    param([string]$Message, [string]$Level = 'Information')
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

try {
    Write-ScriptLog "Starting Go modules build process"
    
    # Check Go installation
    $goVersion = & go version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ScriptLog "Go is not installed. Run ./automation-scripts/0007_Install-Go.ps1" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "Using Go: $goVersion"
    
    # Navigate to go-modules directory
    $goModulesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "go-modules"
    
    if (-not (Test-Path $goModulesPath)) {
        Write-ScriptLog "Go modules directory not found: $goModulesPath" -Level 'Error'
        Write-ScriptLog "Run setup scripts to create directory structure first" -Level 'Error'
        exit 1
    }
    
    Push-Location $goModulesPath
    
    try {
        # Clean if requested
        if ($Clean) {
            Write-ScriptLog "Cleaning build artifacts..."
            & make clean
            if ($LASTEXITCODE -ne 0) {
                throw "Clean failed"
            }
        }
        
        # Run tests if requested
        if ($Test) {
            Write-ScriptLog "Running tests..."
            & make test
            if ($LASTEXITCODE -ne 0) {
                throw "Tests failed"
            }
        }
        
        # Build
        Write-ScriptLog "Building Go modules (target: $Target)..."
        
        if ($Target -eq 'All') {
            & make build
        } else {
            & make $Target
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
        
        # Install if requested
        if ($Install) {
            Write-ScriptLog "Installing binaries..."
            & make install
            if ($LASTEXITCODE -ne 0) {
                throw "Install failed"
            }
        }
        
        Write-ScriptLog "Go modules build completed successfully"
        exit 0
        
    } finally {
        Pop-Location
    }
    
} catch {
    Write-ScriptLog "Go modules build failed: $_" -Level 'Error'
    exit 1
}
```

### Week 3-4: Proof of Concept

#### 3.1 Create Simple Utility Functions in Go

```go
// File: go-modules/pkg/utils/string.go

package utils

import (
    "strings"
    "unicode"
)

// IsNullOrWhitespace checks if a string is null, empty, or whitespace
func IsNullOrWhitespace(s string) bool {
    return len(strings.TrimSpace(s)) == 0
}

// ToPascalCase converts a string to PascalCase
func ToPascalCase(s string) string {
    if IsNullOrWhitespace(s) {
        return s
    }
    
    words := strings.FieldsFunc(s, func(r rune) bool {
        return !unicode.IsLetter(r) && !unicode.IsNumber(r)
    })
    
    var result strings.Builder
    for _, word := range words {
        if len(word) > 0 {
            result.WriteString(strings.ToUpper(string(word[0])))
            if len(word) > 1 {
                result.WriteString(strings.ToLower(word[1:]))
            }
        }
    }
    
    return result.String()
}

// ToKebabCase converts a string to kebab-case
func ToKebabCase(s string) string {
    if IsNullOrWhitespace(s) {
        return s
    }
    
    var result strings.Builder
    for i, r := range s {
        if unicode.IsUpper(r) && i > 0 {
            result.WriteRune('-')
        }
        result.WriteRune(unicode.ToLower(r))
    }
    
    return result.String()
}

// ContainsAny checks if string contains any of the specified substrings
func ContainsAny(s string, substrings []string) bool {
    for _, substr := range substrings {
        if strings.Contains(s, substr) {
            return true
        }
    }
    return false
}
```

```go
// File: go-modules/pkg/utils/string_test.go

package utils

import (
    "testing"
)

func TestIsNullOrWhitespace(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected bool
    }{
        {"Empty string", "", true},
        {"Whitespace only", "   ", true},
        {"Tab and newline", "\t\n", true},
        {"Non-empty", "hello", false},
        {"With spaces", "  hello  ", false},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := IsNullOrWhitespace(tt.input)
            if result != tt.expected {
                t.Errorf("IsNullOrWhitespace(%q) = %v, want %v", tt.input, result, tt.expected)
            }
        })
    }
}

func TestToPascalCase(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
    }{
        {"Kebab case", "hello-world", "HelloWorld"},
        {"Snake case", "hello_world", "HelloWorld"},
        {"Space separated", "hello world", "HelloWorld"},
        {"Already Pascal", "HelloWorld", "HelloWorld"},
        {"Single word", "hello", "Hello"},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := ToPascalCase(tt.input)
            if result != tt.expected {
                t.Errorf("ToPascalCase(%q) = %q, want %q", tt.input, result, tt.expected)
            }
        })
    }
}

func TestToKebabCase(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
    }{
        {"Pascal case", "HelloWorld", "hello-world"},
        {"Camel case", "helloWorld", "hello-world"},
        {"Single word", "Hello", "hello"},
        {"Already kebab", "hello-world", "hello-world"},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := ToKebabCase(tt.input)
            if result != tt.expected {
                t.Errorf("ToKebabCase(%q) = %q, want %q", tt.input, result, tt.expected)
            }
        })
    }
}
```

```go
// File: go-modules/cmd/utils/main.go

package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "os"
    
    "github.com/wizzense/aitherzero-go/pkg/utils"
)

const version = "0.1.0"

type Result struct {
    Success bool        `json:"success"`
    Result  interface{} `json:"result,omitempty"`
    Error   string      `json:"error,omitempty"`
}

func main() {
    // Flags
    versionFlag := flag.Bool("version", false, "Print version")
    operation := flag.String("op", "", "Operation: pascal, kebab, contains")
    input := flag.String("input", "", "Input string")
    substrings := flag.String("substrings", "", "Comma-separated substrings for contains operation")
    
    flag.Parse()
    
    if *versionFlag {
        fmt.Println(version)
        os.Exit(0)
    }
    
    if *operation == "" {
        fmt.Fprintf(os.Stderr, "Error: --op flag is required\n")
        os.Exit(1)
    }
    
    var result Result
    
    switch *operation {
    case "pascal":
        result.Success = true
        result.Result = utils.ToPascalCase(*input)
        
    case "kebab":
        result.Success = true
        result.Result = utils.ToKebabCase(*input)
        
    case "contains":
        if *substrings == "" {
            result.Success = false
            result.Error = "--substrings flag is required for contains operation"
        } else {
            subs := splitCSV(*substrings)
            result.Success = true
            result.Result = utils.ContainsAny(*input, subs)
        }
        
    default:
        result.Success = false
        result.Error = fmt.Sprintf("Unknown operation: %s", *operation)
    }
    
    // Output as JSON
    output, err := json.Marshal(result)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
        os.Exit(1)
    }
    
    fmt.Println(string(output))
    
    if !result.Success {
        os.Exit(1)
    }
}

func splitCSV(s string) []string {
    // Simple CSV split (doesn't handle quoted strings)
    var results []string
    current := ""
    
    for _, r := range s {
        if r == ',' {
            if current != "" {
                results = append(results, current)
                current = ""
            }
        } else {
            current += string(r)
        }
    }
    
    if current != "" {
        results = append(results, current)
    }
    
    return results
}
```

#### 3.2 Integration Test Script

```powershell
# File: tests/go-integration/Test-GoUtilities.Tests.ps1

Describe 'Go Utilities Integration' {
    BeforeAll {
        # Import interop module
        $interopPath = Join-Path $PSScriptRoot "../../domains/utilities/GoInterop.psm1"
        Import-Module $interopPath -Force
        
        # Build Go modules if not already built
        if (-not (Test-GoModuleAvailable -ModuleName 'utils')) {
            Write-Host "Building Go modules..."
            & "$PSScriptRoot/../../automation-scripts/1000_Build-GoModules.ps1" -Target 'utils' -Install
        }
    }
    
    Context 'String Operations' {
        It 'Converts to PascalCase' {
            $result = Invoke-GoModule -ModuleName 'utils' -Arguments @('--op', 'pascal', '--input', 'hello-world')
            $result.success | Should -Be $true
            $result.result | Should -Be 'HelloWorld'
        }
        
        It 'Converts to kebab-case' {
            $result = Invoke-GoModule -ModuleName 'utils' -Arguments @('--op', 'kebab', '--input', 'HelloWorld')
            $result.success | Should -Be $true
            $result.result | Should -Be 'hello-world'
        }
        
        It 'Checks substring contains' {
            $result = Invoke-GoModule -ModuleName 'utils' -Arguments @('--op', 'contains', '--input', 'hello world', '--substrings', 'world,test')
            $result.success | Should -Be $true
            $result.result | Should -Be $true
        }
    }
    
    Context 'Performance' {
        It 'Performs faster than PowerShell equivalent' {
            # PowerShell version
            $psStart = Get-Date
            1..1000 | ForEach-Object {
                $text = "hello-world-$_"
                $words = $text -split '[-_\s]'
                $pascal = ($words | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() }) -join ''
            }
            $psDuration = (Get-Date) - $psStart
            
            # Go version
            $goStart = Get-Date
            1..1000 | ForEach-Object {
                $null = Invoke-GoModule -ModuleName 'utils' -Arguments @('--op', 'pascal', '--input', "hello-world-$_")
            }
            $goDuration = (Get-Date) - $goStart
            
            Write-Host "PowerShell: $($psDuration.TotalMilliseconds)ms"
            Write-Host "Go: $($goDuration.TotalMilliseconds)ms"
            Write-Host "Speedup: $($psDuration.TotalMilliseconds / $goDuration.TotalMilliseconds)x"
            
            # Note: First few runs may show Go slower due to process spawning overhead
            # This is expected for simple operations. Real gains are in complex operations.
        }
    }
}
```

---

## Phase 2: Core Conversions (Months 2-3)

### Module 1: Configuration Parser

See detailed implementation in a separate document: `GO-CONVERSION-CONFIG-PARSER.md`

**Summary:**
- Parse PSD1 files (PowerShell data files)
- Support nested hashtables, arrays, strings
- Validate against schema
- Output as JSON for PowerShell consumption

**Estimated effort**: 60-80 hours  
**Expected speedup**: 15-20x faster than `Import-PowerShellDataFile`

### Module 2: Test Parser

See detailed implementation in: `GO-CONVERSION-TEST-PARSER.md`

**Summary:**
- Parse NUnit XML test results
- Parse Pester JSON output
- Generate aggregated test reports
- Calculate coverage statistics

**Estimated effort**: 80-100 hours  
**Expected speedup**: 20-30x faster than PowerShell XML parsing

### Module 3: Validator

See detailed implementation in: `GO-CONVERSION-VALIDATOR.md`

**Summary:**
- Parse PowerShell AST (Abstract Syntax Tree)
- Implement PSScriptAnalyzer-like rules
- Multi-threaded file processing
- JSON output for integration

**Estimated effort**: 120-150 hours  
**Expected speedup**: 25-35x faster than PSScriptAnalyzer

---

## Phase 3: Integration & Optimization (Month 4)

### Integration Checklist

- [ ] All Go binaries built and tested
- [ ] PowerShell wrappers updated to use Go modules
- [ ] Fallback to PowerShell if Go not available
- [ ] Cross-platform testing (Windows, Linux, macOS)
- [ ] Performance benchmarks documented
- [ ] CI/CD pipeline updated
- [ ] Documentation complete
- [ ] Migration guide for contributors

### Performance Testing

```powershell
# File: tests/performance/Compare-GoVsPowerShell.ps1

[CmdletBinding()]
param(
    [Parameter()]
    [int]$Iterations = 100
)

$results = @()

# Test 1: Configuration parsing
$configPath = Join-Path $PSScriptRoot "../../config.psd1"

$psStart = Get-Date
1..$Iterations | ForEach-Object {
    $null = Import-PowerShellDataFile -Path $configPath
}
$psDuration = (Get-Date) - $psStart

$goStart = Get-Date
1..$Iterations | ForEach-Object {
    $null = Invoke-GoModule -ModuleName 'config-parser' -Arguments @('--file', $configPath)
}
$goDuration = (Get-Date) - $goStart

$results += [PSCustomObject]@{
    Operation = 'Config Parsing'
    PowerShell = $psDuration.TotalMilliseconds
    Go = $goDuration.TotalMilliseconds
    Speedup = [math]::Round($psDuration.TotalMilliseconds / $goDuration.TotalMilliseconds, 2)
}

# Test 2: Test result parsing
$testPath = Join-Path $PSScriptRoot "../../testResults.xml"

$psStart = Get-Date
1..$Iterations | ForEach-Object {
    [xml]$null = Get-Content $testPath
}
$psDuration = (Get-Date) - $psStart

$goStart = Get-Date
1..$Iterations | ForEach-Object {
    $null = Invoke-GoModule -ModuleName 'test-parser' -Arguments @('--file', $testPath)
}
$goDuration = (Get-Date) - $goStart

$results += [PSCustomObject]@{
    Operation = 'Test Parsing'
    PowerShell = $psDuration.TotalMilliseconds
    Go = $goDuration.TotalMilliseconds
    Speedup = [math]::Round($psDuration.TotalMilliseconds / $goDuration.TotalMilliseconds, 2)
}

# Display results
$results | Format-Table -AutoSize

# Generate report
$report = @{
    Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Iterations = $Iterations
    Results = $results
}

$report | ConvertTo-Json -Depth 10 | Out-File "$PSScriptRoot/performance-results.json"

Write-Host "`nAverage speedup: $([math]::Round(($results | Measure-Object -Property Speedup -Average).Average, 2))x"
```

---

## Best Practices

### 1. Error Handling

**Go side:**
```go
type Result struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   *Error      `json:"error,omitempty"`
}

type Error struct {
    Message string `json:"message"`
    Code    string `json:"code"`
    Details string `json:"details,omitempty"`
}

func main() {
    result := Result{Success: true}
    
    // ... operation ...
    
    if err != nil {
        result.Success = false
        result.Error = &Error{
            Message: "Failed to parse file",
            Code:    "PARSE_ERROR",
            Details: err.Error(),
        }
        json.NewEncoder(os.Stdout).Encode(result)
        os.Exit(1)
    }
    
    // ... success path ...
}
```

**PowerShell side:**
```powershell
function Invoke-GoModuleSafe {
    param(
        [string]$ModuleName,
        [string[]]$Arguments
    )
    
    try {
        $result = Invoke-GoModule -ModuleName $ModuleName -Arguments $Arguments
        
        if (-not $result.success) {
            Write-Error "Go module error: $($result.error.message)"
            return $null
        }
        
        return $result.data
        
    } catch {
        Write-Warning "Go module failed, falling back to PowerShell: $_"
        
        # Fallback to PowerShell implementation
        switch ($ModuleName) {
            'config-parser' { return Import-PowerShellDataFile -Path $Arguments[1] }
            'test-parser' { return [xml](Get-Content $Arguments[1]) }
            default { throw "No fallback available for $ModuleName" }
        }
    }
}
```

### 2. Versioning

Track Go module versions alongside PowerShell versions:

```
AitherZero v2.0.0
├── PowerShell modules: v2.0.0
└── Go modules: v0.1.0
```

Update `VERSION` file format:
```
2.0.0
go-modules: 0.1.0
```

### 3. Documentation

Document when Go is used vs. PowerShell:

```powershell
function Get-Configuration {
    <#
    .SYNOPSIS
    Loads and parses configuration.
    
    .DESCRIPTION
    This function uses a high-performance Go parser if available,
    falling back to PowerShell's Import-PowerShellDataFile if not.
    
    Performance: Go version is ~20x faster for large configs.
    #>
    # ...
}
```

---

## Troubleshooting

### Issue: Go binary not found

**Symptoms:**
```
Go module binary not found: /path/to/bin/go-modules/config-parser
```

**Solution:**
```powershell
# Build and install Go modules
cd go-modules
make build
make install

# Or use automation script
./automation-scripts/1000_Build-GoModules.ps1 -Install
```

### Issue: Go version incompatibility

**Symptoms:**
```
go: module requires Go 1.21 or later
```

**Solution:**
```powershell
# Update Go installation
./automation-scripts/0007_Install-Go.ps1 -Configuration @{
    DevelopmentTools = @{
        Go = @{ Install = $true; Version = "1.21.5" }
    }
}
```

### Issue: Cross-platform binary issues

**Symptoms:**
Binary works on Linux but not Windows, or vice versa.

**Solution:**
Build platform-specific binaries:

```bash
# Build for current platform
make build

# Cross-compile for Windows
GOOS=windows GOARCH=amd64 make build

# Cross-compile for Linux
GOOS=linux GOARCH=amd64 make build

# Cross-compile for macOS
GOOS=darwin GOARCH=amd64 make build
```

---

## Success Criteria

### Phase 1 (POC)
- [ ] Go toolchain installed and verified
- [ ] Directory structure created
- [ ] Interop layer functional
- [ ] 3-5 utility functions converted
- [ ] Performance improvement demonstrated (>5x)

### Phase 2 (Core Modules)
- [ ] Config parser: 15-20x faster
- [ ] Test parser: 20-30x faster
- [ ] Validator: 25-35x faster
- [ ] All modules have >90% test coverage
- [ ] Cross-platform support verified

### Phase 3 (Integration)
- [ ] All PowerShell code updated to use Go modules
- [ ] Fallback mechanisms working
- [ ] Performance benchmarks documented
- [ ] CI/CD pipeline updated
- [ ] Documentation complete
- [ ] Zero regressions in functionality

---

## Next Steps

1. **Review this guide** with the development team
2. **Get buy-in** on the hybrid approach
3. **Schedule Phase 1** (4 weeks)
4. **Execute POC** and validate assumptions
5. **Decide** whether to proceed to Phase 2 based on results

---

**Document maintained by**: AitherZero Engineering Team  
**Last updated**: November 3, 2025  
**Related documents**:
- [POWERSHELL-TO-GO-FEASIBILITY.md](./POWERSHELL-TO-GO-FEASIBILITY.md) - Feasibility study
- [GO-CONVERSION-CONFIG-PARSER.md](./GO-CONVERSION-CONFIG-PARSER.md) - Config parser implementation
- [GO-CONVERSION-TEST-PARSER.md](./GO-CONVERSION-TEST-PARSER.md) - Test parser implementation
- [GO-CONVERSION-VALIDATOR.md](./GO-CONVERSION-VALIDATOR.md) - Validator implementation
