## 🚀 PR Ecosystem Report

**Generated**: 2025-11-08 15:01:43 UTC  
**PR**: # -   
**Commit**: [d8f87ce5]()

---
### 📊 Quick Stats

| Metric | Value |
|--------|-------|
| 🧪 Tests | / passed |
| 📝 Quality | /100 |
| 📦 Files Changed |  |
| ➕ Additions | + |
| ➖ Deletions | - |

---
### 🐳 Docker Container

**Image**: `ghcr.io/wizzense/aitherzero:pr--latest`  
**Port**: 8080 (formula: 8080 + PR# % 100)

```bash
# Pull the latest PR container
docker pull ghcr.io/wizzense/aitherzero:pr--latest

# Run interactively
docker run -it --rm \
  -p 8080:8080 \
  -e PR_NUMBER= \
  ghcr.io/wizzense/aitherzero:pr--latest

# Run in background
docker run -d \
  --name aitherzero-pr- \
  -p 8080:8080 \
  ghcr.io/wizzense/aitherzero:pr--latest
```

---
### 📊 Dashboard & Reports

- **[📊 Full Dashboard](https://wizzense.github.io/AitherZero/pr-/)** - Comprehensive metrics and analysis
- **[📈 Test Results](https://wizzense.github.io/AitherZero/pr-/reports/tests.html)** - Detailed test execution data
- **[📋 Coverage Report](https://wizzense.github.io/AitherZero/pr-/reports/coverage/)** - Code coverage visualization
- **[📝 Changelog](https://wizzense.github.io/AitherZero/pr-/reports/CHANGELOG-PR.md)** - Commit history with categorization

---
### ⚡ Quick Actions

- 🔍 [View Full Dashboard](https://wizzense.github.io/AitherZero/pr-/)
- 🐳 [Container Registry](https://github.com/wizzense/AitherZero/pkgs/container/aitherzero)
- 📦 [Download Artifacts](https://github.com/wizzense/AitherZero/actions/runs/19194605244)
- 🔄 [Workflow Run](https://github.com/wizzense/AitherZero/actions/runs/19194605244)
- 📚 [Documentation](https://github.com/wizzense/AitherZero#readme)

---
*🤖 Automated by [AitherZero PR Ecosystem](https://github.com/wizzense/AitherZero) • Powered by native orchestration*
