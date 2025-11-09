# AitherZero MCP Server Changelog

## [2.0.0] - 2025-11-09

### 🚀 Major Release - Complete Modernization

This release completely modernizes the AitherZero MCP server to align with AitherZero v2.0 architecture and GitHub Copilot agent mode best practices.

### Breaking Changes

#### Path Updates
- **Script location**: `automation-scripts/` → `library/automation-scripts/` (880+ scripts)
- **Domain location**: `domains/` → `aithercore/` (11 functional domains)
- **Quality check default**: `./domains` → `./aithercore`

#### Function Name Changes
- **Configuration**: `Get-AitherConfiguration` → `Get-Configuration`
- **Script execution**: `Start-AitherZero.ps1 -Mode Run` → `Invoke-AitherScript`
- **Script listing**: `Start-AitherZero.ps1 -Mode List` → `Get-AitherScript`
- **Playbook execution**: `Start-AitherZero.ps1 -Mode Orchestrate` → `Invoke-AitherPlaybook`

### Added Features

#### New Tools (6 total, 8 → 14)
1. **`list_playbooks`** - List available orchestration playbooks
2. **`get_domain_info`** - Get information about aithercore functional domains
3. **`list_extensions`** - List installed AitherZero extensions
4. **`get_workflow_status`** - Get GitHub Actions workflow status
5. **`generate_documentation`** - Generate/update module documentation
6. **Enhanced `get_configuration`** - Now supports section and key parameters

#### New Resources (2 total, 3 → 5)
1. **`aitherzero://playbooks`** - Available orchestration playbooks
2. **`aitherzero://domains`** - Aithercore domain structure and information

#### New Prompts (4 total, 0 → 4) - NEW CAPABILITY
1. **`setup-dev-environment`** - Guided development environment setup
2. **`validate-code-quality`** - Step-by-step quality validation workflow
3. **`create-pr`** - Pull request creation workflow
4. **`troubleshoot-ci`** - CI/CD failure diagnosis and remediation

### Improved Features

#### Enhanced Tool Descriptions
- All tool descriptions optimized for GitHub Copilot agent mode
- Better parameter documentation with examples
- Usage patterns aligned with common automation tasks

#### Better Error Handling
- Structured error responses with context
- Non-interactive mode support to prevent blocking
- Improved PowerShell execution error capture

#### Extended Capabilities
- Support for 880+ automation scripts (was ~125)
- Integration with 11 aithercore functional domains
- Extension system support (8000-8999 script range)
- GitHub workflow integration via `gh` CLI
- Playbook orchestration with profiles

### Updated Infrastructure

#### Configuration
- Added `AITHERZERO_NONINTERACTIVE` environment variable support
- Updated `.github/mcp-servers.json` to include aitherzero server
- Set aitherzero as default MCP server
- Updated context providers for aithercore and library paths

#### Documentation
- Complete README.md rewrite
- New USAGE.md with comprehensive examples
- Updated COPILOT-MCP-SETUP.md for v2.0
- Added CHANGELOG.md (this file)

#### Package Management
- Updated package.json to v2.0.0
- Added "github-copilot" and "agent-mode" keywords
- Enhanced description

### GitHub Copilot Integration

#### Agent Mode Optimization
- Tool descriptions optimized for autonomous operation
- Resources provide extended context for decision-making
- Prompts enable guided multi-step workflows
- Aligned with GitHub's MCP best practices

#### Best Practices Implementation
- **Extended Context**: 5 resources provide comprehensive system state
- **Reduced Manual Effort**: 14 tools automate common tasks
- **Seamless Integration**: Works across multiple tools without custom integrations
- **Security**: OAuth support, minimal permissions, non-interactive mode

### Migration Guide

#### For Existing Users

1. **Update repository structure awareness**:
   ```typescript
   // Old
   './domains/configuration'
   
   // New
   './aithercore/configuration'
   ```

2. **Update PowerShell cmdlet calls**:
   ```typescript
   // Old
   Get-AitherConfiguration -Key 'Core.Profile'
   
   // New
   Get-Configuration -Section 'Core' -Key 'Profile'
   ```

3. **Rebuild MCP server**:
   ```bash
   cd integrations/mcp-server
   rm -rf node_modules dist
   npm install
   npm run build
   ```

4. **Restart GitHub Copilot** in VS Code to reload the server

#### For New Users

1. Ensure AitherZero v2.0+ is installed
2. Run `./bootstrap.ps1 -Mode Update`
3. Build MCP server: `cd integrations/mcp-server && npm install && npm run build`
4. Open workspace in VS Code - Copilot auto-loads the server

### Testing

- ✅ TypeScript compilation successful
- ✅ Server starts and lists tools correctly
- ✅ Basic stdio communication working
- ⏳ Manual validation with GitHub Copilot (user testing required)
- ⏳ End-to-end testing of all 14 tools (user testing required)
- ⏳ Prompt workflow validation (user testing required)

### Known Issues

None reported at release time.

### Future Enhancements

Planned for future versions:
- Sampling support for long-running operations
- Custom tool parameters validation
- Enhanced error recovery
- Performance metrics collection
- Webhook integration for real-time updates

---

## [0.1.0] - 2024 (Initial Release)

### Initial Features

- 8 basic tools for infrastructure automation
- 3 resources (config, scripts, project-report)
- Support for 0000-9999 automation scripts
- Basic GitHub Copilot integration
- stdio transport protocol

### Tools (Initial 8)
1. run_script
2. list_scripts
3. search_scripts
4. execute_playbook
5. get_configuration
6. run_tests
7. run_quality_check
8. get_project_report

---

**Legend**:
- 🚀 Major Release
- ✨ New Feature
- 🐛 Bug Fix
- 📝 Documentation
- ⚡ Performance
- 🔒 Security
- ⚠️ Breaking Change
