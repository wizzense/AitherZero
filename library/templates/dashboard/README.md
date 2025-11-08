# Dashboard HTML Templates

This directory contains HTML, CSS, and JavaScript templates for the AitherZero dashboard generator (script 0512).

## Purpose

HTML and JavaScript code should **not** be embedded directly in PowerShell scripts as it causes syntax parsing issues. Instead, templates are stored here and loaded by the dashboard generator.

## Files

- `dashboard.html` - Main HTML structure with placeholders
- `styles.css` - All CSS styling
- `scripts.js` - All JavaScript functionality
- `README.md` - This file

## Template Placeholders

The HTML template uses the following placeholders that are replaced by PowerShell:

- `{{CSS}}` - Replaced with contents of styles.css wrapped in `<style>` tags
- `{{JAVASCRIPT}}` - Replaced with contents of scripts.js wrapped in `<script>` tags
- `{{TOC}}` - Table of contents sidebar
- `{{HEADER}}` - Dashboard header section
- `{{CONTENT}}` - Main dashboard content (metrics, charts, etc.)
- `{{FOOTER}}` - Dashboard footer

## Usage

The PowerShell script loads these templates and performs string replacement:

```powershell
$templatePath = Join-Path $ProjectPath "templates/dashboard"
$htmlTemplate = Get-Content (Join-Path $templatePath "dashboard.html") -Raw
$cssContent = Get-Content (Join-Path $templatePath "styles.css") -Raw
$jsContent = Get-Content (Join-Path $templatePath "scripts.js") -Raw

$html = $htmlTemplate -replace '{{CSS}}', "<style>$cssContent</style>" `
                      -replace '{{JAVASCRIPT}}', "<script>$jsContent</script>" `
                      -replace '{{CONTENT}}', $generatedContent
```

## Benefits

1. **Syntax Safety**: No PowerShell parser issues with HTML/JS
2. **Maintainability**: Easier to edit HTML/CSS/JS in proper files
3. **IDE Support**: Full syntax highlighting and IntelliSense
4. **Testing**: Can test templates independently
5. **Reusability**: Templates can be shared across scripts

## Modifying Templates

When modifying templates:

1. Edit the appropriate template file (`.html`, `.css`, or `.js`)
2. Test the dashboard generator: `./az 0512`
3. View the generated dashboard to verify changes
4. Commit template changes along with any script updates
