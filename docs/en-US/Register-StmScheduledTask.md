---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Register-StmScheduledTask

## SYNOPSIS
Registers a scheduled task from XML on a local or remote computer.

## SYNTAX

### XmlString (Default)
```
Register-StmScheduledTask [-TaskName <String>] [-TaskPath <String>] -Xml <String> [-ComputerName <String>]
 [-Credential <PSCredential>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### XmlFile
```
Register-StmScheduledTask [-TaskName <String>] [-TaskPath <String>] -XmlPath <String> [-ComputerName <String>]
 [-Credential <PSCredential>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Register-StmScheduledTask function registers a new scheduled task on a local or remote computer
using XML configuration.
The XML can be provided as a string or loaded from a file.
This function wraps the built-in Register-ScheduledTask cmdlet to provide credential support
and enhanced error handling across the ScheduledTasksManager module.

The function performs the following operations:
1.
Connects to the specified computer using credentials if provided
2.
Loads the XML configuration from string or file
3.
Registers the scheduled task with the specified configuration
4.
Returns the registered task object

This function requires appropriate permissions to manage scheduled tasks on the target computer.

## EXAMPLES

### EXAMPLE 1
```
$xml = Export-StmScheduledTask -TaskName "ExistingTask"
Register-StmScheduledTask -TaskName "NewTask" -Xml $xml
```

Exports an existing task and registers a copy with a new name.

### EXAMPLE 2
```
Register-StmScheduledTask -XmlPath "C:\Backups\MyTask.xml"
```

Registers a scheduled task from an XML file, using the task name from the XML.

### EXAMPLE 3
```
Register-StmScheduledTask -TaskName "CustomTask" -TaskPath "\Custom\Tasks\" -XmlPath ".\task.xml"
```

Registers a task with a custom name and path from an XML file.

### EXAMPLE 4
```
Register-StmScheduledTask -XmlPath "C:\Tasks\backup.xml" -ComputerName "Server01"
```

Registers a task on a remote computer from an XML file.

### EXAMPLE 5
```
Register-StmScheduledTask -TaskName "NewTask" -Xml $xml -WhatIf
```

Shows what would happen if the task were registered without actually performing the operation.

## PARAMETERS

### -TaskName
Specifies the name for the scheduled task.
If not specified, the task name is extracted from
the XML's RegistrationInfo/URI element.

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

### -TaskPath
Specifies the path where the scheduled task will be registered.
The task path represents the folder
structure in the Task Scheduler (e.g., '\Custom\Tasks\').
If not specified, the root path ('\')
will be used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: \
Accept pipeline input: False
Accept wildcard characters: False
```

### -Xml
Specifies the XML configuration for the scheduled task as a string.
This parameter is used
in the 'XmlString' parameter set.

```yaml
Type: String
Parameter Sets: XmlString
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -XmlPath
Specifies the path to an XML file containing the scheduled task configuration.
This parameter
is used in the 'XmlFile' parameter set.

```yaml
Type: String
Parameter Sets: XmlFile
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputerName
Specifies the name of the computer on which to register the scheduled task.
If not specified,
the local computer ('localhost') is used.
This parameter accepts computer names, IP addresses,
or fully qualified domain names.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Localhost
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Specifies credentials to use when connecting to a remote computer.
If not specified, the current
user's credentials are used for the connection.

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

### None. You cannot pipe objects to Register-StmScheduledTask.
## OUTPUTS

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
### Returns the registered scheduled task object.
## NOTES
This function requires:
- Appropriate permissions to manage scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- The Task Scheduler service to be running on the target computer
- Valid Task Scheduler XML following the schema

The function uses CIM sessions internally for remote connections and includes proper error handling
with detailed error messages and recommended actions.

The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.

If a task with the same name already exists at the specified path, an error will be thrown.
Use Import-StmScheduledTask with the -Force parameter to overwrite existing tasks.

## RELATED LINKS
