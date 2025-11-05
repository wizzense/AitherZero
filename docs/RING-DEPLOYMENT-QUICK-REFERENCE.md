# 🎯 Ring Deployment Quick Reference

## Ring Levels

| Ring | Level | Purpose | Test Time | Approvals |
|------|-------|---------|-----------|-----------|
| **ring-0** | 0 | Early Dev | 2-3 min | 0 |
| **ring-0-integrations** | 0.5 | Integration | 5-7 min | 0 |
| **ring-1** | 1 | Validation | 5-10 min | 1 |
| **ring-1-integrations** | 1.5 | Full Integration | 10-15 min | 1 |
| **ring-2** | 2 | Pre-Production | 15-20 min | 1 |
| **dev** | 4 | Development Env | 20-30 min | 1 |
| **main** | 5 | Production | 30-45 min | 2 |

## Quick Commands

### View Status
```bash
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action status
```

### Promote to Next Ring
```bash
./automation-scripts/0710_Manage-RingDeployment.ps1 \
  -Action promote \
  -SourceRing ring-0 \
  -TargetRing ring-0-integrations \
  -CreatePR
```

### Validate Configuration
```bash
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action validate
```

### Generate Report
```bash
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action report
```

## Typical Workflow

1. **Create feature in ring-0**
   ```bash
   git checkout ring-0
   git checkout -b feature/my-feature
   # ... develop ...
   git push origin feature/my-feature
   gh pr create --base ring-0
   ```

2. **Merge to ring-0**
   - Quick tests run (~2-3 min)
   - Merge when green

3. **Promote through rings**
   ```bash
   # ring-0 → ring-0-integrations
   gh pr create --base ring-0-integrations --head ring-0
   
   # ring-0-integrations → ring-1
   gh pr create --base ring-1 --head ring-0-integrations
   
   # Continue through: ring-1 → ring-1-integrations → ring-2 → dev → main
   ```

## Test Profiles

| Profile | What Runs | Duration |
|---------|-----------|----------|
| **quick** | Syntax + Unit | 2-3 min |
| **integration** | + Integration + Security | 5-15 min |
| **standard** | + PSScriptAnalyzer | 5-10 min |
| **comprehensive** | + Performance | 15-20 min |
| **full** | + Coverage + Load | 20-30 min |
| **production** | + Compliance + Stress | 30-45 min |

## PR Labels

Labels are automatically applied:

- `ring:source:<name>` - Source ring (blue)
- `ring:target:<name>` - Target ring (orange)
- `ring:promotion` - Promoting up (green)
- `ring:demotion` - Demoting down (yellow)

## Emergency Hotfix

For production emergencies:

```bash
# 1. Branch from main
git checkout main
git checkout -b hotfix/critical-issue

# 2. Fix and test
# ... make fix ...

# 3. Fast-track PR to main
gh pr create --base main --label emergency-promotion

# 4. After merge, backport to lower rings
```

## Tips

- ✅ **Start low**: Always begin in ring-0
- ✅ **Go sequential**: Don't skip rings
- ✅ **Test locally**: Run tests before pushing
- ✅ **Integration rings**: Use for multi-feature testing
- ✅ **Read PR comments**: Automated comments show requirements

## Troubleshooting

### Tests not running?
Check the target branch - tests match target ring, not source.

### Can't merge?
Ensure required approvals met and all checks pass.

### Need to change target ring?
Close PR and reopen with different base branch.

## Links

- 📖 [Full Documentation](./RING-DEPLOYMENT-STRATEGY.md)
- 🔧 [CI/CD Guide](./CI-CD-GUIDE.md)
- 🧪 [Testing Strategy](./TESTING-STRATEGY.md)
