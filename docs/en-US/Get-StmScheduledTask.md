---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Get-StmScheduledTask

## SYNOPSIS
Retrieves scheduled tasks from a local or remote computer.

## SYNTAX

```
Get-StmScheduledTask [[-TaskName] <String>] [[-TaskPath] <String>] [[-TaskState] <StateEnum>]
 [[-ComputerName] <String>] [[-Credential] <PSCredential>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The Get-StmScheduledTask function retrieves scheduled tasks from the Windows Task Scheduler on a local or
remote computer.
You can filter tasks by name, path, and state, and optionally specify credentials for
remote connections.
This function wraps the built-in Get-ScheduledTask cmdlet to provide credential support
across the ScheduledTasksManager module.

## EXAMPLES

### EXAMPLE 1
```
Get-StmScheduledTask
```

Retrieves all scheduled tasks from the local computer.

### EXAMPLE 2
```
Get-StmScheduledTask -TaskName "MyBackupTask"
```

Retrieves the specific scheduled task named "MyBackupTask" from the local computer.

### EXAMPLE 3
```
Get-StmScheduledTask -TaskPath "\Microsoft\Windows\PowerShell\"
```

Retrieves all scheduled tasks located in the PowerShell folder from the local computer.

### EXAMPLE 4
```
Get-StmScheduledTask -TaskState "Ready"
```

Retrieves all scheduled tasks that are in the "Ready" state from the local computer.

### EXAMPLE 5
```
Get-StmScheduledTask -ComputerName "Server01"
```

Retrieves all scheduled tasks from the remote computer "Server01" using the current user's credentials.

### EXAMPLE 6
```
$credentials = Get-Credential
Get-StmScheduledTask -TaskName "Maintenance*" -ComputerName "Server02" -Credential $credentials
```

Retrieves all scheduled tasks that start with "Maintenance" from the remote computer "Server02" using the
specified credentials.

### EXAMPLE 7
```
Get-StmScheduledTask -TaskName "DatabaseBackup" -TaskPath "\Custom\Database\" -ComputerName "DBServer"
```

Retrieves the "DatabaseBackup" task from the "\Custom\Database\" path on the remote computer "DBServer".

### EXAMPLE 8
```
Get-StmScheduledTask -TaskState "Running" -ComputerName "Server01"
```

Retrieves all running scheduled tasks from the remote computer "Server01".

## PARAMETERS

### -TaskName
Specifies the name of a specific scheduled task to retrieve.
If not specified, all scheduled tasks will be
returned.
This parameter is optional and supports wildcards.

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

### -TaskPath
Specifies the path of the scheduled task(s) to retrieve.
The task path represents the folder structure in the
Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\').
If not specified, tasks
from all paths will be returned.
This parameter is optional and supports wildcards.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskState
Specifies the state of the scheduled task(s) to retrieve.
Valid values are: Unknown, Disabled, Queued, Ready,
and Running.
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

### -ComputerName
Specifies the name of the computer from which to retrieve scheduled tasks.
If not specified, the local
computer ('localhost') is used.
This parameter accepts computer names, IP addresses, or fully qualified
domain names.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
Position: 5
Default value: [System.Management.Automation.PSCredential]::Empty
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

### None. You cannot pipe objects to Get-StmScheduledTask.
## OUTPUTS

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
### Returns ScheduledTask objects that represent the scheduled tasks on the specified computer.
## NOTES
This function requires:
- Appropriate permissions to access scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- The Task Scheduler service to be running on the target computer

The function uses CIM sessions internally for remote connections and includes proper error handling with
detailed error messages and recommended actions.

## RELATED LINKS
