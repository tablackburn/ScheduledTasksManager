function Merge-Object {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]
        $FirstObject,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FirstObjectName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]
        $SecondObject,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SecondObjectName,

        [Parameter(Mandatory = $false)]
        [switch]
        $AsHashtable
    )

    begin {
        Write-Debug 'Starting Merge-Object'
    }

    process {
        $firstObjectProperties = $FirstObject | Get-Member -MemberType 'Properties' | Select-Object -ExpandProperty 'Name'
        $secondObjectProperties = $SecondObject | Get-Member -MemberType 'Properties' | Select-Object -ExpandProperty 'Name'

        $uniqueFirstObjectProperties = $firstObjectProperties | Where-Object { $_ -notin $secondObjectProperties }
        $uniqueSecondObjectProperties = $secondObjectProperties | Where-Object { $_ -notin $firstObjectProperties }

        $sharedProperties = $firstObjectProperties | Where-Object { $_ -in $secondObjectProperties }

        $result = [ordered]@{}

        # Add unique properties from both objects
        foreach ($property in $uniqueFirstObjectProperties) {
            $result[$property] = $FirstObject.$property
        }
        foreach ($property in $uniqueSecondObjectProperties) {
            $result[$property] = $SecondObject.$property
        }

        # Add shared properties with handling for different values
        # If the values are the same, just use one value
        # If they differ, create a hashtable with both values
        # If FirstObjectName or SecondObjectName are provided, use them as keys in the hashtable
        # Otherwise, use generic keys 'FirstObject' and 'SecondObject'
        foreach ($property in $sharedProperties) {
            if ($FirstObject.$property -eq $SecondObject.$property) {
                $result[$property] = $FirstObject.$property
            }
            else {
                $result[$property] = @{}
                if ($PSBoundParameters.ContainsKey('FirstObjectName')) {
                    $result[$property][$FirstObjectName] = $FirstObject.$property
                }
                else {
                    $result[$property]['FirstObject'] = $FirstObject.$property
                }
                if ($PSBoundParameters.ContainsKey('SecondObjectName')) {
                    $result[$property][$SecondObjectName] = $SecondObject.$property
                }
                else {
                    $result[$property]['SecondObject'] = $SecondObject.$property
                }
            }
        }

        # Add the original objects to the result, using the provided names if available
        if ($PSBoundParameters.ContainsKey('FirstObjectName')) {
            $result[$FirstObjectName] = $FirstObject
        }
        else {
            $result['FirstObject'] = $FirstObject
        }
        if ($PSBoundParameters.ContainsKey('SecondObjectName')) {
            $result[$SecondObjectName] = $SecondObject
        }
        else {
            $result['SecondObject'] = $SecondObject
        }


        if ($AsHashtable) {
            $result
        }
        else {
            [PSCustomObject]$result
        }
    }

    end {
        Write-Debug 'Finished Merge-Object'
    }
}
