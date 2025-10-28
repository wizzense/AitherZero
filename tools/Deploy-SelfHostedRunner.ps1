#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Quick alias for deploying a self-hosted runner
.DESCRIPTION
    Convenience wrapper for the self-hosted runner deployment script.
    Alias: az deploy-runner
.EXAMPLE
    ./az.ps1 deploy-runner -GitHubToken "ghp_xxx"
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments)]
    $RemainingArguments
)

# Forward to the actual deployment script
& "$PSScriptRoot/automation-scripts/0724_Deploy-SelfHostedRunner.ps1" @RemainingArguments
