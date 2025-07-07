#!/usr/bin/env pwsh

# Test the Test-FeatureAccess function issue
cd /workspaces/AitherZero

Write-Host "Testing Test-FeatureAccess function..." -ForegroundColor Cyan

# Remove any existing modules
Get-Module StartupExperience | Remove-Module -Force
Get-Module LicenseManager | Remove-Module -Force

# Import StartupExperience module
try {
    Import-Module ./aither-core/modules/StartupExperience -Force
    Write-Host "✓ StartupExperience module imported" -ForegroundColor Green
    
    # Check what Test-FeatureAccess function is available
    $featureAccessCmd = Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue
    if ($featureAccessCmd) {
        Write-Host "✓ Test-FeatureAccess function found" -ForegroundColor Green
        Write-Host "  Source: $($featureAccessCmd.Source)" -ForegroundColor White
        Write-Host "  Module: $($featureAccessCmd.ModuleName)" -ForegroundColor White
        
        # Check parameters
        $params = $featureAccessCmd.Parameters
        Write-Host "  Parameters:" -ForegroundColor White
        $params.Keys | Sort-Object | ForEach-Object {
            if ($_ -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
                Write-Host "    - $_" -ForegroundColor Gray
            }
        }
        
        # Test the function call that's failing
        Write-Host "`nTesting the exact call that's failing..." -ForegroundColor Cyan
        try {
            $result = Test-FeatureAccess -Feature "free" -CurrentTier "enterprise"
            Write-Host "✓ Test call succeeded: $result" -ForegroundColor Green
        } catch {
            Write-Host "❌ Test call failed: $_" -ForegroundColor Red
        }
        
    } else {
        Write-Host "❌ Test-FeatureAccess function not found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}