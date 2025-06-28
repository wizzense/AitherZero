#Requires -Version 7.0

<#
.SYNOPSIS
    Updates ISO test files to use secure password helpers
.DESCRIPTION
    This script updates ISOManager and ISOCustomizer test files to use
    the Test-ISOConfigurations helper instead of hardcoded passwords.
.NOTES
    Run this script to fix security scan issues with hardcoded passwords
#>

param(
    [switch]$WhatIf
)

# Define common password patterns to replace
$passwordPatterns = @{
    'TestPassword123' = 'ISO_Basic'
    'HeadlessTest123!' = 'ISO_Headless'
    'DomainTest123!' = 'ISO_Domain'
    'NetTest123!' = 'ISO_Network'
    'SecTest123!' = 'ISO_Security'
    'WorkflowTest123!' = 'ISO_Workflow'
    'ConfigTest123' = 'ISO_Config'
    'Complex123!' = 'ISO_Complex'
    'XmlTest123!' = 'ISO_XML'
    'TemplateTest123!' = 'ISO_Template'
    'PerfTest123!' = 'ISO_Performance'
    'MemoryTest123!' = 'ISO_Memory'
    'EdgeTest123!' = 'ISO_Edge'
    'SpecialTest123!' = 'ISO_Special'
    'IsoTest123!' = 'ISO_Custom'
    'RegressionTest123!' = 'ISO_Regression'
    'ModernTest123!' = 'ISO_Modern'
    'MinTest123!' = 'ISO_Minimal'
}

function Update-TestFile {
    param(
        [string]$FilePath,
        [switch]$WhatIf
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return
    }
    
    Write-Host "Processing: $FilePath" -ForegroundColor Cyan
    
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    
    # Check if helper is already imported
    $hasHelper = $content -match 'Test-ISOConfigurations\.ps1'
    
    # Add helper import if not present
    if (-not $hasHelper) {
        # Find BeforeAll block or BeforeEach block
        if ($content -match 'BeforeAll\s*{') {
            $content = $content -replace '(BeforeAll\s*{[^}]*?)([\r\n]+)', '$1$2    # Import ISO test configuration helper$2    . "$PSScriptRoot/../../../helpers/Test-ISOConfigurations.ps1"$2$2'
            Write-Host "  Added helper import to BeforeAll block" -ForegroundColor Green
        }
        elseif ($content -match 'BeforeEach\s*{') {
            # For files that use BeforeEach, add the import there
            $importAdded = $false
            $lines = $content -split "`n"
            $newLines = @()
            
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $newLines += $lines[$i]
                if ($lines[$i] -match 'BeforeEach\s*{' -and -not $importAdded) {
                    $newLines += '            # Import ISO test configuration helper'
                    $newLines += '            . "$PSScriptRoot/../../../helpers/Test-ISOConfigurations.ps1"'
                    $newLines += ''
                    $importAdded = $true
                }
            }
            
            if ($importAdded) {
                $content = $newLines -join "`n"
                Write-Host "  Added helper import to BeforeEach block" -ForegroundColor Green
            }
        }
    }
    
    # Replace hardcoded test configurations
    $replacementCount = 0
    
    # Pattern 1: Replace inline configurations with passwords
    foreach ($password in $passwordPatterns.Keys) {
        $purpose = $passwordPatterns[$password]
        
        # Replace AdminPassword assignments
        $pattern = "AdminPassword\s*=\s*['""]$password['""]"
        if ($content -match $pattern) {
            $content = $content -replace $pattern, "AdminPassword = Get-TestPassword -Purpose '$purpose' -ComplexityRequired"
            $replacementCount++
        }
    }
    
    # Pattern 2: Replace entire test configuration blocks
    $configPattern = '@\{\s*ComputerName\s*=\s*["\']([^"\']+)["\']\s*AdminPassword\s*=\s*["\']([^"\']+)["\']\s*\}'
    if ($content -match $configPattern) {
        # For simple configurations, use the helper
        $content = $content -replace $configPattern, 'Get-TestISOConfiguration -ConfigurationType ''Basic'' -ComputerName ''$1'''
        $replacementCount++
    }
    
    # Pattern 3: Replace $testConfig definitions
    $testConfigPattern = '\$testConfig\s*=\s*@\{[^}]+AdminPassword\s*=\s*["\'][^"\']+["\'][^}]+\}'
    $matches = [regex]::Matches($content, $testConfigPattern)
    
    foreach ($match in $matches) {
        $configBlock = $match.Value
        
        # Determine configuration type based on content
        $configType = 'Basic'
        if ($configBlock -match 'JoinDomain|DomainName') { $configType = 'Domain' }
        elseif ($configBlock -match 'StaticIP|Gateway|DNSServers') { $configType = 'Network' }
        elseif ($configBlock -match 'DisableFirewall|EnableWindowsDefender|BitLocker') { $configType = 'Security' }
        elseif ($configBlock -match 'WindowsFeatures|EnableHyperV') { $configType = 'Features' }
        elseif ($configBlock -match 'HeadlessMode') { $configType = 'Headless' }
        elseif ($configBlock -match 'FirstLogonCommands.*DisableFirewall.*DisableUAC') { $configType = 'Complex' }
        
        # Extract computer name if present
        $computerName = ''
        if ($configBlock -match 'ComputerName\s*=\s*["\']([^"\']+)["\']') {
            $computerName = $Matches[1]
        }
        
        # Build replacement
        $replacement = '$testConfig = Get-TestISOConfiguration -ConfigurationType ''' + $configType + ''''
        if ($computerName) {
            $replacement += ' -ComputerName ''' + $computerName + ''''
        }
        
        $content = $content.Replace($match.Value, $replacement)
        $replacementCount++
    }
    
    # Only write file if changes were made
    if ($content -ne $originalContent) {
        if ($WhatIf) {
            Write-Host "  Would update file with $replacementCount replacements" -ForegroundColor Yellow
        }
        else {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8
            Write-Host "  Updated file with $replacementCount replacements" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  No changes needed" -ForegroundColor Gray
    }
}

# Main execution
Write-Host "Updating ISO test files to use secure password helpers..." -ForegroundColor Cyan
Write-Host ""

# Get all ISO test files
$testFiles = @(
    '/workspaces/AitherZero/tests/unit/modules/ISOManager/ISOManager.Tests.ps1'
    '/workspaces/AitherZero/tests/unit/modules/ISOManager/ISOManager-Comprehensive.Tests.ps1'
)

foreach ($file in $testFiles) {
    Update-TestFile -FilePath $file -WhatIf:$WhatIf
}

Write-Host ""
Write-Host "Update complete!" -ForegroundColor Green

if ($WhatIf) {
    Write-Host ""
    Write-Host "This was a dry run. To apply changes, run without -WhatIf parameter." -ForegroundColor Yellow
}