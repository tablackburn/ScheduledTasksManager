function Wait-StmScheduledTask {
    <#
    .SYNOPSIS
        Waits for a scheduled task to complete running on a local or remote computer.

    .DESCRIPTION
        The Wait-StmScheduledTask function polls a scheduled task on a local or remote computer and waits until
        the task is no longer in the 'Running' state or until a timeout is reached.

        The function performs the following operations:
        1. Connects to the specified computer using credentials if provided
        2. Polls the task state at regular intervals
        3. Returns $true if the task completes, $false if timeout is reached
        4. Provides detailed verbose output for troubleshooting

        This function is useful for synchronizing scripts that need to wait for a scheduled task to complete
        before continuing.

    .PARAMETER TaskName
        Specifies the name of the scheduled task to wait for. This parameter is mandatory and must match the exact
        name of the task as it appears in the Task Scheduler.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task to wait for. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
        root path ('\') will be used.

    .PARAMETER ComputerName
        Specifies the name of the computer on which the scheduled task is running. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .PARAMETER PollingIntervalSeconds
        Specifies the number of seconds to wait between polling attempts. Default is 5 seconds. The minimum value
        is 1 second.

    .PARAMETER TimeoutSeconds
        Specifies the maximum number of seconds to wait for the task to complete. Default is 300 seconds (5 minutes).
        If the task does not complete within this time, the function returns $false.

    .EXAMPLE
        Wait-StmScheduledTask -TaskName "MyBackupTask"

        Waits for the scheduled task named "MyBackupTask" to complete on the local computer with default timeout.

    .EXAMPLE
        Wait-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\" -TimeoutSeconds 600

        Waits up to 10 minutes for the task named "MaintenanceTask" located in the "\Custom\Maintenance\" path.

    .EXAMPLE
        Wait-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01" -PollingIntervalSeconds 10

        Waits for the task on a remote computer, checking every 10 seconds.

    .EXAMPLE
        Start-StmScheduledTask -TaskName "LongRunningTask"
        $completed = Wait-StmScheduledTask -TaskName "LongRunningTask" -TimeoutSeconds 1800
        if (-not $completed) {
            Write-Warning "Task did not complete within 30 minutes"
        }

        Starts a task and waits up to 30 minutes for it to complete.

    .INPUTS
        None. You cannot pipe objects to Wait-StmScheduledTask.

    .OUTPUTS
        System.Boolean
        Returns $true if the task completed (is no longer running), or $false if the timeout was reached.

    .NOTES
        This function requires:
        - Appropriate permissions to query scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.

        If the task is not running when this function is called, it will immediately return $true.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
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
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PollingIntervalSeconds = 5,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $TimeoutSeconds = 300
    )

    begin {
        Write-Verbose 'Starting Wait-StmScheduledTask'
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
        try {
            Write-Verbose "Waiting for scheduled task '$TaskName' at path '$TaskPath' on computer '$ComputerName'..."
            Write-Verbose "Polling interval: $PollingIntervalSeconds seconds, Timeout: $TimeoutSeconds seconds"

            $getScheduledTaskParameters = @{
                TaskName    = $TaskName
                TaskPath    = $TaskPath
                CimSession  = $cimSession
                ErrorAction = 'Stop'
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
                $task = Get-ScheduledTask @getScheduledTaskParameters

                if ($task.State -ne 'Running') {
                    $stopwatch.Stop()
                    $elapsedMsg = "Task '$TaskName' is no longer running. State: $($task.State). " +
                        "Elapsed time: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) seconds."
                    Write-Verbose $elapsedMsg
                    return $true
                }

                $remainingSeconds = [math]::Round($TimeoutSeconds - $stopwatch.Elapsed.TotalSeconds, 0)
                Write-Verbose "Task '$TaskName' is still running. Waiting $PollingIntervalSeconds seconds... ($remainingSeconds seconds remaining)"
                Start-Sleep -Seconds $PollingIntervalSeconds
            }

            $stopwatch.Stop()
            Write-Verbose "Timeout reached after $TimeoutSeconds seconds. Task '$TaskName' is still running."
            return $false
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ScheduledTaskWaitFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $TaskName
                Message           = (
                    "Failed to wait for scheduled task '$TaskName' at path '$TaskPath' on computer " +
                    "'$ComputerName'. {$_}"
                )
                RecommendedAction = (
                    'Verify the task name and path are correct, that the task exists, and that you have ' +
                    'permission to query scheduled tasks.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed Wait-StmScheduledTask for task '$TaskName'"
    }
}
