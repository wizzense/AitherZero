#!/usr/bin/env pwsh
# Check TestingFramework exports

Import-Module ./aither-core/modules/TestingFramework -Force
Get-Command -Module TestingFramework | Select-Object Name | Format-Table