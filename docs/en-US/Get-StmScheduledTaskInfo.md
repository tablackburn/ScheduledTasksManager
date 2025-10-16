---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Get-StmScheduledTaskInfo

## SYNOPSIS
Retrieves detailed information about scheduled tasks from a local or remote computer.

## SYNTAX

### ByParameters (Default)
```
Get-StmScheduledTaskInfo [-TaskName <String>] [-TaskPath <String>] [-TaskState <StateEnum>]
 [-ComputerName <String>] [-Credential <PSCredential>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ByInputObject
```
Get-StmScheduledTaskInfo -InputObject <PSObject[]> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-StmScheduledTaskInfo function retrieves comprehensive information about scheduled tasks from the
Windows Task Scheduler on a local or remote computer.
This function wraps Get-ScheduledTaskInfo to provide
additional details such as last run time, next run time, last task result, number of missed runs, and other
operational details.
You can filter tasks by name, path, and state, and optionally specify credentials for
remote connections.

## EXAMPLES

### EXAMPLE 1
```
Get-StmScheduledTaskInfo
```

Retrieves detailed information for all scheduled tasks from the local computer.

### EXAMPLE 2
```
Get-StmScheduledTaskInfo -TaskName "MyBackupTask"
```

Retrieves detailed information for the specific scheduled task named "MyBackupTask" from the local computer.

### EXAMPLE 3
```
Get-StmScheduledTask -TaskName "MyBackupTask" | Get-StmScheduledTaskInfo
```

Retrieves the scheduled task "MyBackupTask" and pipes it to Get-StmScheduledTaskInfo to get detailed
information.

### EXAMPLE 4
```
Get-StmScheduledTaskInfo -TaskPath "\Microsoft\Windows\PowerShell\"
```

Retrieves detailed information for all scheduled tasks located in the PowerShell folder from the local
computer.

### EXAMPLE 5
```
Get-StmScheduledTaskInfo -TaskState "Ready" -ComputerName "Server01"
```

Retrieves detailed information for all scheduled tasks that are in the "Ready" state from the remote
computer "Server01".

### EXAMPLE 6
```
$credentials = Get-Credential
Get-StmScheduledTaskInfo -TaskName "Maintenance*" -ComputerName "Server02" -Credential $credentials
```

Retrieves detailed information for all scheduled tasks that start with "Maintenance" from the remote
computer "Server02" using the specified credentials.

### EXAMPLE 7
```
Get-StmScheduledTask -TaskState "Running" | Get-StmScheduledTaskInfo |
    Select-Object TaskName, LastRunTime, RunningDuration
```

Retrieves all running scheduled tasks and displays their names, last run times, and how long they have been
running.

## PARAMETERS

### -TaskName
Specifies the name of a specific scheduled task to retrieve information for.
If not specified, information
for all scheduled tasks will be returned.
This parameter is optional and supports wildcards.

```yaml
Type: String
Parameter Sets: ByParameters
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskPath
Specifies the path of the scheduled task(s) to retrieve information for.
The task path represents the folder
structure in the Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\').
If not
specified, tasks from all paths will be returned.
This parameter is optional and supports wildcards.

```yaml
Type: String
Parameter Sets: ByParameters
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskState
Specifies the state of the scheduled task(s) to retrieve information for.
Valid values are: Unknown,
Disabled, Queued, Ready, and Running.
If not specified, tasks in all states will be returned.
This parameter
is optional.

```yaml
Type: StateEnum
Parameter Sets: ByParameters
Aliases:
Accepted values: Unknown, Disabled, Queued, Ready, Running

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputerName
Specifies the name of the computer from which to retrieve scheduled task information.
If not specified, the
local computer ('localhost') is used.
This parameter accepts computer names, IP addresses, or fully qualified
domain names.

```yaml
Type: String
Parameter Sets: ByParameters
Aliases:

Required: False
Position: Named
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
Parameter Sets: ByParameters
Aliases:

Required: False
Position: Named
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
Specifies one or more ScheduledTask objects from which to retrieve detailed information.
This parameter
accepts pipeline input from Get-StmScheduledTask or Get-ScheduledTask.

```yaml
Type: PSObject[]
Parameter Sets: ByInputObject
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
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

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
### You can pipe ScheduledTask objects to Get-StmScheduledTaskInfo.
## OUTPUTS

### PSCustomObject
### Returns custom objects containing merged information from both scheduled task and scheduled task info objects:
### - TaskName: The name of the scheduled task
### - TaskPath: The path of the task in Task Scheduler
### - TaskState: The current state of the task
### - LastRunTime: The last time the task was executed
### - LastTaskResult: The result of the last task execution
### - NextRunTime: The next scheduled run time
### - NumberOfMissedRuns: The number of times the task failed to run
### - RunningDuration: TimeSpan showing how long the task has been running (null if not running)
### - ScheduledTaskObject: The underlying scheduled task object
### - ScheduledTaskInfoObject: The underlying scheduled task info object
## NOTES
This function requires:
- Appropriate permissions to access scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- The Task Scheduler service to be running on the target computer

The function uses Get-StmScheduledTask internally to retrieve the task and then calls Get-ScheduledTaskInfo
to get detailed execution information.

## RELATED LINKS
