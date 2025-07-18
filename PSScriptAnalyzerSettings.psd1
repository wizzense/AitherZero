@{
    # PSScriptAnalyzer settings for AitherZero project
    
    # Use severity for filtering
    Severity = @('Error', 'Warning', 'Information')
    
    # Include all default rules
    IncludeDefaultRules = $true
    
    # Exclude specific rules that don't apply to our project
    ExcludeRules = @(
        # We use aliases in interactive scripts
        'PSAvoidUsingCmdletAliases',
        
        # We use Write-Host for CLI output
        'PSAvoidUsingWriteHost',
        
        # We use positional parameters in some cases
        'PSAvoidUsingPositionalParameters',
        
        # We use Invoke-Expression for dynamic module loading
        'PSAvoidUsingInvokeExpression',
        
        # We check for commands differently
        'PSUseApprovedVerbs',
        
        # We use ConvertTo-SecureString with plain text in tests
        'PSAvoidUsingConvertToSecureStringWithPlainText'
    )
    
    # Include custom rules
    Rules = @{
        # Compatibility rules
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @(
                '7.0',
                '7.1',
                '7.2',
                '7.3',
                '7.4'
            )
        }
        
        # Ensure proper module structure
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false
            BlockComment = $true
            VSCodeSnippetCorrection = $true
            Placement = 'before'
        }
    }
    
    # Custom rule paths (if we add any)
    # CustomRulePath = @('./scripts/PSScriptAnalyzer/CustomRules')
    
    # Recurse through subdirectories
    RecurseCustomRulePath = $true
}