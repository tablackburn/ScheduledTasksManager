function Update-StmTaskSettingsXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper that modifies in-memory XML only; parent function handles ShouldProcess')]
    <#
    .SYNOPSIS
        Updates the Settings section of a scheduled task XML document.

    .DESCRIPTION
        Updates task settings elements in a scheduled task XML document based on the
        provided settings object. This function modifies the XML document in place.

        Supports boolean settings, Priority, and ExecutionTimeLimit properties.

    .PARAMETER TaskXml
        The XML document representing the scheduled task configuration. This document is
        modified in place.

    .PARAMETER Settings
        A CIM settings object created by New-ScheduledTaskSettingsSet containing the
        settings to apply to the task.
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
        $Settings
    )

    process {
        $settingsNode = $TaskXml.Task.Settings
        $ns = $TaskXml.DocumentElement.NamespaceURI

        # Map common settings properties to XML elements
        $settingsMap = @{
            'AllowDemandStart'                = 'AllowStartOnDemand'
            'AllowHardTerminate'              = 'AllowHardTerminate'
            'DisallowStartIfOnBatteries'      = 'DisallowStartIfOnBatteries'
            'StopIfGoingOnBatteries'          = 'StopIfGoingOnBatteries'
            'Hidden'                          = 'Hidden'
            'RunOnlyIfNetworkAvailable'       = 'RunOnlyIfNetworkAvailable'
            'Enabled'                         = 'Enabled'
            'WakeToRun'                       = 'WakeToRun'
            'RunOnlyIfIdle'                   = 'RunOnlyIfIdle'
            'StartWhenAvailable'              = 'StartWhenAvailable'
            'DisallowStartOnRemoteAppSession' = 'DisallowStartOnRemoteAppSession'
            'UseUnifiedSchedulingEngine'      = 'UseUnifiedSchedulingEngine'
        }

        foreach ($prop in $settingsMap.Keys) {
            $value = $Settings.$prop
            if ($null -ne $value) {
                $xmlProp = $settingsMap[$prop]
                $existingNode = $settingsNode.SelectSingleNode("*[local-name()='$xmlProp']")
                if ($existingNode) {
                    $existingNode.InnerText = $value.ToString().ToLower()
                }
                else {
                    $newNode = $TaskXml.CreateElement($xmlProp, $ns)
                    $newNode.InnerText = $value.ToString().ToLower()
                    $settingsNode.AppendChild($newNode) | Out-Null
                }
            }
        }

        # Handle Priority
        if ($null -ne $Settings.Priority) {
            $priorityNode = $settingsNode.SelectSingleNode('*[local-name()="Priority"]')
            if ($priorityNode) {
                $priorityNode.InnerText = $Settings.Priority.ToString()
            }
            else {
                $newNode = $TaskXml.CreateElement('Priority', $ns)
                $newNode.InnerText = $Settings.Priority.ToString()
                $settingsNode.AppendChild($newNode) | Out-Null
            }
        }

        # Handle ExecutionTimeLimit
        if ($Settings.ExecutionTimeLimit) {
            $limitNode = $settingsNode.SelectSingleNode('*[local-name()="ExecutionTimeLimit"]')
            if ($limitNode) {
                $limitNode.InnerText = $Settings.ExecutionTimeLimit.ToString()
            }
            else {
                $newNode = $TaskXml.CreateElement('ExecutionTimeLimit', $ns)
                $newNode.InnerText = $Settings.ExecutionTimeLimit.ToString()
                $settingsNode.AppendChild($newNode) | Out-Null
            }
        }
    }
}
