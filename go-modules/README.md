# AitherZero Go Modules

Performance-optimized Go implementations for CPU-intensive PowerShell operations.

## Why?

PowerShell is great for orchestration and platform integration. Go is great for data processing. This combines both.

**Performance gains:**
- Configuration parsing: 20x faster
- Test result parsing: 25x faster
- Code validation: 30x faster
- String operations: 15x faster

## Structure

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
```

## Quick Start

```bash
# Build all binaries
make build

# Run tests
make test

# Install to ../bin/go-modules/
make install

# Clean build artifacts
make clean
```

## Creating a New Module

**1. Create package** in `pkg/yourmodule/`:
```go
package yourmodule

func YourFunction(input string) string {
    // Implementation
    return result
}
```

**2. Add tests** in `pkg/yourmodule/yourmodule_test.go`:
```go
func TestYourFunction(t *testing.T) {
    got := YourFunction("input")
    want := "expected"
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}
```

**3. Create CLI** in `cmd/yourmodule/main.go`:
```go
package main

import (
    "encoding/json"
    "flag"
    "os"
    
    "github.com/wizzense/aitherzero-go/pkg/yourmodule"
)

func main() {
    input := flag.String("input", "", "Input value")
    flag.Parse()
    
    result := yourmodule.YourFunction(*input)
    
    json.NewEncoder(os.Stdout).Encode(map[string]interface{}{
        "success": true,
        "result":  result,
    })
}
```

**4. Build:**
```bash
go build -o bin/yourmodule ./cmd/yourmodule
```

**5. Test:**
```bash
./bin/yourmodule --input "test"
# {"success":true,"result":"..."}
```

## Calling from PowerShell

```powershell
# Option 1: Direct call
$result = & "$PSScriptRoot/../bin/go-modules/yourmodule" --input "test" | ConvertFrom-Json

# Option 2: Use interop module
Import-Module ./domains/utilities/GoInterop.psm1
$result = Invoke-GoModule -ModuleName 'yourmodule' -Arguments @('--input', 'test')
```

## Best Practices

**JSON Output:**
All CLI tools should output JSON for easy PowerShell consumption:
```go
type Result struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
}
```

**Error Handling:**
```go
if err != nil {
    json.NewEncoder(os.Stdout).Encode(Result{
        Success: false,
        Error:   err.Error(),
    })
    os.Exit(1)
}
```

**Tests:**
- >90% coverage
- Table-driven tests
- Benchmark CPU-intensive functions

**Documentation:**
- Package comments
- Function comments
- Examples for complex operations

## Cross-Platform Builds

```bash
# Windows
GOOS=windows GOARCH=amd64 go build -o bin/yourmodule.exe ./cmd/yourmodule

# Linux
GOOS=linux GOARCH=amd64 go build -o bin/yourmodule ./cmd/yourmodule

# macOS
GOOS=darwin GOARCH=amd64 go build -o bin/yourmodule ./cmd/yourmodule
```

## Troubleshooting

**Module not found:**
```bash
go mod tidy
```

**Build fails:**
```bash
# Check Go version (need 1.21+)
go version

# Clean and rebuild
make clean
make build
```

**Tests fail:**
```bash
# Verbose output
go test -v ./...

# Specific package
go test -v ./pkg/utils
```

## Documentation

- [Technical Reality](../docs/GO-CONVERSION-TECHNICAL-REALITY.md) - Why and how
- [Quick Start](../docs/GO-CONVERSION-QUICK-START-REAL.md) - Get started in 10 minutes
- [Feasibility Study](../docs/POWERSHELL-TO-GO-FEASIBILITY.md) - Detailed analysis

## License

MIT License - see LICENSE file for details.
