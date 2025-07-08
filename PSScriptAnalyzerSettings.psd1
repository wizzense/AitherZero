# PSScriptAnalyzer Configuration for AitherZero
# Enterprise-grade PowerShell automation framework
# Security-focused rules with cross-platform compatibility

@{
    # Include all default rules by default
    IncludeDefaultRules = $true
    
    # Severity levels to analyze
    Severity = @('Error', 'Warning', 'Information')
    
    # Explicitly include high-priority rules
    IncludeRules = @(
        # Security Rules (Critical)
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUsePSCredentialType',
        'PSAvoidHardcodedCredentials',
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingInvokeExpression',
        
        # Cross-Platform Compatibility Rules (essential only)
        'PSUseCompatibleCmdlets',
        
        # Code Quality Rules
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPositionalParameters',
        'PSUseCmdletCorrectly',
        'PSUseOutputTypeCorrectly',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSProvideCommentHelp',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseBOMForUnicodeEncodedFile',
        'PSMissingModuleManifestField',
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSAlignAssignmentStatement',
        'PSUseCorrectCasing',
        
        # Performance Rules
        'PSAvoidAssignmentToAutomaticVariable',
        'PSAvoidGlobalVars',
        'PSAvoidUsingFilePath',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidDefaultValueForMandatoryParameter',
        'PSAvoidNullOrEmptyHelpMessageAttribute',
        'PSAvoidLongLines',
        'PSAvoidMultipleTypeAttributes',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingDoubleQuotesForConstantString',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidExclaimOperator',
        'PSAvoidLongLines',
        'PSAvoidMultipleTypeAttributes',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingDoubleQuotesForConstantString',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidExclaimOperator',
        
        # Best Practices
        'PSUseSingularNouns',
        'PSUseApprovedVerbs',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingGet-WmiObject',
        'PSUseSupportsShouldProcess',
        'PSAvoidGlobalAliases',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSUsePSCredentialType',
        'PSAvoidHardcodedCredentials'
    )
    
    # Rules to exclude with business justification (CI-optimized)
    ExcludeRules = @(
        # Framework-specific exclusions (essential only for CI performance)
        'PSAvoidUsingWriteHost',              # Allowed in interactive modules and startup experience
        'PSUseShouldProcessForStateChangingFunctions',  # Not applicable for all utility functions
        'PSAvoidUsingInvokeExpression',       # Required for dynamic configuration and template processing
        'PSAvoidGlobalVars',                  # Framework requires some global state management
        'PSUseApprovedVerbs',                 # Framework uses custom verbs like 'Download-Archive'
        'PSUseSingularNouns',                 # Some nouns are inherently plural (e.g., 'Credentials')
        'PSProvideCommentHelp',               # Some internal functions don't need comment help
        'PSAvoidUsingFilePath',               # Framework requires file path operations
        'PSAvoidLongLines',                   # Some lines exceed limits due to URL strings or complex expressions
        'PSUseConsistentWhitespace',          # Handled by formatting tools
        'PSUseConsistentIndentation',         # Handled by formatting tools
        'PSAlignAssignmentStatement',         # Handled by formatting tools
        'PSUseCorrectCasing',                 # Framework uses consistent casing conventions
        'PSAvoidTrailingWhitespace',          # Handled by formatting tools
        'PSAvoidUsingCmdletAliases',          # Some legacy compatibility required
        'PSAvoidUsingPositionalParameters',   # Some utility functions benefit from positional params
        'PSAvoidUsingDoubleQuotesForConstantString' # Framework uses double quotes for consistency
    )
    
    # Custom rules for AitherZero framework
    CustomRulePath = @(
        # Path to custom rules (to be implemented)
        # './PSScriptAnalyzerCustomRules'
    )
    
    # Rules configuration for specific scenarios
    Rules = @{
        # Security rules - treat as errors
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
            Severity = 'Error'
        }
        PSAvoidUsingUsernameAndPasswordParams = @{
            Enable = $true
            Severity = 'Error'
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
            Severity = 'Error'
        }
        PSUsePSCredentialType = @{
            Enable = $true
            Severity = 'Error'
        }
        PSAvoidHardcodedCredentials = @{
            Enable = $true
            Severity = 'Error'
        }
        
        # Cross-platform compatibility (basic only)
        PSUseCompatibleCmdlets = @{
            Enable = $true
            Severity = 'Warning'
            PowerShellVersion = @('7.0', '7.1', '7.2', '7.3', '7.4', '7.5')
        }
        
        # Code formatting and style
        PSUseConsistentWhitespace = @{
            Enable = $true
            Severity = 'Information'
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckSeparator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $true
            CheckParameter = $true
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Severity = 'Information'
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
            Kind = 'space'
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
            Severity = 'Information'
            CheckHashtable = $true
        }
        PSUseCorrectCasing = @{
            Enable = $true
            Severity = 'Information'
        }
        
        # Performance and best practices
        PSAvoidLongLines = @{
            Enable = $true
            Severity = 'Information'
            MaximumLineLength = 120
        }
        PSAvoidTrailingWhitespace = @{
            Enable = $true
            Severity = 'Information'
        }
        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
            Severity = 'Information'
        }
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
            Severity = 'Information'
        }
        
        # Framework-specific rules
        PSUseApprovedVerbs = @{
            Enable = $true
            Severity = 'Warning'
            # Allow framework-specific verbs
            # Note: This will be overridden by module-specific configs
        }
        PSUseSingularNouns = @{
            Enable = $true
            Severity = 'Warning'
            # Allow framework-specific plural nouns
        }
        PSProvideCommentHelp = @{
            Enable = $true
            Severity = 'Information'
            # Only for public functions
        }
    }
    
    # CI-optimized configuration (no extra metadata for performance)
}