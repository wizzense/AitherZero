# Deprecated Testing Scripts

The following scripts are **DEPRECATED** and should no longer be used.

## Use Instead

**ONE command for all testing:**
```bash
aitherzero orchestrate test-orchestrated --profile <quick|standard|full|ci>
```

## Deprecated Scripts

| Script | Status | Replacement |
|--------|--------|-------------|
| `0409_Run-AllTests.ps1` | ⚠️ DEPRECATED | `test-orchestrated --profile full` |
| `0460_Orchestrate-Tests.ps1` | ⚠️ DEPRECATED | `test-orchestrated` |
| `0470_Orchestrate-SimpleTesting.ps1` | ⚠️ DEPRECATED | `test-orchestrated --profile quick` |
| `0480_Test-Simple.ps1` | ⚠️ DEPRECATED | `test-orchestrated --profile quick` |
| `0490_AI-TestRunner.ps1` | ⚠️ DEPRECATED | `test-orchestrated` |

## Why Deprecated?

1. **Fragmented** - 8+ scripts doing similar things
2. **Confusing** - Which one to use?
3. **Duplicated** - ~30% duplicate code
4. **Scattered results** - Multiple locations

## New System

- **ONE playbook** - Clear entry point
- **ONE dashboard** - All results in one place
- **Zero duplication** - Uses existing modules
- **4 profiles** - quick, standard, full, ci

See `TESTING-README.md` for complete documentation.
