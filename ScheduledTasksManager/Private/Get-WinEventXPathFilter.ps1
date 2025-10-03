function Get-WinEventXPathFilter {
    <#
    .SYNOPSIS
    This function generates an xpath filter that can be used with the -FilterXPath
    parameter of Get-WinEvent.  It may also be used inside the <Select></Select tags
    of a Custom View in Event Viewer.
    .DESCRIPTION
    This function generates an xpath filter that can be used with the -FilterXPath
    parameter of Get-WinEvent.  It may also be used inside the <Select></Select tags
    of a Custom View in Event Viewer.

    This function allows for the creation of xpath which can select events based on
    many properties of the event including those of named data nodes in the event's
    XML.

    XPath is case sensitive and the data passed to the parameters here must
    match the case of the data in the event's XML.
    .NOTES
    Original Code by https://community.spiceworks.com/scripts/show/3238-powershell-xpath-generator-for-windows-events
    Extended by Justin Grote
    .LINK

    .PARAMETER ID
    This parameter accepts an array of event ids to include in the xpath filter.
    .PARAMETER StartTime
    This parameter sets the oldest event that may be returned by the xpath.

    Please, note that the xpath time selector created here is based off of the
    time the xpath is generated.  XPath uses a time difference method to select
    events by time; that time difference being the number of milliseconds between
    the time and now.
    .PARAMETER EndTime
    This parameter sets the newest event that may be returned by the xpath.

    Please, note that the xpath time selector created here is based off of the
    time the xpath is generated.  XPath uses a time difference method to select
    events by time; that time difference being the number of milliseconds between
    the time and now.
    .PARAMETER Data
    This parameter will accept an array of values that may be found in the data
    section of the event's XML.
    .PARAMETER ProviderName
    This parameter will accept an array of values that select events from event
    providers.
    .PARAMETER Level
    This parameter will accept an array of values that specify the severity
    rating of the events to be returned.

    It accepts the following values.

    'Critical',
    'Error',
    'Informational',
    'LogAlways',
    'Verbose',
    'Warning'
    .PARAMETER Keywords
    This parameter accepts an array of long integer keywords. You must
    pass this parameter the long integer value of the keywords you want
    to search and not the keyword description.
    .PARAMETER UserID
    This parameter will accept an array of SIDs or domain accounts.
    .PARAMETER NamedDataFilter
    This parameter will accept an array of hashtables that define the key
    value pairs for which you want to filter against the event's named data
    fields.

    Key values, as with XPath filters, are case sensitive.

    You may assign an array as the value of any key. This will search
    for events where any of the values are present in that particular
    data field. If you wanted to define a filter that searches for a SubjectUserName
    of either john.doe or jane.doe, pass the following

    @{'SubjectUserName'=('john.doe','jane.doe')}

    You may specify multiple data fields and values. Doing so will create
    an XPath filter that will only return results where both values
    are found. If you only wanted to return events where both the
    SubjectUserName is john.doe and the TargetUserName is jane.doe, then
    pass the following

    @{'SubjectUserName'='john.doe';'TargetUserName'='jane.doe'}

    You may pass an array of hash tables to create an 'or' XPath filter
    that will return objects where either key value set will be returned.
    If you wanted to define a filter that searches for either a
    SubjectUserName of john.doe or a TargetUserName of jane.doe then pass
    the following

    (@{'SubjectUserName'='john.doe'},@{'TargetUserName'='jane.doe'})
    .EXAMPLE
    Get-WinEventXPathFilter -ID 4663 -NamedDataFilter @{'SubjectUserName'='john.doe'}

    This will return an XPath filter that will return any events with
    the id of 4663 and has a SubjectUserName of 'john.doe'
    .EXAMPLE
    Get-WinEventXPathFilter -StartTime '1/1/2015 01:30:00 PM' -EndTime '1/1/2015 02:00:00 PM'

    This will return an XPath filter that will return events that occurred between 1:30
    2:00 PM on 1/1/2015.  The filter will only be good if used immediately.  XPath time
    filters are based on the number of milliseconds that have occurred since the event
    and when the filter is used.  StartTime and EndTime simply calculate the number of
    milliseconds and use that for the filter.
    .EXAMPLE
    Get-WinEventXPathFilter -StartTime (Get-Date).AddDays(-1)

    This will return an XPath filter that will get events that occurred within the last
    24 hours.
    #>

    [CmdletBinding()]
    param(
        [String[]]
        $ID,

        [DateTime]
        $StartTime,

        [DateTime]
        $EndTime,

        [String[]]
        $Data,

        [String[]]
        $ProviderName,

        [Long[]]
        $Keywords,

        [ValidateSet(
            'Critical',
            'Error',
            'Informational',
            'LogAlways',
            'Verbose',
            'Warning'
        )]
        [String[]]
        $Level,

        [String[]]
        $UserID,

        [Hashtable[]]
        $NamedDataFilter,

        [Hashtable[]]
        $NamedDataExcludeFilter,

        [String[]]
        $ExcludeID

    )

    $filter = ''

    #region ID filter
    if ($ID) {
        $options = @{
            'Items'                = $ID
            'ForEachFormatString'  = 'EventID={0}'
            'FinalizeFormatString' = '*[System[{0}]]'
        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion ID filter

    #region Exclude ID filter
    if ($ExcludeID) {
        $options = @{
            'Items'                = $ExcludeID
            'ForEachFormatString'  = 'EventID!={0}'
            'FinalizeFormatString' = '*[System[{0}]]'
        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion Exclude ID filter

    #region Date filters
    $Now = Get-Date

    # Time in XPath is filtered based on the number of milliseconds
    # between the creation of the event and when the XPath filter is
    # used.
    #
    # The timediff xpath function is used against the SystemTime
    # attribute of the TimeCreated node.
    if ($StartTime) {
        $Diff = [Math]::Round($Now.Subtract($StartTime).TotalMilliseconds)
        $joinParameters = @{
            NewFilter      = "*[System[TimeCreated[timediff(@SystemTime) <= $Diff]]]"
            ExistingFilter = $filter
        }
        $filter = Join-XPathFilter @joinParameters
    }

    if ($EndTime) {
        $Diff = [Math]::Round($Now.Subtract($EndTime).TotalMilliseconds)
        $joinParameters = @{
            NewFilter      = "*[System[TimeCreated[timediff(@SystemTime) >= $Diff]]]"
            ExistingFilter = $filter
        }
        $filter = Join-XPathFilter @joinParameters
    }
    #endregion Date filters

    #region Data filter
    if ($Data) {
        $options = @{
            'Items'                = $Data
            'ForEachFormatString'  = "Data='{0}'"
            'FinalizeFormatString' = '*[EventData[{0}]]'
        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion Data filter

    #region ProviderName filter
    if ($ProviderName) {
        $options = @{
            'Items'                = $ProviderName
            'ForEachFormatString'  = "@Name='{0}'"
            'FinalizeFormatString' = '*[System[Provider[{0}]]]'
        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion ProviderName filter

    #region Level filter
    if ($Level) {
        $levels = foreach ($item in $Level) {
            # Levels in an event's XML are defined
            # with integer values.
            [Int][System.Diagnostics.Tracing.EventLevel]::$item
        }

        $options = @{
            'Items'                = $levels
            'ForEachFormatString'  = 'Level={0}'
            'FinalizeFormatString' = '*[System[{0}]]'
        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion Level filter

    #region Keyword filter
    # Keywords are stored as a long integer
    # numeric value.  That integer is the
    # flagged (binary) combination of
    # all the keywords.
    #
    # By combining all given keywords
    # with a binary OR operation, and then
    # taking the resultant number and
    # comparing that against the number
    # stored in the events XML with a
    # binary AND operation will return
    # events that have any of the submitted
    # keywords assigned.
    if ($Keywords) {
        $keyword_filter = ''

        foreach ($item in $Keywords) {
            if ($keyword_filter) {
                $keyword_filter = $keyword_filter -bor $item
            }
            else {
                $keyword_filter = $item
            }
        }

        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter "*[System[band(Keywords,$keyword_filter)]]"
    }
    #endregion Keyword filter

    #region UserID filter
    # The UserID attribute of the Security node contains a Sid.
    if ($UserID) {
        $sids = foreach ($item in $UserID) {
            try {
                #If the value submitted isn't a valid sid, it'll error.
                $sid = [System.Security.Principal.SecurityIdentifier]($item)
                $sid = $sid.Translate([System.Security.Principal.SecurityIdentifier])
            }
            catch [System.Management.Automation.RuntimeException] {
                # If a RuntimeException occurred with an InvalidArgument category
                # attempt to create an NTAccount object and resolve.
                if ($Error[0].CategoryInfo.Category -eq 'InvalidArgument') {
                    try {
                        $user = [System.Security.Principal.NTAccount]($item)
                        $sid = $user.Translate([System.Security.Principal.SecurityIdentifier])
                    }
                    catch {
                        #There was an error with either creating the NTAccount or
                        #Translating that object to a sid.
                        throw $Error[0]
                    }
                }
                else {
                    #There was a RuntimeException from either creating the
                    #SecurityIdentifier object or the translation
                    #and the category was not InvalidArgument
                    throw $Error[0]
                }
            }
            catch {
                #There was an error from either the creation of the SecurityIdentifier
                #object or the Translation
                throw $Error[0]
            }

            $sid.Value
        }

        $options = @{
            'Items'                = $sids
            'ForEachFormatString'  = "@UserID='{0}'"
            'FinalizeFormatString' = '*[System[Security[{0}]]]'
        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion UserID filter

    #region NamedDataFilter
    if ($NamedDataFilter) {
        $options = @{
            'Items'                = $(
                # This will create set of data filters for each of
                # the hash tables submitted in the hash table array
                foreach ($item in $NamedDataFilter) {
                    $options = @{
                        'Items'                = $(
                            #This will result in as set of XPath subexpressions
                            #for each key submitted in the hashtable
                            foreach ($key in $item.Keys) {
                                if ($item[$key]) {
                                    #If there is a value for the key, create the
                                    #XPath for the Data node with that Name attribute
                                    #and value. Use 'and' logic to join the data values.
                                    #to the Name Attribute.
                                    $options = @{
                                        'Items'                = $item[$key]
                                        'NoParenthesis'        = $true
                                        'ForEachFormatString'  = "'{0}'"
                                        'FinalizeFormatString' = "Data[@Name='$key'] = {0}"
                                    }
                                    Initialize-XPathFilter @options
                                }
                                else {
                                    #If there isn't a value for the key, create
                                    #XPath for the existence of the Data node with
                                    #that particular Name attribute.
                                    "Data[@Name='$key']"
                                }
                            }
                        )
                        'ForEachFormatString'  = '{0}'
                        'FinalizeFormatString' = '{0}'
                    }
                    Initialize-XPathFilter @options
                }
            )
            'ForEachFormatString'  = '{0}'
            'FinalizeFormatString' = '*[EventData[{0}]]'

        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion NamedDataFilter

    #region NamedDataExcludeFilter
    if ($NamedDataExcludeFilter) {
        $options = @{
            'Items'                = $(
                # This will create set of data filters for each of
                # the hash tables submitted in the hash table array
                foreach ($item in $NamedDataExcludeFilter) {
                    $options = @{
                        'Items'                = $(
                            #This will result in as set of XPath subexpressions
                            #for each key submitted in the hashtable
                            foreach ($key in $item.Keys) {
                                if ($item[$key]) {
                                    #If there is a value for the key, create the
                                    #XPath for the Data node with that Name attribute
                                    #and value. Use 'and' logic to join the data values.
                                    #to the Name Attribute.
                                    $options = @{
                                        'Items'                = $item[$key]
                                        'NoParenthesis'        = $true
                                        'ForEachFormatString'  = "'{0}'"
                                        'FinalizeFormatString' = "Data[@Name='$key'] != {0}"
                                    }
                                    Initialize-XPathFilter @options
                                }
                                else {
                                    #If there isn't a value for the key, create
                                    #XPath for the existence of the Data node with
                                    #that particular Name attribute.
                                    "Data[@Name='$key']"
                                }
                            }
                        )
                        'ForEachFormatString'  = '{0}'
                        'FinalizeFormatString' = '{0}'
                    }
                    Initialize-XPathFilter @options
                }
            )
            'ForEachFormatString'  = '{0}'
            'FinalizeFormatString' = '*[EventData[{0}]]'

        }
        $filter = Join-XPathFilter -ExistingFilter $filter -NewFilter (Initialize-XPathFilter @options)
    }
    #endregion NamedDataExcludeFilter

    return $filter

} # Function Get-WinEventXPathFilter
