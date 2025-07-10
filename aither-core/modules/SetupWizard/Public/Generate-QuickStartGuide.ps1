function Generate-QuickStartGuide {
    <#
    .SYNOPSIS
        Generate platform-specific quick start guide
    .DESCRIPTION
        Creates a comprehensive quick start guide based on setup results and platform
    .PARAMETER SetupState
        Setup state object containing configuration and results
    .EXAMPLE
        $guide = Generate-QuickStartGuide -SetupState $setupState
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SetupState
    )

    $result = @{
        Name = 'Quick Start Guide'
        Status = 'Unknown'
        Details = @()
    }

    try {
        # Generate platform-specific guide
        $guide = @"
# AitherZero Quick Start Guide
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Platform: $($SetupState.Platform.OS) $($SetupState.Platform.Version)

## 🚀 Getting Started

### 1. Basic Usage
``````powershell
# Interactive mode (recommended for beginners)
./Start-AitherZero.ps1

# Run specific module
./Start-AitherZero.ps1 -Scripts 'LabRunner'

# Automated mode
./Start-AitherZero.ps1 -Auto
``````

### 2. Setup Commands

#### First Time Setup
``````powershell
# Run setup wizard
./Start-AitherZero.ps1 -Setup

# Setup with specific profile
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
``````

### 3. Common Tasks

#### Deploy Infrastructure
``````powershell
# Initialize OpenTofu provider
Import-Module ./aither-core/modules/OpenTofuProvider
Initialize-OpenTofuProvider

# Deploy a lab
New-LabInfrastructure -ConfigFile ./configs/lab-configs/dev-lab.json
``````

#### Manage Patches
``````powershell
# Create a patch with PR
Import-Module ./aither-core/modules/PatchManager
New-Feature -Description "Add new functionality" -Changes {
    # Your changes here
}
``````

#### Backup Operations
``````powershell
# Run backup
Import-Module ./aither-core/modules/BackupManager
Start-AutomatedBackup -SourcePath ./important-data -DestinationPath ./backups
``````

## 📋 Your Setup Summary

### ✅ What's Ready:
"@

        foreach ($step in $SetupState.Steps | Where-Object { $_.Status -eq 'Passed' -or $_.Status -eq 'Success' }) {
            $guide += "`n- $($step.Name)"
        }

        if ($SetupState.Warnings -and $SetupState.Warnings.Count -gt 0) {
            $guide += "`n`n### ⚠️ Things to Consider:"
            foreach ($warning in $SetupState.Warnings) {
                $guide += "`n- $warning"
            }
        }

        if ($SetupState.Recommendations -and $SetupState.Recommendations.Count -gt 0) {
            $guide += "`n`n### 💡 Recommendations:"
            foreach ($rec in $SetupState.Recommendations) {
                $guide += "`n- $rec"
            }
        }

        $guide += @"

## 🔗 Resources

- Documentation: ./docs/
- Examples: ./opentofu/examples/
- Module Help: Get-Help <ModuleName> -Full
- Issues: https://github.com/wizzense/AitherZero/issues

## 🎯 Next Steps

1. Review the generated configuration in:
   $(if ($SetupState.Platform.OS -eq 'Windows') { "$env:APPDATA\AitherZero" } else { "~/.config/aitherzero" })

2. Try the interactive menu:
   ./Start-AitherZero.ps1

3. Explore available modules:
   Get-Module -ListAvailable -Name *AitherZero*

4. Run tests to validate your installation:
   ./tests/Run-UnifiedTests.ps1

Happy automating! 🚀
"@

        # Save guide
        try {
            $guidePath = "QuickStart-$($SetupState.Platform.OS)-$(Get-Date -Format 'yyyyMMdd').md"
            Set-Content -Path $guidePath -Value $guide
            $result.Details += "✓ Generated quick start guide: $guidePath"
            $result.Status = 'Passed'

            # Also display key info
            Write-Host ""
            Write-Host "  📖 Quick Start Commands:" -ForegroundColor Green
            Write-Host "     Interactive:  ./Start-AitherZero.ps1" -ForegroundColor White
            Write-Host "     Setup:        ./Start-AitherZero.ps1 -Setup" -ForegroundColor White
            Write-Host "     Automated:    ./Start-AitherZero.ps1 -Auto" -ForegroundColor White
            Write-Host "     Get Help:     ./Start-AitherZero.ps1 -Help" -ForegroundColor White
        } catch {
            $result.Status = 'Warning'
            $result.Details += "⚠️ Could not save guide: $_"
        }

    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Quick start guide generation failed: $_"
    }

    return $result
}

Export-ModuleMember -Function Generate-QuickStartGuide