function Import-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Imports clustered scheduled tasks from XML to a Windows failover cluster.

    .DESCRIPTION
        The Import-StmClusteredScheduledTask function imports clustered scheduled tasks from XML definitions
        to a Windows failover cluster. This function supports three modes of operation:

        - Single file import: Import a task from a single XML file using the -Path parameter
        - XML string import: Import a task from an XML string using the -Xml parameter
        - Bulk directory import: Import all XML files from a directory using the -DirectoryPath parameter

        The function extracts the task name from the XML's RegistrationInfo/URI element by default, but allows
        overriding the task name for single imports using the -TaskName parameter. When a task with the same
        name already exists, the function will error unless the -Force parameter is specified, which causes
        the existing task to be unregistered before importing the new one.

        For bulk directory imports, the function processes all .xml files in the specified directory, reports
        progress, and continues processing even if individual tasks fail to import. A summary object is
        returned with details about successful and failed imports.

    .PARAMETER Path
        Specifies the path to a single XML file containing the scheduled task definition. The file must exist
        and contain valid Task Scheduler XML format. This parameter is mandatory when using the XmlFile
        parameter set.

    .PARAMETER Xml
        Specifies the XML content defining the scheduled task configuration. The XML should follow the Task
        Scheduler schema format. This parameter is mandatory when using the XmlString parameter set.

    .PARAMETER DirectoryPath
        Specifies the path to a directory containing XML files to import. All files with the .xml extension
        in the directory will be processed. This parameter is mandatory when using the Directory parameter
        set. The -TaskName parameter cannot be used with this parameter.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the tasks will be registered. This parameter is
        mandatory for all parameter sets.

    .PARAMETER TaskType
        Specifies the type of clustered scheduled task to register. Valid values are:
        - ResourceSpecific: Task runs on a specific cluster resource
        - AnyNode: Task can run on any node in the cluster
        - ClusterWide: Task runs across the entire cluster
        This parameter is mandatory for all parameter sets.

    .PARAMETER TaskName
        Optionally overrides the task name extracted from the XML's RegistrationInfo/URI element. This
        parameter is only applicable to single file or XML string imports and cannot be used with the
        -DirectoryPath parameter.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current user's
        credentials will be used for the connection.

    .PARAMETER Force
        Overwrites existing tasks with the same name. Without this parameter, an error occurs if a task
        with the same name already exists on the cluster. When specified, the existing task is unregistered
        before importing the new task definition.

    .EXAMPLE
        Import-StmClusteredScheduledTask -Path 'C:\Tasks\BackupTask.xml' -Cluster 'MyCluster' -TaskType 'AnyNode'

        Imports a single clustered scheduled task from an XML file. The task name is extracted from the XML's
        URI element.

    .EXAMPLE
        Import-StmClusteredScheduledTask -Path 'C:\Tasks\Task.xml' -Cluster 'MyCluster' -TaskType 'AnyNode' -TaskName 'CustomName'

        Imports a clustered scheduled task from an XML file, overriding the task name with 'CustomName'.

    .EXAMPLE
        Import-StmClusteredScheduledTask -DirectoryPath 'C:\Tasks\' -Cluster 'MyCluster' -TaskType 'ClusterWide' -Force

        Imports all XML files from the specified directory as clustered scheduled tasks. The -Force parameter
        ensures any existing tasks with the same names are replaced.

    .EXAMPLE
        $xml = Get-Content -Path 'C:\Tasks\Task.xml' -Raw
        Import-StmClusteredScheduledTask -Xml $xml -Cluster 'MyCluster' -TaskType 'AnyNode'

        Imports a clustered scheduled task from an XML string variable.

    .EXAMPLE
        $credential = Get-Credential
        Import-StmClusteredScheduledTask -Path 'C:\Tasks\Task.xml' -Cluster 'MyCluster.contoso.com' -TaskType 'ResourceSpecific' -Credential $credential -Force

        Imports a clustered scheduled task using specified credentials, replacing any existing task with the
        same name.

    .INPUTS
        None. You cannot pipe objects to Import-StmClusteredScheduledTask.

    .OUTPUTS
        Microsoft.Management.Infrastructure.CimInstance#MSFT_ClusteredScheduledTask
        For single file or XML string imports, returns the registered clustered scheduled task object.

        PSCustomObject
        For directory imports, returns a summary object with the following properties:
        - TotalFiles: The total number of XML files found
        - SuccessCount: The number of successfully imported tasks
        - FailureCount: The number of tasks that failed to import
        - ImportedTasks: Array of successfully imported task names
        - FailedTasks: Array of objects describing failed imports (FileName, TaskName, Error)

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to register clustered scheduled tasks
        - Network connectivity to the cluster
        - Valid Task Scheduler XML format for the task definitions

        The XML definitions must follow the Task Scheduler schema and should contain a RegistrationInfo/URI
        element for automatic task name extraction. If the URI element is missing and -TaskName is not
        specified, the import will fail.

        When importing from a directory, the function uses non-terminating errors for individual task
        failures, allowing the import to continue with remaining files. Check the returned summary object
        for details about any failures.

    .LINK
        Export-StmClusteredScheduledTask

    .LINK
        Register-StmClusteredScheduledTask

    .LINK
        Unregister-StmClusteredScheduledTask

    .LINK
        Get-StmClusteredScheduledTask
    #>

    [CmdletBinding(DefaultParameterSetName = 'XmlFile', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'XmlFile')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'XmlString')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Xml,

        [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
        [ValidateNotNullOrEmpty()]
        [string]
        $DirectoryPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cluster,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.ClusterTaskTypeEnum]
        $TaskType,

        [Parameter(Mandatory = $false, ParameterSetName = 'XmlFile')]
        [Parameter(Mandatory = $false, ParameterSetName = 'XmlString')]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    begin {
        Write-Verbose "Starting Import-StmClusteredScheduledTask on cluster '$Cluster'"

        # Validate that TaskName is not used with Directory parameter set
        if ($PSCmdlet.ParameterSetName -eq 'Directory' -and $PSBoundParameters.ContainsKey('TaskName')) {
            $errorMsg = (
                'The -TaskName parameter cannot be used with -DirectoryPath. ' +
                'Task names are extracted from each XML file.'
            )
            $errorRecordParameters = @{
                Exception         = [System.ArgumentException]::new($errorMsg)
                ErrorId           = 'InvalidParameterCombination'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::InvalidArgument
                TargetObject      = $DirectoryPath
                Message           = $errorMsg
                RecommendedAction = (
                    'Remove the -TaskName parameter when using -DirectoryPath, ' +
                    'or use -Path for single file import with a custom task name.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Validate file/directory exists based on parameter set
        if ($PSCmdlet.ParameterSetName -eq 'XmlFile') {
            if (-not (Test-Path -Path $Path -PathType Leaf)) {
                $exceptionMessage = "The file '$Path' was not found."
                $errorRecordParameters = @{
                    Exception         = [System.IO.FileNotFoundException]::new($exceptionMessage)
                    ErrorId           = 'XmlFileNotFound'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    TargetObject      = $Path
                    Message           = "The XML file '$Path' does not exist or is not accessible."
                    RecommendedAction = 'Verify the file path is correct and the file exists.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Directory') {
            if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
                $exceptionMessage = "The directory '$DirectoryPath' was not found."
                $errorRecordParameters = @{
                    Exception         = [System.IO.DirectoryNotFoundException]::new($exceptionMessage)
                    ErrorId           = 'DirectoryNotFound'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    TargetObject      = $DirectoryPath
                    Message           = (
                        "The directory '$DirectoryPath' does not exist or is not accessible."
                    )
                    RecommendedAction = (
                        'Verify the directory path is correct and the directory exists.'
                    )
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'XmlFile' {
                Write-Verbose "Importing task from file: $Path"
                try {
                    $xmlContent = Get-Content -Path $Path -Raw -ErrorAction 'Stop'
                }
                catch {
                    $errorRecordParameters = @{
                        Exception         = $_.Exception
                        ErrorId           = 'XmlFileReadFailed'
                        ErrorCategory     = [System.Management.Automation.ErrorCategory]::ReadError
                        TargetObject      = $Path
                        Message           = "Failed to read XML file '$Path'. $($_.Exception.Message)"
                        RecommendedAction = 'Verify you have read permissions for the file and the file is not locked.'
                    }
                    $errorRecord = New-StmError @errorRecordParameters
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                Import-SingleTask -XmlContent $xmlContent -Cluster $Cluster -TaskType $TaskType `
                    -TaskNameOverride $TaskName -Credential $Credential -Force:$Force
            }

            'XmlString' {
                Write-Verbose 'Importing task from XML string'
                Import-SingleTask -XmlContent $Xml -Cluster $Cluster -TaskType $TaskType `
                    -TaskNameOverride $TaskName -Credential $Credential -Force:$Force
            }

            'Directory' {
                Write-Verbose "Importing tasks from directory: $DirectoryPath"

                $xmlFiles = Get-ChildItem -Path $DirectoryPath -Filter '*.xml' -File
                $totalFiles = $xmlFiles.Count

                if ($totalFiles -eq 0) {
                    Write-Warning "No XML files found in directory '$DirectoryPath'"
                    return [PSCustomObject]@{
                        TotalFiles    = 0
                        SuccessCount  = 0
                        FailureCount  = 0
                        ImportedTasks = @()
                        FailedTasks   = @()
                    }
                }

                Write-Verbose "Found $totalFiles XML file(s) to import"

                $activity = "Importing clustered scheduled tasks from '$DirectoryPath'"
                $successCount = 0
                $importedTasks = [System.Collections.Generic.List[string]]::new()
                $failedTasks = [System.Collections.Generic.List[PSCustomObject]]::new()

                for ($i = 0; $i -lt $totalFiles; $i++) {
                    $xmlFile = $xmlFiles[$i]
                    $percentComplete = [math]::Round((($i + 1) / $totalFiles) * 100)
                    $status = "Processing file $($i + 1) of $totalFiles`: $($xmlFile.Name)"

                    Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete

                    $extractedName = $null
                    try {
                        $xmlContent = Get-Content -Path $xmlFile.FullName -Raw -ErrorAction 'Stop'
                        $extractedName = Get-TaskNameFromXml -XmlContent $xmlContent

                        if ([string]::IsNullOrWhiteSpace($extractedName)) {
                            throw (
                                'Could not extract task name from XML. ' +
                                'The RegistrationInfo/URI element is missing or empty.'
                            )
                        }

                        $importParams = @{
                            XmlContent  = $xmlContent
                            Cluster     = $Cluster
                            TaskType    = $TaskType
                            Credential  = $Credential
                            Force       = $Force
                            ErrorAction = 'Stop'
                        }
                        $null = Import-SingleTask @importParams

                        $successCount++
                        $importedTasks.Add($extractedName)
                        Write-Verbose "Successfully imported task '$extractedName' from '$($xmlFile.Name)'"
                    }
                    catch {
                        $failedTask = [PSCustomObject]@{
                            FileName = $xmlFile.Name
                            TaskName = $extractedName
                            Error    = $_.Exception.Message
                        }
                        $failedTasks.Add($failedTask)
                        Write-Warning "Failed to import task from '$($xmlFile.Name)': $($_.Exception.Message)"
                    }
                }

                Write-Progress -Activity $activity -Completed

                Write-Verbose "Import completed: $successCount of $totalFiles task(s) imported successfully"

                if ($failedTasks.Count -gt 0) {
                    $warningMessage = (
                        "$($failedTasks.Count) task(s) failed to import. " +
                        'See FailedTasks property for details.'
                    )
                    Write-Warning $warningMessage
                }

                [PSCustomObject]@{
                    TotalFiles    = $totalFiles
                    SuccessCount  = $successCount
                    FailureCount  = $failedTasks.Count
                    ImportedTasks = $importedTasks.ToArray()
                    FailedTasks   = $failedTasks.ToArray()
                }
            }
        }
    }

    end {
        Write-Verbose 'Completed Import-StmClusteredScheduledTask'
    }
}

function Import-SingleTask {
    <#
    .SYNOPSIS
        Internal helper function to import a single clustered scheduled task.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $XmlContent,

        [Parameter(Mandatory = $true)]
        [string]
        $Cluster,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.ClusterTaskTypeEnum]
        $TaskType,

        [Parameter(Mandatory = $false)]
        [string]
        $TaskNameOverride,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    # Determine effective task name
    if (-not [string]::IsNullOrWhiteSpace($TaskNameOverride)) {
        $effectiveTaskName = $TaskNameOverride
        Write-Verbose "Using provided task name override: '$effectiveTaskName'"
    }
    else {
        $effectiveTaskName = Get-TaskNameFromXml -XmlContent $XmlContent
        if ([string]::IsNullOrWhiteSpace($effectiveTaskName)) {
            $errorRecordParameters = @{
                Exception         = [System.InvalidOperationException]::new(
                    'Could not determine task name from XML.'
                )
                ErrorId           = 'TaskNameNotFound'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::InvalidData
                TargetObject      = $XmlContent
                Message           = (
                    'Could not extract task name from XML. ' +
                    'The RegistrationInfo/URI element is missing or empty.'
                )
                RecommendedAction = (
                    'Ensure the XML contains a valid RegistrationInfo/URI element, ' +
                    'or use the -TaskName parameter to specify the task name.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        Write-Verbose "Extracted task name from XML: '$effectiveTaskName'"
    }

    # Check if task already exists
    $existingTask = $null
    try {
        $getTaskParams = @{
            TaskName    = $effectiveTaskName
            Cluster     = $Cluster
            ErrorAction = 'Stop'
        }
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $getTaskParams['Credential'] = $Credential
        }
        $existingTask = Get-StmClusteredScheduledTask @getTaskParams
    }
    catch {
        # Task doesn't exist, which is fine
        Write-Verbose "Task '$effectiveTaskName' does not exist on cluster '$Cluster'"
        $existingTask = $null
    }

    if ($null -ne $existingTask) {
        if ($Force) {
            Write-Verbose "Task '$effectiveTaskName' exists. -Force specified, unregistering existing task..."
            $target = "Task '$effectiveTaskName' on cluster '$Cluster'"
            $operation = 'Unregister existing clustered scheduled task'
            if ($PSCmdlet.ShouldProcess($target, $operation)) {
                $unregisterParams = @{
                    TaskName    = $effectiveTaskName
                    Cluster     = $Cluster
                    ErrorAction = 'Stop'
                }
                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                    $unregisterParams['Credential'] = $Credential
                }
                Unregister-StmClusteredScheduledTask @unregisterParams
                Write-Verbose "Existing task '$effectiveTaskName' unregistered"
            }
        }
        else {
            $exceptionMessage = (
                "A clustered scheduled task named '$effectiveTaskName' " +
                "already exists on cluster '$Cluster'."
            )
            $errorRecordParameters = @{
                Exception         = [System.InvalidOperationException]::new($exceptionMessage)
                ErrorId           = 'TaskAlreadyExists'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::ResourceExists
                TargetObject      = $effectiveTaskName
                Message           = "$exceptionMessage Use -Force to overwrite."
                RecommendedAction = (
                    'Use the -Force parameter to overwrite the existing task, ' +
                    'or choose a different task name with -TaskName.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    # Register the task
    $target = "cluster '$Cluster'"
    $operation = "Import clustered scheduled task '$effectiveTaskName'"
    if ($PSCmdlet.ShouldProcess($target, $operation)) {
        try {
            $cimSession = New-StmCimSession -ComputerName $Cluster -Credential $Credential -ErrorAction 'Stop'
            Write-Verbose "CIM session established to cluster '$Cluster'"

            Write-Verbose "Registering clustered scheduled task '$effectiveTaskName'..."
            $registerParams = @{
                TaskName    = $effectiveTaskName
                Xml         = $XmlContent
                CimSession  = $cimSession
                TaskType    = $TaskType
                ErrorAction = 'Stop'
            }
            $result = Register-ClusteredScheduledTask @registerParams
            Write-Verbose "Successfully imported task '$effectiveTaskName'"
            return $result
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'TaskRegistrationFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::OperationStopped
                TargetObject      = $effectiveTaskName
                Message           = (
                    "Failed to register clustered scheduled task '$effectiveTaskName' " +
                    "on cluster '$Cluster'. $($_.Exception.Message)"
                )
                RecommendedAction = (
                    'Verify the XML is valid Task Scheduler format, ' +
                    'the cluster is accessible, and you have appropriate permissions.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}
