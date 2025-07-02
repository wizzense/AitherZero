# Changelog

All notable changes to AitherZero will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.3] - 2025-07-02

### Fixed
- Fixed module dependency circular references that prevented startup
- Removed RequiredModules for Logging from ConfigurationCore, ModuleCommunication, and ProgressTracking
- Removed RequiredModules for LicenseManager from StartupExperience
- Added LicenseManager to priority module loading list
- Fixed regression that reintroduced v1.4.0 startup issues in v1.4.2

### Technical Details
- Module manifests now properly declare dependencies without circular references
- Module loading order ensures core dependencies (Logging, LicenseManager) load first
- PSCustomObject to Hashtable conversion fix from v1.4.1 is preserved

## [1.4.2] - 2025-07-02

### Added
- Enhanced menu system with comprehensive improvements
- Multi-column layout that adapts to terminal width (up to 3 columns)
- Support for 4-digit script prefix execution (e.g., `0200`)
- Script name execution with case-insensitive matching (e.g., `Get-SystemInfo`)
- Module name direct access (e.g., `patchmanager`)
- Comma-separated batch execution (e.g., `0200,0201,0202`)
- Improved menu formatting with compact banner and version display
- Shows both index and prefix for scripts (e.g., `[45/0200]`)
- Clear input instructions displayed at all times
- Partial name matching for convenience

### Changed
- Complete rewrite of `Show-DynamicMenu.ps1` for enhanced functionality
- New input parsing engine in `Process-MenuInput` function
- Flexible item lookup via `Find-MenuItem` function
- Better visual separation between categories

### Fixed
- Menu display spacing and alignment issues
- Support for multiple input methods simultaneously

## [1.4.1] - 2025-07-02

### Fixed
- Critical module dependency issues preventing startup
- Fixed Logging module version mismatches (now v2.0.0 with correct GUID)
- Fixed PSCustomObject to Hashtable conversion error in aither-core.ps1
- Made ActiveDirectory dependency optional in SecurityAutomation module
- Fixed LicenseManager dependency in StartupExperience
- Ensured proper module loading order with Logging loading first

### Changed
- Module manifests updated to resolve circular dependencies
- Improved error handling for missing optional dependencies

## [1.4.0] - 2025-07-02

### Added
- PatchManager v3.0 with atomic operations framework
- Eliminated git stashing to prevent merge conflicts
- Multi-mode operation system (Simple/Standard/Advanced)
- Automatic rollback on operation failures
- Enhanced error recovery mechanisms

### Changed
- Complete refactor of PatchManager to prevent merge conflicts
- Improved Git operations with better conflict detection
- Enhanced branch management and synchronization

### Fixed
- Persistent merge conflicts caused by git stashing
- Branch divergence issues
- Partial state problems during patch operations

## [1.3.0] - 2025-06-30

### Added
- SetupWizard module for intelligent first-time setup
- ProgressTracking module for visual operation feedback
- Installation profiles (minimal, developer, full)
- Platform-specific quick start guides

### Changed
- Enhanced startup experience with better guidance
- Improved module discovery and loading
- Better cross-platform compatibility

## [1.2.0] - 2025-06-15

### Added
- ConfigurationCarousel for multi-environment configuration management
- ConfigurationRepository for Git-based configuration storage
- OrchestrationEngine for advanced workflow execution
- AIToolsIntegration for Claude Code and Gemini CLI support

### Changed
- Improved configuration management architecture
- Enhanced module communication system
- Better error handling and logging

## [1.1.0] - 2025-05-30

### Added
- Initial stable release of AitherZero
- Core module system with 27 specialized modules
- OpenTofu/Terraform infrastructure automation
- Git workflow automation with PatchManager
- Comprehensive testing framework
- Cross-platform support (Windows, Linux, macOS)

### Changed
- Stabilized core architecture
- Improved module loading system
- Enhanced documentation

## [1.0.0] - 2025-05-01

### Added
- Initial release of AitherZero framework
- Basic module system
- Core automation capabilities
- PowerShell 7.0+ support

---

[1.4.3]: https://github.com/wizzense/AitherZero/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/wizzense/AitherZero/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/wizzense/AitherZero/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/wizzense/AitherZero/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/wizzense/AitherZero/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/wizzense/AitherZero/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/wizzense/AitherZero/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/wizzense/AitherZero/releases/tag/v1.0.0