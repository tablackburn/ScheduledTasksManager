---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Start-StmClusteredScheduledTask

## SYNOPSIS
Starts a clustered scheduled task on a Windows failover cluster.

## SYNTAX

```
Start-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Start-StmClusteredScheduledTask function starts a clustered scheduled task on a Windows failover cluster.
This function retrieves the specified clustered scheduled task using Get-StmClusteredScheduledTask and then
starts it using the native Start-ScheduledTask cmdlet.
The function supports the -WhatIf and -Confirm parameters
for safe execution and provides verbose output for troubleshooting.

## EXAMPLES

### EXAMPLE 1
```
Start-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster"
```

Starts the clustered scheduled task named "BackupTask" on cluster "MyCluster" using the current user's credentials.

### EXAMPLE 2
```
Start-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "MyCluster.contoso.com" -WhatIf
```

Shows what would happen if the clustered scheduled task named "MaintenanceTask" were started on cluster "MyCluster.contoso.com"
without actually starting it.

### EXAMPLE 3
```
$creds = Get-Credential
Start-StmClusteredScheduledTask -TaskName "ReportTask" -Cluster "MyCluster" -Credential $creds -Confirm
```

Starts the clustered scheduled task named "ReportTask" on cluster "MyCluster" using specified credentials
and prompts for confirmation before starting.

### EXAMPLE 4
```
Start-StmClusteredScheduledTask -TaskName "CleanupTask" -Cluster "MyCluster" -Verbose
```

Starts the clustered scheduled task named "CleanupTask" on cluster "MyCluster" with verbose output
to show detailed information about the operation.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to start.
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

### None. You cannot pipe objects to Start-StmClusteredScheduledTask.
## OUTPUTS

### None. This function does not return any output objects.
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to start clustered scheduled tasks
- Network connectivity to the cluster
- The task must exist on the specified cluster
- The task must be in a state that allows it to be started (e.g., Ready, Disabled)

The function uses Get-StmClusteredScheduledTask internally to retrieve the task before starting it.
If the task is not found or cannot be started, an error will be thrown.

This function supports the -WhatIf and -Confirm parameters for safe execution in automated scenarios.

## RELATED LINKS
