function Get-StmClusterNode {
    <#
    .SYNOPSIS
        Retrieves information about cluster nodes in a Windows failover cluster.

    .DESCRIPTION
        The Get-StmClusterNode function retrieves detailed information about nodes in a Windows failover cluster
        using PowerShell remoting. This information is useful for understanding the cluster topology when managing
        scheduled tasks across cluster environments. The function connects to the cluster and executes the
        Get-ClusterNode cmdlet remotely to gather node details.

    .PARAMETER Cluster
        Specifies the name or FQDN of the cluster to query for node information. This parameter is mandatory.

    .PARAMETER NodeName
        Specifies the name of a specific cluster node to retrieve information for. If not specified,
        information for all nodes in the cluster will be returned. This parameter is optional.

    .PARAMETER Credential
        Specifies credentials to use when establishing the remote PowerShell session to the cluster.
        If not provided, the current user's credentials will be used for the connection.

    .EXAMPLE
        Get-StmClusterNode -Cluster "MyCluster"

        Retrieves information about all nodes in the cluster named "MyCluster" using the current user's credentials.

    .EXAMPLE
        Get-StmClusterNode -Cluster "MyCluster.contoso.com" -NodeName "Node01"

        Retrieves information about the specific node "Node01" in cluster "MyCluster.contoso.com".

    .EXAMPLE
        $creds = Get-Credential
        Get-StmClusterNode -Cluster "MyCluster" -Credential $creds

        Retrieves cluster node information using the specified credentials for authentication.

    .EXAMPLE
        Get-StmClusterNode -Cluster "MyCluster" | Where-Object { $_.State -eq "Up" }

        Retrieves all cluster nodes and filters to show only nodes that are currently in the "Up" state.

    .INPUTS
        None. You cannot pipe objects to Get-StmClusterNode.

    .OUTPUTS
        Microsoft.FailoverClusters.PowerShell.ClusterNode
        Returns cluster node objects with properties including:
        - Id: Unique identifier for the cluster node
        - Name: Name of the cluster node
        - State: Current state of the node (Up, Down, Paused, Joining, etc.)
        - StatusInformation: Additional status details about the node
        - DynamicWeight: Dynamic weight assigned to the node for load balancing
        - NodeWeight: Static weight assigned to the node
        - FaultDomain: Fault domain the node belongs to for placement decisions
        - Site: Site location of the node for geographic distribution

    .NOTES
        This function requires:
        - PowerShell remoting to be enabled on the target cluster
        - The FailoverClusters PowerShell module to be installed on the target cluster
        - Appropriate permissions to query cluster information
        - Network connectivity to the cluster on the WinRM ports (default 5985/5986)

        The function uses Invoke-Command to execute Get-ClusterNode remotely on the cluster.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cluster,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NodeName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting Get-StmClusterNode for cluster '$Cluster'"

        $clusterNodeParameters = @{
            Cluster     = $Cluster
            ErrorAction = 'Stop'
        }
        if ($NodeName) {
            Write-Verbose "Retrieving information for specific node: '$NodeName'"
            $clusterNodeParameters['Name'] = $NodeName
        }
        else {
            Write-Verbose 'Retrieving information for all nodes in the cluster'
        }

        $invokeCommandParameters = @{
            ComputerName = $Cluster
            ScriptBlock  = {
                param($ClusterNodeParameters)
                Get-ClusterNode @ClusterNodeParameters
            }
            ArgumentList = $clusterNodeParameters
            ErrorAction  = 'Stop'
        }
        $credentialsProvided = $PSBoundParameters.ContainsKey('Credential') -and
            $Credential -ne [System.Management.Automation.PSCredential]::Empty
        if ($credentialsProvided) {
            Write-Verbose "Using provided credentials for the remote command on cluster '$Cluster'"
            $invokeCommandParameters['Credential'] = $Credential
        }
    }

    process {
        try {
            Write-Verbose 'Executing command to retrieve cluster node information...'
            Invoke-Command @invokeCommandParameters
            Write-Verbose "Successfully retrieved information for $($clusterNodes.Count) cluster node(s)"
        }
        catch {
            $errorRecordParameters = @{
                Exception     = $_.Exception
                ErrorId       = 'ClusterNodeRetrievalFailed'
                ErrorCategory = [System.Management.Automation.ErrorCategory]::ReadError
            }
            if ($PSBoundParameters.ContainsKey('NodeName')) {
                $errorRecordParameters['TargetObject'] = $NodeName
                $errorRecordParameters['Message'] = (
                    "Failed to retrieve information for cluster node '$NodeName' on cluster " +
                    "'$Cluster'. $($_.Exception.Message)"
                )
                $errorRecordParameters['RecommendedAction'] = (
                    "Verify the cluster name '$Cluster' is correct and accessible. " +
                    'Ensure you have appropriate permissions to query cluster information. ' +
                    "If specifying a node name, verify '$NodeName' exists in the cluster. " +
                    'Check that the FailoverClusters PowerShell module is installed and available.'
                )
            }
            else {
                $errorRecordParameters['TargetObject'] = $Cluster
                $errorRecordParameters['Message'] = (
                    "Failed to retrieve cluster node information for cluster '$Cluster'. $($_.Exception.Message)"
                )
                $errorRecordParameters['RecommendedAction'] = (
                    "Verify the cluster name '$Cluster' is correct and accessible. " +
                    'Ensure you have appropriate permissions to query cluster information. ' +
                    'Check that the FailoverClusters PowerShell module is installed and available.'
                )
            }
            $errorRecord = New-StmError @errorRecordParameters
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        Write-Verbose "Completed Get-StmClusterNode for cluster '$Cluster'"
    }
}
