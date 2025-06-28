# Claude Code Integration Directory Structure

This document clarifies the directory structure for Claude Code integration with AitherZero.

## Clean Directory Structure (Post-Cleanup)

```
/.claude/                              # Claude Code runtime (active configuration)
├── commands/                          # Active slash commands Claude Code reads
│   ├── monitor.md                     # /monitor - System monitoring
│   ├── service.md                     # /service - Service management
│   ├── infra.md                       # /infra - Infrastructure operations
│   ├── ops.md                         # /ops - Operations management
│   ├── lab.md                         # /lab - Lab environment management
│   ├── patchmanager.md                # /patchmanager - Git workflows
│   └── requirements-*.md              # Requirements gathering commands
├── requirements-config.json           # Runtime configuration file
└── settings.local.json                # Local Claude Code settings

/claude-requirements/                   # Documentation and guides only
├── CLAUDE-CODE-QUICK-START.md         # Quick start guide
├── OPERATIONAL-COMMANDS-DESIGN.md     # Command design documentation  
├── DIRECTORY-STRUCTURE.md             # This file - structure explanation
├── README.md                          # Project documentation
└── examples/                          # Usage examples

/requirements/                         # Active requirements tracking
├── index.md                           # Requirements index
├── 2025-06-28-1929-test-coverage-automation/
├── 2025-06-28-2039-comprehensive-code-review/
└── 2025-06-28-2052-powershell-claude-commands/
```

## Key Distinction

You're absolutely right to question this! Here's the clear distinction:

### **`/.claude/` Directory** 
- **Purpose**: Active runtime configuration that Claude Code actually reads
- **Contents**: Live command definitions, configuration files  
- **Function**: This is where Claude Code looks for slash commands
- **Managed by**: Claude Code CLI and installation scripts

### **`claude-requirements/` Directory**
- **Purpose**: Documentation, guides, and development resources
- **Contents**: Installation guides, design docs, usage examples
- **Function**: Reference materials and installation resources
- **Managed by**: Development team and documentation

## The Corrected Workflow

1. **Active Commands**: Created directly in `/.claude/commands/` (where Claude Code reads them)
2. **Documentation**: Stored in `claude-requirements/` for reference
3. **Installation**: `Install-ClaudeRequirementsSystem` verifies commands exist in `/.claude/commands/`

## Why This Structure?

- **`.claude/`**: Standard location where Claude Code expects to find commands
- **`claude-requirements/`**: Project-specific documentation and guides
- **Separation**: Keeps active runtime separate from documentation

## Current Status

✅ **Active Commands in `.claude/commands/`**:
- monitor.md (system monitoring)
- service.md (service management) 
- infra.md (infrastructure operations)
- ops.md (operations management)
- lab.md (lab environment management)
- patchmanager.md (git workflows)
- requirements-*.md (requirements gathering)

✅ **Documentation in `claude-requirements/`**:
- CLAUDE-CODE-QUICK-START.md
- OPERATIONAL-COMMANDS-DESIGN.md
- This directory structure explanation

## Testing the Commands

You can now use these operational commands in Claude Code:

```bash
/monitor dashboard --system all
/service list --status running
/infra status --all --detailed
/ops dashboard --overview --executive
/lab create --env test --template minimal --ttl 2h
```

The commands are live and ready for AI-assisted infrastructure management!