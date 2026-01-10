function Set-StmScheduledTask {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '',
        Justification = 'Mirrors native Set-ScheduledTask cmdlet interface which uses User/Password strings')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
        Justification = 'Mirrors native Set-ScheduledTask cmdlet interface which uses plain text password')]
    <#
    .SYNOPSIS
        Modifies a scheduled task on a local or remote computer.

    .DESCRIPTION
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

    .PARAMETER TaskName
        Specifies the name of the scheduled task to modify. This parameter is mandatory when using the ByName
        parameter set and must match the exact name of the task as it appears in the Task Scheduler.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task to modify. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
        root path ('\') will be used.

    .PARAMETER InputObject
        Specifies a scheduled task object to modify. This parameter accepts pipeline input from Get-StmScheduledTask
        or Get-ScheduledTask. When using this parameter, the TaskName and TaskPath are extracted from the object.

    .PARAMETER Action
        Specifies an array of action objects that define what the task executes. Use New-ScheduledTaskAction to
        create action objects. When specified, this replaces all existing actions on the task.

    .PARAMETER Trigger
        Specifies an array of trigger objects that define when the task runs. Use New-ScheduledTaskTrigger to
        create trigger objects. When specified, this replaces all existing triggers on the task.

    .PARAMETER Settings
        Specifies a settings object that defines task behavior. Use New-ScheduledTaskSettingsSet to create a
        settings object. When specified, this replaces the existing task settings.

    .PARAMETER Principal
        Specifies a principal object that defines the security context for the task. Use New-ScheduledTaskPrincipal
        to create a principal object. This parameter cannot be used together with User or Password parameters.

    .PARAMETER User
        Specifies the user account under which the task runs. This is an alternative to using the Principal
        parameter. Cannot be used together with the Principal parameter.

    .PARAMETER Password
        Specifies the password for the user account specified by the User parameter. This is an alternative to
        using the Principal parameter. Cannot be used together with the Principal parameter.

    .PARAMETER ComputerName
        Specifies the name of the computer on which to modify the scheduled task. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names. This parameter is only available when using the ByName parameter set.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is relevant when connecting to remote computers
        or when the task requires credentials for the CIM session.

    .PARAMETER PassThru
        Returns an object representing the modified scheduled task. By default, this cmdlet does not generate any
        output.

    .EXAMPLE
        $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File C:\Scripts\Backup.ps1'
        Set-StmScheduledTask -TaskName 'MyBackupTask' -Action $action

        Modifies the action of the scheduled task named "MyBackupTask" to run a different PowerShell script.

    .EXAMPLE
        $trigger = New-ScheduledTaskTrigger -Daily -At '3:00 AM'
        Set-StmScheduledTask -TaskName 'MaintenanceTask' -TaskPath '\Custom\Maintenance\' -Trigger $trigger

        Modifies the trigger of the scheduled task named "MaintenanceTask" in the specified path to run daily
        at 3:00 AM.

    .EXAMPLE
        $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -WakeToRun
        Set-StmScheduledTask -TaskName 'SyncTask' -Settings $settings -ComputerName 'Server01'

        Modifies the settings of the scheduled task named "SyncTask" on Server01 to only run when the network
        is available and to wake the computer if needed.

    .EXAMPLE
        Get-StmScheduledTask -TaskName 'ReportTask' |
            Set-StmScheduledTask -User 'DOMAIN\ServiceAccount' -Password 'P@ssw0rd'

        Uses pipeline input to modify the user account under which the task runs.

    .EXAMPLE
        $action = New-ScheduledTaskAction -Execute 'notepad.exe'
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)
        Set-StmScheduledTask -TaskName 'TestTask' -Action $action -Trigger $trigger -PassThru

        Modifies both the action and trigger of a task and returns the modified task object.

    .EXAMPLE
        $cred = Get-Credential
        $params = @{
            TaskName     = 'RemoteTask'
            ComputerName = 'Server02'
            Credential   = $cred
            User         = 'LocalAdmin'
            Password     = 'Secret123'
        }
        Set-StmScheduledTask @params

        Modifies a task on a remote server using specified credentials for the connection, and changes the
        user account that the task runs under.

    .INPUTS
        Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        You can pipe a scheduled task object from Get-StmScheduledTask or Get-ScheduledTask to this cmdlet.

    .OUTPUTS
        None or Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        When you use the PassThru parameter, this cmdlet returns a ScheduledTask object. Otherwise, this cmdlet
        does not generate any output.

    .NOTES
        This function requires:
        - Appropriate permissions to manage scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.

        At least one modification parameter (Action, Trigger, Settings, Principal, User, or Password) must be
        specified. The Principal parameter cannot be combined with User or Password parameters.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.

    .LINK
        Get-StmScheduledTask

    .LINK
        New-ScheduledTaskAction

    .LINK
        New-ScheduledTaskTrigger

    .LINK
        New-ScheduledTaskSettingsSet

    .LINK
        New-ScheduledTaskPrincipal
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath = '\',

        [Parameter(Mandatory = $true, ParameterSetName = 'ByInputObject', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $InputObject,

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

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName = 'localhost',

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
        Write-Verbose 'Starting Set-StmScheduledTask'

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
        $modificationParams = @('Action', 'Trigger', 'Settings', 'Principal', 'User', 'Password')
        $hasModification = $modificationParams | Where-Object { $PSBoundParameters.ContainsKey($_) }
        if (-not $hasModification) {
            $errorMsg = @(
                'At least one task property (Action, Trigger, Settings, Principal,'
                'User, or Password) must be specified.'
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

        # Create CIM session for ByName parameter set
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $cimSessionParameters = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                Write-Verbose 'Using provided credential'
                $cimSessionParameters['Credential'] = $Credential
            }
            else {
                Write-Verbose 'Using current user credentials'
            }
            $script:cimSession = New-StmCimSession @cimSessionParameters
        }
    }

    process {
        try {
            # Determine task name, path, and computer based on parameter set
            if ($PSCmdlet.ParameterSetName -eq 'ByInputObject') {
                $effectiveTaskName = $InputObject.TaskName
                $effectiveTaskPath = $InputObject.TaskPath
                $effectiveComputerName = if ($InputObject.PSComputerName) {
                    $InputObject.PSComputerName
                }
                else {
                    'localhost'
                }

                Write-Verbose "Processing task from pipeline: '$effectiveTaskName' at '$effectiveTaskPath'"

                # Create CIM session for InputObject
                $cimSessionParameters = @{
                    ComputerName = $effectiveComputerName
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    Write-Verbose 'Using provided credential'
                    $cimSessionParameters['Credential'] = $Credential
                }
                $cimSession = New-StmCimSession @cimSessionParameters
            }
            else {
                $effectiveTaskName = $TaskName
                $effectiveTaskPath = $TaskPath
                $effectiveComputerName = $ComputerName
                $cimSession = $script:cimSession
            }

            $target = "$effectiveTaskName at $effectiveTaskPath on $effectiveComputerName"
            $operation = 'Set scheduled task properties'

            if ($PSCmdlet.ShouldProcess($target, $operation)) {
                $verboseMsg = @(
                    "Modifying scheduled task '$effectiveTaskName'"
                    "at path '$effectiveTaskPath' on computer '$effectiveComputerName'..."
                ) -join ' '
                Write-Verbose $verboseMsg

                # Build Set-ScheduledTask parameters
                $setScheduledTaskParameters = @{
                    TaskName    = $effectiveTaskName
                    TaskPath    = $effectiveTaskPath
                    CimSession  = $cimSession
                    ErrorAction = 'Stop'
                }

                # Add modification parameters if specified
                if ($PSBoundParameters.ContainsKey('Action')) {
                    Write-Verbose 'Adding Action parameter'
                    $setScheduledTaskParameters['Action'] = $Action
                }
                if ($PSBoundParameters.ContainsKey('Trigger')) {
                    Write-Verbose 'Adding Trigger parameter'
                    $setScheduledTaskParameters['Trigger'] = $Trigger
                }
                if ($PSBoundParameters.ContainsKey('Settings')) {
                    Write-Verbose 'Adding Settings parameter'
                    $setScheduledTaskParameters['Settings'] = $Settings
                }
                if ($PSBoundParameters.ContainsKey('Principal')) {
                    Write-Verbose 'Adding Principal parameter'
                    $setScheduledTaskParameters['Principal'] = $Principal
                }
                if ($PSBoundParameters.ContainsKey('User')) {
                    Write-Verbose 'Adding User parameter'
                    $setScheduledTaskParameters['User'] = $User
                }
                if ($PSBoundParameters.ContainsKey('Password')) {
                    Write-Verbose 'Adding Password parameter'
                    $setScheduledTaskParameters['Password'] = $Password
                }

                # Execute Set-ScheduledTask
                $result = Set-ScheduledTask @setScheduledTaskParameters

                $successMsg = "Scheduled task '$effectiveTaskName' has been successfully modified."
                Write-Verbose $successMsg

                if ($PassThru) {
                    Write-Output $result
                }
            }
            else {
                Write-Verbose 'Operation cancelled by user.'
            }
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ScheduledTaskSetFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $effectiveTaskName
                Message           = (
                    "Failed to modify scheduled task '$effectiveTaskName' at path '$effectiveTaskPath' on computer " +
                    "'$effectiveComputerName'. {$_}"
                )
                RecommendedAction = (
                    'Verify the task name and path are correct, that the task exists, that the provided ' +
                    'Action/Trigger/Settings/Principal objects are valid, and that you have permission to ' +
                    'manage scheduled tasks.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        if ($script:cimSession) {
            Remove-CimSession -CimSession $script:cimSession -ErrorAction SilentlyContinue
        }
        if ($cimSession -and $cimSession -ne $script:cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
        Write-Verbose "Completed Set-StmScheduledTask"
    }
}
