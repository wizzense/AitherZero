#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create a new MCP server from the template

.DESCRIPTION
    Scaffolds a new Model Context Protocol (MCP) server using the AitherZero
    MCP server template. This automation script copies the template, customizes
    it with provided parameters, and sets up the development environment.
    
    This script is part of the AitherZero numbered system (0700-0799: AI Tools).

.PARAMETER ServerName
    Name of the MCP server (e.g., "docker-manager", "infrastructure-monitor")
    Will be used in package name, directory name, and configuration

.PARAMETER Description
    Brief description of what the server does
    Will be used in package.json and documentation

.PARAMETER Author
    Author name or organization
    Defaults to current git user

.PARAMETER OutputPath
    Where to create the new server
    Defaults to current directory

.PARAMETER Organization
    NPM organization/scope (e.g., "mycompany" for "@mycompany/servername")
    Defaults to "custom"

.PARAMETER SkipInstall
    Skip npm install and build steps

.PARAMETER SkipGit
    Skip git repository initialization

.EXAMPLE
    ./0754_Create-MCPServer.ps1 -ServerName "docker-manager" -Description "Docker container management MCP server"

.EXAMPLE
    az 0754 -ServerName "my-server" -Description "My custom MCP server" -Author "John Doe"

.NOTES
    Script Number: 0754
    Category: AI Tools & Automation
    Requires: Node.js 18+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$ServerName,
    
    [Parameter(Mandatory = $true)]
    [string]$Description,
    
    [Parameter()]
    [string]$Author,
    
    [Parameter()]
    [string]$OutputPath = ".",
    
    [Parameter()]
    [string]$Organization = "custom",
    
    [switch]$SkipInstall,
    [switch]$SkipGit
)

$ErrorActionPreference = 'Stop'

# Get script root (AitherZero root)
$AitherZeroRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$TemplatePath = Join-Path $AitherZeroRoot "templates" "mcp-server-template"
$TargetPath = Join-Path $OutputPath "$ServerName-mcp-server"

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "║              🚀 CREATE NEW MCP SERVER 🚀                             ║" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get author from git if not specified
if (-not $Author) {
    try {
        $Author = git config user.name
        if (-not $Author) {
            $Author = "Unknown Author"
        }
    } catch {
        $Author = "Unknown Author"
    }
}

Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "   Server Name: $ServerName" -ForegroundColor White
Write-Host "   Description: $Description" -ForegroundColor White
Write-Host "   Author: $Author" -ForegroundColor White
Write-Host "   Organization: @$Organization" -ForegroundColor White
Write-Host "   Target Path: $TargetPath" -ForegroundColor White
Write-Host ""

# Validate template exists
if (-not (Test-Path $TemplatePath)) {
    Write-Host "❌ Template not found at: $TemplatePath" -ForegroundColor Red
    exit 1
}

# Check if target exists
if (Test-Path $TargetPath) {
    Write-Host "❌ Target directory already exists: $TargetPath" -ForegroundColor Red
    exit 1
}

# Create target directory
Write-Host "📁 Creating directory structure..." -ForegroundColor Cyan
try {
    Copy-Item -Path $TemplatePath -Destination $TargetPath -Recurse -Force
    Write-Host "   ✓ Directory created" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to create directory: $_" -ForegroundColor Red
    exit 1
}

# Function to replace placeholders in a file
function Update-TemplateFile {
    param(
        [string]$FilePath,
        [hashtable]$Replacements
    )
    
    if (Test-Path $FilePath) {
        $content = Get-Content -Path $FilePath -Raw
        
        foreach ($key in $Replacements.Keys) {
            $content = $content -replace [regex]::Escape($key), $Replacements[$key]
        }
        
        Set-Content -Path $FilePath -Value $content -NoNewline
        return $true
    }
    return $false
}

# Define replacements
$replacements = @{
    'SERVERNAME' = $ServerName
    'DESCRIPTION' = $Description
    'AUTHOR' = $Author
    'YOURORG' = $Organization
}

Write-Host ""
Write-Host "✏️  Customizing template files..." -ForegroundColor Cyan

# Process package.json.template
$packageJsonTemplate = Join-Path $TargetPath "package.json.template"
$packageJson = Join-Path $TargetPath "package.json"
if (Update-TemplateFile -FilePath $packageJsonTemplate -Replacements $replacements) {
    Rename-Item -Path $packageJsonTemplate -NewName "package.json" -Force
    Write-Host "   ✓ package.json configured" -ForegroundColor Green
}

# Process TypeScript files
$tsFiles = @(
    "src/index.ts.template",
    "src/types.ts.template",
    "src/utils/logger.ts.template",
    "src/utils/executor.ts.template"
)

foreach ($file in $tsFiles) {
    $fullPath = Join-Path $TargetPath $file
    if (Test-Path $fullPath) {
        $newPath = $fullPath -replace '\.template$', ''
        Update-TemplateFile -FilePath $fullPath -Replacements $replacements | Out-Null
        Rename-Item -Path $fullPath -NewName (Split-Path $newPath -Leaf) -Force
        Write-Host "   ✓ $(Split-Path $newPath -Leaf) configured" -ForegroundColor Green
    }
}

# Process test file
$testTemplate = Join-Path $TargetPath "test/basic-test.mjs.template"
if (Test-Path $testTemplate) {
    $testFile = Join-Path $TargetPath "test/basic-test.mjs"
    Update-TemplateFile -FilePath $testTemplate -Replacements $replacements | Out-Null
    Rename-Item -Path $testTemplate -NewName "basic-test.mjs" -Force
    Write-Host "   ✓ test/basic-test.mjs configured" -ForegroundColor Green
}

# Process documentation templates
$docFiles = @(
    "docs/SETUP.md.template",
    "docs/USAGE.md.template",
    "docs/ARCHITECTURE.md.template",
    "docs/TROUBLESHOOTING.md.template"
)

foreach ($file in $docFiles) {
    $fullPath = Join-Path $TargetPath $file
    if (Test-Path $fullPath) {
        $newPath = $fullPath -replace '\.template$', ''
        Update-TemplateFile -FilePath $fullPath -Replacements $replacements | Out-Null
        Rename-Item -Path $fullPath -NewName (Split-Path $newPath -Leaf) -Force
        Write-Host "   ✓ $(Split-Path $newPath -Leaf) configured" -ForegroundColor Green
    }
}

# Process example configs
$exampleFiles = @(
    "examples/claude-config.json",
    "examples/copilot-config.json"
)

foreach ($file in $exampleFiles) {
    $fullPath = Join-Path $TargetPath $file
    if (Test-Path $fullPath) {
        Update-TemplateFile -FilePath $fullPath -Replacements $replacements | Out-Null
        Write-Host "   ✓ $(Split-Path $fullPath -Leaf) configured" -ForegroundColor Green
    }
}

# Process README
$readmePath = Join-Path $TargetPath "README.md"
if (Test-Path $readmePath) {
    Update-TemplateFile -FilePath $readmePath -Replacements $replacements | Out-Null
    Write-Host "   ✓ README.md configured" -ForegroundColor Green
}

# Initialize git repository
if (-not $SkipGit) {
    Write-Host ""
    Write-Host "🔧 Initializing git repository..." -ForegroundColor Cyan
    Push-Location $TargetPath
    try {
        git init 2>&1 | Out-Null
        git add . 2>&1 | Out-Null
        git commit -m "Initial commit: Scaffold from AitherZero MCP template" 2>&1 | Out-Null
        Write-Host "   ✓ Git repository initialized" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Git initialization skipped: $_" -ForegroundColor Yellow
    }
    Pop-Location
}

# Install dependencies and build
if (-not $SkipInstall) {
    Write-Host ""
    Write-Host "📦 Installing dependencies..." -ForegroundColor Cyan
    Push-Location $TargetPath
    
    try {
        # Check Node.js
        $nodeVersion = node --version 2>&1
        Write-Host "   ℹ️  Using Node.js: $nodeVersion" -ForegroundColor Gray
        
        # Install
        npm install 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✓ Dependencies installed" -ForegroundColor Green
        } else {
            throw "npm install failed"
        }
        
        Write-Host ""
        Write-Host "🔨 Building TypeScript..." -ForegroundColor Cyan
        npm run build 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✓ Build successful" -ForegroundColor Green
        } else {
            throw "npm build failed"
        }
        
        Write-Host ""
        Write-Host "🧪 Testing server..." -ForegroundColor Cyan
        $testOutput = npm run test:manual 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✓ Server responds correctly" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Test warning (this is normal for new servers)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "   ⚠️  Installation/build had issues: $_" -ForegroundColor Yellow
        Write-Host "   You can run manually: cd $TargetPath && npm install && npm run build" -ForegroundColor Gray
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║              ✅ MCP SERVER CREATED SUCCESSFULLY! ✅                  ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📍 Server Location: $TargetPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Navigate to your server:" -ForegroundColor White
Write-Host "   cd $TargetPath" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Review and customize:" -ForegroundColor White
Write-Host "   - src/index.ts      (add your tools and resources)" -ForegroundColor Gray
Write-Host "   - README.md         (update documentation)" -ForegroundColor Gray
Write-Host "   - docs/SETUP.md     (customize setup instructions)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Test your server:" -ForegroundColor White
Write-Host "   npm test            (run automated tests)" -ForegroundColor Gray
Write-Host "   npm run test:manual (test JSON-RPC)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Configure AI assistant:" -ForegroundColor White
Write-Host "   - See examples/claude-config.json" -ForegroundColor Gray
Write-Host "   - See examples/copilot-config.json" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Read the guides:" -ForegroundColor White
Write-Host "   - TEMPLATE-GUIDE.md (detailed customization guide)" -ForegroundColor Gray
Write-Host "   - docs/SETUP.md     (setup and configuration)" -ForegroundColor Gray
Write-Host "   - docs/USAGE.md     (usage examples)" -ForegroundColor Gray
Write-Host ""

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "   Template Guide: $TargetPath/TEMPLATE-GUIDE.md" -ForegroundColor Gray
Write-Host "   MCP Specification: https://modelcontextprotocol.io/" -ForegroundColor Gray
Write-Host ""

Write-Host "💡 Tip: The template includes auto-build, so users don't need to run" -ForegroundColor Yellow
Write-Host "   npm install or npm build - it just works!" -ForegroundColor Yellow
Write-Host ""

exit 0
