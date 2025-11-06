@{
    # ===================================================================
    # PROJECT HEALTH CHECK PLAYBOOK
    # ===================================================================
    # Comprehensive validation matching GitHub Actions workflows
    # Validates syntax, code quality, tests, and component health
    
    Name = 'project-health-check'
    Description = 'Complete project health validation (matches GitHub Actions)'
    Version = '1.0.0'
    
    # Environment configuration
    Environment = @{
        NonInteractive = $true
        WhatIf = $false
        FailFast = $false  # Continue through all checks even if some fail
        LogLevel = 'Information'
    }
    
    # Execution profile
    Profile = @{
        Name = 'Full'
        MaxConcurrency = 4
        TimeoutMinutes = 30
    }
    
    # ===================================================================
    # VALIDATION STAGES
    # ===================================================================
    
    Stages = @(
        # Stage 1: Syntax Validation (Quick Health Check equivalent)
        @{
            Name = 'Syntax Validation'
            Description = 'Validate PowerShell syntax for all files'
            Scripts = @(
                @{
                    Number = '0407'
                    Name = 'Validate-Syntax'
                    Parameters = @{
                        All = $true
                    }
                    Required = $true
                    Timeout = 120
                }
            )
        }
        
        # Stage 2: Code Quality Analysis (PR Validation equivalent)
        @{
            Name = 'Code Quality Analysis'
            Description = 'Run PSScriptAnalyzer on all PowerShell files'
            Scripts = @(
                @{
                    Number = '0404'
                    Name = 'Run-PSScriptAnalyzer'
                    Parameters = @{
                        # No parameters - runs on all files
                    }
                    Required = $true
                    Timeout = 300
                }
            )
        }
        
        # Stage 3: Component Quality Validation (Quality Validation workflow)
        @{
            Name = 'Component Quality'
            Description = 'Validate component quality (error handling, logging, tests)'
            Scripts = @(
                @{
                    Number = '0420'
                    Name = 'Validate-ComponentQuality'
                    Parameters = @{
                        Path = './domains'
                        Recursive = $true
                    }
                    Required = $false  # Warning only
                    Timeout = 600
                }
            )
        }
        
        # Stage 4: Unit Tests (Parallel Testing workflow)
        @{
            Name = 'Unit Tests'
            Description = 'Run all unit tests with Pester'
            Scripts = @(
                @{
                    Number = '0402'
                    Name = 'Run-UnitTests'
                    Parameters = @{
                        # No parameters - runs all tests
                    }
                    Required = $true
                    Timeout = 600
                }
            )
        }
        
        # Stage 5: Integration Tests
        @{
            Name = 'Integration Tests'
            Description = 'Run integration tests'
            Scripts = @(
                @{
                    Number = '0403'
                    Name = 'Run-IntegrationTests'
                    Parameters = @{
                        # No parameters - runs all tests
                    }
                    Required = $false  # May not always be applicable
                    Timeout = 600
                }
            )
        }
        
        # Stage 6: Configuration Validation
        @{
            Name = 'Configuration Validation'
            Description = 'Validate config manifest structure'
            Scripts = @(
                @{
                    Number = '0413'
                    Name = 'Validate-ConfigManifest'
                    Parameters = @{
                        # No parameters
                    }
                    Required = $true
                    Timeout = 60
                }
            )
        }
        
        # Stage 7: Test Coverage Report
        @{
            Name = 'Test Coverage'
            Description = 'Generate test coverage report'
            Scripts = @(
                @{
                    Number = '0426'
                    Name = 'Validate-TestScriptSync'
                    Parameters = @{
                        # Validates all scripts have corresponding tests
                    }
                    Required = $false
                    Timeout = 120
                }
            )
        }
        
        # Stage 8: Project Report
        @{
            Name = 'Project Report'
            Description = 'Generate comprehensive project health report'
            Scripts = @(
                @{
                    Number = '0510'
                    Name = 'Generate-ProjectReport'
                    Parameters = @{
                        ShowAll = $true
                    }
                    Required = $false
                    Timeout = 180
                }
            )
        }
    )
    
    # ===================================================================
    # SUCCESS CRITERIA
    # ===================================================================
    
    SuccessCriteria = @{
        # All required stages must pass
        RequiredStagesPassed = $true
        
        # Maximum allowed warnings
        MaxWarnings = 100
        
        # Test coverage thresholds (if available)
        MinimumTestCoverage = 0  # Aspirational - not enforced yet
    }
    
    # ===================================================================
    # FAILURE HANDLING
    # ===================================================================
    
    OnFailure = @{
        # What to do when validation fails
        Action = 'Report'  # Options: Stop, Continue, Report
        
        # Generate detailed failure report
        GenerateReport = $true
        ReportPath = './reports/health-check-failures.json'
        
        # Create GitHub issues for failures (if in CI)
        CreateIssues = $false  # Disabled by default for local runs
    }
    
    # ===================================================================
    # REPORTING
    # ===================================================================
    
    Reporting = @{
        # Generate summary report
        GenerateSummary = $true
        SummaryPath = './reports/health-check-summary.md'
        
        # Console output format
        OutputFormat = 'Detailed'  # Options: Summary, Detailed, JSON
        
        # Save detailed results
        SaveResults = $true
        ResultsPath = './reports/health-check-results.json'
    }
    
    # ===================================================================
    # NOTES
    # ===================================================================
    <#
    .SYNOPSIS
        Comprehensive project health validation
    
    .DESCRIPTION
        This playbook runs the same validation checks as GitHub Actions workflows:
        - quick-health-check.yml (Syntax validation)
        - pr-validation.yml (PSScriptAnalyzer)
        - quality-validation.yml (Component quality)
        - parallel-testing.yml (Unit & Integration tests)
        
        Use this to validate your changes locally before pushing to GitHub.
    
    .EXAMPLE
        # Run full health check
        ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook project-health-check
    
    .EXAMPLE
        # Run with orchestration wrapper (requires bootstrap)
        aitherzero orchestrate project-health-check
    
    .NOTES
        Expected Duration: 15-30 minutes (depending on project size)
        Minimum Profile: Standard
        Recommended Profile: Full
    #>
}
