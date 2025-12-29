---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Export-StmScheduledTask

## SYNOPSIS
Exports a scheduled task configuration to XML on a local or remote computer.

## SYNTAX

```
Export-StmScheduledTask [-TaskName] <String> [[-TaskPath] <String>] [[-ComputerName] <String>]
 [[-Credential] <PSCredential>] [[-FilePath] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The Export-StmScheduledTask function exports the configuration of a scheduled task to XML format.
The XML can be returned as a string or saved to a file.
This function wraps the built-in
Export-ScheduledTask cmdlet to provide credential support and enhanced error handling across
the ScheduledTasksManager module.

The exported XML can be used with Register-StmScheduledTask or Import-StmScheduledTask to
recreate the task on the same or different computer.

This function requires appropriate permissions to query scheduled tasks on the target computer.

## EXAMPLES

### EXAMPLE 1
```
Export-StmScheduledTask -TaskName "MyBackupTask"
```

Exports the scheduled task named "MyBackupTask" and returns the XML as a string.

### EXAMPLE 2
```
Export-StmScheduledTask -TaskName "MyBackupTask" -FilePath "C:\Backups\MyBackupTask.xml"
```

Exports the scheduled task named "MyBackupTask" and saves it to the specified file.

### EXAMPLE 3
```
Export-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\" -FilePath ".\backup.xml"
```

Exports the scheduled task from the specified path and saves it to a file in the current directory.

### EXAMPLE 4
```
$xml = Export-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01"
```

Exports a task from a remote computer and stores the XML in a variable.

### EXAMPLE 5
```
$credentials = Get-Credential
Export-StmScheduledTask -TaskName "ReportTask" -ComputerName "Server02" -Credential $credentials -FilePath "C:\Export\ReportTask.xml"
```

Exports a task from a remote computer using specified credentials and saves to a file.

## PARAMETERS

### -TaskName
Specifies the name of the scheduled task to export.
This parameter is mandatory and must match the exact
name of the task as it appears in the Task Scheduler.

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

### -TaskPath
Specifies the path of the scheduled task to export.
The task path represents the folder structure in the
Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\').
If not specified, the
root path ('\') will be used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: \
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputerName
Specifies the name of the computer from which to export the scheduled task.
If not specified, the local
computer ('localhost') is used.
This parameter accepts computer names, IP addresses, or fully qualified
domain names.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Localhost
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Specifies credentials to use when connecting to a remote computer.
If not specified, the current user's
credentials are used for the connection.
This parameter is only relevant when connecting to remote computers.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
Specifies the path to save the exported XML file.
If not specified, the XML is returned as a string
to the pipeline.
If the directory does not exist, it will be created.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
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

### None. You cannot pipe objects to Export-StmScheduledTask.
## OUTPUTS

### System.String
### When FilePath is not specified, returns the XML representation of the scheduled task.
### When FilePath is specified, no output is returned (file is saved).
## NOTES
This function requires:
- Appropriate permissions to query scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- The Task Scheduler service to be running on the target computer
- Write permissions to the destination directory when using FilePath

The function uses CIM sessions internally for remote connections and includes proper error handling with
detailed error messages and recommended actions.

The exported XML follows the Task Scheduler XML schema and can be imported using
Register-StmScheduledTask, Import-StmScheduledTask, or the built-in Register-ScheduledTask cmdlet.

## RELATED LINKS
