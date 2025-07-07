# Track-TestState.ps1 - Smart Test State Tracking System
# Part of AitherZero Unified Test & Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/test-state.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),
    
    [Parameter(Mandatory = $false)]
    [switch]$Initialize,
    
    [Parameter(Mandatory = $false)]
    [switch]$Analyze,
    
    [Parameter(Mandatory = $false)]
    [switch]$Export
)

# Find project root if not specified
if (-not (Test-Path $ProjectRoot)) {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
}

# Import logging if available
if (Test-Path "$ProjectRoot/aither-core/modules/Logging") {
    Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARN"){"Yellow"} else{"Green"})
    }
}

function Initialize-TestState {
    <#
    .SYNOPSIS
    Initializes a new test state tracking file
    
    .DESCRIPTION
    Creates the initial state file with default schema and scans existing tests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )
    
    Write-Log "Initializing test state tracking..." -Level "INFO"
    
    # Create directory if it doesn't exist
    $stateDir = Split-Path $StateFilePath -Parent
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    # Initialize state schema
    $initialState = @{
        version = "1.0"
        lastScan = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        configuration = @{
            changeThresholds = @{
                testStaleDays = 14                 # 2 weeks for test review
                codeChangeReviewDays = 7           # 1 week when code changes but tests don't
                lineDeltaPercent = 15              # 15% line count change threshold
                minSignificantChange = 10          # Minimum 10 line change
                testCoverageThreshold = 70         # Minimum 70% coverage target
            }
            testExecution = @{
                timeoutMinutes = 10
                maxParallelJobs = 5
                retryCount = 2
            }
            qualityGates = @{
                minTestsPerModule = 5
                maxExecutionTimeSeconds = 300
                requiredTestTypes = @("Unit", "Integration")
            }
        }
        modules = @{}
        statistics = @{
            totalModules = 0
            modulesWithTests = 0
            modulesWithoutTests = 0
            staleDays = 0
            averageTestCoverage = 0
            totalTestFiles = 0
            totalTestCases = 0
        }
    }
    
    # Scan project and populate initial state
    $modulesData = Get-ModulesTestState -ProjectRoot $ProjectRoot
    $initialState.modules = $modulesData.modules
    $initialState.statistics = $modulesData.statistics
    
    # Save state file
    $jsonState = $initialState | ConvertTo-Json -Depth 10
    Set-Content -Path $StateFilePath -Value $jsonState -Encoding UTF8
    
    Write-Log "Test state initialized with $($initialState.statistics.totalModules) modules" -Level "SUCCESS"
    Write-Log "State file created: $StateFilePath" -Level "INFO"
    
    return $initialState
}

function Get-ModulesTestState {
    <#
    .SYNOPSIS
    Scans all modules and determines their test state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )
    
    $modules = @{}
    $stats = @{
        totalModules = 0
        modulesWithTests = 0
        modulesWithoutTests = 0
        staleTests = 0
        averageTestCoverage = 0
        totalTestFiles = 0
        totalTestCases = 0
    }
    
    # Get all module directories
    $modulesPath = Join-Path $ProjectRoot "aither-core/modules"
    if (-not (Test-Path $modulesPath)) {
        Write-Log "Modules directory not found: $modulesPath" -Level "WARN"
        return @{ modules = $modules; statistics = $stats }
    }
    
    $moduleDirectories = Get-ChildItem -Path $modulesPath -Directory
    Write-Log "Scanning $($moduleDirectories.Count) modules for test state..." -Level "INFO"
    
    foreach ($moduleDir in $moduleDirectories) {
        $moduleName = $moduleDir.Name
        $modulePath = $moduleDir.FullName
        
        $moduleState = Get-ModuleTestState -ModuleName $moduleName -ModulePath $modulePath -ProjectRoot $ProjectRoot
        $modules[$moduleName] = $moduleState
        
        # Update statistics
        $stats.totalModules++
        if ($moduleState.hasTests) {
            $stats.modulesWithTests++
            $stats.totalTestFiles += $moduleState.testFiles.Count
            $stats.totalTestCases += $moduleState.estimatedTestCases
        } else {
            $stats.modulesWithoutTests++
        }
        
        if ($moduleState.isStale) {
            $stats.staleTests++
        }
    }
    
    # Calculate average coverage
    if ($stats.modulesWithTests -gt 0) {
        $totalCoverage = 0
        foreach ($moduleKey in $modules.Keys) {
            if ($modules[$moduleKey].hasTests) {
                $totalCoverage += $modules[$moduleKey].estimatedCoverage
            }
        }
        $stats.averageTestCoverage = [Math]::Round($totalCoverage / $stats.modulesWithTests, 1)
    }
    
    Write-Log "Test state scan completed: $($stats.modulesWithTests)/$($stats.totalModules) modules have tests" -Level "SUCCESS"
    
    return @{ modules = $modules; statistics = $stats }
}

function Get-ModuleTestState {
    <#
    .SYNOPSIS
    Analyzes a single module's test state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [string]$ModulePath,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )
    
    $moduleState = @{
        moduleName = $ModuleName
        modulePath = $ModulePath.Replace($ProjectRoot, "").TrimStart('\', '/')
        hasTests = $false
        testStrategy = "None"  # None, Distributed, Centralized
        testFiles = @()
        lastTestModified = $null
        lastCodeModified = $null
        isStale = $false
        estimatedTestCases = 0
        estimatedCoverage = 0
        testExecutionResults = @{
            lastRun = $null
            passed = 0
            failed = 0
            duration = 0
            status = "Unknown"
        }
        codeMetrics = @{
            totalFiles = 0
            totalLines = 0
            publicFunctions = 0
            privateFunctions = 0
        }
        flaggedForReview = $false
        reviewReasons = @()
        lastAnalyzed = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    # Check for distributed tests (co-located)
    $distributedTestPath = Join-Path $ModulePath "tests"
    $distributedTestFile = Join-Path $distributedTestPath "$ModuleName.Tests.ps1"
    
    # Check for centralized tests
    $centralizedTestPath = Join-Path $ProjectRoot "tests/unit/modules/$ModuleName"
    
    if (Test-Path $distributedTestFile) {
        $moduleState.hasTests = $true
        $moduleState.testStrategy = "Distributed"
        $moduleState.testFiles += @{
            path = $distributedTestFile.Replace($ProjectRoot, "").TrimStart('\', '/')
            type = "Distributed"
            size = (Get-Item $distributedTestFile).Length
            lastModified = (Get-Item $distributedTestFile).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        $moduleState.lastTestModified = (Get-Item $distributedTestFile).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        
    } elseif (Test-Path $centralizedTestPath) {
        $moduleState.hasTests = $true
        $moduleState.testStrategy = "Centralized"
        
        $centralizedTestFiles = Get-ChildItem -Path $centralizedTestPath -Filter "*.Tests.ps1" -ErrorAction SilentlyContinue
        foreach ($testFile in $centralizedTestFiles) {
            $moduleState.testFiles += @{
                path = $testFile.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                type = "Centralized"
                size = $testFile.Length
                lastModified = $testFile.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        }
        
        if ($centralizedTestFiles.Count -gt 0) {
            $moduleState.lastTestModified = ($centralizedTestFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    }
    
    # Analyze code metrics
    $moduleState.codeMetrics = Get-ModuleCodeMetrics -ModulePath $ModulePath
    $moduleState.lastCodeModified = $moduleState.codeMetrics.lastModified
    
    # Estimate test coverage and case count
    if ($moduleState.hasTests) {
        $moduleState.estimatedTestCases = Get-EstimatedTestCases -TestFiles $moduleState.testFiles -ProjectRoot $ProjectRoot
        $moduleState.estimatedCoverage = Get-EstimatedCoverage -CodeMetrics $moduleState.codeMetrics -TestCases $moduleState.estimatedTestCases
    }
    
    # Check if tests are stale
    $moduleState.isStale = Test-ModuleTestStaleness -ModuleState $moduleState
    
    return $moduleState
}

function Get-ModuleCodeMetrics {
    <#
    .SYNOPSIS
    Analyzes module code metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath
    )
    
    $metrics = @{
        totalFiles = 0
        totalLines = 0
        publicFunctions = 0
        privateFunctions = 0
        lastModified = $null
    }
    
    try {
        # Get all PowerShell files
        $psFiles = Get-ChildItem -Path $ModulePath -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
        $psFiles += Get-ChildItem -Path $ModulePath -Filter "*.psm1" -ErrorAction SilentlyContinue
        
        $metrics.totalFiles = $psFiles.Count
        
        if ($psFiles.Count -gt 0) {
            # Get last modified date
            $metrics.lastModified = ($psFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            
            # Count lines and functions
            foreach ($file in $psFiles) {
                $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
                if ($content) {
                    $metrics.totalLines += $content.Count
                    
                    # Count functions
                    $functionMatches = $content | Select-String -Pattern "^function\s+[A-Za-z]" -AllMatches
                    
                    if ($file.FullName -match "\\Public\\") {
                        $metrics.publicFunctions += $functionMatches.Count
                    } elseif ($file.FullName -match "\\Private\\") {
                        $metrics.privateFunctions += $functionMatches.Count
                    } else {
                        # If not in Public/Private, assume it's mixed - split evenly
                        $metrics.publicFunctions += [Math]::Ceiling($functionMatches.Count / 2)
                        $metrics.privateFunctions += [Math]::Floor($functionMatches.Count / 2)
                    }
                }
            }
        }
        
    } catch {
        Write-Log "Error analyzing code metrics for $ModulePath : $_" -Level "WARN"
    }
    
    return $metrics
}

function Get-EstimatedTestCases {
    <#
    .SYNOPSIS
    Estimates the number of test cases in test files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$TestFiles,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )
    
    $totalTestCases = 0
    
    foreach ($testFile in $TestFiles) {
        try {
            $fullPath = Join-Path $ProjectRoot $testFile.path
            if (Test-Path $fullPath) {
                $content = Get-Content $fullPath -ErrorAction SilentlyContinue
                if ($content) {
                    # Count "It" blocks (Pester test cases)
                    $itMatches = $content | Select-String -Pattern '^\s*It\s+["\']' -AllMatches
                    $totalTestCases += $itMatches.Count
                }
            }
        } catch {
            Write-Log "Error counting test cases in $($testFile.path) : $_" -Level "WARN"
        }
    }
    
    return $totalTestCases
}

function Get-EstimatedCoverage {
    <#
    .SYNOPSIS
    Estimates test coverage based on code metrics and test cases
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CodeMetrics,
        
        [Parameter(Mandatory = $true)]
        [int]$TestCases
    )
    
    if ($CodeMetrics.publicFunctions -eq 0) {
        return 0
    }
    
    # Simple heuristic: assume each test case covers ~1.5 functions on average
    $estimatedCoveredFunctions = $TestCases * 1.5
    $coverage = [Math]::Min(100, [Math]::Round(($estimatedCoveredFunctions / $CodeMetrics.publicFunctions) * 100, 1))
    
    return $coverage
}

function Test-ModuleTestStaleness {
    <#
    .SYNOPSIS
    Determines if module tests are stale based on time gates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleState
    )
    
    if (-not $ModuleState.hasTests) {
        return $true  # No tests = always stale
    }
    
    try {
        $now = Get-Date
        $lastTestModified = [DateTime]::Parse($ModuleState.lastTestModified)
        $lastCodeModified = if ($ModuleState.lastCodeModified) { [DateTime]::Parse($ModuleState.lastCodeModified) } else { $now }
        
        # Check if code was modified after tests (code changes but tests don't)
        if ($lastCodeModified -gt $lastTestModified) {
            $daysSinceCodeChange = ($now - $lastCodeModified).TotalDays
            if ($daysSinceCodeChange -gt 7) {  # codeChangeReviewDays
                return $true
            }
        }
        
        # Check if tests are generally stale
        $daysSinceTestUpdate = ($now - $lastTestModified).TotalDays
        if ($daysSinceTestUpdate -gt 14) {  # testStaleDays
            return $true
        }
        
        return $false
        
    } catch {
        Write-Log "Error checking staleness for $($ModuleState.moduleName) : $_" -Level "WARN"
        return $true  # Assume stale if we can't determine
    }
}

function Update-TestState {
    <#
    .SYNOPSIS
    Updates an existing test state file with current data
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )
    
    Write-Log "Updating test state..." -Level "INFO"
    
    if (-not (Test-Path $StateFilePath)) {
        Write-Log "State file not found, initializing new state" -Level "WARN"
        return Initialize-TestState -StateFilePath $StateFilePath -ProjectRoot $ProjectRoot
    }
    
    # Load existing state
    $currentState = Get-Content -Path $StateFilePath -Raw | ConvertFrom-Json -AsHashtable
    
    # Update scan timestamp
    $currentState.lastScan = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    
    # Re-scan modules
    $modulesData = Get-ModulesTestState -ProjectRoot $ProjectRoot
    $currentState.modules = $modulesData.modules
    $currentState.statistics = $modulesData.statistics
    
    # Save updated state
    $jsonState = $currentState | ConvertTo-Json -Depth 10
    Set-Content -Path $StateFilePath -Value $jsonState -Encoding UTF8
    
    Write-Log "Test state updated with $($currentState.statistics.totalModules) modules" -Level "SUCCESS"
    
    return $currentState
}

function Get-TestState {
    <#
    .SYNOPSIS
    Loads and returns the current test state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFilePath
    )
    
    if (-not (Test-Path $StateFilePath)) {
        Write-Log "Test state file not found: $StateFilePath" -Level "ERROR"
        return $null
    }
    
    try {
        $state = Get-Content -Path $StateFilePath -Raw | ConvertFrom-Json -AsHashtable
        return $state
    } catch {
        Write-Log "Error loading test state: $_" -Level "ERROR"
        return $null
    }
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath
    
    if ($Initialize) {
        $state = Initialize-TestState -StateFilePath $stateFilePath -ProjectRoot $ProjectRoot
    } elseif ($Analyze) {
        $state = Update-TestState -StateFilePath $stateFilePath -ProjectRoot $ProjectRoot
    } elseif ($Export) {
        $state = Get-TestState -StateFilePath $stateFilePath
        if ($state) {
            Write-Host ($state | ConvertTo-Json -Depth 10)
        }
    } else {
        Write-Log "No action specified. Use -Initialize, -Analyze, or -Export" -Level "WARN"
        Write-Log "Usage examples:" -Level "INFO"
        Write-Log "  Initialize: ./Track-TestState.ps1 -Initialize" -Level "INFO"
        Write-Log "  Analyze:    ./Track-TestState.ps1 -Analyze" -Level "INFO"
        Write-Log "  Export:     ./Track-TestState.ps1 -Export" -Level "INFO"
    }
    
} catch {
    Write-Log "Test state tracking failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}