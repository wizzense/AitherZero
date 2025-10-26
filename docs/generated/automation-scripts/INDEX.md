# Automation Scripts Index

AitherZero uses a number-based orchestration system (0000-9999) for systematic script execution.

## Script Categories

### Environment Setup (0000-0099)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 0000` | Clean up temporary files and prepare environment |  |
| `az 0001` | Ensure PowerShell 7 is installed and restart if needed |  |
| `az 0002` | Create required directories for infrastructure |  |
| `az 0006` | Install validation tools (PSScriptAnalyzer, Pester) |  |
| `az 0007` | Install Go programming language using package managers (winget priority) | development, go, golang, programming |
| `az 0008` | Install OpenTofu infrastructure as code tool |  |
| `az 0009` | Initialize OpenTofu in infrastructure directory | infrastructure, opentofu, terraform |

### Infrastructure (0100-0199)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 0100` | Configure system settings based on configuration |  |
| `az 0104` | Install and configure Certificate Authority | security, certificates, ca, infrastructure |
| `az 0105` | Enable Hyper-V virtualization feature on Windows |  |
| `az 0106` | Install Windows Admin Center for server management | management, infrastructure, windows, wac |
| `az 0106` | Install Windows Subsystem for Linux 2 with chosen distribution | infrastructure, wsl, linux, virtualization |
| `az 0112` | Configure firewall rules for PXE boot support |  |

### Development Tools (0200-0299)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 0201` | Install Node.js runtime using package managers (winget priority) |  |
| `az 0204` | Install Poetry package manager for Python |  |
| `az 0205` | Install Sysinternals utilities suite |  |
| `az 0206` | Install Python programming language using package managers (winget priority) | development, python, programming |
| `az 0207` | Install Git version control system using package managers (winget priority) |  |
| `az 0208` | Install Docker Desktop or Docker Engine using package managers (winget priority) | development, docker, containers, virtualization |
| `az 0209` | Install 7-Zip file archiver using package managers (winget priority) |  |
| `az 0210` | Install Visual Studio Code editor using package managers (winget priority) | development, editor, vscode, ide |
| `az 0211` | Install Visual Studio Build Tools |  |
| `az 0212` | Install Azure CLI for cloud management using package managers (winget priority) |  |
| `az 0213` | Install AWS CLI for cloud management |  |
| `az 0214` | Install HashiCorp Packer for machine image building |  |
| `az 0215` | Install Chocolatey package manager for Windows |  |
| `az 0216` | Configure PowerShell profile for AitherZero environment |  |
| `az 0217` | Install Claude Code CLI and dependencies |  |
| `az 0218` | Install Google Gemini CLI and dependencies |  |

### Testing & Validation (0400-0499)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 0400` | Install testing and validation tools for AitherZero |  |
| `az 0402` | Execute unit tests for AitherZero |  |
| `az 0403` | Execute integration tests for AitherZero |  |
| `az 0404` | Run PSScriptAnalyzer on AitherZero codebase | testing, code-quality, psscriptanalyzer, static-analysis |
| `az 0405` | Validate PowerShell Abstract Syntax Tree (AST) for AitherZero | testing, ast, syntax, validation |
| `az 0405` | Validates all PowerShell module manifest files in the project for Unicode and parsing issues |  |
| `az 0406` | Generate code coverage reports for AitherZero | testing, coverage, reporting, quality |
| `az 0407` | PowerShell syntax validation using AST parser | testing, validation, syntax, ast, quality |
| `az 0408` | Generate test coverage reports and baseline tests |  |
| `az 0409` | Execute all tests for AitherZero (unit, integration, E2E) |  |
| `az 0411` | Intelligent test runner with caching and incremental testing |  |
| `az 0440` | Validates GitHub Actions workflow files for syntax, schema compliance, and best practices |  |
| `az 0441` | Test GitHub Actions workflows locally using act or similar tools |  |
| `az 0442` | Install act for local GitHub Actions testing |  |
| `az 0443` | Installs the powershell-yaml module for YAML parsing capabilities |  |
| `az 0450` | Publishes test results to GitHub Pages for easy viewing |  |
| `az 0450` | High-performance parallel test execution optimized for AitherZero |  |
| `az 0460` | Orchestrated test execution using AitherZero's own automation capabilities |  |
| `az 0470` | Simple testing orchestrator that eliminates configuration complexity |  |
| `az 0480` | Ultra-simple, high-performance test runner for AitherZero |  |
| `az 0490` | AI-friendly test runner with intelligent automation and self-optimization |  |

### Reporting & Analytics (0500-0599)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 0500` | Validate environment setup and dependencies | validation, testing, health-check |
| `az 0501` | Gather and display comprehensive system information |  |
| `az 0510` | Generate comprehensive project status report including dependencies, tests, coverage, and documentation |  |
| `az 0511` | Display comprehensive project dashboard with logs, tests, and metrics |  |
| `az 0512` | Generate comprehensive CI/CD dashboard with real-time status monitoring |  |
| `az 0512` | Schedule automatic report generation for AitherZero project |  |
| `az 0513` | Enable continuous reporting and monitoring for development workflow |  |
| `az 0520` | Configuration usage analysis for tech debt reporting | reporting, tech-debt, configuration, analysis |
| `az 0520` | Deploy documentation and reports to GitHub Pages |  |
| `az 0521` | Documentation coverage analysis for tech debt reporting | reporting, tech-debt, documentation, analysis |
| `az 0522` | Code quality analysis for tech debt reporting | reporting, tech-debt, code-quality, analysis |
| `az 0523` | Security issue analysis for tech debt reporting | reporting, tech-debt, security, analysis |
| `az 0524` | Tech debt report generation from modular analysis results | reporting, tech-debt, aggregation |
| `az 0530` | View and manage AitherZero logs |  |
| `az 0599` | Enhanced CI progress reporting with real-time updates |  |

### Git & AI Tools (0700-0799)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 0700` | Set up Git environment with best practices |  |
| `az 0701` | Create a feature branch with conventional naming |  |
| `az 0702` | Create a conventional commit with validation |  |
| `az 0703` | Create a pull request with templates and automation |  |
| `az 0704` | Stage files for Git commit using patterns |  |
| `az 0705` | Push Git branch to remote repository |  |
| `az 0709` | Post or update PR comment with test results |  |
| `az 0720` | Setup GitHub Actions Self-Hosted Runners |  |
| `az 0721` | Configure GitHub Actions Runner Environment |  |
| `az 0722` | Install GitHub Actions Runner as System Services |  |
| `az 0723` | Setup Matrix of GitHub Actions Self-Hosted Runners |  |
| `az 0730` | Configures and initializes all AI agent integrations for AitherZero |  |
| `az 0731` | Multi-AI code analysis pipeline for comprehensive code review |  |
| `az 0732` | AI-powered test generation using configured providers |  |
| `az 0733` | Automated documentation generation using AI providers |  |
| `az 0733` | Automated reactive documentation generation with quality validation | documentation, automation, reactive, ai-powered |
| `az 0734` | AI-driven performance analysis and optimization |  |
| `az 0735` | Comprehensive security scanning with AI analysis |  |
| `az 0736` | Generate custom orchestration workflows using AI |  |
| `az 0737` | Monitor and report AI API usage and costs |  |
| `az 0738` | Build and train project-specific AI context |  |
| `az 0739` | Validate AI-generated code and content |  |
| `az 0740` | Integrate AI tools for code review and analysis |  |
| `az 0741` | Generate AI-enhanced commit messages from staged changes |  |
| `az 0742` | Create AI-enhanced pull request with automatic description generation |  |
| `az 0743` | Comprehensive automated copilot system enablement | ai, automation, copilot, continuous-improvement |

### Maintenance (9000-9999)

| Script | Description | Tags |
| ------ | ----------- | ---- |
| `az 9999` | Reset machine to clean state (sysprep on Windows, reboot on Linux/macOS) |  |

## Usage

Use the `az` command wrapper to execute scripts:

`powershell
# Examples
az 0402      # Run unit tests
az 0510      # Generate project report  
az 0701      # Create feature branch
`

## Integration

These scripts integrate with:
- **CI/CD Pipelines**: Automated execution in GitHub Actions
- **Orchestration Engine**: Batch execution via playbooks
- **Testing Framework**: Validation and quality gates

---
*Generated automatically on 2025-10-26 22:33:48*
