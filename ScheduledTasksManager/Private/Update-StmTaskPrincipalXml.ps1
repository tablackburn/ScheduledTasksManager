function Update-StmTaskPrincipalXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper that modifies in-memory XML only; parent function handles ShouldProcess')]
    <#
    .SYNOPSIS
        Updates the Principal section of a scheduled task XML document.

    .DESCRIPTION
        Updates the Principal element in a scheduled task XML document based on the
        provided principal object. This function modifies the XML document in place.

        Handles value mapping for LogonType and RunLevel properties to convert from
        PowerShell enum values to Task Scheduler XML values.

    .PARAMETER TaskXml
        The XML document representing the scheduled task configuration. This document is
        modified in place.

    .PARAMETER Principal
        A CIM principal object created by New-ScheduledTaskPrincipal containing the
        security context settings for the task.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [xml]
        $TaskXml,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]
        $Principal
    )

    process {
        $principalsNode = $TaskXml.Task.Principals
        $principalNode = $principalsNode.Principal
        $ns = $TaskXml.DocumentElement.NamespaceURI

        if ($Principal.UserId) {
            $userIdNode = $principalNode.SelectSingleNode('*[local-name()="UserId"]')
            if ($userIdNode) {
                $userIdNode.InnerText = $Principal.UserId
            }
            else {
                $newNode = $TaskXml.CreateElement('UserId', $ns)
                $newNode.InnerText = $Principal.UserId
                $principalNode.AppendChild($newNode) | Out-Null
            }
        }

        if ($Principal.LogonType) {
            $logonTypeNode = $principalNode.SelectSingleNode('*[local-name()="LogonType"]')
            $logonTypeValue = switch ($Principal.LogonType) {
                'Password' {
                    'Password'
                }
                'S4U' {
                    'S4U'
                }
                'Interactive' {
                    'InteractiveToken'
                }
                'InteractiveOrPassword' {
                    'InteractiveTokenOrPassword'
                }
                'ServiceAccount' {
                    'ServiceAccount'
                }
                default {
                    $Principal.LogonType.ToString()
                }
            }
            if ($logonTypeNode) {
                $logonTypeNode.InnerText = $logonTypeValue
            }
            else {
                $newNode = $TaskXml.CreateElement('LogonType', $ns)
                $newNode.InnerText = $logonTypeValue
                $principalNode.AppendChild($newNode) | Out-Null
            }
        }

        if ($Principal.RunLevel) {
            $runLevelNode = $principalNode.SelectSingleNode('*[local-name()="RunLevel"]')
            $runLevelValue = switch ($Principal.RunLevel) {
                'Highest' {
                    'HighestAvailable'
                }
                'Limited' {
                    'LeastPrivilege'
                }
                default {
                    $Principal.RunLevel.ToString()
                }
            }
            if ($runLevelNode) {
                $runLevelNode.InnerText = $runLevelValue
            }
            else {
                $newNode = $TaskXml.CreateElement('RunLevel', $ns)
                $newNode.InnerText = $runLevelValue
                $principalNode.AppendChild($newNode) | Out-Null
            }
        }
    }
}
