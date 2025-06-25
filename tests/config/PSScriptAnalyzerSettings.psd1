@{
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',  # We use Write-Host for colored console output
        'PSUseShouldProcessForStateChangingFunctions',  # Not all functions need this
        'PSAvoidUsingConvertToSecureStringWithPlainText'  # Legitimate use in credential modules
    )
    IncludeDefaultRules = $true
    Severity = @('Error', 'Warning', 'Information')
    Rules = @{
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize = 4
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
        }
    }
}
