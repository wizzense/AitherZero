# Aitherium™ Branding Guidelines

## Overview
This document outlines the branding guidelines for the Aitherium™ AitherZero platform, ensuring consistent visual identity across all components.

## Brand Elements

### Logo
- **Primary Logo**: Located at `assets/branding/aitherium-logo.png`
- **Usage**: Use in documentation headers, reports, and presentations
- **Minimum Size**: 100px width for digital displays
- **Clear Space**: Maintain clear space equal to 25% of logo height on all sides

### Brand Name
- **Full Name**: Aitherium™ Enterprise Infrastructure Automation Platform
- **Product Name**: AitherZero
- **Always Include**: ™ symbol when referring to Aitherium

## Color Palette

### Gradient Theme
The Aitherium brand uses a distinctive gradient from light blue to light pink:

```css
/* Primary Gradient */
background: linear-gradient(135deg, #add8e6 0%, #e0bbf0 50%, #ffb6c1 100%);
```

### Color Values
| Color Name | RGB | Hex | Usage |
|------------|-----|-----|-------|
| Light Blue | 173, 216, 230 | #ADD8E6 | Start of gradient |
| Blue-Cyan | 185, 209, 234 | #B9D1EA | Gradient transition |
| Cyan-Lavender | 197, 202, 238 | #C5CAEE | Gradient midpoint |
| Lavender | 209, 195, 242 | #D1C3F2 | Gradient midpoint |
| Lavender-Pink | 221, 188, 246 | #DDBCF6 | Gradient transition |
| Light Purple-Pink | 233, 181, 250 | #E9B5FA | Gradient transition |
| Pink-Purple | 245, 174, 254 | #F5AEFE | Gradient transition |
| Light Pink | 255, 182, 193 | #FFB6C1 | End of gradient |

## Terminal/Console Branding

### ASCII Banner with Gradient
The platform uses ANSI escape codes to display a gradient-colored banner in PowerShell:

```powershell
# Each line gets a different color from the gradient
$gradientColors = @(
    "`e[38;2;173;216;230m",  # Light Blue
    "`e[38;2;185;209;234m",  # Blue-Cyan
    "`e[38;2;197;202;238m",  # Cyan-Lavender
    "`e[38;2;209;195;242m",  # Lavender
    "`e[38;2;221;188;246m",  # Lavender-Pink
    "`e[38;2;233;181;250m",  # Light Purple-Pink
    "`e[38;2;245;174;254m",  # Pink-Purple
    "`e[38;2;255;182;193m"   # Light Pink
)
```

### Banner Text
```
    _    _ _   _               ______               
   / \  (_) |_| |__   ___ _ __|__  /___ _ __ ___   
  / _ \ | | __| '_ \ / _ \ '__| / // _ \ '__/ _ \  
 / ___ \| | |_| | | |  __/ |   / /|  __/ | | (_) | 
/_/   \_\_|\__|_| |_|\___|_|  /____\___|_|  \___/  
                                                    
        Aitherium™ Automation Platform v1.0
        PowerShell 7 | Cross-Platform | Orchestrated
```

## HTML Reports

### Header Styling
All HTML reports should include the gradient header:

```html
<div class="header" style="background: linear-gradient(135deg, #add8e6 0%, #e0bbf0 50%, #ffb6c1 100%);">
    <div class="header-content">
        <h1>[Report Title]</h1>
        <div class="brand">Aitherium™ AitherZero Platform</div>
        <div class="timestamp">Generated: [DateTime]</div>
    </div>
</div>
```

### Footer
Include branded footer in all reports:

```html
<div style="background: linear-gradient(135deg, #add8e6 0%, #e0bbf0 50%, #ffb6c1 100%);">
    Powered by <strong>Aitherium™</strong> Enterprise Infrastructure Automation Platform<br>
    © 2025 Aitherium Corporation - AitherZero v1.0
</div>
```

## Module Headers

### PowerShell Module Template
All PowerShell modules should include this header:

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    [Module Name and Purpose]
.DESCRIPTION
    Aitherium™ Enterprise Infrastructure Automation Platform
    [Module Description]
.NOTES
    Copyright © 2025 Aitherium Corporation
#>
```

## Documentation

### README Header
The main README.md should include:

```markdown
<p align="center">
  <img src="assets/branding/aitherium-logo.png" alt="Aitherium Logo" width="200"/>
</p>

<h1 align="center">AitherZero</h1>

<p align="center">
  <strong>Aitherium™ Enterprise Infrastructure Automation Platform</strong>
</p>
```

## Usage Guidelines

### Do's
- ✅ Always use the gradient color scheme for headers and banners
- ✅ Include the ™ symbol when writing "Aitherium™"
- ✅ Use consistent branding across all output formats
- ✅ Maintain the gradient direction (135deg) for consistency
- ✅ Include copyright notice in generated reports

### Don'ts
- ❌ Don't alter the gradient colors
- ❌ Don't use the logo on dark backgrounds without adjustment
- ❌ Don't modify the ASCII art banner structure
- ❌ Don't omit the trademark symbol
- ❌ Don't use conflicting color schemes

## Implementation Files

### Key Files with Branding
1. `/Start-AitherZero.ps1` - Show-Banner function with gradient
2. `/domains/reporting/ReportingEngine.psm1` - HTML report templates
3. `/README.md` - Main documentation with logo
4. `/AitherZero.psm1` - Root module with copyright
5. All domain modules - Header with Aitherium branding

## Contact
For branding questions or asset requests, please refer to the Aitherium Corporation brand guidelines.

---
*Last Updated: 2025*
*Copyright © 2025 Aitherium Corporation*