#Requires -Version 7.0

<#
.SYNOPSIS
    AST-based code analysis utilities for test generation and validation

.DESCRIPTION
    Provides functions to parse PowerShell code using AST (Abstract Syntax Tree)
    and extract information about modules, functions, parameters, and code structure
#>

function Get-ModuleFunctions {
    <#
    .SYNOPSIS
        Extract all functions from a PowerShell module using AST
    
    .PARAMETER Path
        Path to the .psm1 file
    
    .OUTPUTS
        Array of hashtables with function information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Module file not found: $Path"
    }
    
    $content = Get-Content -Path $Path -Raw
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    
    $functions = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    
    $results = @()
    foreach ($func in $functions) {
        $functionInfo = @{
            Name = $func.Name
            Parameters = @()
            HasCommentHelp = $false
            HelpContent = @{}
            IsPublic = $false  # Will be determined by Export-ModuleMember
            Complexity = 0
            LineCount = 0
            HasErrorHandling = $false
            HasLogging = $false
        }
        
        # Extract parameters
        if ($func.Parameters) {
            foreach ($param in $func.Parameters) {
                $paramInfo = @{
                    Name = $param.Name.VariablePath.UserPath
                    Type = if ($param.StaticType) { $param.StaticType.Name } else { 'object' }
                    IsMandatory = $false
                    HasDefault = $param.DefaultValue -ne $null
                    DefaultValue = if ($param.DefaultValue) { $param.DefaultValue.Extent.Text } else { $null }
                    Attributes = @()
                }
                
                # Extract parameter attributes
                foreach ($attr in $param.Attributes) {
                    if ($attr.TypeName.Name -eq 'Parameter') {
                        foreach ($arg in $attr.NamedArguments) {
                            if ($arg.ArgumentName -eq 'Mandatory') {
                                $paramInfo.IsMandatory = $arg.Argument.Extent.Text -eq '$true'
                            }
                        }
                    }
                    $paramInfo.Attributes += $attr.TypeName.Name
                }
                
                $functionInfo.Parameters += $paramInfo
            }
        }
        
        # Check for comment-based help
        $helpContent = $func.GetHelpContent()
        if ($helpContent) {
            $functionInfo.HasCommentHelp = $true
            $functionInfo.HelpContent = @{
                Synopsis = $helpContent.Synopsis
                Description = $helpContent.Description
                Examples = $helpContent.Examples
            }
        }
        
        # Calculate metrics
        $functionInfo.LineCount = $func.Extent.EndLineNumber - $func.Extent.StartLineNumber + 1
        
        # Check for error handling (try/catch)
        $tryStatements = $func.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TryStatementAst]
        }, $true)
        $functionInfo.HasErrorHandling = $tryStatements.Count -gt 0
        
        # Check for logging calls
        $commandCalls = $func.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true)
        
        $loggingCommands = @('Write-CustomLog', 'Write-Log', 'Write-ScriptLog', 'Write-Verbose', 'Write-Debug')
        $functionInfo.HasLogging = $commandCalls | Where-Object {
            $cmd = $_.GetCommandName()
            $cmd -in $loggingCommands
        }
        
        # Calculate cyclomatic complexity (simplified)
        $functionInfo.Complexity = Get-CyclomaticComplexity -Ast $func.Body
        
        $results += $functionInfo
    }
    
    # Check Export-ModuleMember to determine public functions
    $exportCalls = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Export-ModuleMember'
    }, $true)
    
    if ($exportCalls) {
        foreach ($export in $exportCalls) {
            # Extract function names from Export-ModuleMember
            $functionParam = $export.CommandElements | Where-Object {
                $_ -is [System.Management.Automation.Language.CommandParameterAst] -and
                $_.ParameterName -eq 'Function'
            }
            
            if ($functionParam) {
                $valueIndex = $export.CommandElements.IndexOf($functionParam) + 1
                if ($valueIndex -lt $export.CommandElements.Count) {
                    $value = $export.CommandElements[$valueIndex]
                    if ($value.Extent.Text -match "'([^']+)'|`"([^`"]+)`"") {
                        $exportedFunctions = $Matches[1] -split ',' | ForEach-Object { $_.Trim() }
                        foreach ($func in $results) {
                            if ($func.Name -in $exportedFunctions) {
                                $func.IsPublic = $true
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $results
}

function Get-CyclomaticComplexity {
    <#
    .SYNOPSIS
        Calculate cyclomatic complexity of a code block
    
    .PARAMETER Ast
        The AST node to analyze
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Ast
    )
    
    $complexity = 1  # Base complexity
    
    # Count decision points
    $decisionPoints = $Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] -or
        $node -is [System.Management.Automation.Language.SwitchStatementAst] -or
        $node -is [System.Management.Automation.Language.WhileStatementAst] -or
        $node -is [System.Management.Automation.Language.ForStatementAst] -or
        $node -is [System.Management.Automation.Language.ForEachStatementAst] -or
        $node -is [System.Management.Automation.Language.CatchClauseAst]
    }, $true)
    
    $complexity += $decisionPoints.Count
    
    # Count logical operators (&&, ||)
    $logicalOps = $Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.BinaryExpressionAst] -and
        ($node.Operator -eq 'And' -or $node.Operator -eq 'Or')
    }, $true)
    
    $complexity += $logicalOps.Count
    
    return $complexity
}

function Get-ScriptMetadata {
    <#
    .SYNOPSIS
        Extract metadata from automation script
    
    .PARAMETER Path
        Path to the script file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $content = Get-Content -Path $Path -Raw
    $metadata = @{
        Stage = $null
        Order = $null
        Dependencies = @()
        Tags = @()
        RequiresAdmin = $false
        SupportsWhatIf = $false
        Description = $null
    }
    
    # Parse metadata from comment block
    if ($content -match '\.NOTES\s+Stage:\s*(\w+)') {
        $metadata.Stage = $Matches[1]
    }
    
    if ($content -match 'Order:\s*(\d+)') {
        $metadata.Order = [int]$Matches[1]
    }
    
    if ($content -match 'Dependencies:\s*([^\r\n]+)') {
        $depsString = $Matches[1].Trim()
        if ($depsString -ne 'None' -and $depsString) {
            $metadata.Dependencies = $depsString -split '[,\s]+' | Where-Object { $_ }
        }
    }
    
    if ($content -match 'Tags:\s*([^\r\n]+)') {
        $tagsString = $Matches[1].Trim()
        $metadata.Tags = $tagsString -split '[,\s]+' | Where-Object { $_ }
    }
    
    if ($content -match 'RequiresAdmin:\s*(true|false)') {
        $metadata.RequiresAdmin = $Matches[1] -eq 'true'
    }
    
    if ($content -match 'SupportsShouldProcess') {
        $metadata.SupportsWhatIf = $true
    }
    
    if ($content -match '\.DESCRIPTION\s+([^\r\n]+)') {
        $metadata.Description = $Matches[1].Trim()
    }
    
    return $metadata
}

function Get-ScriptParameters {
    <#
    .SYNOPSIS
        Extract parameters from a script using AST
    
    .PARAMETER Path
        Path to the script file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $content = Get-Content -Path $Path -Raw
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    
    $paramBlock = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.ParamBlockAst]
    }, $true)
    
    if (-not $paramBlock) {
        return @()
    }
    
    $parameters = @()
    foreach ($param in $paramBlock.Parameters) {
        $paramInfo = @{
            Name = $param.Name.VariablePath.UserPath
            Type = if ($param.StaticType) { $param.StaticType.Name } else { 'object' }
            IsMandatory = $false
            HasDefault = $param.DefaultValue -ne $null
            DefaultValue = if ($param.DefaultValue) { $param.DefaultValue.Extent.Text } else { $null }
            Attributes = @()
        }
        
        foreach ($attr in $param.Attributes) {
            if ($attr.TypeName.Name -eq 'Parameter') {
                foreach ($arg in $attr.NamedArguments) {
                    if ($arg.ArgumentName -eq 'Mandatory') {
                        $paramInfo.IsMandatory = $arg.Argument.Extent.Text -eq '$true'
                    }
                }
            }
            $paramInfo.Attributes += $attr.TypeName.Name
        }
        
        $parameters += $paramInfo
    }
    
    return $parameters
}

function Test-CodeQuality {
    <#
    .SYNOPSIS
        Perform quality checks on PowerShell code
    
    .PARAMETER Path
        Path to file to analyze
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $issues = @()
    $content = Get-Content -Path $Path -Raw
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    
    # Check for functions without error handling
    $functions = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    
    foreach ($func in $functions) {
        $tryStatements = $func.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TryStatementAst]
        }, $true)
        
        if ($tryStatements.Count -eq 0) {
            $issues += @{
                Type = 'MissingErrorHandling'
                Function = $func.Name
                Line = $func.Extent.StartLineNumber
                Message = "Function '$($func.Name)' lacks try/catch error handling"
            }
        }
    }
    
    # Check for high complexity
    foreach ($func in $functions) {
        $complexity = Get-CyclomaticComplexity -Ast $func.Body
        if ($complexity -gt 20) {
            $issues += @{
                Type = 'HighComplexity'
                Function = $func.Name
                Complexity = $complexity
                Line = $func.Extent.StartLineNumber
                Message = "Function '$($func.Name)' has high complexity: $complexity (max: 20)"
            }
        }
    }
    
    return $issues
}

# Export functions
Export-ModuleMember -Function @(
    'Get-ModuleFunctions',
    'Get-CyclomaticComplexity',
    'Get-ScriptMetadata',
    'Get-ScriptParameters',
    'Test-CodeQuality'
)
