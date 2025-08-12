#Requires -Version 7.0

<#
.SYNOPSIS
    Converts config.json to PowerShell Data File (config.psd1) format
.DESCRIPTION
    One-time migration script to convert existing JSON configuration to native PowerShell PSD1 format.
    This provides better IntelliSense, native PowerShell support, and cleaner syntax.
.PARAMETER JsonPath
    Path to the source JSON configuration file
.PARAMETER PsdPath
    Path to the output PSD1 configuration file
.PARAMETER Backup
    Create a backup of the original JSON file
.EXAMPLE
    ./Convert-ConfigToPsd1.ps1
.EXAMPLE
    ./Convert-ConfigToPsd1.ps1 -JsonPath config.json -PsdPath config.psd1 -Backup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$JsonPath = "./config.json",
    [string]$PsdPath = "./config.psd1",
    [switch]$Backup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-PsdString {
    param(
        [Parameter(Mandatory)]
        $Object,
        [int]$Depth = 0,
        [switch]$NoIndent
    )
    
    $indent = if ($NoIndent) { '' } else { '    ' * $Depth }
    $result = ''
    
    if ($null -eq $Object) {
        return '$null'
    }
    elseif ($Object -is [bool]) {
        if ($Object) { 
            return '$true' 
        } else { 
            return '$false' 
        }
    }
    elseif ($Object -is [string]) {
        # Handle special cases
        if ($Object -eq 'true' -or $Object -eq 'false') {
            # Boolean strings - keep as strings
            return "'$Object'"
        }
        # Escape single quotes and wrap in single quotes
        $escaped = $Object -replace "'", "''"
        return "'$escaped'"
    }
    elseif ($Object -is [int] -or $Object -is [long] -or $Object -is [double]) {
        return $Object.ToString()
    }
    elseif ($Object -is [array]) {
        if ($Object.Count -eq 0) {
            return '@()'
        }
        
        $items = @()
        foreach ($item in $Object) {
            $items += ConvertTo-PsdString -Object $item -Depth ($Depth + 1) -NoIndent
        }
        
        if ($items.Count -eq 1) {
            return "@($($items[0]))"
        }
        
        # Check if all items are simple values
        $allSimple = $true
        foreach ($item in $Object) {
            if ($item -is [PSCustomObject] -or $item -is [hashtable] -or $item -is [array]) {
                $allSimple = $false
                break
            }
        }
        
        if ($allSimple -and $items.Count -le 5) {
            # Simple array on one line
            return "@(" + ($items -join ', ') + ")"
        } else {
            # Multi-line array
            $result = "@(`n"
            foreach ($item in $items) {
                $result += "$indent    $item`n"
            }
            $result += "$indent)"
            return $result
        }
    }
    elseif ($Object -is [PSCustomObject] -or $Object -is [hashtable]) {
        # Convert to hashtable
        $hash = if ($Object -is [PSCustomObject]) {
            $h = @{}
            foreach ($prop in $Object.PSObject.Properties) {
                # Skip comment fields in conversion
                if ($prop.Name -notlike '_*') {
                    $h[$prop.Name] = $prop.Value
                }
            }
            $h
        } else {
            $Object
        }
        
        if ($hash.Count -eq 0) {
            return '@{}'
        }
        
        $result = "@{`n"
        foreach ($key in $hash.Keys) {
            $value = ConvertTo-PsdString -Object $hash[$key] -Depth ($Depth + 1)
            
            # Format key name (quote if necessary)
            $keyStr = if ($key -match '^[a-zA-Z_][a-zA-Z0-9_]*$') {
                $key
            } else {
                "'$key'"
            }
            
            # Check if value is multi-line
            if ($value -match "`n" -and $value -notmatch '^\$') {
                $result += "$indent    $keyStr = $value`n"
            } else {
                $result += "$indent    $keyStr = $value`n"
            }
        }
        $result += "$indent}"
        return $result
    }
    else {
        # Default to string representation
        return "'$Object'"
    }
}

try {
    Write-Host "Converting JSON configuration to PowerShell Data File format..." -ForegroundColor Cyan
    
    # Check if source file exists
    if (-not (Test-Path $JsonPath)) {
        throw "Configuration file not found: $JsonPath"
    }
    
    # Load JSON configuration
    Write-Host "Loading JSON from: $JsonPath" -ForegroundColor Gray
    $jsonContent = Get-Content $JsonPath -Raw
    $config = $jsonContent | ConvertFrom-Json
    
    # Create backup if requested
    if ($Backup) {
        $backupPath = "$JsonPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if ($PSCmdlet.ShouldProcess($backupPath, "Create backup")) {
            Copy-Item $JsonPath $backupPath
            Write-Host "Backup created: $backupPath" -ForegroundColor Green
        }
    }
    
    # Generate PSD1 header
    $psd1Content = @"
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Configuration File
.DESCRIPTION
    Main configuration for the AitherZero infrastructure automation platform.
    
    This file uses PowerShell Data File format (.psd1) which provides:
    - Native PowerShell IntelliSense support
    - Syntax highlighting in editors
    - Comment support for documentation
    - No JSON escaping issues
    
    Configuration Precedence (highest to lowest):
    1. Command-line parameters
    2. Environment variables (AITHERZERO_*)
    3. config.local.psd1 (if exists, gitignored)
    4. This file (config.psd1)
    
    For CI/CD environments:
    - Set environment variable CI=true for automatic CI defaults
    - Or use AITHERZERO_* environment variables to override specific settings
    
.EXAMPLE
    # Override a setting via environment variable:
    `$env:AITHERZERO_PROFILE = "Full"
    
.EXAMPLE
    # Load configuration in a script:
    `$config = Import-PowerShellDataFile ./config.psd1
    
.NOTES
    Generated from config.json on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Use config.example.psd1 for a fully documented template
#>

# AitherZero Configuration
$(ConvertTo-PsdString -Object $config -Depth 0)
"@
    
    # Write PSD1 file
    if ($PSCmdlet.ShouldProcess($PsdPath, "Write PSD1 configuration")) {
        $psd1Content | Set-Content $PsdPath -Encoding UTF8
        Write-Host "✅ Successfully created: $PsdPath" -ForegroundColor Green
        
        # Test that the file is valid
        Write-Host "Validating PSD1 file..." -ForegroundColor Gray
        try {
            $testLoad = Import-PowerShellDataFile $PsdPath
            Write-Host "✅ PSD1 file is valid and loadable" -ForegroundColor Green
            
            # Show summary
            $sections = $testLoad.Keys | Sort-Object
            Write-Host "`nConfiguration sections:" -ForegroundColor Cyan
            foreach ($section in $sections) {
                $itemCount = if ($testLoad.$section -is [hashtable]) {
                    $testLoad.$section.Keys.Count
                } else {
                    1
                }
                Write-Host "  - $section ($itemCount settings)" -ForegroundColor Gray
            }
        }
        catch {
            Write-Warning "Generated PSD1 file has issues: $_"
            Write-Host "You may need to manually fix the generated file" -ForegroundColor Yellow
        }
    }
    
    # Provide next steps
    Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Review the generated config.psd1 file" -ForegroundColor White
    Write-Host "2. Update Configuration.psm1 to support PSD1 format" -ForegroundColor White
    Write-Host "3. Test loading with: Import-PowerShellDataFile $PsdPath" -ForegroundColor White
    Write-Host "4. Create config.local.psd1 for local overrides (optional)" -ForegroundColor White
    Write-Host "5. Once verified, you can archive config.json" -ForegroundColor White
    
    if (-not $Backup) {
        Write-Host "`n💡 Tip: Run with -Backup to create a backup of config.json" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to convert configuration: $_"
    exit 1
}