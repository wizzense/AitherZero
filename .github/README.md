# GitHub Copilot Configuration for Aitherium Infrastructure Automation

This directory contains comprehensive GitHub Copilot configuration optimized for PowerShell automation development, OpenTofu infrastructure management, and Pester testing workflows.

## Repository Custom Instructions

### `copilot-instructions.md`
The main repository instruction file that provides Copilot with context about:
- Project architecture and standards
- PowerShell 7.0+ cross-platform requirements
- Module structure and dependencies
- Code generation patterns and best practices
- Infrastructure as Code standards
- Testing and quality assurance guidelines
- Security and compliance requirements

This file is automatically loaded by GitHub Copilot when working in this repository.

## Prompt Templates

### `prompts/powershell-development.md`
Specialized prompts for PowerShell development including:
- Module and function creation templates
- Configuration management patterns
- Environment setup procedures
- Performance optimization strategies
- Documentation and code review prompts

### `prompts/testing-quality.md`
Comprehensive testing prompts covering:
- Pester test development (unit, integration, performance)
- Mock strategy development
- Test data generation and fixtures
- Cross-platform testing approaches
- Security and error handling validation

### `prompts/infrastructure-code.md`
Infrastructure as Code focused prompts for:
- OpenTofu/Terraform resource configuration
- Module development and reusability
- State management and deployment pipelines
- Lab infrastructure and development environments
- Security and compliance frameworks

### `prompts/troubleshooting-debugging.md`
Diagnostic and troubleshooting prompts for:
- Error analysis and resolution
- Performance optimization
- Network and connectivity issues
- Infrastructure and security problems
- Logging and monitoring setup

## Personal Instructions

### `personal-copilot-instructions.md`
Personal preferences for:
- Communication style and explanation depth
- Code generation patterns and preferences
- Development workflow optimization
- Problem-solving approaches
- Focus areas for automation and infrastructure

## Usage Guidelines

### Setting Up Repository Instructions

1. **Automatic Loading**: The `copilot-instructions.md` file is automatically loaded when GitHub Copilot detects you're working in this repository.

2. **VS Code Integration**: The `.vscode/settings.json` file is configured to use these instruction files with the latest Copilot features.

3. **Verification**: Check if instructions are active by looking for the `.github/copilot-instructions.md` reference in Copilot Chat responses.

### Using Prompt Templates

1. **In Copilot Chat**: Reference specific prompts by mentioning the template name or concept.

2. **Custom Prompts**: Combine multiple prompt templates for complex scenarios.

3. **Context-Aware**: Prompts are designed to work with the repository structure and existing codebase.

### Personal Instructions Setup

1. **GitHub Web Interface**:
   - Go to https://github.com/copilot
   - Click the settings icon (⚙️)
   - Select "Personal instructions"
   - Copy content from `personal-copilot-instructions.md`

2. **Customization**: Modify the personal instructions based on your specific preferences and workflow.

## Advanced Features

### Repository Context Awareness
- Copilot understands the project's module structure
- Automatically suggests using existing modules instead of creating new functionality
- Provides context-appropriate code generation based on file location

### Cross-Platform Optimization
- All generated code follows PowerShell 7.0+ standards
- Path handling uses forward slashes for cross-platform compatibility
- Error handling and logging patterns are consistent across the project

### Testing Integration
- Test generation follows Pester 5.0+ patterns
- Mock strategies align with project testing framework
- Integration tests consider the modular architecture

### Infrastructure Focus
- OpenTofu/Terraform code follows HashiCorp best practices
- Resource naming and tagging conventions are enforced
- Security and compliance considerations are built into suggestions

## Best Practices

### Code Generation
1. **Always Review**: Copilot suggestions should be reviewed for project compliance
2. **Test Integration**: Verify generated code works with existing modules
3. **Documentation**: Ensure generated functions include proper help documentation
4. **Error Handling**: All code should include comprehensive error handling and logging

### Prompt Engineering
1. **Be Specific**: Use detailed prompts that reference project standards
2. **Provide Context**: Include information about the target environment and constraints
3. **Iterate**: Refine prompts based on the quality of generated responses
4. **Combine Templates**: Use multiple prompt templates for complex scenarios

### Maintenance
1. **Regular Updates**: Keep instructions current with project evolution
2. **Feedback Integration**: Incorporate lessons learned from development experience
3. **Team Alignment**: Ensure instructions reflect team coding standards
4. **Version Control**: Track changes to instructions for team consistency

## Troubleshooting

### Instructions Not Loading
- Verify file location: `.github/copilot-instructions.md`
- Check VS Code settings for instruction file paths
- Restart VS Code if changes aren't recognized
- Ensure GitHub Copilot extension is up to date

### Poor Code Quality
- Review and refine instruction specificity
- Check if generated code conflicts with existing patterns
- Consider adding more detailed examples to instructions
- Verify prompt templates are being used effectively

### Performance Issues
- Optimize instruction file size and complexity
- Reduce redundant or conflicting instructions
- Use specific, actionable guidance rather than general principles
- Consider breaking complex instructions into focused sections

## Contributing

### Improving Instructions
1. **Test Changes**: Validate instruction modifications with real development scenarios
2. **Document Rationale**: Explain why changes improve code generation quality
3. **Team Review**: Have instructions reviewed by other team members
4. **Incremental Updates**: Make small, focused changes rather than large rewrites

### Adding Prompts
1. **Follow Format**: Use consistent structure and formatting
2. **Practical Focus**: Ensure prompts solve real development challenges
3. **Context Awareness**: Design prompts to work with project architecture
4. **Documentation**: Include clear descriptions of prompt purpose and usage

This configuration provides a comprehensive foundation for AI-assisted development that aligns with project standards and accelerates development workflows while maintaining code quality and consistency.
