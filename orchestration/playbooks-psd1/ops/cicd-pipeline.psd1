#Requires -Version 7.0
<#
.SYNOPSIS
    cicd-pipeline - Complete CI/CD pipeline for AitherZero
.DESCRIPTION
    Orchestrates the complete build, test, and release pipeline.
    Validates playbooks, runs tests, builds release packages, and manages deployments.
.NOTES
    Version: 1.0.0
    Author: AitherZero DevOps Team
#>

@{
    # Metadata
    Name = 'cicd-pipeline'
    Description = 'Complete CI/CD pipeline with validation, testing, and release'
    Version = '1.0.0'
    Author = 'AitherZero DevOps Team'
    Created = '2025-01-13T00:00:00Z'
    
    # Categorization
    Tags = @('ci', 'cd', 'pipeline', 'release', 'automation')
    Category = 'Operations'
    
    # Requirements
    Requirements = @{
        Modules = @('Pester', 'PSScriptAnalyzer')
        MinimumVersion = '7.0'
        EstimatedDuration = '15-30 minutes'
        Tools = @('git')
    }
    
    # Default Variables
    Variables = @{
        RunValidation = $true
        RunTests = $true
        BuildProfiles = @('Core', 'Standard', 'Full')
        CreateRelease = $false
        Version = ''  # Will use version.txt if not specified
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Environment Setup'
            Description = 'Prepare CI/CD environment'
            Sequence = @('0001')  # Environment check
            ContinueOnError = $false
            Timeout = 60
        }
        @{
            Name = 'Validate Playbooks'
            Description = 'Test all playbooks for correctness'
            Sequence = @('0460')  # Test-Playbooks script
            Variables = @{
                CI = $true
                StopOnError = $true
            }
            ContinueOnError = $false
            Timeout = 300
            OnError = @{
                Action = 'Abort'
                Message = 'Cannot proceed with invalid playbooks'
            }
        }
        @{
            Name = 'Run Test Suite'
            Description = 'Execute unit and integration tests'
            Sequence = @('0402', '0403')  # Unit tests, Integration tests
            Variables = @{
                RunCoverage = $true
                FailFast = $false
            }
            ContinueOnError = $false
            Timeout = 600
            Conditional = @{
                When = 'Variables.RunTests -eq $true'
            }
        }
        @{
            Name = 'Static Analysis'
            Description = 'Run code quality checks'
            Sequence = @('0404', '0407')  # PSScriptAnalyzer, Syntax validation
            Variables = @{
                Severity = @('Error', 'Warning')
                ExcludePaths = @('tests', 'examples')
            }
            ContinueOnError = $true
            Timeout = 300
        }
        @{
            Name = 'Build Release Packages'
            Description = 'Create distribution packages'
            Sequence = @('9100')  # Build-Release script
            Variables = @{
                Version = '{Version}'
                Profiles = '{BuildProfiles}'
                CI = $true
            }
            ContinueOnError = $false
            Timeout = 600
        }
        @{
            Name = 'Test Release Packages'
            Description = 'Validate release package installation'
            Sequence = @('9105')  # Test installation (if exists)
            Variables = @{
                TestProfiles = '{BuildProfiles}'
            }
            ContinueOnError = $true
            Timeout = 300
            Conditional = @{
                When = 'Test-Path "./automation-scripts/9105_Test-ReleasePackages.ps1"'
            }
        }
        @{
            Name = 'Generate Documentation'
            Description = 'Update documentation and release notes'
            Sequence = @('0510')  # Generate project report
            Variables = @{
                Format = @('Markdown', 'JSON')
                IncludeMetrics = $true
            }
            ContinueOnError = $true
            Timeout = 180
        }
        @{
            Name = 'Create GitHub Release'
            Description = 'Publish release to GitHub'
            Sequence = @('9102')  # GitHub release script (if exists)
            Variables = @{
                Version = '{Version}'
                Draft = $false
            }
            ContinueOnError = $true
            Timeout = 120
            Conditional = @{
                When = 'Variables.CreateRelease -eq $true'
            }
        }
    )
    
    # Quality Gates
    QualityGates = @{
        PlaybookValidation = @{
            Required = $true
            FailOnError = $true
        }
        Testing = @{
            MinimumPassRate = 95
            CoverageThreshold = 70
        }
        CodeAnalysis = @{
            MaxErrors = 0
            MaxWarnings = 10
        }
    }
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = '✅ CI/CD pipeline completed successfully for version {Version}'
            Level = 'Success'
            ShowSummary = $true
        }
        OnFailure = @{
            Message = '❌ CI/CD pipeline failed at stage: {FailedStage}'
            Level = 'Error'
            ShowDetails = $true
        }
        OnValidationFailure = @{
            Message = '⚠️ Playbook validation failed - cannot proceed'
            Level = 'Error'
        }
    }
    
    # Post Actions
    PostActions = @(
        @{
            Name = 'Display Summary'
            Description = 'Show pipeline execution summary'
            Type = 'Script'
            Script = {
                Write-Host "`n════════════════════════════════════════" -ForegroundColor Blue
                Write-Host " Pipeline Summary" -ForegroundColor White
                Write-Host "════════════════════════════════════════" -ForegroundColor Blue
                
                # Display results
                Get-ChildItem ./release -Filter "AitherZero-*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host "  ✓ Built: $($_.Name)" -ForegroundColor Green
                }
                
                if (Test-Path ./tests/results) {
                    $testResults = Get-ChildItem ./tests/results -Filter "*Summary*.json" -ErrorAction SilentlyContinue | 
                        Select-Object -Last 1
                    if ($testResults) {
                        $summary = Get-Content $testResults.FullName | ConvertFrom-Json
                        Write-Host "  Tests: $($summary.Passed)/$($summary.Total) passed" -ForegroundColor Cyan
                    }
                }
            }
        }
        @{
            Name = 'Clean Artifacts'
            Description = 'Clean temporary build artifacts'
            Type = 'Script'
            Script = {
                # Clean temp directories but keep releases
                Remove-Item ./temp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    )
    
    # CI/CD Integration
    Integrations = @{
        GitHub = @{
            Enabled = $true
            RequireStatusChecks = $true
            ProtectedBranches = @('main')
        }
        Artifacts = @{
            RetentionDays = 30
            Paths = @('./release', './tests/results')
        }
    }
}