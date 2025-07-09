# StartupExperience Private Functions

This directory contains internal (private) functions for the StartupExperience module.

## Function Overview

### Terminal UI Management

- **Initialize-TerminalUI.ps1** - Terminal UI initialization and capability detection
  - Detects terminal capabilities (colors, ReadKey, UTF-8)
  - Applies themes (Dark, Light, HighContrast, Auto)
  - Handles graceful degradation to classic mode
  - Manages cursor control and window titles

### UI Components

- **Show-ContextMenu.ps1** - Context-sensitive menu display
- **Show-LicenseManager.ps1** - License management interface
- **Show-ProfileManager.ps1** - Profile management interface

## Implementation Details

### Terminal Capabilities
The `Initialize-TerminalUI.ps1` function performs comprehensive terminal detection:
- RawUI access availability
- Color support testing
- Cursor control capabilities
- ReadKey method availability
- UTF-8 encoding support
- Input/output redirection detection

### UI Modes
- **Enhanced Mode**: Full terminal features with arrow key navigation
- **Classic Mode**: Text-based numbered menus for compatibility

### Error Handling
Private functions implement comprehensive error handling:
- Graceful degradation when features unavailable
- Detailed logging for troubleshooting
- Fallback to working configurations
- State restoration on cleanup

## Cross-Platform Support

Functions are designed to work across:
- Windows PowerShell 5.1+ (limited features)
- PowerShell Core 6+ (full features)
- Different terminal environments (cmd, PowerShell ISE, VS Code, SSH)
- CI/CD environments (automatic classic mode)

## Performance Considerations

- Terminal capability detection is cached
- UI state is maintained in script variables
- Minimal overhead for classic mode
- Efficient redraw mechanisms for enhanced mode

## Security Notes

- No sensitive data stored in UI state
- Profile data handled securely
- License information displayed appropriately
- Safe cleanup of terminal state on exit