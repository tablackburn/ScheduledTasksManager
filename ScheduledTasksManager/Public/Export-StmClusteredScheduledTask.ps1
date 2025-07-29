function Export-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Exports a clustered scheduled task from a Windows failover cluster.

    .DESCRIPTION
        The Export-StmClusteredScheduledTask function exports a clustered scheduled task from a Windows failover cluster
        to an XML format. This function retrieves the specified clustered scheduled task using Get-StmClusteredScheduledTask
        and then exports it using the native Export-ScheduledTask cmdlet. The exported XML can be used to recreate the task
        on other systems or for backup purposes.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to export. This parameter is mandatory.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter is mandatory.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current user's credentials
        will be used for the connection.

    .PARAMETER FilePath
        Specifies the path where the exported XML file should be saved. If provided, the function will save the XML
        to the specified file path instead of returning it to the pipeline. If not provided, the XML is returned
        to the pipeline as a string.

    .EXAMPLE
        Export-StmClusteredScheduledTask -TaskName "MyTask" -Cluster "MyCluster"

        Exports the clustered scheduled task named "MyTask" from cluster "MyCluster" using the current user's credentials
        and returns the XML to the pipeline.

    .EXAMPLE
        $creds = Get-Credential
        Export-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster.contoso.com" -Credential $creds

        Exports the clustered scheduled task named "BackupTask" from cluster "MyCluster.contoso.com" using the specified credentials
        and returns the XML to the pipeline.

    .EXAMPLE
        Export-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "MyCluster" -FilePath "C:\Tasks\MaintenanceTask.xml"

        Exports the clustered scheduled task and saves the XML output directly to the specified file path.

    .INPUTS
        None. You cannot pipe objects to Export-StmClusteredScheduledTask.

    .OUTPUTS
        System.String
        Returns the XML representation of the clustered scheduled task that can be used to recreate the task.
        If FilePath is specified, no output is returned to the pipeline.

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to access clustered scheduled tasks
        - Network connectivity to the cluster
        - The task must exist on the specified cluster

        The function uses Get-StmClusteredScheduledTask internally to retrieve the task before exporting it.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cluster,

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
        Write-Verbose "Starting Export-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"

        $stmScheduledTaskParameters = @{
            TaskName   = $TaskName
            Cluster    = $Cluster
            Credential = $Credential
        }
        $scheduledTask = Get-StmClusteredScheduledTask @stmScheduledTaskParameters
    }

    process {
        if ($FilePath) {
            Write-Verbose "Exporting task to file: $FilePath"

            # Ensure the directory exists
            $directory = Split-Path -Path $FilePath -Parent
            if ($directory -and -not (Test-Path -Path $directory)) {
                Write-Verbose "Creating directory: $directory"
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }

            try {
                $scheduledTask.ScheduledTaskObject | Export-ScheduledTask | Out-File -FilePath $FilePath -Encoding ([System.Text.Encoding]::UTF8)
                Write-Verbose "Successfully exported task to: $FilePath"
            }
            catch {
                Write-Error "Failed to export task to file '$FilePath': $($_.Exception.Message)"
                throw
            }
        } else {
            $scheduledTask.ScheduledTaskObject | Export-ScheduledTask
        }
    }

    end {
        Write-Verbose "Completed Export-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
    }
}
