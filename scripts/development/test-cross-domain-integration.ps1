#!/usr/bin/env pwsh

# Test cross-domain integration and dependencies
cd /workspaces/AitherZero

Write-Host "Testing cross-domain integration..." -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Load dependencies in correct order
$projectRoot = "/workspaces/AitherZero"
$domainsPath = "$projectRoot/aither-core/domains"
$modulesPath = "$projectRoot/aither-core/modules"

# First, load logging module (required dependency)
Write-Host "`n1. Loading Logging module..." -ForegroundColor Yellow
try {
    $loggingPath = "$modulesPath/Logging"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force
        Write-Host "   ✓ Logging module loaded" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Logging module not found, using fallback" -ForegroundColor Yellow
        # Create fallback Write-CustomLog function
        function Write-CustomLog {
            param(
                [string]$Level,
                [string]$Message
            )
            $timestamp = Get-Date -Format "HH:mm:ss.fff"
            $color = switch ($Level) {
                'ERROR' { 'Red' }
                'WARNING' { 'Yellow' }
                'SUCCESS' { 'Green' }
                'INFO' { 'Cyan' }
                default { 'White' }
            }
            Write-Host "[$timestamp] [$($Level.PadRight(7))] $Message" -ForegroundColor $color
        }
        Write-Host "   ✓ Fallback Write-CustomLog function created" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Error loading logging: $_" -ForegroundColor Red
}

# Test each domain loading
$domains = @('automation', 'configuration', 'experience', 'infrastructure', 'security', 'utilities')

foreach ($domain in $domains) {
    Write-Host "`n2. Testing $domain domain..." -ForegroundColor Yellow
    
    $domainPath = "$domainsPath/$domain"
    if (Test-Path $domainPath) {
        Write-Host "   ✓ Domain directory exists" -ForegroundColor Green
        
        # Find domain scripts
        $scripts = Get-ChildItem -Path $domainPath -Filter "*.ps1" | Where-Object { $_.Name -notmatch "README" }
        
        if ($scripts.Count -gt 0) {
            Write-Host "   ✓ Found $($scripts.Count) domain scripts" -ForegroundColor Green
            
            foreach ($script in $scripts) {
                Write-Host "     Testing: $($script.Name)" -ForegroundColor White
                try {
                    . $script.FullName
                    Write-Host "     ✓ $($script.Name) loaded successfully" -ForegroundColor Green
                } catch {
                    Write-Host "     ❌ $($script.Name) failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   ⚠️  No domain scripts found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Domain directory not found" -ForegroundColor Red
    }
}

# Test specific function availability
Write-Host "`n3. Testing function availability..." -ForegroundColor Yellow

$testFunctions = @(
    @{ Name = 'Start-InteractiveMode'; Domain = 'experience' },
    @{ Name = 'Initialize-TerminalUI'; Domain = 'experience' },
    @{ Name = 'Show-ContextMenu'; Domain = 'experience' },
    @{ Name = 'Test-FeatureAccess'; Domain = 'experience' },
    @{ Name = 'Test-EnhancedUICapability'; Domain = 'experience' },
    @{ Name = 'Get-StartupMode'; Domain = 'experience' },
    @{ Name = 'Start-IntelligentSetup'; Domain = 'experience' },
    @{ Name = 'Edit-Configuration'; Domain = 'experience' },
    @{ Name = 'Get-LicenseStatus'; Domain = 'security' },
    @{ Name = 'New-SecureCredential'; Domain = 'security' },
    @{ Name = 'Start-Backup'; Domain = 'utilities' },
    @{ Name = 'New-RemoteConnection'; Domain = 'utilities' }
)

foreach ($func in $testFunctions) {
    $command = Get-Command $func.Name -ErrorAction SilentlyContinue
    if ($command) {
        Write-Host "   ✓ $($func.Name) ($($func.Domain)) - Available" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $($func.Name) ($($func.Domain)) - Not found" -ForegroundColor Red
    }
}

# Test specific function execution
Write-Host "`n4. Testing function execution..." -ForegroundColor Yellow

# Test Test-FeatureAccess
try {
    if (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue) {
        Write-Host "   Testing Test-FeatureAccess..." -ForegroundColor White
        $result = Test-FeatureAccess -FeatureName "free"
        Write-Host "   ✓ Test-FeatureAccess returned: $result" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Test-FeatureAccess not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Test-FeatureAccess failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Initialize-TerminalUI
try {
    if (Get-Command Initialize-TerminalUI -ErrorAction SilentlyContinue) {
        Write-Host "   Testing Initialize-TerminalUI..." -ForegroundColor White
        Initialize-TerminalUI
        Write-Host "   ✓ Initialize-TerminalUI executed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Initialize-TerminalUI not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Initialize-TerminalUI failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Test-EnhancedUICapability
try {
    if (Get-Command Test-EnhancedUICapability -ErrorAction SilentlyContinue) {
        Write-Host "   Testing Test-EnhancedUICapability..." -ForegroundColor White
        $result = Test-EnhancedUICapability
        Write-Host "   ✓ Test-EnhancedUICapability returned: $result" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Test-EnhancedUICapability not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Test-EnhancedUICapability failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Get-StartupMode
try {
    if (Get-Command Get-StartupMode -ErrorAction SilentlyContinue) {
        Write-Host "   Testing Get-StartupMode..." -ForegroundColor White
        $result = Get-StartupMode -Parameters @{}
        Write-Host "   ✓ Get-StartupMode returned: $($result.Mode)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Get-StartupMode not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Get-StartupMode failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n5. Integration Summary..." -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Cyan

# Count available functions
$availableFunctions = $testFunctions | Where-Object { Get-Command $_.Name -ErrorAction SilentlyContinue }
$totalFunctions = $testFunctions.Count

Write-Host "   Functions Available: $($availableFunctions.Count)/$totalFunctions" -ForegroundColor $(if ($availableFunctions.Count -eq $totalFunctions) { 'Green' } else { 'Yellow' })

if ($availableFunctions.Count -eq $totalFunctions) {
    Write-Host "   ✅ All expected functions are available!" -ForegroundColor Green
} elseif ($availableFunctions.Count -gt ($totalFunctions * 0.5)) {
    Write-Host "   ⚠️  Most functions are available, some may need attention" -ForegroundColor Yellow
} else {
    Write-Host "   ❌ Many functions are missing, domain consolidation may have issues" -ForegroundColor Red
}

Write-Host "`n✅ Cross-domain integration test completed" -ForegroundColor Green