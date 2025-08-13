---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Wait-StmClusteredScheduledTask

## SYNOPSIS
Waits for a clustered scheduled task to complete execution on a Windows failover cluster.

## SYNTAX

```
Wait-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [[-PollingIntervalSeconds] <Int32>] [[-TimeoutSeconds] <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The Wait-StmClusteredScheduledTask function monitors a clustered scheduled task and waits for it to complete
its execution.
This function polls the task state at regular intervals and provides progress feedback
through Write-Progress.
The function will exit when the task is no longer in the 'Running' state or when
the specified timeout is reached.
This is useful for automation scenarios where you need to wait for
a task to complete before proceeding with subsequent operations.

## EXAMPLES

### EXAMPLE 1
```
Wait-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster"
```

Waits for the clustered scheduled task named "BackupTask" on cluster "MyCluster" to complete,
using default polling interval (5 seconds) and timeout (300 seconds).

### EXAMPLE 2
```
Wait-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "MyCluster.contoso.com" -TimeoutSeconds 600
```

Waits for the clustered scheduled task named "MaintenanceTask" on cluster "MyCluster.contoso.com" to complete,
with a timeout of 10 minutes (600 seconds).

### EXAMPLE 3
```
$creds = Get-Credential
Wait-StmClusteredScheduledTask -TaskName "ReportTask" -Cluster "MyCluster" -Credential $creds -PollingIntervalSeconds 10
```

Waits for the clustered scheduled task named "ReportTask" on cluster "MyCluster" using specified credentials,
checking the task state every 10 seconds.

### EXAMPLE 4
```
Wait-StmClusteredScheduledTask -TaskName "LongRunningTask" -Cluster "MyCluster" -TimeoutSeconds 1800 -Verbose
```

Waits for the clustered scheduled task named "LongRunningTask" on cluster "MyCluster" with a 30-minute timeout
and verbose output to show detailed information about the waiting process.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to wait for.
This parameter is mandatory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Cluster
Specifies the name or FQDN of the cluster where the scheduled task is located.
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

### -Credential
Specifies credentials to use when connecting to the cluster.
If not provided, the current user's credentials
will be used for the connection.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -PollingIntervalSeconds
Specifies the interval in seconds between state checks of the clustered scheduled task.
The default value is 5 seconds.
This parameter is optional.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSeconds
Specifies the maximum time in seconds to wait for the task to complete.
If the timeout is reached, the function
will throw an error.
The default value is 300 seconds (5 minutes).
This parameter is optional.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 300
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

### None. You cannot pipe objects to Wait-StmClusteredScheduledTask.
## OUTPUTS

### None. This function does not return any output objects.
## NOTES
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

## RELATED LINKS
