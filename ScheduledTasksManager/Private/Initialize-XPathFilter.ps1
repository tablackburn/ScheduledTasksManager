function Initialize-XPathFilter {
    <#
    .SYNOPSIS
        Initializes an XPath filter by combining items with a format string.

    .DESCRIPTION
        This function loops through a set of items and injects each item in the format string given by
        ForEachFormatString, then combines each of those items together with 'or' logic using the function
        Join-XPathFilter, which handles the joining and parenthesis. Before returning the result, it injects
        the resultant XPath into FinalizeFormatString.

        This function is a part of Get-WinEventXPathFilter.

    .PARAMETER Items
        The array of items to process and combine into an XPath filter.

    .PARAMETER ForEachFormatString
        The format string to apply to each item. Use {0} as the placeholder for the item value.

    .PARAMETER FinalizeFormatString
        The format string to wrap the combined result. Use {0} as the placeholder for the combined filter.

    .PARAMETER NoParenthesis
        When specified, omits parenthesis when joining filter components.

    .OUTPUTS
        System.String

    .NOTES
        This is a private helper function used internally by Get-WinEventXPathFilter.
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object[]]
        $Items,

        [Parameter()]
        [string]
        $ForEachFormatString,

        [Parameter()]
        [string]
        $FinalizeFormatString,

        [Parameter()]
        [switch]
        $NoParenthesis
    )

    $filter = ''

    foreach ($item in $Items) {
        $options = @{
            NewFilter      = ($ForEachFormatString -f $item)
            ExistingFilter = $filter
            Logic          = 'or'
            NoParenthesis  = $NoParenthesis
        }
        $filter = Join-XPathFilter @options
    }

    return $FinalizeFormatString -f $filter
}
