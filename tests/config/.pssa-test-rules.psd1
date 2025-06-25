@{
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidGlobalVars',
        'PSAvoidUsingInvokeExpression',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUsePSCredentialType'
    )

    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
            Allowlist = @()
        }
        PSAvoidGlobalVars = @{
            Enable = $true
        }
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
    }
}