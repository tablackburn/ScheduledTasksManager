function Import-StmScheduledTask {
    <#
    .SYNOPSIS
        Imports scheduled tasks from XML to a local or remote computer.

    .DESCRIPTION
        The Import-StmScheduledTask function imports scheduled tasks from XML definitions to a local or
        remote computer. This function supports three modes of operation:

        - Single file import: Import a task from a single XML file using the -XmlPath parameter
        - XML string import: Import a task from an XML string using the -Xml parameter
        - Bulk directory import: Import all XML files from a directory using the -DirectoryPath parameter

        The function extracts the task name from the XML's RegistrationInfo/URI element by default, but
        allows overriding the task name for single imports using the -TaskName parameter. When a task
        with the same name already exists, the function will error unless the -Force parameter is
        specified, which causes the existing task to be unregistered before importing the new one.

        For bulk directory imports, the function processes all .xml files in the specified directory,
        reports progress, and continues processing even if individual tasks fail to import. A summary
        object is returned with details about successful and failed imports.

    .PARAMETER XmlPath
        Specifies the path to a single XML file containing the scheduled task definition. The file must
        exist and contain valid Task Scheduler XML format. This parameter is mandatory when using the
        XmlFile parameter set.

    .PARAMETER Xml
        Specifies the XML content defining the scheduled task configuration. The XML should follow the
        Task Scheduler schema format. This parameter is mandatory when using the XmlString parameter set.

    .PARAMETER DirectoryPath
        Specifies the path to a directory containing XML files to import. All files with the .xml
        extension in the directory will be processed. This parameter is mandatory when using the
        Directory parameter set. The -TaskName parameter cannot be used with this parameter.

    .PARAMETER TaskName
        Optionally overrides the task name extracted from the XML's RegistrationInfo/URI element.
        This parameter is only applicable to single file or XML string imports and cannot be used
        with the -DirectoryPath parameter.

    .PARAMETER TaskPath
        Specifies the path where the scheduled task will be registered. The task path represents the
        folder structure in the Task Scheduler (e.g., '\Custom\Tasks\'). If not specified, the root
        path ('\') will be used.

    .PARAMETER ComputerName
        Specifies the name of the computer on which to register the scheduled task. If not specified,
        the local computer ('localhost') is used.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not provided, the current
        user's credentials will be used for the connection.

    .PARAMETER Force
        Overwrites existing tasks with the same name. Without this parameter, an error occurs if a task
        with the same name already exists. When specified, the existing task is unregistered before
        importing the new task definition.

    .EXAMPLE
        Import-StmScheduledTask -XmlPath 'C:\Tasks\BackupTask.xml'

        Imports a single scheduled task from an XML file. The task name is extracted from the XML's
        URI element.

    .EXAMPLE
        $params = @{
            XmlPath  = 'C:\Tasks\Task.xml'
            TaskName = 'CustomName'
            TaskPath = '\Custom\Tasks\'
        }
        Import-StmScheduledTask @params

        Imports a scheduled task from an XML file with a custom name and task path.

    .EXAMPLE
        Import-StmScheduledTask -DirectoryPath 'C:\Tasks\' -Force

        Imports all XML files from the specified directory as scheduled tasks. The -Force parameter
        ensures any existing tasks with the same names are replaced.

    .EXAMPLE
        $xml = Get-Content -Path 'C:\Tasks\Task.xml' -Raw
        Import-StmScheduledTask -Xml $xml

        Imports a scheduled task from an XML string variable.

    .EXAMPLE
        $credential = Get-Credential
        $params = @{
            XmlPath      = 'C:\Tasks\Task.xml'
            ComputerName = 'Server01'
            Credential   = $credential
            Force        = $true
        }
        Import-StmScheduledTask @params

        Imports a scheduled task to a remote computer using specified credentials, replacing any
        existing task with the same name.

    .INPUTS
        None. You cannot pipe objects to Import-StmScheduledTask.

    .OUTPUTS
        Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        For single file or XML string imports, returns the registered scheduled task object.

        PSCustomObject
        For directory imports, returns a summary object with the following properties:
        - TotalFiles: The total number of XML files found
        - SuccessCount: The number of successfully imported tasks
        - FailureCount: The number of tasks that failed to import
        - ImportedTasks: Array of successfully imported task names
        - FailedTasks: Array of objects describing failed imports (FileName, TaskName, Error)

    .NOTES
        This function requires:
        - Appropriate permissions to register scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - Valid Task Scheduler XML format for the task definitions

        The XML definitions must follow the Task Scheduler schema and should contain a RegistrationInfo/URI
        element for automatic task name extraction. If the URI element is missing and -TaskName is not
        specified, the import will fail.

        When importing from a directory, the function uses non-terminating errors for individual task
        failures, allowing the import to continue with remaining files. Check the returned summary object
        for details about any failures.

    .LINK
        Export-StmScheduledTask

    .LINK
        Register-StmScheduledTask

    .LINK
        Unregister-StmScheduledTask
    #>

    [CmdletBinding(DefaultParameterSetName = 'XmlFile', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'XmlFile')]
        [ValidateNotNullOrEmpty()]
        [string]
        $XmlPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'XmlString')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Xml,

        [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
        [ValidateNotNullOrEmpty()]
        [string]
        $DirectoryPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'XmlFile')]
        [Parameter(Mandatory = $false, ParameterSetName = 'XmlString')]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath = '\',

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
        [switch]
        $Force
    )

    begin {
        Write-Verbose "Starting Import-StmScheduledTask on computer '$ComputerName'"

        # Validate file/directory exists based on parameter set
        if ($PSCmdlet.ParameterSetName -eq 'XmlFile') {
            if (-not (Test-Path -Path $XmlPath -PathType Leaf)) {
                $exceptionMessage = "The file '$XmlPath' was not found."
                $errorRecordParameters = @{
                    Exception         = [System.IO.FileNotFoundException]::new($exceptionMessage)
                    ErrorId           = 'XmlFileNotFound'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    TargetObject      = $XmlPath
                    Message           = "The XML file '$XmlPath' does not exist or is not accessible."
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
                    Message           = "The directory '$DirectoryPath' does not exist or is not accessible."
                    RecommendedAction = 'Verify the directory path is correct and the directory exists.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }

        # Create CIM session
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
        $cimSession = New-StmCimSession @cimSessionParameters
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'XmlFile' {
                Write-Verbose "Importing task from file: $XmlPath"
                try {
                    $xmlContent = Get-Content -Path $XmlPath -Raw -ErrorAction 'Stop'
                }
                catch {
                    $errorRecordParameters = @{
                        Exception         = $_.Exception
                        ErrorId           = 'XmlFileReadFailed'
                        ErrorCategory     = [System.Management.Automation.ErrorCategory]::ReadError
                        TargetObject      = $XmlPath
                        Message           = "Failed to read XML file '$XmlPath'. $($_.Exception.Message)"
                        RecommendedAction = 'Verify you have read permissions for the file and the file is not locked.'
                    }
                    $errorRecord = New-StmError @errorRecordParameters
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                Import-SingleLocalTask -XmlContent $xmlContent -TaskPath $TaskPath -CimSession $cimSession `
                    -ComputerName $ComputerName -TaskNameOverride $TaskName -Force:$Force
            }

            'XmlString' {
                Write-Verbose 'Importing task from XML string'
                Import-SingleLocalTask -XmlContent $Xml -TaskPath $TaskPath -CimSession $cimSession `
                    -ComputerName $ComputerName -TaskNameOverride $TaskName -Force:$Force
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

                $activity = "Importing scheduled tasks from '$DirectoryPath'"
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
                            XmlContent   = $xmlContent
                            TaskPath     = $TaskPath
                            CimSession   = $cimSession
                            ComputerName = $ComputerName
                            Force        = $Force
                            ErrorAction  = 'Stop'
                        }
                        $null = Import-SingleLocalTask @importParams

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
        if ($cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
        Write-Verbose 'Completed Import-StmScheduledTask'
    }
}

function Import-SingleLocalTask {
    <#
    .SYNOPSIS
        Internal helper function to import a single scheduled task.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $XmlContent,

        [Parameter(Mandatory = $true)]
        [string]
        $TaskPath,

        [Parameter(Mandatory = $true)]
        $CimSession,

        [Parameter(Mandatory = $true)]
        [string]
        $ComputerName,

        [Parameter(Mandatory = $false)]
        [string]
        $TaskNameOverride,

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
                Exception         = [System.InvalidOperationException]::new('Could not determine task name from XML.')
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
            TaskPath    = $TaskPath
            CimSession  = $CimSession
            ErrorAction = 'Stop'
        }
        $existingTask = Get-ScheduledTask @getTaskParams
    }
    catch {
        # Task doesn't exist, which is fine
        Write-Verbose "Task '$effectiveTaskName' does not exist at path '$TaskPath' on '$ComputerName'"
        $existingTask = $null
    }

    if ($null -ne $existingTask) {
        if ($Force) {
            Write-Verbose "Task '$effectiveTaskName' exists. -Force specified, unregistering existing task..."
            $target = "Task '$effectiveTaskName' at '$TaskPath' on '$ComputerName'"
            $operation = 'Unregister existing scheduled task'
            if ($PSCmdlet.ShouldProcess($target, $operation)) {
                $unregisterParams = @{
                    TaskName    = $effectiveTaskName
                    TaskPath    = $TaskPath
                    CimSession  = $CimSession
                    Confirm     = $false
                    ErrorAction = 'Stop'
                }
                Unregister-ScheduledTask @unregisterParams
                Write-Verbose "Existing task '$effectiveTaskName' unregistered"
            }
        }
        else {
            $exceptionMessage = (
                "A scheduled task named '$effectiveTaskName' already exists at path '$TaskPath' " +
                "on computer '$ComputerName'."
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
    $target = "computer '$ComputerName'"
    $operation = "Import scheduled task '$effectiveTaskName' to path '$TaskPath'"
    if ($PSCmdlet.ShouldProcess($target, $operation)) {
        try {
            Write-Verbose "Registering scheduled task '$effectiveTaskName' at path '$TaskPath'..."
            $registerParams = @{
                TaskName    = $effectiveTaskName
                TaskPath    = $TaskPath
                Xml         = $XmlContent
                CimSession  = $CimSession
                ErrorAction = 'Stop'
            }
            $result = Register-ScheduledTask @registerParams
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
                    "Failed to register scheduled task '$effectiveTaskName' at path '$TaskPath' " +
                    "on computer '$ComputerName'. $($_.Exception.Message)"
                )
                RecommendedAction = (
                    'Verify the XML is valid Task Scheduler format, ' +
                    'the computer is accessible, and you have appropriate permissions.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}
