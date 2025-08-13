---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Disable-StmClusteredScheduledTask

## SYNOPSIS
Disables (unregisters) a clustered scheduled task from a Windows failover cluster.

## SYNTAX

```
Disable-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Disable-StmClusteredScheduledTask function safely disables a clustered scheduled task by
unregistering it from a Windows failover cluster.
Before unregistering the task, the function
automatically creates a backup of the task configuration in XML format to the system's temporary
directory.
This ensures that the task can be restored if needed.

The function performs the following operations:
1.
Creates a backup of the task configuration using Export-StmClusteredScheduledTask
2.
Unregisters the clustered scheduled task using the native Unregister-ClusteredScheduledTask cmdlet
3.
Verifies that the task has been successfully unregistered
4.
Provides detailed verbose output for troubleshooting

This function requires appropriate permissions to manage clustered scheduled tasks and
network connectivity to the target cluster.

## EXAMPLES

### EXAMPLE 1
```
Disable-StmClusteredScheduledTask -TaskName "MyBackupTask" -Cluster "MyCluster"
```

Disables the clustered scheduled task named "MyBackupTask" on cluster "MyCluster" using
the current user's credentials.
A backup will be created before unregistering the task.

### EXAMPLE 2
```
$creds = Get-Credential
Disable-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "ProdCluster" -Credential $creds
```

Disables the clustered scheduled task named "MaintenanceTask" on cluster "ProdCluster" using
the specified credentials.
A backup will be created before unregistering the task.

### EXAMPLE 3
```
Disable-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "TestCluster" -Verbose
```

Disables the clustered scheduled task with verbose output showing detailed information about
the backup creation and unregistration process.

### EXAMPLE 4
```
Disable-StmClusteredScheduledTask -TaskName "OldTask" -Cluster "MyCluster" -WhatIf
```

Shows what would happen if the cmdlet runs without actually performing the operation.
This is useful for testing the command before execution.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to disable.
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

### None. You cannot pipe objects to Disable-StmClusteredScheduledTask.
## OUTPUTS

### None. This cmdlet does not return any objects.
## NOTES
This function requires:
- PowerShell remoting to be enabled on the target cluster
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to manage clustered scheduled tasks
- Network connectivity to the cluster on the WinRM ports (default 5985/5986)
- Write permissions to the system's temporary directory for backup creation

The function automatically creates a backup of the task configuration before unregistering it.
The backup file is saved to the system's temporary directory with a timestamp in the filename
format: TaskName_Cluster_yyyyMMddHHmmss.xml

This operation is irreversible once confirmed.
The task will be completely removed from the
cluster and cannot be easily restored without the backup file.

The function supports the -WhatIf and -Confirm parameters for safe operation in automated
environments.

## RELATED LINKS
