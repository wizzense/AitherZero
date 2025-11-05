# Ring-Based Deployment System

This directory contains configuration and workflows for AitherZero's ring-based deployment strategy.

## Files

### Configuration
- **`ring-config.json`** - Central configuration for rings, test profiles, and deployment gates

### Workflows
- **`ring-based-deployment.yml`** - Main workflow for ring-aware CI/CD
  - Automatic ring detection
  - PR labeling
  - Ring-appropriate test execution
  - Promotion/demotion support

- **`configure-ring-protection.yml`** - Branch protection configuration (requires admin)
  - Set up branch protection rules from configuration
  - Dry-run mode for validation
  - Generates configuration report

### Templates
- **`PULL_REQUEST_TEMPLATE/ring-deployment.md`** - PR template for ring promotions

## Quick Links

- 📖 [Full Documentation](../docs/RING-DEPLOYMENT-STRATEGY.md)
- 🚀 [Quick Reference](../docs/RING-DEPLOYMENT-QUICK-REFERENCE.md)
- 🔧 [Management Script](../automation-scripts/0710_Manage-RingDeployment.ps1)

## Ring Hierarchy

```
Ring 0 (Level 0)
  └─► Ring 0-Integrations (Level 0.5)
        └─► Ring 1 (Level 1)
              └─► Ring 1-Integrations (Level 1.5)
                    └─► Ring 2 (Level 2)
                          └─► Dev (Level 4)
                                └─► Main (Level 5)
```

## Configuration Schema

### Ring Definition
```json
{
  "ringName": {
    "level": 0,
    "name": "Display Name",
    "description": "Purpose of this ring",
    "type": "development|integration|pre-production|environment|production",
    "testProfile": "quick|integration|standard|comprehensive|full|production",
    "testTimeout": 30,
    "requiredApprovals": 1,
    "autoMerge": false,
    "deploymentGates": {
      "syntaxValidation": true,
      "unitTests": true,
      "integrationTests": true,
      "securityScan": true,
      "performanceTest": true,
      "manualApproval": false
    },
    "nextRing": "next-ring-name",
    "previousRing": "previous-ring-name",
    "protected": true,
    "color": "#HEX"
  }
}
```

### Test Profile Definition
```json
{
  "profileName": {
    "name": "Display Name",
    "description": "What this profile tests",
    "estimatedDuration": "X-Y minutes",
    "tests": [
      "test-suite-1",
      "test-suite-2"
    ],
    "parallel": true,
    "failFast": false
  }
}
```

## Customization

To modify ring behavior:

1. **Edit `ring-config.json`**
   - Add/remove rings
   - Adjust test profiles
   - Configure deployment gates

2. **Validate changes**
   ```powershell
   ./automation-scripts/0710_Manage-RingDeployment.ps1 -Action validate
   ```

3. **Apply branch protection** (requires admin)
   - Run `configure-ring-protection.yml` workflow
   - Use dry-run first to preview

4. **Test with PR**
   - Create test PR between rings
   - Verify labels and tests

## Maintenance

### Adding a New Ring

1. Add ring definition to `ring-config.json`:
   ```json
   {
     "rings": {
       "new-ring": {
         "level": 1.75,
         "name": "New Ring",
         // ... other properties
       }
     }
   }
   ```

2. Add branch protection config:
   ```json
   {
     "branchProtection": {
       "new-ring": {
         "requiredStatusChecks": [...],
         // ... other settings
       }
     }
   }
   ```

3. Validate configuration:
   ```bash
   ./automation-scripts/0710_Manage-RingDeployment.ps1 -Action validate
   ```

4. Create branch:
   ```bash
   git checkout -b new-ring
   git push origin new-ring
   ```

5. Configure protection (requires admin):
   - Run `configure-ring-protection.yml` with target `new-ring`

### Modifying Test Profiles

1. Edit test profile in `ring-config.json`
2. Update ring assignments to use new profile
3. Test with PR to verify profile runs correctly

### Changing Branch Protection

1. Edit `branchProtection` section in `ring-config.json`
2. Run `configure-ring-protection.yml` (dry-run first)
3. Verify in repository Settings → Branches

## Troubleshooting

### Workflow Not Running
- Check workflow triggers in `ring-based-deployment.yml`
- Verify branch names match configuration
- Check workflow permissions

### Labels Not Applied
- Ensure PR is between valid ring branches
- Check workflow logs for errors
- Manually trigger workflow if needed

### Tests Not Running
- Verify test profile exists in configuration
- Check playbook mapping in workflow
- Review workflow logs for errors

### Can't Apply Branch Protection
- Requires repository admin permissions
- Check `configure-ring-protection.yml` permissions
- Verify branch exists before applying protection

## Support

For issues with the ring system:
- 📖 [Documentation](../docs/RING-DEPLOYMENT-STRATEGY.md)
- 🐛 [Report Issue](https://github.com/wizzense/AitherZero/issues/new)
- 💬 [Discussions](https://github.com/wizzense/AitherZero/discussions)
