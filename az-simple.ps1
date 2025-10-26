#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Modern CLI - Simplified Demo Version
.DESCRIPTION
    A working demonstration of the modern CLI interface concept
#>

param(
    [string]$Action,
    [string]$Target,
    [string[]]$Arguments = @()
)

# Setup colors based on environment
$Colors = if ($env:CI -eq 'true') {
    # No colors in CI
    @{ Info='White'; Success='White'; Warning='White'; Error='White'; Accent='White'; Muted='White' }
} else {
    # Rich colors for interactive use
    @{ Info='White'; Success='Green'; Warning='Yellow'; Error='Red'; Accent='Cyan'; Muted='DarkGray' }
}

function Write-CLI {
    param(
        [string]$Message,
        [string]$Type = 'Info',
        [string]$Icon = '',
        [switch]$NoNewline
    )
    
    $color = $Colors[$Type]
    
    if ($Icon) {
        $prefix = "$Icon "
    } else {
        $prefix = switch ($Type) {
            'Success' { '✓ ' }
            'Warning' { '⚠ ' }
            'Error' { '✗ ' }
            'Accent' { '➤ ' }
            default { '' }
        }
    }
    
    Write-Host "$prefix$Message" -ForegroundColor $color -NoNewline:$NoNewline
}

function Show-Help {
    param([string]$ActionHelp)
    
    if ($ActionHelp) {
        switch ($ActionHelp) {
            'run' {
                Write-CLI "az run - Execute scripts, playbooks, or sequences" -Type 'Accent'
                Write-Host ""
                Write-CLI "Examples:" -Type 'Info'
                Write-CLI "  az run script 0402" -Type 'Muted'
                Write-CLI "  az run playbook tech-debt-analysis" -Type 'Muted'
                Write-CLI "  az run sequence 0400-0499" -Type 'Muted'
            }
            default {
                Write-CLI "Unknown action: $ActionHelp" -Type 'Error'
            }
        }
        return
    }
    
    Write-CLI "AitherZero Modern CLI" -Type 'Accent'
    Write-CLI "Usage: az <action> <target> [options]" -Type 'Info'
    Write-Host ""
    
    Write-CLI "Available Actions:" -Type 'Info'
    Write-CLI "  list" -Type 'Accent' -NoNewline
    Write-CLI " - List available resources (scripts, playbooks)" -Type 'Muted'
    Write-CLI "  run" -Type 'Accent' -NoNewline  
    Write-CLI " - Execute scripts, playbooks, or sequences" -Type 'Muted'
    Write-CLI "  search" -Type 'Accent' -NoNewline
    Write-CLI " - Find resources by name or description" -Type 'Muted'
    Write-CLI "  config" -Type 'Accent' -NoNewline
    Write-CLI " - Configure settings" -Type 'Muted'
    Write-CLI "  help" -Type 'Accent' -NoNewline
    Write-CLI " - Show help information" -Type 'Muted'
    
    Write-Host ""
    Write-CLI "Examples:" -Type 'Info'
    Write-CLI "  az list scripts                       # List all automation scripts" -Type 'Muted'
    Write-CLI "  az run script 0402                    # Run unit tests" -Type 'Muted'
    Write-CLI "  az search security                    # Find security-related items" -Type 'Muted'
    Write-CLI "  az help run                           # Get help for 'run' action" -Type 'Muted'
}

function Invoke-ListAction {
    param([string]$ListTarget)
    
    switch ($ListTarget) {
        'scripts' {
            if (Test-Path "automation-scripts") {
                $scripts = Get-ChildItem "automation-scripts" -Filter "*.ps1" | Sort-Object Name
                Write-CLI "Available Scripts ($($scripts.Count)):" -Type 'Accent'
                Write-Host ""
                
                foreach ($script in $scripts) {
                    if ($script.Name -match '^(\d{4})_(.+)\.ps1$') {
                        $number = $matches[1]
                        $name = $matches[2].Replace('_', ' ').Replace('-', ' ')
                        Write-CLI "  $number" -Type 'Accent' -NoNewline
                        Write-CLI " - $name" -Type 'Info'
                    }
                }
            } else {
                Write-CLI "Scripts directory not found" -Type 'Warning'
            }
        }
        'playbooks' {
            if (Test-Path "orchestration/playbooks") {
                $playbooks = Get-ChildItem "orchestration/playbooks" -Filter "*.json" -Recurse | Sort-Object Directory,Name
                Write-CLI "Available Playbooks ($($playbooks.Count)):" -Type 'Accent'
                Write-Host ""
                
                $currentCategory = ""
                foreach ($playbook in $playbooks) {
                    try {
                        $pb = Get-Content $playbook.FullName | ConvertFrom-Json
                        $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                        $desc = if ($pb.Description) { $pb.Description } else { $pb.description }
                        $category = $playbook.Directory.Name
                        
                        if ($category -ne $currentCategory -and $category -ne 'playbooks') {
                            if ($currentCategory) { Write-Host "" }
                            Write-CLI "[$($category.ToUpper())]" -Type 'Accent'
                            $currentCategory = $category
                        }
                        
                        Write-CLI "  $name" -Type 'Info' -NoNewline
                        if ($desc) {
                            Write-CLI " - $desc" -Type 'Muted'
                        } else {
                            Write-Host ""
                        }
                    } catch {
                        Write-CLI "  [Error reading: $($playbook.Name)]" -Type 'Warning'
                    }
                }
            } else {
                Write-CLI "Playbooks directory not found" -Type 'Warning'
            }
        }
        'all' {
            Invoke-ListAction -ListTarget 'scripts'
            Write-Host ""
            Invoke-ListAction -ListTarget 'playbooks'
        }
        default {
            Write-CLI "Unknown target: $ListTarget" -Type 'Error'
            Write-CLI "Valid targets: scripts, playbooks, all" -Type 'Info'
        }
    }
}

function Invoke-SearchAction {
    param([string]$Query)
    
    if (-not $Query) {
        Write-CLI "Search query required: az search <term>" -Type 'Error'
        return
    }
    
    Write-CLI "Searching for: $Query" -Type 'Info'
    Write-Host ""
    
    # Search scripts
    if (Test-Path "automation-scripts") {
        $matchingScripts = Get-ChildItem "automation-scripts" -Filter "*.ps1" | Where-Object {
            $_.Name -like "*$Query*"
        } | Sort-Object Name
        
        if ($matchingScripts) {
            Write-CLI "Scripts:" -Type 'Accent'
            foreach ($script in $matchingScripts) {
                if ($script.Name -match '^(\d{4})_(.+)\.ps1$') {
                    $number = $matches[1]
                    $name = $matches[2].Replace('_', ' ').Replace('-', ' ')
                    Write-CLI "  $number - $name" -Type 'Info'
                }
            }
            Write-Host ""
        }
    }
    
    # Search playbooks
    if (Test-Path "orchestration/playbooks") {
        $matchingPlaybooks = Get-ChildItem "orchestration/playbooks" -Filter "*.json" -Recurse | ForEach-Object {
            try {
                $pb = Get-Content $_.FullName | ConvertFrom-Json
                $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                $desc = if ($pb.Description) { $pb.Description } else { $pb.description }
                
                if ($name -like "*$Query*" -or ($desc -and $desc -like "*$Query*")) {
                    [PSCustomObject]@{
                        Name = $name
                        Description = $desc
                        Category = $_.Directory.Name
                    }
                }
            } catch {
                $null
            }
        } | Where-Object { $_ }
        
        if ($matchingPlaybooks) {
            Write-CLI "Playbooks:" -Type 'Accent'
            foreach ($playbook in $matchingPlaybooks) {
                Write-CLI "  [$($playbook.Category)] $($playbook.Name)" -Type 'Info'
                if ($playbook.Description) {
                    Write-CLI "    $($playbook.Description)" -Type 'Muted'
                }
            }
        }
    }
    
    if (-not $matchingScripts -and -not $matchingPlaybooks) {
        Write-CLI "No results found for: $Query" -Type 'Warning'
    }
}

function Invoke-RunAction {
    param([string]$RunTarget, [string[]]$RunArgs)
    
    switch ($RunTarget) {
        'script' {
            if ($RunArgs.Count -eq 0) {
                Write-CLI "Script number required: az run script <number>" -Type 'Error'
                return
            }
            
            $scriptNumber = $RunArgs[0]
            Write-CLI "Running script $scriptNumber..." -Type 'Info'
            
            # In a real implementation, this would call the az.ps1 script
            if (Test-Path "./az.ps1") {
                Write-CLI "Executing: ./az.ps1 $scriptNumber" -Type 'Success'
                # & "./az.ps1" $scriptNumber
            } else {
                Write-CLI "[Simulated] Would execute script $scriptNumber" -Type 'Success'
            }
        }
        'playbook' {
            if ($RunArgs.Count -eq 0) {
                Write-CLI "Playbook name required: az run playbook <name>" -Type 'Error'
                return
            }
            
            $playbookName = $RunArgs[0]
            Write-CLI "Running playbook: $playbookName" -Type 'Info'
            Write-CLI "[Simulated] Would execute playbook $playbookName" -Type 'Success'
        }
        'sequence' {
            if ($RunArgs.Count -eq 0) {
                Write-CLI "Sequence required: az run sequence <range>" -Type 'Error'
                return
            }
            
            $sequence = $RunArgs[0]
            Write-CLI "Running sequence: $sequence" -Type 'Info'
            Write-CLI "[Simulated] Would execute sequence $sequence" -Type 'Success'
        }
        default {
            Write-CLI "Unknown target: $RunTarget" -Type 'Error'
            Write-CLI "Valid targets: script, playbook, sequence" -Type 'Info'
        }
    }
}

# Parse arguments
$allArgs = @()
if ($Action) { $allArgs += $Action }
if ($Target) { $allArgs += $Target } 
$allArgs += $Arguments

# Handle interactive mode if no args
if ($allArgs.Count -eq 0 -and [Environment]::UserInteractive -and $env:CI -ne 'true') {
    Clear-Host
    Write-CLI "🚀 AitherZero Modern CLI" -Type 'Success'
    Write-Host "=" * 50 -ForegroundColor DarkCyan
    Write-Host ""
    
    Write-CLI "Quick Start Commands:" -Type 'Accent'
    Write-CLI "  az list scripts          # List all automation scripts" -Type 'Muted'
    Write-CLI "  az run script 0402       # Run unit tests" -Type 'Muted'
    Write-CLI "  az search security       # Find security-related items" -Type 'Muted'
    Write-CLI "  az help                  # Show full help" -Type 'Muted'
    Write-Host ""
    
    # Interactive prompt
    while ($true) {
        Write-CLI "az> " -Type 'Accent' -NoNewline
        $input = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($input)) {
            continue
        }
        
        if ($input -in @('exit', 'quit', 'q')) {
            Write-CLI "Goodbye! 👋" -Type 'Success'
            break
        }
        
        $inputArgs = $input -split '\s+' | Where-Object { $_ }
        
        if ($inputArgs.Count -gt 0) {
            $Action = $inputArgs[0]
            $Target = if ($inputArgs.Count -gt 1) { $inputArgs[1] } else { '' }
            $Arguments = if ($inputArgs.Count -gt 2) { $inputArgs[2..($inputArgs.Count-1)] } else { @() }
            
            # Execute command
            switch ($Action.ToLower()) {
                'list' { Invoke-ListAction -ListTarget $Target }
                'search' { Invoke-SearchAction -Query $Target }
                'run' { Invoke-RunAction -RunTarget $Target -RunArgs $Arguments }
                'help' { Show-Help -ActionHelp $Target }
                default {
                    Write-CLI "Unknown action: $Action" -Type 'Error'
                    Write-CLI "Use 'help' to see available actions" -Type 'Info'
                }
            }
        }
        
        Write-Host ""
    }
    
    exit 0
}

# Handle command line execution
if ($allArgs.Count -eq 0) {
    Show-Help
    exit 0
}

$action = $allArgs[0].ToLower()
$target = if ($allArgs.Count -gt 1) { $allArgs[1] } else { '' }
$remainingArgs = if ($allArgs.Count -gt 2) { $allArgs[2..($allArgs.Count-1)] } else { @() }

switch ($action) {
    'list' { Invoke-ListAction -ListTarget $target }
    'search' { Invoke-SearchAction -Query $target }
    'run' { Invoke-RunAction -RunTarget $target -RunArgs $remainingArgs }
    'help' { Show-Help -ActionHelp $target }
    '--version' {
        $version = if (Test-Path "VERSION") { Get-Content "VERSION" -Raw } else { "unknown" }
        Write-CLI "AitherZero Modern CLI v$version" -Type 'Info'
    }
    default {
        Write-CLI "Unknown action: $action" -Type 'Error'
        Write-CLI "Use 'az help' to see available actions" -Type 'Info'
        exit 1
    }
}