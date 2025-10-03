@{
    # Include all rules by default
    IncludeRules = @(
        '*'
    )

    # Configure specific rule settings
    Rules        = @{
        # Enforce consistent formatting
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
            NoEmptyLineBefore  = $false
        }

        # Enable formatting rules (they default to disabled)
        PSUseConsistentWhitespace  = @{
            Enable                                  = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
        }

        # Enable additional formatting rules (disabled by default)
        PSUseCorrectCasing         = @{
            Enable = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSAvoidLongLines           = @{
            Enable            = $true
            MaximumLineLength = 120
        }
    }
}
