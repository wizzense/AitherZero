# PlaybookHelpers - Making Playbook Creation Easy!

The **PlaybookHelpers** module provides developer-friendly tools for creating, validating, and understanding AitherZero orchestration playbooks.

## 🎯 Why PlaybookHelpers?

**Before** PlaybookHelpers, creating playbooks was challenging:
- ❌ Manual hashtable construction (error-prone)
- ❌ Case-sensitive property names caused silent failures
- ❌ Errors only appeared at runtime with cryptic messages
- ❌ Had to open playbook files to understand what they do

**Now** with PlaybookHelpers:
- ✅ Template generation (no manual hashtables!)
- ✅ Pre-flight validation (catch errors before running)
- ✅ Detailed error messages (know exactly what's wrong)
- ✅ Quick script info (understand at a glance)

## 📚 Available Functions

### 1. New-PlaybookTemplate

Generate playbook templates with sensible defaults.

```powershell
# Create a testing playbook
New-PlaybookTemplate -Name 'my-validation' -Scripts @('0407', '0413') -Type Testing

# Create a CI playbook
New-PlaybookTemplate -Name 'pr-checks' -Scripts @('0404', '0407') -Type CI

# Create a deployment playbook
New-PlaybookTemplate -Name 'deploy-staging' -Type Deployment
```

**Parameters:**
- **Name**: Playbook name (lowercase-with-dashes)
- **Scripts**: Array of script numbers to include (e.g., @('0407', '0413'))
- **Type**: Template type (Simple, Testing, CI, Deployment)
- **Description**: Human-readable description (optional)
- **OutputPath**: Where to save (defaults to library/playbooks/)

**Template Types:**
- **Simple**: Basic playbook with minimal configuration
- **Testing**: Test-optimized (sequential, fail-fast, test variables)
- **CI**: CI/CD optimized (non-interactive, fail-fast, CI variables)
- **Deployment**: Deployment-optimized (environment-aware, dry-run support)

### 2. Test-PlaybookDefinition

Validate playbooks BEFORE running them.

```powershell
# Validate a playbook
Test-PlaybookDefinition -Path './library/playbooks/my-test.psd1'

# Strict validation (warns about missing descriptions)
Test-PlaybookDefinition -Path './my-test.psd1' -Strict
```

**What it validates:**
- ✅ Required properties (Name, Sequence)
- ✅ Property types (Parameters is hashtable, Timeout is int)
- ✅ Script numbers exist in automation-scripts/
- ✅ Timeout values are reasonable (positive, not too large)
- ✅ Parameter compatibility
- ✅ Variable references

**Output:**
- ❌ **Errors**: Must be fixed before playbook can run
- ⚠️ **Warnings**: Should be addressed but won't prevent execution
- ✅ **Info**: Success messages and counts

**Example Output:**
```
📋 Playbook Validation: my-test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❌ ERRORS (2):
   • Script #2 : Script file not found in automation-scripts/
   • Script #3 : Timeout must be positive, got -30

⚠️  WARNINGS (1):
   • Script #1 : Missing 'Description' (recommended)

✅ SUCCESS:
   • Loaded playbook from: ./my-test.psd1
   • Validated 3 script(s) in sequence

💥 Playbook has errors that must be fixed before use
```

### 3. Get-PlaybookScriptInfo

Quick overview of playbook scripts.

```powershell
# View playbook scripts
Get-PlaybookScriptInfo -PlaybookName 'pr-validation-fast'

# Or by path
Get-PlaybookScriptInfo -Path './library/playbooks/my-test.psd1'
```

**Output:**
```
📚 Playbook: pr-validation-fast
   Fast PR validation - essential checks only (< 2 min)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📜 Scripts (2):

   1. [0407] 0407_Validate-Syntax.ps1
      → Quick syntax validation
      Parameters: All
      Timeout: 60s

   2. [0413] 0413_Validate-ConfigManifest.ps1
      → Config validation
      Timeout: 30s
```

### 4. ConvertTo-NormalizedParameter

Convert parameter values to match script parameter types (internal helper).

```powershell
# Convert string 'true' to switch parameter
ConvertTo-NormalizedParameter -Value 'true' -ParameterType ([switch])
# Returns: $true

# Convert string to integer
ConvertTo-NormalizedParameter -Value '300' -ParameterType ([int])
# Returns: 300
```

This function is used internally by OrchestrationEngine to ensure parameters passed to scripts are the correct type.

## 🚀 Quick Start Guide

### Step 1: Create a Playbook

```powershell
# Generate a template
New-PlaybookTemplate -Name 'my-validation' -Scripts @('0407', '0413') -Type Testing
```

This creates `library/playbooks/my-validation.psd1` with a ready-to-use template.

### Step 2: Customize the Playbook

Edit the generated file to customize:
- Script descriptions
- Parameters for each script
- Timeouts
- Variables
- Execution options

```powershell
@{
    Name = 'my-validation'
    Description = 'Custom validation checks'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0407'
            Description = 'Validate PowerShell syntax'
            Parameters = @{ All = $true }  # Customize here!
            ContinueOnError = $false
            Timeout = 120  # Adjust timeout
        }
    )
    
    Variables = @{
        ReportsPath = './custom-reports'  # Add variables
    }
}
```

### Step 3: Validate the Playbook

```powershell
# Check for errors
Test-PlaybookDefinition -Path './library/playbooks/my-validation.psd1'
```

Fix any errors or warnings reported.

### Step 4: Review Scripts

```powershell
# See what the playbook will do
Get-PlaybookScriptInfo -PlaybookName 'my-validation'
```

### Step 5: Test Run

```powershell
# Dry run (see what would execute)
Invoke-OrchestrationSequence -LoadPlaybook 'my-validation' -DryRun

# Actual run
Invoke-OrchestrationSequence -LoadPlaybook 'my-validation'
```

## 💡 Tips & Best Practices

### Tip 1: Always Validate Before Running

```powershell
# Good practice: Validate first
Test-PlaybookDefinition -Path './library/playbooks/my-test.psd1'

# Then run if valid
Invoke-OrchestrationSequence -LoadPlaybook 'my-test'
```

### Tip 2: Use Templates for Consistency

Don't create playbooks from scratch - use templates:
```powershell
# CI template includes CI variables automatically
New-PlaybookTemplate -Name 'ci-validation' -Type CI

# Testing template includes test-optimized settings
New-PlaybookTemplate -Name 'unit-tests' -Type Testing
```

### Tip 3: Add Meaningful Descriptions

```powershell
@{
    Script = '0407'
    Description = 'Validate PowerShell syntax across all core modules'  # Good!
    # vs
    Description = 'Syntax check'  # Too vague
}
```

### Tip 4: Set Appropriate Timeouts

```powershell
@{
    Script = '0407'
    Timeout = 60  # Short timeout for fast scripts
}

@{
    Script = '0402'
    Timeout = 300  # Longer timeout for test suites
}
```

### Tip 5: Use Strict Validation for Production

```powershell
# Production playbooks should pass strict validation
Test-PlaybookDefinition -Path './deploy-prod.psd1' -Strict
```

## 📖 Examples

### Example 1: Quick Validation Playbook

```powershell
New-PlaybookTemplate `
    -Name 'quick-check' `
    -Scripts @('0407') `
    -Type Testing `
    -Description 'Fast syntax validation for pre-commit'
```

### Example 2: Comprehensive CI Playbook

```powershell
New-PlaybookTemplate `
    -Name 'ci-full-validation' `
    -Scripts @('0404', '0407', '0402', '0403') `
    -Type CI `
    -Description 'Complete CI validation suite'
```

### Example 3: Staged Deployment Playbook

```powershell
New-PlaybookTemplate `
    -Name 'deploy-staging' `
    -Scripts @('0100', '0101', '0105') `
    -Type Deployment `
    -Description 'Deploy to staging environment'
```

## 🔍 Troubleshooting

### Error: "Script file not found in automation-scripts/"

**Cause**: Script number doesn't exist or is mistyped.

**Fix**: 
1. Check available scripts: `ls ./library/automation-scripts/ | grep <number>`
2. Use correct 4-digit number: `'0407'` not `'407'` or `'0407_Validate-Syntax.ps1'`

### Error: "Timeout must be positive"

**Cause**: Timeout value is 0, negative, or not a number.

**Fix**: Use positive integer (seconds):
```powershell
Timeout = 300  # 5 minutes
```

### Error: "Parameters must be a hashtable"

**Cause**: Parameters property is not a hashtable.

**Fix**: Use hashtable syntax:
```powershell
Parameters = @{ All = $true; Fast = $false }
# Not: Parameters = 'All'
```

### Warning: "Missing 'Description' (recommended)"

**Cause**: Script definition lacks description (strict mode).

**Fix**: Add description to each script:
```powershell
@{
    Script = '0407'
    Description = 'Validate PowerShell syntax'  # Add this
    Parameters = @{}
}
```

## 🎓 Advanced Usage

### Custom Output Path

```powershell
# Save template to custom location
New-PlaybookTemplate `
    -Name 'custom-test' `
    -Scripts @('0407') `
    -OutputPath './custom-playbooks/my-test.psd1'
```

### Programmatic Validation

```powershell
# Get validation result object
$result = Test-PlaybookDefinition -Path './my-test.psd1'

if ($result.IsValid) {
    Write-Host "✅ Playbook is valid"
    Invoke-OrchestrationSequence -LoadPlaybook 'my-test'
} else {
    Write-Host "❌ Errors: $($result.Errors -join '; ')"
    exit 1
}
```

### Batch Validation

```powershell
# Validate all playbooks
Get-ChildItem './library/playbooks/*.psd1' | ForEach-Object {
    Write-Host "`nValidating: $($_.Name)"
    Test-PlaybookDefinition -Path $_.FullName
}
```

## 📚 Related Documentation

- **OrchestrationEngine**: Core orchestration system
- **Playbook Format**: Structure and properties
- **Automation Scripts**: Available scripts (0000-9999)

## 🤝 Contributing

Found a bug or have a suggestion? Create an issue or submit a PR!

### Adding New Template Types

To add a new template type, edit `PlaybookHelpers.psm1` and add to the `$typeDefaults` switch in `New-PlaybookTemplate`.

---

**Rachel PowerShell** - Making automation easy, one script at a time! 🚀
