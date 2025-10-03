function Disable-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Disables (unregisters) a clustered scheduled task from a Windows failover cluster.

    .DESCRIPTION
        The Disable-StmClusteredScheduledTask function safely disables a clustered scheduled task by
        unregistering it from a Windows failover cluster. Before unregistering the task, the function
        automatically creates a backup of the task configuration in XML format to the system's temporary
        directory. This ensures that the task can be restored if needed.

        The function performs the following operations:
        1. Creates a backup of the task configuration using Export-StmClusteredScheduledTask
        2. Unregisters the clustered scheduled task using the native Unregister-ClusteredScheduledTask cmdlet
        3. Verifies that the task has been successfully unregistered
        4. Provides detailed verbose output for troubleshooting

        This function requires appropriate permissions to manage clustered scheduled tasks and
        network connectivity to the target cluster.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to disable. This parameter is mandatory
        and must match the exact name of the task as it appears in the cluster.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter
        is mandatory and must be a valid Windows failover cluster.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current
        user's credentials will be used for the connection. This parameter is optional.

    .EXAMPLE
        Disable-StmClusteredScheduledTask -TaskName "MyBackupTask" -Cluster "MyCluster"

        Disables the clustered scheduled task named "MyBackupTask" on cluster "MyCluster" using
        the current user's credentials. A backup will be created before unregistering the task.

    .EXAMPLE
        $creds = Get-Credential
        Disable-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "ProdCluster" -Credential $creds

        Disables the clustered scheduled task named "MaintenanceTask" on cluster "ProdCluster" using
        the specified credentials. A backup will be created before unregistering the task.

    .EXAMPLE
        Disable-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "TestCluster" -Verbose

        Disables the clustered scheduled task with verbose output showing detailed information about
        the backup creation and unregistration process.

    .EXAMPLE
        Disable-StmClusteredScheduledTask -TaskName "OldTask" -Cluster "MyCluster" -WhatIf

        Shows what would happen if the cmdlet runs without actually performing the operation.
        This is useful for testing the command before execution.

    .INPUTS
        None. You cannot pipe objects to Disable-StmClusteredScheduledTask.

    .OUTPUTS
        None. This cmdlet does not return any objects.

    .NOTES
        This function requires:
        - PowerShell remoting to be enabled on the target cluster
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to manage clustered scheduled tasks
        - Network connectivity to the cluster on the WinRM ports (default 5985/5986)
        - Write permissions to the system's temporary directory for backup creation

        The function automatically creates a backup of the task configuration before unregistering it.
        The backup file is saved to the system's temporary directory with a timestamp in the filename
        format: TaskName_Cluster_yyyyMMddHHmmss.xml

        This operation is irreversible once confirmed. The task will be completely removed from the
        cluster and cannot be easily restored without the backup file.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated
        environments.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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
        Write-Warning (
            "You are about to disable (unregister) the clustered scheduled task '$TaskName' on " +
            "cluster '$Cluster'. This action cannot be undone. A backup of the task will be created " +
            'before proceeding.'
        )
    }

    process {
        if ($PSCmdlet.ShouldProcess("$TaskName on $Cluster", 'Disable (unregister) clustered scheduled task')) {
            try {
                $pathParameters = @{
                    Path      = $env:TEMP
                    ChildPath = ('{0}_{1}_{2:yyyyMMddHHmmss}.xml' -f $TaskName, $Cluster, (Get-Date))
                }
                $backupPath = Join-Path @pathParameters
                Write-Verbose "Backing up clustered scheduled task '$TaskName' to '$backupPath'..."
                $exportTaskParameters = @{
                    TaskName    = $TaskName
                    Cluster     = $Cluster
                    Credential  = $Credential
                    FilePath    = $backupPath
                    ErrorAction = 'Stop'
                }
                Export-StmClusteredScheduledTask @exportTaskParameters
                $backupSuccessful = (
                    (Test-Path -Path $backupPath) -and
                    (Get-Content -Path $backupPath).Length -gt 0
                )
                if ($backupSuccessful) {
                    Write-Verbose (
                        "Backup of clustered scheduled task '$TaskName' created successfully at '$backupPath'."
                    )
                }
                else {
                    $errorParameters = @{
                        Message     = "Failed to create backup for clustered scheduled task '$TaskName'."
                        ErrorAction = 'Stop'
                    }
                    Write-Error @errorParameters
                }
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'BackupFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::WriteError
                    TargetObject      = $TaskName
                    Message           = (
                        "Failed to create backup for clustered scheduled task '$TaskName'. $($_.Exception.Message)"
                    )
                    RecommendedAction = 'Ensure you have write permissions to the specified backup path.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }

            try {
                Write-Verbose "Unregistering clustered scheduled task '$TaskName' on cluster '$Cluster'..."
                $cimSessionParameters = @{
                    ComputerName = $Cluster
                    Credential   = $Credential
                    ErrorAction  = 'Stop'
                }
                $clusterCimSession = New-StmCimSession @cimSessionParameters
                $unregisterClusteredScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    Cluster     = $Cluster
                    CimSession  = $clusterCimSession
                    ErrorAction = 'Stop'
                }
                Unregister-ClusteredScheduledTask @unregisterClusteredScheduledTaskParameters
                Write-Verbose "Verifying unregistration of clustered scheduled task '$TaskName'..."
                $taskParameters = @{
                    TaskName      = $TaskName
                    Cluster       = $Cluster
                    CimSession    = $clusterCimSession
                    ErrorAction   = 'Stop'
                    WarningAction = 'SilentlyContinue' # Suppress the warning about the task not being found
                }
                $task = Get-StmClusteredScheduledTask @taskParameters
                $taskExists = $null -ne $task
                if ($taskExists) {
                    $errorParameters = @{
                        Message     = (
                            "Clustered scheduled task '$TaskName' still exists on cluster '$Cluster' after " +
                            'unregistration.'
                        )
                        ErrorAction = 'Stop'
                    }
                    Write-Error @errorParameters
                }
                else {
                    $verboseParameters = @{
                        Message     = "Clustered scheduled task '$TaskName' has been successfully unregistered."
                        ErrorAction = 'Continue'
                    }
                    Write-Verbose @verboseParameters
                }
            }
            catch {
                $errorRecordParameters = @{
                    Exception         = $_.Exception
                    ErrorId           = 'UnregisterFailed'
                    ErrorCategory     = [System.Management.Automation.ErrorCategory]::WriteError
                    TargetObject      = $TaskName
                    Message           = (
                        "Failed to unregister clustered scheduled task '$TaskName'. $($_.Exception.Message)"
                    )
                    RecommendedAction = 'Ensure the task is not running and you have the necessary permissions.'
                }
                $errorRecord = New-StmError @errorRecordParameters
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
        else {
            Write-Verbose 'Operation cancelled by user.'
        }
    }

    end {
        Write-Verbose "Completed Disable-StmClusteredScheduledTask for task '$TaskName'"
    }
}
