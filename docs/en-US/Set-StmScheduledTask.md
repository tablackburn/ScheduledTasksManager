---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Set-StmScheduledTask

## SYNOPSIS
Modifies a scheduled task on a local or remote computer.

## SYNTAX

### ByName (Default)
```
Set-StmScheduledTask [-TaskName] <String> [[-TaskPath] <String>] [[-Action] <CimInstance[]>]
 [[-Trigger] <CimInstance[]>] [[-Settings] <CimInstance>] [[-Principal] <CimInstance>] [[-User] <String>]
 [[-Password] <String>] [[-ComputerName] <String>] [[-Credential] <PSCredential>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByInputObject
```
Set-StmScheduledTask [-InputObject] <CimInstance> [[-Action] <CimInstance[]>] [[-Trigger] <CimInstance[]>]
 [[-Settings] <CimInstance>] [[-Principal] <CimInstance>] [[-User] <String>] [[-Password] <String>]
 [[-Credential] <PSCredential>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The Set-StmScheduledTask function modifies the properties of a scheduled task on a local or remote computer
using the Windows Task Scheduler. This function wraps the built-in Set-ScheduledTask cmdlet to provide
credential support and enhanced error handling across the ScheduledTasksManager module.

The function can modify the following task properties:
- Actions: The commands or programs the task executes
- Triggers: The schedules that determine when the task runs
- Settings: Task configuration options like run behavior and power management
- Principal: The security context under which the task runs

At least one modification parameter (Action, Trigger, Settings, Principal, User, or Password) must be
specified. The function supports both direct task identification via TaskName/TaskPath and pipeline input
from Get-StmScheduledTask.

This function requires appropriate permissions to manage scheduled tasks on the target computer.

## EXAMPLES

### EXAMPLE 1
```
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File C:\Scripts\Backup.ps1'
Set-StmScheduledTask -TaskName 'MyBackupTask' -Action $action
```

Modifies the action of the scheduled task named "MyBackupTask" to run a different PowerShell script.

### EXAMPLE 2
```
$trigger = New-ScheduledTaskTrigger -Daily -At '3:00 AM'
Set-StmScheduledTask -TaskName 'MaintenanceTask' -TaskPath '\Custom\Maintenance\' -Trigger $trigger
```

Modifies the trigger of the scheduled task named "MaintenanceTask" in the specified path to run daily
at 3:00 AM.

### EXAMPLE 3
```
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -WakeToRun
Set-StmScheduledTask -TaskName 'SyncTask' -Settings $settings -ComputerName 'Server01'
```

Modifies the settings of the scheduled task named "SyncTask" on Server01 to only run when the network
is available and to wake the computer if needed.

### EXAMPLE 4
```
Get-StmScheduledTask -TaskName 'ReportTask' | Set-StmScheduledTask -User 'DOMAIN\ServiceAccount' -Password 'P@ssw0rd'
```

Uses pipeline input to modify the user account under which the task runs.

### EXAMPLE 5
```
$action = New-ScheduledTaskAction -Execute 'notepad.exe'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)
Set-StmScheduledTask -TaskName 'TestTask' -Action $action -Trigger $trigger -PassThru
```

Modifies both the action and trigger of a task and returns the modified task object.

### EXAMPLE 6
```
$cred = Get-Credential
Set-StmScheduledTask -TaskName 'RemoteTask' -ComputerName 'Server02' -Credential $cred -User 'LocalAdmin' -Password 'Secret123'
```

Modifies a task on a remote server using specified credentials for the connection, and changes the
user account that the task runs under.

## PARAMETERS

### -TaskName
Specifies the name of the scheduled task to modify. This parameter is mandatory when using the ByName
parameter set and must match the exact name of the task as it appears in the Task Scheduler.

```yaml
Type: String
Parameter Sets: ByName
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -TaskPath
Specifies the path of the scheduled task to modify. The task path represents the folder structure in the
Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
root path ('\') will be used.

```yaml
Type: String
Parameter Sets: ByName
Aliases:

Required: False
Position: 2
Default value: \
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -InputObject
Specifies a scheduled task object to modify. This parameter accepts pipeline input from Get-StmScheduledTask
or Get-ScheduledTask. When using this parameter, the TaskName and TaskPath are extracted from the object.

```yaml
Type: CimInstance
Parameter Sets: ByInputObject
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Action
Specifies an array of action objects that define what the task executes. Use New-ScheduledTaskAction to
create action objects. When specified, this replaces all existing actions on the task.

```yaml
Type: CimInstance[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Trigger
Specifies an array of trigger objects that define when the task runs. Use New-ScheduledTaskTrigger to
create trigger objects. When specified, this replaces all existing triggers on the task.

```yaml
Type: CimInstance[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Settings
Specifies a settings object that defines task behavior. Use New-ScheduledTaskSettingsSet to create a
settings object. When specified, this replaces the existing task settings.

```yaml
Type: CimInstance
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Principal
Specifies a principal object that defines the security context for the task. Use New-ScheduledTaskPrincipal
to create a principal object. This parameter cannot be used together with User or Password parameters.

```yaml
Type: CimInstance
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -User
Specifies the user account under which the task runs. This is an alternative to using the Principal
parameter. Cannot be used together with the Principal parameter.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
Specifies the password for the user account specified by the User parameter. This is an alternative to
using the Principal parameter. Cannot be used together with the Principal parameter.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputerName
Specifies the name of the computer on which to modify the scheduled task. If not specified, the local
computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
domain names. This parameter is only available when using the ByName parameter set.

```yaml
Type: String
Parameter Sets: ByName
Aliases:

Required: False
Position: Named
Default value: localhost
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
credentials are used for the connection. This parameter is relevant when connecting to remote computers
or when the task requires credentials for the CIM session.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns an object representing the modified scheduled task. By default, this cmdlet does not generate any
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
Shows what would happen if the cmdlet runs. The cmdlet is not run.

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

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
### You can pipe a scheduled task object from Get-StmScheduledTask or Get-ScheduledTask to this cmdlet.

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

At least one modification parameter (Action, Trigger, Settings, Principal, User, or Password) must be
specified. The Principal parameter cannot be combined with User or Password parameters.

The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.

## RELATED LINKS

[Get-StmScheduledTask](Get-StmScheduledTask.md)

[New-ScheduledTaskAction](https://docs.microsoft.com/powershell/module/scheduledtasks/new-scheduledtaskaction)

[New-ScheduledTaskTrigger](https://docs.microsoft.com/powershell/module/scheduledtasks/new-scheduledtasktrigger)

[New-ScheduledTaskSettingsSet](https://docs.microsoft.com/powershell/module/scheduledtasks/new-scheduledtasksettingsset)

[New-ScheduledTaskPrincipal](https://docs.microsoft.com/powershell/module/scheduledtasks/new-scheduledtaskprincipal)
