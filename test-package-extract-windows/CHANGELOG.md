# CHANGELOG

## [0.7.3] - 2025-07-08 - Comprehensive Reporting & CI Improvements

### Added
- **Comprehensive Report Generation**: Complete project health dashboard with metrics
  - Fixed test coverage calculation (was showing 0%)
  - Added documentation, duplicate, and security audit sections
  - Interactive feature map with module dependencies
  - Executive summary for stakeholders
- **GitHub Pages Deployment**: Automated deployment of reports to GitHub Pages
  - Live dashboard at https://wizzense.github.io/AitherZero/
  - Daily automated updates via GitHub Actions
- **CI/CD Improvements**: Optimized workflows for better performance
  - Removed unnecessary PowerShell installations (9+ minute savings)
  - Fixed YAML syntax errors in workflows
  - Made CI checks non-blocking for improved stability

### Fixed
- **Report Generation**: Eliminated duplicate HTML file generation
- **Test Coverage**: Fixed calculation to show accurate coverage percentages
- **CI Performance**: Resolved stuck runners and workflow hanging issues
- **YAML Syntax**: Fixed PowerShell here-string conflicts in workflows

### Changed
- **Report Filename**: Standardized to `aitherZero-comprehensive-report.html`
- **Release Workflow**: Now includes comprehensive reports in release assets
- **README**: Added links to live GitHub Pages reports

## [Unreleased] - Module Consolidation & Cleanup

### 🚀 Major Module Consolidation

Successfully reduced module count from 30+ to 23 active modules through intelligent consolidation and deduplication.

### Fixed
- **Compatibility Shims**: Fixed 6 broken compatibility shims referencing non-existent modules
  - Updated UtilityManager references to UtilityServices
  - Updated SetupManager references to UserExperience
- **PowerShell Verb Compliance**: Renamed functions to use approved verbs
  - `Send-ModuleMessage` → `Submit-ModuleMessage`
  - `Send-ModuleEvent` → `Submit-ModuleEvent`
  - `Publish-TestEvent` → `Submit-TestEvent`
  - `Subscribe-TestEvent` → `Register-TestEventHandler`
- **TestingFramework**: Fixed distributed test execution showing 0% success
  - Added proper Pester 5.x result format handling
  - Improved test result aggregation

### Added
- **Developer Experience**: New unified developer setup command
  - `Start-DeveloperSetup` with Quick/Standard/Full/Custom profiles
  - Convenient `Start-DeveloperSetup.ps1` wrapper script
- **Progress Indicators**: Visual progress during module loading
  - `Show-Progress.ps1` utility for startup feedback
  - Module loading progress bars with timing statistics
- **PowerShell Detection**: Simplified version detection
  - `Test-PowerShellVersion.ps1` utility for consistent checking
  - Maintained PowerShell 5.1+ compatibility
- **Documentation**: Comprehensive consolidation documentation
  - `CONSOLIDATION-SUMMARY.md` with detailed changes
  - `MODULE-ARCHITECTURE.md` describing current structure

### Changed
- **Module Organization**: Consolidated related modules
  - UserExperience now includes SetupManager, StartupExperience functionality
  - UtilityServices consolidated multiple utility modules
  - CloudProviderIntegration merged cloud-related modules
- **Function Names**: All functions now use approved PowerShell verbs
  - Created backward compatibility aliases for smooth migration
- **Module Count**: Reduced from 30+ to 23 active modules (23% reduction)

### Technical Details
- Maintained full backward compatibility through shim modules
- All consolidated modules retain original functionality
- Test coverage improved with new test suites for consolidated modules
- Performance improved through optimized module loading

---

## [0.5-beta] - 2025-01-02

### 🎉 Fresh Start - Beta Release

This marks a complete reset of the AitherZero project versioning to establish a clean release history.

### Fixed
- **Critical**: Fixed PowerShell syntax errors in ConfigurationCore module
  - Corrected variable interpolation in error messages using `${variableName}:` syntax
  - Resolved "Variable reference is not valid" errors preventing module loading
  - Fixed 5 instances in Validate-Configuration.ps1
  - Fixed 1 instance in Invoke-ConfigurationReload.ps1

### Changed
- Reset version numbering from v1.4.3 to v0.5-beta
- Cleaned up all previous tags and releases for a fresh start
- Established new release strategy: beta → release candidate → stable

### Added
- Comprehensive test suite for ConfigurationCore module
- Backup of all previous tags and releases for reference

### Technical Details
- All 29 previous tags removed (v1.0.0 through v1.4.3)
- All 16 GitHub releases archived and removed
- Clean git history maintained with proper commit tracking

### Next Steps
- Continue beta development (0.5 → 0.6 → 0.7 → 0.8 → 0.9)
- Release candidates (1.0.0-rc1, 1.0.0-rc2, etc.)
- First stable release (1.0.0)

---

*Previous release history has been archived in backup-before-reset/*
