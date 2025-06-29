# CI/CD Refactor Implementation Examples

## Practical Code Examples for Key Components

### 1. Pipeline Configuration Generator

```powershell
# .github/actions/configure-pipeline/Generate-PipelineConfig.ps1
param(
    [string[]]$ChangedFiles,
    [string]$EventName,
    [string]$TestLevelOverride,
    [string]$ConfigPath
)

function Get-ChangeClassification {
    param([string[]]$Files)
    
    $classification = @{
        Type = 'unknown'
        CoreChanges = $false
        ModuleChanges = @()
        AffectsPackages = $false
        SecuritySensitive = $false
    }
    
    foreach ($file in $Files) {
        switch -Regex ($file) {
            '^aither-core/aither-core\.ps1$' { 
                $classification.Type = 'core'
                $classification.CoreChanges = $true
                $classification.AffectsPackages = $true
            }
            '^aither-core/modules/([^/]+)/' {
                $moduleName = $matches[1]
                $classification.ModuleChanges += $moduleName
                
                # Check if it's a core module
                if ($moduleName -in @('Logging', 'LabRunner', 'BackupManager')) {
                    $classification.CoreChanges = $true
                    $classification.AffectsPackages = $true
                }
            }
            '^\.github/workflows/' {
                $classification.Type = 'ci-cd'
            }
            '\.(md|txt)$' {
                if ($classification.Type -eq 'unknown') {
                    $classification.Type = 'docs'
                }
            }
            'SecureCredentials|Security|password|secret' {
                $classification.SecuritySensitive = $true
            }
        }
    }
    
    # Determine final type
    if ($classification.CoreChanges) {
        $classification.Type = 'core'
    } elseif ($classification.ModuleChanges.Count -gt 0) {
        $classification.Type = 'module'
    }
    
    return $classification
}

function Get-OptimalTestLevel {
    param(
        [hashtable]$ChangeInfo,
        [string]$EventName,
        [string]$Override
    )
    
    if ($Override -and $Override -ne 'auto') {
        return $Override
    }
    
    # Load test level configuration
    $testLevels = Get-Content "$ConfigPath/test-levels.json" | ConvertFrom-Json
    
    # Apply auto-detection rules
    switch ($ChangeInfo.Type) {
        'core' { return 'complete' }
        'module' {
            if ($ChangeInfo.ModuleChanges.Count -gt 3) {
                return 'complete'
            }
            return 'standard'
        }
        'docs' { return 'minimal' }
        'ci-cd' { return 'standard' }
        default { return 'standard' }
    }
}

function Get-JobMatrix {
    param(
        [string]$TestLevel,
        [hashtable]$ChangeInfo
    )
    
    $matrixConfig = Get-Content "$ConfigPath/ci-matrix.json" | ConvertFrom-Json
    
    $matrix = @{
        validate = @{
            os = $matrixConfig.platforms.$TestLevel
            validation = $matrixConfig."validation-types".all
        }
        test = @{
            os = $matrixConfig.platforms.$TestLevel
            suite = $matrixConfig."test-suites".$TestLevel
        }
        build = @{
            os = @('ubuntu-latest', 'windows-latest')  # Always test builds on both
        }
    }
    
    # Optimize based on changes
    if ($ChangeInfo.Type -eq 'docs') {
        $matrix.validate.validation = @('syntax')
        $matrix.test = @{ os = @('ubuntu-latest'); suite = @('smoke') }
    }
    
    return $matrix
}

# Main logic
$changeInfo = Get-ChangeClassification -Files $ChangedFiles
$testLevel = Get-OptimalTestLevel -ChangeInfo $changeInfo -EventName $EventName -Override $TestLevelOverride
$matrix = Get-JobMatrix -TestLevel $testLevel -ChangeInfo $changeInfo

# Determine which jobs to skip
$skipJobs = @()
if ($changeInfo.Type -eq 'docs' -and -not $changeInfo.CoreChanges) {
    $skipJobs += 'build', 'security'
}

# Generate cache key
$cacheKey = "pwsh-$([System.Environment]::OSVersion.Platform)-$(Get-Date -Format 'yyyy-MM')-$testLevel"

# Output configuration
$config = @{
    TestLevel = $testLevel
    ChangeInfo = $changeInfo
    Matrix = $matrix
    SkipJobs = $skipJobs
    CacheKey = $cacheKey
    Timeouts = @{
        validate = 10
        test = if ($testLevel -eq 'complete') { 30 } else { 15 }
        build = 10
        security = 10
    }
}

$config | ConvertTo-Json -Depth 10 -Compress
```

### 2. Smart Change Detection

```powershell
# .github/actions/detect-changes/Classify-Changes.ps1
param(
    [string[]]$ChangedFiles
)

class ChangeClassifier {
    [hashtable]$Rules = @{
        Core = @(
            '^aither-core/aither-core\.ps1$',
            '^aither-core/shared/',
            '^Start-AitherZero\.ps1$'
        )
        CoreModules = @(
            'Logging', 'LabRunner', 'BackupManager', 
            'ParallelExecution', 'UnifiedMaintenance'
        )
        DevModules = @(
            'PatchManager', 'TestingFramework', 'DevEnvironment',
            'ISOManager', 'ISOCustomizer'
        )
        PackageFiles = @(
            '^aither-core/',
            '^configs/(default|core|recommended)',
            '^opentofu/',
            '^templates/launchers/',
            '^README\.md$',
            '^LICENSE$'
        )
    }
    
    [string] ClassifyFile([string]$File) {
        # Check if it's a core file
        foreach ($pattern in $this.Rules.Core) {
            if ($File -match $pattern) {
                return 'core'
            }
        }
        
        # Check if it's a module
        if ($File -match '^aither-core/modules/([^/]+)/') {
            $moduleName = $matches[1]
            if ($moduleName -in $this.Rules.CoreModules) {
                return 'core-module'
            } elseif ($moduleName -in $this.Rules.DevModules) {
                return 'dev-module'
            }
            return 'other-module'
        }
        
        # Check file type
        switch -Regex ($File) {
            '\.md$' { return 'docs' }
            '^\.github/' { return 'ci-cd' }
            '^tests/' { return 'tests' }
            '^configs/' { return 'config' }
            default { return 'other' }
        }
    }
    
    [bool] AffectsPackage([string]$File) {
        foreach ($pattern in $this.Rules.PackageFiles) {
            if ($File -match $pattern) {
                return $true
            }
        }
        return $false
    }
}

$classifier = [ChangeClassifier]::new()
$fileClassifications = @{}
$affectedModules = @()
$affectsPackage = $false

foreach ($file in $ChangedFiles) {
    $classification = $classifier.ClassifyFile($file)
    $fileClassifications[$file] = $classification
    
    if ($classifier.AffectsPackage($file)) {
        $affectsPackage = $true
    }
    
    if ($file -match '^aither-core/modules/([^/]+)/') {
        $affectedModules += $matches[1]
    }
}

# Determine overall change type
$changeTypes = $fileClassifications.Values | Select-Object -Unique
$overallType = 'mixed'

if ($changeTypes -contains 'core' -or $changeTypes -contains 'core-module') {
    $overallType = 'core'
} elseif ($changeTypes.Count -eq 1) {
    $overallType = $changeTypes[0]
} elseif ($changeTypes -contains 'dev-module' -and $changeTypes.Count -le 2) {
    $overallType = 'module'
}

@{
    Type = $overallType
    FileClassifications = $fileClassifications
    Modules = $affectedModules | Select-Object -Unique
    AffectsPackage = $affectsPackage
    Stats = @{
        TotalFiles = $ChangedFiles.Count
        FileTypes = $changeTypes
    }
}
```

### 3. Unified Test Runner

```powershell
# .github/actions/run-tests/Run-UnifiedTests.ps1
param(
    [ValidateSet('smoke', 'unit', 'integration', 'e2e', 'performance')]
    [string]$Suite,
    
    [ValidateSet('minimal', 'standard', 'complete')]
    [string]$Level,
    
    [bool]$Coverage = $false,
    
    [string]$OutputPath = './tests/results'
)

# Import required modules
$projectRoot = $env:GITHUB_WORKSPACE ?? (Get-Location).Path
Import-Module "$projectRoot/aither-core/modules/Logging" -Force

Write-CustomLog -Level 'INFO' -Message "Starting $Suite tests at $Level level"

# Configure test parameters based on suite and level
$testParams = @{
    OutputFile = Join-Path $OutputPath "$Suite-results.xml"
    OutputFormat = 'NUnitXml'
}

switch ($Suite) {
    'smoke' {
        $testParams.Path = "$projectRoot/tests/smoke"
        $testParams.Tag = 'Smoke'
    }
    'unit' {
        $testParams.Path = "$projectRoot/tests/unit"
        $testParams.ExcludeTag = 'Integration', 'E2E'
        
        if ($Coverage) {
            $testParams.CodeCoverage = @{
                Path = "$projectRoot/aither-core"
                OutputPath = Join-Path $OutputPath "coverage-$Suite.xml"
                OutputFormat = 'JaCoCo'
            }
        }
    }
    'integration' {
        $testParams.Path = "$projectRoot/tests/integration"
        $testParams.Tag = 'Integration'
    }
    'e2e' {
        $testParams.Path = "$projectRoot/tests/e2e"
        $testParams.Tag = 'E2E'
    }
    'performance' {
        $testParams.Path = "$projectRoot/tests/performance"
        $testParams.Tag = 'Performance'
    }
}

# Adjust parameters based on level
switch ($Level) {
    'minimal' {
        $testParams.Tag = 'Critical'
        $testParams.FailFast = $true
    }
    'standard' {
        # Default parameters
    }
    'complete' {
        $testParams.Strict = $true
        if ($Suite -eq 'unit') {
            $testParams.CodeCoverage.CoveragePercentTarget = 80
        }
    }
}

try {
    # Run the tests
    $results = Invoke-Pester @testParams -PassThru
    
    # Generate summary
    $summary = @"
## Test Results: $Suite ($Level)

- **Total Tests**: $($results.TotalCount)
- **Passed**: $($results.PassedCount)
- **Failed**: $($results.FailedCount)
- **Skipped**: $($results.SkippedCount)
- **Duration**: $($results.Duration.TotalSeconds)s

"@
    
    if ($Coverage -and $results.CodeCoverage) {
        $coverage = $results.CodeCoverage.CoveragePercent
        $summary += @"
### Code Coverage
- **Coverage**: $coverage%
- **Lines Covered**: $($results.CodeCoverage.NumberOfCommandsExecuted)/$($results.CodeCoverage.NumberOfCommandsAnalyzed)

"@
    }
    
    # Output to GitHub summary
    if ($env:GITHUB_STEP_SUMMARY) {
        $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append
    }
    
    # Check if tests passed
    if ($results.FailedCount -gt 0) {
        Write-CustomLog -Level 'ERROR' -Message "$($results.FailedCount) tests failed"
        exit 1
    }
    
    Write-CustomLog -Level 'SUCCESS' -Message "All $Suite tests passed"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Test execution failed: $_"
    throw
}
```

### 4. Enhanced Security Scanner

```yaml
# .github/workflows/_reusable/security-scan.yml
name: Security Scan

on:
  workflow_call:
    inputs:
      config:
        required: true
        type: string

jobs:
  scan:
    name: Security Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy Scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'
          
      - name: Run PowerShell Security Analysis
        shell: pwsh
        run: |
          # Custom PowerShell security checks
          $issues = @()
          
          # Check for hardcoded secrets
          $secretPatterns = @(
            'password\s*=\s*["\'](?!.*\$)[^"\']+["\']',
            'apikey\s*=\s*["\'][A-Za-z0-9]{20,}["\']',
            'token\s*=\s*["\'][A-Za-z0-9]{20,}["\']'
          )
          
          Get-ChildItem -Path . -Include *.ps1,*.psm1 -Recurse | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            foreach ($pattern in $secretPatterns) {
              if ($content -match $pattern) {
                $issues += @{
                  File = $_.FullName
                  Issue = "Potential hardcoded secret"
                  Pattern = $pattern
                }
              }
            }
          }
          
          # Check for unsafe practices
          $unsafePatterns = @{
            'Invoke-Expression' = 'Code injection risk'
            '-AsPlainText -Force' = 'Insecure credential handling'
            'TrustAllCertsPolicy' = 'Certificate validation bypass'
          }
          
          foreach ($pattern in $unsafePatterns.Keys) {
            Get-ChildItem -Path . -Include *.ps1,*.psm1 -Recurse | 
              Select-String -Pattern $pattern | 
              ForEach-Object {
                $issues += @{
                  File = $_.Path
                  Line = $_.LineNumber
                  Issue = $unsafePatterns[$pattern]
                  Content = $_.Line.Trim()
                }
              }
          }
          
          # Generate SARIF output
          $sarif = @{
            version = "2.1.0"
            runs = @(@{
              tool = @{
                driver = @{
                  name = "PowerShell Security Scanner"
                  version = "1.0.0"
                }
              }
              results = $issues | ForEach-Object {
                @{
                  ruleId = "PS001"
                  level = "warning"
                  message = @{ text = $_.Issue }
                  locations = @(@{
                    physicalLocation = @{
                      artifactLocation = @{ uri = $_.File }
                      region = @{ startLine = $_.Line ?? 1 }
                    }
                  })
                }
              }
            })
          }
          
          $sarif | ConvertTo-Json -Depth 10 | Out-File -FilePath "powershell-security.sarif"
          
      - name: Upload SARIF Results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: |
            trivy-results.sarif
            powershell-security.sarif
```

### 5. Pipeline Status Notifier

```powershell
# .github/actions/notify-status/Send-PipelineNotification.ps1
param(
    [string]$Config,
    [string]$Jobs,
    [bool]$NotifyPR = $false
)

$configObj = $Config | ConvertFrom-Json
$jobsObj = $Jobs | ConvertFrom-Json

# Calculate overall status
$overallStatus = 'success'
$failedJobs = @()

foreach ($job in $jobsObj.PSObject.Properties) {
    if ($job.Value.result -eq 'failure') {
        $overallStatus = 'failure'
        $failedJobs += $job.Name
    } elseif ($job.Value.result -eq 'cancelled' -and $overallStatus -ne 'failure') {
        $overallStatus = 'cancelled'
    }
}

# Generate summary
$emoji = switch ($overallStatus) {
    'success' { '✅' }
    'failure' { '❌' }
    'cancelled' { '⚠️' }
    default { '❓' }
}

$summary = @"
## $emoji CI/CD Pipeline Results

**Overall Status**: $overallStatus
**Test Level**: $($configObj.TestLevel)
**Change Type**: $($configObj.ChangeInfo.Type)

### Job Results
"@

foreach ($job in $jobsObj.PSObject.Properties) {
    $jobEmoji = switch ($job.Value.result) {
        'success' { '✅' }
        'failure' { '❌' }
        'skipped' { '⏭️' }
        default { '⏸️' }
    }
    $summary += "`n- $jobEmoji **$($job.Name)**: $($job.Value.result)"
}

if ($failedJobs.Count -gt 0) {
    $summary += @"

### Failed Jobs
$($failedJobs | ForEach-Object { "- $_" } | Out-String)

Please check the workflow logs for details.
"@
}

# Add performance metrics if available
if (Test-Path './pipeline-metrics.json') {
    $metrics = Get-Content './pipeline-metrics.json' | ConvertFrom-Json
    $summary += @"

### Performance Metrics
- **Total Duration**: $($metrics.Duration)s
- **Cache Hit Rate**: $($metrics.CacheHitRate)%
- **Tests Run**: $($metrics.TestsRun)
"@
}

# Output to GitHub summary
$summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY

# Post PR comment if needed
if ($NotifyPR -and $env:GITHUB_EVENT_NAME -eq 'pull_request') {
    # This would be handled by the GitHub Script action in the workflow
    Write-Output "pr-comment<<EOF" >> $env:GITHUB_OUTPUT
    Write-Output $summary >> $env:GITHUB_OUTPUT
    Write-Output "EOF" >> $env:GITHUB_OUTPUT
}

# Send to external notification systems (Slack, Teams, etc.)
if ($configObj.Notifications) {
    # Implementation would go here
    Write-Host "Sending notifications to configured channels..."
}
```

## Complete Working Example

Here's how these components work together in practice:

```yaml
# Example PR workflow execution
name: CI/CD Pipeline
run-name: PR #123 - Add new feature

jobs:
  configure:
    # Detects changes in:
    # - aither-core/modules/NewFeature/
    # - tests/unit/modules/NewFeature/
    # Result: module change, standard test level
    
  validate:
    # Runs in parallel:
    # - Syntax check on ubuntu-latest
    # - Lint check on ubuntu-latest, windows-latest
    # - Format check on ubuntu-latest
    
  test:
    # Runs in parallel:
    # - Unit tests on ubuntu-latest, windows-latest
    # - Integration tests on ubuntu-latest, windows-latest
    
  security:
    # Runs: Trivy + PowerShell security analysis
    
  build:
    # Validates build on ubuntu-latest, windows-latest
    
  status:
    # Posts PR comment with results
    # Sends Slack notification
    # Updates GitHub status
```

This architecture provides a clean, maintainable, and efficient CI/CD pipeline that addresses all identified issues while maintaining the sophisticated testing capabilities of the current system.