# Contributing to AitherZero

Thank you for your interest in contributing to AitherZero! This document provides guidelines and workflows for contributing to the project.

## Development Workflow

AitherZero uses a **protected main branch strategy** with `dev` as the primary integration branch.

### Branch Strategy

- **`main`** - Production branch. Protected. Only accepts PRs from `dev`. Triggers production releases.
- **`dev`** - Development/integration branch. Default branch for all feature PRs. All development happens here.
- **`feature/*`** - Feature branches created from `dev`
- **`fix/*`** - Bug fix branches created from `dev`
- **`docs/*`** - Documentation branches created from `dev`

### Workflow Steps

1. **Create a Feature Branch**
   ```bash
   # Using AitherZero automation (recommended)
   ./az.ps1 0701 -Type feature -Name "my-feature"
   
   # Or manually
   git checkout dev
   git pull origin dev
   git checkout -b feature/my-feature
   ```

2. **Make Your Changes**
   - Write code following project standards
   - Add tests for new functionality
   - Update documentation as needed
   - Run local validation:
     ```bash
     ./az.ps1 0407  # Syntax validation
     ./az.ps1 0402  # Unit tests
     ./az.ps1 0404  # Code quality analysis
     ```

3. **Commit Your Changes**
   ```bash
   # Using AitherZero automation (recommended)
   ./az.ps1 0702 -Type feat -Message "add new feature"
   
   # Or manually with conventional commits
   git add .
   git commit -m "feat: add new feature"
   ```

4. **Create a Pull Request to `dev`**
   ```bash
   # Using AitherZero automation (recommended)
   ./az.ps1 0703 -Title "Add new feature"
   
   # Or manually via GitHub CLI
   gh pr create --base dev --title "Add new feature"
   ```

5. **PR Review and Testing**
   - Automated CI/CD checks will run
   - Docker preview environment will be deployed for testing
   - Address any feedback from reviewers
   - Ensure all checks pass

6. **Merge to `dev`**
   - Once approved, PR will be merged to `dev`
   - Preview environment will be cleaned up
   - Changes are now in the integration branch

7. **Release to Production (Maintainers Only)**
   - When ready for release, create PR from `dev` to `main`
   - After approval, merge to `main`
   - Automatic production release will be triggered:
     - Docker container published with `latest` tag
     - GitHub Pages documentation deployed
     - Release notes generated (if tagged)

## Pull Request Guidelines

### PR Targeting

- **Default target**: `dev` branch (automatically set by `az.ps1 0703`)
- **Feature PRs**: Always target `dev`
- **Hotfix PRs**: Can target `main` with maintainer approval (emergency fixes only)

### PR Checklist

Before submitting a PR, ensure:

- [ ] Code follows PowerShell best practices
- [ ] All tests pass (`./az.ps1 0402`)
- [ ] Code quality checks pass (`./az.ps1 0404`)
- [ ] Documentation is updated
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] PR description clearly explains the changes

### PR Preview Environments

All PRs to `dev` or `main` automatically get:
- Docker container preview deployment
- Automated validation and testing
- Code quality reports
- Test coverage reports

Production deployments (GitHub Pages, official releases) only happen from `main`.

## Testing Requirements

### Local Testing

Before pushing, run:

```bash
# Quick validation
./az.ps1 0407          # Syntax check

# Full validation
./az.ps1 0402          # Unit tests
./az.ps1 0404          # PSScriptAnalyzer
./az.ps1 0420 -Path <file>  # Quality validation
```

### CI/CD Testing

All PRs automatically run:
- Syntax validation
- Unit tests
- Integration tests (where applicable)
- Code quality analysis
- Security scanning

## Code Standards

### PowerShell Style Guide

- Use approved PowerShell verbs (`Get-Verb` to check)
- Follow consistent naming conventions
- Use proper error handling with try/catch
- Include Write-CustomLog for logging
- Support cross-platform execution (Windows/Linux/macOS)
- Use `[CmdletBinding()]` for all functions

### Documentation

- Add comment-based help for all functions
- Update README.md if adding major features
- Update FUNCTIONALITY-INDEX.md for new functions
- Keep inline comments minimal but meaningful

### Testing

- Add Pester tests for new functionality
- Maintain or improve test coverage
- Test on multiple platforms when possible

## Release Process (Maintainers)

### Creating a Release

1. **Prepare `dev` branch**
   - Ensure all features are tested and working
   - Update VERSION file if needed
   - Update CHANGELOG (if applicable)

2. **Create Release PR**
   ```bash
   git checkout dev
   git pull origin dev
   gh pr create --base main --title "Release v1.x.x"
   ```

3. **Review and Merge**
   - Full test suite runs automatically
   - Review all changes since last release
   - Merge to `main`

4. **Automatic Release** (triggered by merge to main)
   - Docker container built and pushed as `latest`
   - GitHub Pages documentation deployed
   - If tagged, GitHub release created

5. **Tag Release** (optional, for versioned releases)
   ```bash
   git checkout main
   git pull origin main
   git tag -a v1.x.x -m "Release v1.x.x"
   git push origin v1.x.x
   ```

### Emergency Hotfixes

For critical production issues:

1. Create hotfix branch from `main`
2. Make minimal fix
3. Create PR targeting `main` (requires maintainer approval)
4. After merge, backport to `dev`:
   ```bash
   git checkout dev
   git merge main
   git push origin dev
   ```

## Getting Help

- **Issues**: Create an issue for bugs, features, or questions
- **Discussions**: Use GitHub Discussions for general questions
- **Documentation**: Check the [FUNCTIONALITY-INDEX.md](FUNCTIONALITY-INDEX.md)
- **Quick Reference**: See [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

## Code of Conduct

- Be respectful and constructive
- Focus on the code, not the person
- Accept constructive criticism gracefully
- Help others learn and grow

## License

By contributing to AitherZero, you agree that your contributions will be licensed under the project's [LICENSE](LICENSE).
