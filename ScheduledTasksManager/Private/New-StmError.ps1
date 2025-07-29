function New-StmError {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [System.Exception]
        $Exception,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ErrorId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory,

        [Parameter(Mandatory = $false)]
        [object]
        $TargetObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [Parameter(Mandatory = $false)]
        [string]
        $RecommendedAction
    )

    begin {
        Write-Verbose "Creating error record with ID '$ErrorId'"
    }

    process {
        if ($PSCmdlet.ShouldProcess($ErrorId, 'Create error record')) {
            $errorDetails = New-Object -TypeName 'System.Management.Automation.ErrorDetails' -ArgumentList $Message
            $errorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList @(
                $Exception,        # The original exception
                $ErrorId,          # The error ID
                $ErrorCategory,    # The error category
                $TargetObject      # The target object
            )

            $errorRecord.ErrorDetails = $errorDetails

            if ($PSBoundParameters.ContainsKey('RecommendedAction')) {
                $errorRecord.ErrorDetails.RecommendedAction = $RecommendedAction
            }

            $errorRecord
        }
    }

    end {
        Write-Verbose 'Error record created successfully'
    }
}
