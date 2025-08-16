#Requires -Version 7.0

<#
.SYNOPSIS
    Tests the release packages to ensure they work correctly
.DESCRIPTION
    Extracts and tests each release package to verify:
    - Package integrity
    - Bootstrap functionality
    - Module loading
    - Basic orchestration
.PARAMETER ReleaseDir
    Directory containing release packages
.PARAMETER TestProfiles
    Which profiles to test (Core, Standard, Full)
.PARAMETER SkipCleanup
    Don't clean up test directories after testing
.EXAMPLE
    ./9105_Test-ReleasePackages.ps1 -TestProfiles @('Core', 'Standard')
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ReleaseDir = "./release",
    
    [string[]]$TestProfiles = @('Core', 'Standard', 'Full'),
    
    [switch]$SkipCleanup
)

# Initialize
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:TestResults = @()
$script:FailedTests = 0

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [PackageTest] $Message"
    
    switch ($Level) {
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
}

function Test-Package {
    param(
        [string]$PackagePath,
        [string]$Profile
    )
    
    $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-Test-$Profile-$(Get-Random)"
    $result = [PSCustomObject]@{
        Profile = $Profile
        Package = Split-Path $PackagePath -Leaf
        Tests = @()
        Success = $true
        Duration = $null
    }
    
    $startTime = Get-Date
    
    try {
        # Test 1: Extract package
        Write-Host "  [1/5] Extracting package..." -NoNewline
        if ($PSCmdlet.ShouldProcess($PackagePath, "Extract package")) {
            Expand-Archive -Path $PackagePath -DestinationPath $testDir -Force
        }
        $result.Tests += [PSCustomObject]@{
            Name = 'Extract'
            Passed = $true
            Message = 'Package extracted successfully'
        }
        Write-Host " ✓" -ForegroundColor Green
        
        # Test 2: Verify core files exist
        Write-Host "  [2/5] Verifying core files..." -NoNewline
        $requiredFiles = @(
            'AitherZero.psd1',
            'AitherZero.psm1',
            'bootstrap.ps1',
            'Start-AitherZero.ps1'
        )
        
        $missingFiles = @()
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path (Join-Path $testDir $file))) {
                $missingFiles += $file
            }
        }
        
        if ($missingFiles.Count -eq 0) {
            $result.Tests += [PSCustomObject]@{
                Name = 'CoreFiles'
                Passed = $true
                Message = 'All core files present'
            }
            Write-Host " ✓" -ForegroundColor Green
        } else {
            $result.Tests += [PSCustomObject]@{
                Name = 'CoreFiles'
                Passed = $false
                Message = "Missing files: $($missingFiles -join ', ')"
            }
            $result.Success = $false
            Write-Host " ✗" -ForegroundColor Red
            Write-Host "       Missing: $($missingFiles -join ', ')" -ForegroundColor Red
        }
        
        # Test 3: Module can be imported
        Write-Host "  [3/5] Testing module import..." -NoNewline
        try {
            Import-Module (Join-Path $testDir 'AitherZero.psd1') -Force -ErrorAction Stop
            Remove-Module AitherZero -Force -ErrorAction SilentlyContinue
            
            $result.Tests += [PSCustomObject]@{
                Name = 'ModuleImport'
                Passed = $true
                Message = 'Module imported successfully'
            }
            Write-Host " ✓" -ForegroundColor Green
        } catch {
            $result.Tests += [PSCustomObject]@{
                Name = 'ModuleImport'
                Passed = $false
                Message = "Import failed: $_"
            }
            $result.Success = $false
            Write-Host " ✗" -ForegroundColor Red
            Write-Host "       Error: $_" -ForegroundColor Red
        }
        
        # Test 4: Bootstrap script syntax
        Write-Host "  [4/5] Checking bootstrap syntax..." -NoNewline
        $bootstrapPath = Join-Path $testDir 'bootstrap.ps1'
        $syntaxErrors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $bootstrapPath -Raw), [ref]$syntaxErrors)
        
        if ($syntaxErrors.Count -eq 0) {
            $result.Tests += [PSCustomObject]@{
                Name = 'BootstrapSyntax'
                Passed = $true
                Message = 'Bootstrap script has valid syntax'
            }
            Write-Host " ✓" -ForegroundColor Green
        } else {
            $result.Tests += [PSCustomObject]@{
                Name = 'BootstrapSyntax'
                Passed = $false
                Message = "Syntax errors: $($syntaxErrors.Count)"
            }
            $result.Success = $false
            Write-Host " ✗" -ForegroundColor Red
        }
        
        # Test 5: Verify manifest
        Write-Host "  [5/5] Checking manifest..." -NoNewline
        $manifestPath = Join-Path $testDir 'manifest.json'
        if (Test-Path $manifestPath) {
            try {
                $manifest = Get-Content $manifestPath | ConvertFrom-Json
                if ($manifest.Profile -eq $Profile -and $manifest.Version) {
                    $result.Tests += [PSCustomObject]@{
                        Name = 'Manifest'
                        Passed = $true
                        Message = "Valid manifest for $Profile profile"
                    }
                    Write-Host " ✓" -ForegroundColor Green
                } else {
                    throw "Invalid manifest content"
                }
            } catch {
                $result.Tests += [PSCustomObject]@{
                    Name = 'Manifest'
                    Passed = $false
                    Message = "Manifest error: $_"
                }
                $result.Success = $false
                Write-Host " ✗" -ForegroundColor Red
            }
        } else {
            $result.Tests += [PSCustomObject]@{
                Name = 'Manifest'
                Passed = $false
                Message = 'Manifest file not found'
            }
            $result.Success = $false
            Write-Host " ✗" -ForegroundColor Red
        }
        
    } catch {
        $result.Success = $false
        Write-TestLog "Unexpected error testing $Profile package: $_" -Level 'Error'
    } finally {
        # Cleanup
        if (-not $SkipCleanup -and (Test-Path $testDir)) {
            if ($PSCmdlet.ShouldProcess($testDir, "Remove test directory")) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        $result.Duration = (Get-Date) - $startTime
    }
    
    return $result
}

# Main execution
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " AitherZero Package Tester" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# Check release directory
if (-not (Test-Path $ReleaseDir)) {
    Write-TestLog "Release directory not found: $ReleaseDir" -Level 'Error'
    exit 1
}

# Find latest packages for each profile
foreach ($profile in $TestProfiles) {
    Write-Host "Testing $profile Profile Package" -ForegroundColor Cyan
    Write-Host ("─" * 50) -ForegroundColor DarkGray
    
    # Find latest package for this profile
    $packagePattern = Join-Path $ReleaseDir "AitherZero-*-$profile.zip"
    $package = Get-ChildItem $packagePattern -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1
    
    if (-not $package) {
        Write-TestLog "No package found for $profile profile" -Level 'Warning'
        $script:TestResults += [PSCustomObject]@{
            Profile = $profile
            Package = 'Not found'
            Success = $false
            Tests = @()
        }
        continue
    }
    
    Write-Host "Package: $($package.Name)" -ForegroundColor Gray
    Write-Host "Size: $([math]::Round($package.Length / 1MB, 2)) MB" -ForegroundColor Gray
    Write-Host ""
    
    # Test the package
    $result = Test-Package -PackagePath $package.FullName -Profile $profile
    $script:TestResults += $result
    
    if ($result.Success) {
        Write-Host "  Result: " -NoNewline
        Write-Host "PASSED" -ForegroundColor Green
    } else {
        Write-Host "  Result: " -NoNewline
        Write-Host "FAILED" -ForegroundColor Red
        $script:FailedTests++
    }
    
    Write-Host ""
}

# Display summary
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " TEST SUMMARY" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

$totalTests = ($script:TestResults | ForEach-Object { $_.Tests.Count } | Measure-Object -Sum).Sum
$passedTests = ($script:TestResults | ForEach-Object { $_.Tests | Where-Object Passed } | Measure-Object).Count

Write-Host "Total Packages Tested: $($script:TestResults.Count)" -ForegroundColor White
Write-Host "Total Tests Run: $totalTests" -ForegroundColor White
Write-Host "  ✓ Passed: $passedTests" -ForegroundColor Green
Write-Host "  ✗ Failed: $($totalTests - $passedTests)" -ForegroundColor Red

if ($script:FailedTests -gt 0) {
    Write-Host ""
    Write-Host "Failed Packages:" -ForegroundColor Red
    foreach ($result in $script:TestResults | Where-Object { -not $_.Success }) {
        Write-Host "  - $($result.Profile): $($result.Package)" -ForegroundColor Red
        foreach ($test in $result.Tests | Where-Object { -not $_.Passed }) {
            Write-Host "    • $($test.Name): $($test.Message)" -ForegroundColor Red
        }
    }
    exit 1
} else {
    Write-Host ""
    Write-Host "✅ All package tests passed!" -ForegroundColor Green
    exit 0
}