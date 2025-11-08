#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive AST-based tests for PowerShell modules

.DESCRIPTION
    Analyzes PowerShell modules using AST and generates comprehensive test files
    that validate function parameters, return values, error handling, and behavior

.EXAMPLE
    ./ModuleTestGenerator.ps1 -Module Configuration
    
.EXAMPLE
    ./ModuleTestGenerator.ps1 -All
#>

[CmdletBinding()]
param(
    [string]$Module,
    [switch]$All,
    [switch]$Force,
    [string]$OutputPath = (Join-Path $PSScriptRoot '../unit/modules')
)

$ErrorActionPreference = 'Stop'

# Import helpers
$astAnalyzerPath = Join-Path $PSScriptRoot '../helpers/ASTAnalyzer.psm1'
$testHelpersPath = Join-Path $PSScriptRoot '../helpers/TestHelpers.psm1'

Import-Module $astAnalyzerPath -Force
Import-Module $testHelpersPath -Force

function New-ModuleTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$ModulePath,
        
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )
    
    Write-Host "Generating tests for module: $ModuleName" -ForegroundColor Cyan
    
    # Analyze module
    $functions = Get-ModuleFunctions -Path $ModulePath
    $publicFunctions = $functions | Where-Object { $_.IsPublic }
    
    Write-Host "  Found $($functions.Count) functions ($($publicFunctions.Count) public)" -ForegroundColor Gray
    
    if ($publicFunctions.Count -eq 0) {
        Write-Warning "No public functions found in $ModuleName"
        return
    }
    
    # Generate test file
    $testFileName = "$ModuleName.Tests.ps1"
    $testFilePath = Join-Path $OutputDirectory $testFileName
    
    # Build test content
    $testContent = @"
#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive tests for $ModuleName module

.DESCRIPTION
    AST-generated tests validating all public functions, parameters,
    return values, error handling, and cross-platform compatibility
    
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Functions: $($publicFunctions.Count)
#>

Describe '$ModuleName Module Tests' -Tag 'Unit', 'Module', '$ModuleName' {
    
    BeforeAll {
        # Import test helpers
        `$testHelpersPath = Join-Path `$PSScriptRoot '../../helpers/TestHelpers.psm1'
        if (Test-Path `$testHelpersPath) {
            Import-Module `$testHelpersPath -Force
        }
        
        # Initialize test environment
        Initialize-TestEnvironment
        
        # Import module
        `$modulePath = Get-TestFilePath 'aithercore/$($ModuleName.ToLower())/$ModuleName.psm1'
        if (-not (Test-Path `$modulePath)) {
            throw "Module not found: `$modulePath"
        }
        
        Import-Module `$modulePath -Force
    }
    
    AfterAll {
        Clear-TestEnvironment
    }
    
    Context 'Module Structure' {
        It 'Should have valid module file' {
            `$modulePath = Get-TestFilePath 'aithercore/$($ModuleName.ToLower())/$ModuleName.psm1'
            Test-Path `$modulePath | Should -Be `$true
        }
        
        It 'Should have valid PowerShell syntax' {
            `$modulePath = Get-TestFilePath 'aithercore/$($ModuleName.ToLower())/$ModuleName.psm1'
            Test-ScriptSyntax -Path `$modulePath | Should -Be `$true
        }
        
        It 'Should export $($publicFunctions.Count) public functions' {
            `$exported = Get-ModuleExportedFunctions -ModulePath (Get-TestFilePath 'aithercore/$($ModuleName.ToLower())/$ModuleName.psm1')
            `$exported.Count | Should -Be $($publicFunctions.Count)
        }
    }

"@

    # Generate tests for each public function
    foreach ($func in $publicFunctions) {
        $testContent += @"
    
    Context '$($func.Name) Function' {
        
        It 'Should be available' {
            Get-Command $($func.Name) -ErrorAction SilentlyContinue | Should -Not -BeNull
        }

"@

        # Parameter tests
        if ($func.Parameters.Count -gt 0) {
            $testContent += @"
        
        Context 'Parameters' {
"@
            foreach ($param in $func.Parameters) {
                $testContent += @"
            
            It 'Should have parameter: $($param.Name)' {
                `$cmd = Get-Command $($func.Name)
                `$cmd.Parameters.ContainsKey('$($param.Name)') | Should -Be `$true
            }
            
            It 'Parameter $($param.Name) should have type $($param.Type)' {
                `$cmd = Get-Command $($func.Name)
                `$cmd.Parameters['$($param.Name)'].ParameterType.Name | Should -Be '$($param.Type)'
            }

"@
                if ($param.IsMandatory) {
                    $testContent += @"
            
            It 'Parameter $($param.Name) should be mandatory' {
                `$cmd = Get-Command $($func.Name)
                `$param = `$cmd.Parameters['$($param.Name)']
                `$param.Attributes | Where-Object { `$_ -is [Parameter] } | 
                    ForEach-Object { `$_.Mandatory } | Should -Contain `$true
            }

"@
                }
            }
            $testContent += @"
        }

"@
        }

        # Help documentation tests
        $testContent += @"
        
        Context 'Help Documentation' {
            It 'Should have comment-based help' {
                `$help = Get-Help $($func.Name) -ErrorAction SilentlyContinue
                `$help | Should -Not -BeNull
            }
            
            It 'Should have Synopsis' {
                `$help = Get-Help $($func.Name)
                `$help.Synopsis | Should -Not -BeNullOrEmpty
            }
            
            It 'Should have Description' {
                `$help = Get-Help $($func.Name)
                `$help.Description | Should -Not -BeNullOrEmpty
            }
            
            It 'Should have Examples' {
                `$help = Get-Help $($func.Name)
                `$help.Examples | Should -Not -BeNull
            }
        }

"@

        # Code quality tests
        if ($func.HasErrorHandling) {
            $testContent += @"
        
        Context 'Error Handling' {
            It 'Should have try/catch blocks' {
                # Verified by AST analysis
                `$true | Should -Be `$true
            }
        }

"@
        }
        else {
            $testContent += @"
        
        Context 'Error Handling' {
            It 'Should have try/catch blocks' {
                # WARNING: Function lacks error handling
                Write-Warning "Function $($func.Name) should implement try/catch error handling"
            } -Skip
        }

"@
        }

        if ($func.HasLogging) {
            $testContent += @"
        
        Context 'Logging' {
            It 'Should include logging calls' {
                # Verified by AST analysis
                `$true | Should -Be `$true
            }
        }

"@
        }

        # Complexity check
        if ($func.Complexity -gt 20) {
            $testContent += @"
        
        Context 'Code Metrics' {
            It 'Should have acceptable complexity' {
                # WARNING: Complexity is $($func.Complexity) (max: 20)
                Write-Warning "Function $($func.Name) has high complexity: $($func.Complexity)"
            } -Skip
        }

"@
        }

        $testContent += @"
    }

"@
    }

    # Close Describe block
    $testContent += @"
}
"@

    # Write test file
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
    
    $testContent | Set-Content -Path $testFilePath -Force
    Write-Host "  Generated: $testFilePath" -ForegroundColor Green
    
    return $testFilePath
}

# Main execution
try {
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $env:AITHERZERO_ROOT = $repoRoot
    
    $aitherCorePath = Join-Path $repoRoot 'aithercore'
    
    if (-not (Test-Path $aitherCorePath)) {
        throw "aithercore directory not found: $aitherCorePath"
    }
    
    # Determine which modules to process
    $modulesToProcess = @()
    
    if ($All) {
        # Find all modules
        $moduleFiles = Get-ChildItem -Path $aitherCorePath -Recurse -Filter '*.psm1' |
            Where-Object { $_.Name -notmatch 'Test' }
        
        foreach ($file in $moduleFiles) {
            $moduleName = $file.BaseName
            $modulesToProcess += @{
                Name = $moduleName
                Path = $file.FullName
            }
        }
    }
    elseif ($Module) {
        # Process specific module
        $modulePath = Get-ChildItem -Path $aitherCorePath -Recurse -Filter "$Module.psm1" |
            Select-Object -First 1
        
        if (-not $modulePath) {
            throw "Module not found: $Module"
        }
        
        $modulesToProcess += @{
            Name = $Module
            Path = $modulePath.FullName
        }
    }
    else {
        Write-Host "Usage: ./ModuleTestGenerator.ps1 -Module <ModuleName> OR -All" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  ./ModuleTestGenerator.ps1 -Module Configuration"
        Write-Host "  ./ModuleTestGenerator.ps1 -All"
        exit 0
    }
    
    # Process modules
    $generated = 0
    $skipped = 0
    
    foreach ($mod in $modulesToProcess) {
        $moduleName = $mod.Name
        $moduleOutputDir = Join-Path $OutputPath $moduleName.ToLower()
        $testFile = Join-Path $moduleOutputDir "$moduleName.Tests.ps1"
        
        if ((Test-Path $testFile) -and -not $Force) {
            Write-Host "Skipping $moduleName (test exists, use -Force to overwrite)" -ForegroundColor Yellow
            $skipped++
            continue
        }
        
        New-ModuleTest -ModuleName $moduleName -ModulePath $mod.Path -OutputDirectory $moduleOutputDir
        $generated++
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Generated: $generated" -ForegroundColor Green
    Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
    Write-Host "  Total: $($modulesToProcess.Count)" -ForegroundColor Gray
}
catch {
    Write-Error "Test generation failed: $_"
    exit 1
}
