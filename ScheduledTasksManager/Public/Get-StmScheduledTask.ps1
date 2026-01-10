function Get-StmScheduledTask {
    <#
    .SYNOPSIS
        Retrieves scheduled tasks from a local or remote computer.

    .DESCRIPTION
        The Get-StmScheduledTask function retrieves scheduled tasks from the Windows Task Scheduler on a local or
        remote computer. You can filter tasks by name, path, and state, and optionally specify credentials for
        remote connections. This function wraps the built-in Get-ScheduledTask cmdlet to provide credential support
        across the ScheduledTasksManager module.

    .PARAMETER TaskName
        Specifies the name of a specific scheduled task to retrieve. If not specified, all scheduled tasks will be
        returned. This parameter is optional and supports wildcards.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task(s) to retrieve. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, tasks
        from all paths will be returned. This parameter is optional and supports wildcards.

    .PARAMETER TaskState
        Specifies the state of the scheduled task(s) to retrieve. Valid values are: Unknown, Disabled, Queued, Ready,
        and Running. If not specified, tasks in all states will be returned. This parameter is optional.

    .PARAMETER ComputerName
        Specifies the name of the computer from which to retrieve scheduled tasks. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .EXAMPLE
        Get-StmScheduledTask

        Retrieves all scheduled tasks from the local computer.

    .EXAMPLE
        Get-StmScheduledTask -TaskName "MyBackupTask"

        Retrieves the specific scheduled task named "MyBackupTask" from the local computer.

    .EXAMPLE
        Get-StmScheduledTask -TaskPath "\Microsoft\Windows\PowerShell\"

        Retrieves all scheduled tasks located in the PowerShell folder from the local computer.

    .EXAMPLE
        Get-StmScheduledTask -TaskState "Ready"

        Retrieves all scheduled tasks that are in the "Ready" state from the local computer.

    .EXAMPLE
        Get-StmScheduledTask -ComputerName "Server01"

        Retrieves all scheduled tasks from the remote computer "Server01" using the current user's credentials.

    .EXAMPLE
        $credentials = Get-Credential
        Get-StmScheduledTask -TaskName "Maintenance*" -ComputerName "Server02" -Credential $credentials

        Retrieves all scheduled tasks that start with "Maintenance" from the remote computer "Server02" using the
        specified credentials.

    .EXAMPLE
        Get-StmScheduledTask -TaskName "DatabaseBackup" -TaskPath "\Custom\Database\" -ComputerName "DBServer"

        Retrieves the "DatabaseBackup" task from the "\Custom\Database\" path on the remote computer "DBServer".

    .EXAMPLE
        Get-StmScheduledTask -TaskState "Running" -ComputerName "Server01"

        Retrieves all running scheduled tasks from the remote computer "Server01".

    .INPUTS
        None. You cannot pipe objects to Get-StmScheduledTask.

    .OUTPUTS
        Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        Returns ScheduledTask objects that represent the scheduled tasks on the specified computer.

    .NOTES
        This function requires:
        - Appropriate permissions to access scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]
        $TaskState,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName = 'localhost',

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose 'Starting Get-StmScheduledTask'
        $scheduledTaskParameters = @{
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('TaskName')) {
            Write-Verbose "Using provided task name '$TaskName'"
            $scheduledTaskParameters['TaskName'] = $TaskName
        }
        else {
            Write-Verbose 'No task name provided, retrieving all scheduled tasks'
        }

        if ($PSBoundParameters.ContainsKey('TaskPath')) {
            Write-Verbose "Using provided task path '$TaskPath'"
            $scheduledTaskParameters['TaskPath'] = $TaskPath
        }
        else {
            Write-Verbose 'No task path provided, retrieving all scheduled tasks'
        }

        $cimSessionParameters = @{
            ErrorAction = 'Stop'
        }
        $cimSessionParameters['ComputerName'] = $ComputerName
        if ($PSBoundParameters.ContainsKey('ComputerName')) {
            Write-Verbose "Using provided computer name '$ComputerName'"
        }
        else {
            Write-Verbose 'Using local computer'
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            Write-Verbose 'Using provided credential'
            $cimSessionParameters['Credential'] = $Credential
        }
        else {
            Write-Verbose 'Using current user credentials'
        }
        $cimSession = New-StmCimSession @cimSessionParameters
        $scheduledTaskParameters['CimSession'] = $cimSession
    }

    process {
        try {
            $scheduledTasks = Get-ScheduledTask @scheduledTaskParameters

            if ($PSBoundParameters.ContainsKey('TaskState')) {
                Write-Verbose "Filtering scheduled tasks by state '$TaskState'"
                $scheduledTasks = $scheduledTasks | Where-Object { $_.State -eq $TaskState }
            }

            Write-Verbose "Retrieved $($scheduledTasks.Count) task(s). Returning them."
            $scheduledTasks
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ScheduledTaskRetrievalFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $TaskName
                Message           = "Failed to retrieve scheduled tasks. $($_.Exception.Message)"
                RecommendedAction = (
                    'Verify the task name is correct and that you have permission to access the scheduled tasks.'
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
        Write-Verbose 'Finished Get-StmScheduledTask'
    }
}
