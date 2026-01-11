function Update-StmTaskActionXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper that modifies in-memory XML only; parent function handles ShouldProcess')]
    <#
    .SYNOPSIS
        Updates the Actions section of a scheduled task XML document.

    .DESCRIPTION
        Removes existing Exec actions from a scheduled task XML document and replaces them
        with new actions from the provided CIM action objects. This function modifies the
        XML document in place.

    .PARAMETER TaskXml
        The XML document representing the scheduled task configuration. This document is
        modified in place.

    .PARAMETER Action
        An array of CIM action objects created by New-ScheduledTaskAction. Each action
        defines a command to execute, with optional arguments and working directory.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [xml]
        $TaskXml,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object[]]
        $Action
    )

    process {
        $actionsNode = $TaskXml.Task.Actions
        $ns = $TaskXml.DocumentElement.NamespaceURI

        # Clear existing Exec actions
        $execActions = @($actionsNode.ChildNodes | Where-Object { $_.LocalName -eq 'Exec' })
        foreach ($exec in $execActions) {
            $actionsNode.RemoveChild($exec) | Out-Null
        }

        # Add new actions
        foreach ($act in $Action) {
            $execElement = $TaskXml.CreateElement('Exec', $ns)

            $cmdElement = $TaskXml.CreateElement('Command', $ns)
            $cmdElement.InnerText = $act.Execute
            $execElement.AppendChild($cmdElement) | Out-Null

            if ($act.Arguments) {
                $argsElement = $TaskXml.CreateElement('Arguments', $ns)
                $argsElement.InnerText = $act.Arguments
                $execElement.AppendChild($argsElement) | Out-Null
            }

            if ($act.WorkingDirectory) {
                $wdElement = $TaskXml.CreateElement('WorkingDirectory', $ns)
                $wdElement.InnerText = $act.WorkingDirectory
                $execElement.AppendChild($wdElement) | Out-Null
            }

            $actionsNode.AppendChild($execElement) | Out-Null
        }
    }
}
