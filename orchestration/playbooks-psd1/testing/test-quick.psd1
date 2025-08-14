#Requires -Version 7.0
<#
.SYNOPSIS
    test-quick - Fast validation for development
.DESCRIPTION
    Quick validation playbook that runs unit tests and syntax analysis.
    Designed for rapid feedback during development with minimal overhead.
    Completes in 5-10 minutes.
.NOTES
    Version: 2.0.0
    Author: AitherZero Testing Framework
#>

@{
    # Metadata
    Name = 'test-quick'
    Description = 'Fast validation for development - runs unit tests and syntax analysis'
    Version = '2.0.0'
    Author = 'AitherZero Testing Framework'
    Created = '2025-01-13T00:00:00Z'
    
    # Categorization
    Tags = @('testing', 'quick', 'development', 'validation', 'ci-friendly')
    Category = 'Testing'
    
    # Requirements
    Requirements = @{
        Modules = @('Pester', 'PSScriptAnalyzer')
        MinimumVersion = '7.0'
        EstimatedDuration = '5-10 minutes'
        DiskSpace = '100MB'
    }
    
    # Default Variables
    Variables = @{
        TestPath = './tests'
        OutputPath = './tests/results'
        SkipCoverage = $true
        FailFast = $true
        Parallel = $true
        MaxConcurrency = 4
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Environment Check'
            Description = 'Verify testing tools are installed'
            Sequence = @('0400')
            ContinueOnError = $false
            Timeout = 60
        }
        @{
            Name = 'Unit Tests'
            Description = 'Run unit tests with fast fail mode'
            Sequence = @('0402')
            Variables = @{
                NoCoverage = $true
                FailFast = $true
            }
            ContinueOnError = $false
            Timeout = 300
        }
        @{
            Name = 'Static Analysis'
            Description = 'Quick PSScriptAnalyzer validation'
            Sequence = @('0404')
            Variables = @{
                ExcludePaths = @('tests', 'legacy-to-migrate', 'examples')
                Severity = @('Error', 'Warning')
            }
            ContinueOnError = $true
            Timeout = 180
        }
        @{
            Name = 'Syntax Validation'
            Description = 'Validate PowerShell syntax only'
            Sequence = @('0407')
            Variables = @{
                CheckSyntax = $true
                CheckParameters = $false
                CheckCommands = $false
                CheckModuleDependencies = $false
            }
            ContinueOnError = $true
            Timeout = 120
        }
    )
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = '✅ Quick validation passed!'
            Level = 'Information'
            ShowSummary = $true
        }
        OnFailure = @{
            Message = '❌ Quick validation failed - check test results'
            Level = 'Error'
            ShowDetails = $true
        }
        OnWarning = @{
            Message = '⚠️ Quick validation completed with warnings'
            Level = 'Warning'
        }
    }
    
    # Post Actions
    PostActions = @(
        @{
            Name = 'Display Summary'
            Description = 'Show test execution summary'
            Type = 'Script'
            Script = {
                $summaryFile = Get-ChildItem './tests/results' -Filter '*Summary*.json' -ErrorAction SilentlyContinue | 
                    Select-Object -Last 1
                if ($summaryFile) {
                    Get-Content $summaryFile.FullName | ConvertFrom-Json | Format-List
                }
            }
        }
    )
    
    # Integration Points
    Integrations = @{
        CI = @{
            Enabled = $true
            ArtifactPaths = @('./tests/results')
            FailOnWarning = $false
        }
        VSCode = @{
            Enabled = $true
            ProblemMatcher = 'pester'
        }
    }
}