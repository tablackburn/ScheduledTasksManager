---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Wait-StmScheduledTask

## SYNOPSIS
Waits for a scheduled task to complete running on a local or remote computer.

## SYNTAX

```
Wait-StmScheduledTask [-TaskName] <String> [[-TaskPath] <String>] [[-ComputerName] <String>]
 [[-Credential] <PSCredential>] [[-PollingIntervalSeconds] <Int32>] [[-TimeoutSeconds] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Wait-StmScheduledTask function polls a scheduled task on a local or remote computer and waits until
the task is no longer in the 'Running' state or until a timeout is reached.

The function performs the following operations:
1.
Connects to the specified computer using credentials if provided
2.
Polls the task state at regular intervals
3.
Returns $true if the task completes, $false if timeout is reached
4.
Provides detailed verbose output for troubleshooting

This function is useful for synchronizing scripts that need to wait for a scheduled task to complete
before continuing.

## EXAMPLES

### EXAMPLE 1
```
Wait-StmScheduledTask -TaskName "MyBackupTask"
```

Waits for the scheduled task named "MyBackupTask" to complete on the local computer with default timeout.

### EXAMPLE 2
```
Wait-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\" -TimeoutSeconds 600
```

Waits up to 10 minutes for the task named "MaintenanceTask" located in the "\Custom\Maintenance\" path.

### EXAMPLE 3
```
Wait-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01" -PollingIntervalSeconds 10
```

Waits for the task on a remote computer, checking every 10 seconds.

### EXAMPLE 4
```
Start-StmScheduledTask -TaskName "LongRunningTask"
$completed = Wait-StmScheduledTask -TaskName "LongRunningTask" -TimeoutSeconds 1800
if (-not $completed) {
    Write-Warning "Task did not complete within 30 minutes"
}
```

Starts a task and waits up to 30 minutes for it to complete.

## PARAMETERS

### -TaskName
Specifies the name of the scheduled task to wait for.
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
Specifies the path of the scheduled task to wait for.
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
Specifies the name of the computer on which the scheduled task is running.
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

### -PollingIntervalSeconds
Specifies the number of seconds to wait between polling attempts.
Default is 5 seconds.
The minimum value
is 1 second.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSeconds
Specifies the maximum number of seconds to wait for the task to complete.
Default is 300 seconds (5 minutes).
If the task does not complete within this time, the function returns $false.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 300
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

### None. You cannot pipe objects to Wait-StmScheduledTask.
## OUTPUTS

### System.Boolean
### Returns $true if the task completed (is no longer running), or $false if the timeout was reached.
## NOTES
This function requires:
- Appropriate permissions to query scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- The Task Scheduler service to be running on the target computer

The function uses CIM sessions internally for remote connections and includes proper error handling with
detailed error messages and recommended actions.

If the task is not running when this function is called, it will immediately return $true.

## RELATED LINKS
