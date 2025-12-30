function Set-StmClusteredScheduledTask {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '',
        Justification = 'Mirrors native scheduled task cmdlet interface which uses User/Password strings')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
        Justification = 'Mirrors native scheduled task cmdlet interface which uses plain text password')]
    <#
    .SYNOPSIS
        Modifies a clustered scheduled task in a Windows failover cluster.

    .DESCRIPTION
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

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to modify. This parameter is mandatory
        and must match the exact name of the task as it appears in the cluster.

    .PARAMETER InputObject
        Specifies a clustered scheduled task object to modify. This parameter accepts pipeline input from
        Get-StmClusteredScheduledTask. When using this parameter, the TaskName is extracted from the object.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter
        is mandatory and must be a valid Windows failover cluster.

    .PARAMETER Action
        Specifies an array of action objects that define what the task executes. Use New-ScheduledTaskAction
        to create action objects. When specified, this replaces all existing actions on the task.

    .PARAMETER Trigger
        Specifies an array of trigger objects that define when the task runs. Use New-ScheduledTaskTrigger
        to create trigger objects. When specified, this replaces all existing triggers on the task.

    .PARAMETER Settings
        Specifies a settings object that defines task behavior. Use New-ScheduledTaskSettingsSet to create
        a settings object. When specified, this merges with existing task settings.

    .PARAMETER Principal
        Specifies a principal object that defines the security context for the task. Use
        New-ScheduledTaskPrincipal to create a principal object. This parameter cannot be used together
        with User or Password parameters.

    .PARAMETER User
        Specifies the user account under which the task runs. This is an alternative to using the
        Principal parameter. Cannot be used together with the Principal parameter.

    .PARAMETER Password
        Specifies the password for the user account specified by the User parameter. This is an
        alternative to using the Principal parameter. Cannot be used together with the Principal parameter.

    .PARAMETER TaskType
        Specifies the cluster task type. Valid values are:
        - ResourceSpecific: Task runs on a specific cluster resource
        - AnyNode: Task can run on any cluster node
        - ClusterWide: Task runs on all cluster nodes

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not specified, the current user's
        credentials are used for the connection.

    .PARAMETER PassThru
        Returns an object representing the modified clustered scheduled task. By default, this cmdlet does
        not generate any output.

    .EXAMPLE
        $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File C:\Scripts\Backup.ps1'
        Set-StmClusteredScheduledTask -TaskName 'ClusterBackup' -Cluster 'MyCluster' -Action $action

        Modifies the action of the clustered scheduled task named "ClusterBackup" to run a different
        PowerShell script.

    .EXAMPLE
        $trigger = New-ScheduledTaskTrigger -Daily -At '3:00 AM'
        Set-StmClusteredScheduledTask -TaskName 'MaintenanceTask' -Cluster 'ProdCluster' -Trigger $trigger

        Modifies the trigger of the clustered scheduled task to run daily at 3:00 AM.

    .EXAMPLE
        $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -WakeToRun
        $credential = Get-Credential
        Set-StmClusteredScheduledTask -TaskName 'SyncTask' -Cluster 'MyCluster' -Settings $settings -Credential $credential

        Modifies the settings of the clustered scheduled task using specified credentials for the
        cluster connection.

    .EXAMPLE
        Get-StmClusteredScheduledTask -TaskName 'ReportTask' -Cluster 'MyCluster' |
            Set-StmClusteredScheduledTask -Cluster 'MyCluster' -User 'DOMAIN\ServiceAccount' -Password 'P@ssw0rd'

        Uses pipeline input to modify the user account under which the clustered task runs.

    .EXAMPLE
        Set-StmClusteredScheduledTask -TaskName 'FlexibleTask' -Cluster 'MyCluster' -TaskType 'AnyNode'

        Changes the task type of a clustered scheduled task to run on any available node.

    .INPUTS
        Microsoft.Management.Infrastructure.CimInstance
        You can pipe a clustered scheduled task object from Get-StmClusteredScheduledTask to this cmdlet.

    .OUTPUTS
        None or System.Object
        When you use the PassThru parameter, this cmdlet returns the modified task object. Otherwise,
        this cmdlet does not generate any output.

    .NOTES
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

    .LINK
        Get-StmClusteredScheduledTask

    .LINK
        Export-StmClusteredScheduledTask

    .LINK
        Register-StmClusteredScheduledTask

    .LINK
        Unregister-StmClusteredScheduledTask
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByInputObject', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cluster,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Action,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Trigger,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Settings,

        [Parameter(Mandatory = $false)]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Principal,

        [Parameter(Mandatory = $false)]
        [string]
        $User,

        [Parameter(Mandatory = $false)]
        [string]
        $Password,

        [Parameter(Mandatory = $false)]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.ClusterTaskTypeEnum]
        $TaskType,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        Write-Verbose 'Starting Set-StmClusteredScheduledTask'

        # Validate mutually exclusive parameters (Principal vs User/Password)
        if ($PSBoundParameters.ContainsKey('Principal') -and
            ($PSBoundParameters.ContainsKey('User') -or $PSBoundParameters.ContainsKey('Password'))) {
            $errorMsg = 'The Principal parameter cannot be used with User or Password parameters.'
            $errorRecordParameters = @{
                Exception         = [System.ArgumentException]::new($errorMsg)
                ErrorId           = 'InvalidParameterCombination'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::InvalidArgument
                TargetObject      = $null
                Message           = $errorMsg
                RecommendedAction = 'Use either Principal or User/Password, not both.'
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Validate that at least one modification parameter is specified
        $modificationParams = @('Action', 'Trigger', 'Settings', 'Principal', 'User', 'Password', 'TaskType')
        $hasModification = $modificationParams | Where-Object { $PSBoundParameters.ContainsKey($_) }
        if (-not $hasModification) {
            $errorMsg = 'At least one task property (Action, Trigger, Settings, Principal, User, Password, or TaskType) must be specified.'
            $errorRecordParameters = @{
                Exception         = [System.ArgumentException]::new($errorMsg)
                ErrorId           = 'NoModificationSpecified'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::InvalidArgument
                TargetObject      = $null
                Message           = $errorMsg
                RecommendedAction = 'Specify at least one property to modify.'
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    process {
        try {
            # Determine task name based on parameter set
            if ($PSCmdlet.ParameterSetName -eq 'ByInputObject') {
                $effectiveTaskName = $InputObject.TaskName
                Write-Verbose "Processing task from pipeline: '$effectiveTaskName'"
            }
            else {
                $effectiveTaskName = $TaskName
            }

            $target = "clustered task '$effectiveTaskName' on cluster '$Cluster'"
            $operation = 'Set clustered scheduled task properties'

            Write-Verbose "Exporting clustered scheduled task '$effectiveTaskName'..."
            $exportParams = @{
                TaskName   = $effectiveTaskName
                Cluster    = $Cluster
                Credential = $Credential
            }
            $taskXml = Export-StmClusteredScheduledTask @exportParams

            if (-not $taskXml) {
                $errorMsg = "Failed to export current configuration for task '$effectiveTaskName'."
                $errorRecordParameters = @{
                    Exception         = [System.InvalidOperationException]::new($errorMsg)
                    ErrorId           = 'ClusteredTaskExportFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    TargetObject      = $effectiveTaskName
                    Message           = $errorMsg
                    RecommendedAction = 'Verify the task name is correct and that the task exists on the cluster.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }

            # Get current task to retrieve TaskType if not specified
            Write-Verbose 'Retrieving current task information...'
            $getTaskParams = @{
                TaskName   = $effectiveTaskName
                Cluster    = $Cluster
                Credential = $Credential
            }
            $currentTask = Get-StmClusteredScheduledTask @getTaskParams
            $effectiveTaskType = if ($PSBoundParameters.ContainsKey('TaskType')) {
                $TaskType
            }
            else {
                $currentTask.ClusteredScheduledTaskObject.TaskType
            }

            # Load XML for modification
            [xml]$taskXmlDocument = $taskXml

            # Modify Actions if specified
            if ($PSBoundParameters.ContainsKey('Action')) {
                Write-Verbose 'Modifying Actions in task XML...'
                $actionsNode = $taskXmlDocument.Task.Actions
                # Clear existing Exec actions using simple child node enumeration
                $execActions = @($actionsNode.ChildNodes | Where-Object { $_.LocalName -eq 'Exec' })
                foreach ($exec in $execActions) {
                    $actionsNode.RemoveChild($exec) | Out-Null
                }

                # Add new actions
                foreach ($act in $Action) {
                    $execElement = $taskXmlDocument.CreateElement('Exec', $taskXmlDocument.DocumentElement.NamespaceURI)

                    $cmdElement = $taskXmlDocument.CreateElement('Command', $taskXmlDocument.DocumentElement.NamespaceURI)
                    $cmdElement.InnerText = $act.Execute
                    $execElement.AppendChild($cmdElement) | Out-Null

                    if ($act.Arguments) {
                        $argsElement = $taskXmlDocument.CreateElement('Arguments', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $argsElement.InnerText = $act.Arguments
                        $execElement.AppendChild($argsElement) | Out-Null
                    }

                    if ($act.WorkingDirectory) {
                        $wdElement = $taskXmlDocument.CreateElement('WorkingDirectory', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $wdElement.InnerText = $act.WorkingDirectory
                        $execElement.AppendChild($wdElement) | Out-Null
                    }

                    $actionsNode.AppendChild($execElement) | Out-Null
                }
            }

            # Modify Triggers if specified
            if ($PSBoundParameters.ContainsKey('Trigger')) {
                Write-Verbose 'Modifying Triggers in task XML...'
                $triggersNode = $taskXmlDocument.Task.Triggers
                # Clear existing triggers
                $triggersNode.RemoveAll()

                # Add new triggers based on type
                foreach ($trig in $Trigger) {
                    $triggerElement = $null
                    $triggerType = $trig.CimClass.CimClassName

                    switch -Wildcard ($triggerType) {
                        '*Daily*' {
                            $triggerElement = $taskXmlDocument.CreateElement('CalendarTrigger', $taskXmlDocument.DocumentElement.NamespaceURI)
                            $schedByDay = $taskXmlDocument.CreateElement('ScheduleByDay', $taskXmlDocument.DocumentElement.NamespaceURI)
                            $daysInterval = $taskXmlDocument.CreateElement('DaysInterval', $taskXmlDocument.DocumentElement.NamespaceURI)
                            $daysInterval.InnerText = if ($trig.DaysInterval) { $trig.DaysInterval } else { '1' }
                            $schedByDay.AppendChild($daysInterval) | Out-Null
                            $triggerElement.AppendChild($schedByDay) | Out-Null
                        }
                        '*Weekly*' {
                            $triggerElement = $taskXmlDocument.CreateElement('CalendarTrigger', $taskXmlDocument.DocumentElement.NamespaceURI)
                            $schedByWeek = $taskXmlDocument.CreateElement('ScheduleByWeek', $taskXmlDocument.DocumentElement.NamespaceURI)
                            $triggerElement.AppendChild($schedByWeek) | Out-Null
                        }
                        '*Once*' {
                            $triggerElement = $taskXmlDocument.CreateElement('TimeTrigger', $taskXmlDocument.DocumentElement.NamespaceURI)
                        }
                        '*Logon*' {
                            $triggerElement = $taskXmlDocument.CreateElement('LogonTrigger', $taskXmlDocument.DocumentElement.NamespaceURI)
                        }
                        '*Boot*' {
                            $triggerElement = $taskXmlDocument.CreateElement('BootTrigger', $taskXmlDocument.DocumentElement.NamespaceURI)
                        }
                        default {
                            $triggerElement = $taskXmlDocument.CreateElement('TimeTrigger', $taskXmlDocument.DocumentElement.NamespaceURI)
                        }
                    }

                    if ($triggerElement) {
                        # Add start boundary if available
                        if ($trig.StartBoundary) {
                            $startBoundary = $taskXmlDocument.CreateElement('StartBoundary', $taskXmlDocument.DocumentElement.NamespaceURI)
                            $startBoundary.InnerText = $trig.StartBoundary
                            $triggerElement.PrependChild($startBoundary) | Out-Null
                        }

                        # Add enabled status
                        $enabled = $taskXmlDocument.CreateElement('Enabled', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $enabled.InnerText = if ($trig.Enabled -eq $false) { 'false' } else { 'true' }
                        $triggerElement.AppendChild($enabled) | Out-Null

                        $triggersNode.AppendChild($triggerElement) | Out-Null
                    }
                }
            }

            # Modify Settings if specified
            if ($PSBoundParameters.ContainsKey('Settings')) {
                Write-Verbose 'Modifying Settings in task XML...'
                $settingsNode = $taskXmlDocument.Task.Settings

                # Map common settings properties to XML elements
                $settingsMap = @{
                    'AllowDemandStart'             = 'AllowStartOnDemand'
                    'AllowHardTerminate'           = 'AllowHardTerminate'
                    'DisallowStartIfOnBatteries'   = 'DisallowStartIfOnBatteries'
                    'StopIfGoingOnBatteries'       = 'StopIfGoingOnBatteries'
                    'Hidden'                       = 'Hidden'
                    'RunOnlyIfNetworkAvailable'    = 'RunOnlyIfNetworkAvailable'
                    'Enabled'                      = 'Enabled'
                    'WakeToRun'                    = 'WakeToRun'
                    'RunOnlyIfIdle'                = 'RunOnlyIfIdle'
                    'StartWhenAvailable'           = 'StartWhenAvailable'
                    'DisallowStartOnRemoteAppSession' = 'DisallowStartOnRemoteAppSession'
                    'UseUnifiedSchedulingEngine'   = 'UseUnifiedSchedulingEngine'
                }

                foreach ($prop in $settingsMap.Keys) {
                    $value = $Settings.$prop
                    if ($null -ne $value) {
                        $xmlProp = $settingsMap[$prop]
                        $existingNode = $settingsNode.SelectSingleNode($xmlProp)
                        if ($existingNode) {
                            $existingNode.InnerText = $value.ToString().ToLower()
                        }
                        else {
                            $newNode = $taskXmlDocument.CreateElement($xmlProp, $taskXmlDocument.DocumentElement.NamespaceURI)
                            $newNode.InnerText = $value.ToString().ToLower()
                            $settingsNode.AppendChild($newNode) | Out-Null
                        }
                    }
                }

                # Handle Priority
                if ($null -ne $Settings.Priority) {
                    $priorityNode = $settingsNode.SelectSingleNode('Priority')
                    if ($priorityNode) {
                        $priorityNode.InnerText = $Settings.Priority.ToString()
                    }
                    else {
                        $newNode = $taskXmlDocument.CreateElement('Priority', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $newNode.InnerText = $Settings.Priority.ToString()
                        $settingsNode.AppendChild($newNode) | Out-Null
                    }
                }

                # Handle ExecutionTimeLimit
                if ($Settings.ExecutionTimeLimit) {
                    $limitNode = $settingsNode.SelectSingleNode('ExecutionTimeLimit')
                    if ($limitNode) {
                        $limitNode.InnerText = $Settings.ExecutionTimeLimit.ToString()
                    }
                    else {
                        $newNode = $taskXmlDocument.CreateElement('ExecutionTimeLimit', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $newNode.InnerText = $Settings.ExecutionTimeLimit.ToString()
                        $settingsNode.AppendChild($newNode) | Out-Null
                    }
                }
            }

            # Modify Principal if specified
            if ($PSBoundParameters.ContainsKey('Principal')) {
                Write-Verbose 'Modifying Principal in task XML...'
                $principalsNode = $taskXmlDocument.Task.Principals
                $principalNode = $principalsNode.Principal

                if ($Principal.UserId) {
                    $userIdNode = $principalNode.SelectSingleNode('UserId')
                    if ($userIdNode) {
                        $userIdNode.InnerText = $Principal.UserId
                    }
                    else {
                        $newNode = $taskXmlDocument.CreateElement('UserId', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $newNode.InnerText = $Principal.UserId
                        $principalNode.AppendChild($newNode) | Out-Null
                    }
                }

                if ($Principal.LogonType) {
                    $logonTypeNode = $principalNode.SelectSingleNode('LogonType')
                    $logonTypeValue = switch ($Principal.LogonType) {
                        'Password' { 'Password' }
                        'S4U' { 'S4U' }
                        'Interactive' { 'InteractiveToken' }
                        'InteractiveOrPassword' { 'InteractiveTokenOrPassword' }
                        'ServiceAccount' { 'ServiceAccount' }
                        default { $Principal.LogonType.ToString() }
                    }
                    if ($logonTypeNode) {
                        $logonTypeNode.InnerText = $logonTypeValue
                    }
                    else {
                        $newNode = $taskXmlDocument.CreateElement('LogonType', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $newNode.InnerText = $logonTypeValue
                        $principalNode.AppendChild($newNode) | Out-Null
                    }
                }

                if ($Principal.RunLevel) {
                    $runLevelNode = $principalNode.SelectSingleNode('RunLevel')
                    $runLevelValue = switch ($Principal.RunLevel) {
                        'Highest' { 'HighestAvailable' }
                        'Limited' { 'LeastPrivilege' }
                        default { $Principal.RunLevel.ToString() }
                    }
                    if ($runLevelNode) {
                        $runLevelNode.InnerText = $runLevelValue
                    }
                    else {
                        $newNode = $taskXmlDocument.CreateElement('RunLevel', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $newNode.InnerText = $runLevelValue
                        $principalNode.AppendChild($newNode) | Out-Null
                    }
                }
            }

            # Modify User/Password if specified
            if ($PSBoundParameters.ContainsKey('User')) {
                Write-Verbose 'Modifying User in task XML...'
                $principalsNode = $taskXmlDocument.Task.Principals
                $principalNode = $principalsNode.Principal

                $userIdNode = $principalNode.SelectSingleNode('UserId')
                if ($userIdNode) {
                    $userIdNode.InnerText = $User
                }
                else {
                    $newNode = $taskXmlDocument.CreateElement('UserId', $taskXmlDocument.DocumentElement.NamespaceURI)
                    $newNode.InnerText = $User
                    $principalNode.AppendChild($newNode) | Out-Null
                }

                # If password is provided, set LogonType to Password
                if ($PSBoundParameters.ContainsKey('Password')) {
                    $logonTypeNode = $principalNode.SelectSingleNode('LogonType')
                    if ($logonTypeNode) {
                        $logonTypeNode.InnerText = 'Password'
                    }
                    else {
                        $newNode = $taskXmlDocument.CreateElement('LogonType', $taskXmlDocument.DocumentElement.NamespaceURI)
                        $newNode.InnerText = 'Password'
                        $principalNode.AppendChild($newNode) | Out-Null
                    }
                }
            }

            $modifiedXml = $taskXmlDocument.OuterXml

            if ($PSCmdlet.ShouldProcess($target, $operation)) {
                Write-Verbose "Unregistering clustered scheduled task '$effectiveTaskName'..."
                $cimSessionParams = @{
                    ComputerName = $Cluster
                    Credential   = $Credential
                }
                $cimSession = New-StmCimSession @cimSessionParams

                $unregisterParams = @{
                    TaskName    = $effectiveTaskName
                    CimSession  = $cimSession
                    ErrorAction = 'Stop'
                }
                Unregister-ClusteredScheduledTask @unregisterParams

                Write-Verbose "Re-registering clustered scheduled task '$effectiveTaskName' with modified configuration..."
                $registerParams = @{
                    TaskName   = $effectiveTaskName
                    Cluster    = $Cluster
                    Xml        = $modifiedXml
                    TaskType   = $effectiveTaskType
                    Credential = $Credential
                }

                $result = Register-StmClusteredScheduledTask @registerParams

                $successMsg = "Clustered scheduled task '$effectiveTaskName' has been successfully modified."
                Write-Verbose $successMsg

                if ($PassThru) {
                    # Return the updated task
                    $getTaskParams = @{
                        TaskName   = $effectiveTaskName
                        Cluster    = $Cluster
                        Credential = $Credential
                    }
                    Write-Output (Get-StmClusteredScheduledTask @getTaskParams)
                }
            }
            else {
                Write-Verbose 'Operation cancelled by user.'
            }
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ClusteredScheduledTaskSetFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $effectiveTaskName
                Message           = (
                    "Failed to modify clustered scheduled task '$effectiveTaskName' on cluster '$Cluster'. {$_}"
                )
                RecommendedAction = (
                    'Verify the task name is correct, that the task exists, that the provided ' +
                    'Action/Trigger/Settings/Principal objects are valid, and that you have permission to ' +
                    'manage clustered scheduled tasks.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed Set-StmClusteredScheduledTask"
    }
}
