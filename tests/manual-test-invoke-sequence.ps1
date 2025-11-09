#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Manual test for Invoke-AitherSequence parameter handling
.DESCRIPTION
    Tests that Invoke-AitherSequence accepts both string and array inputs
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

Write-Host "`nManual Test: Invoke-AitherSequence Parameter Handling`n" -ForegroundColor Cyan

# Get project root
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Set environment to suppress interactive prompts
$env:AITHERZERO_SUPPRESS_BANNER = '1'
$env:AITHERZERO_NONINTERACTIVE = '1'
$env:AITHERZERO_TEST_MODE = '1'

try {
    # Import the AitherZero module
    Write-Host "Importing AitherZero module..." -ForegroundColor Yellow
    Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
    Write-Host "✓ Module imported successfully`n" -ForegroundColor Green
    
    # Test 1: Check if function exists
    Write-Host "Test 1: Checking if Invoke-AitherSequence exists..." -ForegroundColor Yellow
    $cmd = Get-Command Invoke-AitherSequence -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✓ Function exists`n" -ForegroundColor Green
    } else {
        throw "Function Invoke-AitherSequence not found"
    }
    
    # Test 2: Check parameter type
    Write-Host "Test 2: Checking Sequence parameter type..." -ForegroundColor Yellow
    $param = $cmd.Parameters['Sequence']
    if ($param) {
        $paramType = $param.ParameterType
        Write-Host "  Parameter type: $($paramType.Name)" -ForegroundColor Gray
        
        # Check if it accepts arrays
        if ($paramType.IsArray -or $paramType.Name -eq 'String[]') {
            Write-Host "✓ Parameter accepts arrays (String[])`n" -ForegroundColor Green
        } else {
            throw "Parameter does not accept arrays. Type is: $($paramType.FullName)"
        }
    } else {
        throw "Sequence parameter not found"
    }
    
    # Test 3: Test with DryRun to avoid actual execution
    Write-Host "Test 3: Testing with array syntax (0500,0501) using -DryRun..." -ForegroundColor Yellow
    try {
        # This should work now with our fix
        $result = Invoke-AitherSequence 0500,0501 -DryRun -ErrorAction Stop
        Write-Host "✓ Array syntax works without errors`n" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed with error: $_`n" -ForegroundColor Red
        throw
    }
    
    # Test 4: Test with explicit array
    Write-Host "Test 4: Testing with explicit array @('0500', '0501') using -DryRun..." -ForegroundColor Yellow
    try {
        $result = Invoke-AitherSequence @("0500", "0501") -DryRun -ErrorAction Stop
        Write-Host "✓ Explicit array syntax works`n" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed with error: $_`n" -ForegroundColor Red
        throw
    }
    
    # Test 5: Test with string (backward compatibility)
    Write-Host "Test 5: Testing with string '0500,0501' using -DryRun..." -ForegroundColor Yellow
    try {
        $result = Invoke-AitherSequence "0500,0501" -DryRun -ErrorAction Stop
        Write-Host "✓ String syntax still works (backward compatible)`n" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed with error: $_`n" -ForegroundColor Red
        throw
    }
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    Write-Host ("=" * 60) + "`n" -ForegroundColor Cyan
    
    exit 0
}
catch {
    Write-Host "`n" + ("=" * 60) -ForegroundColor Red
    Write-Host "Tests failed! ✗" -ForegroundColor Red
    Write-Host ("=" * 60) -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`n"
    exit 1
}
