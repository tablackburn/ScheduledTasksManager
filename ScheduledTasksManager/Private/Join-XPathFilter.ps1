function Join-XPathFilter {
    param(
        [Parameter(
            Mandatory = $True,
            Position = 0
        )]
        [String]
        $NewFilter,

        [Parameter(
            Position = 1
        )]
        [String]
        $ExistingFilter = '',

        [Parameter(
            Position = 2
        )]
        # and and or are case sensitive
        # in xpath
        [ValidateSet(
            'and',
            'or',
            IgnoreCase = $False
        )]
        [String]
        $Logic = 'and',

        [switch]$NoParenthesis
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
    <#
    .SYNOPSIS
    This function handles the parenthesis and logical joining
    of XPath statements inside of Get-WinEventXPathFilter
    #>
}
