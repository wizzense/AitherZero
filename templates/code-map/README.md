# Code Map HTML Templates

This directory contains HTML, CSS, and JavaScript templates for the AitherZero interactive code map visualizer (script 0514).

## Purpose

HTML and JavaScript code should **not** be embedded directly in PowerShell scripts as it causes syntax parsing issues. Instead, templates are stored here and loaded by the code map generator.

## Files

- `code-map.html` - Main HTML structure with placeholders for CSS, JavaScript, and data
- `code-map.css` - All CSS styling for the interactive visualizer
- `code-map.js` - All JavaScript functionality for graphs, trees, and interactions
- `README.md` - This file

## Template Placeholders

The HTML template uses the following placeholders that are replaced by PowerShell:

- `{{CSS}}` - Replaced with contents of code-map.css wrapped in `<style>` tags
- `{{JAVASCRIPT}}` - Replaced with contents of code-map.js wrapped in `<script>` tags
- `{{DATA}}` - Replaced with JSON data about modules, functions, scripts, and their relationships

## Features

The code map visualizer provides:

1. **Multiple Visualization Views**:
   - Tree View - Hierarchical file structure
   - Graph View - Dependency and relationship graphs
   - Matrix View - Cross-reference matrix
   - Sunburst View - Circular hierarchical visualization

2. **Interactive Exploration**:
   - Search functionality for files and functions
   - Tabbed interface (Domains, Functions, Files, Stats)
   - Info panel with detailed metadata
   - Click-to-navigate functionality

3. **Code Analysis**:
   - Function dependencies and call graphs
   - Module relationships
   - File organization by domain
   - Usage statistics

## Usage

The PowerShell script (0514_Generate-CodeMap.ps1) loads these templates and performs string replacement:

```powershell
$templatePath = Join-Path $ProjectPath "templates/code-map"
$htmlTemplate = Get-Content (Join-Path $templatePath "code-map.html") -Raw
$cssContent = Get-Content (Join-Path $templatePath "code-map.css") -Raw
$jsContent = Get-Content (Join-Path $templatePath "code-map.js") -Raw

# Generate JSON data from codebase analysis
$dataJson = @{
    domains = $domainData
    functions = $functionData
    files = $fileData
    relationships = $relationshipData
} | ConvertTo-Json -Depth 10

# Replace placeholders
$html = $htmlTemplate -replace '{{CSS}}', "<style>$cssContent</style>" `
                      -replace '{{JAVASCRIPT}}', "<script>$jsContent</script>" `
                      -replace '{{DATA}}', "const codeMapData = $dataJson;"
```

## Benefits

1. **Syntax Safety**: No PowerShell parser issues with HTML/JS
2. **Maintainability**: Easier to edit HTML/CSS/JS in proper files
3. **IDE Support**: Full syntax highlighting and IntelliSense
4. **Testing**: Can test templates independently in browsers
5. **Reusability**: Templates can be shared across scripts
6. **Advanced Visualizations**: Leverages D3.js for sophisticated graphs

## Modifying Templates

When modifying templates:

1. Edit the appropriate template file (`.html`, `.css`, or `.js`)
2. Test the code map generator: `./automation-scripts/0514_Generate-CodeMap.ps1 -Open`
3. View the generated code map to verify changes
4. Test all visualization modes (tree, graph, matrix, sunburst)
5. Verify search and navigation functionality
6. Commit template changes along with any script updates

## Dependencies

- D3.js v7 (loaded from CDN in the HTML template)
- Modern web browser with JavaScript enabled
- No server-side dependencies (fully client-side)

## Related

- Dashboard templates: `../dashboard/`
- Generator script: `../../automation-scripts/0514_Generate-CodeMap.ps1`
- Dashboard integration: `../../automation-scripts/0512_Generate-Dashboard.ps1`
- See main [project README](../../README.md) for overview
