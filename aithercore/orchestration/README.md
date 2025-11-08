# Orchestration Domain

**Status**: ✅ Active

The Orchestration domain contains playbook definitions and orchestration configurations for the AitherZero platform. This domain organizes workflow definitions, CI/CD mappings, and execution sequences.

## Directory Structure

```
aithercore/orchestration/
├── README.md              # This file
├── index.md               # Auto-generated index
├── playbooks/            # Playbook definitions
│   ├── core/             # Core playbooks
│   │   ├── operations/   # CI/CD operation playbooks
│   │   └── testing/      # Testing playbooks
│   ├── testing/          # Test orchestration configs
│   ├── converted/        # GitHub workflow conversions
│   ├── *.psd1            # PowerShell data playbooks
│   └── *.json            # JSON format playbooks
└── schema/               # Playbook schema definitions
    └── playbook-schema-v3.json
```

## Purpose

The orchestration domain serves as the central repository for:

1. **Playbook Definitions**: Workflow configurations in JSON and PSD1 formats
2. **CI/CD Mappings**: Mirrors of GitHub Actions workflows for local execution
3. **Test Orchestration**: Testing workflow configurations and profiles
4. **Schema Definitions**: Validation schemas for playbook formats

## Key Components

### Playbooks Directory

Contains all playbook definitions organized by purpose:

- **`core/operations/`**: CI/CD operation playbooks (PR validation, testing, quality checks)
- **`core/testing/`**: Test execution playbooks (quick, standard, comprehensive, full)
- **`testing/`**: Active test orchestration configurations
- **`converted/`**: GitHub workflow files converted to playbook format

### Schema Directory

Contains JSON schema definitions for validating playbook formats:

- **`playbook-schema-v3.json`**: Current playbook schema specification

## Usage

Playbooks in this domain are executed via:

1. **Automation Scripts**: `0962_Run-Playbook.ps1` and related scripts
2. **CLI Module**: `aithercore/cli/AitherZeroCLI.psm1` playbook commands
3. **Orchestration Engine**: `aithercore/automation/OrchestrationEngine.psm1`

### Example

```powershell
# List available playbooks
./automation-scripts/0962_Run-Playbook.ps1 -List

# Run a playbook
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-pr-validation

# Execute with specific profile
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-comprehensive-test -Profile quick
```

## Relationship with Automation Domain

The orchestration domain contains the **data** (playbooks, schemas), while the automation domain (`aithercore/automation/`) contains the **execution logic**:

- **Orchestration Domain**: Playbook definitions, configurations, schemas
- **Automation Domain**: `OrchestrationEngine.psm1`, `AsyncOrchestration.psm1`, execution logic

This separation follows the domain-driven design principle of separating data from behavior.

## Adding New Playbooks

1. Create playbook file in appropriate subdirectory
2. Follow the v3.0 schema format (see `schema/playbook-schema-v3.json`)
3. Test with `0962_Run-Playbook.ps1 -DryRun`
4. Document in playbook metadata (name, description, duration)

## Migration Note

This domain was moved from the root `orchestration/` directory to `aithercore/orchestration/` to align with the domain-based architecture of AitherZero. All path references have been updated across the codebase.

## Best Practices

1. **Use Schema Validation**: Validate playbooks against the schema before committing
2. **Document Playbooks**: Include clear name, description, and duration estimates
3. **Organize by Purpose**: Place playbooks in the appropriate subdirectory
4. **Test Locally**: Use `0962_Run-Playbook.ps1` to test before pushing to CI/CD
5. **Version Control**: Track playbook changes carefully as they affect CI/CD behavior

## Related Documentation

- [Playbook README](playbooks/README.md) - Comprehensive playbook documentation
- [OrchestrationEngine Guide](../../docs/ORCHESTRATION-ENGINE-GUIDE.md) - Engine documentation
- [Local Validation System](../../docs/LOCAL-VALIDATION-SYSTEM.md) - Testing playbooks locally
