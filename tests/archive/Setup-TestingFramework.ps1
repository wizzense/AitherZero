<#
.SYNOPSIS
Sets up the extensible testing framework for the OpenTofu Lab Automation project

.DESCRIPTION
This script initializes the testing framework by:
- Installing required PowerShell modules
- Generating tests for existing scripts
- Setting up file watchers
- Validating the framework setup

.EXAMPLE
./Setup-TestingFramework.ps1

.EXAMPLE
./Setup-TestingFramework.ps1 -RegenerateAll -SetupWatcher
#>

param(
    [switch]$RegenerateAll,
    [switch]$SetupWatcher,
    [switch]$ValidateOnly,
    [string]$WatchDirectory = 'pwsh'
)

$ErrorActionPreference = 'Stop'

Write-Information 'Setting up OpenTofu Lab Automation Testing Framework' -InformationAction Continue
Write-Information ('=' * 60) -InformationAction Continue

# Load helper functions
$helpersPath = Join-Path $PSScriptRoot 'helpers'
if (Test-Path (Join-Path $helpersPath 'TestHelpers.ps1')) {
    . (Join-Path $helpersPath 'TestHelpers.ps1')
    Write-Information 'PASS Loaded test helpers' -InformationAction Continue
} else {
    Write-Warning 'Test helpers not found, some features may not work'
}

function Install-RequiredModules {
    Write-Information "`nInstalling required PowerShell modules..." -InformationAction Continue

    $modules = @(
        @{ Name = 'Pester'; Version = '5.7.1'; Scope = 'CurrentUser' }
        @{ Name = 'powershell-yaml'; Scope = 'CurrentUser' }
        @{ Name = 'PSScriptAnalyzer'; Scope = 'CurrentUser' }
    )

    foreach ($module in $modules) {
        try {
            $installed = Get-Module -ListAvailable -Name $module.Name
            if ($module.Version) {
                $installed = $installed | Where-Object { $_.Version -ge $module.Version }
            }

            if ($installed) {
                Write-Information " $($module.Name) already installed" -InformationAction Continue
            } else {
                Write-Information " Installing $($module.Name)..." -InformationAction Continue
                $installParams = @{
                    Name  = $module.Name
                    Force = $true
                    Scope = $module.Scope
                }
                if ($module.Version) {
                    $installParams.RequiredVersion = $module.Version
                }
                Install-Module @installParams
                Write-Information " $($module.Name) installed successfully" -InformationAction Continue
            }
        } catch {
            Write-Error "Failed to install $($module.Name): $_"
        }
    }
}

function Test-FrameworkComponents {
    Write-Information "`nValidating framework components..." -InformationAction Continue

    $components = @(
        @{
            Name        = 'Test Generator'
            Path        = Join-Path $helpersPath 'New-AutoTestGenerator.ps1'
            Description = 'Automatic test generation script'
        }
        @{
            Name        = 'Extensible Test Runner'
            Path        = Join-Path $helpersPath 'Invoke-ExtensibleTests.ps1'
            Description = 'Enhanced test execution framework'
        }
        @{
            Name        = 'Test Helpers'
            Path        = Join-Path $helpersPath 'TestHelpers.ps1'
            Description = 'Common test utilities and functions'
        }
        @{
            Name        = 'GitHub Actions Workflow'
            Path        = Join-Path $PSScriptRoot '..' '.github' 'workflows' 'auto-test-generation.yml'
            Description = 'Automated test generation CI/CD'
        }
    )

    $allValid = $true
    foreach ($component in $components) {
        if (Test-Path $component.Path) {
            Write-Information " $($component.Name): Found" -InformationAction Continue

            # Validate PowerShell syntax for .ps1 files
            if ($component.Path -like '*.ps1') {
                try {
                    $content = Get-Content $component.Path -Raw
                    $errors = $null
                    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
                    if ($errors.Count -gt 0) {
                        Write-Warning " Syntax warnings: $($errors.Count)"
                    } else {
                        Write-Information ' Syntax validated' -InformationAction Continue
                    }
                } catch {
                    Write-Error " Syntax validation failed: $_"
                    $allValid = $false
                }
            }
        } else {
            Write-Information " $($component.Name): Missing ($($component.Path))" -InformationAction Continue
            Write-Information " $($component.Description)" -InformationAction Continue
            $allValid = $false
        }
    }

    return $allValid
}

function Initialize-TestGeneration {
    Write-Information "`nGenerating tests for existing scripts..." -InformationAction Continue

    $scriptDirs = @(
        (Join-Path $PSScriptRoot '..' 'core-runner' 'core_app' 'scripts'),
        (Join-Path $PSScriptRoot '..' 'core-runner' 'lab_utils'),
        (Join-Path $PSScriptRoot '..' 'core-runner')
    )

    $totalScripts = 0
    $generatedTests = 0

    foreach ($dir in $scriptDirs) {
        if (Test-Path $dir) {
            Write-Information " � Processing directory: $dir" -InformationAction Continue

            $scripts = Get-ChildItem $dir -Filter '*.ps1' -Recurse | Where-Object { -not $_.Name.EndsWith('.Tests.ps1') -and $_.Name -ne 'Setup-TestingFramework.ps1' }

            $totalScripts += $scripts.Count
            Write-Information " Found $($scripts.Count) scripts" -InformationAction Continue

            foreach ($script in $scripts) {
                $testName = $script.Name -replace '\.ps1$', '.Tests.ps1'
                $testPath = Join-Path $PSScriptRoot $testName

                if (-not (Test-Path $testPath) -or $RegenerateAll) {
                    try {
                        Write-Information " Generating test for: $($script.Name)" -InformationAction Continue
                        & (Join-Path $helpersPath 'New-AutoTestGenerator.ps1') -ScriptPath $script.FullName -Force:$RegenerateAll
                        $generatedTests++
                        Write-Information " PASS Generated: $testName" -InformationAction Continue
                    } catch {
                        Write-Error " Failed to generate test for $($script.Name): $_"
                    }
                } else {
                    Write-Information " [SKIP] Test exists: $testName" -InformationAction Continue
                }
            }
        }
    }

    Write-Information "`n Test Generation Summary:" -InformationAction Continue
    Write-Information " Total Scripts: $totalScripts" -InformationAction Continue
    Write-Information " Tests Generated: $generatedTests" -InformationAction Continue
    Write-Information " Tests Skipped: $($totalScripts - $generatedTests)" -InformationAction Continue
}

function Start-FileWatcher {
    Write-Information "`n� Setting up file watcher..." -InformationAction Continue

    $watchPath = Join-Path $PSScriptRoot '..' $WatchDirectory
    if (-not (Test-Path $watchPath)) {
        Write-Error "Watch directory not found: $watchPath"
        return
    }

    Write-Information " � Watching: $watchPath" -InformationAction Continue
    Write-Information ' Starting background watcher process...' -InformationAction Continue

    $watcherScript = Join-Path $helpersPath 'New-AutoTestGenerator.ps1'
    $job = Start-Job -ScriptBlock {
        param($WatcherScript, $WatchPath)
        & $WatcherScript -WatchMode -WatchDirectory $WatchPath -WatchIntervalSeconds 30
    } -ArgumentList $watcherScript, $watchPath

    Write-Information " PASS File watcher started (Job ID: $($job.Id))" -InformationAction Continue
    Write-Information " Use 'Get-Job | Remove-Job' to stop the watcher" -InformationAction Continue

    return $job
}

function Test-FrameworkExecution {
    Write-Information "`nTesting framework execution..." -InformationAction Continue

    try {
        # Test basic Pester functionality
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = 'None'
        $pesterConfig.Run.Path = @() # Empty path to test config only

        $result = Invoke-Pester -Configuration $pesterConfig
        Write-Information ' PASS Pester integration working' -InformationAction Continue

        return $true
    } catch {
        Write-Error " Framework execution test failed: $_"
        return $false
    }
}

function Show-NextSteps {
    Write-Information "`n Next Steps:" -InformationAction Continue
    Write-Information ('=' * 40) -InformationAction Continue

    Write-Information "`n1. Run tests locally:" -InformationAction Continue
    Write-Information ' ./tests/helpers/Invoke-ExtensibleTests.ps1' -InformationAction Continue

    Write-Information "`n2. Generate test for new script:" -InformationAction Continue
    Write-Information " ./tests/helpers/New-AutoTestGenerator.ps1 -ScriptPath 'path/to/script.ps1'" -InformationAction Continue

    Write-Information "`n3. Start file watcher:" -InformationAction Continue
    Write-Information ' ./tests/helpers/New-AutoTestGenerator.ps1 -WatchMode' -InformationAction Continue

    Write-Information "`n4. View framework documentation:" -InformationAction Continue
    Write-Information ' docs/testing-framework.md' -InformationAction Continue

    Write-Information "`n5. GitHub Actions will automatically:" -InformationAction Continue
    Write-Information ' - Generate tests for new/modified scripts' -InformationAction Continue
    Write-Information ' - Fix naming conventions' -InformationAction Continue
    Write-Information ' - Run tests across platforms' -InformationAction Continue

    Write-Information "`n Documentation: docs/testing-framework.md" -InformationAction Continue
    Write-Information '� Issues: Report to the project repository' -InformationAction Continue
}

# Main execution
try {
    if ($ValidateOnly) {
        Write-Information ' Validation mode - checking framework components only' -InformationAction Continue
        $isValid = Test-FrameworkComponents
        if ($isValid) {
            Write-Information "`nPASS Framework validation passed!" -InformationAction Continue
        } else {
            Write-Error "`nFramework validation failed!"
            exit 1
        }
        exit 0
    }

    # Step 1: Install required modules
    Install-RequiredModules

    # Step 2: Validate framework components
    Write-Information "`n Validating framework components..." -InformationAction Continue
    $isValid = Test-FrameworkComponents
    if (-not $isValid) {
        Write-Error 'Framework validation failed. Please check missing components.'
    }

    # Step 3: Generate tests for existing scripts
    if (-not $ValidateOnly) {
        Initialize-TestGeneration
    }

    # Step 4: Test framework execution
    Write-Information "`n Testing framework execution..." -InformationAction Continue
    $executionWorks = Test-FrameworkExecution
    if (-not $executionWorks) {
        Write-Warning 'Framework execution test failed, but setup will continue'
    }

    # Step 5: Setup file watcher if requested
    if ($SetupWatcher) {
        $watcherJob = Start-FileWatcher
    }

    # Success message
    Write-Information "`n Testing framework setup completed successfully!" -InformationAction Continue
    Write-Information ('=' * 60) -InformationAction Continue

    # Show next steps
    Show-NextSteps

    if ($SetupWatcher -and $watcherJob) {
        Write-Information "`n[TIME] File watcher is running in background (Job ID: $($watcherJob.Id))" -InformationAction Continue
        Write-Information ' Press Ctrl+C to stop this script, watcher will continue running' -InformationAction Continue

        # Keep script running to monitor watcher
        Write-Information "`n� Monitoring file watcher (press Ctrl+C to exit)..." -InformationAction Continue
        try {
            while ($true) {
                Start-Sleep 10
                $job = Get-Job -Id $watcherJob.Id -ErrorAction SilentlyContinue
                if (-not $job -or $job.State -eq 'Failed') {
                    Write-Warning 'File watcher stopped unexpectedly'
                    break
                }
            }
        } catch {
            Write-Information "`n� Monitoring stopped" -InformationAction Continue
        }
    } } catch {
    Write-Error "`nSetup failed: $_"
    Write-Information 'Check the error above and try again' -InformationAction Continue
    exit 1
}
