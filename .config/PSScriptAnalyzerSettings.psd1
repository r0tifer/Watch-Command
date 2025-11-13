@{
    Severity = @('Error', 'Warning', 'Information')
    IncludeRules = @(
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseApprovedVerbs',
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPositionalParameters',
        'PSReviewUnusedParameter',
        'PSUseCompatibleTypes',
        'PSUseCompatibleSyntax',
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSAlignAssignmentStatement',
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSAvoidTrailingWhitespace'
    )
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
        PSAvoidUsingWriteHost = @{
            Severity = 'Information'
        }
    }
}
