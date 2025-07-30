function Get-StmScheduledTaskRun {
    <#
    .SYNOPSIS
        Retrieves run history for scheduled tasks on a local or remote computer.

    .DESCRIPTION
        The Get-StmScheduledTaskRun function retrieves information about the execution history of scheduled tasks
        from the Windows Task Scheduler. It queries the Task Scheduler event log to provide details about task runs,
        including start and end times, status, and results. You can filter by task name and target a specific computer.
        Optionally, credentials can be supplied for remote queries.

    .PARAMETER TaskName
        The name of the scheduled task to retrieve run history for. If not specified, retrieves run history for all tasks.

    .PARAMETER ComputerName
        The name of the computer to query. If not specified, the local computer is used.

    .PARAMETER Credential
        The credentials to use when connecting to the remote computer. If not specified, the current user's credentials are used.

    .PARAMETER MaxRuns
        The maximum number of task runs to return per task. If not specified, all available runs are returned.

    .EXAMPLE
        Get-StmScheduledTaskRun -TaskName "MyTask"

        Retrieves the run history for the scheduled task named "MyTask" on the local computer.

    .EXAMPLE
        Get-StmScheduledTaskRun -ComputerName "Server01"

        Retrieves the run history for all scheduled tasks on the remote computer "Server01".

    .EXAMPLE
        $creds = Get-Credential
        Get-StmScheduledTaskRun -TaskName "BackupTask" -ComputerName "Server02" -Credential $creds

        Retrieves the run history for the "BackupTask" scheduled task on "Server02" using the specified credentials.

    .EXAMPLE
        Get-StmScheduledTaskRun -TaskName "MyTask" -MaxRuns 5

        Retrieves the 5 most recent runs for the scheduled task named "MyTask" on the local computer.

    .INPUTS
        None. You cannot pipe objects to Get-StmScheduledTaskRun.

    .OUTPUTS
        PSCustomObject
        Returns objects containing details about each scheduled task run, including task name, start time, end time, status, and result.

    .NOTES
        This function requires access to the Microsoft-Windows-TaskScheduler/Operational event log on the target computer.
        Remote queries require appropriate permissions and network connectivity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName = 'localhost',

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $MaxRuns
    )

    begin {
        Write-Verbose 'Starting Get-StmScheduledTaskRun'
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

        $cimSessionParameters = @{
            ErrorAction = 'Stop'
        }
        $getWinEventCommonParameters = @{
            LogName     = 'Microsoft-Windows-TaskScheduler/Operational'
            ErrorAction = 'Stop'
        }
        $cimSessionParameters['ComputerName'] = $ComputerName
        if ($PSBoundParameters.ContainsKey('ComputerName')) {
            Write-Verbose "Using provided computer name '$ComputerName'"
            $getWinEventCommonParameters['ComputerName'] = $ComputerName
        }
        else {
            Write-Verbose 'Using local computer'
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            Write-Verbose 'Using provided credential'
            $cimSessionParameters['Credential'] = $Credential
            $getWinEventCommonParameters['Credential'] = $Credential
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
            Write-Verbose "Retrieved $($scheduledTasks.Count) task(s)"
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ScheduledTaskRetrievalFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $TaskName
                Message           = "Failed to retrieve scheduled tasks. $($_.Exception.Message)"
                RecommendedAction = 'Verify the task name is correct and that you have permission to access the scheduled tasks.'
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        if ($null -eq $scheduledTasks -or $scheduledTasks.Count -eq 0) {
            Write-Verbose 'No scheduled tasks found.'
            return # Exit early if no tasks are found
        }

        # Use a stack to process tasks in LIFO order
        $scheduledTasksToProcess = New-Object -TypeName 'System.Collections.Stack'
        $scheduledTasks | ForEach-Object {
            $scheduledTasksToProcess.Push($_)
        }

        # Iterate through the stack to process each task
        Write-Verbose "Processing $($scheduledTasksToProcess.Count) scheduled task(s) for last run information"
        while ($scheduledTasksToProcess.Count -gt 0) {
            $currentTask = $scheduledTasksToProcess.Pop()
            Write-Verbose "Processing task '$($currentTask.TaskName)'"
            try {
                Write-Verbose "Getting scheduled task information for task '$($currentTask.TaskName)'"
                $currentTaskInfo = $currentTask | Get-ScheduledTaskInfo -ErrorAction 'Continue'
                if ($null -eq $currentTaskInfo) {
                    Write-Verbose "No scheduled task information found for task '$($currentTask.TaskName)'"
                }
                else {
                    Write-Verbose "Scheduled task information for task '$($currentTask.TaskName)': $($currentTaskInfo | Out-String)"
                }

                Write-Verbose "Retrieving all events for task '$($currentTask.TaskName)' from the Task Scheduler Operational log"
                Write-Verbose "Log Name: $($getWinEventCommonParameters['LogName'])"
                $allEventsXPathParameters = @{
                    NamedDataFilter = @{
                        TaskName = $currentTask.URI
                    }
                }
                $allEventsXPathFilter = Get-WinEventXPathFilter @allEventsXPathParameters
                Write-Verbose "XPath filter for all events of task '$($currentTask.TaskName)': $allEventsXPathFilter"
                $taskEventsParameters = @{
                    FilterXPath = $allEventsXPathFilter
                }
                $taskEvents = Get-WinEvent @taskEventsParameters @getWinEventCommonParameters
                Write-Verbose "Retrieved $($taskEvents.Count) event(s) for task '$($currentTask.TaskName)'"

                if ($null -eq $taskEvents -or $taskEvents.Count -eq 0) {
                    Write-Verbose "No events found for task '$($currentTask.TaskName)'"
                    continue # Skip to the next task if no events are found
                }

                $uniqueActivityIds = $taskEvents | Select-Object -ExpandProperty 'ActivityId' -Unique
                Write-Verbose "Found $($uniqueActivityIds.Count) unique activity ID(s) for task '$($currentTask.TaskName)'"

                # Limit the number of activity IDs if MaxRuns is specified
                if ($PSBoundParameters.ContainsKey('MaxRuns')) {
                    Write-Verbose "Limiting to $MaxRuns most recent runs for task '$($currentTask.TaskName)'"
                    $uniqueActivityIds = $uniqueActivityIds | Select-Object -First $MaxRuns
                    Write-Verbose "Limited to $($uniqueActivityIds.Count) activity ID(s) for task '$($currentTask.TaskName)'"
                }

                foreach ($activityId in $uniqueActivityIds) {
                    Write-Verbose "Processing activity ID '$activityId' for task '$($currentTask.TaskName)'"
                    $runDetails = [ordered]@{
                        TaskName             = $currentTask.TaskName
                        ActivityId           = $activityId
                        ResultCode           = $null
                        StartTime            = $null
                        EndTime              = $null
                        Duration             = $null
                        DurationSeconds      = $null
                        LaunchRequestIgnored = $null
                        Events               = $null
                        EventCount           = $null
                        EventXml             = $null
                    }
                    $activityEvents = $taskEvents | Where-Object { $_.ActivityId -eq $activityId }
                    Write-Verbose "Found $($activityEvents.Count) event(s) for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    if ($activityEvents.Count -eq 0) {
                        Write-Verbose "No events found for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        continue # Skip to the next activity ID if no events are found
                    }

                    # Find the start and end events for the activity ID
                    # The Windows Event Log returns events from newest to oldest so the first event is the most recent
                    # Sort the events by RecordId to be safe
                    Write-Verbose "Sorting events by RecordId for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    $sortedEvents = $activityEvents | Sort-Object -Property 'RecordId' -Descending
                    Write-Verbose "Finding the start event for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    $startEvent = $sortedEvents | Select-Object -Last 1
                    Write-Verbose "Start event for activity ID '$activityId' of task '$($currentTask.TaskName)': $($startEvent | Out-String)"
                    Write-Verbose "Finding the end event for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    $endEvent = $sortedEvents | Select-Object -First 1
                    Write-Verbose "End event for activity ID '$activityId' of task '$($currentTask.TaskName)': $($endEvent | Out-String)"

                    # Some events may not have an ActivityId, so we need to handle that case
                    # For example, event ID 129 (Created Task Process) does not have an ActivityId
                    # We assume no unrelated events exist between the start and end events (🤞)
                    Write-Verbose "Finding events between the start and end events of task '$($currentTask.TaskName)' that do not have an ActivityId"
                    $eventsWithoutActivityId = $taskEvents | Where-Object {
                        $null -eq $_.ActivityId -and
                        $_.RecordId -gt $startEvent.RecordId -and
                        $_.RecordId -lt $endEvent.RecordId
                    }
                    Write-Verbose "Found $($eventsWithoutActivityId.Count) event(s) without ActivityId for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    if ($eventsWithoutActivityId.Count -gt 0) {
                        Write-Verbose "Adding events without ActivityId to run details for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        $sortedEvents += $eventsWithoutActivityId
                        $sortedEvents = $sortedEvents | Sort-Object -Property 'TimeCreated' -Descending
                    }

                    # Add all of the events to the run details
                    Write-Verbose "Adding events to run details for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    $runDetails['Events'] = $sortedEvents
                    $runDetails['EventCount'] = $sortedEvents.Count
                    $runDetails['EventXml'] = $sortedEvents | ForEach-Object {
                        # Convert each event to XML for more detailed information
                        Write-Verbose "Converting event with RecordId '$($_.RecordId)' to XML for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        $xml = $_.ToXml()
                        if ($null -eq $xml) {
                            Write-Verbose "Event with RecordId '$($_.RecordId)' has no XML representation"
                            $null
                        }
                        else {
                            Write-Verbose "Event with RecordId '$($_.RecordId)' converted to XML"
                            [xml]$xml
                        }
                    }
                    Write-Verbose "Added $($sortedEvents.Count) event(s) to run details for activity ID '$activityId' of task '$($currentTask.TaskName)'"

                    # Add the result code
                    $resultCode = $runDetails['EventXml'].Event.EventData.Data | Where-Object {
                        $_.Name -eq 'ResultCode'
                    } | Select-Object -ExpandProperty '#text' -Unique
                    if ($null -eq $resultCode -or $resultCode.Count -eq 0 -or [string]::IsNullOrEmpty($resultCode[0])) {
                        Write-Verbose "No ResultCode found for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    }
                    elseif ($resultCode.Count -gt 1) {
                        Write-Verbose "Multiple ResultCode(s) found for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        $runDetails['ResultCode'] = $resultCode | Select-Object -ExpandProperty 'ResultCode' -Unique
                        Write-Verbose "Using multiple ResultCode(s): $($runDetails['ResultCode'] | Out-String)"
                    }
                    else {
                        Write-Verbose "Single ResultCode found for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        $runDetails['ResultCode'] = $resultCode
                        Write-Verbose "Using ResultCode '$($runDetails['ResultCode'])' for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    }

                    # Add the start and end times
                    $startTime = $startEvent.TimeCreated
                    $endTime = $endEvent.TimeCreated
                    Write-Verbose "Start time for activity ID '$activityId' of task '$($currentTask.TaskName)': $startTime"
                    Write-Verbose "End time for activity ID '$activityId' of task '$($currentTask.TaskName)': $endTime"
                    $runDetails['StartTime'] = $startTime
                    $runDetails['EndTime'] = $endTime

                    # Add the duration
                    $runDetails['Duration'] = $endTime - $startTime
                    $runDetails['DurationSeconds'] = [math]::Round($runDetails['Duration'].TotalSeconds, 2)
                    Write-Verbose "Duration for activity ID '$activityId' of task '$($currentTask.TaskName)': $($runDetails['Duration'])"

                    # Check if the task was launched or ignored
                    $launchRequestIgnoredEvent = $sortedEvents | Where-Object {
                        $_.TaskDisplayName -eq 'Launch request ignored, instance already running'
                    }
                    if ($null -ne $launchRequestIgnoredEvent) {
                        Write-Verbose "Launch request ignored event found for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        $runDetails['LaunchRequestIgnored'] = $true
                    }
                    else {
                        Write-Verbose "No launch request ignored event found for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                        $runDetails['LaunchRequestIgnored'] = $false
                    }

                    # Return the run details
                    Write-Verbose "Returning run details for activity ID '$activityId' of task '$($currentTask.TaskName)'"
                    [PSCustomObject]$runDetails
                }
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'ScheduledTaskRunRetrievalFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                    TargetObject      = $currentTask.TaskName
                    Message           = "Failed to retrieve scheduled task run information for task '$($currentTask.TaskName)'. $($_.Exception.Message)"
                    RecommendedAction = 'Verify the task name is correct and that you have permission to access the scheduled tasks.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                Write-Error -ErrorRecord $errorRecord
            }
        }
    }

    end {
        Write-Verbose 'Completed Get-StmScheduledTaskRun'
        if ($null -ne $cimSession) {
            Write-Verbose 'Closing CIM session'
            $cimSession | Remove-CimSession -ErrorAction 'SilentlyContinue'
        }
        else {
            Write-Verbose 'No CIM session to close'
        }
    }
}
