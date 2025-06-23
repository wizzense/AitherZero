@{
    IncludeRules = @(
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace', 
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSAvoidTrailingWhitespace',
        'PSUseCompatibleSyntax',
        'PSAvoidUsingPositionalParameters',
        'PSReviewUnusedParameter',
        'PSUseDeclaredVarsMoreThanAssignments'
    )
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingWriteHost',
        'PSAvoidGlobalVars',
        'PSAvoidUsingPlainTextForPassword'
    )
    # Custom rule settings
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
    }
}



