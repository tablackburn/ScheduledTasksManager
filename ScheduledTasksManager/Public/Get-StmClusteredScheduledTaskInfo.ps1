function Get-StmClusteredScheduledTaskInfo {
    <#
    .SYNOPSIS
        Retrieves detailed information about clustered scheduled tasks from a Windows failover cluster.

    .DESCRIPTION
        The Get-StmClusteredScheduledTaskInfo function retrieves comprehensive information about clustered scheduled tasks
        from a Windows failover cluster. This function combines information from both the clustered scheduled task object
        and the scheduled task info object to provide detailed execution history, last run times, next run times,
        and other operational details. You can filter tasks by name, state, or type to get information for specific tasks.

    .PARAMETER TaskName
        Specifies the name of a specific clustered scheduled task to retrieve information for. This parameter is mandatory.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster to query for clustered scheduled task information. This parameter is mandatory.

    .PARAMETER TaskState
        Specifies the state of the tasks to filter by. Valid values are: Unknown, Disabled, Queued, Ready, Running.
        If not specified, tasks in all states will be returned. This parameter is optional.

    .PARAMETER TaskType
        Specifies the type of clustered tasks to filter by. Valid values are: ResourceSpecific, AnyNode, ClusterWide.
        If not specified, tasks of all types will be returned. This parameter is optional.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current user's credentials
        will be used for the connection.

    .PARAMETER CimSession
        Specifies an existing CIM session to use for the connection to the cluster. If not provided, a new CIM session
        will be created using the Cluster and Credential parameters.

    .EXAMPLE
        Get-StmClusteredScheduledTaskInfo -TaskName "BackupTask" -Cluster "MyCluster"

        Retrieves detailed information about the clustered scheduled task named "BackupTask" from cluster "MyCluster".

    .EXAMPLE
        Get-StmClusteredScheduledTaskInfo -TaskName "MaintenanceTask" -Cluster "MyCluster.contoso.com" -TaskState "Ready"

        Retrieves detailed information about the clustered scheduled task named "MaintenanceTask" that is in "Ready" state
        from cluster "MyCluster.contoso.com".

    .EXAMPLE
        $credentials = Get-Credential
        Get-StmClusteredScheduledTaskInfo -TaskName "ReportTask" -Cluster "MyCluster" -Credential $credentials |
            Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime

        Retrieves detailed information about the clustered scheduled task named "ReportTask" using specified credentials
        and displays only the task name, last run time, last result, and next run time.

    .EXAMPLE
        $session = New-CimSession -ComputerName "MyCluster"
        Get-StmClusteredScheduledTaskInfo -TaskName "CleanupTask" -Cluster "MyCluster" -CimSession $session

        Retrieves detailed information about the clustered scheduled task named "CleanupTask" using an existing CIM session.

    .INPUTS
        None. You cannot pipe objects to Get-StmClusteredScheduledTaskInfo.

    .OUTPUTS
        PSCustomObject
        Returns custom objects containing merged information from both clustered scheduled task and scheduled task info objects:
        - TaskName: The name of the clustered scheduled task
        - CurrentOwner: The current owner node of the task
        - TaskState: The current state of the task
        - TaskType: The type of clustered task
        - LastRunTime: The last time the task was executed
        - LastTaskResult: The result of the last task execution
        - NextRunTime: The next scheduled run time
        - NumberOfMissedRuns: The number of times the task failed to run
        - ClusteredScheduledTaskObject: The underlying clustered scheduled task object
        - ScheduledTaskInfoObject: The underlying scheduled task info object

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to access clustered scheduled tasks
        - Network connectivity to the cluster
        - The task must exist on the specified cluster

        The function uses Get-StmClusteredScheduledTask internally to retrieve the task and then calls
        Get-ScheduledTaskInfo to get detailed execution information.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cluster,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]
        $TaskState,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.ClusterTaskTypeEnum]
        $TaskType,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $CimSession
    )

    begin {
        Write-Verbose "Starting Get-StmClusteredScheduledTaskInfo on cluster '$Cluster'"
        $stmScheduledTaskParameters = @{
            Cluster = $Cluster
        }

        if ($PSBoundParameters.ContainsKey('TaskName')) {
            Write-Verbose "Filtering tasks by name: '$TaskName'"
            $stmScheduledTaskParameters['TaskName'] = $TaskName
        }
        else {
            Write-Verbose "Retrieving all tasks on cluster '$Cluster'"
        }

        if ($PSBoundParameters.ContainsKey('TaskType')) {
            Write-Verbose "Filtering tasks by type: '$TaskType'"
            $stmScheduledTaskParameters['TaskType'] = $TaskType
        }
        else {
            Write-Verbose 'No specific task type filter applied'
        }

        if ($PSBoundParameters.ContainsKey('TaskState')) {
            Write-Verbose "Filtering tasks by state: '$TaskState'"
            $stmScheduledTaskParameters['TaskState'] = $TaskState
        }
        else {
            Write-Verbose 'No specific task state filter applied'
        }

        if ($PSBoundParameters.ContainsKey('CimSession')) {
            Write-Verbose "Using provided CIM session for cluster '$Cluster'"
            $stmScheduledTaskParameters['CimSession'] = $CimSession
        }
        elseif ($PSBoundParameters.ContainsKey('Credential')) {
            Write-Verbose "Using provided credentials for cluster '$Cluster'"
            $stmScheduledTaskParameters['Credential'] = $Credential
        }
        else {
            Write-Verbose 'No CIM session or credentials provided, using default credentials'
        }

        $scheduledTask = Get-StmClusteredScheduledTask @stmScheduledTaskParameters
    }

    process {
        if ($scheduledTask.Count -eq 0) {
            Write-Warning "No scheduled tasks found on cluster '$Cluster' with the specified parameters."
            return
        }
        Write-Verbose "Retrieving scheduled task info for $($scheduledTask.Count) tasks on cluster '$Cluster'"
        $scheduledTaskInfo = $scheduledTask.ScheduledTaskObject | Get-ScheduledTaskInfo

        Write-Verbose 'Merging properties from clustered scheduled task and task info'
        $mergeParameters = @{
            FirstObject      = $scheduledTask.ClusteredScheduledTaskObject
            FirstObjectName  = 'ClusteredScheduledTaskObject'
            SecondObject     = $scheduledTaskInfo
            SecondObjectName = 'ScheduledTaskInfoObject'
            AsHashtable      = $true
            ErrorAction      = 'Stop'
        }
        $mergedHashtable = Merge-Object @mergeParameters
        # Ensure top-level TaskName property for test compatibility
        if (-not ($mergedHashtable.Keys -contains 'TaskName') -and ($mergedHashtable.Keys -contains 'ClusteredScheduledTaskObject')) {
            $mergedHashtable['TaskName'] = $mergedHashtable['ClusteredScheduledTaskObject'].TaskName
        }
        # If TaskName is a hashtable (from merge conflict), set it to the value from ClusteredScheduledTaskObject
        if ($mergedHashtable['TaskName'] -is [hashtable] -and ($mergedHashtable.Keys -contains 'ClusteredScheduledTaskObject')) {
            $mergedHashtable['TaskName'] = $mergedHashtable['ClusteredScheduledTaskObject'].TaskName
        }
        [PSCustomObject]$mergedHashtable
    }

    end {
        Write-Verbose "Completed Get-StmClusteredScheduledTaskInfo for cluster '$Cluster'"
    }
}
