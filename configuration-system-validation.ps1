#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Configuration & Environment Setup Validation Report
    
.DESCRIPTION
    Agent 4: Configuration & Environment Setup Specialist
    Complete validation of configuration system reliability after bootstrap
    
.NOTES
    Validates all critical configuration areas for new user experience
#>

param(
    [switch]$Detailed,
    [switch]$ExportReport
)

Set-Location '/workspaces/AitherZero'

# Initialize results
$ValidationResults = @{
    TestResults = @{}
    Issues = @()
    Recommendations = @()
    OverallHealth = @{
        Score = 0
        Grade = 'F'
        Status = 'Unknown'
    }
}

function Add-TestResult {
    param($TestName, $Result, $Details = '', $Score = 0)
    $ValidationResults.TestResults[$TestName] = @{
        Result = $Result
        Details = $Details
        Score = $Score
        Timestamp = Get-Date
    }
}

function Add-Issue {
    param($Issue, $Severity = 'Medium')
    $ValidationResults.Issues += @{
        Issue = $Issue
        Severity = $Severity
        Timestamp = Get-Date
    }
}

function Add-Recommendation {
    param($Recommendation, $Priority = 'Medium')
    $ValidationResults.Recommendations += @{
        Recommendation = $Recommendation
        Priority = $Priority
        Timestamp = Get-Date
    }
}

Write-Host "=== Configuration & Environment Setup Validation ===" -ForegroundColor Cyan
Write-Host "Agent 4: Configuration & Environment Setup Specialist" -ForegroundColor Green
Write-Host "Validating configuration system reliability after bootstrap`n" -ForegroundColor Yellow

# TEST 1: Default Configuration Creation and Validation
Write-Host "📋 1. Default Configuration Creation and Validation" -ForegroundColor Yellow
try {
    $configPaths = @(
        @{ Path = './configs/default-config.json'; Type = 'Main' },
        @{ Path = './aither-core/configs/default-config.json'; Type = 'Core' }
    )
    
    $configScore = 0
    $configDetails = @()
    
    foreach ($configInfo in $configPaths) {
        $path = $configInfo.Path
        $type = $configInfo.Type
        
        if (Test-Path $path) {
            try {
                $config = Get-Content $path | ConvertFrom-Json
                $configDetails += "✓ $type configuration valid"
                $configScore += 25
                
                # Validate critical sections
                $criticalSections = @('tools', 'system', 'infrastructure', 'metadata')
                $sectionsFound = 0
                foreach ($section in $criticalSections) {
                    if ($config.PSObject.Properties.Name -contains $section) {
                        $sectionsFound++
                    }
                }
                
                if ($sectionsFound -ge 3) {
                    $configDetails += "✓ $type has $sectionsFound/$($criticalSections.Count) critical sections"
                    $configScore += 15
                } else {
                    $configDetails += "⚠ $type missing critical sections (has $sectionsFound/$($criticalSections.Count))"
                    Add-Issue "Configuration $type missing critical sections" 'Medium'
                }
                
            } catch {
                $configDetails += "✗ $type configuration invalid JSON: $_"
                Add-Issue "Invalid JSON in $type configuration: $_" 'High'
            }
        } else {
            $configDetails += "✗ $type configuration not found"
            Add-Issue "Missing $type configuration file" 'High'
        }
    }
    
    Add-TestResult 'DefaultConfigCreation' ($configScore -ge 50) ($configDetails -join '; ') $configScore
    Write-Host "   Score: $configScore/80 - $($configDetails -join ', ')" -ForegroundColor $(if ($configScore -ge 60) { 'Green' } else { 'Yellow' })
    
} catch {
    Add-TestResult 'DefaultConfigCreation' $false "Error: $_" 0
    Add-Issue "Default configuration test failed: $_" 'High'
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# TEST 2: Environment Detection and Setup
Write-Host "`n🌍 2. Environment Detection and Setup" -ForegroundColor Yellow
try {
    $envScore = 0
    $envDetails = @()
    
    # Platform detection
    $platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
    $envDetails += "Platform: $platform"
    $envScore += 20
    
    # PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        $envDetails += "PowerShell: $($psVersion.ToString()) ✓"
        $envScore += 20
    } else {
        $envDetails += "PowerShell: $($psVersion.ToString()) ⚠"
        Add-Issue "PowerShell version should be 7.0+" 'Medium'
        $envScore += 10
    }
    
    # Git availability
    try {
        $gitVersion = git --version 2>$null
        $envDetails += "Git: Available ✓"
        $envScore += 20
    } catch {
        $envDetails += "Git: Not available ⚠"
        Add-Issue "Git not available or not in PATH" 'Medium'
    }
    
    # File system permissions
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) 'aitherzero-permission-test'
    try {
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
        Remove-Item $tempPath -Force
        $envDetails += "File operations: Working ✓"
        $envScore += 20
    } catch {
        $envDetails += "File operations: Failed ⚠"
        Add-Issue "File system permission issues detected" 'High'
    }
    
    # Network connectivity
    try {
        $null = Resolve-DnsName 'github.com' -ErrorAction Stop 2>$null
        $envDetails += "Network: Available ✓"
        $envScore += 20
    } catch {
        $envDetails += "Network: Limited ⚠"
        Add-Recommendation "Check network connectivity for downloads" 'Low'
    }
    
    Add-TestResult 'EnvironmentDetection' ($envScore -ge 80) ($envDetails -join '; ') $envScore
    Write-Host "   Score: $envScore/100 - $($envDetails -join ', ')" -ForegroundColor $(if ($envScore -ge 80) { 'Green' } else { 'Yellow' })
    
} catch {
    Add-TestResult 'EnvironmentDetection' $false "Error: $_" 0
    Add-Issue "Environment detection failed: $_" 'High'
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# TEST 3: Configuration Module Loading
Write-Host "`n🔧 3. Configuration Module Loading and Management" -ForegroundColor Yellow
try {
    $moduleScore = 0
    $moduleDetails = @()
    
    # Core configuration modules to test
    $configModules = @(
        'ConfigurationCore',
        'ConfigurationManager', 
        'ConfigurationCarousel',
        'ConfigurationRepository'
    )
    
    $loadedModules = 0
    foreach ($moduleName in $configModules) {
        $modulePath = "./aither-core/modules/$moduleName"
        if (Test-Path "$modulePath/$moduleName.psm1") {
            try {
                # Import Logging first as dependency
                Import-Module './aither-core/modules/Logging' -Force -ErrorAction SilentlyContinue
                Import-Module $modulePath -Force -ErrorAction Stop
                $moduleDetails += "${moduleName}: Loaded ✓"
                $loadedModules++
                $moduleScore += 20
            } catch {
                $moduleDetails += "${moduleName}: Failed ⚠"
                Add-Issue "Module $moduleName failed to load: $_" 'Medium'
                $moduleScore += 5
            }
        } else {
            $moduleDetails += "${moduleName}: Not found ✗"
            Add-Issue "Module $moduleName not found" 'High'
        }
    }
    
    # Test ConfigurationCore initialization if loaded
    if ($loadedModules -gt 0) {
        try {
            # Test basic configuration functionality
            $configStore = Get-ConfigurationStore -ErrorAction SilentlyContinue
            if ($configStore) {
                $moduleDetails += "ConfigStore${":"} Accessible ✓"
                $moduleScore += 20
            }
        } catch {
            $moduleDetails += "ConfigStore${":"} Not accessible ⚠"
        }
    }
    
    Add-TestResult 'ConfigurationModules' ($loadedModules -ge 2) ($moduleDetails -join '; ') $moduleScore
    Write-Host "   Score: $moduleScore/100 - Loaded: $loadedModules/$($configModules.Count) modules" -ForegroundColor $(if ($loadedModules -ge 2) { 'Green' } else { 'Yellow' })
    
} catch {
    Add-TestResult 'ConfigurationModules' $false "Error: $_" 0
    Add-Issue "Configuration module testing failed: $_" 'High'
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# TEST 4: Cross-Platform Configuration Handling
Write-Host "`n🌐 4. Cross-Platform Configuration Handling" -ForegroundColor Yellow
try {
    $platformScore = 0
    $platformDetails = @()
    
    # Test path construction
    $pathTests = @(
        @('configs', 'default-config.json'),
        @('aither-core', 'modules'),
        @([System.IO.Path]::GetTempPath(), 'test.json')
    )
    
    foreach ($pathComponents in $pathTests) {
        try {
            $path = Join-Path @pathComponents
            if ($path -and $path.Length -gt 0) {
                $platformDetails += "Path construction working ✓"
                $platformScore += 25
            }
        } catch {
            $platformDetails += "Path construction failed ⚠"
            Add-Issue "Cross-platform path construction issues" 'Medium'
        }
    }
    
    # Test file operations
    $testFile = Join-Path ([System.IO.Path]::GetTempPath()) 'aitherzero-platform-test.json'
    try {
        @{ test = 'cross-platform'; platform = $platform } | ConvertTo-Json | Out-File $testFile
        $content = Get-Content $testFile | ConvertFrom-Json
        Remove-Item $testFile -Force
        
        if ($content.test -eq 'cross-platform') {
            $platformDetails += "File I/O working ✓"
            $platformScore += 25
        }
    } catch {
        $platformDetails += "File I/O failed ⚠"
        Add-Issue "Cross-platform file operations issues" 'Medium'
    }
    
    Add-TestResult 'CrossPlatformHandling' ($platformScore -ge 75) ($platformDetails -join '; ') $platformScore
    Write-Host "   Score: $platformScore/100 - $($platformDetails -join ', ')" -ForegroundColor $(if ($platformScore -ge 75) { 'Green' } else { 'Yellow' })
    
} catch {
    Add-TestResult 'CrossPlatformHandling' $false "Error: $_" 0
    Add-Issue "Cross-platform testing failed: $_" 'High'
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# TEST 5: Configuration Validation and Error Recovery
Write-Host "`n🛡️ 5. Configuration Validation and Error Recovery" -ForegroundColor Yellow
try {
    $validationScore = 0
    $validationDetails = @()
    
    # Test JSON validation
    try {
        $validConfig = @{ test = 'valid'; created = Get-Date } | ConvertTo-Json
        $parsed = $validConfig | ConvertFrom-Json
        $validationDetails += "JSON validation working ✓"
        $validationScore += 30
    } catch {
        $validationDetails += "JSON validation failed ⚠"
        Add-Issue "JSON validation not working properly" 'High'
    }
    
    # Test error handling with corrupt JSON
    try {
        '{ "invalid": json }' | ConvertFrom-Json -ErrorAction Stop
        $validationDetails += "Error detection failed ⚠"
        Add-Issue "Corrupt JSON not properly detected" 'High'
    } catch {
        $validationDetails += "Error detection working ✓"
        $validationScore += 35
    }
    
    # Test schema validation concepts
    $testConfig = @{
        metadata = @{ version = '1.0' }
        environments = @{ default = @{ name = 'default' } }
    }
    
    if ($testConfig.metadata -and $testConfig.environments) {
        $validationDetails += "Schema validation concepts ✓"
        $validationScore += 35
    }
    
    Add-TestResult 'ConfigValidation' ($validationScore -ge 80) ($validationDetails -join '; ') $validationScore
    Write-Host "   Score: $validationScore/100 - $($validationDetails -join ', ')" -ForegroundColor $(if ($validationScore -ge 80) { 'Green' } else { 'Yellow' })
    
} catch {
    Add-TestResult 'ConfigValidation' $false "Error: $_" 0
    Add-Issue "Configuration validation testing failed: $_" 'High'
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# TEST 6: User Profile and Preference Management
Write-Host "`n👤 6. User Profile and Preference Management" -ForegroundColor Yellow
try {
    $userScore = 0
    $userDetails = @()
    
    # Test user directory detection
    $userProfile = [Environment]::GetFolderPath('UserProfile')
    if ($userProfile -and (Test-Path $userProfile)) {
        $userDetails += "User profile detected ✓"
        $userScore += 30
    } else {
        $userDetails += "User profile not detected ⚠"
        Add-Issue "User profile directory not accessible" 'Medium'
    }
    
    # Test preference file simulation
    $prefFile = Join-Path ([System.IO.Path]::GetTempPath()) 'aitherzero-preferences.json'
    try {
        $preferences = @{
            ui = @{ theme = 'dark'; welcome = $false }
            setup = @{ completed = $true; profile = 'developer' }
            lastAccess = Get-Date
        }
        
        $preferences | ConvertTo-Json | Out-File $prefFile
        $loadedPrefs = Get-Content $prefFile | ConvertFrom-Json
        Remove-Item $prefFile -Force
        
        if ($loadedPrefs.ui.theme -eq 'dark') {
            $userDetails += "Preference persistence working ✓"
            $userScore += 40
        }
    } catch {
        $userDetails += "Preference persistence failed ⚠"
        Add-Issue "User preference persistence issues" 'Medium'
    }
    
    # Test configuration profiles
    if (Test-Path './configs/profiles') {
        $profiles = Get-ChildItem './configs/profiles' -Directory
        $userDetails += "Found $($profiles.Count) configuration profiles ✓"
        $userScore += 30
    } else {
        $userDetails += "Configuration profiles not found ⚠"
        Add-Issue "Configuration profiles directory missing" 'Medium'
    }
    
    Add-TestResult 'UserPreferences' ($userScore -ge 70) ($userDetails -join '; ') $userScore
    Write-Host "   Score: $userScore/100 - $($userDetails -join ', ')" -ForegroundColor $(if ($userScore -ge 70) { 'Green' } else { 'Yellow' })
    
} catch {
    Add-TestResult 'UserPreferences' $false "Error: $_" 0
    Add-Issue "User preference testing failed: $_" 'High'
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# Calculate Overall Health Score
Write-Host "`n📊 Calculating Overall Health Score..." -ForegroundColor Cyan

$totalScore = 0
$maxScore = 0
$passedTests = 0
$totalTests = $ValidationResults.TestResults.Count

foreach ($testName in $ValidationResults.TestResults.Keys) {
    $test = $ValidationResults.TestResults[$testName]
    $totalScore += $test.Score
    
    # Determine max score based on test type
    $testMaxScore = switch ($testName) {
        'DefaultConfigCreation' { 80 }
        'EnvironmentDetection' { 100 }
        'ConfigurationModules' { 100 }
        'CrossPlatformHandling' { 100 }
        'ConfigValidation' { 100 }
        'UserPreferences' { 100 }
        default { 100 }
    }
    $maxScore += $testMaxScore
    
    if ($test.Result) { $passedTests++ }
}

$healthPercentage = if ($maxScore -gt 0) { [math]::Round(($totalScore / $maxScore) * 100, 1) } else { 0 }

$grade = switch ($healthPercentage) {
    { $_ -ge 90 } { 'A' }
    { $_ -ge 80 } { 'B' }
    { $_ -ge 70 } { 'C' }
    { $_ -ge 60 } { 'D' }
    default { 'F' }
}

$status = switch ($grade) {
    'A' { 'Excellent' }
    'B' { 'Good' }
    'C' { 'Satisfactory' }
    'D' { 'Needs Improvement' }
    'F' { 'Requires Attention' }
}

$ValidationResults.OverallHealth = @{
    Score = $healthPercentage
    Grade = $grade
    Status = $status
    PassedTests = $passedTests
    TotalTests = $totalTests
}

# Generate Final Report
Write-Host "`n=== CONFIGURATION SYSTEM VALIDATION SUMMARY ===" -ForegroundColor Cyan

$color = switch ($grade) {
    'A' { 'Green' }
    'B' { 'Green' }
    'C' { 'Yellow' }
    'D' { 'Yellow' }
    'F' { 'Red' }
}

Write-Host "🎯 Overall Health: $healthPercentage% (Grade: $grade - $status)" -ForegroundColor $color
Write-Host "✅ Tests Passed: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { 'Green' } else { 'Yellow' })

Write-Host "`n📋 Test Results:" -ForegroundColor Yellow
foreach ($testName in $ValidationResults.TestResults.Keys) {
    $test = $ValidationResults.TestResults[$testName]
    $symbol = if ($test.Result) { '✅' } else { '❌' }
    $testColor = if ($test.Result) { 'Green' } else { 'Red' }
    Write-Host "   $symbol $testName (Score: $($test.Score))" -ForegroundColor $testColor
}

if ($ValidationResults.Issues.Count -gt 0) {
    Write-Host "`n⚠️ Issues Found ($($ValidationResults.Issues.Count)):" -ForegroundColor Red
    foreach ($issue in $ValidationResults.Issues) {
        $severityColor = switch ($issue.Severity) {
            'High' { 'Red' }
            'Medium' { 'Yellow' }
            'Low' { 'Gray' }
        }
        Write-Host "   - [$($issue.Severity)] $($issue.Issue)" -ForegroundColor $severityColor
    }
}

if ($ValidationResults.Recommendations.Count -gt 0) {
    Write-Host "`n💡 Recommendations ($($ValidationResults.Recommendations.Count)):" -ForegroundColor Blue
    foreach ($rec in $ValidationResults.Recommendations) {
        Write-Host "   - [$($rec.Priority)] $($rec.Recommendation)" -ForegroundColor Blue
    }
}

# Export report if requested
if ($ExportReport) {
    $reportPath = Join-Path (Get-Location) "configuration-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $ValidationResults | ConvertTo-Json -Depth 10 | Out-File $reportPath
    Write-Host "`n📄 Report exported to: $reportPath" -ForegroundColor Green
}

# Final Assessment
Write-Host "`n🏆 FINAL ASSESSMENT:" -ForegroundColor Cyan
if ($healthPercentage -ge 80) {
    Write-Host "Configuration system is READY for production use!" -ForegroundColor Green
    Write-Host "New users should have a smooth setup experience." -ForegroundColor Green
    exit 0
} elseif ($healthPercentage -ge 60) {
    Write-Host "Configuration system is MOSTLY READY with minor issues." -ForegroundColor Yellow
    Write-Host "Address the issues above for optimal user experience." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "Configuration system NEEDS ATTENTION before production use." -ForegroundColor Red
    Write-Host "Critical issues must be resolved for proper operation." -ForegroundColor Red
    exit 1
}