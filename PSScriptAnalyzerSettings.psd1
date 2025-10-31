@{
    # Select which rules to run
    IncludeRules = @('*')

    # Exclude specific rules
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',  # We use Write-Host for UI output
        'PSUseShouldProcessForStateChangingFunctions',  # Not all functions need ShouldProcess
        'PSReviewUnusedParameter'  # ArgumentCompleter scriptblocks require unused parameters
    )

    # Rule-specific settings
    Rules = @{
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false
            BlockComment = $true
            Placement = "begin"
        }

        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('7.0')
        }
    }


}
