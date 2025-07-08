#!/usr/bin/env pwsh
# Check for unapproved verbs in modules

$modulesWithWarnings = @(
    'AIToolsIntegration', 'ConfigurationCarousel', 'ConfigurationCore', 
    'ConfigurationRepository', 'ModuleCommunication', 'OrchestrationEngine',
    'SemanticVersioning', 'SetupWizard'
)

$approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb

foreach ($module in $modulesWithWarnings) {
    Write-Host "`nChecking module: $module" -ForegroundColor Yellow
    
    try {
        $moduleInfo = Import-Module "./aither-core/modules/$module" -PassThru -Force
        $exportedFunctions = $moduleInfo.ExportedFunctions.Keys
        
        $unapprovedFunctions = @()
        foreach ($function in $exportedFunctions) {
            $verb = $function.Split('-')[0]
            if ($verb -notin $approvedVerbs) {
                $unapprovedFunctions += $function
            }
        }
        
        if ($unapprovedFunctions.Count -gt 0) {
            Write-Host "  Unapproved functions:" -ForegroundColor Red
            foreach ($func in $unapprovedFunctions) {
                $verb = $func.Split('-')[0]
                Write-Host "    $func (verb: $verb)" -ForegroundColor Red
            }
        } else {
            Write-Host "  No unapproved verbs found" -ForegroundColor Green
        }
        
        Remove-Module $module -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "  Error checking module: $_" -ForegroundColor Red
    }
}