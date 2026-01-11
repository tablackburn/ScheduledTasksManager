function Update-StmTaskTriggerXml {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper that modifies in-memory XML only; parent function handles ShouldProcess')]
    <#
    .SYNOPSIS
        Updates the Triggers section of a scheduled task XML document.

    .DESCRIPTION
        Clears existing triggers from a scheduled task XML document and replaces them
        with new triggers from the provided CIM trigger objects. This function modifies
        the XML document in place.

        Supports the following trigger types:
        - Daily (CalendarTrigger with ScheduleByDay)
        - Weekly (CalendarTrigger with ScheduleByWeek)
        - Once (TimeTrigger)
        - Logon (LogonTrigger)
        - Boot (BootTrigger)

    .PARAMETER TaskXml
        The XML document representing the scheduled task configuration. This document is
        modified in place.

    .PARAMETER Trigger
        An array of CIM trigger objects created by New-ScheduledTaskTrigger. Each trigger
        defines when the task should run.
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
        $Trigger
    )

    process {
        $triggersNode = $TaskXml.Task.Triggers
        $ns = $TaskXml.DocumentElement.NamespaceURI

        # Clear existing triggers
        $triggersNode.RemoveAll()

        # Add new triggers based on type
        foreach ($trig in $Trigger) {
            $triggerElement = $null
            $triggerType = $trig.CimClass.CimClassName

            switch -Wildcard ($triggerType) {
                '*Daily*' {
                    $triggerElement = $TaskXml.CreateElement('CalendarTrigger', $ns)
                    $schedByDay = $TaskXml.CreateElement('ScheduleByDay', $ns)
                    $daysInterval = $TaskXml.CreateElement('DaysInterval', $ns)
                    $daysInterval.InnerText = if ($trig.DaysInterval) {
                        $trig.DaysInterval
                    }
                    else {
                        '1'
                    }
                    $schedByDay.AppendChild($daysInterval) | Out-Null
                    $triggerElement.AppendChild($schedByDay) | Out-Null
                }
                '*Weekly*' {
                    $triggerElement = $TaskXml.CreateElement('CalendarTrigger', $ns)
                    $schedByWeek = $TaskXml.CreateElement('ScheduleByWeek', $ns)

                    # Add WeeksInterval
                    $weeksInterval = $TaskXml.CreateElement('WeeksInterval', $ns)
                    $weeksInterval.InnerText = if ($trig.WeeksInterval) { $trig.WeeksInterval } else { '1' }
                    $schedByWeek.AppendChild($weeksInterval) | Out-Null

                    # Add DaysOfWeek - Windows Task Scheduler uses bit flags (Sunday=1, Monday=2, Tuesday=4, etc.)
                    if ($trig.DaysOfWeek) {
                        $daysOfWeek = $TaskXml.CreateElement('DaysOfWeek', $ns)
                        $dayFlags = @{
                            Sunday    = 1
                            Monday    = 2
                            Tuesday   = 4
                            Wednesday = 8
                            Thursday  = 16
                            Friday    = 32
                            Saturday  = 64
                        }
                        foreach ($dayName in $dayFlags.Keys) {
                            if ($trig.DaysOfWeek -band $dayFlags[$dayName]) {
                                $dayElement = $TaskXml.CreateElement($dayName, $ns)
                                $daysOfWeek.AppendChild($dayElement) | Out-Null
                            }
                        }
                        $schedByWeek.AppendChild($daysOfWeek) | Out-Null
                    }

                    $triggerElement.AppendChild($schedByWeek) | Out-Null
                }
                '*TimeTrigger*' {
                    $triggerElement = $TaskXml.CreateElement('TimeTrigger', $ns)
                }
                '*Logon*' {
                    $triggerElement = $TaskXml.CreateElement('LogonTrigger', $ns)
                }
                '*Boot*' {
                    $triggerElement = $TaskXml.CreateElement('BootTrigger', $ns)
                }
                default {
                    Write-Warning "Unknown trigger type '$triggerType'. Falling back to TimeTrigger."
                    $triggerElement = $TaskXml.CreateElement('TimeTrigger', $ns)
                }
            }

            if ($triggerElement) {
                # Add start boundary if available
                if ($trig.StartBoundary) {
                    $startBoundary = $TaskXml.CreateElement('StartBoundary', $ns)
                    $startBoundary.InnerText = $trig.StartBoundary
                    $triggerElement.PrependChild($startBoundary) | Out-Null
                }

                # Add enabled status
                $enabled = $TaskXml.CreateElement('Enabled', $ns)
                $enabled.InnerText = if ($trig.Enabled -eq $false) {
                    'false'
                }
                else {
                    'true'
                }
                $triggerElement.AppendChild($enabled) | Out-Null

                $triggersNode.AppendChild($triggerElement) | Out-Null
            }
        }
    }
}
