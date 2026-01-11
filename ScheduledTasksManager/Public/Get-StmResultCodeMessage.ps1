function Get-StmResultCodeMessage {
    <#
    .SYNOPSIS
        Translates Windows Task Scheduler result codes to human-readable messages.

    .DESCRIPTION
        The Get-StmResultCodeMessage function translates numeric result codes from Windows Task Scheduler
        into human-readable messages. This is useful for understanding the meaning of cryptic result codes
        returned by scheduled tasks.

        The function uses a three-tier translation approach:
        1. Task Scheduler-specific codes (SCHED_S_*, SCHED_E_*) from Microsoft documentation
        2. HRESULT decoding for Win32 error codes wrapped in HRESULT format
        3. Direct Win32 error code translation for small positive integers

        For codes that may have multiple interpretations, all possible meanings are returned in the
        Meanings property, with the most likely interpretation shown in the Message property.

    .PARAMETER ResultCode
        The result code to translate. Accepts:
        - Integer values (e.g., 267521, 2147942402)
        - Decimal strings (e.g., '267521')
        - Hexadecimal strings with 0x prefix (e.g., '0x8004131F', '0x80070002')

        Multiple codes can be provided via the pipeline.

    .EXAMPLE
        Get-StmResultCodeMessage -ResultCode 0

        ResultCode   : 0
        HexCode      : 0x00000000
        Message      : The operation completed successfully
        Source       : Win32
        ConstantName : ERROR_SUCCESS
        IsSuccess    : True
        Facility     : FACILITY_NULL
        FacilityCode : 0
        Meanings     : {...}

        Translates the success code 0.

    .EXAMPLE
        Get-StmResultCodeMessage -ResultCode 267521

        Translates SCHED_S_TASK_RUNNING to show "The task is currently running".

    .EXAMPLE
        Get-StmResultCodeMessage -ResultCode '0x8004131F'

        Translates the hex code for SCHED_E_ALREADY_RUNNING.

    .EXAMPLE
        0, 267521, 2147750687 | Get-StmResultCodeMessage

        Translates multiple result codes via pipeline input.

    .EXAMPLE
        Get-StmScheduledTaskRun -TaskName 'MyTask' | Select-Object -ExpandProperty ResultCode |
            Get-StmResultCodeMessage

        Translates result codes from task run history.

    .EXAMPLE
        Get-StmResultCodeMessage -ResultCode 2147942402 | Select-Object -ExpandProperty Meanings

        Shows all possible meanings for an ambiguous code. In this case, shows that 0x80070002
        is "The system cannot find the file specified" (Win32 ERROR_FILE_NOT_FOUND).

    .INPUTS
        System.Object
        Accepts result codes as integers, decimal strings, or hex strings via pipeline.

    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - ResultCode: The original code as an integer
        - HexCode: The code in hexadecimal format (0x00000000)
        - Message: The primary translated message
        - Source: Where the translation came from (TaskScheduler, Win32, Unknown)
        - ConstantName: The constant name if known (e.g., SCHED_S_TASK_RUNNING)
        - IsSuccess: Whether the code indicates success or failure
        - Facility: The HRESULT facility name
        - FacilityCode: The HRESULT facility code number
        - Meanings: Array of all possible interpretations for ambiguous codes

    .NOTES
        Task Scheduler codes are sourced from Microsoft documentation:
        https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants

        Common result codes:
        - 0: Success
        - 267521 (0x00041301): Task is currently running
        - 267523 (0x00041303): Task has not yet run
        - 2147750687 (0x8004131F): An instance of this task is already running
        - 2147942402 (0x80070002): File not found

    .LINK
        Get-StmScheduledTaskRun

    .LINK
        Get-StmClusteredScheduledTaskRun

    .LINK
        https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        [object]
        $ResultCode
    )

    process {
        Write-Verbose "Translating result code: $ResultCode"
        $result = ConvertTo-StmResultMessage -ResultCode $ResultCode

        if ($null -eq $result) {
            Write-Verbose 'No translation result returned'
            return
        }

        Write-Verbose "Translation result: $($result.Message) (Source: $($result.Source))"
        return $result
    }
}
