---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Set-StmClusteredScheduledTask

## SYNOPSIS
Modifies a clustered scheduled task in a Windows failover cluster.

## SYNTAX

### ByName (Default)
```
Set-StmClusteredScheduledTask [-TaskName] <String> [-Cluster] <String> [[-Action] <CimInstance[]>]
 [[-Trigger] <CimInstance[]>] [[-Settings] <CimInstance>] [[-Principal] <CimInstance>] [[-User] <String>]
 [[-Password] <String>] [[-TaskType] <ClusterTaskTypeEnum>] [[-Credential] <PSCredential>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByInputObject
```
Set-StmClusteredScheduledTask [-InputObject] <CimInstance> [-Cluster] <String> [[-Action] <CimInstance[]>]
 [[-Trigger] <CimInstance[]>] [[-Settings] <CimInstance>] [[-Principal] <CimInstance>] [[-User] <String>]
 [[-Password] <String>] [[-TaskType] <ClusterTaskTypeEnum>] [[-Credential] <PSCredential>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Set-StmClusteredScheduledTask function modifies the properties of a clustered scheduled task
in a Windows failover cluster. Since there is no native Set-ClusteredScheduledTask cmdlet, this
function exports the current task configuration, modifies it, and re-registers the task.

The function can modify the following task properties:
- Actions: The commands or programs the task executes
- Triggers: The schedules that determine when the task runs
- Settings: Task configuration options like run behavior and power management
- Principal: The security context under which the task runs
- TaskType: The cluster task type (ResourceSpecific, AnyNode, ClusterWide)

The function performs the following operations:
1. Exports the current task configuration using Export-StmClusteredScheduledTask
2. Modifies the XML configuration based on provided parameters
3. Retrieves the original task type if not specified
4. Unregisters the current task
5. Re-registers the task with the modified configuration

At least one modification parameter (Action, Trigger, Settings, Principal, User, Password, or
TaskType) must be specified.

This function requires appropriate permissions to manage clustered scheduled tasks.

## EXAMPLES

### EXAMPLE 1
```
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File C:\Scripts\Backup.ps1'
Set-StmClusteredScheduledTask -TaskName 'ClusterBackup' -Cluster 'MyCluster' -Action $action
```

Modifies the action of the clustered scheduled task named "ClusterBackup" to run a different
PowerShell script.

### EXAMPLE 2
```
$trigger = New-ScheduledTaskTrigger -Daily -At '3:00 AM'
Set-StmClusteredScheduledTask -TaskName 'MaintenanceTask' -Cluster 'ProdCluster' -Trigger $trigger
```

Modifies the trigger of the clustered scheduled task to run daily at 3:00 AM.

### EXAMPLE 3
```
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -WakeToRun
$credential = Get-Credential
Set-StmClusteredScheduledTask -TaskName 'SyncTask' -Cluster 'MyCluster' -Settings $settings -Credential $credential
```

Modifies the settings of the clustered scheduled task using specified credentials for the
cluster connection.

### EXAMPLE 4
```
Get-StmClusteredScheduledTask -TaskName 'ReportTask' -Cluster 'MyCluster' |
    Set-StmClusteredScheduledTask -Cluster 'MyCluster' -User 'DOMAIN\ServiceAccount' -Password 'P@ssw0rd'
```

Uses pipeline input to modify the user account under which the clustered task runs.

### EXAMPLE 5
```
Set-StmClusteredScheduledTask -TaskName 'FlexibleTask' -Cluster 'MyCluster' -TaskType 'AnyNode'
```

Changes the task type of a clustered scheduled task to run on any available node.

### EXAMPLE 6
```
$action = New-ScheduledTaskAction -Execute 'notepad.exe'
Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $action -PassThru
```

Modifies the action of a clustered task and returns the modified task object.

## PARAMETERS

### -TaskName
Specifies the name of the clustered scheduled task to modify. This parameter is mandatory when using
the ByName parameter set and must match the exact name of the task as it appears in the cluster.

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

### -InputObject
Specifies a clustered scheduled task object to modify. This parameter accepts pipeline input from
Get-StmClusteredScheduledTask. When using this parameter, the TaskName is extracted from the object.

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

### -Cluster
Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter
is mandatory and must be a valid Windows failover cluster.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Action
Specifies an array of action objects that define what the task executes. Use New-ScheduledTaskAction
to create action objects. When specified, this replaces all existing actions on the task.

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
Specifies an array of trigger objects that define when the task runs. Use New-ScheduledTaskTrigger
to create trigger objects. When specified, this replaces all existing triggers on the task.

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
Specifies a settings object that defines task behavior. Use New-ScheduledTaskSettingsSet to create
a settings object. When specified, this merges with existing task settings.

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
Specifies a principal object that defines the security context for the task. Use
New-ScheduledTaskPrincipal to create a principal object. This parameter cannot be used together
with User or Password parameters.

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
Specifies the user account under which the task runs. This is an alternative to using the
Principal parameter. Cannot be used together with the Principal parameter.

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
Specifies the password for the user account specified by the User parameter. This is an
alternative to using the Principal parameter. Cannot be used together with the Principal parameter.

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

### -TaskType
Specifies the cluster task type. Valid values are:
- ResourceSpecific: Task runs on a specific cluster resource
- AnyNode: Task can run on any cluster node
- ClusterWide: Task runs on all cluster nodes

```yaml
Type: ClusterTaskTypeEnum
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Specifies credentials to use when connecting to the cluster. If not specified, the current user's
credentials are used for the connection.

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
Returns an object representing the modified clustered scheduled task. By default, this cmdlet does
not generate any output.

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

### Microsoft.Management.Infrastructure.CimInstance
### You can pipe a clustered scheduled task object from Get-StmClusteredScheduledTask to this cmdlet.

## OUTPUTS

### None or System.Object
### When you use the PassThru parameter, this cmdlet returns the modified task object. Otherwise,
### this cmdlet does not generate any output.

## NOTES
This function requires:
- PowerShell remoting to be enabled on the target cluster
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to manage clustered scheduled tasks
- Network connectivity to the cluster on the WinRM ports (default 5985/5986)

The function performs a complete re-registration of the task, which involves:
- Exporting the current task configuration
- Modifying the configuration based on parameters
- Unregistering the current task
- Re-registering the task with the new configuration

This operation temporarily removes the task from the cluster during the re-registration
process. The task will be unavailable for execution during this brief period.

At least one modification parameter (Action, Trigger, Settings, Principal, User, Password, or
TaskType) must be specified. The Principal parameter cannot be combined with User or Password.

The function supports the -WhatIf and -Confirm parameters for safe operation in automated
environments.

## RELATED LINKS

[Get-StmClusteredScheduledTask](Get-StmClusteredScheduledTask.md)

[Export-StmClusteredScheduledTask](Export-StmClusteredScheduledTask.md)

[Register-StmClusteredScheduledTask](Register-StmClusteredScheduledTask.md)

[Unregister-StmClusteredScheduledTask](Unregister-StmClusteredScheduledTask.md)
