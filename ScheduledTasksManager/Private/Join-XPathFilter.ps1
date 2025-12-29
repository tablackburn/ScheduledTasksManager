function Join-XPathFilter {
    <#
    .SYNOPSIS
        Joins XPath filter components with logical operators.

    .DESCRIPTION
        This function handles the parenthesis and logical joining of XPath statements inside of
        Get-WinEventXPathFilter. It combines a new filter with an existing filter using the specified
        logical operator (and/or).

    .PARAMETER NewFilter
        The new XPath filter component to add.

    .PARAMETER ExistingFilter
        The existing XPath filter to combine with the new filter.

    .PARAMETER Logic
        The logical operator to use when joining filters. Valid values are 'and' and 'or'.
        Note that XPath logical operators are case sensitive.

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
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $NewFilter,

        [Parameter(Position = 1)]
        [string]
        $ExistingFilter = '',

        [Parameter(Position = 2)]
        [ValidateSet('and', 'or', IgnoreCase = $false)]
        [string]
        $Logic = 'and',

        [Parameter()]
        [switch]
        $NoParenthesis
    )

    if ($ExistingFilter) {
        # If there is an existing filter add parenthesis unless NoParenthesis is specified
        # and the logical operator
        if ($NoParenthesis) {
            return "$ExistingFilter $Logic $NewFilter"
        }
        else {
            return "($ExistingFilter) $Logic ($NewFilter)"
        }
    }
    else {
        return $NewFilter
    }
}
