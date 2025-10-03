function Unregister-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Unregisters a clustered scheduled task from a Windows failover cluster.

    .DESCRIPTION
        The Unregister-StmClusteredScheduledTask function removes a clustered scheduled task from a Windows
        failover cluster. This function creates a CIM session to the cluster and uses the native
        Unregister-ClusteredScheduledTask cmdlet to remove the task. The function supports the -WhatIf and
        -Confirm parameters for safe execution and provides comprehensive error handling for connection and
        operation failures.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to unregister. This parameter is mandatory.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter is mandatory.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current user's credentials
        will be used for the connection.

    .EXAMPLE
        Unregister-StmClusteredScheduledTask -TaskName "OldBackupTask" -Cluster "MyCluster"

        Unregisters the clustered scheduled task named "OldBackupTask" from cluster "MyCluster"
        using the current user's credentials.

    .EXAMPLE
        Unregister-StmClusteredScheduledTask -TaskName "DeprecatedTask" -Cluster "MyCluster.contoso.com" -WhatIf

        Shows what would happen if the clustered scheduled task named "DeprecatedTask" were unregistered
        from cluster "MyCluster.contoso.com" without actually removing it.

    .EXAMPLE
        $creds = Get-Credential
        Unregister-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "MyCluster" -Credential $creds -Confirm

        Unregisters the clustered scheduled task named "TestTask" from cluster "MyCluster" using specified credentials
        and prompts for confirmation before removing the task.

    .EXAMPLE
        Unregister-StmClusteredScheduledTask -TaskName "CleanupTask" -Cluster "MyCluster" -Verbose

        Unregisters the clustered scheduled task named "CleanupTask" from cluster "MyCluster" with verbose output
        to show detailed information about the operation.

    .INPUTS
        None. You cannot pipe objects to Unregister-StmClusteredScheduledTask.

    .OUTPUTS
        None. This function does not return any output objects.

    .NOTES
        This function requires:
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to unregister clustered scheduled tasks
        - Network connectivity to the cluster
        - The task must exist on the specified cluster

        The function provides comprehensive error handling for:
        - CIM session creation failures
        - Task unregistration failures
        - Invalid task names or cluster names

        This function supports the -WhatIf and -Confirm parameters for safe execution in automated scenarios.
        The unregistration operation is irreversible, so use caution when running this function.
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
        Write-Verbose "Starting Unregister-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
    }

    process {
        try {
            $cimSession = New-StmCimSession -ComputerName $Cluster -Credential $Credential -ErrorAction 'Stop'
            Write-Verbose "CIM session established to cluster '$Cluster'"
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'CimSessionCreationFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::ConnectionError
                TargetObject      = $Cluster
                Message           = "Failed to create CIM session to cluster '$Cluster'. $($_.Exception.Message)"
                RecommendedAction = (
                    "Verify the cluster name '$Cluster' is correct, the cluster is accessible, " +
                    'and you have appropriate permissions. If using credentials, verify they are valid for ' +
                    'the cluster.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        try {
            $shouldProcessArguments = @(
                "Task '$TaskName' on cluster '$Cluster'", # Target for ShouldProcess
                'Unregister clustered scheduled task'     # Action description
            )
            if ($PSCmdlet.ShouldProcess($shouldProcessArguments)) {
                Write-Verbose "Unregistering clustered scheduled task '$TaskName'..."
                Unregister-ClusteredScheduledTask -TaskName $TaskName -CimSession $cimSession -ErrorAction 'Stop'
                Write-Verbose "Clustered scheduled task '$TaskName' has been unregistered."
            }
        }
        catch {
            $errorRecordParameters = @{
                Exception         = $_.Exception
                ErrorId           = 'ClusteredTaskUnregistrationFailed'
                ErrorCategory     = [System.Management.Automation.ErrorCategory]::OperationStopped
                TargetObject      = $TaskName
                Message           = (
                    "Failed to unregister clustered scheduled task '$TaskName' on " +
                    "cluster '$Cluster'. $($_.Exception.Message)"
                )
                RecommendedAction = (
                    "Ensure the task name '$TaskName' is correct, the cluster '$Cluster' is accessible, " +
                    'and you have appropriate permissions to unregister the task.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed Unregister-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
    }
}
