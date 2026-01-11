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

        At least one modification parameter (Action, Trigger, Settings, Principal, User, or
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
        with the User parameter.

    .PARAMETER User
        Specifies the user account under which the task runs. This is an alternative to using the
        Principal parameter. Cannot be used together with the Principal parameter. Note that this
        only sets the UserId in the task XML; for tasks requiring stored credentials, consider using
        a Group Managed Service Account (gMSA).

    .PARAMETER Password
        This parameter is not supported for clustered scheduled tasks. The native
        Register-ClusteredScheduledTask cmdlet does not accept a Password parameter. If you need to run
        a clustered task with stored credentials, configure the task on each cluster node individually
        using Set-ScheduledTask, or use a Group Managed Service Account (gMSA) which does not require
        a stored password.

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
        $params = @{
            TaskName   = 'SyncTask'
            Cluster    = 'MyCluster'
            Settings   = $settings
            Credential = $credential
        }
        Set-StmClusteredScheduledTask @params

        Modifies the settings of the clustered scheduled task using specified credentials for the
        cluster connection.

    .EXAMPLE
        Get-StmClusteredScheduledTask -TaskName 'ReportTask' -Cluster 'MyCluster' |
            Set-StmClusteredScheduledTask -Cluster 'MyCluster' -User 'DOMAIN\gMSA$'

        Uses pipeline input to modify the user account under which the clustered task runs.
        Note: For clustered tasks, use a Group Managed Service Account (gMSA) instead of
        username/password credentials.

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

        At least one modification parameter (Action, Trigger, Settings, Principal, User, or
        TaskType) must be specified. The Principal parameter cannot be combined with User.

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

        # Validate that Password parameter is not supported for clustered tasks
        # The native Register-ClusteredScheduledTask cmdlet does not support a Password parameter
        if ($PSBoundParameters.ContainsKey('Password')) {
            $errorMsg = @(
                'The Password parameter is not supported for clustered scheduled tasks.'
                'The native Register-ClusteredScheduledTask cmdlet does not accept a Password parameter.'
                'To run a clustered task with stored credentials, configure the task on each cluster node'
                'individually using Set-ScheduledTask, or use a Group Managed Service Account (gMSA).'
            ) -join ' '
            $errorRecordParameters = @{
                Exception         = [System.NotSupportedException]::new($errorMsg)
                ErrorId           = 'PasswordNotSupportedForClusteredTask'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::InvalidArgument
                TargetObject      = $null
                Message           = $errorMsg
                RecommendedAction = 'Remove the Password parameter or use a gMSA account.'
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Validate mutually exclusive parameters (Principal vs User)
        if ($PSBoundParameters.ContainsKey('Principal') -and $PSBoundParameters.ContainsKey('User')) {
            $errorMsg = 'The Principal parameter cannot be used with the User parameter.'
            $errorRecordParameters = @{
                Exception         = [System.ArgumentException]::new($errorMsg)
                ErrorId           = 'InvalidParameterCombination'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::InvalidArgument
                TargetObject      = $null
                Message           = $errorMsg
                RecommendedAction = 'Use either Principal or User, not both.'
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Validate that at least one modification parameter is specified
        $modificationParams = @('Action', 'Trigger', 'Settings', 'Principal', 'User', 'TaskType')
        $hasModification = $modificationParams | Where-Object { $PSBoundParameters.ContainsKey($_) }
        if (-not $hasModification) {
            $errorMsg = @(
                'At least one task property (Action, Trigger, Settings, Principal,'
                'User, or TaskType) must be specified.'
            ) -join ' '
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
        $cimSession = $null
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
                Update-StmTaskActionXml -TaskXml $taskXmlDocument -Action $Action
            }

            # Modify Triggers if specified
            if ($PSBoundParameters.ContainsKey('Trigger')) {
                Write-Verbose 'Modifying Triggers in task XML...'
                Update-StmTaskTriggerXml -TaskXml $taskXmlDocument -Trigger $Trigger
            }

            # Modify Settings if specified
            if ($PSBoundParameters.ContainsKey('Settings')) {
                Write-Verbose 'Modifying Settings in task XML...'
                Update-StmTaskSettingsXml -TaskXml $taskXmlDocument -Settings $Settings
            }

            # Modify Principal if specified
            if ($PSBoundParameters.ContainsKey('Principal')) {
                Write-Verbose 'Modifying Principal in task XML...'
                Update-StmTaskPrincipalXml -TaskXml $taskXmlDocument -Principal $Principal
            }

            # Modify User if specified
            if ($PSBoundParameters.ContainsKey('User')) {
                Write-Verbose 'Modifying User in task XML...'
                Update-StmTaskUserXml -TaskXml $taskXmlDocument -User $User
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

                $msg = "Re-registering clustered task '$effectiveTaskName'..."
                Write-Verbose $msg
                $registerParams = @{
                    TaskName   = $effectiveTaskName
                    Cluster    = $Cluster
                    Xml        = $modifiedXml
                    TaskType   = $effectiveTaskType
                    Credential = $Credential
                }

                $null = Register-StmClusteredScheduledTask @registerParams

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
        if ($cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
        Write-Verbose "Completed Set-StmClusteredScheduledTask"
    }
}
