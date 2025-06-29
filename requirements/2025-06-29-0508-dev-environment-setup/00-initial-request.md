# Initial Request

## Feature Description
Full development environment setup with AI agent tools integration and configuration management

## Detailed Requirements

### 1. AI Agent Tools Integration
- Make it easy to setup the full development environment with all AI agent tools:
  - Claude Code
  - Codex
  - Gemini
- Include Claude commands that can use all of these tools

### 2. Claude Commands for PowerShell Modules
- Add new Claude commands for all new PowerShell module capabilities
- Integrate with existing AitherZero modules

### 3. Configuration Management System
- Easy creation of new GitHub repo/fork for 'settings/configs/opentofu'
- After first run, users can transition to their own custom settings
- Project provides defaults but allows customization
- Optional configuration wizard for FULL configuration file setup
- Process ends with:
  - Creating a git repo for custom settings
  - Configuring the project to add it to the 'configuration carousel'
- Easy switching between default settings and custom configurations
- Support for multiple settings configurations

### 4. Orchestration Playbooks
- Basic orchestration playbooks using aither-core and runner script system
- Run scripts in specific order to achieve different results
- Examples:
  - Only run scripts 0002-0010 on deployment
  - Any combination or order
- Tool deployable as code using:
  - Basic instruction sets based on script number
  - Natural language instructions
  - PowerShell script instructions

## Key Goals
1. Simplify development environment setup
2. Enable easy customization and configuration management
3. Create flexible orchestration capabilities
4. Make the tool deployable as infrastructure-as-code