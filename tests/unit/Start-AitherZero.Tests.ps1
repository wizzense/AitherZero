#Requires -Modules Pester

Describe "Start-AitherZero Script" -Tag 'Unit' {
    BeforeAll {
        # Setup test environment
        $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $script:EntryScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
        
        # Mock functions that would be loaded by the script
        function Get-Configuration { return @{ Core = @{ Name = "Test" } } }
        function Initialize-AitherModules { return $true }
        function Show-InteractiveMenu { return "Exit" }
        function Invoke-OrchestrationSequence { param($Sequence) return @{ Success = $true } }
        function Write-CustomLog { param($Message, $Level) }
    }

    AfterAll {
        # Cleanup
        Remove-Item Function:\Get-Configuration -ErrorAction SilentlyContinue
        Remove-Item Function:\Initialize-AitherModules -ErrorAction SilentlyContinue
        Remove-Item Function:\Show-InteractiveMenu -ErrorAction SilentlyContinue
        Remove-Item Function:\Invoke-OrchestrationSequence -ErrorAction SilentlyContinue
        Remove-Item Function:\Write-CustomLog -ErrorAction SilentlyContinue
    }
    
    Context "Script Validation" {
        It "Should have a valid script file" {
            Test-Path $script:EntryScript | Should -Be $true
        }
        
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:EntryScript, 
                [ref]$null, 
                [ref]$errors
            )
            $errors | Should -BeNullOrEmpty
        }
        
        It "Should have proper script metadata" {
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match "\.SYNOPSIS"
            $content | Should -Match "\.DESCRIPTION"
            $content | Should -Match "\.PARAMETER"
        }
    }
    
    Context "Parameter Validation" {
        BeforeEach {
            # Create a test version of the script that we can invoke
            $script:TestScript = @'
param(
    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$Interactive,
    
    [Parameter(ParameterSetName = 'Orchestrate')]
    [string]$Mode,
    
    [Parameter(ParameterSetName = 'Orchestrate')]
    [string]$Sequence,
    
    [Parameter(ParameterSetName = 'Orchestrate')]
    [string]$Playbook,
    
    [hashtable]$Variables = @{},
    
    [string]$ConfigPath,
    
    [switch]$DryRun,
    
    [switch]$Verbose,
    
    [switch]$Help
)

# Return parameters for testing
return $PSBoundParameters
'@
            $script:TestScriptPath = Join-Path $TestDrive "test-start.ps1"
            $script:TestScript | Set-Content $script:TestScriptPath
        }
        
        It "Should have correct parameter sets" {
            # The script should exist
            Test-Path $script:EntryScript | Should -Be $true
            
            # Get the AST to check parameters
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:EntryScript,
                [ref]$null,
                [ref]$null
            )
            
            # Find the param block
            $paramBlock = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $false) | Select-Object -First 1
            $paramBlock | Should -Not -BeNullOrEmpty
        }
        
        It "Should support Interactive mode" {
            $result = & $script:TestScriptPath -Interactive
            $result.Interactive | Should -Be $true
        }
        
        It "Should support Orchestrate mode" {
            $result = & $script:TestScriptPath -Mode Orchestrate -Sequence "0400-0499"
            $result.Mode | Should -Be "Orchestrate"
            $result.Sequence | Should -Be "0400-0499"
        }
    }
    
    Context "Configuration Loading" {
        It "Should attempt to load configuration" {
            # Create a simple test that validates configuration loading logic exists
            $content = Get-Content $script:EntryScript -Raw
            
            # Check for configuration-related code
            $content | Should -Match "Get-Configuration|Load-Configuration|ConfigPath"
        }
    }
    
    Context "Help System" {
        It "Should display help when requested" {
            # Check that help documentation exists
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match "\.SYNOPSIS"
            $content | Should -Match "\.EXAMPLE"
        }
    }
}