---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Import-StmScheduledTask

## SYNOPSIS
Imports scheduled tasks from XML to a local or remote computer.

## SYNTAX

### XmlFile (Default)
```
Import-StmScheduledTask -XmlPath <String> [-TaskName <String>] [-TaskPath <String>] [-ComputerName <String>]
 [-Credential <PSCredential>] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### XmlString
```
Import-StmScheduledTask -Xml <String> [-TaskName <String>] [-TaskPath <String>] [-ComputerName <String>]
 [-Credential <PSCredential>] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### Directory
```
Import-StmScheduledTask -DirectoryPath <String> [-TaskPath <String>] [-ComputerName <String>]
 [-Credential <PSCredential>] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The Import-StmScheduledTask function imports scheduled tasks from XML definitions to a local or
remote computer.
This function supports three modes of operation:

- Single file import: Import a task from a single XML file using the -XmlPath parameter
- XML string import: Import a task from an XML string using the -Xml parameter
- Bulk directory import: Import all XML files from a directory using the -DirectoryPath parameter

The function extracts the task name from the XML's RegistrationInfo/URI element by default, but
allows overriding the task name for single imports using the -TaskName parameter.
When a task
with the same name already exists, the function will error unless the -Force parameter is
specified, which causes the existing task to be unregistered before importing the new one.

For bulk directory imports, the function processes all .xml files in the specified directory,
reports progress, and continues processing even if individual tasks fail to import.
A summary
object is returned with details about successful and failed imports.

## EXAMPLES

### EXAMPLE 1
```
Import-StmScheduledTask -XmlPath 'C:\Tasks\BackupTask.xml'
```

Imports a single scheduled task from an XML file.
The task name is extracted from the XML's
URI element.

### EXAMPLE 2
```
$params = @{
    XmlPath  = 'C:\Tasks\Task.xml'
    TaskName = 'CustomName'
    TaskPath = '\Custom\Tasks\'
}
Import-StmScheduledTask @params
```

Imports a scheduled task from an XML file with a custom name and task path.

### EXAMPLE 3
```
Import-StmScheduledTask -DirectoryPath 'C:\Tasks\' -Force
```

Imports all XML files from the specified directory as scheduled tasks.
The -Force parameter
ensures any existing tasks with the same names are replaced.

### EXAMPLE 4
```
$xml = Get-Content -Path 'C:\Tasks\Task.xml' -Raw
Import-StmScheduledTask -Xml $xml
```

Imports a scheduled task from an XML string variable.

### EXAMPLE 5
```
$credential = Get-Credential
$params = @{
    XmlPath      = 'C:\Tasks\Task.xml'
    ComputerName = 'Server01'
    Credential   = $credential
    Force        = $true
}
Import-StmScheduledTask @params
```

Imports a scheduled task to a remote computer using specified credentials, replacing any
existing task with the same name.

## PARAMETERS

### -XmlPath
Specifies the path to a single XML file containing the scheduled task definition.
The file must
exist and contain valid Task Scheduler XML format.
This parameter is mandatory when using the
XmlFile parameter set.

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

### -Xml
Specifies the XML content defining the scheduled task configuration.
The XML should follow the
Task Scheduler schema format.
This parameter is mandatory when using the XmlString parameter set.

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

### -DirectoryPath
Specifies the path to a directory containing XML files to import.
All files with the .xml
extension in the directory will be processed.
This parameter is mandatory when using the
Directory parameter set.
The -TaskName parameter cannot be used with this parameter.

```yaml
Type: String
Parameter Sets: Directory
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskName
Optionally overrides the task name extracted from the XML's RegistrationInfo/URI element.
This parameter is only applicable to single file or XML string imports and cannot be used
with the -DirectoryPath parameter.

```yaml
Type: String
Parameter Sets: XmlFile, XmlString
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskPath
Specifies the path where the scheduled task will be registered.
The task path represents the
folder structure in the Task Scheduler (e.g., '\Custom\Tasks\').
If not specified, the root
path ('\') will be used.

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

### -ComputerName
Specifies the name of the computer on which to register the scheduled task.
If not specified,
the local computer ('localhost') is used.

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
If not provided, the current
user's credentials will be used for the connection.

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

### -Force
Overwrites existing tasks with the same name.
Without this parameter, an error occurs if a task
with the same name already exists.
When specified, the existing task is unregistered before
importing the new task definition.

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

### None. You cannot pipe objects to Import-StmScheduledTask.
## OUTPUTS

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
### For single file or XML string imports, returns the registered scheduled task object.
### PSCustomObject
### For directory imports, returns a summary object with the following properties:
### - TotalFiles: The total number of XML files found
### - SuccessCount: The number of successfully imported tasks
### - FailureCount: The number of tasks that failed to import
### - ImportedTasks: Array of successfully imported task names
### - FailedTasks: Array of objects describing failed imports (FileName, TaskName, Error)
## NOTES
This function requires:
- Appropriate permissions to register scheduled tasks on the target computer
- Network connectivity to remote computers when using the ComputerName parameter
- Valid Task Scheduler XML format for the task definitions

The XML definitions must follow the Task Scheduler schema and should contain a RegistrationInfo/URI
element for automatic task name extraction.
If the URI element is missing and -TaskName is not
specified, the import will fail.

When importing from a directory, the function uses non-terminating errors for individual task
failures, allowing the import to continue with remaining files.
Check the returned summary object
for details about any failures.

## RELATED LINKS

[Export-StmScheduledTask]()

[Register-StmScheduledTask]()

[Unregister-StmScheduledTask]()

