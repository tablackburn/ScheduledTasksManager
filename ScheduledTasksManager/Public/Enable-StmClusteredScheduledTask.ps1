function Enable-StmClusteredScheduledTask {
    <#
    .SYNOPSIS
        Enables a disabled clustered scheduled task in a Windows failover cluster.

    .DESCRIPTION
        The Enable-StmClusteredScheduledTask function enables a previously disabled clustered scheduled task
        by modifying its configuration and re-registering it in the Windows failover cluster. The function
        performs a complete task re-registration process to ensure the task is properly enabled and functional.

        The function performs the following operations:
        1. Exports the current task configuration using Export-StmClusteredScheduledTask
        2. Modifies the XML configuration to set the Enabled property to 'true'
        3. Retrieves the original task type to maintain proper registration
        4. Unregisters the current disabled task
        5. Re-registers the task with the modified (enabled) configuration
        6. Provides detailed verbose output for troubleshooting

        This function is useful when a clustered scheduled task has been disabled and needs to be
        re-enabled for execution. The re-registration process ensures the task is properly configured
        and ready to run according to its schedule.

    .PARAMETER TaskName
        Specifies the name of the clustered scheduled task to enable. This parameter is mandatory
        and must match the exact name of the task as it appears in the cluster.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster where the scheduled task is located. This parameter
        is mandatory and must be a valid Windows failover cluster.

    .PARAMETER Credential
        Specifies credentials to use when connecting to the cluster. If not provided, the current
        user's credentials will be used for the connection. This parameter is optional.

    .EXAMPLE
        Enable-StmClusteredScheduledTask -TaskName "MyBackupTask" -Cluster "MyCluster"

        Enables the clustered scheduled task named "MyBackupTask" on cluster "MyCluster" using
        the current user's credentials. The task will be re-registered with enabled status.

    .EXAMPLE
        $creds = Get-Credential
        Enable-StmClusteredScheduledTask -TaskName "MaintenanceTask" -Cluster "ProdCluster" -Credential $creds

        Enables the clustered scheduled task named "MaintenanceTask" on cluster "ProdCluster" using
        the specified credentials. The task will be re-registered with enabled status.

    .EXAMPLE
        Enable-StmClusteredScheduledTask -TaskName "TestTask" -Cluster "TestCluster" -Verbose

        Enables the clustered scheduled task with verbose output showing detailed information about
        the export, modification, and re-registration process.

    .EXAMPLE
        Enable-StmClusteredScheduledTask -TaskName "DisabledTask" -Cluster "MyCluster" -WhatIf

        Shows what would happen if the cmdlet runs without actually performing the operation.
        This is useful for testing the command before execution.

    .INPUTS
        None. You cannot pipe objects to Enable-StmClusteredScheduledTask.

    .OUTPUTS
        None. This cmdlet does not return any objects.

    .NOTES
        This function requires:
        - PowerShell remoting to be enabled on the target cluster
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to manage clustered scheduled tasks
        - Network connectivity to the cluster on the WinRM ports (default 5985/5986)

        The function performs a complete re-registration of the task, which involves:
        - Unregistering the current disabled task
        - Re-registering the task with the enabled configuration
        - Maintaining the original task type and other properties

        If the task is already enabled, the function will display a warning and exit without
        making any changes.

        This operation temporarily removes the task from the cluster during the re-registration
        process. The task will be unavailable for execution during this brief period.

        The function supports the -WhatIf and -Confirm parameters for safe operation in automated
        environments.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Cluster,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting Enable-StmClusteredScheduledTask for task '$TaskName' on cluster '$Cluster'"
    }

    process {
        try {
            Write-Verbose "Exporting clustered scheduled task '$TaskName'..."
            $exportStmClusteredScheduledTaskParameters = @{
                TaskName   = $TaskName
                Cluster    = $Cluster
                Credential = $Credential
            }
            $taskXml = Export-StmClusteredScheduledTask @exportStmClusteredScheduledTaskParameters
            if (-not $taskXml) {
                Write-Error "Failed to export XML for task '$TaskName'. Aborting."
                return
            }

            # Load and modify XML if needed
            [xml]$taskXmlDocument = $taskXml
            $settingsNode = $taskXmlDocument.Task.Settings
            if ($settingsNode.Enabled -eq 'false') {
                Write-Verbose 'Task is currently disabled. Setting Enabled to true in XML...'
                $settingsNode.Enabled = 'true'
                $taskXml = $taskXmlDocument.OuterXml
            }
            else {
                Write-Warning "Task '$TaskName' is already enabled. No changes made."
                return
            }

            Write-Verbose 'Retrieving original task type...'
            $getStmClusteredScheduledTaskParameters = @{
                TaskName   = $TaskName
                Cluster    = $Cluster
                Credential = $Credential
            }
            $scheduledTask = Get-StmClusteredScheduledTask @getStmClusteredScheduledTaskParameters
            $taskType = $scheduledTask.ClusteredScheduledTaskObject.TaskType
            if (-not $taskType) {
                Write-Error "Failed to retrieve original task type for '$TaskName'. Aborting."
                return
            }

            if ($PSCmdlet.ShouldProcess("$TaskName on cluster $Cluster", "Enable clustered scheduled task")) {
                Write-Verbose "Unregistering clustered scheduled task '$TaskName'..."
                $newStmCimSessionParameters = @{
                    ComputerName = $Cluster
                    Credential   = $Credential
                }
                $unregisterClusteredScheduledTaskParameters = @{
                    TaskName    = $TaskName
                    CimSession  = (New-StmCimSession @newStmCimSessionParameters)
                    ErrorAction = 'Stop'
                }
                Unregister-ClusteredScheduledTask @unregisterClusteredScheduledTaskParameters

                Write-Verbose "Re-registering clustered scheduled task '$TaskName'..."
                $registerStmClusteredScheduledTaskParameters = @{
                    TaskName   = $TaskName
                    Cluster    = $Cluster
                    Xml        = $taskXml
                    TaskType   = $taskType
                    Credential = $Credential
                }
                Register-StmClusteredScheduledTask @registerStmClusteredScheduledTaskParameters
                Write-Verbose "Clustered scheduled task '$TaskName' has been enabled (re-registered)."
            }
        }
        catch {
            Write-Error "Failed to enable clustered scheduled task '$TaskName': $_"
        }
    }

    end {
        Write-Verbose "Completed Enable-StmClusteredScheduledTask for task '$TaskName'"
    }
}
