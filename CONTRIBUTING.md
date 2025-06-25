# Contributing to AitherZero

Welcome to AitherZero! We're excited that you're interested in contributing to our PowerShell infrastructure automation framework.

## 🚀 Quick Start for Contributors

### Prerequisites
- **PowerShell 7.0+** (cross-platform)
- **Git** for version control
- **GitHub CLI** (optional, for easier PR management)
- **OpenTofu/Terraform** (for infrastructure components)

### Getting Started
```powershell
# 1. Fork the repository on GitHub
# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/AitherZero.git
cd AitherZero

# 3. Set up the development environment
Import-Module './aither-core/modules/DevEnvironment' -Force
Initialize-DevEnvironment

# 4. Run tests to verify setup
pwsh -File './tests/Run-BulletproofValidation.ps1' -ValidationLevel 'Quick'
```

## 🛠️ Development Workflow

### Using PatchManager (Recommended)
AitherZero includes a sophisticated patch management system that automates much of the development workflow:

```powershell
# Start a new feature using PatchManager
Import-Module './aither-core/modules/PatchManager' -Force

# Create a feature with automatic issue tracking
Invoke-PatchWorkflow -PatchDescription "Add new module validation feature" -PatchOperation {
    # Your code changes here
    Write-Host "Implementing new feature..."
    # ... make your changes ...
} -CreatePR -TestCommands @("pwsh -File './tests/Run-BulletproofValidation.ps1' -ValidationLevel 'Quick'")
```

**PatchManager automatically handles:**
- ✅ Branch creation with descriptive names
- ✅ Issue creation and linking
- ✅ Commit management
- ✅ Pull request creation
- ✅ Test validation
- ✅ Clean working tree management

### Manual Git Workflow (Alternative)
If you prefer traditional Git workflows:

```powershell
# 1. Create a feature branch
git checkout -b feature/your-feature-name

# 2. Make your changes
# ... edit files ...

# 3. Test your changes
pwsh -File './tests/Run-BulletproofValidation.ps1' -ValidationLevel 'Standard'

# 4. Commit and push
git add .
git commit -m "feat: add your feature description"
git push origin feature/your-feature-name

# 5. Create PR on GitHub
gh pr create --title "Add your feature" --body "Description of changes"
```

## 📋 Types of Contributions

### 🐛 Bug Fixes
- Use branch prefix: `fix/` or `hotfix/`
- Include issue reference in commit message
- Add or update tests to prevent regression

### ✨ New Features
- Use branch prefix: `feature/`
- Update documentation and tests
- Consider impact on existing modules

### 📚 Documentation
- Use branch prefix: `docs/`
- Update relevant README files
- Include examples where helpful

### 🧪 Tests
- Use branch prefix: `test/`
- Follow existing test patterns
- Ensure tests are cross-platform compatible

### 🔧 Infrastructure
- Use branch prefix: `ci/` or `infra/`
- Test changes across multiple platforms
- Update relevant workflow documentation

## 📝 Coding Standards

### PowerShell Guidelines
- **PowerShell 7.0+ syntax** - Use modern, cross-platform features
- **Forward slashes** for paths (`/` not `\`) for cross-platform compatibility
- **One True Brace Style (OTBS)** for consistent formatting
- **Comprehensive error handling** with try-catch blocks
- **Descriptive function names** using approved PowerShell verbs

### Module Architecture
```powershell
# Import project modules using standard pattern
Import-Module './aither-core/modules/ModuleName' -Force

# Use project logging consistently
Write-CustomLog -Level 'INFO' -Message "Operation completed successfully"

# Follow error handling patterns
try {
    # Operations here
    Write-CustomLog -Level 'INFO' -Message "Operation started"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
    throw
}
```

### File Organization
- **Modules**: Place in `aither-core/modules/ModuleName/`
- **Tests**: Corresponding tests in `tests/unit/modules/ModuleName/`
- **Documentation**: Update relevant files in `docs/`
- **Scripts**: Utility scripts in `aither-core/scripts/`

## 🧪 Testing Requirements

### Required Test Coverage
All contributions must include appropriate tests:

```powershell
# Run quick validation during development
pwsh -File './tests/Run-BulletproofValidation.ps1' -ValidationLevel 'Quick'

# Run comprehensive tests before PR
pwsh -File './tests/Run-BulletproofValidation.ps1' -ValidationLevel 'Complete'

# Test specific modules
Invoke-Pester -Path "./tests/unit/modules/YourModule" -Output Detailed
```

### Test Categories
- **Unit Tests**: Test individual functions in isolation
- **Integration Tests**: Test module interactions
- **Cross-Platform Tests**: Verify Windows/Linux/macOS compatibility
- **Performance Tests**: Ensure scalability (for core components)

## 📖 Documentation Standards

### Function Documentation
```powershell
<#
.SYNOPSIS
Brief description of the function

.DESCRIPTION
Detailed description of what the function does

.PARAMETER ParameterName
Description of the parameter

.EXAMPLE
Example-Function -Parameter "value"
Description of what this example does

.NOTES
Any additional notes or requirements
#>
function Example-Function {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Parameter
    )
    # Function implementation
}
```

### README Updates
When adding new modules or features:
1. Update the main README.md
2. Create/update module-specific README files
3. Include usage examples
4. Document any new dependencies

## 🎯 Pull Request Guidelines

### PR Checklist
- [ ] **Descriptive title** following conventional commits format
- [ ] **Clear description** of changes and motivation
- [ ] **Tests included** and passing
- [ ] **Documentation updated** for new features
- [ ] **Cross-platform compatibility** verified
- [ ] **No breaking changes** (or clearly documented)
- [ ] **Clean commit history** (squash if needed)

### PR Description Template
```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Cross-platform testing completed
- [ ] Manual testing performed

## Documentation
- [ ] README updated
- [ ] Function documentation complete
- [ ] Examples provided

## Breaking Changes
List any breaking changes and migration path
```

## 🏷️ Issue Labels and Projects

We use GitHub labels to categorize issues:

- `good first issue` - Perfect for new contributors
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements or additions to docs
- `help wanted` - Extra attention is needed
- `question` - Further information is requested
- `priority: high` - Urgent issues
- `priority: medium` - Important but not urgent
- `priority: low` - Nice to have

## 🤝 Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Provide constructive feedback
- Help newcomers get started
- Follow GitHub's community guidelines

### Getting Help
- **Issues**: Create a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check existing docs and examples first

### Recognition
Contributors will be:
- Listed in project documentation
- Mentioned in release notes
- Invited to become maintainers (for significant contributions)

## 🚀 Advanced Contributing

### Becoming a Maintainer
Regular contributors may be invited to become maintainers with:
- Commit access to the repository
- Ability to review and merge PRs
- Input on project direction and roadmap

### Project Architecture
Understanding the project structure helps with larger contributions:
- **aither-core/**: Main framework modules
- **tests/**: Comprehensive testing framework
- **docs/**: Documentation and guides
- **opentofu/**: Infrastructure as Code components
- **.github/**: GitHub workflows and templates

Thank you for contributing to AitherZero! 🎉

## 📞 Contact

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and community chat
- **Project Maintainer**: [@wizzense](https://github.com/wizzense)
