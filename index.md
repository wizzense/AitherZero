---
layout: default
title: AitherZero Project Dashboard
---

<style>
/* Component-specific styles - colors handled by main stylesheet */
.badge-container {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 20px 0;
  justify-content: center;
}
.badge-container img {
  height: 22px;
}
.card {
  border-radius: 8px;
  padding: 24px;
  margin: 24px 0;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.card:hover {
  transform: translateY(-2px);
}
.card h3 {
  margin-top: 0;
  font-size: 1.4rem;
}
.highlight-box {
  padding: 40px 30px;
  border-radius: 16px;
  margin: 0 0 30px 0;
  text-align: center;
  position: relative;
  overflow: hidden;
}
.highlight-box::before {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
  animation: rotate 20s linear infinite;
}
@keyframes rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
@media (prefers-reduced-motion: reduce) {
  .highlight-box::before {
    animation: none;
  }
}
.highlight-box h1 {
  margin: 0 0 15px 0;
  font-size: 3rem;
  font-weight: 800;
  position: relative;
  z-index: 1;
  text-shadow: 0 2px 8px rgba(0,0,0,0.3);
}
.highlight-box p {
  position: relative;
  z-index: 1;
  color: rgba(255,255,255,0.95) !important;
}
.highlight-box .subtitle {
  font-size: 1.3rem;
  font-weight: 500;
  margin-bottom: 10px;
}
.highlight-box .tagline {
  font-size: 1rem;
  opacity: 0.9;
}
.quick-links {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 15px;
  margin: 24px 0;
}
.quick-link {
  border-radius: 10px;
  padding: 18px;
  text-align: center;
  text-decoration: none;
  font-weight: 600;
  transition: all 0.3s ease;
  font-size: 1.05rem;
}
.quick-link:hover {
  transform: translateY(-3px);
  text-decoration: none !important;
}
</style>

<div class="highlight-box">
  <h1>🚀 AitherZero</h1>
  <p class="subtitle">Infrastructure Automation Platform</p>
  <p class="tagline">Number-based orchestration system for systematic infrastructure automation</p>
</div>

<div class="badge-container">
  <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/intelligent-ci-orchestrator.yml?label=CI%2FCD&logo=github" alt="CI/CD Status">
  <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/pr-validation.yml?label=PR%20Validation&logo=github" alt="PR Validation">
  <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/quality-validation.yml?label=Quality&logo=github" alt="Quality Check">
  <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/jekyll-gh-pages.yml?label=GitHub%20Pages&logo=github" alt="GitHub Pages">
  <img src="https://img.shields.io/badge/PowerShell-7.0+-blue?logo=powershell" alt="PowerShell Version">
  <img src="https://img.shields.io/github/license/wizzense/AitherZero" alt="License">
  <img src="https://img.shields.io/github/last-commit/wizzense/AitherZero" alt="Last Commit">
  <img src="https://img.shields.io/github/stars/wizzense/AitherZero" alt="Stars">
</div>

## 📊 Interactive Dashboard

<div class="quick-links">
  <a href="reports/dashboard.html" class="quick-link">
    📈 View Live Dashboard
  </a>
  <a href="https://github.com/wizzense/AitherZero" class="quick-link">
    🏠 GitHub Repository
  </a>
  <a href="https://github.com/wizzense/AitherZero/actions" class="quick-link">
    ⚡ CI/CD Pipeline
  </a>
  <a href="https://github.com/wizzense/AitherZero/releases" class="quick-link">
    📦 Releases
  </a>
</div>

<div class="card">
  <h3>🎯 Key Features</h3>
  <ul>
    <li><strong>Number-Based Orchestration (0000-9999):</strong> Systematic script execution with predictable ordering</li>
    <li><strong>Domain-Based Architecture:</strong> 11 consolidated domains including AI-Agents, Infrastructure, Testing, and more</li>
    <li><strong>Comprehensive Testing:</strong> 108+ tests with unit and integration coverage</li>
    <li><strong>Intelligent CI/CD:</strong> Automated workflows with AI-powered issue management</li>
    <li><strong>Cross-Platform Support:</strong> PowerShell 7.0+ on Windows, Linux, and macOS</li>
    <li><strong>Real-Time Dashboards:</strong> Interactive monitoring and reporting</li>
  </ul>
</div>

## 📈 Latest Reports & Analysis

<div class="card">
  <h3>📊 Dashboard & Metrics</h3>
  <ul>
    <li><a href="reports/dashboard.html"><strong>Interactive Dashboard</strong></a> - Real-time project metrics, module information, and CI/CD status</li>
    <li><a href="reports/VALIDATION-FINAL-SUMMARY.md">Validation Summary</a> - Comprehensive project validation results</li>
    <li><a href="reports/PR-DOCKER-DEPLOYMENT-VALIDATION.md">Docker Deployment</a> - Container deployment validation</li>
  </ul>
</div>

<div class="card">
  <h3>🔍 Code Quality & Testing</h3>
  <ul>
    <li><a href="reports/psscriptanalyzer-fast-results.json">PSScriptAnalyzer Results</a> - Static code analysis</li>
    <li><a href="reports/">Test Reports</a> - Automated test execution results</li>
    <li><a href="reports/tech-debt/">Technical Debt Tracking</a> - Prioritized improvement items</li>
  </ul>
</div>

## 🏗️ Architecture Overview

AitherZero uses a **consolidated domain-based module system** with the following structure:

- **🤖 AI-Agents** - Intelligent automation agents
- **⚙️ Automation** - Orchestration engine and workflows
- **🔧 Configuration** - Environment and settings management
- **💻 Development** - Git automation and development tools
- **📚 Documentation** - Automated documentation generation
- **🎨 Experience** - UI components and user interface
- **🏢 Infrastructure** - Cloud and on-premises infrastructure automation
- **📊 Reporting** - Dashboards and metrics collection
- **🔒 Security** - Credentials, certificates, and security tools
- **🧪 Testing** - Comprehensive testing framework
- **🛠️ Utilities** - Cross-platform helpers and logging

## 🚀 Quick Start

```powershell
# Initialize environment (always run first in new sessions)
./Initialize-AitherEnvironment.ps1

# Start interactive menu
./Start-AitherZero.ps1

# Run numbered automation scripts
./az 0402  # Run unit tests
./az 0404  # Run PSScriptAnalyzer
./az 0510  # Generate project report
./az 0512  # Generate dashboard
```

## 🔗 Essential Links

<div class="quick-links">
  <a href="https://github.com/wizzense/AitherZero/blob/main/README.md" class="quick-link">
    📄 README
  </a>
  <a href="https://github.com/wizzense/AitherZero/issues" class="quick-link">
    🐛 Issues
  </a>
  <a href="https://github.com/wizzense/AitherZero/pulls" class="quick-link">
    🔀 Pull Requests
  </a>
  <a href="https://github.com/wizzense/AitherZero/wiki" class="quick-link">
    📖 Wiki
  </a>
</div>

## 🤖 Intelligent Automation

AitherZero features **AI-powered automation** that automatically:

- ✅ Creates issues from test failures and code quality problems
- 🔍 Analyzes CI/CD runs and provides actionable insights
- 📝 Generates comprehensive reports and documentation
- 🚨 Detects security vulnerabilities and performance issues
- 🔄 Optimizes workflow execution based on changes

View [automated issues](https://github.com/wizzense/AitherZero/issues?q=is:issue+label:automated-issue) created by the intelligent analyzer.

## 📈 Project Statistics

The dashboard provides real-time metrics including:

- **177 Project Files** (121 scripts, 47 modules, 9 data files)
- **69,338 Lines of Code** across the codebase
- **51 Exported Functions** from the module manifest
- **108 Tests** (100 unit, 8 integration)
- **11 Domain Modules** in consolidated architecture

---

<div style="text-align: center; color: #666; margin-top: 40px;">
  <p><em>Last updated: {{ site.time | date: '%Y-%m-%d %H:%M:%S UTC' }}</em></p>
  <p>Generated by AitherZero Automation Platform</p>
</div>
