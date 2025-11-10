#Requires -Version 7.0

<#
.SYNOPSIS
    PowerShell script analysis and AST parsing utilities

.DESCRIPTION
    Provides easy-to-use cmdlets for analyzing PowerShell scripts using the
    Abstract Syntax Tree (AST) parser. Makes complex parsing operations simple.

.NOTES
    Module: ScriptAnalysis
    Domain: Utilities
    Purpose: Simplify PowerShell script analysis and validation
#>

function Test-ScriptSyntax {
    <#
    .SYNOPSIS
        Test PowerShell script syntax using AST parser
    
    .DESCRIPTION
        Parses a PowerShell script file or script block and reports any syntax errors.
        Much easier than remembering the complex AST parser syntax!
    
    .PARAMETER Path
        Path to the PowerShell script file to analyze
    
    .PARAMETER ScriptBlock
        Script block to analyze
    
    .PARAMETER Detailed
        Show detailed error information including extent and position
    
    .OUTPUTS
        Boolean (when -PassThru not specified)
        PSCustomObject with parsing results (when errors exist or -Detailed)
    
    .EXAMPLE
        Test-ScriptSyntax -Path ./my-script.ps1
        Returns $true if valid, $false if errors
    
    .EXAMPLE
        Test-ScriptSyntax -Path ./my-script.ps1 -Detailed
        Shows detailed syntax error information
    
    .EXAMPLE
        Get-ChildItem *.ps1 | Test-ScriptSyntax
        Test all PS1 files in current directory
    
    .EXAMPLE
        Test-ScriptSyntax -ScriptBlock { Get-Process; Write-Host "test" }
        Test a script block for syntax errors
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([bool], [PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FilePath', 'FullName')]
        [string]$Path,
        
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    process {
        try {
            $errors = $null
            $tokens = $null
            $ast = $null
            
            if ($PSCmdlet.ParameterSetName -eq 'Path') {
                # Resolve path
                $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
                
                # Parse file
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $resolvedPath,
                    [ref]$tokens,
                    [ref]$errors
                )
                
                $source = $resolvedPath
            }
            else {
                # Parse script block
                $ast = [System.Management.Automation.Language.Parser]::ParseInput(
                    $ScriptBlock.ToString(),
                    [ref]$tokens,
                    [ref]$errors
                )
                
                $source = "ScriptBlock"
            }
            
            # Prepare result
            $hasErrors = $null -ne $errors -and $errors.Count -gt 0
            
            if ($hasErrors -or $Detailed) {
                $result = [PSCustomObject]@{
                    Source      = $source
                    Valid       = -not $hasErrors
                    ErrorCount  = if ($errors) { $errors.Count } else { 0 }
                    Errors      = $errors
                    TokenCount  = if ($tokens) { $tokens.Count } else { 0 }
                    AST         = $ast
                }
                
                # Add custom type for better formatting
                $result.PSObject.TypeNames.Insert(0, 'AitherZero.ScriptAnalysis.SyntaxResult')
                
                if ($hasErrors) {
                    Write-Output $result
                } else {
                    Write-Output $result
                }
            }
            else {
                # Simple boolean output
                Write-Output (-not $hasErrors)
            }
        }
        catch {
            Write-Error "Failed to parse script: $_"
            if ($Detailed) {
                [PSCustomObject]@{
                    Source      = $Path ?? "ScriptBlock"
                    Valid       = $false
                    ErrorCount  = 1
                    Errors      = @([PSCustomObject]@{
                        Message = $_.Exception.Message
                        Exception = $_.Exception
                    })
                    TokenCount  = 0
                    AST         = $null
                }
            } else {
                Write-Output $false
            }
        }
    }
}

function Get-ScriptAST {
    <#
    .SYNOPSIS
        Get the Abstract Syntax Tree for a PowerShell script
    
    .DESCRIPTION
        Parses a PowerShell script and returns the AST, tokens, and any errors.
        Simplifies working with the PowerShell parser.
    
    .PARAMETER Path
        Path to the PowerShell script file
    
    .PARAMETER IncludeTokens
        Include token information in the output
    
    .PARAMETER IncludeErrors
        Include parsing errors in the output (always included if errors exist)
    
    .OUTPUTS
        PSCustomObject with AST, Tokens (optional), and Errors (if any)
    
    .EXAMPLE
        $ast = Get-ScriptAST -Path ./my-script.ps1
        $functions = $ast.AST.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    
    .EXAMPLE
        Get-ScriptAST -Path ./script.ps1 -IncludeTokens | Select-Object -ExpandProperty Tokens
        Get all tokens from a script
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FilePath', 'FullName')]
        [string]$Path,
        
        [Parameter()]
        [switch]$IncludeTokens,
        
        [Parameter()]
        [switch]$IncludeErrors
    )
    
    process {
        try {
            $errors = $null
            $tokens = $null
            
            # Resolve path
            $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
            
            # Parse file
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $resolvedPath,
                [ref]$tokens,
                [ref]$errors
            )
            
            $result = [PSCustomObject]@{
                Path   = $resolvedPath
                AST    = $ast
            }
            
            if ($IncludeTokens) {
                $result | Add-Member -NotePropertyName 'Tokens' -NotePropertyValue $tokens
            }
            
            if ($errors -or $IncludeErrors) {
                $result | Add-Member -NotePropertyName 'Errors' -NotePropertyValue $errors
                $result | Add-Member -NotePropertyName 'HasErrors' -NotePropertyValue ($null -ne $errors -and $errors.Count -gt 0)
            }
            
            Write-Output $result
        }
        catch {
            Write-Error "Failed to get AST for '$Path': $_"
        }
    }
}

function Find-ScriptFunction {
    <#
    .SYNOPSIS
        Find all function definitions in a PowerShell script
    
    .DESCRIPTION
        Extracts function definitions from a script using AST parsing.
        Much easier than manually traversing the AST!
    
    .PARAMETER Path
        Path to the PowerShell script file
    
    .PARAMETER Name
        Optional function name to search for (supports wildcards)
    
    .OUTPUTS
        PSCustomObject with function information
    
    .EXAMPLE
        Find-ScriptFunction -Path ./module.psm1
        Find all functions in a module
    
    .EXAMPLE
        Find-ScriptFunction -Path ./script.ps1 -Name "Write-*"
        Find all functions starting with "Write-"
    
    .EXAMPLE
        $func = Find-ScriptFunction -Path ./script.ps1 -Name "MyFunction"
        $func.Definition  # Get the full function code
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FilePath', 'FullName')]
        [string]$Path,
        
        [Parameter(Position = 1)]
        [SupportsWildcards()]
        [string]$Name = '*'
    )
    
    process {
        try {
            $astResult = Get-ScriptAST -Path $Path
            
            $functions = $astResult.AST.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)
            
            foreach ($func in $functions) {
                if ($func.Name -like $Name) {
                    [PSCustomObject]@{
                        Name       = $func.Name
                        Parameters = $func.Parameters.Name
                        Definition = $func.Extent.Text
                        StartLine  = $func.Extent.StartLineNumber
                        EndLine    = $func.Extent.EndLineNumber
                        Path       = $Path
                        AST        = $func
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to find functions in '$Path': $_"
        }
    }
}

function Invoke-ScriptAnalysis {
    <#
    .SYNOPSIS
        Comprehensive script analysis combining multiple checks
    
    .DESCRIPTION
        Runs multiple analysis checks on a PowerShell script:
        - Syntax validation
        - Function detection
        - Parameter analysis
        - Comment-based help detection
    
    .PARAMETER Path
        Path to the PowerShell script file
    
    .OUTPUTS
        PSCustomObject with comprehensive analysis results
    
    .EXAMPLE
        Invoke-ScriptAnalysis -Path ./my-script.ps1
        Get comprehensive analysis of a script
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FilePath', 'FullName')]
        [string]$Path
    )
    
    process {
        try {
            # Get AST
            $astResult = Get-ScriptAST -Path $Path -IncludeTokens -IncludeErrors
            
            # Find functions
            $functions = Find-ScriptFunction -Path $Path
            
            # Find comment-based help
            $helpComments = $astResult.AST.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommentBlockAst]
            }, $true)
            
            # Count parameters
            $parameters = $astResult.AST.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.ParameterAst]
            }, $true)
            
            [PSCustomObject]@{
                Path            = $astResult.Path
                Valid           = -not $astResult.HasErrors
                Errors          = $astResult.Errors
                FunctionCount   = $functions.Count
                Functions       = $functions.Name
                ParameterCount  = $parameters.Count
                HasCommentHelp  = $helpComments.Count -gt 0
                TokenCount      = $astResult.Tokens.Count
                LineCount       = (Get-Content $Path).Count
            }
        }
        catch {
            Write-Error "Failed to analyze '$Path': $_"
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Test-ScriptSyntax'
    'Get-ScriptAST'
    'Find-ScriptFunction'
    'Invoke-ScriptAnalysis'
)
