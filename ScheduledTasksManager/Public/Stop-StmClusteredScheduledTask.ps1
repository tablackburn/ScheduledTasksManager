function Stop-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Stops a running clustered scheduled task on a Windows failover cluster.

    .DESCRIPTION
        The Stop-StmClusteredScheduledTask function stops a running clustered scheduled task on a Windows
        failover cluster. This function retrieves the specified clustered scheduled task using
        Get-StmClusteredScheduledTask and then stops it using the native Stop-ScheduledTask cmdlet. The function
        supports the -WhatIf and -Confirm parameters for safe execution and provides verbose output for
        troubleshooting.

        The function performs the following operations:
        1. Retrieves the clustered scheduled task using Get-StmClusteredScheduledTask
        2. Stops the scheduled task using the native Stop-ScheduledTask cmdlet
        3. Provides detailed verbose output for troubleshooting

        This function requires appropriate permissions to stop clustered scheduled tasks and
        network connectivity to the target cluster.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to stop. This parameter is mandatory
        and must match the exact name of the task as it appears in the cluster.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter
        is mandatory and must be a valid Windows failover cluster.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current
        user's credentials will be used for the connection. This parameter is optional.

    .EXAMPLE
        Stop-StmClusteredScheduledTask -TaskName "MyBackupTask" -Cluster "MyCluster"

        Stops the clustered scheduled task named "MyBackupTask" on cluster "MyCluster" using
        the current user's credentials.

    .EXAMPLE
        $creds = Get-Credential
        Stop-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "ProdCluster" -Credential $creds

        Stops the clustered scheduled task named "MaintenanceTask" on cluster "ProdCluster" using
        the specified credentials.

    .EXAMPLE
        Stop-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "TestCluster" -Verbose

        Stops the clustered scheduled task with verbose output showing detailed information about
        the retrieval and stopping process.

    .EXAMPLE
        Stop-StmClusteredScheduledTask -TaskName "RunningTask" -Cluster "MyCluster" -WhatIf

        Shows what would happen if the cmdlet runs without actually performing the operation.
        This is useful for testing the command before execution.

    .INPUTS
        None. You cannot pipe objects to Stop-StmClusteredScheduledTask.

    .OUTPUTS
        None. This function does not return any objects.

    .NOTES
        This function requires:
        - PowerShell remoting to be enabled on the target cluster
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to stop clustered scheduled tasks
        - Network connectivity to the cluster on the WinRM ports (default 5985/5986)

        The function uses Get-StmClusteredScheduledTask internally to retrieve the task before stopping it.
        If the task is not found or is not running, an error will be thrown.

        Only tasks that are currently running can be stopped. Tasks that are in other states
        (such as Ready, Disabled, or Queued) cannot be stopped.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated
        environments.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
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
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting Stop-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
    }

    process {
        try {
            Write-Verbose "Retrieving clustered scheduled task '$TaskName'..."
            $getStmClusteredScheduledTaskParameters = @{
                TaskName    = $TaskName
                Cluster     = $Cluster
                Credential  = $Credential
                ErrorAction = 'Stop'
            }
            $scheduledTask = Get-StmClusteredScheduledTask @getStmClusteredScheduledTaskParameters

            if (-not $scheduledTask) {
                $errorRecordParameters = @{
                    Exception         = [System.Management.Automation.ItemNotFoundException]::new('Task not found')
                    ErrorId           = 'TaskNotFound'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    TargetObject      = $TaskName
                    Message           = "Clustered scheduled task '$TaskName' not found on cluster '$Cluster'."
                    RecommendedAction = 'Verify the task name and cluster name are correct.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }

            Write-Verbose "Retrieved clustered scheduled task '$TaskName'. Current state: $($scheduledTask.TaskState)"

            if ($PSCmdlet.ShouldProcess("$TaskName on $Cluster", 'Stop clustered scheduled task')) {
                Write-Verbose "Stopping clustered scheduled task '$TaskName'..."
                try {
                    $scheduledTask.ScheduledTaskObject | Stop-ScheduledTask -ErrorAction 'Stop'
                    Write-Verbose "Clustered scheduled task '$TaskName' has been stopped successfully."
                }
                catch {
                    $errorRecordParameters = @{
                        Exception         = $_.Exception
                        ErrorId           = 'StopTaskFailed'
                        ErrorCategory     = [System.Management.Automation.ErrorCategory]::WriteError
                        TargetObject      = $TaskName
                        Message           = (
                            "Failed to stop clustered scheduled task '$TaskName'. $($_.Exception.Message)"
                        )
                        RecommendedAction = (
                            'Ensure the task is running and you have the necessary ' +
                            'permissions to stop it.'
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
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'RetrieveTaskFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::WriteError
                TargetObject      = $TaskName
                Message           = "Failed to retrieve clustered scheduled task '$TaskName'. $($_.Exception.Message)"
                RecommendedAction = 'Ensure the task exists on the cluster and you have the necessary permissions.'
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed Stop-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
    }
}
