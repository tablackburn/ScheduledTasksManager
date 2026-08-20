@{
    IncludeRules = @('*')

    # Scope analysis to actionable severities. Microsoft's documented settings
    # example does the same; without it Information-level findings are in scope
    # with nothing having decided that they should be.
    Severity     = @('Error', 'Warning')

    # Formatting rules, taken from the CodeFormatting preset PSScriptAnalyzer
    # ships (Settings/CodeFormatting.psd1). They are disabled by default, so they
    # only run when named here.
    #
    # This replaces a hand-rolled block: the same six rules, but with
    # IgnoreOneLineBlock disabled on both brace rules and with indentation and
    # whitespace left on their defaults. Measured against this codebase, the
    # shipped presets score CodeFormatting 42, Stroustrup 42 (identical rules),
    # the hand-rolled block 61, OTBS 188 and Allman 679 -- so this is the style
    # the code is already written in, and it now has a published name.
    Rules        = @{
        PSAlignAssignmentStatement = @{
            CheckHashtable = $true
            Enable         = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
            NoEmptyLineBefore  = $false
        }

        PSPlaceOpenBrace = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
            OnSameLine         = $true
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace = @{
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckParameter                          = $false
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $false
            CheckSeparator                          = $true
            Enable                                  = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSUseCorrectCasing = @{
            Enable = $true
        }
    }
}
