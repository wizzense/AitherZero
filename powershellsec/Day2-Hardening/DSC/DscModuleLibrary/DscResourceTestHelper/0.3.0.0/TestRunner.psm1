﻿<#
    .SYNOPSIS Runs tests on all DSC resources in given folder (including common tests)
    .PARAM
        resourcesPath Path where DSC resource modules have been cloned (tests will run for all modules in that path)
    .EXAMPLE
        Start-DscResourceTests -resourcesPath C:\DscResources\xDscResources
#>
function Start-DscResourceTests
{
    param(
    [String] $resourcesPath
    )
    
    $testsPath = $pwd
    cd $resourcesPath
    ls | % {
        $module = $_.Name
        Write-Host "Copying common tests from $testsPath to $resourcesPath\$module" -ForegroundColor Yellow
        Copy-Item $testsPath "$resourcesPath\$module" -recurse -force 
        cd $module
        Write-Host "Running tests for $module" -ForegroundColor Yellow
        Invoke-Pester
        cd ..
    }
}
