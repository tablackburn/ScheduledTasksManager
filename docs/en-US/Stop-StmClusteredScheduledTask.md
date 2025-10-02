---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Stop-StmClusteredScheduledTask

## SYNOPSIS
Stops a running clustered scheduled task on a Windows failover cluster.

## SYNTAX

```
Stop-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Stop-StmClusteredScheduledTask function stops a running clustered scheduled task on a Windows failover cluster.
This function retrieves the specified clustered scheduled task using Get-StmClusteredScheduledTask and then
stops it using the native Stop-ScheduledTask cmdlet.
The function supports the -WhatIf and -Confirm parameters
for safe execution and provides verbose output for troubleshooting.

The function performs the following operations:
1. Retrieves the clustered scheduled task using Get-StmClusteredScheduledTask
2. Stops the scheduled task using the native Stop-ScheduledTask cmdlet
3. Provides detailed verbose output for troubleshooting

This function requires appropriate permissions to stop clustered scheduled tasks and
network connectivity to the target cluster.

## EXAMPLES

### EXAMPLE 1
```
Stop-StmClusteredScheduledTask -TaskName "MyBackupTask" -Cluster "MyCluster"
```

Stops the clustered scheduled task named "MyBackupTask" on cluster "MyCluster" using
the current user's credentials.

### EXAMPLE 2
```
$creds = Get-Credential
Stop-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "ProdCluster" -Credential $creds
```

Stops the clustered scheduled task named "MaintenanceTask" on cluster "ProdCluster" using
the specified credentials.

### EXAMPLE 3
```
Stop-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "TestCluster" -Verbose
```

Stops the clustered scheduled task with verbose output showing detailed information about
the retrieval and stopping process.

### EXAMPLE 4
```
Stop-StmClusteredScheduledTask -TaskName "RunningTask" -Cluster "MyCluster" -WhatIf
```

Shows what would happen if the cmdlet runs without actually performing the operation.
This is useful for testing the command before execution.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to stop.
This parameter is mandatory
and must match the exact name of the task as it appears in the cluster.

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
This parameter
is mandatory and must be a valid Windows failover cluster.

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
If not provided, the current
user's credentials will be used for the connection.
This parameter is optional.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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

### None. You cannot pipe objects to Stop-StmClusteredScheduledTask.
## OUTPUTS

### None. This function does not return any objects.
## NOTES
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

## RELATED LINKS
