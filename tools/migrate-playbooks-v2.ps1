#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Migrate legacy v1 playbooks to new v2.0 format
.DESCRIPTION
    This script helps convert existing v1 playbooks to the new v2.0 standardized format.
    It analyzes existing playbooks and provides migration suggestions.
.PARAMETER InputPath
    Path to directory containing v1 playbooks
.PARAMETER OutputPath  
    Path to output converted v2.0 playbooks
.PARAMETER DryRun
    Show what would be converted without making changes
#>

param(
    [Parameter(Mandatory)]
    [string]$InputPath,
    
    [Parameter(Mandatory)]
    [string]$OutputPath,
    
    [switch]$DryRun
)

function ConvertTo-V2Format {
    param(
        [hashtable]$V1Playbook,
        [string]$FileName
    )

    # Extract name from filename or use existing name
    $name = if ($V1Playbook.Name) { $V1Playbook.Name } 
            elseif ($V1Playbook.name) { $V1Playbook.name }
            else { [System.IO.Path]::GetFileNameWithoutExtension($FileName) }

    # Convert to kebab-case
    $name = $name.ToLower() -replace '[^a-z0-9\-]', '-' -replace '--+', '-'

    # Determine category based on name/content
    $category = "development"  # Default
    if ($name -match "infra|hyperv|vm|network") { $category = "infrastructure" }
    elseif ($name -match "test|validation|quality") { $category = "testing" }
    elseif ($name -match "deploy|ci|cd|pipeline") { $category = "deployment" }
    elseif ($name -match "security|scan|audit") { $category = "security" }
    elseif ($name -match "clean|maintenance|optimization") { $category = "maintenance" }
    elseif ($name -match "analysis|report") { $category = "analysis" }

    # Build v2.0 playbook
    $v2Playbook = @{
        metadata = @{
            name = $name
            description = if ($V1Playbook.Description) { $V1Playbook.Description } 
                         elseif ($V1Playbook.description) { $V1Playbook.description }
                         else { "Converted from v1 playbook" }
            version = "2.0.0"
            category = $category
            author = if ($V1Playbook.Author) { $V1Playbook.Author }
                    elseif ($V1Playbook.author) { $V1Playbook.author }
                    else { "AitherZero Team" }
            tags = @("converted", "v2", $category)
            estimatedDuration = "5-15 minutes"
            lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        requirements = @{
            minimumPowerShellVersion = "7.0"
            requiredModules = @("OrchestrationEngine")
            platforms = @("CrossPlatform")
        }
        orchestration = @{
            defaultVariables = if ($V1Playbook.Variables) { $V1Playbook.Variables }
                              elseif ($V1Playbook.variables) { $V1Playbook.variables }
                              else { @{} }
            stages = @()
        }
        notifications = @{
            onStart = @{
                message = "🚀 Starting $name workflow..."
                level = "Information"
            }
            onSuccess = @{
                message = "✅ Workflow completed successfully!"
                level = "Success"
            }
            onFailure = @{
                message = "❌ Workflow failed. Check logs for details."
                level = "Error"
            }
        }
        reporting = @{
            enabled = $true
            formats = @("JSON", "Markdown")
            outputPath = "./reports/$category"
            includeMetrics = $true
        }
    }

    # Handle profiles
    if ($V1Playbook.options -and $V1Playbook.options.profiles) {
        $v2Playbook.orchestration.profiles = $V1Playbook.options.profiles
    }

    # Convert sequences and stages
    if ($V1Playbook.Stages -or $V1Playbook.stages) {
        # Convert existing stages
        $stages = if ($V1Playbook.Stages) { $V1Playbook.Stages } else { $V1Playbook.stages }
        foreach ($stage in $stages) {
            $v2Stage = @{
                name = if ($stage.Name) { $stage.Name } else { $stage.name }
                description = if ($stage.Description) { $stage.Description } else { $stage.description }
                sequences = if ($stage.Sequence) { $stage.Sequence } else { $stage.sequence }
                continueOnError = if ($null -ne $stage.ContinueOnError) { $stage.ContinueOnError } 
                                 elseif ($null -ne $stage.continueOnError) { $stage.continueOnError }
                                 else { $false }
                timeout = 600
            }
            
            if ($stage.Variables -or $stage.variables) {
                $v2Stage.variables = if ($stage.Variables) { $stage.Variables } else { $stage.variables }
            }
            
            $v2Playbook.orchestration.stages += $v2Stage
        }
    } 
    elseif ($V1Playbook.Sequence -or $V1Playbook.sequence) {
        # Convert simple sequence to single stage
        $sequences = if ($V1Playbook.Sequence) { $V1Playbook.Sequence } else { $V1Playbook.sequence }
        $v2Stage = @{
            name = "Main Execution"
            description = "Primary workflow execution"
            sequences = $sequences
            continueOnError = $false
            timeout = 900
        }
        $v2Playbook.orchestration.stages += $v2Stage
    }

    return $v2Playbook
}

# Main script
Write-Host "🔄 AitherZero Playbook Migration Tool v2.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if (-not (Test-Path $InputPath)) {
    Write-Error "Input path does not exist: $InputPath"
    exit 1
}

if (-not $DryRun -and -not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "📁 Created output directory: $OutputPath" -ForegroundColor Green
}

$v1Playbooks = Get-ChildItem -Path $InputPath -Filter "*.json" -Recurse
Write-Host "🔍 Found $($v1Playbooks.Count) JSON files to analyze" -ForegroundColor Yellow

$convertedCount = 0
$skippedCount = 0

foreach ($file in $v1Playbooks) {
    try {
        $content = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        
        # Check if already v2.0 format
        if ($content.ContainsKey('metadata') -and $content.ContainsKey('orchestration')) {
            Write-Host "⏭️  Skipping v2.0 playbook: $($file.Name)" -ForegroundColor Gray
            $skippedCount++
            continue
        }

        Write-Host "🔄 Converting: $($file.Name)" -ForegroundColor Yellow
        
        $v2Playbook = ConvertTo-V2Format -V1Playbook $content -FileName $file.Name
        
        if (-not $DryRun) {
            # Determine output category directory
            $categoryDir = Join-Path $OutputPath $v2Playbook.metadata.category
            if (-not (Test-Path $categoryDir)) {
                New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null
            }
            
            $outputFile = Join-Path $categoryDir "$($v2Playbook.metadata.name).json"
            $v2Playbook | ConvertTo-Json -Depth 10 | Set-Content $outputFile -Encoding UTF8
            Write-Host "   ✅ Converted to: $outputFile" -ForegroundColor Green
        } else {
            Write-Host "   📋 Would convert to: $($v2Playbook.metadata.category)/$($v2Playbook.metadata.name).json" -ForegroundColor Cyan
            Write-Host "      Category: $($v2Playbook.metadata.category)" -ForegroundColor White
            Write-Host "      Stages: $($v2Playbook.orchestration.stages.Count)" -ForegroundColor White
        }
        
        $convertedCount++
    }
    catch {
        Write-Host "   ❌ Failed to convert $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host "`n📊 Migration Summary:" -ForegroundColor Cyan
Write-Host "   Converted: $convertedCount" -ForegroundColor Green
Write-Host "   Skipped (already v2.0): $skippedCount" -ForegroundColor Gray
Write-Host "   Total processed: $($v1Playbooks.Count)" -ForegroundColor White

if ($DryRun) {
    Write-Host "`n💡 This was a dry run. Use -DryRun:`$false to perform actual conversion." -ForegroundColor Yellow
} else {
    Write-Host "`n🎉 Migration completed! New v2.0 playbooks are in: $OutputPath" -ForegroundColor Green
}