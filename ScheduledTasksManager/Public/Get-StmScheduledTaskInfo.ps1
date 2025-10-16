function Get-StmScheduledTaskInfo {
    <#
    .SYNOPSIS
        Retrieves detailed information about scheduled tasks from a local or remote computer.

    .DESCRIPTION
        The Get-StmScheduledTaskInfo function retrieves comprehensive information about scheduled tasks from the
        Windows Task Scheduler on a local or remote computer. This function wraps Get-ScheduledTaskInfo to provide
        additional details such as last run time, next run time, last task result, number of missed runs, and other
        operational details. You can filter tasks by name, path, and state, and optionally specify credentials for
        remote connections.

    .PARAMETER TaskName
        Specifies the name of a specific scheduled task to retrieve information for. If not specified, information
        for all scheduled tasks will be returned. This parameter is optional and supports wildcards.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task(s) to retrieve information for. The task path represents the folder
        structure in the Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not
        specified, tasks from all paths will be returned. This parameter is optional and supports wildcards.

    .PARAMETER TaskState
        Specifies the state of the scheduled task(s) to retrieve information for. Valid values are: Unknown,
        Disabled, Queued, Ready, and Running. If not specified, tasks in all states will be returned. This parameter
        is optional.

    .PARAMETER ComputerName
        Specifies the name of the computer from which to retrieve scheduled task information. If not specified, the
        local computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .PARAMETER InputObject
        Specifies one or more ScheduledTask objects from which to retrieve detailed information. This parameter
        accepts pipeline input from Get-StmScheduledTask or Get-ScheduledTask.

    .EXAMPLE
        Get-StmScheduledTaskInfo

        Retrieves detailed information for all scheduled tasks from the local computer.

    .EXAMPLE
        Get-StmScheduledTaskInfo -TaskName "MyBackupTask"

        Retrieves detailed information for the specific scheduled task named "MyBackupTask" from the local computer.

    .EXAMPLE
        Get-StmScheduledTask -TaskName "MyBackupTask" | Get-StmScheduledTaskInfo

        Retrieves the scheduled task "MyBackupTask" and pipes it to Get-StmScheduledTaskInfo to get detailed
        information.

    .EXAMPLE
        Get-StmScheduledTaskInfo -TaskPath "\Microsoft\Windows\PowerShell\"

        Retrieves detailed information for all scheduled tasks located in the PowerShell folder from the local
        computer.

    .EXAMPLE
        Get-StmScheduledTaskInfo -TaskState "Ready" -ComputerName "Server01"

        Retrieves detailed information for all scheduled tasks that are in the "Ready" state from the remote
        computer "Server01".

    .EXAMPLE
        $credentials = Get-Credential
        Get-StmScheduledTaskInfo -TaskName "Maintenance*" -ComputerName "Server02" -Credential $credentials

        Retrieves detailed information for all scheduled tasks that start with "Maintenance" from the remote
        computer "Server02" using the specified credentials.

    .EXAMPLE
        Get-StmScheduledTask -TaskState "Running" | Get-StmScheduledTaskInfo |
            Select-Object TaskName, LastRunTime, RunningDuration

        Retrieves all running scheduled tasks and displays their names, last run times, and how long they have been
        running.

    .INPUTS
        Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        You can pipe ScheduledTask objects to Get-StmScheduledTaskInfo.

    .OUTPUTS
        PSCustomObject
        Returns custom objects containing merged information from both scheduled task and scheduled task info objects:
        - TaskName: The name of the scheduled task
        - TaskPath: The path of the task in Task Scheduler
        - TaskState: The current state of the task
        - LastRunTime: The last time the task was executed
        - LastTaskResult: The result of the last task execution
        - NextRunTime: The next scheduled run time
        - NumberOfMissedRuns: The number of times the task failed to run
        - RunningDuration: TimeSpan showing how long the task has been running (null if not running)
        - ScheduledTaskObject: The underlying scheduled task object
        - ScheduledTaskInfoObject: The underlying scheduled task info object

    .NOTES
        This function requires:
        - Appropriate permissions to access scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer

        The function uses Get-StmScheduledTask internally to retrieve the task and then calls Get-ScheduledTaskInfo
        to get detailed execution information.
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByParameters')]
    param (
        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ByParameters'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ByParameters'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ByParameters'
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]
        $TaskState,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ByParameters'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName = 'localhost',

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ByParameters'
        )]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = 'ByInputObject'
        )]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]
        $InputObject
    )

    begin {
        Write-Verbose 'Starting Get-StmScheduledTaskInfo'
        if ($PSCmdlet.ParameterSetName -eq 'ByParameters') {
            $stmScheduledTaskParameters = @{
                ComputerName = $ComputerName
            }

            if ($PSBoundParameters.ContainsKey('TaskName')) {
                Write-Verbose "Filtering tasks by name: '$TaskName'"
                $stmScheduledTaskParameters['TaskName'] = $TaskName
            }
            else {
                Write-Verbose 'Retrieving all tasks'
            }

            if ($PSBoundParameters.ContainsKey('TaskPath')) {
                Write-Verbose "Filtering tasks by path: '$TaskPath'"
                $stmScheduledTaskParameters['TaskPath'] = $TaskPath
            }
            else {
                Write-Verbose 'No specific task path filter applied'
            }

            if ($PSBoundParameters.ContainsKey('TaskState')) {
                Write-Verbose "Filtering tasks by state: '$TaskState'"
                $stmScheduledTaskParameters['TaskState'] = $TaskState
            }
            else {
                Write-Verbose 'No specific task state filter applied'
            }

            if ($PSBoundParameters.ContainsKey('Credential')) {
                Write-Verbose 'Using provided credentials'
                $stmScheduledTaskParameters['Credential'] = $Credential
            }
            else {
                Write-Verbose 'Using current user credentials'
            }

            $scheduledTasks = Get-StmScheduledTask @stmScheduledTaskParameters
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByInputObject') {
            $scheduledTasks = $InputObject
        }

        if ($scheduledTasks.Count -eq 0) {
            Write-Warning 'No scheduled tasks found with the specified parameters.'
            return
        }

        Write-Verbose "Retrieving scheduled task info for $($scheduledTasks.Count) task(s)"

        foreach ($task in $scheduledTasks) {
            try {
                $scheduledTaskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath

                Write-Verbose "Merging properties for task '$($task.TaskName)'"
                $mergeParameters = @{
                    FirstObject      = $task
                    FirstObjectName  = 'ScheduledTaskObject'
                    SecondObject     = $scheduledTaskInfo
                    SecondObjectName = 'ScheduledTaskInfoObject'
                    AsHashtable      = $true
                    ErrorAction      = 'Stop'
                }
                $mergedHashtable = Merge-Object @mergeParameters

                # Ensure top-level TaskName property for consistency
                if (-not ($mergedHashtable.Keys -contains 'TaskName') -and
                    ($mergedHashtable.Keys -contains 'ScheduledTaskObject')) {
                    $mergedHashtable['TaskName'] = $mergedHashtable['ScheduledTaskObject'].TaskName
                }

                # If TaskName is a hashtable (from merge conflict), set it to the value from ScheduledTaskObject
                if ($mergedHashtable['TaskName'] -is [hashtable] -and
                    ($mergedHashtable.Keys -contains 'ScheduledTaskObject')) {
                    $mergedHashtable['TaskName'] = $mergedHashtable['ScheduledTaskObject'].TaskName
                }

                # Calculate running duration if task is currently running
                if ($task.State -and
                    ([string]$task.State) -eq 'Running' -and
                    ($mergedHashtable.Keys -contains 'LastRunTime') -and
                    ($null -ne $mergedHashtable['LastRunTime'])) {

                    $runningDuration = (Get-Date) - $mergedHashtable['LastRunTime']
                    $mergedHashtable['RunningDuration'] = $runningDuration
                    Write-Verbose (
                        "Task '$($mergedHashtable['TaskName'])' has been running for $($runningDuration.ToString())"
                    )
                }
                else {
                    $mergedHashtable['RunningDuration'] = $null
                }

                [PSCustomObject]$mergedHashtable
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'ScheduledTaskInfoRetrievalFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                    TargetObject      = $task.TaskName
                    Message           = (
                        "Failed to retrieve scheduled task info for task '$($task.TaskName)'. " +
                        "$($_.Exception.Message)"
                    )
                    RecommendedAction = (
                        'Verify the task exists and that you have permission to access the scheduled task.'
                    )
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
    }

    end {
        Write-Verbose 'Finished Get-StmScheduledTaskInfo'
    }
}
