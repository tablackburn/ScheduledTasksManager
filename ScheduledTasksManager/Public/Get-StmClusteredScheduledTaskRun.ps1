function Get-StmClusteredScheduledTaskRun {
    <#
    .SYNOPSIS
        Retrieves run history for scheduled tasks across all nodes in a Windows failover cluster.

    .DESCRIPTION
        The Get-StmClusteredScheduledTaskRun function retrieves execution history for scheduled tasks
        from all nodes in a Windows failover cluster. It queries each cluster node to gather task run
        information including start times, end times, durations, and result codes. This is useful for
        auditing task execution across clustered environments where tasks may run on different nodes.

    .PARAMETER TaskName
        Specifies the name of the scheduled task to retrieve run history for. This parameter is mandatory.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster to query. This parameter is mandatory.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task in Task Scheduler. If not specified, all task paths
        are searched.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster nodes. If not provided, the current
        user's credentials will be used.

    .EXAMPLE
        Get-StmClusteredScheduledTaskRun -TaskName "BackupTask" -Cluster "MyCluster"

        Retrieves the run history for the scheduled task named "BackupTask" from all nodes in the
        cluster "MyCluster".

    .EXAMPLE
        $params = @{
            TaskName = "MaintenanceTask"
            Cluster  = "MyCluster.contoso.com"
            TaskPath = "\CustomTasks\"
        }
        Get-StmClusteredScheduledTaskRun @params

        Retrieves the run history for the "MaintenanceTask" located in the "\CustomTasks\" path from
        all nodes in the cluster "MyCluster.contoso.com".

    .EXAMPLE
        $credentials = Get-Credential
        Get-StmClusteredScheduledTaskRun -TaskName "ReportTask" -Cluster "MyCluster" -Credential $credentials |
            Select-Object TaskName, StartTime, EndTime, Duration, ResultCode

        Retrieves run history for "ReportTask" using specified credentials and displays key run details.

    .EXAMPLE
        Get-StmClusteredScheduledTaskRun -TaskName "CleanupTask" -Cluster "MyCluster" |
            Where-Object { $_.ResultCode -ne 0 } |
            Select-Object TaskName, StartTime, ResultCode

        Retrieves run history for "CleanupTask" and filters to show only failed runs (non-zero result codes).

    .INPUTS
        None. You cannot pipe objects to Get-StmClusteredScheduledTaskRun.

    .OUTPUTS
        PSCustomObject
        Returns objects containing details about each scheduled task run:
        - TaskName: The name of the scheduled task
        - ActivityId: The unique identifier for the task run
        - ResultCode: The exit code from the task execution
        - StartTime: When the task started
        - EndTime: When the task completed
        - Duration: The TimeSpan duration of the run
        - DurationSeconds: The duration in seconds
        - LaunchRequestIgnored: Whether the launch was skipped due to an existing instance
        - Events: The raw event log entries for the run
        - EventCount: The number of events in the run
        - EventXml: The XML representation of the events

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module on the cluster
        - Network connectivity to all cluster nodes
        - Appropriate permissions to query the Task Scheduler event log on each node

        The function uses Get-StmClusterNode to enumerate cluster nodes and Get-StmScheduledTaskRun
        to retrieve run history from each node.
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
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting Get-StmClusteredScheduledTaskRun on cluster '$Cluster'"

        $stmClusterNodeParameters = @{
            Cluster = $Cluster
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $stmClusterNodeParameters['Credential'] = $Credential
        }

        $scheduledTaskRunParameters = @{
            TaskName = $TaskName
        }
        if ($PSBoundParameters.ContainsKey('TaskPath')) {
            $scheduledTaskRunParameters['TaskPath'] = $TaskPath
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $scheduledTaskRunParameters['Credential'] = $Credential
        }
    }

    process {
        Write-Verbose "Getting cluster nodes for cluster '$Cluster'"
        $clusterNodes = Get-StmClusterNode @stmClusterNodeParameters
        if ($null -eq $clusterNodes -or $clusterNodes.Count -eq 0) {
            Write-Error "No cluster nodes found for cluster '$Cluster'"
            return
        }
        Write-Verbose "Cluster nodes found: $($clusterNodes.Count)"
        Write-Verbose "Cluster nodes: $($clusterNodes | Out-String)"

        foreach ($node in $clusterNodes) {
            Write-Verbose "Getting scheduled task runs for node '$($node.Name)' on cluster '$Cluster'"
            Get-StmScheduledTaskRun -ComputerName $node.Name @scheduledTaskRunParameters
        }

    }

    end {
        Write-Verbose "Finished Get-StmClusteredScheduledTaskRun on cluster '$Cluster'"
    }
}
