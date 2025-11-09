---
layout: default
title: AitherZero - Infrastructure Automation Platform
---

# 🎯 AitherZero Project Dashboard

**Last Updated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Version:** 1.0.0.0
**Branch:** copilot/full-validation-and-deployment

## 🚀 Quick Links

- [📊 **Comprehensive Dashboard**](library/reports/dashboard.html) - Real-time metrics and project health
- [📚 **Documentation**](README.md) - Platform documentation
- [🧪 **Test Results**](library/tests/results/) - Latest test execution data
- [📈 **Reports**](library/reports/) - All generated reports

---

## 📦 About AitherZero

AitherZero is a comprehensive infrastructure automation platform built on PowerShell 7+ with a unique number-based orchestration system (0000-9999) for systematic script execution.

### Key Features

- **Infrastructure as Code**: OpenTofu/Terraform integration
- **VM Management**: Hyper-V lab automation
- **Testing Framework**: Comprehensive Pester-based testing
- **Orchestration**: Playbook-driven automation
- **AI Integration**: GitHub Copilot, MCP server support
- **Cross-Platform**: Windows, Linux, and macOS support

---

## 📊 Project Health

Visit the [**Dashboard**](library/reports/dashboard.html) for:

- ✅ Real-time project metrics
- 📈 Code quality scores
- 🧪 Test execution results
- 📚 Documentation coverage
- 🔍 PSScriptAnalyzer results

---

## 🏗️ Architecture

- **11 Functional Domains**: Modular architecture
- **175+ Automation Scripts**: Organized by number ranges
- **47 PowerShell Modules**: Domain-specific functionality  
- **362+ Test Files**: Comprehensive test coverage
- **22+ Playbooks**: Orchestrated workflows

---

## 🚀 Getting Started

### Quick Install

```powershell
# One-line install (PowerShell)
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex

# Or clone and bootstrap
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
./bootstrap.ps1 -Mode New -InstallProfile Minimal
```

### Docker

```bash
# Pull and run
docker pull ghcr.io/wizzense/aitherzero:latest
docker run -it --rm ghcr.io/wizzense/aitherzero:latest
```

---

## 📚 Resources

- [**GitHub Repository**](https://github.com/wizzense/AitherZero)
- [**Quick Reference**](QUICK-REFERENCE.md)
- [**Documentation Index**](DOCUMENTATION-INDEX.md)
- [**Strategic Roadmap**](STRATEGIC-ROADMAP.md)

---

*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
*Platform: AitherZero Infrastructure Automation*
