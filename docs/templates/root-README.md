# Template Files

This directory contains reusable template files for the AitherZero project.

## Available Templates

### `copilot-instructions-template.md`

A comprehensive template for creating GitHub Copilot coding agent instructions for any repository.

**Purpose**: Guide AI coding agents on how to work efficiently with a codebase by providing:
- Project overview and architecture
- Exact build, test, and validation commands with timing
- Common patterns and file locations
- Known issues and workarounds
- Quality validation checklists

**How to Use This Template**:

1. **Copy to your repository**:
   ```bash
   cp templates/copilot-instructions-template.md /path/to/your/repo/.github/copilot-instructions.md
   ```

2. **Customize the following sections**:
   - **Project Overview**: Update with your project's description, size, languages, frameworks
   - **Build, Test, and Validation Commands**: Replace with your project's actual commands
   - **Project Layout**: Update directory structure and file locations
   - **Configuration Files**: Document your config files and settings
   - **Key Source Files**: Identify main entry points and critical modules
   - **Known Issues**: List any expected test failures or linter warnings
   - **Timing Expectations**: Test and document actual command execution times

3. **Test all documented commands**:
   - Run each command in a clean environment
   - Document the exact order of execution
   - Record actual timing (use `time` command)
   - Note any prerequisites or dependencies
   - Document errors encountered and solutions

4. **Validate completeness**:
   - Ensure commands work in CI/CD environment
   - Verify all file paths are absolute or relative from repo root
   - Check that common workflows are documented
   - Add troubleshooting for known issues
   - Include performance expectations

5. **Keep up to date**:
   - Update when project structure changes
   - Revise timing as codebase grows
   - Add new patterns and common mistakes
   - Document new CI/CD workflows

**Template Structure**:

The template is organized into these main sections:

1. **Project Overview** - High-level description and statistics
2. **Essential Architecture Understanding** - Core concepts and patterns
3. **Build, Test, and Validation Commands** - Exact command sequences with timing
4. **Project Layout and Architecture** - Directory structure and key files
5. **Critical Development Patterns** - Common issues and solutions
6. **Key Commands & Workflows** - Frequently used operations
7. **Configuration System** - How config is managed
8. **Common Issues & Solutions** - Known problems and fixes
9. **Acceptance Criteria** - Quality requirements for PRs
10. **Quick Reference Summary** - Copy-paste commands and checklists

**Benefits of Using This Template**:

- ✅ Reduces time agents spend exploring codebase
- ✅ Prevents common build/test failures
- ✅ Documents exact command sequences that work
- ✅ Captures timing expectations for long operations
- ✅ Lists known issues to ignore
- ✅ Provides troubleshooting for common errors
- ✅ Establishes quality standards upfront

**Example Projects Using This Template**:

- AitherZero (this project) - PowerShell infrastructure automation platform
- *(Add your projects here as you use the template)*

## Contributing

When adding new templates:

1. Create the template file in this directory
2. Document it in this README
3. Include usage instructions
4. Provide examples of customization
5. List benefits and use cases

## Template Maintenance

Templates should be reviewed and updated:

- When project structure changes significantly
- When new best practices emerge
- When feedback indicates missing information
- Quarterly as part of regular maintenance

---

**Note**: Templates are starting points. Always customize them thoroughly for your specific project needs.
