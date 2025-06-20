---
mode: 'agent'
tools: ['codebase']
description: 'Generate a PowerShell function following project standards'
---

Generate a PowerShell function that follows the Aitherium Infrastructure Automation project standards.

Requirements:
- Use PowerShell 7.0+ cross-platform syntax
- Include `[CmdletBinding(SupportsShouldProcess)]` pattern
- Add comprehensive parameter validation with `[ValidateNotNullOrEmpty()]`
- Implement begin/process/end blocks where appropriate
- Use `Write-CustomLog` for all logging operations from the Logging module
- Include proper help documentation with examples
- Use forward slashes for all file paths
- Follow OTBS (One True Brace Style) formatting

Reference the project's module architecture from [modules.instructions.md](../instructions/modules.instructions.md).

If function name and parameters are not provided, ask for:
1. Function name (Verb-Noun format)
2. Primary parameters and their types
3. Function purpose and behavior
4. Any specific module dependencies

Generate complete function with:
- Proper comment-based help
- Parameter validation
- Error handling with try-catch
- Logging integration
- Cross-platform compatibility
