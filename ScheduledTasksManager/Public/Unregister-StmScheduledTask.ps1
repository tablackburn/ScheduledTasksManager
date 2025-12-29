function Unregister-StmScheduledTask {
    <#
    .SYNOPSIS
        Unregisters (deletes) a scheduled task on a local or remote computer.

    .DESCRIPTION
        The Unregister-StmScheduledTask function unregisters (deletes) a scheduled task on a local or remote computer
        using the Windows Task Scheduler. This function wraps the built-in Unregister-ScheduledTask cmdlet to provide
        credential support and enhanced error handling across the ScheduledTasksManager module.

        The function performs the following operations:
        1. Connects to the specified computer using credentials if provided
        2. Unregisters the specified scheduled task
        3. Provides detailed verbose output for troubleshooting

        WARNING: This operation permanently deletes the scheduled task. This action cannot be undone.

        This function requires appropriate permissions to manage scheduled tasks on the target computer.

    .PARAMETER TaskName
        Specifies the name of the scheduled task to unregister. This parameter is mandatory and must match the exact
        name of the task as it appears in the Task Scheduler.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task to unregister. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
        root path ('\') will be used.

    .PARAMETER ComputerName
        Specifies the name of the computer on which to unregister the scheduled task. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .EXAMPLE
        Unregister-StmScheduledTask -TaskName "MyBackupTask"

        Unregisters the scheduled task named "MyBackupTask" on the local computer.

    .EXAMPLE
        Unregister-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\"

        Unregisters the scheduled task named "MaintenanceTask" located in the "\Custom\Maintenance\" path on the
        local computer.

    .EXAMPLE
        Unregister-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01"

        Unregisters the scheduled task named "DatabaseBackup" on the remote computer "Server01" using the current
        user's credentials.

    .EXAMPLE
        $credentials = Get-Credential
        Unregister-StmScheduledTask -TaskName "ReportGeneration" -ComputerName "Server02" -Credential $credentials

        Unregisters the scheduled task named "ReportGeneration" on the remote computer "Server02" using the specified
        credentials.

    .EXAMPLE
        Unregister-StmScheduledTask -TaskName "CriticalTask" -WhatIf

        Shows what would happen if the cmdlet runs without actually performing the operation. This is useful for
        testing the command before execution.

    .EXAMPLE
        Unregister-StmScheduledTask -TaskName "OldTask" -Confirm:$false

        Unregisters the scheduled task named "OldTask" without prompting for confirmation.

    .INPUTS
        None. You cannot pipe objects to Unregister-StmScheduledTask.

    .OUTPUTS
        None. This cmdlet does not generate any output.

    .NOTES
        This function requires:
        - Appropriate permissions to manage scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.

        WARNING: This operation permanently deletes the scheduled task. Consider exporting the task configuration
        using Export-StmScheduledTask before unregistering if you may need to restore the task later.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.
        Due to the destructive nature of this operation, ConfirmImpact is set to 'High' which will prompt for
        confirmation by default unless -Confirm:$false is specified.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath = '\',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName = 'localhost',

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose 'Starting Unregister-StmScheduledTask'
        $cimSessionParameters = @{
            ComputerName = $ComputerName
            ErrorAction  = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            Write-Verbose 'Using provided credential'
            $cimSessionParameters['Credential'] = $Credential
        }
        else {
            Write-Verbose 'Using current user credentials'
        }
        $cimSession = New-StmCimSession @cimSessionParameters
    }

    process {
        if ($PSCmdlet.ShouldProcess("$TaskName at $TaskPath on $ComputerName", 'Unregister (delete) scheduled task')) {
            try {
                Write-Verbose "Unregistering scheduled task '$TaskName' at path '$TaskPath' on computer '$ComputerName'..."
                $unregisterScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    TaskPath    = $TaskPath
                    CimSession  = $cimSession
                    Confirm     = $false
                    ErrorAction = 'Stop'
                }
                Unregister-ScheduledTask @unregisterScheduledTaskParameters

                $successMsg = (
                    "Scheduled task '" + $TaskName +
                    "' has been successfully unregistered from computer '" + $ComputerName + "'."
                )
                Write-Verbose $successMsg
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'ScheduledTaskUnregisterFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                    TargetObject      = $TaskName
                    Message           = (
                        "Failed to unregister scheduled task '$TaskName' at path '$TaskPath' on computer " +
                        "'$ComputerName'. {$_}"
                    )
                    RecommendedAction = (
                        'Verify the task name and path are correct, that the task exists, and that you have ' +
                        'permission to manage scheduled tasks.'
                    )
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
        else {
            Write-Verbose 'Operation cancelled by user.'
        }
    }

    end {
        Write-Verbose "Completed Unregister-StmScheduledTask for task '$TaskName'"
    }
}
