function Disable-StmScheduledTask {
    <#
    .SYNOPSIS
        Disables a scheduled task on a local or remote computer.

    .DESCRIPTION
        The Disable-StmScheduledTask function disables a scheduled task on a local or remote computer using the
        Windows Task Scheduler. This function wraps the built-in Disable-ScheduledTask cmdlet to provide credential
        support and enhanced error handling across the ScheduledTasksManager module.

        The function performs the following operations:
        1. Connects to the specified computer using credentials if provided
        2. Disables the specified scheduled task
        3. Verifies that the task has been successfully disabled
        4. Provides detailed verbose output for troubleshooting

        This function requires appropriate permissions to manage scheduled tasks on the target computer.

    .PARAMETER TaskName
        Specifies the name of the scheduled task to disable. This parameter is mandatory and must match the exact
        name of the task as it appears in the Task Scheduler.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task to disable. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
        root path ('\') will be used.

    .PARAMETER ComputerName
        Specifies the name of the computer on which to disable the scheduled task. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .PARAMETER PassThru
        Returns an object representing the disabled scheduled task. By default, this cmdlet does not generate any
        output.

    .EXAMPLE
        Disable-StmScheduledTask -TaskName "MyBackupTask"

        Disables the scheduled task named "MyBackupTask" on the local computer.

    .EXAMPLE
        Disable-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\"

        Disables the scheduled task named "MaintenanceTask" located in the "\Custom\Maintenance\" path on the
        local computer.

    .EXAMPLE
        Disable-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01"

        Disables the scheduled task named "DatabaseBackup" on the remote computer "Server01" using the current
        user's credentials.

    .EXAMPLE
        $credentials = Get-Credential
        Disable-StmScheduledTask -TaskName "ReportGeneration" -ComputerName "Server02" -Credential $credentials

        Disables the scheduled task named "ReportGeneration" on the remote computer "Server02" using the specified
        credentials.

    .EXAMPLE
        Disable-StmScheduledTask -TaskName "TestTask" -PassThru

        Disables the scheduled task named "TestTask" on the local computer and returns the task object.

    .EXAMPLE
        Disable-StmScheduledTask -TaskName "CriticalTask" -WhatIf

        Shows what would happen if the cmdlet runs without actually performing the operation. This is useful for
        testing the command before execution.

    .INPUTS
        None. You cannot pipe objects to Disable-StmScheduledTask.

    .OUTPUTS
        None or Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        When you use the PassThru parameter, this cmdlet returns a ScheduledTask object. Otherwise, this cmdlet
        does not generate any output.

    .NOTES
        This function requires:
        - Appropriate permissions to manage scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.

        This operation can be reversed by using the Enable-ScheduledTask cmdlet or the corresponding
        Enable-StmScheduledTask function if available.

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
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        Write-Verbose 'Starting Disable-StmScheduledTask'
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
        if ($PSCmdlet.ShouldProcess("$TaskName at $TaskPath on $ComputerName", 'Disable scheduled task')) {
            try {
                Write-Verbose "Disabling scheduled task '$TaskName' at path '$TaskPath' on computer '$ComputerName'..."
                $disableScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    TaskPath    = $TaskPath
                    CimSession  = $cimSession
                    ErrorAction = 'Stop'
                }
                Disable-ScheduledTask @disableScheduledTaskParameters

                Write-Verbose "Verifying that scheduled task '$TaskName' has been disabled..."
                $getScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    TaskPath    = $TaskPath
                    CimSession  = $cimSession
                    ErrorAction = 'Stop'
                }
                $task = Get-ScheduledTask @getScheduledTaskParameters

                if ($task.State -eq 'Disabled') {
                    $successMsg = (
                        "Scheduled task '" + $TaskName +
                        "' has been successfully disabled on computer '" + $ComputerName + "'."
                    )
                    Write-Verbose $successMsg
                    if ($PassThru) {
                        Write-Output $task
                    }
                }
                else {
                    Write-Error (
                        "Scheduled task '$($TaskName)' was not disabled successfully. " +
                        "Current state: $($task.State)"
                    ) -ErrorAction 'Stop'
                }
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'ScheduledTaskDisableFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                    TargetObject      = $TaskName
                    Message           = (
                        "Failed to disable scheduled task '$TaskName' at path '$TaskPath' on computer " +
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
        if ($cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
        Write-Verbose "Completed Disable-StmScheduledTask for task '$TaskName'"
    }
}
