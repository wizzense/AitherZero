# Custom Playbooks

This directory is for your custom automation playbooks. Create playbooks here to define your own endpoint configurations, deployment workflows, and automation sequences.

## Getting Started

### 1. Use the Template

Start with the provided template:

```bash
cp ../templates/custom-playbook-template.json ./my-custom-playbook.json
```

### 2. Edit Your Playbook

Customize the template:
- Update `metadata` with your playbook name and description
- Modify `stages` to include your desired automation blocks
- Configure `profiles` for different execution scenarios
- Add `variables` for customization

### 3. Execute Your Playbook

Run your custom playbook:

```powershell
# Basic execution
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-custom-playbook

# With profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-custom-playbook -Profile minimal

# Dry run (see what will execute)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-custom-playbook -DryRun
```

## Example Playbooks

### endpoint-configuration-example.json

A comprehensive example demonstrating:
- Multiple profiles (minimal, web-development, python-datascience, etc.)
- Conditional execution based on project type
- Parallel installation where appropriate
- Error handling strategies
- Post-execution validation

**Usage:**
```powershell
# Web development setup
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook endpoint-configuration-example -Profile web-development

# Python data science
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook endpoint-configuration-example -Profile python-datascience

# Cloud DevOps
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook endpoint-configuration-example -Profile cloud-devops
```

## Building Blocks Reference

### Available Script Ranges

| Range | Category | Purpose |
|-------|----------|---------|
| 0000-0099 | Environment Prep | PowerShell 7, directories, validation tools |
| 0100-0199 | Infrastructure | Hyper-V, WSL2, certificates, system config |
| 0200-0299 | Dev Tools | Languages, IDEs, package managers, CLIs |
| 0400-0499 | Testing | Unit tests, integration tests, quality checks |
| 0500-0599 | Reporting | Reports, metrics, analytics, tech debt |
| 0700-0799 | Dev Workflows | Git, CI/CD, AI tools, MCP servers |
| 0800-0899 | Issue & Deploy | Issue management, PR environments |
| 0900-0999 | Test Generation | Automated test generation, validation |

See `docs/BUILDING-BLOCKS.md` for complete reference.

### Common Building Blocks

**Essential Setup:**
```json
{
  "sequences": ["0001", "0002", "0207"]
}
```

**Web Development:**
```json
{
  "sequences": ["0001", "0002", "0207", "0201", "0208", "0210"]
}
```

**Python Development:**
```json
{
  "sequences": ["0001", "0002", "0207", "0206", "0204", "0210"]
}
```

**Testing & Validation:**
```json
{
  "sequences": ["0400", "0402", "0404", "0407", "0420"]
}
```

**AI-Powered Development:**
```json
{
  "sequences": ["0010", "0730", "0740", "0743", "0744", "0745"]
}
```

## Playbook Structure

### Minimal Playbook

```json
{
  "$schema": "../../schema/playbook-schema-v3.json",
  "metadata": {
    "name": "my-playbook",
    "description": "My custom automation playbook",
    "version": "1.0.0",
    "category": "operations"
  },
  "orchestration": {
    "stages": [
      {
        "name": "Setup",
        "sequences": ["0001", "0002", "0207"]
      }
    ]
  }
}
```

### Playbook with Profiles

```json
{
  "metadata": {
    "name": "my-playbook"
  },
  "orchestration": {
    "profiles": {
      "quick": {
        "description": "Quick setup",
        "variables": {
          "installOptional": false
        }
      },
      "complete": {
        "description": "Complete setup",
        "variables": {
          "installOptional": true
        }
      }
    },
    "stages": [
      {
        "name": "Core",
        "sequences": ["0001", "0002"]
      },
      {
        "name": "Optional",
        "sequences": ["0210"],
        "condition": "{{installOptional}}"
      }
    ]
  }
}
```

### Playbook with Conditional Execution

```json
{
  "orchestration": {
    "defaultVariables": {
      "platform": "Windows",
      "includeDocker": true
    },
    "stages": [
      {
        "name": "Windows Infrastructure",
        "sequences": ["0105"],
        "condition": "$IsWindows"
      },
      {
        "name": "Docker",
        "sequences": ["0208"],
        "condition": "{{includeDocker}}"
      }
    ]
  }
}
```

### Playbook with Parallel Execution

```json
{
  "orchestration": {
    "stages": [
      {
        "name": "Install Tools",
        "sequences": ["0201", "0206", "0207"],
        "parallel": true,
        "maxConcurrency": 3
      }
    ]
  }
}
```

## Best Practices

### 1. Use Descriptive Names

```json
{
  "metadata": {
    "name": "web-dev-complete-setup",
    "description": "Complete web development environment with Docker and testing"
  }
}
```

### 2. Define Multiple Profiles

Create profiles for different use cases:
- `minimal`: Essential tools only
- `standard`: Typical development setup
- `complete`: All tools and features

### 3. Add Validation

```json
{
  "validation": {
    "preConditions": [
      {
        "name": "PowerShell Version",
        "condition": "$PSVersionTable.PSVersion.Major -ge 7",
        "message": "PowerShell 7+ required"
      }
    ],
    "postConditions": [
      {
        "name": "Tools Installed",
        "condition": "$results.Failed -eq 0",
        "message": "All tools should install successfully"
      }
    ]
  }
}
```

### 4. Handle Errors Gracefully

```json
{
  "stages": [
    {
      "name": "Critical Setup",
      "sequences": ["0001", "0002"],
      "continueOnError": false
    },
    {
      "name": "Optional Tools",
      "sequences": ["0210"],
      "continueOnError": true
    }
  ]
}
```

### 5. Document Your Playbook

Add comments in the JSON using `_comments` or `_documentation` fields:

```json
{
  "_documentation": {
    "purpose": "Sets up a Python data science environment",
    "usage": [
      "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook"
    ],
    "notes": [
      "Requires at least 8GB RAM for Jupyter",
      "Docker optional but recommended"
    ]
  }
}
```

### 6. Test Before Deploying

Always dry-run first:

```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook -DryRun
```

### 7. Use Timeouts

Set appropriate timeouts for each stage:

```json
{
  "stages": [
    {
      "name": "Quick Setup",
      "timeout": 300
    },
    {
      "name": "Docker Install",
      "timeout": 1200
    }
  ]
}
```

## Common Patterns

### Pattern: Multi-Environment Playbook

```json
{
  "orchestration": {
    "defaultVariables": {
      "environment": "Development"
    },
    "stages": [
      {
        "name": "Base Setup",
        "sequences": ["0001", "0002"]
      },
      {
        "name": "Development Tools",
        "sequences": ["0207", "0210"],
        "condition": "{{environment}} -eq 'Development'"
      },
      {
        "name": "Production Tools",
        "sequences": ["0208", "0212"],
        "condition": "{{environment}} -eq 'Production'"
      }
    ]
  }
}
```

### Pattern: Feature Flags

```json
{
  "orchestration": {
    "defaultVariables": {
      "features": ["Git", "Docker", "Python"]
    },
    "stages": [
      {
        "name": "Git",
        "sequences": ["0207"],
        "condition": "{{features}} -contains 'Git'"
      },
      {
        "name": "Docker",
        "sequences": ["0208"],
        "condition": "{{features}} -contains 'Docker'"
      },
      {
        "name": "Python",
        "sequences": ["0206"],
        "condition": "{{features}} -contains 'Python'"
      }
    ]
  }
}
```

### Pattern: Progressive Enhancement

```json
{
  "orchestration": {
    "stages": [
      {
        "name": "Level 1: Essentials",
        "sequences": ["0001", "0002", "0207"]
      },
      {
        "name": "Level 2: Development",
        "sequences": ["0201", "0206", "0210"],
        "continueOnError": true
      },
      {
        "name": "Level 3: Advanced",
        "sequences": ["0208", "0730", "0740"],
        "continueOnError": true
      }
    ]
  }
}
```

## Troubleshooting

### Playbook Not Found

Ensure your playbook is in `orchestration/playbooks/custom/` and the name matches (without `.json` extension).

### Validation Errors

Check your JSON syntax:

```powershell
Get-Content ./my-playbook.json | ConvertFrom-Json
```

### Stage Not Executing

Check conditions and variables:

```powershell
# Enable verbose output
$VerbosePreference = 'Continue'
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook -Verbose
```

### Timeout Issues

Increase timeout values for long-running stages:

```json
{
  "timeout": 1800
}
```

## Resources

- **Complete Guide**: `docs/BUILDING-BLOCKS.md`
- **Quick Reference**: `docs/BUILDING-BLOCKS-QUICK-REFERENCE.md`
- **Reorganization Plan**: `docs/BUILDING-BLOCKS-REORGANIZATION.md`
- **Schema**: `orchestration/schema/playbook-schema-v3.json`
- **Core Examples**: `orchestration/playbooks/core/`
- **Templates**: `orchestration/playbooks/templates/`

## Contributing

Share your useful playbooks with the community:

1. Test your playbook thoroughly
2. Add comprehensive documentation
3. Submit a PR to include it in the examples
4. Help others by sharing patterns that work

---

**Happy Automating! 🚀**
