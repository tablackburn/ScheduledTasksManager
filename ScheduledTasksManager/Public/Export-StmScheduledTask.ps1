function Export-StmScheduledTask {
    <#
    .SYNOPSIS
        Exports a scheduled task configuration to XML on a local or remote computer.

    .DESCRIPTION
        The Export-StmScheduledTask function exports the configuration of a scheduled task to XML format.
        The XML can be returned as a string or saved to a file. This function wraps the built-in
        Export-ScheduledTask cmdlet to provide credential support and enhanced error handling across
        the ScheduledTasksManager module.

        The exported XML can be used with Register-StmScheduledTask or Import-StmScheduledTask to
        recreate the task on the same or different computer.

        This function requires appropriate permissions to query scheduled tasks on the target computer.

    .PARAMETER TaskName
        Specifies the name of the scheduled task to export. This parameter is mandatory and must match the exact
        name of the task as it appears in the Task Scheduler.

    .PARAMETER TaskPath
        Specifies the path of the scheduled task to export. The task path represents the folder structure in the
        Task Scheduler where the task is located (e.g., '\Microsoft\Windows\PowerShell\'). If not specified, the
        root path ('\') will be used.

    .PARAMETER ComputerName
        Specifies the name of the computer from which to export the scheduled task. If not specified, the local
        computer ('localhost') is used. This parameter accepts computer names, IP addresses, or fully qualified
        domain names.

    .PARAMETER Credential
        Specifies credentials to use when connecting to a remote computer. If not specified, the current user's
        credentials are used for the connection. This parameter is only relevant when connecting to remote computers.

    .PARAMETER FilePath
        Specifies the path to save the exported XML file. If not specified, the XML is returned as a string
        to the pipeline. If the directory does not exist, it will be created.

    .EXAMPLE
        Export-StmScheduledTask -TaskName "MyBackupTask"

        Exports the scheduled task named "MyBackupTask" and returns the XML as a string.

    .EXAMPLE
        Export-StmScheduledTask -TaskName "MyBackupTask" -FilePath "C:\Backups\MyBackupTask.xml"

        Exports the scheduled task named "MyBackupTask" and saves it to the specified file.

    .EXAMPLE
        Export-StmScheduledTask -TaskName "MaintenanceTask" -TaskPath "\Custom\Maintenance\" -FilePath ".\backup.xml"

        Exports the scheduled task from the specified path and saves it to a file in the current directory.

    .EXAMPLE
        $xml = Export-StmScheduledTask -TaskName "DatabaseBackup" -ComputerName "Server01"

        Exports a task from a remote computer and stores the XML in a variable.

    .EXAMPLE
        $credentials = Get-Credential
        Export-StmScheduledTask -TaskName "ReportTask" -ComputerName "Server02" -Credential $credentials -FilePath "C:\Export\ReportTask.xml"

        Exports a task from a remote computer using specified credentials and saves to a file.

    .INPUTS
        None. You cannot pipe objects to Export-StmScheduledTask.

    .OUTPUTS
        System.String
        When FilePath is not specified, returns the XML representation of the scheduled task.
        When FilePath is specified, no output is returned (file is saved).

    .NOTES
        This function requires:
        - Appropriate permissions to query scheduled tasks on the target computer
        - Network connectivity to remote computers when using the ComputerName parameter
        - The Task Scheduler service to be running on the target computer
        - Write permissions to the destination directory when using FilePath

        The function uses CIM sessions internally for remote connections and includes proper error handling with
        detailed error messages and recommended actions.

        The exported XML follows the Task Scheduler XML schema and can be imported using
        Register-StmScheduledTask, Import-StmScheduledTask, or the built-in Register-ScheduledTask cmdlet.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
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
        [ValidateNotNullOrEmpty()]
        [string]
        $FilePath
    )

    begin {
        Write-Verbose 'Starting Export-StmScheduledTask'
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
            Write-Verbose "Exporting scheduled task '$TaskName' at path '$TaskPath' from computer '$ComputerName'..."

            # First get the task to verify it exists
            $getScheduledTaskParameters = @{
                TaskName    = $TaskName
                TaskPath    = $TaskPath
                CimSession  = $cimSession
                ErrorAction = 'Stop'
            }
            $task = Get-ScheduledTask @getScheduledTaskParameters

            # Export to XML
            $exportScheduledTaskParameters = @{
                TaskName    = $TaskName
                TaskPath    = $TaskPath
                CimSession  = $cimSession
                ErrorAction = 'Stop'
            }
            $xml = Export-ScheduledTask @exportScheduledTaskParameters

            if ($PSBoundParameters.ContainsKey('FilePath')) {
                Write-Verbose "Saving exported task to file '$FilePath'..."

                # Ensure the directory exists
                $directory = Split-Path -Path $FilePath -Parent
                if ($directory -and -not (Test-Path -Path $directory)) {
                    Write-Verbose "Creating directory '$directory'..."
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }

                # Save to file
                $outFileParameters = @{
                    FilePath = $FilePath
                    Encoding = 'unicode'
                }
                $xml | Out-File @outFileParameters -Force
                Write-Verbose "Task configuration saved to '$FilePath'"
            }
            else {
                Write-Verbose "Returning XML to pipeline"
                Write-Output $xml
            }
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ScheduledTaskExportFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::NotSpecified
                TargetObject      = $TaskName
                Message           = (
                    "Failed to export scheduled task '$TaskName' at path '$TaskPath' from computer " +
                    "'$ComputerName'. {$_}"
                )
                RecommendedAction = (
                    'Verify the task name and path are correct, that the task exists, and that you have ' +
                    'permission to query scheduled tasks.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed Export-StmScheduledTask for task '$TaskName'"
    }
}
