function Get-TaskNameFromXml {
    <#
    .SYNOPSIS
        Extracts the task name from a Task Scheduler XML definition.

    .DESCRIPTION
        The Get-TaskNameFromXml function parses a Task Scheduler XML definition and extracts the task name
        from the RegistrationInfo/URI element. The URI element typically contains the full path to the task
        (e.g., '\Folder\TaskName'), and this function returns just the task name portion.

    .PARAMETER XmlContent
        The XML content string containing the Task Scheduler task definition.

    .EXAMPLE
        $xml = Get-Content -Path 'C:\Tasks\BackupTask.xml' -Raw
        $taskName = Get-TaskNameFromXml -XmlContent $xml

        Extracts the task name from the XML file content.

    .INPUTS
        None. You cannot pipe objects to Get-TaskNameFromXml.

    .OUTPUTS
        System.String
        Returns the task name extracted from the XML, or $null if the task name cannot be determined.

    .NOTES
        This is a private helper function used internally by Import-StmClusteredScheduledTask.
        The function expects valid Task Scheduler XML format with a RegistrationInfo/URI element.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $XmlContent
    )

    begin {
        Write-Verbose 'Starting Get-TaskNameFromXml'
    }

    process {
        try {
            [xml]$taskXml = $XmlContent

            # The URI element contains the task path/name
            # Format is typically like '\TaskName' or '\Folder\TaskName'
            $uri = $taskXml.Task.RegistrationInfo.URI

            if ([string]::IsNullOrWhiteSpace($uri)) {
                Write-Verbose 'No URI found in XML RegistrationInfo element'
                return $null
            }

            # Extract just the task name from the URI path
            # e.g., '\MyFolder\MyTask' -> 'MyTask'
            # Handle edge case where URI is just '\' (root)
            if ($uri -eq '\' -or $uri -eq '/') {
                Write-Verbose 'URI is root path only, no task name present'
                return $null
            }

            $taskName = Split-Path -Path $uri -Leaf

            if ([string]::IsNullOrWhiteSpace($taskName)) {
                Write-Verbose 'Could not extract task name from URI'
                return $null
            }

            Write-Verbose "Extracted task name: '$taskName'"
            return $taskName
        }
        catch {
            Write-Verbose "Failed to parse XML for task name: $($_.Exception.Message)"
            return $null
        }
    }

    end {
        Write-Verbose 'Completed Get-TaskNameFromXml'
    }
}
