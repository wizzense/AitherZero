#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0831_Prompt-Templates.ps1"

    Mock Write-Host -MockWith {}
    Mock Write-Error -MockWith {}
    Mock Set-Content -MockWith {}
    Mock Format-Table -MockWith {}
    Mock Set-Clipboard -MockWith {}
    Mock Get-Command -MockWith { return $true } -ParameterFilter { $Name -eq "xclip" }

    # Dot source the script to access functions and templates
    . $scriptPath
}

Describe "0831_Prompt-Templates" {
    Context "Parameter Validation" {
        It "Should support WhatIf functionality" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept valid TemplateName values" {
            { & $scriptPath -TemplateName "CodeReview" -WhatIf } | Should -Not -Throw
            { & $scriptPath -TemplateName "BugAnalysis" -WhatIf } | Should -Not -Throw
            { & $scriptPath -TemplateName "TestGeneration" -WhatIf } | Should -Not -Throw
        }

        It "Should accept Variables parameter" {
            $vars = @{ FilePath = "test.ps1"; Language = "PowerShell" }
            { & $scriptPath -TemplateName "CodeReview" -Variables $vars -WhatIf } | Should -Not -Throw
        }

        It "Should accept OutputPath parameter" {
            { & $scriptPath -TemplateName "CodeReview" -OutputPath "output.md" -WhatIf } | Should -Not -Throw
        }
    }

    Context "Template Library Access" {
        It "Should have Get-PromptTemplates function available" {
            Get-Command Get-PromptTemplates | Should -Not -BeNullOrEmpty
        }

        It "Should have Get-PromptTemplate function available" {
            Get-Command Get-PromptTemplate | Should -Not -BeNullOrEmpty
        }

        It "Should return list of available templates" {
            $templates = Get-PromptTemplates
            $templates | Should -Not -BeNullOrEmpty
            $templates[0].Name | Should -Not -BeNullOrEmpty
        }

        It "Should include standard template types" {
            $templates = Get-PromptTemplates
            $templateNames = $templates.Name

            $templateNames | Should -Contain "CodeReview"
            $templateNames | Should -Contain "BugAnalysis"
            $templateNames | Should -Contain "TestGeneration"
            $templateNames | Should -Contain "FeatureImplementation"
            $templateNames | Should -Contain "APIEndpoint"
        }
    }

    Context "Template Retrieval" {
        It "Should retrieve template by name" {
            $template = Get-PromptTemplate -Name "CodeReview"
            $template | Should -Not -BeNullOrEmpty
            $template | Should -Match "Code Review Request"
        }

        It "Should fail for non-existent template" {
            { Get-PromptTemplate -Name "NonExistentTemplate" } | Should -Throw "*not found*"
        }

        It "Should replace variables in template" {
            $variables = @{
                FilePath = "test.ps1"
                Language = "PowerShell"
                LineCount = "100"
            }

            $template = Get-PromptTemplate -Name "CodeReview" -Variables $variables
            $template | Should -Match "test.ps1"
            $template | Should -Match "PowerShell"
            $template | Should -Match "100"
        }

        It "Should warn about unreplaced variables" {
            $variables = @{ FilePath = "test.ps1" } # Missing other required variables

            $template = Get-PromptTemplate -Name "CodeReview" -Variables $variables
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*Unreplaced variables:*" }
        }
    }

    Context "Code Review Template" {
        It "Should generate code review template" {
            $variables = @{
                FilePath = "src/module.ps1"
                Language = "PowerShell"
                LineCount = "150"
                LastModified = "2023-01-01"
                Code = "function Get-Data { return 'test' }"
                Concerns = "Performance optimization needed"
            }

            $template = Get-PromptTemplate -Name "CodeReview" -Variables $variables

            $template | Should -Match "Code Review Request"
            $template | Should -Match "src/module.ps1"
            $template | Should -Match "Security"
            $template | Should -Match "Quality"
            $template | Should -Match "Performance"
            $template | Should -Match "Best Practices"
        }

        It "Should include all review categories" {
            $template = Get-PromptTemplate -Name "CodeReview"

            $template | Should -Match "Security"
            $template | Should -Match "Input validation"
            $template | Should -Match "Authentication"
            $template | Should -Match "Quality"
            $template | Should -Match "Code clarity"
            $template | Should -Match "Performance"
            $template | Should -Match "Algorithm efficiency"
            $template | Should -Match "Best Practices"
            $template | Should -Match "Naming conventions"
        }
    }

    Context "Bug Analysis Template" {
        It "Should generate bug analysis template" {
            $variables = @{
                BugId = "BUG-123"
                Severity = "High"
                Component = "Authentication"
                ReportDate = "2023-01-01"
                Description = "Login failure"
                ReproSteps = "1. Navigate to login 2. Enter credentials"
                Expected = "Successful login"
                Actual = "Error message displayed"
                ErrorMessage = "Authentication failed"
                StackTrace = "at Login.Authenticate()"
                OS = "Windows 11"
                Version = "1.0.0"
                Config = "Default"
            }

            $template = Get-PromptTemplate -Name "BugAnalysis" -Variables $variables

            $template | Should -Match "Bug Analysis Request"
            $template | Should -Match "BUG-123"
            $template | Should -Match "High"
            $template | Should -Match "Authentication"
            $template | Should -Match "Root cause analysis"
        }
    }

    Context "Test Generation Template" {
        It "Should generate test generation template" {
            $variables = @{
                FilePath = "src/calculator.ps1"
                Target = "Add-Numbers"
                TestType = "Unit"
                Language = "PowerShell"
                Code = "function Add-Numbers { param($a, $b) return $a + $b }"
                Framework = "Pester"
                Coverage = "95"
                Scenarios = "Valid inputs, null inputs, negative numbers"
                MockingNeeds = "External API calls"
            }

            $template = Get-PromptTemplate -Name "TestGeneration" -Variables $variables

            $template | Should -Match "Test Generation Request"
            $template | Should -Match "Add-Numbers"
            $template | Should -Match "Pester"
            $template | Should -Match "95%"
            $template | Should -Match "Unit tests"
            $template | Should -Match "Integration tests"
            $template | Should -Match "Edge cases"
        }
    }

    Context "Feature Implementation Template" {
        It "Should generate feature implementation template" {
            $variables = @{
                FeatureName = "User Authentication"
                Module = "Security"
                Priority = "High"
                Description = "Implement OAuth2 authentication"
                FunctionalReqs = "Login, logout, token refresh"
                NonFunctionalReqs = "Sub-second response time"
                UserType = "developer"
                Goal = "secure API access"
                Benefit = "improved security"
                AcceptanceCriteria = "User can login with OAuth2"
                TechnicalApproach = "Use OAuth2 library"
                APIDesign = "REST endpoints for auth"
                Language = "PowerShell"
                Framework = ".NET"
                Dependencies = "Microsoft.Identity"
                PerformanceReqs = "< 1 second response"
            }

            $template = Get-PromptTemplate -Name "FeatureImplementation" -Variables $variables

            $template | Should -Match "Feature Implementation Request"
            $template | Should -Match "User Authentication"
            $template | Should -Match "OAuth2"
            $template | Should -Match "User Story"
            $template | Should -Match "Acceptance Criteria"
        }
    }

    Context "API Endpoint Template" {
        It "Should generate API endpoint template" {
            $variables = @{
                Path = "/api/users"
                Method = "POST"
                AuthType = "Bearer Token"
                RateLimit = "100 requests/minute"
                Headers = "Content-Type, Authorization"
                Parameters = "name, email"
                RequestSchema = '{"name": "string", "email": "string"}'
                SuccessCode = "201"
                SuccessResponse = '{"id": 123, "name": "John"}'
                ErrorResponses = "400 Bad Request, 409 Conflict"
                BusinessLogic = "Create user account"
                ValidationRules = "Email format validation"
                DatabaseOps = "INSERT INTO users"
                ExternalCalls = "Email service validation"
            }

            $template = Get-PromptTemplate -Name "APIEndpoint" -Variables $variables

            $template | Should -Match "API Endpoint Implementation"
            $template | Should -Match "/api/users"
            $template | Should -Match "POST"
            $template | Should -Match "Bearer Token"
            $template | Should -Match "Request Schema"
            $template | Should -Match "Response"
        }
    }

    Context "Documentation Templates" {
        It "Should generate system documentation template" {
            $variables = @{
                SystemName = "AitherZero"
                Version = "1.0.0"
                Purpose = "Automation platform"
                ArchitectureDescription = "Modular PowerShell framework"
                ComponentList = "Orchestration, Testing, Reporting"
                Audience = "Developers and system administrators"
            }

            $template = Get-PromptTemplate -Name "SystemDocumentation" -Variables $variables

            $template | Should -Match "System Documentation Request"
            $template | Should -Match "AitherZero"
            $template | Should -Match "Automation platform"
            $template | Should -Match "Overview"
            $template | Should -Match "Architecture"
            $template | Should -Match "API Reference"
        }

        It "Should generate release notes template" {
            $variables = @{
                Version = "1.1.0"
                Date = "2023-01-01"
                ReleaseType = "Minor"
                CodeName = "Stability"
                PreviousVersion = "1.0.0"
                CommitList = "feat: new feature\nfix: bug fix"
                PRList = "#123, #124, #125"
                IssueList = "#100, #101, #102"
                Format = "Markdown"
                Tone = "Professional"
            }

            $template = Get-PromptTemplate -Name "ReleaseNotes" -Variables $variables

            $template | Should -Match "Release Notes Generation"
            $template | Should -Match "1.1.0"
            $template | Should -Match "Minor"
            $template | Should -Match "New Features"
            $template | Should -Match "Bug Fixes"
            $template | Should -Match "Breaking Changes"
        }
    }

    Context "Troubleshooting Templates" {
        It "Should generate error diagnosis template" {
            $variables = @{
                ErrorType = "RuntimeError"
                ErrorCode = "E001"
                Timestamp = "2023-01-01 12:00:00"
                Frequency = "Intermittent"
                ErrorMessage = "Null reference exception"
                StackTrace = "at Function.Execute()"
                Operation = "Data processing"
                UserAction = "Click submit button"
                SystemState = "High memory usage"
                OS = "Windows 11"
                Runtime = "PowerShell 7.3"
                Version = "1.0.0"
                Config = "Production"
                RecentChanges = "Updated authentication module"
                Logs = "Additional error details"
            }

            $template = Get-PromptTemplate -Name "ErrorDiagnosis" -Variables $variables

            $template | Should -Match "Error Diagnosis Request"
            $template | Should -Match "RuntimeError"
            $template | Should -Match "E001"
            $template | Should -Match "Root cause analysis"
            $template | Should -Match "Impact assessment"
        }

        It "Should generate performance analysis template" {
            $variables = @{
                Component = "Database queries"
                Metric = "Response time"
                CurrentValue = "5 seconds"
                ExpectedValue = "1 second"
                Degradation = "400"
                Measurements = "Average: 5s, P95: 8s"
                CPU = "80%"
                Memory = "12GB"
                DiskIO = "High"
                Network = "Normal"
                Language = "PowerShell"
                Code = "Invoke-SqlCmd -Query $query"
                ProfilingData = "Query execution: 4.5s"
                TargetTime = "< 1 second"
                TargetThroughput = "1000 req/s"
                ResourceBudget = "8GB RAM max"
                Constraints = "Cannot change database schema"
            }

            $template = Get-PromptTemplate -Name "PerformanceAnalysis" -Variables $variables

            $template | Should -Match "Performance Analysis Request"
            $template | Should -Match "Database queries"
            $template | Should -Match "Response time"
            $template | Should -Match "5 seconds"
            $template | Should -Match "bottlenecks"
        }
    }

    Context "Script Execution" {
        It "Should list templates when called with List parameter" {
            & $scriptPath -TemplateName "List"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Available Prompt Templates*" }
            Should -Invoke Format-Table -Times 1
        }

        It "Should show template when ShowTemplate is used" {
            & $scriptPath -TemplateName "CodeReview" -ShowTemplate

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Template: Code Review*" }
        }

        It "Should save template to file when OutputPath specified" {
            & $scriptPath -TemplateName "CodeReview" -OutputPath "test.md"

            Should -Invoke Set-Content -ParameterFilter { $Path -eq "test.md" }
        }

        It "Should copy to clipboard when requested" {
            & $scriptPath -TemplateName "CodeReview" -CopyToClipboard

            Should -Invoke Set-Clipboard -Times 1
        }

        It "Should output template content by default" {
            $result = & $scriptPath -TemplateName "CodeReview"
            $result | Should -Match "Code Review Request"
        }
    }

    Context "Error Handling" {
        It "Should handle invalid template names" {
            { & $scriptPath -TemplateName "InvalidTemplate" } | Should -Throw
        }

        It "Should handle empty variables gracefully" {
            { & $scriptPath -TemplateName "CodeReview" -Variables @{} } | Should -Not -Throw
        }

        It "Should handle null variables" {
            { & $scriptPath -TemplateName "CodeReview" -Variables $null } | Should -Not -Throw
        }
    }

    Context "Variable Substitution" {
        It "Should identify required variables for each template" {
            $templates = Get-PromptTemplates

            foreach ($template in $templates) {
                $template.Variables | Should -Not -BeNullOrEmpty
            }
        }

        It "Should substitute all provided variables" {
            $variables = @{
                FilePath = "test.ps1"
                Language = "PowerShell"
                LineCount = "50"
                LastModified = "Today"
                Code = "Write-Host 'Hello'"
                Concerns = "None"
            }

            $template = Get-PromptTemplate -Name "CodeReview" -Variables $variables

            # Should not contain unreplaced variable placeholders for provided variables
            $template | Should -Not -Match "\{FilePath\}"
            $template | Should -Not -Match "\{Language\}"
            $template | Should -Not -Match "\{LineCount\}"
        }
    }

    Context "Template Content Validation" {
        It "Should have non-empty templates" {
            $templates = Get-PromptTemplates

            foreach ($template in $templates) {
                $content = Get-PromptTemplate -Name $template.Name
                $content.Length | Should -BeGreaterThan 10
            }
        }

        It "Should contain proper markdown formatting" {
            $template = Get-PromptTemplate -Name "CodeReview"

            $template | Should -Match "^#"  # Should start with header
            $template | Should -Match "##"  # Should have subheaders
        }

        It "Should contain structured sections" {
            $template = Get-PromptTemplate -Name "BugAnalysis"

            $template | Should -Match "Bug Information"
            $template | Should -Match "Description"
            $template | Should -Match "Environment"
            $template | Should -Match "Analysis Required"
        }
    }
}
