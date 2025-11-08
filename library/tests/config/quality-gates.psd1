@{
    # Quality gates that must be passed for code to merge
    
    # Gate execution order
    ExecutionOrder = @(
        'Syntax',
        'UnitTests',
        'PSScriptAnalyzer',
        'ASTAnalysis',
        'IntegrationTests',
        'Documentation',
        'Coverage',
        'SecurityScan'
    )
    
    # Individual quality gates
    Gates = @{
        
        Syntax = @{
            Enabled = $true
            Critical = $true  # Must pass to continue
            Name = 'PowerShell Syntax Validation'
            Description = 'Validates all PowerShell files have correct syntax'
            
            Rules = @{
                AllFilesMustParse = $true
                NoParseErrors = $true
                ValidEncoding = 'UTF8'  # or 'UTF8-BOM'
            }
            
            Exclusions = @()
            
            FailureAction = 'Stop'  # Stop, Continue, Warn
        }
        
        UnitTests = @{
            Enabled = $true
            Critical = $true
            Name = 'Unit Test Execution'
            Description = 'All unit tests must pass'
            
            Rules = @{
                PassRate = 100  # Percentage that must pass
                MaxFailures = 0
                MaxSkipped = 5  # Allow some skipped tests (platform-specific)
                Timeout = 900   # 15 minutes max
            }
            
            FailureAction = 'Stop'
        }
        
        PSScriptAnalyzer = @{
            Enabled = $true
            Critical = $true
            Name = 'PSScriptAnalyzer Validation'
            Description = 'Code must meet PowerShell best practices'
            
            Rules = @{
                # Severity levels that fail the gate
                FailOn = @('Error', 'Warning')
                
                # Maximum allowed violations by severity
                MaxViolations = @{
                    Error = 0
                    Warning = 10
                    Information = 50
                }
                
                # Use custom rules file
                SettingsFile = 'PSScriptAnalyzerSettings.psd1'
                
                # Specific rules to always enforce
                RequiredRules = @(
                    'PSAvoidUsingPlainTextForPassword',
                    'PSAvoidUsingConvertToSecureStringWithPlainText',
                    'PSUseDeclaredVarsMoreThanAssignments'
                )
            }
            
            Exclusions = @(
                'tests/**/*.Tests.ps1'  # Test files have different requirements
            )
            
            FailureAction = 'Stop'
        }
        
        ASTAnalysis = @{
            Enabled = $true
            Critical = $false  # Warning only initially
            Name = 'AST Code Analysis'
            Description = 'Advanced static code analysis'
            
            Rules = @{
                # Cyclomatic complexity
                MaxComplexity = 20
                TargetComplexity = 10
                
                # Function metrics
                MaxFunctionLength = 200  # Lines
                MaxParameterCount = 10
                MaxNestingDepth = 5
                
                # Error handling
                RequireTryCatch = $true
                RequireErrorActionPreference = $true
                
                # Logging
                RequireLoggingInFunctions = $true
                MinimumLoggingLevel = 'Information'
                
                # Cross-platform
                CheckPlatformCompatibility = $true
                RequirePlatformChecks = $true
            }
            
            FailureAction = 'Warn'
        }
        
        IntegrationTests = @{
            Enabled = $true
            Critical = $true
            Name = 'Integration Test Execution'
            Description = 'Integration tests must pass'
            
            Rules = @{
                PassRate = 95  # Allow 5% failure for flaky tests
                MaxFailures = 5
                MaxSkipped = 10
                Timeout = 1800  # 30 minutes max
                
                # Critical integration tests (must pass 100%)
                CriticalTests = @(
                    'Bootstrap-To-Infrastructure',
                    'ModuleLoading',
                    'OrchestrationEngine'
                )
            }
            
            FailureAction = 'Stop'
        }
        
        Documentation = @{
            Enabled = $true
            Critical = $false  # Warning only
            Name = 'Documentation Coverage'
            Description = 'All public functions must have documentation'
            
            Rules = @{
                # Comment-based help requirements
                RequireHelp = $true
                RequiredHelpSections = @(
                    '.SYNOPSIS',
                    '.DESCRIPTION',
                    '.PARAMETER',
                    '.EXAMPLE'
                )
                
                # README requirements
                RequireReadmeInDomains = $true
                RequireReadmeInScriptRanges = $true
                
                # Function documentation
                MinimumDocumentationCoverage = 90  # Percentage of public functions
            }
            
            FailureAction = 'Warn'
        }
        
        Coverage = @{
            Enabled = $true
            Critical = $true
            Name = 'Code Coverage'
            Description = 'Code coverage must meet minimum thresholds'
            
            Rules = @{
                MinimumOverall = 75
                MinimumPerModule = 70
                MinimumForNewCode = 80
                
                # Critical paths must have 100% coverage
                RequireCriticalPathCoverage = $true
                
                # Use coverage rules from coverage-rules.psd1
                UseDetailedRules = $true
            }
            
            FailureAction = 'Stop'
        }
        
        SecurityScan = @{
            Enabled = $true
            Critical = $true
            Name = 'Security Vulnerability Scan'
            Description = 'No security vulnerabilities allowed'
            
            Rules = @{
                # Password handling
                NoPlainTextPasswords = $true
                NoHardcodedSecrets = $true
                
                # Secure communication
                RequireHttps = $true
                ValidateCertificates = $true
                
                # File operations
                ValidateFilePaths = $true
                SanitizeInputs = $true
                
                # Execution
                NoInvokeExpression = $true
                NoStartProcess = $false  # Warning only
                
                # Dependencies
                ScanDependencies = $true
                NoKnownVulnerabilities = $true
            }
            
            FailureAction = 'Stop'
        }
        
        Performance = @{
            Enabled = $false  # Not enforced by default
            Critical = $false
            Name = 'Performance Validation'
            Description = 'Performance must not regress'
            
            Rules = @{
                # Execution time limits
                MaxModuleImportTime = 5000  # milliseconds
                MaxScriptExecutionTime = 60000  # milliseconds
                MaxFunctionExecutionTime = 1000  # milliseconds
                
                # Resource usage
                MaxMemoryUsageMB = 500
                MaxCpuPercent = 80
                
                # Regression detection
                AllowRegression = $false
                MaxRegressionPercent = 10
            }
            
            FailureAction = 'Warn'
        }
    }
    
    # Gate profiles for different scenarios
    Profiles = @{
        
        PR = @{
            Description = 'Quality gates for pull requests'
            EnabledGates = @(
                'Syntax',
                'UnitTests',
                'PSScriptAnalyzer',
                'IntegrationTests',
                'Coverage',
                'SecurityScan'
            )
            StopOnFirstFailure = $false
        }
        
        Release = @{
            Description = 'Quality gates for releases'
            EnabledGates = @(
                'Syntax',
                'UnitTests',
                'PSScriptAnalyzer',
                'ASTAnalysis',
                'IntegrationTests',
                'Documentation',
                'Coverage',
                'SecurityScan',
                'Performance'
            )
            StopOnFirstFailure = $true
        }
        
        Quick = @{
            Description = 'Quick validation for local development'
            EnabledGates = @(
                'Syntax',
                'UnitTests',
                'PSScriptAnalyzer'
            )
            StopOnFirstFailure = $true
        }
    }
    
    # Reporting
    Reporting = @{
        GenerateSummary = $true
        GenerateDetailedReport = $true
        OutputFormat = @('Console', 'Json', 'Html')
        ReportPath = 'library/tests/results/quality-gates'
        
        # PR comment template
        PRCommentTemplate = @"
## Quality Gate Results

{{#if passed}}
✅ All quality gates passed!
{{else}}
❌ Quality gates failed
{{/if}}

### Gate Results

{{#each gates}}
- {{#if passed}}✅{{else}}❌{{/if}} **{{name}}**: {{status}}
  {{#if violations}}
  - Violations: {{violations}}
  {{/if}}
{{/each}}

### Details

{{details}}
"@
    }
}
