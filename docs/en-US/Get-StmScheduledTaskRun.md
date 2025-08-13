---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Get-StmScheduledTaskRun

## SYNOPSIS
Retrieves run history for scheduled tasks on a local or remote computer.

## SYNTAX

```
Get-StmScheduledTaskRun [[-TaskName] <String>] [[-TaskPath] <String>] [[-ComputerName] <String>]
 [[-Credential] <PSCredential>] [[-MaxRuns] <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-StmScheduledTaskRun function retrieves information about the execution history of scheduled tasks
from the Windows Task Scheduler.
It queries the Task Scheduler event log to provide details about task runs,
including start and end times, status, and results.
You can filter by task name and target a specific computer.
Optionally, credentials can be supplied for remote queries.

## EXAMPLES

### EXAMPLE 1
```
Get-StmScheduledTaskRun -TaskName "MyTask"
```

Retrieves the run history for the scheduled task named "MyTask" on the local computer.

### EXAMPLE 2
```
Get-StmScheduledTaskRun -ComputerName "Server01"
```

Retrieves the run history for all scheduled tasks on the remote computer "Server01".

### EXAMPLE 3
```
$credentials = Get-Credential
Get-StmScheduledTaskRun -TaskName "BackupTask" -ComputerName "Server02" -Credential $credentials
```

Retrieves the run history for the "BackupTask" scheduled task on "Server02" using the specified credentials.

### EXAMPLE 4
```
Get-StmScheduledTaskRun -TaskName "MyTask" -MaxRuns 5
```

Retrieves the 5 most recent runs for the scheduled task named "MyTask" on the local computer.

## PARAMETERS

### -TaskName
The name of the scheduled task to retrieve run history for.
If not specified, retrieves run history for all tasks.

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
The path of the scheduled task(s) to retrieve run history for.
Matches the TaskPath parameter of Get-ScheduledTask.
If not specified, all task paths are considered.

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

### -ComputerName
The name of the computer to query.
If not specified, the local computer is used.

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
The credentials to use when connecting to the remote computer.
If not specified, the current user's credentials are used.

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

### -MaxRuns
The maximum number of task runs to return per task.
If not specified, all available runs are returned.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 0
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

### None. You cannot pipe objects to Get-StmScheduledTaskRun.
## OUTPUTS

### PSCustomObject
### Returns objects containing details about each scheduled task run, including task name, start time, end time, status, and result.
## NOTES
This function requires access to the Microsoft-Windows-TaskScheduler/Operational event log on the target computer.
Remote queries require appropriate permissions and network connectivity.

## RELATED LINKS
