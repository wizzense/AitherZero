#Requires -Version 7.0
<#
.SYNOPSIS
    ci-cd-complete - Comprehensive CI/CD pipeline from validation to release
.DESCRIPTION
    Complete CI/CD pipeline that handles everything from initial validation through
    testing, building, security scanning, and release deployment. Designed to work
    both locally and in GitHub Actions with minimal configuration.
.NOTES
    Version: 1.0.0
    Author: AitherZero DevOps Team
#>

@{
    # Metadata
    Name = 'ci-cd-complete'
    Description = 'Complete CI/CD pipeline from validation to release deployment'
    Version = '1.0.0'
    Author = 'AitherZero DevOps Team'
    Created = '2025-08-16T00:00:00Z'
    
    # Categorization
    Tags = @('ci', 'cd', 'pipeline', 'complete', 'release', 'deployment')
    Category = 'Operations'
    
    # Requirements
    Requirements = @{
        Modules = @('Pester', 'PSScriptAnalyzer')
        MinimumVersion = '7.0'
        EstimatedDuration = '20-40 minutes'
        Tools = @('git')
    }
    
    # Default Variables - Can be overridden by environment or parameters
    Variables = @{
        # Control flags
        RunValidation = $true
        RunTests = $true
        RunSecurity = $true
        RunCompliance = $true
        RunBuild = $true
        CreateRelease = $false  # Only true when tagged
        DeployDocs = $false     # Only true on main branch
        
        # Configuration
        TestProfile = 'Full'    # Quick, Standard, Full
        BuildProfiles = @('Core', 'Standard', 'Full')
        CoverageThreshold = 80
        
        # Paths
        OutputPath = './artifacts'
        ReportsPath = './reports'
        ReleasePath = './release'
        
        # Version (auto-detected from git tag or VERSION file)
        Version = ''
        Prerelease = $false
    }
    
    # Execution Stages
    Stages = @(
        # === STAGE 1: ENVIRONMENT SETUP ===
        @{
            Name = 'Environment Setup'
            Description = 'Initialize environment and detect configuration'
            Sequence = @('0001')  # Environment check
            ContinueOnError = $false
            Timeout = 60
        }
        
        # === STAGE 2: VALIDATION ===
        @{
            Name = 'Validation'
            Description = 'Validate code syntax, workflows, and playbooks'
            Sequence = @(
                '0407'  # Syntax validation
                '0440'  # GitHub workflow validation
                '0460'  # Playbook validation
            )
            ContinueOnError = $false
            Timeout = 300
            Condition = 'Variables.RunValidation -eq $true'
            OnError = @{
                Action = 'Abort'
                Message = 'Validation failed - cannot proceed with invalid code'
            }
        }
        
        # === STAGE 3: STATIC ANALYSIS ===
        @{
            Name = 'Static Analysis'
            Description = 'Run PSScriptAnalyzer and code quality checks'
            Sequence = @('0404')  # PSScriptAnalyzer
            Variables = @{
                Severity = @('Error', 'Warning')
                GenerateSARIF = $true  # For GitHub code scanning
            }
            ContinueOnError = $false
            Timeout = 300
        }
        
        # === STAGE 4: TESTING ===
        @{
            Name = 'Testing'
            Description = 'Run comprehensive test suite with coverage'
            Sequence = @(
                '0402'  # Unit tests
                '0403'  # Integration tests (if exists)
            )
            Variables = @{
                RunCoverage = $true
                OutputFormat = @('NUnitXml', 'JaCoCo')
                FailFast = $false
            }
            ContinueOnError = $false
            Timeout = 900
            Condition = 'Variables.RunTests -eq $true'
        }
        
        # === STAGE 5: SECURITY SCANNING ===
        @{
            Name = 'Security'
            Description = 'Run security vulnerability scanning'
            Sequence = @('0523')  # Security scan script
            Variables = @{
                ScanLevel = 'Standard'
                GenerateReport = $true
            }
            ContinueOnError = $true
            Timeout = 600
            Condition = 'Variables.RunSecurity -eq $true'
        }
        
        # === STAGE 6: BUILD ===
        @{
            Name = 'Build'
            Description = 'Build release packages'
            Sequence = @('9100')  # Build-Release script
            Variables = @{
                SignPackages = $false  # Would need cert
            }
            ContinueOnError = $false
            Timeout = 600
            Condition = 'Variables.RunBuild -eq $true'
        }
        
        # === STAGE 7: PACKAGE VALIDATION ===
        @{
            Name = 'Validate Packages'
            Description = 'Test that built packages work correctly'
            Sequence = @('9105')  # Test-ReleasePackages
            ContinueOnError = $true
            Timeout = 300
            Condition = 'Variables.RunBuild -eq $true'
        }
        
        # === STAGE 8: DOCUMENTATION ===
        @{
            Name = 'Documentation'
            Description = 'Generate reports and documentation'
            Sequence = @(
                '0510'  # Project report
                '0511'  # Dashboard
            )
            Variables = @{
                Format = @('HTML', 'Markdown', 'JSON')
                IncludeMetrics = $true
            }
            ContinueOnError = $true
            Timeout = 300
        }
        
        # === STAGE 9: COMPLIANCE & AUDIT ===
        @{
            Name = 'Compliance Audit'
            Description = 'Run compliance checks and generate audit reports'
            Sequence = @('0524', '0525')  # Compliance check, Audit report
            Variables = @{
                AuditLevel = 'Full'
                GenerateReport = $true
                CheckLicenses = $true
                CheckDependencies = $true
                CheckSecurityPolicies = $true
            }
            ContinueOnError = $true
            Timeout = 300
            Condition = 'Variables.RunCompliance -eq $true'
        }
        
        # === STAGE 10: RELEASE ===
        @{
            Name = 'Release'
            Description = 'Create GitHub release'
            Sequence = @('9102')  # Create-GitHubRelease
            Variables = @{
                GenerateNotes = $true
            }
            ContinueOnError = $true
            Timeout = 180
            Condition = 'Variables.CreateRelease -eq $true'
        }
    )
    
    # Quality Gates
    QualityGates = @{
        Validation = @{
            Required = $true
            FailOnError = $true
        }
        Testing = @{
            MinimumPassRate = 95
            CoverageThreshold = 80
        }
        Analysis = @{
            MaxErrors = 0
            MaxWarnings = 20
        }
        Security = @{
            MaxHighSeverity = 0
            MaxMediumSeverity = 5
        }
        Compliance = @{
            RequiredPolicies = @('LICENSE', 'SECURITY.md', 'CODE_OF_CONDUCT.md')
            MaxLicenseRisk = 'Medium'
            RequireSignedCommits = $false
            RequireDependencyAudit = $true
        }
    }
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = 'CI/CD pipeline completed successfully'
            Level = 'Success'
            ShowSummary = $true
        }
        OnFailure = @{
            Message = 'CI/CD pipeline failed at stage: {FailedStage}'
            Level = 'Error'
            ShowDetails = $true
        }
    }
    
    # CI/CD Integration
    Integrations = @{
        GitHub = @{
            Enabled = $true
            RequireStatusChecks = $true
            PublishTestResults = $true
            PublishCodeCoverage = $true
            UploadSARIF = $true
        }
        Artifacts = @{
            RetentionDays = 30
            Paths = @('./release', './reports', './tests/results', './tests/coverage')
        }
    }
}