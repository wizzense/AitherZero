# Aitherium Infrastructure Automation - GitHub Copilot Instructions

This project is a **PowerShell-based infrastructure automation framework** using OpenTofu/Terraform for lab environments. Follow these instructions when generating code or providing assistance.

## Core Standards & Requirements

**PowerShell Version**: Always use PowerShell 7.0+ features and cross-platform compatible syntax.

**Path Handling**: Use forward slashes (`/`) for all file paths to ensure cross-platform compatibility.

**Code Style**: Follow One True Brace Style (OTBS) with consistent indentation and spacing.

**Module Architecture**: Import modules from `aither-core/modules` using `Import-Module` with `-Force` parameter.

**Error Handling**: Always implement comprehensive try-catch blocks with detailed logging using the `Logging` module.

**Testing**: Use Pester 5.0+ with the project's testing framework from `TestingFramework` module.

## Project Modules & Their Purposes

Use these existing modules instead of creating new functionality:

- **BackupManager**: File backup, cleanup, and consolidation operations
- **DevEnvironment**: Development environment preparation and validation
- **LabRunner**: Lab automation orchestration and test execution coordination
- **Logging**: Centralized logging with levels (INFO, WARN, ERROR, SUCCESS)
- **ParallelExecution**: Runspace-based parallel task execution
- **PatchManager**: NEW CONSOLIDATED VERSION - 4 core functions: Invoke-PatchWorkflow, New-PatchIssue, New-PatchPR, Invoke-PatchRollback. Legacy functions archived.
- **ScriptManager**: Script repository management and template handling
- **TestingFramework**: Pester test wrapper with project-specific configurations
- **UnifiedMaintenance**: Unified entry point for all maintenance operations

## Code Generation Patterns

**Function Structure**: Use `[CmdletBinding(SupportsShouldProcess)]` with proper parameter validation and begin/process/end blocks.

**Parameter Validation**: Always include `[ValidateNotNullOrEmpty()]` and appropriate validation attributes.

**Logging Integration**: Use `Write-CustomLog -Level 'LEVEL' -Message 'MESSAGE'` for all logging operations.

**Cross-Platform Paths**: Use `Join-Path` and avoid hardcoded Windows-style paths.

**Module Dependencies**: Reference existing modules rather than reimplementing functionality.

## Infrastructure as Code Standards

**OpenTofu/Terraform**: Use HCL syntax with proper variable definitions and output declarations.

**Resource Naming**: Follow consistent naming conventions with environment prefixes.

**State Management**: Always consider remote state and workspace isolation.

**Security**: Never hardcode credentials; use variable files and secure practices.

## Testing & Quality Assurance

**Pester Tests**: Create comprehensive test suites with Describe-Context-It structure.

**Mock Strategy**: Use proper mocking for external dependencies and file system operations.

**Code Coverage**: Aim for high test coverage with meaningful assertions.

**Integration Tests**: Include end-to-end testing scenarios for critical workflows.

## Security & Best Practices

**Credential Handling**: Use secure strings and credential objects, never plain text passwords.

**Input Validation**: Validate all user inputs and external data sources.

**Least Privilege**: Follow principle of least privilege for all operations.

**Audit Logging**: Log all significant operations for security and troubleshooting.

## Advanced Copilot Features

**Context Awareness**: Leverage repository-specific instructions to provide context-aware suggestions.

**Prompt Integration**: Use specialized prompt templates for PowerShell development, testing, infrastructure, and troubleshooting.

**Code Review Assistance**: Generate code that adheres to project standards and includes inline comments for clarity.

**Documentation Generation**: Automatically include detailed help documentation for all functions and modules.

**Performance Optimization**: Suggest improvements for parallel execution, memory efficiency, and large dataset handling.

**Error Diagnosis**: Provide troubleshooting steps and common resolutions for errors encountered during development.

**Architecture Awareness**: Follow advanced architecture patterns from `instructions/advanced-architecture.instructions.md` including:
- Shared utilities integration (Find-ProjectRoot, etc.)
- Dynamic repository detection and cross-fork operations
- PatchManager v2.1 single-step workflows
- Bulletproof testing integration
- VS Code task creation patterns
- Comprehensive error handling and logging standards

## Collaboration and Feedback

**Team Standards**: Ensure generated code aligns with team coding standards and practices.

**Feedback Loop**: Continuously refine instructions based on team feedback and project evolution.

**Version Control**: Track changes to instructions and prompt templates to maintain consistency across the team.

**Training and Onboarding**: Use Copilot to assist new team members in understanding project architecture and standards.

When suggesting code changes or new features, always consider how they integrate with existing modules and follow these established patterns.
