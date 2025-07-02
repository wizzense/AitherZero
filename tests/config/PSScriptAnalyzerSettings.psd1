# PSScriptAnalyzer Configuration for AitherZero
# 
# Policy: Do not use global rule exclusions. Instead:
# 1. Fix the code to comply with best practices
# 2. Use targeted suppressions with [Diagnostics.CodeAnalysis.SuppressMessageAttribute] when truly necessary
# 3. Always provide clear justification for any suppression
#
# Security rules should NEVER be globally suppressed.

@{
    ExcludeRules = @(
        # No global exclusions - use targeted suppressions where necessary
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