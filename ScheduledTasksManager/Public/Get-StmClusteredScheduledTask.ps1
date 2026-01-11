function Get-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Retrieves clustered scheduled tasks from a Windows failover cluster.

    .DESCRIPTION
        The Get-StmClusteredScheduledTask function retrieves clustered scheduled tasks from a Windows failover cluster.
        This function connects to the specified cluster and retrieves information about clustered scheduled tasks,
        including their current state, ownership, and configuration. You can filter tasks by name, state, or type.
        The function returns detailed information about each task including its scheduled task object, current owner,
        and cluster-specific properties.

    .PARAMETER TaskName
        Specifies the name of a specific clustered scheduled task to retrieve. If not specified, all clustered
        scheduled tasks on the cluster will be returned. This parameter is optional.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster to query for clustered scheduled tasks. This parameter is mandatory.

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
        Get-StmClusteredScheduledTask -Cluster "MyCluster"

        Retrieves all clustered scheduled tasks from cluster "MyCluster" using the current user's credentials.

    .EXAMPLE
        Get-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster.contoso.com"

        Retrieves the specific clustered scheduled task named "BackupTask" from cluster "MyCluster.contoso.com".

    .EXAMPLE
        Get-StmClusteredScheduledTask -Cluster "MyCluster" -TaskState "Ready" -TaskType "ClusterWide"

        Retrieves all clustered scheduled tasks that are in "Ready" state and are "ClusterWide" type from cluster
        "MyCluster".

    .EXAMPLE
        $credentials = Get-Credential
        Get-StmClusteredScheduledTask -Cluster "MyCluster" -Credential $credentials |
            Where-Object { $_.CurrentOwner -eq "Node01" }

        Retrieves all clustered scheduled tasks from cluster "MyCluster" using specified credentials and filters to show
        only tasks owned by "Node01".

    .EXAMPLE
        $session = New-CimSession -ComputerName "MyCluster"
        Get-StmClusteredScheduledTask -Cluster "MyCluster" -CimSession $session

        Retrieves all clustered scheduled tasks using an existing CIM session.

    .INPUTS
        None. You cannot pipe objects to Get-StmClusteredScheduledTask.

    .OUTPUTS
        PSCustomObject
        Returns custom objects containing:
        - ScheduledTaskObject: The underlying ScheduledTask object
        - CurrentOwner: The current owner node of the task
        - TaskName: The name of the clustered scheduled task
        - TaskState: The current state of the task
        - TaskType: The type of clustered task
        - Cluster: The cluster name where the task is located

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to access clustered scheduled tasks
        - Network connectivity to the cluster
        - The cluster must be properly configured with clustered scheduled tasks

        The function uses Get-ClusteredScheduledTask internally to retrieve the task information from the cluster.
    #>

    [CmdletBinding()]
    param(
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
        $clusteredScheduledTasksParameters = @{
            Cluster = $Cluster
        }

        $taskNameProvided = $PSBoundParameters.ContainsKey('TaskName')
        if ($taskNameProvided) {
            Write-Verbose "Starting Get-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
            $clusteredScheduledTasksParameters['TaskName'] = $TaskName
        }
        else {
            Write-Verbose "Starting Get-StmClusteredScheduledTask for all tasks on cluster '$Cluster'"
        }

        if ($PSBoundParameters.ContainsKey('TaskType')) {
            Write-Verbose "Filtering tasks by type: '$TaskType'"
            $clusteredScheduledTasksParameters['TaskType'] = $TaskType
        }

        # Track CIM sessions for cleanup
        $script:cimSessionsToCleanup = [System.Collections.Generic.List[Microsoft.Management.Infrastructure.CimSession]]::new()

        if ($PSBoundParameters.ContainsKey('CimSession')) {
            Write-Verbose "Using provided CIM session for cluster '$Cluster'"
            $clusteredScheduledTasksParameters['CimSession'] = $CimSession
        }
        else {
            Write-Verbose "Creating new CIM session for cluster '$Cluster'"
            $cimSessionParameters = @{
                ComputerName = $Cluster
                Credential   = $Credential
                ErrorAction  = 'Stop'
            }
            $clusterCimSession = New-StmCimSession @cimSessionParameters
            $clusteredScheduledTasksParameters['CimSession'] = $clusterCimSession
            $script:cimSessionsToCleanup.Add($clusterCimSession)
        }
    }

    process {
        Write-Verbose "Retrieving clustered scheduled tasks from cluster '$Cluster'"
        $clusteredScheduledTasks = Get-ClusteredScheduledTask @clusteredScheduledTasksParameters
        if ($clusteredScheduledTasks.Count -eq 0) {
            Write-Warning (
                "No clustered scheduled tasks found on cluster '$Cluster'. " +
                'Ensure the cluster is properly configured.'
            )
            return
        }
        Write-Verbose "Found $($clusteredScheduledTasks.Count) clustered scheduled task(s) on cluster '$Cluster'"

        $uniqueTaskOwners = @(
            $clusteredScheduledTasks |
                Select-Object -ExpandProperty 'CurrentOwner' |
                Where-Object { -not [string]::IsNullOrEmpty($_) } |
                Select-Object -Unique
        )
        if ($uniqueTaskOwners.Count -eq 0) {
            Write-Error (
                "No current owners found for tasks in cluster '$Cluster'. " +
                'Ensure the cluster is properly configured.'
            )
            return
        }
        else {
            Write-Verbose "Found $($uniqueTaskOwners.Count) unique task owner(s): $($uniqueTaskOwners -join ', ')"
        }
        foreach ($taskOwner in $uniqueTaskOwners) {
            if ([string]::IsNullOrEmpty($taskOwner)) {
                Write-Verbose 'Skipping task owner with null or empty name'
                continue
            }

            $clusteredScheduledTasksOwnedByCurrentOwner = $clusteredScheduledTasks | Where-Object {
                $_.CurrentOwner -eq $taskOwner
            }
            $taskNames = $clusteredScheduledTasksOwnedByCurrentOwner.TaskName

            try {
                # Note: Task owner CIM sessions are NOT cleaned up because the returned
                # ScheduledTaskObject contains CIM instance references that depend on them
                $taskOwnerCimSession = New-StmCimSession -ComputerName $taskOwner -Credential $Credential
                Write-Verbose "Retrieving scheduled tasks from owner '$taskOwner' using CIM session"
                $getScheduledTaskParameters = @{
                    TaskName   = $taskNames
                    CimSession = $taskOwnerCimSession
                }
                $scheduledTasksFromOwner = Get-ScheduledTask @getScheduledTaskParameters

                if ($PSBoundParameters.ContainsKey('TaskState')) {
                    Write-Verbose "Filtering scheduled tasks by state '$TaskState' on owner '$taskOwner'"
                    $scheduledTasksFromOwner = $scheduledTasksFromOwner | Where-Object { $_.State -eq $TaskState }
                }

                foreach ($scheduledTaskFromOwner in $scheduledTasksFromOwner) {
                    $procMsg = (
                        "Processing scheduled task '" + $scheduledTaskFromOwner.TaskName +
                        "' from owner '" + $taskOwner + "'"
                    )
                    Write-Verbose $procMsg
                    $findMsg = (
                        "Finding matching clustered scheduled task for '" +
                        $scheduledTaskFromOwner.TaskName + "'"
                    )
                    Write-Verbose $findMsg
                    $clusteredScheduledTask = $clusteredScheduledTasksOwnedByCurrentOwner | Where-Object {
                        $_.TaskName -eq $scheduledTaskFromOwner.TaskName
                    }

                    if ($null -eq $clusteredScheduledTask) {
                        $noMatchMsg = (
                            "No matching clustered task found for '" +
                            $scheduledTaskFromOwner.TaskName + "'"
                        )
                        Write-Warning $noMatchMsg
                        continue
                    }

                    try {
                        Write-Verbose 'Merging properties from clustered scheduled task and task info'
                        $mergeParameters = @{
                            FirstObject      = $clusteredScheduledTask
                            FirstObjectName  = 'ClusteredScheduledTaskObject'
                            SecondObject     = $scheduledTaskFromOwner
                            SecondObjectName = 'ScheduledTaskObject'
                            AsHashtable      = $true
                            ErrorAction      = 'Stop'
                        }
                        $mergedHashtable = Merge-Object @mergeParameters
                        [PSCustomObject]$mergedHashtable
                    }
                    catch {
                        $mergeFailMsg = (
                            "Failed to merge objects for task '" +
                            $scheduledTaskFromOwner.TaskName + "': " + $_.Exception.Message
                        )
                        Write-Warning $mergeFailMsg
                    }
                }
            }
            catch {
                # Clean up the session on error since no valid objects will be returned
                if ($taskOwnerCimSession) {
                    Remove-CimSession -CimSession $taskOwnerCimSession -ErrorAction SilentlyContinue
                }
                $ownerErrMsg = (
                    "Failed to retrieve tasks from owner '" + $taskOwner +
                    "': " + $_.Exception.Message
                )
                Write-Error $ownerErrMsg
            }
        }
    }

    end {
        foreach ($session in $script:cimSessionsToCleanup) {
            if ($session) {
                Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue
            }
        }
        Write-Verbose "Finished Get-StmClusteredScheduledTask for cluster '$Cluster'"
    }
}
