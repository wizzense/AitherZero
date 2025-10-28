---
layout: default
title: AitherZero Project Dashboard
---

# AitherZero Project Dashboard

Welcome to the AitherZero infrastructure automation platform. This page provides access to automated test reports, analysis results, and project metrics.

## 📊 Latest Reports

### Test Reports
- [Latest Dashboard](reports/dashboard.html) - Interactive project dashboard with metrics
- [Project Report](reports/VALIDATION-FINAL-SUMMARY.md) - Comprehensive validation summary
- [Docker Deployment Validation](reports/PR-DOCKER-DEPLOYMENT-VALIDATION.md) - PR deployment status

### Analysis Results
- [PSScriptAnalyzer Results](reports/psscriptanalyzer-fast-results.json) - Code quality analysis
- [Test Reports](reports/) - Browse all test execution reports

### Technical Debt
- [Tech Debt Tracking](reports/tech-debt/) - Technical debt items and priorities

## 🔗 Quick Links

- [GitHub Repository](https://github.com/wizzense/AitherZero)
- [Issues](https://github.com/wizzense/AitherZero/issues)
- [Pull Requests](https://github.com/wizzense/AitherZero/pulls)
- [Actions Workflows](https://github.com/wizzense/AitherZero/actions)

## 📈 CI/CD Status

Visit the [Actions](https://github.com/wizzense/AitherZero/actions) page to see the latest workflow runs and their status.

## 🤖 Automated Issue Tracking

Issues are automatically created from:
- Test failures detected by CI runs
- PSScriptAnalyzer code quality issues
- Security vulnerabilities
- Performance regressions

View [automated issues](https://github.com/wizzense/AitherZero/issues?q=is:issue+label:automated-issue) created by the intelligent report analyzer.

---
*Last updated: {{ site.time | date: '%Y-%m-%d %H:%M:%S UTC' }}*
