---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Enable-StmClusteredScheduledTask

## SYNOPSIS
Enables a disabled clustered scheduled task in a Windows failover cluster.

## SYNTAX

```
Enable-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Enable-StmClusteredScheduledTask function enables a previously disabled clustered scheduled task
by modifying its configuration and re-registering it in the Windows failover cluster.
The function
performs a complete task re-registration process to ensure the task is properly enabled and functional.

The function performs the following operations:
1.
Exports the current task configuration using Export-StmClusteredScheduledTask
2.
Modifies the XML configuration to set the Enabled property to 'true'
3.
Retrieves the original task type to maintain proper registration
4.
Unregisters the current disabled task
5.
Re-registers the task with the modified (enabled) configuration
6.
Provides detailed verbose output for troubleshooting

This function is useful when a clustered scheduled task has been disabled and needs to be
re-enabled for execution.
The re-registration process ensures the task is properly configured
and ready to run according to its schedule.

## EXAMPLES

### EXAMPLE 1
```
Enable-StmClusteredScheduledTask -TaskName "MyBackupTask" -Cluster "MyCluster"
```

Enables the clustered scheduled task named "MyBackupTask" on cluster "MyCluster" using
the current user's credentials.
The task will be re-registered with enabled status.

### EXAMPLE 2
```
$creds = Get-Credential
Enable-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "ProdCluster" -Credential $creds
```

Enables the clustered scheduled task named "MaintenanceTask" on cluster "ProdCluster" using
the specified credentials.
The task will be re-registered with enabled status.

### EXAMPLE 3
```
Enable-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "TestCluster" -Verbose
```

Enables the clustered scheduled task with verbose output showing detailed information about
the export, modification, and re-registration process.

### EXAMPLE 4
```
Enable-StmClusteredScheduledTask -TaskName "DisabledTask" -Cluster "MyCluster" -WhatIf
```

Shows what would happen if the cmdlet runs without actually performing the operation.
This is useful for testing the command before execution.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to enable.
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

### None. You cannot pipe objects to Enable-StmClusteredScheduledTask.
## OUTPUTS

### None. This cmdlet does not return any objects.
## NOTES
This function requires:
- PowerShell remoting to be enabled on the target cluster
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to manage clustered scheduled tasks
- Network connectivity to the cluster on the WinRM ports (default 5985/5986)

The function performs a complete re-registration of the task, which involves:
- Unregistering the current disabled task
- Re-registering the task with the enabled configuration
- Maintaining the original task type and other properties

If the task is already enabled, the function will display a warning and exit without
making any changes.

This operation temporarily removes the task from the cluster during the re-registration
process.
The task will be unavailable for execution during this brief period.

The function supports the -WhatIf and -Confirm parameters for safe operation in automated
environments.

## RELATED LINKS
