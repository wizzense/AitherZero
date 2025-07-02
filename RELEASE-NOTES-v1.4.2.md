# Release Notes - AitherZero v1.4.2

## 🚀 Enhanced Menu System

This release introduces comprehensive improvements to the AitherZero menu system, addressing all user feedback from v1.4.1.

### 🎨 Visual Improvements
- **Multi-Column Layout**: Menu items now display in up to 3 columns, utilizing horizontal space efficiently
- **Compact Banner**: Streamlined header with integrated version display
- **Better Spacing**: Improved alignment and formatting throughout the menu
- **Category Grouping**: Cleaner organization of modules by category

### 🔧 Input Enhancements
- **Menu Numbers**: Original functionality preserved (e.g., `3`)
- **4-Digit Prefixes**: Full support for legacy script prefixes (e.g., `0200`)
- **Script Names**: Case-insensitive name matching (e.g., `Get-SystemInfo`)
- **Module Names**: Direct module access (e.g., `patchmanager`)
- **Batch Execution**: Comma-separated inputs for multiple operations (e.g., `0200,0201,0202`)

### 📝 User Experience
- Shows both index and prefix for scripts (e.g., `[45/0200]`)
- Clear input instructions displayed at all times
- Partial name matching for convenience
- Enhanced help documentation with input examples

### 🛠️ Technical Changes
- Complete rewrite of `Show-DynamicMenu.ps1`
- New input parsing engine in `Process-MenuInput` function
- Flexible item lookup via `Find-MenuItem` function
- Efficient menu structure building with multiple lookup tables
- Full backward compatibility maintained

### 📋 Files Modified
- `/aither-core/shared/Show-DynamicMenu.ps1` - Complete rewrite with enhanced functionality
- `/Test-EnhancedMenu.ps1` - Test script for validating new features
- `/VERSION` - Updated to 1.4.2

### 🐛 Fixes from v1.4.1
All critical startup issues from v1.4.0 were resolved in v1.4.1:
- ✅ Fixed module dependency resolution
- ✅ Fixed PSCustomObject to Hashtable conversion
- ✅ Made ActiveDirectory dependency optional
- ✅ Fixed module loading order

### 💡 Example Usage

```powershell
# Launch AitherZero with enhanced menu
./Start-AitherZero.ps1

# Input examples in the menu:
# Single item by number
3

# Single item by 4-digit prefix
0200

# Single item by name
Get-SystemInfo

# Multiple items (comma-separated)
0200,0201,0202

# Mix of input types
3,0200,patchmanager
```

### 📊 Terminal Width Adaptation
- 80 chars: 1 column layout
- 120 chars: 2 column layout
- 160+ chars: 3 column layout (maximum)

### 🎯 Next Steps
After updating to v1.4.2:
1. Run AitherZero to experience the enhanced menu
2. Try different input methods (numbers, prefixes, names)
3. Test batch execution with comma-separated inputs
4. Enjoy the improved visual layout

---

**Full Changelog**: v1.4.1...v1.4.2