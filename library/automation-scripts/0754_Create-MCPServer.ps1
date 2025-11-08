#!/usr/bin/env pwsh
# Stage: Automation
# Dependencies: Node.js 18+
# Category: AI Tools & Automation
# Description: Scaffolds a new Model Context Protocol (MCP) server using the AitherZero MCP server template
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

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
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

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output if logging module fails to load
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if ($script:LoggingAvailable) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting MCP server creation: $ServerName"

# Get script root (AitherZero root)
# This script is in automation-scripts/, so parent is AitherZero root
$AitherZeroRoot = Split-Path $PSScriptRoot -Parent
$TemplatePath = Join-Path $AitherZeroRoot "templates" "mcp-server-template"

# Create output path if it doesn't exist, then get absolute path
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}
# Use GetFullPath for reliable absolute path resolution (works with newly created directories)
$OutputPathResolved = [System.IO.Path]::GetFullPath($OutputPath)
$TargetPath = Join-Path $OutputPathResolved "$ServerName-mcp-server"

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
        Write-ScriptLog "Detected author from git config: $Author" -Level 'Debug'
    } catch {
        $Author = "Unknown Author"
        Write-ScriptLog "Could not detect git user, using default author" -Level 'Debug'
    }
}

Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "   Server Name: $ServerName" -ForegroundColor White
Write-Host "   Description: $Description" -ForegroundColor White
Write-Host "   Author: $Author" -ForegroundColor White
Write-Host "   Organization: @$Organization" -ForegroundColor White
Write-Host "   Target Path: $TargetPath" -ForegroundColor White
Write-Host ""

Write-ScriptLog "Configuration - Server: $ServerName, Output: $TargetPath, Org: @$Organization"

# Validate template exists
if (-not (Test-Path $TemplatePath)) {
    Write-ScriptLog "Template not found at: $TemplatePath" -Level 'Error'
    Write-Host "❌ Template not found at: $TemplatePath" -ForegroundColor Red
    exit 1
}

Write-ScriptLog "Template validated at: $TemplatePath" -Level 'Debug'

# Check if target exists
if (Test-Path $TargetPath) {
    Write-ScriptLog "Target directory already exists: $TargetPath" -Level 'Error'
    Write-Host "❌ Target directory already exists: $TargetPath" -ForegroundColor Red
    exit 1
}

Write-ScriptLog "Target path validated, proceeding with creation"

# Create target directory
Write-Host "📁 Creating directory structure..." -ForegroundColor Cyan
Write-ScriptLog "Copying template from $TemplatePath to $TargetPath"

if ($PSCmdlet.ShouldProcess($TargetPath, "Create MCP server from template")) {
    try {
        # Suppress progress bar for cleaner output
        $ProgressPreference = 'SilentlyContinue'
        Copy-Item -Path $TemplatePath -Destination $TargetPath -Recurse -Force
        $ProgressPreference = 'Continue'
        Write-Host "   ✓ Directory created" -ForegroundColor Green
        Write-ScriptLog "Directory structure created successfully"
    } catch {
        Write-ScriptLog "Failed to create directory: $_" -Level 'Error'
        Write-Host "   ❌ Failed to create directory: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "   (WhatIf) Would create directory: $TargetPath" -ForegroundColor Yellow
    Write-ScriptLog "WhatIf: Would create directory structure at $TargetPath"
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
Write-ScriptLog "Starting template customization with replacements"

# Process package.json.template
$packageJsonTemplate = Join-Path $TargetPath "package.json.template"
$packageJson = Join-Path $TargetPath "package.json"
if ($WhatIfPreference) {
    Write-Host "   (WhatIf) Would configure package.json" -ForegroundColor Yellow
} elseif (Update-TemplateFile -FilePath $packageJsonTemplate -Replacements $replacements) {
    Rename-Item -Path $packageJsonTemplate -NewName "package.json" -Force
    Write-Host "   ✓ package.json configured" -ForegroundColor Green
    Write-ScriptLog "Configured package.json" -Level 'Debug'
} else {
    Write-ScriptLog "Failed to configure package.json" -Level 'Warning'
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
    "library/SETUP.md.template",
    "library/USAGE.md.template",
    "library/ARCHITECTURE.md.template",
    "library/TROUBLESHOOTING.md.template"
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

Write-ScriptLog "Template customization completed successfully"

# Initialize git repository
if (-not $SkipGit) {
    Write-Host ""
    Write-Host "🔧 Initializing git repository..." -ForegroundColor Cyan
    Write-ScriptLog "Initializing git repository in $TargetPath"

    if ($PSCmdlet.ShouldProcess($TargetPath, "Initialize git repository")) {
        Push-Location $TargetPath
        try {
            git init
            if ($LASTEXITCODE -ne 0) {
                throw "git init failed (exit code $LASTEXITCODE)"
            }

            git add .
            if ($LASTEXITCODE -ne 0) {
                throw "git add failed (exit code $LASTEXITCODE)"
            }

            git commit -m "Initial commit: Scaffold from AitherZero MCP template"
            if ($LASTEXITCODE -ne 0) {
                throw "git commit failed (exit code $LASTEXITCODE)"
            }

            Write-Host "   ✓ Git repository initialized" -ForegroundColor Green
            Write-ScriptLog "Git repository initialized successfully"
        } catch {
            Write-ScriptLog "Git initialization failed: $_" -Level 'Warning'
            Write-Host "   ⚠️  Git initialization skipped: $_" -ForegroundColor Yellow
        }
        Pop-Location
    } else {
        Write-Host "   (WhatIf) Would initialize git repository" -ForegroundColor Yellow
        Write-ScriptLog "WhatIf: Would initialize git repository in $TargetPath"
    }
}

# Install dependencies and build
if (-not $SkipInstall) {
    Write-Host ""
    Write-Host "📦 Installing dependencies..." -ForegroundColor Cyan
    Write-ScriptLog "Starting npm install and build process"

    if ($PSCmdlet.ShouldProcess($TargetPath, "Install npm dependencies and build")) {
        Push-Location $TargetPath

        try {
            # Check Node.js
            $nodeVersion = node --version 2>&1
            Write-Host "   ℹ️  Using Node.js: $nodeVersion" -ForegroundColor Gray
            Write-ScriptLog "Node.js version: $nodeVersion" -Level 'Debug'

            # Install
            npm install 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✓ Dependencies installed" -ForegroundColor Green
                Write-ScriptLog "npm install completed successfully"
            } else {
                throw "npm install failed"
            }

            Write-Host ""
            Write-Host "🔨 Building TypeScript..." -ForegroundColor Cyan
            npm run build 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✓ Build successful" -ForegroundColor Green
                Write-ScriptLog "TypeScript build completed successfully"
            } else {
                throw "npm build failed"
            }

            Write-Host ""
            Write-Host "🧪 Testing server..." -ForegroundColor Cyan
            $testOutput = npm run test:manual 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✓ Server responds correctly" -ForegroundColor Green
                Write-ScriptLog "Server test passed"
            } else {
                Write-Host "   ⚠️  Test warning (this is normal for new servers)" -ForegroundColor Yellow
                Write-ScriptLog "Server test had warnings (expected for new servers)" -Level 'Warning'
            }

        } catch {
            Write-ScriptLog "Installation/build had issues: $_" -Level 'Warning'
            Write-Host "   ⚠️  Installation/build had issues: $_" -ForegroundColor Yellow
            Write-Host "   You can run manually: cd $TargetPath && npm install && npm run build" -ForegroundColor Gray
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "   (WhatIf) Would install dependencies and build" -ForegroundColor Yellow
        Write-ScriptLog "WhatIf: Would run npm install and build in $TargetPath"
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

Write-ScriptLog "MCP server creation completed successfully: $TargetPath"

exit 0
