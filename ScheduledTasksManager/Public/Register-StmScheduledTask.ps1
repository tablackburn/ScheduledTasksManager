function Register-StmScheduledTask {
    <#
    .SYNOPSIS
        Registers a scheduled task from XML on a local or remote computer.

    .DESCRIPTION
        The Register-StmScheduledTask function registers a new scheduled task on a local or remote computer
        using XML configuration. The XML can be provided as a string or loaded from a file.
        This function wraps the built-in Register-ScheduledTask cmdlet to provide credential support
        and enhanced error handling across the ScheduledTasksManager module.

        The function performs the following operations:
        1. Connects to the specified computer using credentials if provided
        2. Loads the XML configuration from string or file
        3. Registers the scheduled task with the specified configuration
        4. Returns the registered task object

        This function requires appropriate permissions to manage scheduled tasks on the target computer.

    .PARAMETER TaskName
        Specifies the name for the scheduled task. If not specified, the task name is extracted from
        the XML's RegistrationInfo/URI element.

    .PARAMETER TaskPath
        Specifies the path where the scheduled task will be registered. The task path represents the folder
        structure in the Task Scheduler (e.g., '\Custom\Tasks\'). If not specified, the root path ('\')
        will be used.

    .PARAMETER Xml
        Specifies the XML configuration for the scheduled task as a string. This parameter is used
        in the 'XmlString' parameter set.

    .PARAMETER XmlPath
        Specifies the path to an XML file containing the scheduled task configuration. This parameter
        is used in the 'XmlFile' parameter set.

    .PARAMETER ComputerName
        Specifies the name of the computer on which to register the scheduled task. If not specified,
        the local computer ('localhost') is used. This parameter accepts computer names, IP addresses,
        or fully qualified domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current
        user's credentials are used for the connection.

    .EXAMPLE
        $xml = Export-StmScheduledTask -TaskName "ExistingTask"
        Register-StmScheduledTask -TaskName "NewTask" -Xml $xml

        Exports an existing task and registers a copy with a new name.

    .EXAMPLE
        Register-StmScheduledTask -XmlPath "C:\Backups\MyTask.xml"

        Registers a scheduled task from an XML file, using the task name from the XML.

    .EXAMPLE
        Register-StmScheduledTask -TaskName "CustomTask" -TaskPath "\Custom\Tasks\" -XmlPath ".\task.xml"

        Registers a task with a custom name and path from an XML file.

    .EXAMPLE
        Register-StmScheduledTask -XmlPath "C:\Tasks\backup.xml" -ComputerName "Server01"

        Registers a task on a remote computer from an XML file.

    .EXAMPLE
        Register-StmScheduledTask -TaskName "NewTask" -Xml $xml -WhatIf

        Shows what would happen if the task were registered without actually performing the operation.

    .INPUTS
        None. You cannot pipe objects to Register-StmScheduledTask.

    .OUTPUTS
        Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask
        Returns the registered scheduled task object.

    .NOTES
        This function requires:
        - Appropriate permissions to manage scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer
        - Valid Task Scheduler XML following the schema

        The function uses CIM sessions internally for remote connections and includes proper error handling
        with detailed error messages and recommended actions.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated environments.

        If a task with the same name already exists at the specified path, an error will be thrown.
        Use Import-StmScheduledTask with the -Force parameter to overwrite existing tasks.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'XmlString')]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath = '\',

        [Parameter(Mandatory = $true, ParameterSetName = 'XmlString')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Xml,

        [Parameter(Mandatory = $true, ParameterSetName = 'XmlFile')]
        [ValidateNotNullOrEmpty()]
        [string]
        $XmlPath,

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
        Write-Verbose 'Starting Register-StmScheduledTask'
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
        try {
            # Load XML from file if XmlPath was specified
            if ($PSCmdlet.ParameterSetName -eq 'XmlFile') {
                Write-Verbose "Loading XML from file '$XmlPath'..."
                if (-not (Test-Path -Path $XmlPath)) {
                    throw "The file '$XmlPath' does not exist."
                }
                $Xml = Get-Content -Path $XmlPath -Raw
            }

            # Extract task name from XML if not provided
            if (-not $PSBoundParameters.ContainsKey('TaskName')) {
                Write-Verbose 'TaskName not provided, extracting from XML...'
                $TaskName = Get-TaskNameFromXml -XmlContent $Xml
                Write-Verbose "Extracted task name: '$TaskName'"
            }

            if ($PSCmdlet.ShouldProcess("$TaskName at $TaskPath on $ComputerName", 'Register scheduled task')) {
                $verboseMsg = @(
                    "Registering scheduled task '$TaskName'"
                    "at path '$TaskPath' on computer '$ComputerName'..."
                ) -join ' '
                Write-Verbose $verboseMsg

                $registerScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    TaskPath    = $TaskPath
                    Xml         = $Xml
                    CimSession  = $cimSession
                    ErrorAction = 'Stop'
                }
                $registeredTask = Register-ScheduledTask @registerScheduledTaskParameters

                $successMsg = (
                    "Scheduled task '" + $TaskName +
                    "' has been successfully registered on computer '" + $ComputerName + "'."
                )
                Write-Verbose $successMsg

                Write-Output $registeredTask
            }
            else {
                Write-Verbose 'Operation cancelled by user.'
            }
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ScheduledTaskRegisterFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $TaskName
                Message           = (
                    "Failed to register scheduled task '$TaskName' at path '$TaskPath' on computer " +
                    "'$ComputerName'. {$_}"
                )
                RecommendedAction = (
                    'Verify the XML is valid, that a task with this name does not already exist at the ' +
                    'specified path, and that you have permission to manage scheduled tasks.'
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
        Write-Verbose "Completed Register-StmScheduledTask for task '$TaskName'"
    }
}
