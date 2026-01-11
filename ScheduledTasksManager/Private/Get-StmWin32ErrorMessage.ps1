function Get-StmWin32ErrorMessage {
    <#
    .SYNOPSIS
        Retrieves the Win32 error message for a given error code.

    .DESCRIPTION
        Wraps System.ComponentModel.Win32Exception to translate Win32 error codes
        into human-readable messages. Returns $null if translation fails.

    .PARAMETER ErrorCode
        The Win32 error code to translate.

    .OUTPUTS
        System.String or $null
        Returns the error message string, or $null if translation fails.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $ErrorCode
    )

    process {
        Write-Verbose "Translating Win32 error code: $ErrorCode"

        try {
            $win32Exception = [System.ComponentModel.Win32Exception]::new($ErrorCode)
            $message = $win32Exception.Message

            Write-Verbose "Win32 translation result: $message"
            return $message
        }
        catch {
            Write-Verbose "Failed to translate Win32 error code ${ErrorCode}: $_"
            return $null
        }
    }
}
