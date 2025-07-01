#!/usr/bin/env pwsh
#Requires -Version 7.0

Write-Host "🚀 AitherZero Infrastructure Automation Framework v1.3.2" -ForegroundColor Cyan
Write-Host "   Local Build - Essential Components Only" -ForegroundColor Yellow

$env:PROJECT_ROOT = $PSScriptRoot

& "$PSScriptRoot/aither-core.ps1" $args
