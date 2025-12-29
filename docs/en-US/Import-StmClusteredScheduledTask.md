---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Import-StmClusteredScheduledTask

## SYNOPSIS
Imports clustered scheduled tasks from XML to a Windows failover cluster.

## SYNTAX

### XmlFile (Default)
```
Import-StmClusteredScheduledTask -Path <String> -Cluster <String> -TaskType <ClusterTaskTypeEnum>
 [-TaskName <String>] [-Credential <PSCredential>] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### XmlString
```
Import-StmClusteredScheduledTask -Xml <String> -Cluster <String> -TaskType <ClusterTaskTypeEnum>
 [-TaskName <String>] [-Credential <PSCredential>] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### Directory
```
Import-StmClusteredScheduledTask -DirectoryPath <String> -Cluster <String> -TaskType <ClusterTaskTypeEnum>
 [-Credential <PSCredential>] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The Import-StmClusteredScheduledTask function imports clustered scheduled tasks from XML definitions
to a Windows failover cluster.
This function supports three modes of operation:

- Single file import: Import a task from a single XML file using the -Path parameter
- XML string import: Import a task from an XML string using the -Xml parameter
- Bulk directory import: Import all XML files from a directory using the -DirectoryPath parameter

The function extracts the task name from the XML's RegistrationInfo/URI element by default, but allows
overriding the task name for single imports using the -TaskName parameter.
When a task with the same
name already exists, the function will error unless the -Force parameter is specified, which causes
the existing task to be unregistered before importing the new one.

For bulk directory imports, the function processes all .xml files in the specified directory, reports
progress, and continues processing even if individual tasks fail to import.
A summary object is
returned with details about successful and failed imports.

## EXAMPLES

### EXAMPLE 1
```
Import-StmClusteredScheduledTask -Path 'C:\Tasks\BackupTask.xml' -Cluster 'MyCluster' -TaskType 'AnyNode'
```

Imports a single clustered scheduled task from an XML file.
The task name is extracted from the XML's
URI element.

### EXAMPLE 2
```
Import-StmClusteredScheduledTask -Path 'C:\Tasks\Task.xml' -Cluster 'MyCluster' -TaskType 'AnyNode' -TaskName 'CustomName'
```

Imports a clustered scheduled task from an XML file, overriding the task name with 'CustomName'.

### EXAMPLE 3
```
Import-StmClusteredScheduledTask -DirectoryPath 'C:\Tasks\' -Cluster 'MyCluster' -TaskType 'ClusterWide' -Force
```

Imports all XML files from the specified directory as clustered scheduled tasks.
The -Force parameter
ensures any existing tasks with the same names are replaced.

### EXAMPLE 4
```
$xml = Get-Content -Path 'C:\Tasks\Task.xml' -Raw
Import-StmClusteredScheduledTask -Xml $xml -Cluster 'MyCluster' -TaskType 'AnyNode'
```

Imports a clustered scheduled task from an XML string variable.

### EXAMPLE 5
```
$credential = Get-Credential
Import-StmClusteredScheduledTask -Path 'C:\Tasks\Task.xml' -Cluster 'MyCluster.contoso.com' -TaskType 'ResourceSpecific' -Credential $credential -Force
```

Imports a clustered scheduled task using specified credentials, replacing any existing task with the
same name.

## PARAMETERS

### -Path
Specifies the path to a single XML file containing the scheduled task definition.
The file must exist
and contain valid Task Scheduler XML format.
This parameter is mandatory when using the XmlFile
parameter set.

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
The XML should follow the Task
Scheduler schema format.
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
All files with the .xml extension
in the directory will be processed.
This parameter is mandatory when using the Directory parameter
set.
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

### -Cluster
Specifies the name or FQDN of the cluster where the tasks will be registered.
This parameter is
mandatory for all parameter sets.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskType
Specifies the type of clustered scheduled task to register.
Valid values are:
- ResourceSpecific: Task runs on a specific cluster resource
- AnyNode: Task can run on any node in the cluster
- ClusterWide: Task runs across the entire cluster
This parameter is mandatory for all parameter sets.

```yaml
Type: ClusterTaskTypeEnum
Parameter Sets: (All)
Aliases:
Accepted values: ResourceSpecific, AnyNode, ClusterWide

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TaskName
Optionally overrides the task name extracted from the XML's RegistrationInfo/URI element.
This
parameter is only applicable to single file or XML string imports and cannot be used with the
-DirectoryPath parameter.

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

### -Credential
Specifies credentials to use when connecting to the cluster.
If not provided, the current user's
credentials will be used for the connection.

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
with the same name already exists on the cluster.
When specified, the existing task is unregistered
before importing the new task definition.

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

### None. You cannot pipe objects to Import-StmClusteredScheduledTask.
## OUTPUTS

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ClusteredScheduledTask
### For single file or XML string imports, returns the registered clustered scheduled task object.
### PSCustomObject
### For directory imports, returns a summary object with the following properties:
### - TotalFiles: The total number of XML files found
### - SuccessCount: The number of successfully imported tasks
### - FailureCount: The number of tasks that failed to import
### - ImportedTasks: Array of successfully imported task names
### - FailedTasks: Array of objects describing failed imports (FileName, TaskName, Error)
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to register clustered scheduled tasks
- Network connectivity to the cluster
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

[Export-StmClusteredScheduledTask]()

[Register-StmClusteredScheduledTask]()

[Unregister-StmClusteredScheduledTask]()

[Get-StmClusteredScheduledTask]()

