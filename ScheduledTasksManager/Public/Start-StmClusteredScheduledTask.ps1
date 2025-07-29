function Start-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Starts a clustered scheduled task on a Windows failover cluster.

    .DESCRIPTION
        The Start-StmClusteredScheduledTask function starts a clustered scheduled task on a Windows failover cluster.
        This function retrieves the specified clustered scheduled task using Get-StmClusteredScheduledTask and then
        starts it using the native Start-ScheduledTask cmdlet. The function supports the -WhatIf and -Confirm parameters
        for safe execution and provides verbose output for troubleshooting.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to start. This parameter is mandatory.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter is mandatory.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current user's credentials
        will be used for the connection.

    .EXAMPLE
        Start-StmClusteredScheduledTask -TaskName "BackupTask" -Cluster "MyCluster"

        Starts the clustered scheduled task named "BackupTask" on cluster "MyCluster" using the current user's credentials.

    .EXAMPLE
        Start-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "MyCluster.contoso.com" -WhatIf

        Shows what would happen if the clustered scheduled task named "MaintenanceTask" were started on cluster "MyCluster.contoso.com"
        without actually starting it.

    .EXAMPLE
        $creds = Get-Credential
        Start-StmClusteredScheduledTask -TaskName "ReportTask" -Cluster "MyCluster" -Credential $creds -Confirm

        Starts the clustered scheduled task named "ReportTask" on cluster "MyCluster" using specified credentials
        and prompts for confirmation before starting.

    .EXAMPLE
        Start-StmClusteredScheduledTask -TaskName "CleanupTask" -Cluster "MyCluster" -Verbose

        Starts the clustered scheduled task named "CleanupTask" on cluster "MyCluster" with verbose output
        to show detailed information about the operation.

    .INPUTS
        None. You cannot pipe objects to Start-StmClusteredScheduledTask.

    .OUTPUTS
        None. This function does not return any output objects.

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to start clustered scheduled tasks
        - Network connectivity to the cluster
        - The task must exist on the specified cluster
        - The task must be in a state that allows it to be started (e.g., Ready, Disabled)

        The function uses Get-StmClusteredScheduledTask internally to retrieve the task before starting it.
        If the task is not found or cannot be started, an error will be thrown.

        This function supports the -WhatIf and -Confirm parameters for safe execution in automated scenarios.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
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
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose 'Starting Start-StmClusteredScheduledTask'

        $stmScheduledTaskParameters = @{
            TaskName   = $TaskName
            Cluster    = $Cluster
            Credential = $Credential
        }
        $scheduledTask = Get-StmClusteredScheduledTask @stmScheduledTaskParameters
    }

    process {
        if ($PSCmdlet.ShouldProcess($TaskName, 'Start clustered scheduled task')) {
            $scheduledTask.ScheduledTaskObject | Start-ScheduledTask
        }
    }

    end {
        Write-Verbose 'Completed Start-StmClusteredScheduledTask'
    }
}
