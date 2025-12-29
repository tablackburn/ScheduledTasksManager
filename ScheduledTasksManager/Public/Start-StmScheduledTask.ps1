function Start-StmScheduledTask {
    <#
    .SYNOPSIS
        Starts a scheduled task on a local or remote computer.

    .DESCRIPTION
        The Start-StmScheduledTask function starts a scheduled task on a local or remote computer using the
        Windows Task Scheduler. This function wraps the built-in Start-ScheduledTask cmdlet to provide credential
        support and enhanced error handling across the ScheduledTasksManager module.

        The function performs the following operations:
        1. Connects to the specified computer using credentials if provided
        2. Starts the specified scheduled task
        3. Provides detailed verbose output for troubleshooting

        This function requires appropriate permissions to manage scheduled tasks on the target computer.

    .PARAMETER TaskName
        Specifies the name of the scheduled task to start. This parameter is mandatory and must match the exact
        name of the task as it appears in the Task Scheduler.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task to start. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
        root path ('\') will be used.

    .PARAMETER ComputerName
        Specifies the name of the computer on which to start the scheduled task. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .EXAMPLE
        Start-StmScheduledTask -TaskName "MyBackupTask"

        Starts the scheduled task named "MyBackupTask" on the local computer.

    .EXAMPLE
        Start-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\"

        Starts the scheduled task named "MaintenanceTask" located in the "\Custom\Maintenance\" path on the
        local computer.

    .EXAMPLE
        Start-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01"

        Starts the scheduled task named "DatabaseBackup" on the remote computer "Server01" using the current
        user's credentials.

    .EXAMPLE
        $credentials = Get-Credential
        Start-StmScheduledTask -TaskName "ReportGeneration" -ComputerName "Server02" -Credential $credentials

        Starts the scheduled task named "ReportGeneration" on the remote computer "Server02" using the specified
        credentials.

    .EXAMPLE
        Start-StmScheduledTask -TaskName "CriticalTask" -WhatIf

        Shows what would happen if the cmdlet runs without actually performing the operation. This is useful for
        testing the command before execution.

    .INPUTS
        None. You cannot pipe objects to Start-StmScheduledTask.

    .OUTPUTS
        None. This cmdlet does not generate any output.

    .NOTES
        This function requires:
        - Appropriate permissions to manage scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer
        - The task must be in a Ready state (enabled) to be started

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.

        Starting a task that is already running will have no effect and will not cause an error.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
        Write-Verbose 'Starting Start-StmScheduledTask'
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
        if ($PSCmdlet.ShouldProcess("$TaskName at $TaskPath on $ComputerName", 'Start scheduled task')) {
            try {
                Write-Verbose "Starting scheduled task '$TaskName' at path '$TaskPath' on computer '$ComputerName'..."
                $startScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    TaskPath    = $TaskPath
                    CimSession  = $cimSession
                    ErrorAction = 'Stop'
                }
                Start-ScheduledTask @startScheduledTaskParameters

                $successMsg = (
                    "Scheduled task '" + $TaskName +
                    "' has been successfully started on computer '" + $ComputerName + "'."
                )
                Write-Verbose $successMsg
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'ScheduledTaskStartFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                    TargetObject      = $TaskName
                    Message           = (
                        "Failed to start scheduled task '$TaskName' at path '$TaskPath' on computer " +
                        "'$ComputerName'. {$_}"
                    )
                    RecommendedAction = (
                        'Verify the task name and path are correct, that the task exists, that the task is ' +
                        'enabled (Ready state), and that you have permission to manage scheduled tasks.'
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
        Write-Verbose "Completed Start-StmScheduledTask for task '$TaskName'"
    }
}
