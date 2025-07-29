function Initialize-XPathFilter {
    param(
        [Object[]]
        $Items,

        [String]
        $ForEachFormatString,

        [String]
        $FinalizeFormatString,

        [switch]$NoParenthesis
    )

    $filter = ''

    foreach ($item in $Items) {
        $options = @{
            'NewFilter'      = ($ForEachFormatString -f $item)
            'ExistingFilter' = $filter
            'Logic'          = 'or'
            'NoParenthesis'  = $NoParenthesis
        }
        $filter = Join-XPathFilter @options
    }

    return $FinalizeFormatString -f $filter
    <#
    .SYNOPSIS
    This function loops thru a set of items and injecting each
    item in the format string given by ForEachFormatString, then
    combines each of those items together with 'or' logic
    using the function Join-XPathFilter, which handles the
    joining and parenthesis.  Before returning the result,
    it injects the resultant xpath into FinalizeFormatString.

    This function is a part of Get-WinEventXPathFilter
    #>
}
