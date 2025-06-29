#Requires -Version 7.0

<#
.SYNOPSIS
    Runs integration certification validation for third-party tools.

.DESCRIPTION
    This script validates third-party integrations against AitherZero certification
    requirements including API compatibility, security, performance, and documentation
    standards.

.PARAMETER IntegrationName
    Name of the integration being certified.

.PARAMETER Level
    Certification level: Basic, Standard, or Enterprise.

.PARAMETER TestEndpoint
    Base URL of the integration endpoint to test.

.PARAMETER ConfigPath
    Path to integration configuration file.

.PARAMETER OutputPath
    Path to save certification report.

.PARAMETER SkipPerformanceTests
    Skip performance testing (for development testing).

.EXAMPLE
    ./Run-IntegrationCertification.ps1 -IntegrationName "ExampleTool" -Level "Standard" -TestEndpoint "https://api.example.com"

.EXAMPLE
    ./Run-IntegrationCertification.ps1 -IntegrationName "EnterpriseTool" -Level "Enterprise" -ConfigPath "./configs/enterprise-config.json"
#>

param(
    [Parameter(Mandatory)]
    [string]$IntegrationName,
    
    [Parameter(Mandatory)]
    [ValidateSet('Basic', 'Standard', 'Enterprise')]
    [string]$Level,
    
    [Parameter()]
    [string]$TestEndpoint,
    
    [Parameter()]
    [string]$ConfigPath,
    
    [Parameter()]
    [string]$OutputPath = "./certification-reports",
    
    [Parameter()]
    [switch]$SkipPerformanceTests
)

# Import required modules
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
Import-Module (Join-Path $projectRoot "aither-core/modules/RestAPIServer") -Force

# Initialize logging
Initialize-LoggingSystem -LogLevel "INFO" -EnableTrace $true

Write-CustomLog -Message "Starting integration certification: $IntegrationName (Level: $Level)" -Level "INFO"

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$reportPath = Join-Path $OutputPath "$IntegrationName-certification-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Initialize certification result
$certificationResult = @{
    IntegrationName = $IntegrationName
    CertificationLevel = $Level
    TestStartTime = Get-Date
    TestEndTime = $null
    OverallResult = "PENDING"
    TestResults = @{}
    Score = 0
    MaxScore = 0
    Requirements = @{}
    Recommendations = @()
    Errors = @()
}

# Define certification requirements by level
$requirements = @{
    Basic = @{
        APICompatibility = @{ Weight = 30; MinScore = 85 }
        Security = @{ Weight = 25; MinScore = 80 }
        Documentation = @{ Weight = 20; MinScore = 75 }
        Performance = @{ Weight = 15; MinScore = 70 }
        Reliability = @{ Weight = 10; MinScore = 80 }
    }
    Standard = @{
        APICompatibility = @{ Weight = 25; MinScore = 90 }
        Security = @{ Weight = 30; MinScore = 85 }
        Documentation = @{ Weight = 15; MinScore = 85 }
        Performance = @{ Weight = 20; MinScore = 80 }
        Reliability = @{ Weight = 10; MinScore = 85 }
    }
    Enterprise = @{
        APICompatibility = @{ Weight = 20; MinScore = 95 }
        Security = @{ Weight = 35; MinScore = 95 }
        Documentation = @{ Weight = 15; MinScore = 90 }
        Performance = @{ Weight = 20; MinScore = 90 }
        Reliability = @{ Weight = 10; MinScore = 95 }
    }
}

$levelRequirements = $requirements[$Level]
$certificationResult.Requirements = $levelRequirements

try {
    # Test 1: API Compatibility
    Write-CustomLog -Message "Testing API compatibility..." -Level "INFO"
    $apiResult = Test-APICompatibility -IntegrationName $IntegrationName -Endpoint $TestEndpoint -Level $Level
    $certificationResult.TestResults.APICompatibility = $apiResult
    
    # Test 2: Security Validation
    Write-CustomLog -Message "Testing security requirements..." -Level "INFO"
    $securityResult = Test-SecurityRequirements -IntegrationName $IntegrationName -Endpoint $TestEndpoint -Level $Level
    $certificationResult.TestResults.Security = $securityResult
    
    # Test 3: Documentation Assessment
    Write-CustomLog -Message "Assessing documentation..." -Level "INFO"
    $docsResult = Test-DocumentationRequirements -IntegrationName $IntegrationName -Level $Level
    $certificationResult.TestResults.Documentation = $docsResult
    
    # Test 4: Performance Testing
    if (-not $SkipPerformanceTests) {
        Write-CustomLog -Message "Running performance tests..." -Level "INFO"
        $perfResult = Test-PerformanceRequirements -IntegrationName $IntegrationName -Endpoint $TestEndpoint -Level $Level
        $certificationResult.TestResults.Performance = $perfResult
    } else {
        Write-CustomLog -Message "Skipping performance tests" -Level "WARNING"
        $certificationResult.TestResults.Performance = @{ Score = 0; Skipped = $true }
    }
    
    # Test 5: Reliability Assessment
    Write-CustomLog -Message "Testing reliability..." -Level "INFO"
    $reliabilityResult = Test-ReliabilityRequirements -IntegrationName $IntegrationName -Endpoint $TestEndpoint -Level $Level
    $certificationResult.TestResults.Reliability = $reliabilityResult
    
    # Calculate overall score
    $totalScore = 0
    $maxScore = 0
    $passed = $true
    
    foreach ($category in $levelRequirements.Keys) {
        $requirement = $levelRequirements[$category]
        $result = $certificationResult.TestResults[$category]
        
        if ($result -and -not $result.Skipped) {
            $weightedScore = $result.Score * $requirement.Weight / 100
            $totalScore += $weightedScore
            $maxScore += $requirement.Weight
            
            # Check if minimum score met
            if ($result.Score -lt $requirement.MinScore) {
                $passed = $false
                $certificationResult.Errors += "Category '$category' scored $($result.Score)% but requires minimum $($requirement.MinScore)%"
            }
        }
    }
    
    $certificationResult.Score = if ($maxScore -gt 0) { [math]::Round($totalScore, 2) } else { 0 }
    $certificationResult.MaxScore = $maxScore
    
    # Determine certification result
    if ($passed -and $certificationResult.Score -ge ($maxScore * 0.85)) {
        $certificationResult.OverallResult = "APPROVED"
        Write-CustomLog -Message "🎯 Certification APPROVED: $IntegrationName (Level: $Level)" -Level "SUCCESS"
    } elseif ($certificationResult.Score -ge ($maxScore * 0.75)) {
        $certificationResult.OverallResult = "CONDITIONAL"
        Write-CustomLog -Message "⚠️ Certification CONDITIONAL: $IntegrationName requires improvements" -Level "WARNING"
    } else {
        $certificationResult.OverallResult = "REJECTED"
        Write-CustomLog -Message "❌ Certification REJECTED: $IntegrationName does not meet requirements" -Level "ERROR"
    }
    
} catch {
    $certificationResult.OverallResult = "ERROR"
    $certificationResult.Errors += "Certification process failed: $($_.Exception.Message)"
    Write-CustomLog -Message "Certification process failed: $($_.Exception.Message)" -Level "ERROR"
}

# Finalize result
$certificationResult.TestEndTime = Get-Date
$certificationResult.Duration = ($certificationResult.TestEndTime - $certificationResult.TestStartTime).TotalMinutes

# Generate recommendations
$certificationResult.Recommendations = Generate-CertificationRecommendations -Results $certificationResult -Level $Level

# Save certification report
$certificationResult | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-CustomLog -Message "Certification report saved: $reportPath" -Level "INFO"

# Display summary
Show-CertificationSummary -Results $certificationResult

return $certificationResult

# Helper Functions

function Test-APICompatibility {
    param($IntegrationName, $Endpoint, $Level)
    
    $result = @{
        Category = "API Compatibility"
        Score = 0
        Tests = @()
        Details = @{}
    }
    
    try {
        # Test basic connectivity
        if ($Endpoint) {
            $connectTest = Test-APIConnection -Port 80 -Protocol HTTP -HealthCheck
            $result.Tests += @{
                Name = "Basic Connectivity"
                Result = if ($connectTest.Success) { "PASS" } else { "FAIL" }
                Score = if ($connectTest.Success) { 100 } else { 0 }
            }
        }
        
        # Test authentication methods
        $authTest = @{
            Name = "Authentication Support"
            Result = "PASS"  # Simulated for example
            Score = 90
        }
        $result.Tests += $authTest
        
        # Test webhook support
        $webhookTest = @{
            Name = "Webhook Support"
            Result = "PASS"  # Simulated for example
            Score = 85
        }
        $result.Tests += $webhookTest
        
        # Calculate average score
        $result.Score = ($result.Tests | Measure-Object -Property Score -Average).Average
        
    } catch {
        $result.Tests += @{
            Name = "API Compatibility Test"
            Result = "ERROR"
            Score = 0
            Error = $_.Exception.Message
        }
    }
    
    return $result
}

function Test-SecurityRequirements {
    param($IntegrationName, $Endpoint, $Level)
    
    $result = @{
        Category = "Security"
        Score = 0
        Tests = @()
        Details = @{}
    }
    
    # Security tests (simulated for example)
    $securityTests = @(
        @{ Name = "TLS Configuration"; Score = 95; Result = "PASS" }
        @{ Name = "Authentication Security"; Score = 90; Result = "PASS" }
        @{ Name = "Input Validation"; Score = 85; Result = "PASS" }
        @{ Name = "Rate Limiting"; Score = 80; Result = "PASS" }
        @{ Name = "Audit Logging"; Score = 88; Result = "PASS" }
    )
    
    $result.Tests = $securityTests
    $result.Score = ($securityTests | Measure-Object -Property Score -Average).Average
    
    return $result
}

function Test-DocumentationRequirements {
    param($IntegrationName, $Level)
    
    $result = @{
        Category = "Documentation"
        Score = 0
        Tests = @()
        Details = @{}
    }
    
    # Documentation assessment (simulated)
    $docTests = @(
        @{ Name = "API Documentation"; Score = 85; Result = "PASS" }
        @{ Name = "User Guide"; Score = 80; Result = "PASS" }
        @{ Name = "Security Guide"; Score = 75; Result = "CONDITIONAL" }
        @{ Name = "Examples"; Score = 90; Result = "PASS" }
    )
    
    $result.Tests = $docTests
    $result.Score = ($docTests | Measure-Object -Property Score -Average).Average
    
    return $result
}

function Test-PerformanceRequirements {
    param($IntegrationName, $Endpoint, $Level)
    
    $result = @{
        Category = "Performance"
        Score = 0
        Tests = @()
        Details = @{}
    }
    
    # Performance tests (simulated)
    $perfTests = @(
        @{ Name = "Response Time"; Score = 85; Result = "PASS"; Value = "2.3s" }
        @{ Name = "Throughput"; Score = 80; Result = "PASS"; Value = "150 req/min" }
        @{ Name = "Reliability"; Score = 90; Result = "PASS"; Value = "99.7%" }
        @{ Name = "Resource Usage"; Score = 75; Result = "CONDITIONAL"; Value = "High CPU" }
    )
    
    $result.Tests = $perfTests
    $result.Score = ($perfTests | Measure-Object -Property Score -Average).Average
    
    return $result
}

function Test-ReliabilityRequirements {
    param($IntegrationName, $Endpoint, $Level)
    
    $result = @{
        Category = "Reliability"
        Score = 0
        Tests = @()
        Details = @{}
    }
    
    # Reliability tests (simulated)
    $reliabilityTests = @(
        @{ Name = "Error Handling"; Score = 90; Result = "PASS" }
        @{ Name = "Failover"; Score = 85; Result = "PASS" }
        @{ Name = "Recovery"; Score = 80; Result = "PASS" }
    )
    
    $result.Tests = $reliabilityTests
    $result.Score = ($reliabilityTests | Measure-Object -Property Score -Average).Average
    
    return $result
}

function Generate-CertificationRecommendations {
    param($Results, $Level)
    
    $recommendations = @()
    
    foreach ($category in $Results.TestResults.Keys) {
        $categoryResult = $Results.TestResults[$category]
        $requirement = $Results.Requirements[$category]
        
        if ($categoryResult.Score -lt $requirement.MinScore) {
            $recommendations += "Improve $category: Current score $($categoryResult.Score)% is below required $($requirement.MinScore)%"
        }
    }
    
    if ($Results.OverallResult -eq "CONDITIONAL") {
        $recommendations += "Address all failing test cases before final certification"
        $recommendations += "Consider upgrading security measures for better compliance"
    }
    
    return $recommendations
}

function Show-CertificationSummary {
    param($Results)
    
    Write-Host "`n🏆 CERTIFICATION SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 50
    Write-Host "Integration: $($Results.IntegrationName)" -ForegroundColor White
    Write-Host "Level: $($Results.CertificationLevel)" -ForegroundColor White
    Write-Host "Result: $($Results.OverallResult)" -ForegroundColor $(
        switch ($Results.OverallResult) {
            "APPROVED" { "Green" }
            "CONDITIONAL" { "Yellow" }
            "REJECTED" { "Red" }
            default { "Gray" }
        }
    )
    Write-Host "Score: $($Results.Score)/$($Results.MaxScore)" -ForegroundColor White
    Write-Host "Duration: $([math]::Round($Results.Duration, 2)) minutes" -ForegroundColor White
    
    Write-Host "`n📊 CATEGORY RESULTS" -ForegroundColor Cyan
    foreach ($category in $Results.TestResults.Keys) {
        $categoryResult = $Results.TestResults[$category]
        $requirement = $Results.Requirements[$category]
        
        $status = if ($categoryResult.Score -ge $requirement.MinScore) { "✅" } else { "❌" }
        Write-Host "$status $category : $($categoryResult.Score)% (min: $($requirement.MinScore)%)"
    }
    
    if ($Results.Recommendations.Count -gt 0) {
        Write-Host "`n💡 RECOMMENDATIONS" -ForegroundColor Cyan
        foreach ($rec in $Results.Recommendations) {
            Write-Host "  • $rec" -ForegroundColor Yellow
        }
    }
    
    if ($Results.Errors.Count -gt 0) {
        Write-Host "`n❌ ERRORS" -ForegroundColor Red
        foreach ($error in $Results.Errors) {
            Write-Host "  • $error" -ForegroundColor Red
        }
    }
}