# Quick Reference: New Testing System

## TL;DR - What You Need to Know

### Before (OLD - Confusing)
```bash
# Which script should I use? 🤔
./automation-scripts/0409_Run-AllTests.ps1?
./automation-scripts/0460_Orchestrate-Tests.ps1?
./automation-scripts/0470_Orchestrate-SimpleTesting.ps1?
./automation-scripts/0480_Test-Simple.ps1?
# Where are my results? Multiple places...
```

### After (NEW - Simple)
```bash
# ONE command, choose your speed:
aitherzero orchestrate test-orchestrated --profile quick     # 5min
aitherzero orchestrate test-orchestrated --profile standard  # 10min
aitherzero orchestrate test-orchestrated --profile full      # 20min

# Results? ONE place:
open reports/dashboard.html  # Everything you need!
```

## Quick Commands

### Run Tests Locally
```bash
# Quick check (before commit)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-orchestrated -Profile quick

# Standard check (default)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-orchestrated

# Full check (before release)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-orchestrated -Profile full
```

### View Results
```bash
# Open dashboard
open reports/dashboard.html        # macOS
xdg-open reports/dashboard.html    # Linux  
start reports/dashboard.html       # Windows/PowerShell

# Or use existing script
./automation-scripts/0511_Show-ProjectDashboard.ps1
```

### In CI/CD
The workflow runs automatically! Just push your code.

Manual trigger:
```bash
# Via GitHub UI: Actions → Unified Testing → Run workflow → Choose profile
```

## What Runs in Each Profile

### Quick (5min) ⚡
- ✅ Install tools
- ✅ Unit tests
- ✅ Syntax validation
- ✅ Static analysis
- ❌ Integration tests
- ❌ Quality analysis
- ❌ Security scan

### Standard (10min) 🎯
- ✅ Install tools
- ✅ Unit tests
- ✅ Integration tests
- ✅ Syntax validation
- ✅ Static analysis
- ✅ Quality analysis
- ❌ Security scan

### Full (20min) 💯
- ✅ Everything!

### CI (10min) 🤖
- Same as standard
- Optimized for GitHub Actions
- Dashboard published to Pages

## Dashboard Features

The unified dashboard shows:
- 📊 **Test Summary** - Pass/fail/skip counts
- 🐛 **Prioritized Issues** - What to fix first
- 📈 **Trends** - Are we improving?
- 🔍 **Details** - Click through to specifics
- 💡 **Recommendations** - What to do next

## Where Things Are

```
orchestration/playbooks/testing/test-orchestrated.json  ← THE playbook
.github/workflows/unified-testing.yml                   ← THE workflow
reports/dashboard.html                                  ← THE dashboard
TESTING-OVERHAUL-COMPLETE.md                            ← THE guide
```

## Migration Cheat Sheet

| Old Command | New Command |
|-------------|-------------|
| `./automation-scripts/0409_Run-AllTests.ps1` | `aitherzero orchestrate test-orchestrated --profile full` |
| `./automation-scripts/0480_Test-Simple.ps1` | `aitherzero orchestrate test-orchestrated --profile quick` |
| `./automation-scripts/0460_Orchestrate-Tests.ps1` | `aitherzero orchestrate test-orchestrated` |
| Multiple result files | One dashboard: `reports/dashboard.html` |

## Still Work (For Now)

Old scripts still function if you need them:
- `0402_Run-UnitTests.ps1` - Direct unit test execution
- `0403_Run-IntegrationTests.ps1` - Direct integration tests
- `0404_Run-PSScriptAnalyzer.ps1` - Direct analysis
- etc.

But **prefer the playbook** for consistency!

## Troubleshooting

### "Playbook not found"
```bash
# Make sure you're in the project root
cd /path/to/AitherZero
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-orchestrated
```

### "No dashboard generated"
```bash
# Dashboard is generated after all tests run
# Check reports/ directory:
ls -la reports/

# If empty, tests may have failed early. Check logs:
./automation-scripts/0530_View-Logs.ps1
```

### "Tests taking too long"
```bash
# Use quick profile:
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-orchestrated -Profile quick

# Or customize the playbook:
# Edit: orchestration/playbooks/testing/test-orchestrated.json
# Remove stages you don't need
```

## Pro Tips

1. **Quick local validation**: Always run `--profile quick` before committing
2. **Full check before PR**: Run `--profile full` before creating PR
3. **Read the dashboard**: It prioritizes issues - fix critical first!
4. **Customize profiles**: Edit the playbook to add your own profiles
5. **Check workflow**: Monitor GitHub Actions for automated runs

## Need Help?

- Full guide: `TESTING-OVERHAUL-COMPLETE.md`
- Playbook config: `orchestration/playbooks/testing/test-orchestrated.json`
- Workflow config: `.github/workflows/unified-testing.yml`
- Existing modules: `domains/reporting/`, `domains/testing/`

---

Remember: **ONE playbook, ONE dashboard, ZERO confusion!** 🎯
