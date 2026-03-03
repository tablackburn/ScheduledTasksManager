function New-StmCimSession {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creating a CIM session is a read-only connection, not a state change')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting New-StmCimSession for computer '$ComputerName'"

        $cimSessionParameters = @{
            ComputerName = $ComputerName
            ErrorAction  = 'Stop'
        }
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            Write-Verbose "Using provided credentials for CIM session on '$ComputerName'"
            $cimSessionParameters['Credential'] = $Credential
        }
        else {
            Write-Verbose "Using current credentials for CIM session on '$ComputerName'"
        }
    }

    process {
        try {
            # Prevent WhatIf/Confirm preference propagation from calling functions.
            # When callers use -WhatIf, $WhatIfPreference propagates via PowerShell's
            # dynamic scope and can cause downstream cmdlets to skip operations.
            # Note: New-CimSession does not expose -WhatIf/-Confirm parameters, so
            # the -WhatIf:$false call-site pattern (used for Remove-CimSession elsewhere)
            # cannot be used here. Reset the preference variables instead.
            $WhatIfPreference = $false
            $ConfirmPreference = 'High'

            Write-Verbose "Creating CIM session to '$ComputerName'..."
            New-CimSession @cimSessionParameters
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'CimSessionCreationFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::ConnectionError
                TargetObject      = $ComputerName
                Message           = "Failed to create CIM session to '$ComputerName'. $($_.Exception.Message)"
                RecommendedAction = (
                    "Verify the computer name '$ComputerName' is correct, the target computer is accessible, " +
                    'and you have appropriate permissions. If using credentials, verify they are valid for ' +
                    'the target computer.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed New-StmCimSession for computer '$ComputerName'"
    }
}
