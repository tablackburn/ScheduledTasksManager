function Get-StmClusteredScheduledTaskRun {
    [CmdletBinding()]
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
        [ValidateNotNullOrEmpty()]
        [string]
        $TaskPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting Get-StmClusteredScheduledTaskRun on cluster '$Cluster'"

        $stmClusterNodeParameters = @{
            Cluster = $Cluster
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $stmClusterNodeParameters['Credential'] = $Credential
        }

        $scheduledTaskRunParameters = @{
            TaskName = $TaskName
        }
        if ($PSBoundParameters.ContainsKey('TaskPath')) {
            $scheduledTaskRunParameters['TaskPath'] = $TaskPath
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $scheduledTaskRunParameters['Credential'] = $Credential
        }
    }

    process {
        Write-Verbose "Getting cluster nodes for cluster '$Cluster'"
        $clusterNodes = Get-StmClusterNode @stmClusterNodeParameters
        if ($null -eq $clusterNodes -or $clusterNodes.Count -eq 0) {
            Write-Error "No cluster nodes found for cluster '$Cluster'"
            return
        }
        Write-Verbose "Cluster nodes found: $($clusterNodes.Count)"
        Write-Verbose "Cluster nodes: $($clusterNodes | Out-String)"

        foreach ($node in $clusterNodes) {
            Write-Verbose "Getting scheduled task runs for node '$($node.Name)' on cluster '$Cluster'"
            Get-StmScheduledTaskRun -ComputerName $node.Name @scheduledTaskRunParameters
        }

    }

    end {
        Write-Verbose "Finished Get-StmClusteredScheduledTaskRun on cluster '$Cluster'"
    }
}
