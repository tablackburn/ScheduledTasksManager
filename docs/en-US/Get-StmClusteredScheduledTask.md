---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Get-StmClusteredScheduledTask

## SYNOPSIS
Retrieves clustered scheduled tasks from a Windows failover cluster.

## SYNTAX

```
Get-StmClusteredScheduledTask [[-TaskName] <String>] [-Cluster] <String> [[-TaskState] <StateEnum>]
 [[-TaskType] <ClusterTaskTypeEnum>] [[-Credential] <PSCredential>] [[-CimSession] <CimSession>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-StmClusteredScheduledTask function retrieves clustered scheduled tasks from a Windows failover cluster.
This function connects to the specified cluster and retrieves information about clustered scheduled tasks,
including their current state, ownership, and configuration.
You can filter tasks by name, state, or type.
The function returns detailed information about each task including its scheduled task object, current owner,
and cluster-specific properties.

## EXAMPLES

### EXAMPLE 1
```
Get-StmClusteredScheduledTask -Cluster "MyCluster"
```

Retrieves all clustered scheduled tasks from cluster "MyCluster" using the current user's credentials.

### EXAMPLE 2
```
Get-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster.contoso.com"
```

Retrieves the specific clustered scheduled task named "BackupTask" from cluster "MyCluster.contoso.com".

### EXAMPLE 3
```
Get-StmClusteredScheduledTask -Cluster "MyCluster" -TaskState "Ready" -TaskType "ClusterWide"
```

Retrieves all clustered scheduled tasks that are in "Ready" state and are "ClusterWide" type from cluster "MyCluster".

### EXAMPLE 4
```
$credentials = Get-Credential
Get-StmClusteredScheduledTask -Cluster "MyCluster" -Credential $credentials | Where-Object { $_.CurrentOwner -eq "Node01" }
```

Retrieves all clustered scheduled tasks from cluster "MyCluster" using specified credentials and filters to show
only tasks owned by "Node01".

### EXAMPLE 5
```
$session = New-CimSession -ComputerName "MyCluster"
Get-StmClusteredScheduledTask -Cluster "MyCluster" -CimSession $session
```

Retrieves all clustered scheduled tasks using an existing CIM session.

## PARAMETERS

### -TaskName
Specifies the name of a specific clustered scheduled task to retrieve.
If not specified, all clustered
scheduled tasks on the cluster will be returned.
This parameter is optional.

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
Specifies the name or FQDN of the cluster to query for clustered scheduled tasks.
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

### None. You cannot pipe objects to Get-StmClusteredScheduledTask.
## OUTPUTS

### PSCustomObject
### Returns custom objects containing:
### - ScheduledTaskObject: The underlying ScheduledTask object
### - CurrentOwner: The current owner node of the task
### - TaskName: The name of the clustered scheduled task
### - TaskState: The current state of the task
### - TaskType: The type of clustered task
### - Cluster: The cluster name where the task is located
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to access clustered scheduled tasks
- Network connectivity to the cluster
- The cluster must be properly configured with clustered scheduled tasks

The function uses Get-ClusteredScheduledTask internally to retrieve the task information from the cluster.

## RELATED LINKS
