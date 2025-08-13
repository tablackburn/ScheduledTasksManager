---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Get-StmClusteredScheduledTaskInfo

## SYNOPSIS
Retrieves detailed information about clustered scheduled tasks from a Windows failover cluster.

## SYNTAX

```
Get-StmClusteredScheduledTaskInfo [[-TaskName] <String>] [-Cluster] <String> [[-TaskState] <StateEnum>]
 [[-TaskType] <ClusterTaskTypeEnum>] [[-Credential] <PSCredential>] [[-CimSession] <CimSession>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-StmClusteredScheduledTaskInfo function retrieves comprehensive information about clustered scheduled tasks
from a Windows failover cluster.
This function combines information from both the clustered scheduled task object
and the scheduled task info object to provide detailed execution history, last run times, next run times,
and other operational details.
You can filter tasks by name, state, or type to get information for specific tasks.

## EXAMPLES

### EXAMPLE 1
```
Get-StmClusteredScheduledTaskInfo -TaskName "BackupTask" -Cluster "MyCluster"
```

Retrieves detailed information about the clustered scheduled task named "BackupTask" from cluster "MyCluster".

### EXAMPLE 2
```
Get-StmClusteredScheduledTaskInfo -TaskName "MaintenanceTask" -Cluster "MyCluster.contoso.com" -TaskState "Ready"
```

Retrieves detailed information about the clustered scheduled task named "MaintenanceTask" that is in "Ready" state
from cluster "MyCluster.contoso.com".

### EXAMPLE 3
```
$credentials = Get-Credential
Get-StmClusteredScheduledTaskInfo -TaskName "ReportTask" -Cluster "MyCluster" -Credential $credentials |
    Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime
```

Retrieves detailed information about the clustered scheduled task named "ReportTask" using specified credentials
and displays only the task name, last run time, last result, and next run time.

### EXAMPLE 4
```
$session = New-CimSession -ComputerName "MyCluster"
Get-StmClusteredScheduledTaskInfo -TaskName "CleanupTask" -Cluster "MyCluster" -CimSession $session
```

Retrieves detailed information about the clustered scheduled task named "CleanupTask" using an existing CIM session.

## PARAMETERS

### -TaskName
Specifies the name of a specific clustered scheduled task to retrieve information for.
This parameter is mandatory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Cluster
Specifies the name or FQDN of the cluster to query for clustered scheduled task information.
This parameter is mandatory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskState
Specifies the state of the tasks to filter by.
Valid values are: Unknown, Disabled, Queued, Ready, Running.
If not specified, tasks in all states will be returned.
This parameter is optional.

```yaml
Type: StateEnum
Parameter Sets: (All)
Aliases:
Accepted values: Unknown, Disabled, Queued, Ready, Running

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskType
Specifies the type of clustered tasks to filter by.
Valid values are: ResourceSpecific, AnyNode, ClusterWide.
If not specified, tasks of all types will be returned.
This parameter is optional.

```yaml
Type: ClusterTaskTypeEnum
Parameter Sets: (All)
Aliases:
Accepted values: ResourceSpecific, AnyNode, ClusterWide

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Specifies credentials to use when connecting to the cluster.
If not provided, the current user's credentials
will be used for the connection.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -CimSession
Specifies an existing CIM session to use for the connection to the cluster.
If not provided, a new CIM session
will be created using the Cluster and Credential parameters.

```yaml
Type: CimSession
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None. You cannot pipe objects to Get-StmClusteredScheduledTaskInfo.
## OUTPUTS

### PSCustomObject
### Returns custom objects containing merged information from both clustered scheduled task and scheduled task info objects:
### - TaskName: The name of the clustered scheduled task
### - CurrentOwner: The current owner node of the task
### - TaskState: The current state of the task
### - TaskType: The type of clustered task
### - LastRunTime: The last time the task was executed
### - LastTaskResult: The result of the last task execution
### - NextRunTime: The next scheduled run time
### - NumberOfMissedRuns: The number of times the task failed to run
### - ClusteredScheduledTaskObject: The underlying clustered scheduled task object
### - ScheduledTaskInfoObject: The underlying scheduled task info object
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to access clustered scheduled tasks
- Network connectivity to the cluster
- The task must exist on the specified cluster

The function uses Get-StmClusteredScheduledTask internally to retrieve the task and then calls
Get-ScheduledTaskInfo to get detailed execution information.

## RELATED LINKS
