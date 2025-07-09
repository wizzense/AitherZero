# Experience Domain Tests

This directory contains tests for the Experience domain, which consolidates user experience and setup automation functionality.

## Domain Overview

The Experience domain consolidates the following legacy modules:
- **SetupWizard** - Intelligent setup automation with installation profiles
- **StartupExperience** - Interactive startup and configuration management

**Total Functions: 22**

## Function Reference

### Setup Automation (11 functions)
- `Start-IntelligentSetup` - Start intelligent setup process with profile selection
- `Get-PlatformInfo` - Get comprehensive platform information
- `Show-WelcomeMessage` - Display welcome message with branding
- `Show-SetupBanner` - Show setup banner with progress information
- `Get-InstallationProfile` - Get installation profile configuration
- `Show-EnhancedInstallationProfile` - Display enhanced installation profile details
- `Get-SetupSteps` - Get setup steps for selected profile
- `Show-EnhancedProgress` - Show enhanced progress with ETA and visual indicators
- `Show-SetupPrompt` - Show interactive setup prompts
- `Show-SetupSummary` - Display setup completion summary
- `Invoke-ErrorRecovery` - Handle setup errors with recovery options

### Interactive Experience (11 functions)
- `Start-InteractiveMode` - Start interactive mode with menu system
- `Get-StartupMode` - Determine startup mode (interactive, auto, setup)
- `Show-Banner` - Display application banner
- `Initialize-TerminalUI` - Initialize terminal UI enhancements
- `Reset-TerminalUI` - Reset terminal UI to default state
- `Test-EnhancedUICapability` - Test enhanced UI capabilities
- `Show-ContextMenu` - Show context-sensitive menus
- `Edit-Configuration` - Interactive configuration editing
- `Review-Configuration` - Review configuration changes
- `Generate-QuickStartGuide` - Generate platform-specific quick start guide
- `Find-ProjectRoot` - Find project root directory

## Test Categories

### Unit Tests
- **Setup Automation Tests** - Test setup process and profile management
- **Interactive Experience Tests** - Test interactive mode and UI components
- **Platform Detection Tests** - Test platform information and capabilities
- **Configuration Tests** - Test configuration editing and review
- **Error Recovery Tests** - Test error handling and recovery scenarios

### Integration Tests
- **End-to-End Setup Tests** - Test complete setup workflows
- **Cross-Platform Tests** - Test functionality across operating systems
- **UI Integration Tests** - Test UI component interactions
- **Configuration Integration Tests** - Test configuration management integration

### User Experience Tests
- **Usability Tests** - Test user interaction flows
- **Accessibility Tests** - Test accessibility features
- **Performance Tests** - Test UI responsiveness and performance
- **Workflow Tests** - Test user workflow completion

## Test Execution

### Run All Experience Domain Tests
```powershell
# Run all experience tests
./tests/Run-Tests.ps1 -Domain experience

# Run specific test categories
./tests/Run-Tests.ps1 -Domain experience -Category unit
./tests/Run-Tests.ps1 -Domain experience -Category integration
./tests/Run-Tests.ps1 -Domain experience -Category experience
```

### Run Individual Test Files
```powershell
# Run main experience tests
Invoke-Pester ./tests/domains/experience/Experience.Tests.ps1

# Run with coverage
Invoke-Pester ./tests/domains/experience/Experience.Tests.ps1 -CodeCoverage
```

## Expected Test Results

### Coverage Targets
- **Function Coverage**: 95% (21/22 functions)
- **Line Coverage**: 90%
- **Branch Coverage**: 85%

### Performance Targets
- **Setup Operations**: < 2 seconds
- **UI Operations**: < 500ms
- **Configuration Operations**: < 1 second
- **Menu Operations**: < 200ms

### Compatibility Targets
- **Windows**: 100% pass rate
- **Linux**: 100% pass rate
- **macOS**: 100% pass rate

## Legacy Module Compatibility

### Migration from SetupWizard
The experience domain maintains backward compatibility with SetupWizard functions:
- All existing setup automation functions are available
- Installation profile configurations are preserved
- Progress tracking and error recovery are maintained

### Migration from StartupExperience
Startup experience functionality is integrated:
- All interactive mode functions are available
- Menu system and UI components are preserved
- Configuration management workflows are maintained

## Common Test Scenarios

### 1. Setup Process Testing
```powershell
# Test complete setup process
$platformInfo = Get-PlatformInfo
$profile = Get-InstallationProfile -ProfileName "developer"
$steps = Get-SetupSteps -Profile $profile
$result = Start-IntelligentSetup -Profile $profile
```

### 2. Interactive Mode Testing
```powershell
# Test interactive mode
Initialize-TerminalUI
$startupMode = Get-StartupMode
Start-InteractiveMode -Mode $startupMode
Reset-TerminalUI
```

### 3. Configuration Management Testing
```powershell
# Test configuration editing
$config = Edit-Configuration -ConfigPath "test-config.json"
Review-Configuration -Configuration $config
$guide = Generate-QuickStartGuide -Configuration $config
```

### 4. Error Recovery Testing
```powershell
# Test error recovery
try {
    # Simulate setup error
    throw "Test error"
} catch {
    $recovery = Invoke-ErrorRecovery -Error $_ -Context "setup"
}
```

## Special Test Considerations

### Terminal UI Testing
- Tests may require specific terminal capabilities
- Mock terminal implementations are used for automated testing
- Cross-platform terminal behavior is tested

### Interactive Testing
- Some tests may require user interaction simulation
- Mock input/output streams are used for automated testing
- User experience flows are tested programmatically

### Platform-Specific Features
- Terminal capabilities vary by platform
- Enhanced UI features may not be available on all platforms
- Platform detection is used to skip unsupported features

## Troubleshooting

### Common Test Issues
1. **Terminal Issues** - Ensure terminal supports required features
2. **UI Issues** - Check UI capability detection and fallbacks
3. **Platform Issues** - Verify platform-specific feature availability
4. **Input Issues** - Ensure proper input stream handling

### Debug Commands
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Test UI capabilities
Test-EnhancedUICapability

# Get platform information
Get-PlatformInfo

# Check startup mode
Get-StartupMode
```

## Contributing

### Adding New Tests
1. Follow the existing test structure
2. Consider cross-platform compatibility
3. Handle interactive elements appropriately
4. Test error conditions and edge cases
5. Ensure proper UI cleanup

### Test Guidelines
- Test all function parameters and variations
- Include both positive and negative test cases
- Test error conditions and recovery scenarios
- Verify cross-platform compatibility
- Test performance and responsiveness
- Test user experience flows
- Handle terminal and UI variations appropriately