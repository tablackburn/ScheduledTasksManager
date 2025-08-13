---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Unregister-StmClusteredScheduledTask

## SYNOPSIS
Unregisters a clustered scheduled task from a Windows failover cluster.

## SYNTAX

```
Unregister-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Unregister-StmClusteredScheduledTask function removes a clustered scheduled task from a Windows failover cluster.
This function creates a CIM session to the cluster and uses the native Unregister-ClusteredScheduledTask cmdlet to
remove the task.
The function supports the -WhatIf and -Confirm parameters for safe execution and provides
comprehensive error handling for connection and operation failures.

## EXAMPLES

### EXAMPLE 1
```
Unregister-StmClusteredScheduledTask -TaskName "OldBackupTask" -Cluster "MyCluster"
```

Unregisters the clustered scheduled task named "OldBackupTask" from cluster "MyCluster" using the current user's credentials.

### EXAMPLE 2
```
Unregister-StmClusteredScheduledTask -TaskName "DeprecatedTask" -Cluster "MyCluster.contoso.com" -WhatIf
```

Shows what would happen if the clustered scheduled task named "DeprecatedTask" were unregistered from cluster "MyCluster.contoso.com"
without actually removing it.

### EXAMPLE 3
```
$creds = Get-Credential
Unregister-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "MyCluster" -Credential $creds -Confirm
```

Unregisters the clustered scheduled task named "TestTask" from cluster "MyCluster" using specified credentials
and prompts for confirmation before removing the task.

### EXAMPLE 4
```
Unregister-StmClusteredScheduledTask -TaskName "CleanupTask" -Cluster "MyCluster" -Verbose
```

Unregisters the clustered scheduled task named "CleanupTask" from cluster "MyCluster" with verbose output
to show detailed information about the operation.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to unregister.
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

### None. You cannot pipe objects to Unregister-StmClusteredScheduledTask.
## OUTPUTS

### None. This function does not return any output objects.
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to unregister clustered scheduled tasks
- Network connectivity to the cluster
- The task must exist on the specified cluster

The function provides comprehensive error handling for:
- CIM session creation failures
- Task unregistration failures
- Invalid task names or cluster names

This function supports the -WhatIf and -Confirm parameters for safe execution in automated scenarios.
The unregistration operation is irreversible, so use caution when running this function.

## RELATED LINKS
