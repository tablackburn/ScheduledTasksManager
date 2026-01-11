function Wait-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Waits for a clustered scheduled task to complete execution on a Windows failover cluster.

    .DESCRIPTION
        The Wait-StmClusteredScheduledTask function monitors a clustered scheduled task and waits for it to
        complete its execution. This function polls the task state at regular intervals and provides progress
        feedback through Write-Progress. The function will exit when the task is no longer in the 'Running' state
        or when the specified timeout is reached. This is useful for automation scenarios where you need to wait
        for a task to complete before proceeding with subsequent operations.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to wait for. This parameter is mandatory.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter is
        mandatory.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current user's
        credentials will be used for the connection.

    .PARAMETER PollingIntervalSeconds
        Specifies the interval in seconds between state checks of the clustered scheduled task. The default
        value is 5 seconds. This parameter is optional.

    .PARAMETER TimeoutSeconds
        Specifies the maximum time in seconds to wait for the task to complete. If the timeout is reached, the
        function will throw an error. The default value is 300 seconds (5 minutes). This parameter is optional.

    .EXAMPLE
        Wait-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster"

        Waits for the clustered scheduled task named "BackupTask" on cluster "MyCluster" to complete,
        using default polling interval (5 seconds) and timeout (300 seconds).

    .EXAMPLE
        Wait-StmClusteredScheduledTask `
            -TaskName "MaintenanceTask" `
            -Cluster "MyCluster.contoso.com" `
            -TimeoutSeconds 600

        Waits for the clustered scheduled task named "MaintenanceTask" on cluster "MyCluster.contoso.com" to
        complete, with a timeout of 10 minutes (600 seconds).

    .EXAMPLE
        $credential = Get-Credential
        Wait-StmClusteredScheduledTask `
            -TaskName "ReportTask" `
            -Cluster "MyCluster" `
            -Credential $credential `
            -PollingIntervalSeconds 10

        Waits for the clustered scheduled task named "ReportTask" on cluster "MyCluster" using specified
        credentials, checking the task state every 10 seconds.

    .EXAMPLE
        Wait-StmClusteredScheduledTask `
            -TaskName "LongRunningTask" `
            -Cluster "MyCluster" `
            -TimeoutSeconds 1800 `
            -Verbose

        Waits for the clustered scheduled task named "LongRunningTask" on cluster "MyCluster" with a 30-minute
        timeout and verbose output to show detailed information about the waiting process.

    .INPUTS
        None. You cannot pipe objects to Wait-StmClusteredScheduledTask.

    .OUTPUTS
        None. This function does not return any output objects.

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to access clustered scheduled tasks
        - Network connectivity to the cluster
        - The task must exist on the specified cluster

        The function provides:
        - Progress bar showing elapsed time and current task state
        - Verbose output for troubleshooting
        - Configurable polling interval and timeout
        - Error handling for timeout scenarios

        The function will exit when:
        - The task state is no longer 'Running' (task completed, failed, or stopped)
        - The specified timeout is reached (throws an error)

        Use this function in automation scenarios where you need to ensure a task has completed
        before proceeding with subsequent operations.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cluster,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [int]
        $PollingIntervalSeconds = 5,

        [Parameter(Mandatory = $false)]
        [int]
        $TimeoutSeconds = 300
    )

    begin {
        Write-Verbose "Starting Wait-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
        $startTime = Get-Date
    }

    process {
        $activity = "Waiting for clustered scheduled task '$TaskName' to complete"
        $status = ''
        $percentComplete = 0
        $consecutiveErrors = 0
        $maxConsecutiveErrors = 3
        while ($true) {
            $clusteredScheduledTaskParameters = @{
                TaskName   = $TaskName
                Cluster    = $Cluster
                Credential = $Credential
            }
            try {
                $scheduledTask = Get-StmClusteredScheduledTask @clusteredScheduledTaskParameters
                $consecutiveErrors = 0  # Reset error counter on success
            }
            catch {
                $consecutiveErrors++
                $warnMsg = (
                    "Failed to retrieve task status (attempt $consecutiveErrors of $maxConsecutiveErrors): " +
                    $_.Exception.Message
                )
                Write-Warning $warnMsg
                if ($consecutiveErrors -ge $maxConsecutiveErrors) {
                    Write-Progress -Activity $activity -Completed
                    $errorMessage = (
                        "Failed to retrieve task '$TaskName' status after $maxConsecutiveErrors consecutive attempts. " +
                        "Last error: $($_.Exception.Message)"
                    )
                    $errorRecordParameters = @{
                        Exception     = [System.InvalidOperationException]::new($errorMessage, $_.Exception)
                        ErrorId       = 'ClusterUnreachable'
                        ErrorCategory = [System.Management.Automation.ErrorCategory]::ConnectionError
                        TargetObject  = $Cluster
                        Message       = $errorMessage
                    }
                    $errorRecord = New-StmError @errorRecordParameters
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                Start-Sleep -Seconds $PollingIntervalSeconds
                # Check timeout after retry sleep
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalSeconds -ge $TimeoutSeconds) {
                    Write-Progress -Activity $activity -Completed
                    $timeoutMessage = "Timeout reached while waiting for task '$TaskName' to complete."
                    $errorRecordParameters = @{
                        Exception     = [System.TimeoutException]::new($timeoutMessage)
                        ErrorId       = 'TimeoutReached'
                        ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationTimeout
                        TargetObject  = $TaskName
                        Message       = $timeoutMessage
                    }
                    $errorRecord = New-StmError @errorRecordParameters
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                continue
            }
            $state = $scheduledTask.ScheduledTaskObject.State
            $elapsed = (Get-Date) - $startTime
            $percentComplete = [math]::Min([math]::Round(($elapsed.TotalSeconds / $TimeoutSeconds) * 100), 100)
            $status = 'Elapsed: {0:N0}s / {1}s | State: {2}' -f $elapsed.TotalSeconds, $TimeoutSeconds, $state
            Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete
            Write-Verbose "Current state of task '$TaskName': $state"

            if ($state -ne 'Running') {
                Write-Progress -Activity $activity -Completed
                Write-Verbose "Task '$TaskName' is no longer running. Exiting wait."
                break
            }

            if ($elapsed.TotalSeconds -ge $TimeoutSeconds) {
                Write-Progress -Activity $activity -Completed
                $timeoutMessage = "Timeout reached while waiting for task '$TaskName' to complete."
                $errorRecordParameters = @{
                    Exception     = [System.TimeoutException]::new($timeoutMessage)
                    ErrorId       = 'TimeoutReached'
                    ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationTimeout
                    TargetObject  = $TaskName
                    Message       = $timeoutMessage
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
                break
            }

            Start-Sleep -Seconds $PollingIntervalSeconds
        }
    }

    end {
        Write-Verbose "Completed Wait-StmClusteredScheduledTask for task '$TaskName'"
    }
}
