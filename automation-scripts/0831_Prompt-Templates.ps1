#Requires -Version 7.0
<#
.SYNOPSIS
    Library of prompt templates for various scenarios
.DESCRIPTION
    Provides reusable prompt templates for different types of AI interactions
    Can be used standalone or with 0830_Generate-PromptFromData.ps1
.PARAMETER TemplateName
    Name of the template to use
.PARAMETER Variables
    Variables to substitute in the template
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$TemplateName = 'List',

    [Parameter(Mandatory = $false)]
    [hashtable]$Variables = @{},

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = $null,

    [switch]$ShowTemplate,

    [switch]$CopyToClipboard,

    [switch]$ReturnObject
)

# Template library
$Templates = @{
    # Analysis Templates
    'CodeReview' = @{
        Name = 'Code Review'
        Description = 'Comprehensive code review template'
        Template = @'
# Code Review Request

## File Information
- **Path:** {FilePath}
- **Language:** {Language}
- **Lines:** {LineCount}
- **Last Modified:** {LastModified}

## Review Scope
Please review the following code for:

### Security
- [ ] Input validation
- [ ] Authentication/authorization
- [ ] Sensitive data handling
- [ ] Injection vulnerabilities
- [ ] Cryptographic usage

### Quality
- [ ] Code clarity and readability
- [ ] Proper error handling
- [ ] Resource management
- [ ] Dead code
- [ ] Code duplication

### Performance
- [ ] Algorithm efficiency
- [ ] Memory usage
- [ ] Database queries
- [ ] Caching opportunities
- [ ] Async/parallel opportunities

### Best Practices
- [ ] Naming conventions
- [ ] Documentation
- [ ] Testing coverage
- [ ] Design patterns
- [ ] SOLID principles

## Code to Review
```{Language}
{Code}
```

## Specific Concerns
{Concerns}

## Expected Output
1. Critical issues that must be fixed
2. Recommendations for improvement
3. Security vulnerabilities
4. Performance optimizations
5. Suggested refactoring
'@
    }

    'BugAnalysis' = @{
        Name = 'Bug Analysis'
        Description = 'Template for analyzing bug reports'
        Template = @'
# Bug Analysis Request

## Bug Information
- **ID:** {BugId}
- **Severity:** {Severity}
- **Component:** {Component}
- **Reported:** {ReportDate}

## Description
{Description}

## Reproduction Steps
{ReproSteps}

## Expected vs Actual
**Expected:** {Expected}
**Actual:** {Actual}

## Error Details
```
{ErrorMessage}
```

## Stack Trace
```
{StackTrace}
```

## Environment
- **OS:** {OS}
- **Version:** {Version}
- **Configuration:** {Config}

## Analysis Required
1. Root cause analysis
2. Impact assessment
3. Fix recommendations
4. Prevention strategies
5. Test cases needed
'@
    }

    'TestGeneration' = @{
        Name = 'Test Generation'
        Description = 'Generate tests for code'
        Template = @'
# Test Generation Request

## Target Code
**File:** {FilePath}
**Function/Class:** {Target}
**Type:** {TestType}

## Code to Test
```{Language}
{Code}
```

## Test Requirements
- **Framework:** {Framework}
- **Coverage Target:** {Coverage}%
- **Test Types:**
  - [ ] Unit tests
  - [ ] Integration tests
  - [ ] Edge cases
  - [ ] Error conditions
  - [ ] Performance tests

## Specific Scenarios
{Scenarios}

## Mocking Requirements
{MockingNeeds}

## Output Format
Generate tests using {Framework} that:
1. Follow best practices
2. Include proper setup/teardown
3. Use appropriate assertions
4. Include helpful test names
5. Document test purpose
'@
    }

    # Conversion Templates
    'LanguageConversion' = @{
        Name = 'Language Conversion'
        Description = 'Convert code between languages'
        Template = @'
# Language Conversion Request

## Source
- **Language:** {SourceLanguage}
- **Framework:** {SourceFramework}
- **File:** {SourceFile}

## Target
- **Language:** {TargetLanguage}
- **Framework:** {TargetFramework}
- **Version:** {TargetVersion}

## Code to Convert
```{SourceLanguage}
{SourceCode}
```

## Conversion Requirements
1. Maintain exact functionality
2. Use idiomatic {TargetLanguage} patterns
3. Preserve comments and documentation
4. Handle error cases appropriately
5. Optimize for {TargetLanguage} performance

## Special Considerations
{Considerations}

## Dependencies to Map
{Dependencies}
'@
    }

    'DataTransformation' = @{
        Name = 'Data Transformation'
        Description = 'Transform data between formats'
        Template = @'
# Data Transformation Request

## Source Format
- **Type:** {SourceFormat}
- **Schema:** {SourceSchema}
- **Size:** {DataSize}

## Target Format
- **Type:** {TargetFormat}
- **Schema:** {TargetSchema}
- **Validation:** {ValidationRules}

## Sample Data
```{SourceFormat}
{SampleData}
```

## Transformation Rules
1. {Rule1}
2. {Rule2}
3. {Rule3}

## Field Mappings
{FieldMappings}

## Special Processing
- **Date Format:** {DateFormat}
- **Null Handling:** {NullHandling}
- **Encoding:** {Encoding}

## Output Requirements
- Validate all required fields
- Handle missing data gracefully
- Preserve data integrity
- Include transformation metadata
'@
    }

    # Implementation Templates
    'FeatureImplementation' = @{
        Name = 'Feature Implementation'
        Description = 'Implement a new feature'
        Template = @'
# Feature Implementation Request

## Feature Overview
**Name:** {FeatureName}
**Module:** {Module}
**Priority:** {Priority}

## Description
{Description}

## Requirements
### Functional Requirements
{FunctionalReqs}

### Non-Functional Requirements
{NonFunctionalReqs}

## User Story
As a {UserType}
I want {Goal}
So that {Benefit}

## Acceptance Criteria
{AcceptanceCriteria}

## Technical Approach
{TechnicalApproach}

## API Design
{APIDesign}

## Implementation Constraints
- **Language:** {Language}
- **Framework:** {Framework}
- **Dependencies:** {Dependencies}
- **Performance:** {PerformanceReqs}

## Deliverables
1. Implementation code
2. Unit tests
3. Integration tests
4. Documentation
5. Usage examples
'@
    }

    'APIEndpoint' = @{
        Name = 'API Endpoint'
        Description = 'Create API endpoint implementation'
        Template = @'
# API Endpoint Implementation

## Endpoint Details
- **Path:** {Path}
- **Method:** {Method}
- **Authentication:** {AuthType}
- **Rate Limit:** {RateLimit}

## Request
### Headers
{Headers}

### Parameters
{Parameters}

### Body Schema
```json
{RequestSchema}
```

## Response
### Success Response
**Code:** {SuccessCode}
```json
{SuccessResponse}
```

### Error Responses
{ErrorResponses}

## Business Logic
{BusinessLogic}

## Validation Rules
{ValidationRules}

## Implementation Requirements
1. Input validation
2. Error handling
3. Logging
4. Performance optimization
5. Security checks

## Database Operations
{DatabaseOps}

## External Service Calls
{ExternalCalls}
'@
    }

    # Documentation Templates
    'SystemDocumentation' = @{
        Name = 'System Documentation'
        Description = 'Generate system documentation'
        Template = @'
# System Documentation Request

## System Overview
**Name:** {SystemName}
**Version:** {Version}
**Purpose:** {Purpose}

## Architecture
{ArchitectureDescription}

## Components
{ComponentList}

## Documentation Sections Needed
1. **Overview**
   - Purpose and goals
   - Key features
   - System boundaries

2. **Architecture**
   - High-level design
   - Component diagram
   - Data flow
   - Technology stack

3. **API Reference**
   - Endpoints
   - Parameters
   - Examples
   - Error codes

4. **Configuration**
   - Settings
   - Environment variables
   - Deployment options

5. **Operations**
   - Installation
   - Monitoring
   - Troubleshooting
   - Maintenance

## Target Audience
{Audience}

## Format Requirements
- Markdown format
- Include diagrams (Mermaid)
- Code examples
- Quick start guide
'@
    }

    'ReleaseNotes' = @{
        Name = 'Release Notes'
        Description = 'Generate release notes'
        Template = @'
# Release Notes Generation

## Release Information
- **Version:** {Version}
- **Release Date:** {Date}
- **Type:** {ReleaseType}
- **Code Name:** {CodeName}

## Changes Since {PreviousVersion}

### Commits
```
{CommitList}
```

### Pull Requests
{PRList}

### Issues Closed
{IssueList}

## Generation Requirements
Please generate release notes that include:

1. **Overview**
   - Release highlights
   - Key improvements

2. **New Features**
   - Feature descriptions
   - Usage examples

3. **Improvements**
   - Performance enhancements
   - UX improvements

4. **Bug Fixes**
   - Critical fixes
   - Other fixes

5. **Breaking Changes**
   - API changes
   - Migration guide

6. **Deprecations**
   - Deprecated features
   - Removal timeline

7. **Known Issues**
   - Current limitations
   - Workarounds

Format: {Format}
Tone: {Tone}
'@
    }

    # Troubleshooting Templates
    'ErrorDiagnosis' = @{
        Name = 'Error Diagnosis'
        Description = 'Diagnose and fix errors'
        Template = @'
# Error Diagnosis Request

## Error Information
**Error Type:** {ErrorType}
**Error Code:** {ErrorCode}
**Timestamp:** {Timestamp}
**Frequency:** {Frequency}

## Error Message
```
{ErrorMessage}
```

## Stack Trace
```
{StackTrace}
```

## Context
**Operation:** {Operation}
**User Action:** {UserAction}
**System State:** {SystemState}

## Environment
- **OS:** {OS}
- **Runtime:** {Runtime}
- **Version:** {Version}
- **Configuration:** {Config}

## Recent Changes
{RecentChanges}

## Diagnosis Required
1. Root cause analysis
2. Impact assessment
3. Immediate workaround
4. Permanent fix
5. Prevention measures

## Additional Logs
```
{Logs}
```
'@
    }

    'PerformanceAnalysis' = @{
        Name = 'Performance Analysis'
        Description = 'Analyze performance issues'
        Template = @'
# Performance Analysis Request

## Performance Issue
**Component:** {Component}
**Metric:** {Metric}
**Current:** {CurrentValue}
**Expected:** {ExpectedValue}
**Degradation:** {Degradation}%

## Measurements
{Measurements}

## System Resources
- **CPU:** {CPU}
- **Memory:** {Memory}
- **Disk I/O:** {DiskIO}
- **Network:** {Network}

## Code Section
```{Language}
{Code}
```

## Profiling Data
{ProfilingData}

## Analysis Required
1. Identify bottlenecks
2. Resource usage analysis
3. Algorithm complexity review
4. Database query optimization
5. Caching opportunities

## Optimization Goals
- Target Response Time: {TargetTime}
- Target Throughput: {TargetThroughput}
- Resource Budget: {ResourceBudget}

## Constraints
{Constraints}
'@
    }
}

# Function to list available templates
function Get-PromptTemplates {
    $Templates.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Key
            DisplayName = $_.Value.Name
            Description = $_.Value.Description
            Variables = @(([regex]::Matches($_.Value.Template, '\{(\w+)\}') | ForEach-Object { $_.Groups[1].Value }) | Select-Object -Unique)
        }
    } | Sort-Object Name
}

# Function to get template
function Get-PromptTemplate {
    param(
        [string]$Name,
        [hashtable]$Variables = @{}
    )

    if (-not $Templates.ContainsKey($Name)) {
        throw "Template '$Name' not found. Available templates: $($Templates.Keys -join ', ')"
    }

    $template = $Templates[$Name].Template

    # Replace variables
    foreach ($key in $Variables.Keys) {
        $template = $template -replace "\{$key\}", $Variables[$key]
    }

    # Highlight unreplaced variables
    $unreplaced = [regex]::Matches($template, '\{(\w+)\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    if ($unreplaced) {
        Write-Warning "Unreplaced variables: $($unreplaced -join ', ')"
    }

    return $template
}

# Main execution
if ($PSCmdlet.MyInvocation.InvocationName -ne '&') {
    # Script is being run directly, not dot-sourced

    if ($TemplateName -eq 'List') {
        Write-Host "📋 Available Prompt Templates" -ForegroundColor Cyan
        Write-Host ""

        Get-PromptTemplates | Format-Table -AutoSize

        Write-Host "`n💡 Usage Examples:" -ForegroundColor Yellow
        Write-Host "   # Get a specific template:" -ForegroundColor Gray
        Write-Host "   ./0831_Prompt-Templates.ps1 -TemplateName CodeReview -ShowTemplate" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   # Use with variables:" -ForegroundColor Gray
        Write-Host "   ./0831_Prompt-Templates.ps1 -TemplateName BugAnalysis -Variables @{BugId='123'; Severity='High'}" -ForegroundColor DarkGray

        exit 0
    }

    try {
        $result = Get-PromptTemplate -Name $TemplateName -Variables $Variables

        if ($ShowTemplate) {
            Write-Host "📄 Template: $($Templates[$TemplateName].Name)" -ForegroundColor Cyan
            Write-Host "=" * 80 -ForegroundColor DarkGray
            Write-Host $result
            Write-Host "=" * 80 -ForegroundColor DarkGray
        }

        if ($OutputPath) {
            if ($PSCmdlet.ShouldProcess($OutputPath, 'Save Template')) {
                $result | Set-Content $OutputPath -Encoding UTF8
                Write-Host "✅ Template saved to: $OutputPath" -ForegroundColor Green
            }
        }

        if ($CopyToClipboard) {
            if ($IsWindows) {
                $result | Set-Clipboard
                Write-Host "📋 Copied to clipboard!" -ForegroundColor Green
            }
        }

        if ($ReturnObject) {
            return $result
        }

        if (-not $ShowTemplate -and -not $OutputPath -and -not $CopyToClipboard) {
            # Default: show the template
            Write-Output $result
        }
    }
    catch {
        Write-Error $_
        exit 1
    }
}