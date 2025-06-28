# Claude Requirements Gathering System

An intelligent requirements gathering system for Claude Code that progressively builds context through automated discovery, asks simple yes/no questions, and generates comprehensive requirements documentation.

## 🚀 Quick Start with AitherZero

### Option 1: Install via DevEnvironment Module

```powershell
# Import the DevEnvironment module
Import-Module ./aither-core/modules/DevEnvironment -Force

# Install the requirements system
Install-ClaudeRequirementsSystem

# Verify installation
Test-ClaudeRequirementsSystem
```

### Option 2: Run via LabRunner Script

```powershell
# Using the AitherZero launcher
./Start-AitherZero.ps1 -Scripts "0220_Setup-ClaudeRequirements"

# Or directly
./aither-core/scripts/0220_Setup-ClaudeRequirements.ps1
```

### Option 3: Manual Installation

```powershell
# Copy commands to project-specific Claude directory
cp -r claude-requirements/commands .claude/

# Or for user-wide installation
cp -r claude-requirements/commands ~/.claude/commands/
```

## 📋 Using the Requirements System

Once installed, open Claude Code in your project and use these commands:

### Start Gathering Requirements
```
/requirements-start add user authentication system
```

### Check Progress
```
/requirements-status
```

### View Current Requirement
```
/requirements-current
```

### List All Requirements
```
/requirements-list
```

### End Current Requirement
```
/requirements-end
```

### Remind AI of Rules
```
/remind
```

## 🔄 How It Works

### Phase 1: Initial Analysis
- AI analyzes your entire codebase structure
- Understands architecture, tech stack, and patterns

### Phase 2: Context Discovery (5 Questions)
- Simple yes/no questions for product managers
- Example: "Will users interact through a visual interface?"
- Default answers provided - just say "idk" to use defaults

### Phase 3: Deep Code Analysis
- AI autonomously searches specific files
- Reads relevant code sections
- Documents technical constraints

### Phase 4: Expert Requirements (5 Questions)
- Detailed yes/no questions based on code understanding
- Example: "Should we use the existing UserService at services/UserService.ts?"

### Phase 5: Documentation Generation
- Comprehensive requirements spec
- Specific file paths and implementation patterns
- Ready for development

## 📁 Directory Structure

```
claude-requirements/
├── commands/                     # Claude command definitions
│   ├── requirements-start.md    # Begin new requirement
│   ├── requirements-status.md   # Check progress
│   ├── requirements-current.md  # View active requirement
│   ├── requirements-end.md      # Finalize requirement
│   ├── requirements-list.md     # List all requirements
│   └── requirements-remind.md   # Remind AI of rules
│
├── requirements/                # Requirement documentation storage
│   ├── .current-requirement    # Tracks active requirement
│   ├── index.md               # Summary of all requirements
│   └── YYYY-MM-DD-HHMM-name/ # Individual requirement folders
│
└── examples/                   # Example requirements (optional)
```

## 🎯 Integration with AitherZero

The Claude Requirements System integrates seamlessly with AitherZero's modular architecture:

- **DevEnvironment Module**: Provides installation and verification functions
- **LabRunner**: Can execute the setup script as part of automation workflows
- **Logging Module**: All operations are logged using AitherZero's centralized logging
- **Project Structure**: Follows AitherZero's cross-platform path handling

## 💡 Best Practices

### For Requirements Gathering
1. **Be Specific**: Clear initial descriptions help AI ask better questions
2. **Use Defaults**: "idk" is perfectly fine - defaults are well-reasoned
3. **Stay Focused**: Use /remind if AI goes off track
4. **Complete When Ready**: Don't feel obligated to answer every question

### For Integration
1. **Use PatchManager**: When implementing requirements, use AitherZero's PatchManager
2. **Follow Patterns**: Requirements will reference existing patterns in your codebase
3. **Link PRs**: Connect requirements to development sessions and pull requests
4. **Track Progress**: Use the requirements list to monitor implementation status

## 🔧 Troubleshooting

### Requirements System Not Found
```powershell
# Check if installed
Test-ClaudeRequirementsSystem

# Reinstall if needed
Install-ClaudeRequirementsSystem -Force
```

### Commands Not Working in Claude
1. Ensure .claude/commands directory exists
2. Check that command files have .md extension
3. Restart Claude Code after installation

### Missing Dependencies
```powershell
# Import required modules
Import-Module ./aither-core/modules/Logging -Force
Import-Module ./aither-core/modules/DevEnvironment -Force
```

## 📚 Examples

### Feature Development
```
/requirements-start implement dark mode for dashboard
# Answer 5 context questions
# AI analyzes codebase
# Answer 5 expert questions
# Get comprehensive requirements doc
```

### Bug Fix Requirements
```
/requirements-start fix memory leak in data processing
# Define scope through questions
# AI identifies problematic components
# Get targeted fix requirements
```

## 🤝 Contributing

This system is part of the AitherZero project. To contribute:

1. Use PatchManager for all changes
2. Follow AitherZero coding standards
3. Add tests for new functionality
4. Update documentation

## 📄 License

Part of the AitherZero Infrastructure Automation Framework.
See the main project LICENSE file for details.