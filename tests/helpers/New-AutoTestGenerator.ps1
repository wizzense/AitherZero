<#
.SYNOPSIS
Automatically generates Pester tests for new PowerShell scripts

.DESCRIPTION
This script monitors the aither-core/scripts directory for new scripts and automatically:
- Creates corresponding .Tests.ps1 files
- Generates boilerplate test code based on script analysis
- Follows naming conventions and test patterns
- Integrates with the extensible test framework

.EXAMPLE
./New-AutoTestGenerator.ps1 -WatchDirectory "aither-core/scripts"

.EXAMPLE
./New-AutoTestGenerator.ps1 -ScriptPath "aither-core/scripts/0301_Install-NewTool.ps1" -Force
#>

param(
    string$WatchDirectory = "aither-core/scripts",
    string$ScriptPath,
    string$OutputDirectory = "tests",
    switch$Force,
    switch$WatchMode,
    int$WatchIntervalSeconds = 30
)

. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

function Get-ScriptAnalysis {
    <#
    .SYNOPSIS
    Analyzes a PowerShell script to determine test generation strategy
    #>
    param(string$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }
    
    $content = Get-Content $ScriptPath -Raw
    $ast = System.Management.Automation.Language.Parser::ParseInput($content, ref$null, ref$null)
    
        $functions = $ast.FindAll({ $args0 -is System.Management.Automation.Language.FunctionDefinitionAst }, $true)
    foreach ($func in $functions) {
        $analysis.Functions += @{
            Name = $func.Name
            Parameters = $func.Parameters.Name.VariablePath.UserPath
            HasCmdletBinding = $func.Body.ParamBlock.Attributes.TypeName.Name -contains 'CmdletBinding'
        }
    }
    
    # Find script parameters
    $paramBlock = $ast.FindAll({ $args0 -is System.Management.Automation.Language.ParamBlockAst }, $true) | Select-Object -First 1
    if ($paramBlock) {
        $analysis.Parameters = $paramBlock.Parameters.Name.VariablePath.UserPath
    }
    
    # Determine category and characteristics
    if ($content -match 'Install-Download-Invoke-WebRequestwgetcurl') {
        $analysis.Category = 'Installer'
        $analysis.HasDownloads = $true
        $analysis.HasInstallation = $true
    }
    elseif ($content -match 'Enable-Disable-Set-.*FeatureWindowsFeature') {
        $analysis.Category = 'Feature'
        $analysis.HasConfiguration = $true
    }
    elseif ($content -match 'Start-ServiceStop-ServiceNew-ServiceSet-Service') {
        $analysis.Category = 'Service'
        $analysis.HasServiceManagement = $true
    }
    elseif ($content -match 'Set-.*ConfigConfig-Configure-') {
        $analysis.Category = 'Configuration'
        $analysis.HasConfiguration = $true
    }
    elseif ($content -match 'Reset-Cleanup-Remove-') {
        $analysis.Category = 'Maintenance'
    }
    
    # Platform detection
    if ($content -match 'Win32Windows\.msi\.exeRegistryWinRM') {
        $analysis.Platform = 'Windows'
    }
    elseif ($content -match 'apt-getyumsystemctl/usr//etc/') {
        $analysis.Platform = 'Linux'
    }
    elseif ($content -match 'brew/usr/locallaunchctl') {
        $analysis.Platform = 'macOS'
    }
    
    # Admin requirements
    if ($content -match 'RequireAdministratorStart-Process.*-Verb RunAssudo') {
        $analysis.RequiresAdmin = $true
    }
    
    # External dependencies
    $externalCommands = @('git', 'docker', 'kubectl', 'terraform', 'opentofu', 'gh', 'az')
    foreach ($cmd in $externalCommands) {
        if ($content -match "\b$cmd\b") {
            $analysis.DependsOnExternal += $cmd
        }
    }
    
    return $analysis
}

function New-TestTemplate {
    <#
    .SYNOPSIS
    Generates a test template based on script analysis
    #>
    param(
        string$ScriptName,
        object$Analysis,
        string$ScriptPath
    )
    
    $testName = $ScriptName -replace '\.ps1$', '.Tests.ps1'
    $scriptRelativePath = $ScriptPath -replace regex::Escape((Get-Location).Path + '\'), ''
    
    $skipConditions = @()
    if ($Analysis.Platform -eq 'Windows') {
        $skipConditions += '$SkipNonWindows'
    }
    elseif ($Analysis.Platform -eq 'Linux') {
        $skipConditions += '$SkipNonLinux'
    }
    elseif ($Analysis.Platform -eq 'macOS') {
        $skipConditions += '$SkipNonMacOS'
    }

    $template = @"
# filepath: tests/$testName
. (Join-Path `$PSScriptRoot 'TestDriveCleanup.ps1')
. (Join-Path `$PSScriptRoot 'helpers' 'TestHelpers.ps1')

BeforeAll {
        `$TestConfig = Get-TestConfiguration
    `$SkipNonWindows = -not (Get-Platform).IsWindows
    `$SkipNonLinux = -not (Get-Platform).IsLinux
    `$SkipNonMacOS = -not (Get-Platform).IsMacOS
    `$SkipNonAdmin = -not (Test-IsAdministrator)
}

Describe '$($ScriptName -replace '\.ps1$', '') Tests' -Tag '$($Analysis.Category)' {
    
    Context 'Script Structure Validation' {
        It 'should have valid PowerShell syntax'$skipClause {
            `$scriptPath  Should -Exist
            { . `$scriptPath }  Should -Not -Throw
        }
        
        It 'should follow naming conventions'$skipClause {
            `$scriptName = System.IO.Path::GetFileName(`$scriptPath)
            `$scriptName  Should -Match '^0-9{4}_A-Za-zA-Z0-9-+\.ps1$^A-Za-zA-Z0-9-+\.ps1$'
        }
"@

    # Add function-specific tests
    if ($Analysis.Functions.Count -gt 0) {
        $template += @"

        It 'should define expected functions'$skipClause {
"@
        foreach ($func in $Analysis.Functions) {
            $template += @"

            Get-Command '$($func.Name)' -ErrorAction SilentlyContinue  Should -Not -BeNullOrEmpty
"@
        }
        $template += @"

        }
"@
    }
    
    $template += @"

    }
    
    Context 'Parameter Validation' {
"@

    if ($Analysis.Parameters.Count -gt 0) {
        foreach ($param in $Analysis.Parameters) {
            $template += @"

        It 'should accept $param parameter'$skipClause {
            { & `$scriptPath -$param 'TestValue' -WhatIf }  Should -Not -Throw
        }
"@
        }
    } else {
        $template += @"

        It 'should handle execution without parameters'$skipClause {
            { & `$scriptPath -WhatIf }  Should -Not -Throw
        }
"@
    }
    
    $template += @"

    }
"@

    # Category-specific test contexts
    switch ($Analysis.Category) {
        'Installer' {
            $template += @"

    Context 'Installation Tests' {
        BeforeEach {
            # Mock external dependencies for testing
"@
            foreach ($dep in $Analysis.DependsOnExternal) {
                $template += @"

            Mock Invoke-WebRequest { return @{ StatusCode = 200 } }
            Mock Start-Process { return @{ ExitCode = 0 } }
"@
            }
            $template += @"

        }
        
        It 'should validate prerequisites'$skipClause {
            # Test prerequisite checking logic
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
        
        It 'should handle download failures gracefully'$skipClause {
            # Test error handling for failed downloads
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
        
        It 'should verify installation success'$skipClause {
            # Test installation verification
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
    }
"@
        }
        
        'Configuration' {
            $template += @"

    Context 'Configuration Tests' {
        It 'should backup existing configuration'$skipClause {
            # Test configuration backup logic
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
        
        It 'should validate configuration changes'$skipClause {
            # Test configuration validation
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
        
        It 'should handle rollback on failure'$skipClause {
            # Test rollback functionality
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
    }
"@
        }
        
        'Service' {
            $template += @"

    Context 'Service Management Tests' {
        It 'should check service status before changes'$skipClause {
            # Test service status checking
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
        
        It 'should handle service start/stop operations'$skipClause {
            # Test service operations
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
        
        It 'should verify service configuration'$skipClause {
            # Test service configuration
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
    }
"@
        }
    }
    
    # Add function-specific tests
    foreach ($func in $Analysis.Functions) {
        $template += @"

    Context '$($func.Name) Function Tests' {
        It 'should be defined and accessible'$skipClause {
            Get-Command '$($func.Name)'  Should -Not -BeNullOrEmpty
        }
        
"@
        if ($func.HasCmdletBinding) {
            $template += @"
        It 'should support common parameters'$skipClause {
            (Get-Command '$($func.Name)').Parameters.Keys  Should -Contain 'Verbose'
            (Get-Command '$($func.Name)').Parameters.Keys  Should -Contain 'WhatIf'
        }
        
"@
        }
        
        foreach ($param in $func.Parameters) {
            $template += @"
        It 'should accept $param parameter'$skipClause {
            (Get-Command '$($func.Name)').Parameters.Keys  Should -Contain '$param'
        }
        
"@
        }
        
        $template += @"
        It 'should handle execution with valid parameters'$skipClause {
            # Add specific test logic for $($func.Name)
            `$true | Should -BeTrue  # Placeholder - implement actual tests
        }
    }
"@
    }
    
    $template += @"

}

# Clean up test environment
AfterAll {
    # Restore any modified system state
    # Remove test artifacts
}
"@

    return $template
}

function Format-ScriptName {
    <#
    .SYNOPSIS
    Formats script names to follow the project naming convention
    #>
    param(string$OriginalName)
    
    # Remove file extension
    $baseName = System.IO.Path::GetFileNameWithoutExtension($OriginalName)
    
    # Check if already follows convention (nnnn_Verb-Noun format)
    if ($baseName -match '^0-9{4}_A-Za-zA-Z0-9-+$') {
        return $OriginalName
    }
    
    # Split and convert to proper case
    $parts = $baseName -split '-_\s' | Where-Object{ $_.Length -gt 0 } | ForEach-Object{
        $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
    }
    
    # Determine verb and noun
    $verb = $null
    $noun = $null
    
    $commonVerbs = @('Install', 'Enable', 'Disable', 'Configure', 'Set', 'Get', 'New', 'Remove', 'Reset', 'Start', 'Stop', 'Test', 'Invoke', 'Config')
    
    # Check if first part is a verb
    if ($parts.Count -gt 0 -and $commonVerbs -contains $parts0) {
            # Infer verb based on common patterns
        if ($allParts -match 'ConfigConfigureSetupSet') { $verb = 'Configure' }
        elseif ($allParts -match 'EnableStartTurn.*On') { $verb = 'Enable' }
        elseif ($allParts -match 'DisableStopTurn.*Off') { $verb = 'Disable' }
        elseif ($allParts -match 'GetRetrieveFetch') { $verb = 'Get' }
        elseif ($allParts -match 'RemoveDeleteCleanReset') { $verb = 'Remove' }
        elseif ($allParts -match 'TestCheckVerify') { $verb = 'Test' }
        
        $noun = $allParts
    }
    
    # Ensure we have both verb and noun
    if (-not $noun) { $noun = 'Task' }
    
            $runnerScriptsPath = Join-Path $PSScriptRoot ".." ".." "core-runner" "core_app" "scripts"
        if (Test-Path $runnerScriptsPath) {
            $existingScripts = Get-ChildItem $runnerScriptsPath -Filter "*.ps1" | Where-Object{ $_.Name -match '^0-9{4}_' } | ForEach-Object{ int($_.Name.Substring(0,4)) } | Sort-Object$nextNumber = if ($existingScripts.Count -gt 0) { $existingScripts-1 + 1    } else { 100    }
        } else {
            $nextNumber = 100
        }
        $formattedName = "{0:D4}_{1}" -f $nextNumber, $formattedName
    }
    
    return "$formattedName.ps1"
}

function Watch-ScriptDirectory {
    <#
    .SYNOPSIS
    Monitors directory for new scripts and auto-generates tests
    #>
    param(string$Directory, int$IntervalSeconds = 30)
    
    Write-Host "Starting script directory watcher for: $Directory" -ForegroundColor Green
    Write-Host "Checking every $IntervalSeconds seconds. Press Ctrl+C to stop." -ForegroundColor Yellow
    
    $processedFiles = @{}
    
    while ($true) {
        try {
            $scriptFiles = Get-ChildItem $Directory -Filter "*.ps1" -Recurse | Where-Object{ -not $_.Name.EndsWith('.Tests.ps1') }
            
            foreach ($script in $scriptFiles) {
                $key = $script.FullName
                $lastWrite = $script.LastWriteTime
                
                # Check if file is new or modified
                if (-not $processedFiles.ContainsKey($key) -or $processedFiles$key -lt $lastWrite) {
                    Write-Host "Detected new/modified script: $($script.Name)" -ForegroundColor Cyan
                    
                    try {
                        # Format script name if needed
                        $formattedName = Format-ScriptName $script.Name
                        if ($formattedName -ne $script.Name) {
                            $newPath = Join-Path $script.Directory $formattedName
                            Write-Host "Renaming script to follow convention: $($script.Name) -> $formattedName" -ForegroundColor Yellow
                            Move-Item $script.FullName $newPath
                            $script = Get-Item $newPath
                        }
                        
                        # Generate test if it doesn't exist
                            
                        $processedFiles$key = $lastWrite
                        
                    } catch {
                        Write-Error "Failed to process script $($script.Name): $_"
                    }
                }
            }
            
            Start-Sleep $IntervalSeconds
            
        } catch {
            Write-Error "Error in watch loop: $_"
            Start-Sleep 5
        }
    }
}

function New-TestForScript {
    <#
    .SYNOPSIS
        $scriptName = System.IO.Path::GetFileName($ScriptPath)
    Write-Host "Analyzing script: $scriptName" -ForegroundColor Cyan
    
    $analysis = Get-ScriptAnalysis $ScriptPath
    $template = New-TestTemplate -ScriptName $scriptName -Analysis $analysis -ScriptPath $ScriptPath
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
    
    Set-Content -Path $OutputPath -Value $template -Encoding UTF8
    Write-Host "Generated test file: $OutputPath" -ForegroundColor Green
    
    # Update test index if it exists
    $indexPath = Join-Path (Split-Path $OutputPath -Parent) 'test-index.json'
    if (Test-Path $indexPath) {
        $index = Get-Content $indexPath | ConvertFrom-Json} else {
        $index = @{
            Tests = @()
            LastUpdated = Get-Date
        }
    }
    
    $testInfo = @{
        TestFile = System.IO.Path::GetFileName($OutputPath)
        SourceScript = $scriptName
        Category = $analysis.Category
        Platform = $analysis.Platform
        Generated = Get-Date
        Functions = $analysis.Functions.Name
    }
    
    # Remove existing entry for this script if present
    $index.Tests = $index.Tests | Where-Object{ $_.SourceScript -ne $scriptName }
    if ($ScriptPath) {
    # Generate test for specific script
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script not found: $ScriptPath"
        exit 1
    }
    
    $testName = System.IO.Path::GetFileNameWithoutExtension($ScriptPath) + '.Tests.ps1'
    $testPath = Join-Path $OutputDirectory $testName
    
    if ((Test-Path $testPath) -and -not $Force) {
        Write-Warning "Test file already exists: $testPath. Use -Force to overwrite."
        exit 0
    }
    
    New-TestForScript -ScriptPath $ScriptPath -OutputPath $testPath
    
} elseif ($WatchMode) {
    # Start directory watcher
    $fullWatchPath = Join-Path $PSScriptRoot ".." ".." $WatchDirectory
    if (-not (Test-Path $fullWatchPath)) {
        Write-Error "Watch directory not found: $fullWatchPath"
        exit 1
    }
    
    Watch-ScriptDirectory -Directory $fullWatchPath -IntervalSeconds $WatchIntervalSeconds
    
} else {
        $scriptFiles = Get-ChildItem $fullWatchPath -Filter "*.ps1" -Recurse | Where-Object{ -not $_.Name.EndsWith('.Tests.ps1') }
    
    Write-Host "Found $($scriptFiles.Count) scripts to process" -ForegroundColor Green
    
    foreach ($script in $scriptFiles) {
        $testName = $script.Name -replace '\.ps1$', '.Tests.ps1'
        $testPath = Join-Path $OutputDirectory $testName
        
        if (-not (Test-Path $testPath) -or $Force) {
            try {
                New-TestForScript -ScriptPath $script.FullName -OutputPath $testPath
            } catch {
                Write-Error "Failed to generate test for $($script.Name): $_"
            }
        } else {
            Write-Host "Skipping existing test: $testName (use -Force to regenerate)" -ForegroundColor Yellow
        }
    }
}
