#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Production test runner for AitherZero CI/CD pipeline

.DESCRIPTION
    This script runs production tests and properly reports failures.
    It integrates with the bulletproof validation system.

.PARAMETER TestSuite
    The test suite to run: Critical, Standard, Complete, or All

.PARAMETER OutputFormat
    The output format for test results

.PARAMETER FailFast
    Stop on first test failure
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Critical', 'Standard', 'Complete', 'All')]
    [string]$TestSuite = 'Standard',
    
    [Parameter()]
    [ValidateSet('NUnit', 'JUnit', 'Console')]
    [string]$OutputFormat = 'Console',
    
    [Parameter()]
    [switch]$FailFast
)

# CRITICAL: Fail immediately on any error
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host "🚀 Starting Production Tests - Suite: $TestSuite" -ForegroundColor Cyan

try {
    # Find the modern test runner script
    $scriptPath = Join-Path $PSScriptRoot "Run-Tests.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        throw "CRITICAL: Run-Tests.ps1 not found at: $scriptPath"
    }
    
    # Map test suite to test type
    $testType = switch ($TestSuite) {
        'Critical' { 'Unit' }
        'Standard' { 'Integration' }
        'Complete' { 'All' }
        'All' { 'All' }
        default { 'Integration' }
    }
    
    Write-Host "📋 Mapped $TestSuite suite to $testType test type" -ForegroundColor Yellow
    
    # Build parameters for modern test runner
    $params = @{
        Type = $testType
        Coverage = $true
    }
    
    if ($FailFast) {
        $params['FailFast'] = $true
    }
    
    # Run the tests
    Write-Host "🧪 Executing tests..." -ForegroundColor Yellow
    & $scriptPath @params
    
    # Check exit code
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "❌ TESTS FAILED with exit code: $exitCode"
    }
    
    Write-Host "✅ All production tests passed!" -ForegroundColor Green
    exit 0
    
} catch {
    # FAIL LOUD AND PROUD
    Write-Host "" -ForegroundColor Red
    Write-Host "💥💥💥 PRODUCTION TESTS FAILED 💥💥💥" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "THIS IS A CRITICAL FAILURE - FIX BEFORE PROCEEDING" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    
    # Exit with failure code
    exit 1
}