---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Register-StmClusteredScheduledTask

## SYNOPSIS
Registers a new clustered scheduled task on a Windows failover cluster.

## SYNTAX

### XmlString (Default)
```
Register-StmClusteredScheduledTask -TaskName <String> -Cluster <String> -Xml <String>
 -TaskType <ClusterTaskTypeEnum> [-Credential <PSCredential>] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### XmlFile
```
Register-StmClusteredScheduledTask -TaskName <String> -Cluster <String> -XmlPath <String>
 -TaskType <ClusterTaskTypeEnum> [-Credential <PSCredential>] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Register-StmClusteredScheduledTask function registers a new clustered scheduled task on a Windows failover cluster
using an XML definition.
This function supports two parameter sets: one for providing the XML content as a string
and another for providing the path to an XML file.
The function creates a CIM session to the cluster and registers
the task using the native Register-ClusteredScheduledTask cmdlet.
Clustered scheduled tasks can be configured to run
on specific nodes, any node, or across the entire cluster depending on the task type specified.

## EXAMPLES

### EXAMPLE 1
```
$xmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Triggers>
        <TimeTrigger>
            <Repetition>
                <Interval>PT1H</Interval>
                <StopAtDurationEnd>false</StopAtDurationEnd>
            </Repetition>
            <Enabled>true</Enabled>
        </TimeTrigger>
    </Triggers>
    <Principals>
        <Principal id="Author">
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Settings>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
        <AllowHardTerminate>true</AllowHardTerminate>
        <StartWhenAvailable>false</StartWhenAvailable>
        <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
        <IdleSettings>
            <StopOnIdleEnd>true</StopOnIdleEnd>
            <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <Enabled>true</Enabled>
        <Hidden>false</Hidden>
        <RunOnlyIfIdle>false</RunOnlyIfIdle>
        <WakeToRun>false</WakeToRun>
        <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
        <Priority>7</Priority>
    </Settings>
    <Actions Context="Author">
        <Exec>
            <Command>powershell.exe</Command>
            <Arguments>-Command "Write-Host 'Hello from clustered task'</Arguments>
        </Exec>
    </Actions>
</Task>
"@
Register-StmClusteredScheduledTask -TaskName "MyClusteredTask" -Cluster "MyCluster" -Xml $xmlContent -TaskType "AnyNode"
```

Registers a new clustered scheduled task named "MyClusteredTask" on cluster "MyCluster" using XML content provided as a string.
The task is configured to run on any node in the cluster.

### EXAMPLE 2
```
Register-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster.contoso.com" -XmlPath "C:\Tasks\BackupTask.xml" -TaskType "ClusterWide"
```

Registers a new clustered scheduled task named "BackupTask" on cluster "MyCluster.contoso.com" using an XML file.
The task is configured to run cluster-wide.

### EXAMPLE 3
```
$creds = Get-Credential
Register-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "MyCluster" -XmlPath "C:\Tasks\MaintenanceTask.xml" -TaskType "ResourceSpecific" -Credential $creds
```

Registers a new clustered scheduled task named "MaintenanceTask" on cluster "MyCluster" using specified credentials.
The task is configured as resource-specific.

## PARAMETERS

### -TaskName
Specifies the name for the new clustered scheduled task.
This parameter is mandatory.

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

### -Cluster
Specifies the name or FQDN of the cluster where the scheduled task will be registered.
This parameter is mandatory.

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

### -Xml
Specifies the XML content that defines the scheduled task configuration.
This parameter is mandatory when using
the XmlString parameter set.
The XML should follow the Task Scheduler schema format.

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
Specifies the path to an XML file that contains the scheduled task configuration.
This parameter is mandatory when
using the XmlFile parameter set.
The file should contain valid Task Scheduler XML format.

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

### -TaskType
Specifies the type of clustered scheduled task to register.
Valid values are:
- ResourceSpecific: Task runs on a specific cluster resource
- AnyNode: Task can run on any node in the cluster
- ClusterWide: Task runs across the entire cluster
This parameter is mandatory.

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

### -Credential
Specifies credentials to use when connecting to the cluster.
If not provided, the current user's credentials
will be used for the connection.

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

### None. You cannot pipe objects to Register-StmClusteredScheduledTask.
## OUTPUTS

### Microsoft.Management.Infrastructure.CimInstance#MSFT_ClusteredScheduledTask
### Returns the registered clustered scheduled task object containing:
### - TaskName: The name of the registered task
### - TaskType: The type of clustered task
### - CurrentOwner: The current owner node
### - State: The current state of the task
### - Cluster: The cluster where the task is registered
## NOTES
This function requires:
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to register clustered scheduled tasks
- Network connectivity to the cluster
- Valid Task Scheduler XML format for the task definition

The XML definition must follow the Task Scheduler schema and include all required elements such as triggers,
principals, settings, and actions.
The function validates the XML format before attempting to register the task.

Different task types have different behaviors:
- ResourceSpecific: Task is tied to a specific cluster resource
- AnyNode: Task can run on any available node
- ClusterWide: Task runs across the entire cluster infrastructure

## RELATED LINKS
