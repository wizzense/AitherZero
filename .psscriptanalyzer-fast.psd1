@{
    # Fast PSScriptAnalyzer configuration for CI environments
    # Only run critical rules that matter for production code
    
    # Include only critical rules that catch real bugs
    IncludeRules = @(
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword', 
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSPossibleIncorrectComparisonWithNull',
        'PSAvoidGlobalVars',
        'PSAvoidUsingCmdletAliases',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSMisleadingBacktick',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidDefaultValueSwitchParameter'
    )
    
    # Exclude directories with non-production code  
    ExcludeRules = @(
        'PSUseSingularNouns',           # Too many false positives
        'PSUseApprovedVerbs',          # Not critical for functionality
        'PSAvoidUsingWriteHost',       # Acceptable for logging scripts
        'PSUseShouldProcessForStateChangingFunctions',  # Too verbose for automation
        'PSProvideCommentHelp'         # Documentation rule, not critical
    )
    
    # Severity threshold - only errors and warnings, skip information
    Severity = @('Error', 'Warning')
}