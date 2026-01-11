function Update-StmTaskUserXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper that modifies in-memory XML only; parent function handles ShouldProcess')]
    <#
    .SYNOPSIS
        Updates the UserId in a scheduled task XML document.

    .DESCRIPTION
        Updates the UserId element in the Principal section of a scheduled task XML
        document. Optionally sets the LogonType to 'Password' when a password will be
        provided during registration. This function modifies the XML document in place.

    .PARAMETER TaskXml
        The XML document representing the scheduled task configuration. This document is
        modified in place.

    .PARAMETER User
        The username to set as the task's UserId.

    .PARAMETER SetPasswordLogonType
        When specified, sets the LogonType to 'Password' to indicate the task will run
        with stored credentials.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [xml]
        $TaskXml,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $User,

        [Parameter(Mandatory = $false)]
        [switch]
        $SetPasswordLogonType
    )

    process {
        $principalsNode = $TaskXml.Task.Principals
        $principalNode = $principalsNode.Principal
        $ns = $TaskXml.DocumentElement.NamespaceURI

        $userIdNode = $principalNode.SelectSingleNode('*[local-name()="UserId"]')
        if ($userIdNode) {
            $userIdNode.InnerText = $User
        }
        else {
            $newNode = $TaskXml.CreateElement('UserId', $ns)
            $newNode.InnerText = $User
            $principalNode.AppendChild($newNode) | Out-Null
        }

        # If SetPasswordLogonType is specified, set LogonType to Password
        if ($SetPasswordLogonType) {
            $logonTypeNode = $principalNode.SelectSingleNode('*[local-name()="LogonType"]')
            if ($logonTypeNode) {
                $logonTypeNode.InnerText = 'Password'
            }
            else {
                $newNode = $TaskXml.CreateElement('LogonType', $ns)
                $newNode.InnerText = 'Password'
                $principalNode.AppendChild($newNode) | Out-Null
            }
        }
    }
}
