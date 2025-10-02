---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Disable-StmScheduledTask

## SYNOPSIS
Disables a scheduled task on a local or remote computer.

## SYNTAX

```
Disable-StmScheduledTask [-TaskName] <String> [[-TaskPath] <String>] [[-ComputerName] <String>]
 [[-Credential] <PSCredential>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The Disable-StmScheduledTask function disables a scheduled task on a local or remote computer using the
Windows Task Scheduler.
This function wraps the built-in Disable-ScheduledTask cmdlet to provide credential
support and enhanced error handling across the ScheduledTasksManager module.

The function performs the following operations:
1.
Connects to the specified computer using credentials if provided
2.
Disables the specified scheduled task
3.
Verifies that the task has been successfully disabled
4.
Provides detailed verbose output for troubleshooting

This function requires appropriate permissions to manage scheduled tasks on the target computer.

## EXAMPLES

### EXAMPLE 1
```
Disable-StmScheduledTask -TaskName "MyBackupTask"
```

Disables the scheduled task named "MyBackupTask" on the local computer.

### EXAMPLE 2
```
Disable-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\"
```

Disables the scheduled task named "MaintenanceTask" located in the "\Custom\Maintenance\" path on the
local computer.

### EXAMPLE 3
```
Disable-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01"
```

Disables the scheduled task named "DatabaseBackup" on the remote computer "Server01" using the current
user's credentials.

### EXAMPLE 4
```
$credentials = Get-Credential
Disable-StmScheduledTask -TaskName "ReportGeneration" -ComputerName "Server02" -Credential $credentials
```

Disables the scheduled task named "ReportGeneration" on the remote computer "Server02" using the specified
credentials.

### EXAMPLE 5
```
Disable-StmScheduledTask -TaskName "TestTask" -PassThru
```

Disables the scheduled task named "TestTask" on the local computer and returns the task object.

### EXAMPLE 6
```
Disable-StmScheduledTask -TaskName "CriticalTask" -WhatIf
```

Shows what would happen if the cmdlet runs without actually performing the operation.
This is useful for
testing the command before execution.

## PARAMETERS

### -TaskName
Specifies the name of the scheduled task to disable.
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
Specifies the path of the scheduled task to disable.
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
Specifies the name of the computer on which to disable the scheduled task.
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

### -PassThru
Returns an object representing the disabled scheduled task.
By default, this cmdlet does not generate any
output.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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

### None. You cannot pipe objects to Disable-StmScheduledTask.
## OUTPUTS

### None or Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
### When you use the PassThru parameter, this cmdlet returns a ScheduledTask object. Otherwise, this cmdlet
### does not generate any output.
## NOTES
This function requires:
- Appropriate permissions to manage scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- The Task Scheduler service to be running on the target computer

The function uses CIM sessions internally for remote connections and includes proper error handling with
detailed error messages and recommended actions.

This operation can be reversed by using the Enable-ScheduledTask cmdlet or the corresponding
Enable-StmScheduledTask function if available.

The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.

## RELATED LINKS
