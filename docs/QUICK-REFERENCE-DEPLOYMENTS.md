# 🚀 Branch Deployments Quick Reference

## URLs

| Branch | URL |
|--------|-----|
| **Main** | https://wizzense.github.io/AitherZero/ |
| **Dev** | https://wizzense.github.io/AitherZero/dev/ |
| **Dev-Staging** | https://wizzense.github.io/AitherZero/dev-staging/ |
| **All Branches** | https://wizzense.github.io/AitherZero/deployments.html |

## Quick Commands

### Deploy a Branch
```bash
# Automatic on push
git checkout dev-staging
git push origin dev-staging

# Manual trigger
# Go to Actions → "Deploy Jekyll with GitHub Pages" → Run workflow
```

### Check Deployment Status
```bash
# View workflow runs
https://github.com/wizzense/AitherZero/actions/workflows/jekyll-gh-pages.yml

# Check deployment logs
# Actions → Latest run → View jobs → deploy
```

### Test Deployment
```bash
# Access your branch
curl -I https://wizzense.github.io/AitherZero/dev-staging/

# Should return: HTTP/2 200
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **404 Error** | Wait 5-10 min for CDN propagation |
| **Permission Error** | Settings → Actions → Read and write permissions |
| **Environment Block** | ✅ Fixed! Uses peaceiris action now |
| **Wrong Content** | Clear cache (Ctrl+F5) |

## Documentation

- **User Guide**: [deployments.md](../deployments.md)
- **Technical**: [docs/BRANCH-DEPLOYMENTS.md](BRANCH-DEPLOYMENTS.md)
- **Testing**: [docs/TESTING-BRANCH-DEPLOYMENTS.md](TESTING-BRANCH-DEPLOYMENTS.md)
- **Architecture**: [docs/DEPLOYMENT-ARCHITECTURE.md](DEPLOYMENT-ARCHITECTURE.md)
- **Summary**: [BRANCH-DEPLOYMENT-SUMMARY.md](../BRANCH-DEPLOYMENT-SUMMARY.md)

## Key Changes

✅ **Problem**: dev-staging blocked by environment protection  
✅ **Solution**: Branch-specific subdirectory deployments  
✅ **Result**: All branches deploy independently  

## File Layout

```
gh-pages branch:
├── / (main)
├── /dev/
├── /dev-staging/  ← Now works!
├── /develop/
└── /ring-*/
```

## Workflow

1. **Push to branch** → Triggers workflow
2. **Setup job** → Determines config
3. **Build job** → Creates Jekyll site
4. **Deploy job** → Publishes to subdirectory
5. **Result** → Available at branch URL

---

**Status**: ✅ Production Ready  
**Version**: 2.0  
**Date**: 2025-11-09
