# GitHub Copilot Configuration for AitherZero
# This file configures GitHub Copilot for optimal performance with the AitherZero platform

# ===================================================================
# COPILOT CHAT CONFIGURATIONS
# ===================================================================

# Project Context Instructions
@workspace /explain Explain this AitherZero component and its role in the infrastructure automation platform
@workspace /review Review this PowerShell code for AitherZero best practices and domain architecture compliance
@workspace /test Generate comprehensive Pester tests for this AitherZero module following the existing test patterns
@workspace /docs Generate documentation for this AitherZero component following the project's documentation standards
@workspace /fix Fix this PowerShell script to align with AitherZero coding standards and PSScriptAnalyzer rules

# Domain-Specific Shortcuts
@domains /infrastructure Explain infrastructure automation patterns in AitherZero domains
@domains /ai-agents Discuss AI agent integration and orchestration workflows
@domains /configuration Review configuration management and hierarchical loading
@domains /security Analyze security implementation and credential management
@domains /automation Examine orchestration engine and parallel execution patterns

# Common Workflow Commands
@az /script Generate a new automation script following the AitherZero numbering convention (0000-9999)
@az /module Create a new domain module with proper PowerShell structure and exports
@az /test Generate unit tests for the specified module or function
@az /playbook Create an orchestration playbook for the specified workflow

# ===================================================================
# POWERSHELL-SPECIFIC PROMPTS
# ===================================================================

# Code Quality Prompts
@quality /analyzer Review this code against PSScriptAnalyzer rules used in AitherZero
@quality /performance Optimize this PowerShell code for better performance and memory usage
@quality /security Review this code for security vulnerabilities and credential exposure
@quality /compatibility Ensure this PowerShell code works across Windows, Linux, and macOS

# AitherZero Architecture Prompts  
@architecture /modules Explain how this fits into the AitherZero domain module system
@architecture /loading Review the module loading sequence and dependencies
@architecture /logging Implement proper logging using Write-CustomLog pattern
@architecture /config Implement configuration loading following the hierarchical pattern

# ===================================================================
# INFRASTRUCTURE AS CODE PROMPTS
# ===================================================================

# OpenTofu/Terraform
@iac /tofu Generate OpenTofu configuration for this infrastructure component
@iac /terraform Convert this Terraform to OpenTofu format
@iac /validate Review this infrastructure code for best practices and security

# Automation Scripts
@automation /deploy Generate deployment automation for this component
@automation /parallel Design parallel execution strategy for these scripts
@automation /orchestration Create orchestration workflow for this automation sequence

# ===================================================================
# TESTING & QUALITY ASSURANCE
# ===================================================================

# Test Generation
@test /pester Generate comprehensive Pester tests following AitherZero patterns
@test /integration Create integration tests for this domain module
@test /mock Generate mock objects for external dependencies
@test /coverage Analyze test coverage and suggest additional test cases

# Code Analysis  
@analyze /complexity Review code complexity and suggest simplification
@analyze /dependencies Analyze module dependencies and potential circular references
@analyze /patterns Review adherence to AitherZero coding patterns and conventions

# ===================================================================
# DOCUMENTATION PROMPTS
# ===================================================================

# Documentation Generation
@docs /readme Generate comprehensive README for this component
@docs /help Create PowerShell comment-based help for this function
@docs /api Document the API interface for this module
@docs /architecture Document the architectural decisions and patterns

# ===================================================================
# GIT & WORKFLOW PROMPTS
# ===================================================================

# Git Workflow
@git /commit Generate conventional commit message for these changes
@git /branch Suggest appropriate branch name for this feature/fix
@git /pr Create pull request description for these changes
@git /changelog Generate changelog entries for this release

# ===================================================================
# AI AGENT INTEGRATION PROMPTS  
# ===================================================================

# Multi-AI Workflows
@ai /claude Configure Claude integration for code review and analysis
@ai /gemini Setup Gemini for code generation and optimization
@ai /codex Implement OpenAI Codex integration for documentation
@ai /orchestrate Design multi-AI workflow for this development task

# AI Context Management
@context /index Update AI context with current project state
@context /compress Optimize AI context for better token efficiency
@context /exclude Configure AI context exclusion patterns
@context /include Define important files for AI context inclusion

# ===================================================================
# PLATFORM-SPECIFIC PROMPTS
# ===================================================================

# Cross-Platform Development
@platform /windows Implement Windows-specific functionality
@platform /linux Implement Linux-specific functionality
@platform /macos Implement macOS-specific functionality
@platform /cross Design cross-platform compatible solution

# Environment Management
@env /dev Configure development environment setup
@env /ci Configure CI/CD pipeline integration
@env /prod Implement production deployment considerations
@env /test Setup testing environment configuration

# ===================================================================
# COPILOT WORKSPACE INSTRUCTIONS
# ===================================================================

# Tell Copilot about our project structure
Copilot: This is the AitherZero infrastructure automation platform with the following key characteristics:

1. **Number-Based Script System**: Scripts in automation-scripts/ follow 0000-9999 numbering
2. **Domain Architecture**: Consolidated modules in domains/ directory (infrastructure, ai-agents, configuration, etc.)
3. **PowerShell-First**: Cross-platform PowerShell 7+ with specific coding patterns
4. **AI Integration**: Multi-AI orchestration with Claude, Gemini, OpenAI, and GitHub Copilot
5. **Module Loading**: Hierarchical loading through AitherZero.psd1 manifest
6. **Configuration**: Hierarchical .psd1 configuration with environment overrides
7. **Testing**: Pester-based testing with domain-specific test organization
8. **Logging**: Centralized logging using Write-CustomLog pattern
9. **Cross-Platform**: Windows, Linux, macOS compatibility with platform checks

Key Patterns to Follow:
- Use Write-CustomLog instead of Write-Host for output
- Implement [CmdletBinding()] for advanced functions
- Check platform variables ($IsWindows, $IsLinux, $IsMacOS)
- Follow hierarchical configuration loading pattern
- Use Export-ModuleMember for module exports
- Implement proper error handling with try/catch
- Use approved PowerShell verbs (Get-Verb to check)
- Include comment-based help for functions
- Support -WhatIf and -Confirm for state-changing functions