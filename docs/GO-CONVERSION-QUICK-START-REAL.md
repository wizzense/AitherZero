# PowerShell to Go - Actual Quick Start

**For people who can actually code and don't need hand-holding**

---

## Prerequisites

- Go installed: `go version`
- You understand PowerShell
- You understand Go
- That's it

---

## Step 1: Setup (10 minutes)

```bash
cd /path/to/AitherZero

# Initialize Go module if not already done
if [ ! -f go-modules/go.mod ]; then
    ./automation-scripts/1001_Initialize-GoInfrastructure.ps1
fi

cd go-modules

# Verify it works
go mod download
```

---

## Step 2: Pick a Target Function (5 minutes)

Profile your PowerShell code to find slow operations:

```powershell
Measure-Command {
    Import-PowerShellDataFile -Path ./config.psd1
}
# If > 50ms, good candidate

Measure-Command {
    [xml]$x = Get-Content ./testResults.xml
}
# If > 100ms, good candidate

Measure-Command {
    # Your expensive operation here
}
# Profile everything, pick the slowest
```

---

## Step 3: Write Go Implementation (30 mins - 4 hours)

### Example: String Utility

**File: `pkg/utils/string.go`**
```go
package utils

import (
    "strings"
    "unicode"
)

func ToPascalCase(s string) string {
    words := strings.FieldsFunc(s, func(r rune) bool {
        return r == '-' || r == '_' || unicode.IsSpace(r)
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
```

**File: `pkg/utils/string_test.go`**
```go
package utils

import "testing"

func TestToPascalCase(t *testing.T) {
    tests := []struct{ input, want string }{
        {"hello-world", "HelloWorld"},
        {"hello_world", "HelloWorld"},
        {"hello world", "HelloWorld"},
    }
    
    for _, tt := range tests {
        got := ToPascalCase(tt.input)
        if got != tt.want {
            t.Errorf("ToPascalCase(%q) = %q, want %q", tt.input, got, tt.want)
        }
    }
}
```

**File: `cmd/utils/main.go`**
```go
package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "os"
    
    "github.com/wizzense/aitherzero-go/pkg/utils"
)

func main() {
    op := flag.String("op", "", "Operation: pascal, kebab")
    input := flag.String("input", "", "Input string")
    flag.Parse()
    
    if *op == "" || *input == "" {
        fmt.Fprintln(os.Stderr, "Usage: utils --op pascal --input 'hello-world'")
        os.Exit(1)
    }
    
    var result interface{}
    switch *op {
    case "pascal":
        result = utils.ToPascalCase(*input)
    default:
        fmt.Fprintf(os.Stderr, "Unknown operation: %s\n", *op)
        os.Exit(1)
    }
    
    json.NewEncoder(os.Stdout).Encode(map[string]interface{}{
        "success": true,
        "result":  result,
    })
}
```

---

## Step 4: Build and Test (5 minutes)

```bash
cd go-modules

# Build
go build -o bin/utils ./cmd/utils

# Test Go
go test ./pkg/utils
# PASS

# Test CLI
./bin/utils --op pascal --input "hello-world"
# {"success":true,"result":"HelloWorld"}
```

---

## Step 5: Call from PowerShell (10 minutes)

**File: `domains/utilities/StringUtils.psm1` (or add to existing)**

```powershell
function ConvertTo-PascalCase {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)
    
    # Try Go version
    $goBin = Join-Path $PSScriptRoot "../../bin/go-modules/utils"
    if ($IsWindows) { $goBin += '.exe' }
    
    if (Test-Path $goBin) {
        try {
            $result = & $goBin --op pascal --input $Text 2>&1
            if ($LASTEXITCODE -eq 0) {
                $json = $result | ConvertFrom-Json
                if ($json.success) {
                    return $json.result
                }
            }
        } catch {
            # Fall through to PowerShell version
        }
    }
    
    # Fallback: PowerShell implementation
    ($Text -split '[-_\s]' | ForEach-Object {
        $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
    }) -join ''
}

Export-ModuleMember -Function ConvertTo-PascalCase
```

---

## Step 6: Benchmark (5 minutes)

```powershell
# Test both implementations
$iterations = 1000

# PowerShell version
$ps = Measure-Command {
    1..$iterations | ForEach-Object {
        $text = "hello-world-$_"
        ($text -split '[-_\s]' | ForEach-Object {
            $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
        }) -join ''
    }
}

# Go version
$go = Measure-Command {
    1..$iterations | ForEach-Object {
        ConvertTo-PascalCase "hello-world-$_"
    }
}

"PowerShell: $($ps.TotalMilliseconds)ms"
"Go: $($go.TotalMilliseconds)ms"
"Speedup: $([math]::Round($ps.TotalMilliseconds / $go.TotalMilliseconds, 1))x"
```

---

## Common Patterns

### Pattern 1: JSON Output

All Go CLIs should output JSON:

```go
type Result struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
}

func main() {
    result := Result{Success: true}
    
    // ... do work ...
    
    if err != nil {
        result.Success = false
        result.Error = err.Error()
        json.NewEncoder(os.Stdout).Encode(result)
        os.Exit(1)
    }
    
    result.Data = yourData
    json.NewEncoder(os.Stdout).Encode(result)
}
```

### Pattern 2: PowerShell Wrapper

```powershell
function Invoke-GoFunction {
    param(
        [string]$Binary,
        [string[]]$Arguments
    )
    
    $bin = Join-Path $PSScriptRoot "../../bin/go-modules/$Binary"
    if ($IsWindows) { $bin += '.exe' }
    
    if (-not (Test-Path $bin)) {
        throw "Go binary not found: $bin. Run 'make install' in go-modules/"
    }
    
    $json = & $bin @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Go function failed: $json"
    }
    
    return $json | ConvertFrom-Json
}
```

### Pattern 3: Error Handling

```go
func DoWork() error {
    if err := step1(); err != nil {
        return fmt.Errorf("step1: %w", err)
    }
    
    if err := step2(); err != nil {
        return fmt.Errorf("step2: %w", err)
    }
    
    return nil
}

func main() {
    if err := DoWork(); err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}
```

---

## Real Conversion Examples

### Config Parser (2-4 hours)

**What it does:** Parse `config.psd1` (PowerShell data file) to JSON

**Challenge:** PSD1 is not standard JSON/YAML - it's PowerShell syntax

**Options:**
1. Call PowerShell from Go to parse, then work with result
2. Write PSD1 parser in Go (complex)
3. Convert config to JSON/YAML format instead

**Recommendation:** Option 3 is easiest, or Option 1 if you must keep PSD1

### Test Result Parser (1-2 hours)

**What it does:** Parse NUnit XML test results

**Implementation:**
```go
type TestResults struct {
    XMLName xml.Name `xml:"test-results"`
    Total   int      `xml:"total,attr"`
    Errors  int      `xml:"errors,attr"`
    Tests   []TestCase `xml:"test-suite>results>test-case"`
}

func ParseTests(path string) (*TestResults, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    
    var results TestResults
    if err := xml.Unmarshal(data, &results); err != nil {
        return nil, err
    }
    
    return &results, nil
}
```

### Validator (4-8 hours)

**What it does:** Validate PowerShell syntax and style rules

**Challenge:** Most complex conversion - need AST parsing

**Options:**
1. Shell out to PowerShell's AST parser, process in Go
2. Write simple regex-based rules (limited but fast)
3. Use existing Go PowerShell parser library (if exists)

**Recommendation:** Start with Option 2 for quick wins, expand later

---

## AI Assistance (Practical)

**What works:**
```
Convert this PowerShell function to Go. Include tests and a CLI wrapper that outputs JSON.

[paste PowerShell code]
```

**What doesn't work:**
- Asking AI to solve architectural problems
- Expecting perfect code without review
- Blindly trusting complex conversions

**Best use of AI:**
- Generate test scaffolding
- Write CLI boilerplate
- Suggest standard library functions
- Create struct definitions from data

---

## Troubleshooting

### Build fails with "module not found"
```bash
go mod tidy
```

### Binary not found from PowerShell
```bash
# Build and install
cd go-modules
make build
make install  # Copies to ../bin/go-modules/
```

### Tests fail
```bash
# Run with verbose output
go test -v ./...

# Run specific test
go test -v ./pkg/utils -run TestToPascalCase
```

### Cross-platform issues

Build for specific platforms:
```bash
# Windows
GOOS=windows GOARCH=amd64 go build -o bin/utils.exe ./cmd/utils

# Linux
GOOS=linux GOARCH=amd64 go build -o bin/utils ./cmd/utils

# macOS
GOOS=darwin GOARCH=amd64 go build -o bin/utils ./cmd/utils
```

---

## Actual Timeline

| Task | Time |
|------|------|
| Setup infrastructure | 10-30 min |
| First utility function | 30-60 min |
| String utilities module | 1-2 hours |
| Config parser | 2-4 hours |
| Test result parser | 1-2 hours |
| Validation engine | 4-8 hours |
| Integration & testing | 2-4 hours |
| **Total** | **11-21 hours (1.5-3 days)** |

Spread across a weekend or a few evenings.

---

## Done

That's it. No processes, no teams, no meetings. Just:

1. Write Go code
2. Build binary
3. Call from PowerShell
4. Verify it's faster

If you can't do this in 2-3 days, you probably shouldn't be converting to Go.

---

**Reality Check Complete**  
**No Project Management Theater**  
**Just Technical Work**
