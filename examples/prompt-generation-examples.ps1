#Requires -Version 7.0
<#
.SYNOPSIS
    Examples of using the prompt generation system
.DESCRIPTION
    Demonstrates various ways to generate AI prompts from structured data
#>

# Import modules if needed
$scriptPath = Split-Path $PSScriptRoot -Parent
. "$scriptPath/Initialize-AitherModules.ps1" -ErrorAction SilentlyContinue

Write-Host "🤖 AitherZero Prompt Generation Examples" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# Example 1: Convert Tanium package to PowerShell
Write-Host "`n📌 Example 1: Tanium Package Analysis" -ForegroundColor Yellow
Write-Host "Converting Tanium package export to PowerShell implementation" -ForegroundColor Gray

$taniumExample = @'
# Analyze Tanium package and generate PowerShell equivalent
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./examples/p.json" `
    -DataType "Tanium" `
    -PromptTemplate "Implementation" `
    -OutputPath "./.claude/tanium-conversion.md" `
    -IncludeExamples

# Result: Creates a prompt asking AI to convert Tanium packages to PowerShell
'@
Write-Host $taniumExample -ForegroundColor DarkGray

# Example 2: Analyze orchestration patterns
Write-Host "`n📌 Example 2: Orchestration Analysis" -ForegroundColor Yellow
Write-Host "Analyzing orchestration examples for optimization" -ForegroundColor Gray

$orchestrationExample = @'
# Analyze orchestration patterns
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./examples/orchestration-examples.ps1" `
    -DataType "Orchestration" `
    -PromptTemplate "Analysis" `
    -Context @{
        Goal = "Optimize parallel execution"
        Environment = "Production"
    }

# Result: Creates analysis prompt for orchestration optimization
'@
Write-Host $orchestrationExample -ForegroundColor DarkGray

# Example 3: Generate tests from JSON data
Write-Host "`n📌 Example 3: Test Generation from Data" -ForegroundColor Yellow
Write-Host "Creating test cases from structured data" -ForegroundColor Gray

$testGenExample = @'
# Generate tests for JSON configuration
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./config.psd1" `
    -DataType "Configuration" `
    -PromptTemplate "Testing" `
    -MaxTokens 3000 `
    -GenerateCode

# Result: Creates prompt for generating Pester tests
'@
Write-Host $testGenExample -ForegroundColor DarkGray

# Example 4: Documentation generation
Write-Host "`n📌 Example 4: Auto-Generate Documentation" -ForegroundColor Yellow
Write-Host "Creating documentation from code/data" -ForegroundColor Gray

$docExample = @'
# Generate documentation for orchestration playbook
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./orchestration/playbooks/test-full.json" `
    -DataType "JSON" `
    -PromptTemplate "Documentation" `
    -IncludeExamples

# Result: Creates prompt for comprehensive documentation
'@
Write-Host $docExample -ForegroundColor DarkGray

# Example 5: Using prompt templates
Write-Host "`n📌 Example 5: Using Prompt Templates" -ForegroundColor Yellow
Write-Host "Pre-built templates for common scenarios" -ForegroundColor Gray

$templateExample = @'
# List available templates
./automation-scripts/0831_Prompt-Templates.ps1 -TemplateName List

# Use code review template
./automation-scripts/0831_Prompt-Templates.ps1 `
    -TemplateName "CodeReview" `
    -Variables @{
        FilePath = "./domains/automation/OrchestrationEngine.psm1"
        Language = "PowerShell"
        LineCount = 500
        Concerns = "Performance and error handling"
    } `
    -OutputPath "./.claude/code-review.md"

# Use bug analysis template
./automation-scripts/0831_Prompt-Templates.ps1 `
    -TemplateName "BugAnalysis" `
    -Variables @{
        BugId = "GH-123"
        Severity = "High"
        Component = "OrchestrationEngine"
        Description = "Parallel execution fails on error"
    }
'@
Write-Host $templateExample -ForegroundColor DarkGray

# Example 6: Chain with session management
Write-Host "`n📌 Example 6: Integration with Session Management" -ForegroundColor Yellow
Write-Host "Combine with context saving for continuity" -ForegroundColor Gray

$chainExample = @'
# Save context and generate continuation prompt with data analysis
seq 0820  # Save work context
seq 0830 -InputPath "./tests/results/latest-test-results.json" -DataType "TestResults"
seq 0821  # Generate continuation prompt

# Result: Complete context with test analysis for AI handoff
'@
Write-Host $chainExample -ForegroundColor DarkGray

# Example 7: Custom template with Tanium data
Write-Host "`n📌 Example 7: Custom Template Application" -ForegroundColor Yellow
Write-Host "Using custom templates for specific needs" -ForegroundColor Gray

$customExample = @'
# Create custom template
$customTemplate = @"
# Security Audit Request for {DataType} Data

## Audit Scope
Analyze the following {DataType} data for security vulnerabilities:

## Data Source
- File: {Source}
- Size: {Metadata.PackageCount} packages
- Export Date: {Metadata.ExportDate}

## Security Checks Required
1. Command injection vulnerabilities
2. Privilege escalation risks
3. Data exposure concerns
4. Network security implications
5. Compliance violations

## Data Content
{Content}

## Expected Output
- Critical security issues
- Risk assessment matrix
- Remediation recommendations
- Compliance gaps
"@

# Apply custom template
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./examples/p.json" `
    -DataType "Tanium" `
    -PromptTemplate "Custom" `
    -CustomTemplate $customTemplate
'@
Write-Host $customExample -ForegroundColor DarkGray

# Example 8: Batch processing
Write-Host "`n📌 Example 8: Batch Processing Multiple Files" -ForegroundColor Yellow
Write-Host "Process multiple data files at once" -ForegroundColor Gray

$batchExample = @'
# Process all JSON files in a directory
Get-ChildItem "./examples/*.json" | ForEach-Object {
    ./automation-scripts/0830_Generate-PromptFromData.ps1 `
        -InputPath $_.FullName `
        -DataType "Auto" `
        -PromptTemplate "Analysis" `
        -OutputPath "./.claude/prompts/$($_.BaseName)-analysis.md"
}

# Process test results
Get-ChildItem "./tests/results/*-results.json" | ForEach-Object {
    ./automation-scripts/0830_Generate-PromptFromData.ps1 `
        -InputPath $_.FullName `
        -DataType "TestResults" `
        -PromptTemplate "Implementation" `
        -OutputPath "./.claude/prompts/$($_.BaseName)-fixes.md"
}
'@
Write-Host $batchExample -ForegroundColor DarkGray

# Example 9: Interactive mode
Write-Host "`n📌 Example 9: Interactive Prompt Editing" -ForegroundColor Yellow
Write-Host "Edit prompts before finalizing" -ForegroundColor Gray

$interactiveExample = @'
# Interactive mode allows editing before saving
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./examples/p.json" `
    -DataType "Tanium" `
    -PromptTemplate "Conversion" `
    -Interactive `
    -CopyToClipboard

# Result: Opens editor for refinement, then copies to clipboard
'@
Write-Host $interactiveExample -ForegroundColor DarkGray

# Example 10: Pipeline integration
Write-Host "`n📌 Example 10: Pipeline Integration" -ForegroundColor Yellow
Write-Host "Use in CI/CD pipelines" -ForegroundColor Gray

$pipelineExample = @'
# GitHub Actions workflow snippet
- name: Generate AI Prompt from Test Failures
  if: failure()
  run: |
    ./automation-scripts/0830_Generate-PromptFromData.ps1 `
        -InputPath "./tests/results/latest-test-results.json" `
        -DataType "TestResults" `
        -PromptTemplate "Implementation" `
        -OutputPath "./ai-fix-prompt.md"
    
    # Upload as artifact
    echo "::set-output name=prompt_path::./ai-fix-prompt.md"

- name: Create Issue with AI Prompt
  if: failure()
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require("fs");
      const prompt = fs.readFileSync("./ai-fix-prompt.md", "utf8");
      
      await github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: "[AI] Test Failures Need Fixing",
        body: prompt,
        labels: ["ai-assistance", "test-failure"]
      });
'@
Write-Host $pipelineExample -ForegroundColor DarkGray

# Show practical workflow
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "💡 Practical Workflow Example" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

$workflowExample = @'
# Complete workflow for analyzing and converting Tanium package

# 1. First, analyze the Tanium export
$analysis = ./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./examples/p.json" `
    -DataType "Tanium" `
    -PromptTemplate "Analysis" `
    -ReturnObject

# 2. Review the analysis (send to AI for insights)
# ... AI provides analysis ...

# 3. Generate implementation based on analysis
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./examples/p.json" `
    -DataType "Tanium" `
    -PromptTemplate "Implementation" `
    -Context @{
        TargetPlatform = "AitherZero"
        ScriptPrefix = "0900"
        Module = "automation"
    } `
    -OutputPath "./.claude/tanium-implementation.md"

# 4. After AI generates code, create tests
./automation-scripts/0831_Prompt-Templates.ps1 `
    -TemplateName "TestGeneration" `
    -Variables @{
        FilePath = "./automation-scripts/0900_Event-Tracing.ps1"
        Target = "Start-EventTracing"
        TestType = "Unit"
        Framework = "Pester 5"
        Coverage = 80
    } `
    -OutputPath "./.claude/test-generation.md"

# 5. Document the new functionality
./automation-scripts/0830_Generate-PromptFromData.ps1 `
    -InputPath "./automation-scripts/0900_Event-Tracing.ps1" `
    -DataType "PowerShell" `
    -PromptTemplate "Documentation" `
    -OutputPath "./.claude/documentation.md"

Write-Host "✅ Complete prompt generation workflow executed!" -ForegroundColor Green
'@

Write-Host $workflowExample -ForegroundColor DarkCyan

# Tips section
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "📚 Tips & Best Practices" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

$tips = @"
1. **Data Type Detection**: Use -DataType "Auto" for automatic detection

2. **Token Management**: Set -MaxTokens appropriately for your AI model
   - Claude: 4000-8000 tokens
   - GPT-4: 8000-32000 tokens

3. **Context Preservation**: Include relevant context with -Context parameter
   - Environment details
   - Project constraints
   - Performance requirements

4. **Template Selection**:
   - Analysis: For understanding and insights
   - Implementation: For code generation
   - Conversion: For format/language transformation
   - Documentation: For creating docs
   - Testing: For test generation

5. **Chaining Operations**: Combine multiple scripts
   seq 0820,0830,0821  # Save context, generate prompt, create continuation

6. **Custom Templates**: Create domain-specific templates for repeated tasks

7. **Batch Processing**: Process multiple files with PowerShell pipelines

8. **Version Control**: Commit generated prompts for reproducibility

9. **CI/CD Integration**: Automate prompt generation on failures

10. **Interactive Refinement**: Use -Interactive for complex prompts
"@

Write-Host $tips -ForegroundColor Gray

Write-Host "`n✨ Ready to generate AI prompts from any structured data!" -ForegroundColor Green