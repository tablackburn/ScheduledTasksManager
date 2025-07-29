---
external help file: ScheduledTasksManager-help.xml
Module Name: ScheduledTasksManager
online version:
schema: 2.0.0
---

# Get-StmClusterNode

## SYNOPSIS
Retrieves information about cluster nodes in a Windows failover cluster.

## SYNTAX

```
Get-StmClusterNode [-Cluster] <String> [[-NodeName] <String>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-StmClusterNode function retrieves detailed information about nodes in a Windows failover cluster
using PowerShell remoting.
This information is useful for understanding the cluster topology when managing
scheduled tasks across cluster environments.
The function connects to the cluster and executes the
Get-ClusterNode cmdlet remotely to gather node details.

## EXAMPLES

### EXAMPLE 1
```
Get-StmClusterNode -Cluster "MyCluster"
```

Retrieves information about all nodes in the cluster named "MyCluster" using the current user's credentials.

### EXAMPLE 2
```
Get-StmClusterNode -Cluster "MyCluster.contoso.com" -NodeName "Node01"
```

Retrieves information about the specific node "Node01" in cluster "MyCluster.contoso.com".

### EXAMPLE 3
```
$creds = Get-Credential
```

Get-StmClusterNode -Cluster "MyCluster" -Credential $creds

Retrieves cluster node information using the specified credentials for authentication.

### EXAMPLE 4
```
Get-StmClusterNode -Cluster "MyCluster" | Where-Object { $_.State -eq "Up" }
```

Retrieves all cluster nodes and filters to show only nodes that are currently in the "Up" state.

## PARAMETERS

### -Cluster
Specifies the name or FQDN of the cluster to query for node information.
This parameter is mandatory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NodeName
Specifies the name of a specific cluster node to retrieve information for.
If not specified,
information for all nodes in the cluster will be returned.
This parameter is optional.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Specifies credentials to use when establishing the remote PowerShell session to the cluster.
If not provided, the current user's credentials will be used for the connection.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None. You cannot pipe objects to Get-StmClusterNode.
## OUTPUTS

### Microsoft.FailoverClusters.PowerShell.ClusterNode
### Returns cluster node objects with properties including:
### - Id: Unique identifier for the cluster node
### - Name: Name of the cluster node
### - State: Current state of the node (Up, Down, Paused, Joining, etc.)
### - StatusInformation: Additional status details about the node
### - DynamicWeight: Dynamic weight assigned to the node for load balancing
### - NodeWeight: Static weight assigned to the node
### - FaultDomain: Fault domain the node belongs to for placement decisions
### - Site: Site location of the node for geographic distribution
## NOTES
This function requires:
- PowerShell remoting to be enabled on the target cluster
- The FailoverClusters PowerShell module to be installed on the target cluster
- Appropriate permissions to query cluster information
- Network connectivity to the cluster on the WinRM ports (default 5985/5986)

The function uses Invoke-Command to execute Get-ClusterNode remotely on the cluster.

## RELATED LINKS
