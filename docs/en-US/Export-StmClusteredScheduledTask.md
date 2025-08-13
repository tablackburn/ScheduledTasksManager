---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Export-StmClusteredScheduledTask

## SYNOPSIS
Exports a clustered scheduled task from a Windows failover cluster.

## SYNTAX

```
Export-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Credential] <PSCredential>]
 [[-FilePath] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Export-StmClusteredScheduledTask function exports a clustered scheduled task from a Windows failover cluster
to an XML format.
This function retrieves the specified clustered scheduled task using Get-StmClusteredScheduledTask
and then exports it using the native Export-ScheduledTask cmdlet.
The exported XML can be used to recreate the task
on other systems or for backup purposes.

## EXAMPLES

### EXAMPLE 1
```
Export-StmClusteredScheduledTask -TaskName "MyTask" -Cluster "MyCluster"
```

Exports the clustered scheduled task named "MyTask" from cluster "MyCluster" using the current user's credentials
and returns the XML to the pipeline.

### EXAMPLE 2
```
$creds = Get-Credential
Export-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster.contoso.com" -Credential $creds
```

Exports the clustered scheduled task named "BackupTask" from cluster "MyCluster.contoso.com" using the specified credentials
and returns the XML to the pipeline.

### EXAMPLE 3
```
Export-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "MyCluster" -FilePath "C:\Tasks\MaintenanceTask.xml"
```

Exports the clustered scheduled task and saves the XML output directly to the specified file path.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to export.
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

### -FilePath
Specifies the path where the exported XML file should be saved.
If provided, the function will save the XML
to the specified file path instead of returning it to the pipeline.
If not provided, the XML is returned
to the pipeline as a string.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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

### None. You cannot pipe objects to Export-StmClusteredScheduledTask.
## OUTPUTS

### System.String
### Returns the XML representation of the clustered scheduled task that can be used to recreate the task.
### If FilePath is specified, no output is returned to the pipeline.
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to access clustered scheduled tasks
- Network connectivity to the cluster
- The task must exist on the specified cluster

The function uses Get-StmClusteredScheduledTask internally to retrieve the task before exporting it.

## RELATED LINKS
