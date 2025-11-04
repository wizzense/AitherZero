# results

**Navigation**: [🏠 Root](../../index.md) → [tests](../index.md) → **results**

⬆️ **Parent**: [tests](../index.md)

## 📖 Overview

*This directory contains generated test execution results and analysis reports.*

### 📊 Contents

This directory stores auto-generated test artifacts including:

- **Unit test results**: XML reports from Pester test executions
- **Code coverage reports**: XML coverage data from test runs
- **PSScriptAnalyzer results**: CSV and JSON reports from static code analysis
- **Test summaries**: JSON summaries of test execution statistics

**Note**: Files in this directory are automatically generated during test execution and are not committed to version control (excluded via `.gitignore`).

### 🔄 Regeneration

Results files are created by running:
- `./automation-scripts/0402_Run-UnitTests.ps1` - Unit test results
- `./automation-scripts/0404_Run-PSScriptAnalyzer.ps1` - Static analysis results
- Various other test automation scripts

---

*Generated test artifacts directory* • Files are auto-generated and excluded from Git
