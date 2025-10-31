# VS Code Configuration for OpenTofu Lab Automation

This directory contains optimized VS Code workspace configuration specifically tailored for PowerShell automation development, Pester testing, and OpenTofu infrastructure management with enhanced GitHub Copilot integration.

## Files Overview

### Core Configuration Files

#### `settings.json`

Comprehensive workspace settings optimized for:

- **GitHub Copilot Instructions**: Latest instruction file system with automatic detection
- **Custom Instructions**: Task-specific instructions for code generation, testing, and reviews
- **Prompt Files**: Reusable prompts stored in `.github/prompts/` directory
- **PowerShell Development**: Formatting, analysis, and cross-platform compatibility
- **Pester Testing**: Test discovery, execution, and reporting
- **OpenTofu/Terraform**: Infrastructure as code support

Key Copilot features enabled:
- `github.copilot.chat.codeGeneration.useInstructionFiles: true`
- `chat.promptFiles: true`
- Automatic instruction file detection from `.github/instructions/`
- Custom prompt files in `.github/prompts/`

#### `tasks.json`

Predefined tasks for common development operations:

- `Run All Pester Tests`: Execute the complete test suite
- `Run Specific Module Tests`: Test individual modules
- `PowerShell Script Analysis`: Static code analysis
- `Setup Development Environment`: Initialize the development environment
- `Import All Modules`: Load all project modules
- `OpenTofu Plan/Apply`: Infrastructure deployment tasks
- `Generate Test Report`: Create detailed test reports
- `Clean Test Results`: Remove test artifacts
- `Validate All Module Manifests`: Check module integrity

#### `launch.json`

Debug configurations for:

- **Current File**: Debug the currently open PowerShell file
- **Pester Tests**: Debug test execution
- **Specific Module**: Debug individual modules with input prompts
- **Core Runner**: Debug the main automation framework
- **Test Environment**: Debug environment setup

#### `extensions.json`

Recommended extensions for optimal development experience:

- PowerShell development tools
- GitHub Copilot and AI assistance
- Testing frameworks (Pester)
- Infrastructure as code (Terraform/OpenTofu)
- Code quality and analysis tools
- Git and version control enhancements
- Productivity and UI improvements

### Copilot Enhancement Files

#### `copilot-instructions.md`

Comprehensive instructions for GitHub Copilot including:

- Project overview and standards
- PowerShell 7.0+ cross-platform requirements
- Module and function structure guidelines
- Logging and error handling standards
- Testing and security considerations
- Code review and quality guidelines

#### Specialized Prompt Files

**`prompts-powershell.md`**

- Module development prompts
- Function implementation templates
- Configuration and environment setup
- Performance optimization guidance
- Documentation and security review prompts

**`prompts-pester.md`**

- Comprehensive test suite generation
- Mock strategy development
- Performance and cross-platform testing
- Test data and fixture management
- Integration testing strategies

**`prompts-review.md`**

- Code review and quality analysis
- Security and performance assessment
- Architecture and standards compliance
- Dependency and error handling analysis
- Refactoring recommendations

**`prompts-troubleshooting.md`**

- Error diagnosis and resolution
- Module loading and configuration issues
- Performance and compatibility problems
- Network, file system, and security troubleshooting

### Code Snippets

#### `snippets/powershell.json`

Ready-to-use PowerShell code snippets:

- Function templates with project standards
- Module manifest boilerplate
- Pester test structures
- Error handling patterns
- Parameter validation
- Cross-platform utilities
- Logging implementations

## Key Features

### GitHub Copilot Optimizations

1. **Custom Instructions**: Tailored to project coding standards and cross-platform requirements
2. **Specialized Prompts**: Pre-built prompts for common development scenarios
3. **Advanced Settings**: Optimized temperature, length, and stop sequences for PowerShell
4. **Context-Aware**: Instructions adapt to different development contexts (testing, review, troubleshooting)

### PowerShell Development

1. **Cross-Platform Standards**: Enforced forward slash paths and PowerShell 7.0+ compatibility
2. **Code Formatting**: OTBS (One True Brace Style) with consistent spacing and indentation
3. **Static Analysis**: Integrated PSScriptAnalyzer with project-specific settings
4. **Module Management**: Simplified import and validation workflows

### Testing Infrastructure

1. **Pester Integration**: Optimized for Pester 5.0+ with proper configuration
2. **Test Discovery**: Automatic test file detection and organization
3. **Debugging Support**: Debug configurations for test execution and analysis
4. **Report Generation**: Automated test reporting and result management

### Infrastructure as Code

1. **OpenTofu Support**: Tasks and configurations for infrastructure management
2. **Terraform Integration**: HCL syntax support and formatting
3. **Plan/Apply Workflows**: Streamlined deployment processes

## Usage Guidelines

### Getting Started

1. **Install Recommended Extensions**: Use the Command Palette (`Ctrl+Shift+P`) and run "Extensions: Show Recommended Extensions"
2. **Configure Environment**: Run the "Setup Development Environment" task
3. **Import Modules**: Use the "Import All Modules" task to load project modules
4. **Run Tests**: Execute "Run All Pester Tests" to validate the environment

### Development Workflow

1. **Use Copilot Prompts**: Reference the prompt files for consistent code generation
2. **Follow Standards**: Adhere to the PowerShell 7.0+ cross-platform guidelines
3. **Test Continuously**: Run relevant tests as you develop
4. **Debug Effectively**: Use the provided debug configurations

### Best Practices

1. **Cross-Platform**: Always use forward slashes for paths
2. **Error Handling**: Implement comprehensive try-catch blocks with logging
3. **Parameter Validation**: Use validation attributes for all function parameters
4. **Documentation**: Include proper help documentation for all functions
5. **Testing**: Write comprehensive Pester tests for all functionality

### Testing Instruction Files

Run the "🔍 Test Copilot Instructions Setup" task to verify your instruction files are properly configured and detected by VS Code.

### Using Prompt Files

In VS Code chat:
- Type `/create-powershell-function` to generate functions following project standards
- Type `/run-bulletproof-tests` for testing guidance
- Use Command Palette: "Chat: Run Prompt" to browse all available prompts

### Custom Instructions

Instructions are automatically applied based on file patterns:
- **All .ps1 files**: Module guidelines and PowerShell standards
- **Test files**: Testing workflows and Pester patterns
- **Code generation**: Project-specific coding standards

## Customization

### Adding New Prompts

Create new prompt files in the `.vscode` directory following the existing pattern:

- Use descriptive headings
- Include specific, actionable instructions
- Provide context about the project structure
- Follow the established formatting conventions

### Modifying Settings

When updating `settings.json`:

- Maintain the existing structure and categories
- Test changes with the development workflow
- Document significant modifications
- Consider cross-platform compatibility

### Creating New Tasks

When adding tasks to `tasks.json`:

- Use descriptive labels and groups
- Include appropriate problem matchers
- Configure presentation options for optimal UX
- Test task execution in different scenarios

## Troubleshooting

### Common Issues

1. **Extension Conflicts**: Check for conflicting extensions and disable as needed
2. **PowerShell Version**: Ensure PowerShell 7.0+ is installed and configured
3. **Module Loading**: Verify module paths and permissions
4. **Test Failures**: Check Pester configuration and test file paths

### Instructions Not Loading
- Verify `github.copilot.chat.codeGeneration.useInstructionFiles` is set to `true`
- Check that instruction files exist in `.github/instructions/`
- Run "🔍 Test Copilot Instructions Setup" task to validate file presence
- Restart VS Code if changes aren't recognized
- Ensure GitHub Copilot extension is up to date

### Prompt Files Not Working
- Verify `chat.promptFiles` is set to `true`
- Check that prompt files have `.prompt.md` extension
- Ensure prompt files are in `.github/prompts/` directory
- Validate front matter syntax in prompt files

### Support Resources

- Project documentation in the `docs/` directory
- Test configuration in `tests/config/`
- Module examples in `core-runner/modules/`
- Troubleshooting scripts in the project root

## Maintenance

### Regular Updates

1. **Extension Updates**: Keep recommended extensions current
2. **Setting Reviews**: Periodically review and optimize settings
3. **Prompt Refinement**: Update prompts based on development experience
4. **Task Optimization**: Improve task performance and reliability

### Version Control

- Include all `.vscode` files in version control
- Document significant configuration changes
- Share improvements with the development team
- Maintain consistency across development environments

This configuration setup provides a comprehensive, optimized development environment for PowerShell automation, testing, and infrastructure management with enhanced AI assistance through GitHub Copilot.
