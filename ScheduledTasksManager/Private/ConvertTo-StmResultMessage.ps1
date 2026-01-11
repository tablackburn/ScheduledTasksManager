function ConvertTo-StmResultMessage {
    <#
    .SYNOPSIS
        Converts a Task Scheduler result code to a human-readable message.

    .DESCRIPTION
        The ConvertTo-StmResultMessage function translates numeric result codes from Windows Task Scheduler
        into human-readable messages. It uses a three-tier translation approach:

        1. Task Scheduler-specific codes (SCHED_S_*, SCHED_E_*) - highest confidence
        2. HRESULT decoding (parses structure, extracts Win32 code) - medium-high confidence
        3. Direct Win32/application codes - medium confidence
        4. Unknown codes - returns original with hex representation

        For ambiguous codes that may have multiple meanings, all possible interpretations are returned
        in the Meanings array.

    .PARAMETER ResultCode
        The result code to translate. Accepts integer, decimal string, or hex string (with 0x prefix).

    .EXAMPLE
        ConvertTo-StmResultMessage -ResultCode 0

        Translates the success code 0 to "The operation completed successfully".

    .EXAMPLE
        ConvertTo-StmResultMessage -ResultCode 267521

        Translates SCHED_S_TASK_RUNNING to "The task is currently running".

    .EXAMPLE
        ConvertTo-StmResultMessage -ResultCode '0x8004131F'

        Translates SCHED_E_ALREADY_RUNNING from hex format.

    .EXAMPLE
        ConvertTo-StmResultMessage -ResultCode 2147942402

        Translates the HRESULT 0x80070002 to "The system cannot find the file specified".

    .INPUTS
        System.Object
        Accepts result codes as integers, strings (decimal), or hex strings.

    .OUTPUTS
        PSCustomObject
        Returns an object with translation details including ResultCode, HexCode, Message, Source,
        ConstantName, IsSuccess, Facility, FacilityCode, and Meanings array.

    .NOTES
        This function is used internally by Get-StmResultCodeMessage and Get-StmScheduledTaskRun.
        Task Scheduler codes are sourced from Microsoft documentation:
        https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [object]
        $ResultCode
    )

    begin {
        # Task Scheduler-specific codes from Microsoft documentation
        # Source: https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants
        $script:TaskSchedulerCodes = @{
            # Success codes (SCHED_S_*)
            # Hex 0x00041300 = decimal 267008
            267008 = @{
                Name      = 'SCHED_S_TASK_READY'
                Message   = 'The task is ready to run at its next scheduled time'
                IsSuccess = $true
            }
            # Hex 0x00041301 = decimal 267009
            267009 = @{
                Name      = 'SCHED_S_TASK_RUNNING'
                Message   = 'The task is currently running'
                IsSuccess = $true
            }
            # Hex 0x00041302 = decimal 267010
            267010 = @{
                Name      = 'SCHED_S_TASK_DISABLED'
                Message   = 'The task will not run at the scheduled times because it has been disabled'
                IsSuccess = $true
            }
            # Hex 0x00041303 = decimal 267011
            267011 = @{
                Name      = 'SCHED_S_TASK_HAS_NOT_RUN'
                Message   = 'The task has not yet run'
                IsSuccess = $true
            }
            # Hex 0x00041304 = decimal 267012
            267012 = @{
                Name      = 'SCHED_S_TASK_NO_MORE_RUNS'
                Message   = 'There are no more runs scheduled for this task'
                IsSuccess = $true
            }
            # Hex 0x00041305 = decimal 267013
            267013 = @{
                Name      = 'SCHED_S_TASK_NOT_SCHEDULED'
                Message   = 'One or more of the properties needed to run this task on a schedule have not been set'
                IsSuccess = $true
            }
            # Hex 0x00041306 = decimal 267014
            267014 = @{
                Name      = 'SCHED_S_TASK_TERMINATED'
                Message   = 'The last run of the task was terminated by the user'
                IsSuccess = $true
            }
            # Hex 0x00041307 = decimal 267015
            267015 = @{
                Name      = 'SCHED_S_TASK_NO_VALID_TRIGGERS'
                Message   = 'Either the task has no triggers or the existing triggers are disabled or not set'
                IsSuccess = $true
            }
            # Hex 0x00041308 = decimal 267016
            267016 = @{
                Name      = 'SCHED_S_EVENT_TRIGGER'
                Message   = 'Event triggers do not have set run times'
                IsSuccess = $true
            }
            # Hex 0x0004131B = decimal 267035
            267035 = @{
                Name      = 'SCHED_S_SOME_TRIGGERS_FAILED'
                Message   = 'The task is registered, but not all specified triggers will start the task'
                IsSuccess = $true
            }
            # Hex 0x0004131C = decimal 267036
            267036 = @{
                Name      = 'SCHED_S_BATCH_LOGON_PROBLEM'
                Message   = 'The task is registered, but may fail to start. Batch logon privilege needs to be enabled for the task principal'
                IsSuccess = $true
            }
            # Hex 0x00041325 = decimal 267045
            267045 = @{
                Name      = 'SCHED_S_TASK_QUEUED'
                Message   = 'The Task Scheduler service has asked the task to run'
                IsSuccess = $true
            }

            # Error codes (SCHED_E_*)
            6200 = @{
                Name      = 'SCHED_E_SERVICE_NOT_LOCALSYSTEM'
                Message   = 'The Task Scheduler service must be configured to run in the System account to function properly'
                IsSuccess = $false
            }
            2147750665 = @{
                Name      = 'SCHED_E_TRIGGER_NOT_FOUND'
                Message   = 'Trigger not found'
                IsSuccess = $false
            }
            2147750666 = @{
                Name      = 'SCHED_E_TASK_NOT_READY'
                Message   = 'One or more of the properties needed to run this task have not been set'
                IsSuccess = $false
            }
            2147750667 = @{
                Name      = 'SCHED_E_TASK_NOT_RUNNING'
                Message   = 'There is no running instance of the task'
                IsSuccess = $false
            }
            2147750668 = @{
                Name      = 'SCHED_E_SERVICE_NOT_INSTALLED'
                Message   = 'The Task Scheduler Service is not installed on this computer'
                IsSuccess = $false
            }
            2147750669 = @{
                Name      = 'SCHED_E_CANNOT_OPEN_TASK'
                Message   = 'The task object could not be opened'
                IsSuccess = $false
            }
            2147750670 = @{
                Name      = 'SCHED_E_INVALID_TASK'
                Message   = 'The object is either an invalid task object or is not a task object'
                IsSuccess = $false
            }
            2147750671 = @{
                Name      = 'SCHED_E_ACCOUNT_INFORMATION_NOT_SET'
                Message   = 'No account information could be found in the Task Scheduler security database for the task indicated'
                IsSuccess = $false
            }
            2147750672 = @{
                Name      = 'SCHED_E_ACCOUNT_NAME_NOT_FOUND'
                Message   = 'Unable to establish existence of the account specified'
                IsSuccess = $false
            }
            2147750673 = @{
                Name      = 'SCHED_E_ACCOUNT_DBASE_CORRUPT'
                Message   = 'Corruption was detected in the Task Scheduler security database; the database has been reset'
                IsSuccess = $false
            }
            2147750674 = @{
                Name      = 'SCHED_E_NO_SECURITY_SERVICES'
                Message   = 'Task Scheduler security services are available only on Windows NT'
                IsSuccess = $false
            }
            2147750675 = @{
                Name      = 'SCHED_E_UNKNOWN_OBJECT_VERSION'
                Message   = 'The task object version is either unsupported or invalid'
                IsSuccess = $false
            }
            2147750676 = @{
                Name      = 'SCHED_E_UNSUPPORTED_ACCOUNT_OPTION'
                Message   = 'The task has been configured with an unsupported combination of account settings and run time options'
                IsSuccess = $false
            }
            2147750677 = @{
                Name      = 'SCHED_E_SERVICE_NOT_RUNNING'
                Message   = 'The Task Scheduler Service is not running'
                IsSuccess = $false
            }
            2147750678 = @{
                Name      = 'SCHED_E_UNEXPECTEDNODE'
                Message   = 'The task XML contains an unexpected node'
                IsSuccess = $false
            }
            2147750679 = @{
                Name      = 'SCHED_E_NAMESPACE'
                Message   = 'The task XML contains an element or attribute from an unexpected namespace'
                IsSuccess = $false
            }
            2147750680 = @{
                Name      = 'SCHED_E_INVALIDVALUE'
                Message   = 'The task XML contains a value which is incorrectly formatted or out of range'
                IsSuccess = $false
            }
            2147750681 = @{
                Name      = 'SCHED_E_MISSINGNODE'
                Message   = 'The task XML is missing a required element or attribute'
                IsSuccess = $false
            }
            2147750682 = @{
                Name      = 'SCHED_E_MALFORMEDXML'
                Message   = 'The task XML is malformed'
                IsSuccess = $false
            }
            2147750685 = @{
                Name      = 'SCHED_E_TOO_MANY_NODES'
                Message   = 'The task XML contains too many nodes of the same type'
                IsSuccess = $false
            }
            2147750686 = @{
                Name      = 'SCHED_E_PAST_END_BOUNDARY'
                Message   = 'The task cannot be started after the trigger end boundary'
                IsSuccess = $false
            }
            2147750687 = @{
                Name      = 'SCHED_E_ALREADY_RUNNING'
                Message   = 'An instance of this task is already running'
                IsSuccess = $false
            }
            2147750688 = @{
                Name      = 'SCHED_E_USER_NOT_LOGGED_ON'
                Message   = 'The task will not run because the user is not logged on'
                IsSuccess = $false
            }
            2147750689 = @{
                Name      = 'SCHED_E_INVALID_TASK_HASH'
                Message   = 'The task image is corrupt or has been tampered with'
                IsSuccess = $false
            }
            2147750690 = @{
                Name      = 'SCHED_E_SERVICE_NOT_AVAILABLE'
                Message   = 'The Task Scheduler service is not available'
                IsSuccess = $false
            }
            2147750691 = @{
                Name      = 'SCHED_E_SERVICE_TOO_BUSY'
                Message   = 'The Task Scheduler service is too busy to handle your request. Please try again later'
                IsSuccess = $false
            }
            2147750692 = @{
                Name      = 'SCHED_E_TASK_ATTEMPTED'
                Message   = 'The Task Scheduler service attempted to run the task, but the task did not run due to one of the constraints in the task definition'
                IsSuccess = $false
            }
            2147750694 = @{
                Name      = 'SCHED_E_TASK_DISABLED'
                Message   = 'The task is disabled'
                IsSuccess = $false
            }
            2147750695 = @{
                Name      = 'SCHED_E_TASK_NOT_V1_COMPAT'
                Message   = 'The task has properties that are not compatible with previous versions of Windows'
                IsSuccess = $false
            }
            2147750696 = @{
                Name      = 'SCHED_E_START_ON_DEMAND'
                Message   = 'The task settings do not allow the task to start on demand'
                IsSuccess = $false
            }
            2147750697 = @{
                Name      = 'SCHED_E_TASK_NOT_UBPM_COMPAT'
                Message   = 'The combination of properties that task is using is not compatible with the scheduling engine'
                IsSuccess = $false
            }
            2147750704 = @{
                Name      = 'SCHED_E_DEPRECATED_FEATURE_USED'
                Message   = 'The task definition uses a deprecated feature'
                IsSuccess = $false
            }

            # Common COM/OLE errors seen in task results (FACILITY_ITF)
            # These are not Task Scheduler specific but commonly appear when tasks fail
            2147746065 = @{
                Name      = 'CLASS_E_CLASSNOTAVAILABLE'
                Message   = 'ClassFactory cannot supply requested class'
                IsSuccess = $false
            }
            2147746132 = @{
                Name      = 'REGDB_E_CLASSNOTREG'
                Message   = 'Class not registered'
                IsSuccess = $false
            }
        }

        # Common HRESULT facility codes
        $script:FacilityCodes = @{
            0  = 'FACILITY_NULL'
            1  = 'FACILITY_RPC'
            2  = 'FACILITY_DISPATCH'
            3  = 'FACILITY_STORAGE'
            4  = 'FACILITY_ITF'
            7  = 'FACILITY_WIN32'
            8  = 'FACILITY_WINDOWS'
            9  = 'FACILITY_SECURITY'
            10 = 'FACILITY_CONTROL'
            11 = 'FACILITY_CERT'
            12 = 'FACILITY_INTERNET'
            13 = 'FACILITY_MEDIASERVER'
            14 = 'FACILITY_MSMQ'
            15 = 'FACILITY_SETUPAPI'
            16 = 'FACILITY_SCARD'
            17 = 'FACILITY_COMPLUS'
            18 = 'FACILITY_AAF'
            19 = 'FACILITY_URT'
            20 = 'FACILITY_ACS'
            21 = 'FACILITY_DPLAY'
            22 = 'FACILITY_UMI'
            23 = 'FACILITY_SXS'
            24 = 'FACILITY_WINDOWS_CE'
            25 = 'FACILITY_HTTP'
            26 = 'FACILITY_USERMODE_COMMONLOG'
            31 = 'FACILITY_USERMODE_FILTER_MANAGER'
            32 = 'FACILITY_BACKGROUNDCOPY'
            33 = 'FACILITY_CONFIGURATION'
            34 = 'FACILITY_STATE_MANAGEMENT'
            35 = 'FACILITY_METADIRECTORY'
            36 = 'FACILITY_WINDOWSUPDATE'
            37 = 'FACILITY_DIRECTORYSERVICE'
            38 = 'FACILITY_GRAPHICS'
            39 = 'FACILITY_SHELL'
            40 = 'FACILITY_TPM_SERVICES'
            41 = 'FACILITY_TPM_SOFTWARE'
            48 = 'FACILITY_PLA'
            49 = 'FACILITY_FVE'
            50 = 'FACILITY_FWP'
            51 = 'FACILITY_WINRM'
            52 = 'FACILITY_NDIS'
            53 = 'FACILITY_USERMODE_HYPERVISOR'
            54 = 'FACILITY_CMI'
            55 = 'FACILITY_USERMODE_VIRTUALIZATION'
            56 = 'FACILITY_USERMODE_VOLMGR'
            57 = 'FACILITY_BCD'
            58 = 'FACILITY_USERMODE_VHD'
            60 = 'FACILITY_SDIAG'
            61 = 'FACILITY_WEBSERVICES'
            80 = 'FACILITY_WINDOWS_DEFENDER'
            81 = 'FACILITY_OPC'
        }
    }

    process {
        # Handle null or empty input
        if ($null -eq $ResultCode -or ($ResultCode -is [string] -and [string]::IsNullOrWhiteSpace($ResultCode))) {
            Write-Verbose 'ResultCode is null or empty, returning null'
            return $null
        }

        # Parse the input to get an integer value
        [int64]$codeValue = 0
        $parseSuccess = $false

        if ($ResultCode -is [int] -or $ResultCode -is [int64] -or $ResultCode -is [uint32]) {
            $codeValue = [int64]$ResultCode
            $parseSuccess = $true
            Write-Verbose "Parsed integer input: $codeValue"
        }
        elseif ($ResultCode -is [string]) {
            $stringValue = $ResultCode.Trim()

            # Check for hex format (0x or 0X prefix)
            if ($stringValue -match '^0[xX]([0-9a-fA-F]+)$') {
                try {
                    $codeValue = [Convert]::ToInt64($Matches[1], 16)
                    $parseSuccess = $true
                    Write-Verbose "Parsed hex string input '$stringValue' to: $codeValue"
                }
                catch {
                    Write-Verbose "Failed to parse hex string '$stringValue': $_"
                }
            }
            else {
                # Try to parse as decimal
                if ([int64]::TryParse($stringValue, [ref]$codeValue)) {
                    $parseSuccess = $true
                    Write-Verbose "Parsed decimal string input '$stringValue' to: $codeValue"
                }
                else {
                    Write-Verbose "Failed to parse decimal string '$stringValue'"
                }
            }
        }
        else {
            # Try to convert other types
            try {
                $codeValue = [int64]$ResultCode
                $parseSuccess = $true
                Write-Verbose "Converted input type '$($ResultCode.GetType().Name)' to: $codeValue"
            }
            catch {
                Write-Verbose "Failed to convert input type '$($ResultCode.GetType().Name)': $_"
            }
        }

        if (-not $parseSuccess) {
            Write-Warning "Unable to parse result code: $ResultCode"
            return [PSCustomObject]@{
                ResultCode   = $ResultCode
                HexCode      = $null
                Message      = 'Unable to parse result code'
                Source       = 'Unknown'
                ConstantName = $null
                IsSuccess    = $null
                Facility     = $null
                FacilityCode = $null
                Meanings     = @()
            }
        }

        # Convert to unsigned for hex display (handle negative values properly)
        if ($codeValue -lt 0) {
            if ($codeValue -ge [int]::MinValue -and $codeValue -le [int]::MaxValue) {
                # Value fits in int32, use BitConverter for proper signed-to-unsigned conversion
                $bytes = [System.BitConverter]::GetBytes([int32]$codeValue)
                $unsignedValue = [System.BitConverter]::ToUInt32($bytes, 0)
                $hexCode = '0x{0:X8}' -f $unsignedValue
            }
            else {
                # Large negative value outside int32 range, display as int64 hex
                $hexCode = '0x{0:X16}' -f $codeValue
            }
        }
        else {
            $hexCode = '0x{0:X8}' -f $codeValue
        }

        Write-Verbose "Processing result code: $codeValue ($hexCode)"

        # Build the meanings array
        $meanings = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Tier 1: Check Task Scheduler lookup table first
        # Try int64 lookup first (for SCHED_E_* codes with values > int32 max)
        # Then try int32 lookup (for SCHED_S_* codes stored as int32 keys)
        $taskSchedulerMatch = $script:TaskSchedulerCodes[[int64]$codeValue]
        if (-not $taskSchedulerMatch -and $codeValue -ge [int]::MinValue -and $codeValue -le [int]::MaxValue) {
            $taskSchedulerMatch = $script:TaskSchedulerCodes[[int]$codeValue]
        }
        if ($taskSchedulerMatch) {
            Write-Verbose "Found Task Scheduler code: $($taskSchedulerMatch.Name)"
            $meanings.Add([PSCustomObject]@{
                Source       = 'TaskScheduler'
                ConstantName = $taskSchedulerMatch.Name
                Message      = $taskSchedulerMatch.Message
                IsSuccess    = $taskSchedulerMatch.IsSuccess
            })
        }

        # Parse HRESULT structure for additional information
        # HRESULT structure:
        # Bit 31: Severity (1=failure, 0=success)
        # Bit 30: Reserved
        # Bit 29: Customer (1=customer-defined, 0=Microsoft-defined)
        # Bits 16-28: Facility code (13 bits)
        # Bits 0-15: Error code (16 bits)

        $isFailure = ($codeValue -band 0x80000000) -ne 0
        $facilityCode = [int](($codeValue -shr 16) -band 0x1FFF)
        $errorCode = [int]($codeValue -band 0xFFFF)

        $facilityName = $script:FacilityCodes[$facilityCode]
        if (-not $facilityName) {
            $facilityName = "FACILITY_$facilityCode"
        }

        Write-Verbose "HRESULT: IsFailure=$isFailure, Facility=$facilityName ($facilityCode), ErrorCode=$errorCode"

        # Tier 2: HRESULT decoding - translate Win32 error code if applicable
        if ($facilityCode -eq 7) {
            # FACILITY_WIN32 - extract and translate the Win32 error code
            Write-Verbose "Detected FACILITY_WIN32, extracting error code: $errorCode"
            try {
                $win32Exception = [System.ComponentModel.Win32Exception]::new($errorCode)
                $win32Message = $win32Exception.Message

                # Only add if different from Task Scheduler message (avoid duplicates)
                $isDuplicate = $meanings | Where-Object { $_.Message -eq $win32Message }
                if (-not $isDuplicate) {
                    $meanings.Add([PSCustomObject]@{
                        Source       = 'Win32'
                        ConstantName = $null
                        Message      = $win32Message
                        IsSuccess    = -not $isFailure
                    })
                    Write-Verbose "Added Win32 translation: $win32Message"
                }
            }
            catch {
                Write-Verbose "Failed to translate Win32 error code $errorCode : $_"
            }
        }
        elseif ($codeValue -ne 0 -and -not $taskSchedulerMatch -and $codeValue -gt 0 -and $codeValue -le 65535) {
            # Tier 3: Small positive integers - try direct Win32 translation
            Write-Verbose "Trying direct Win32 translation for small code: $codeValue"
            try {
                $win32Exception = [System.ComponentModel.Win32Exception]::new([int]$codeValue)
                $win32Message = $win32Exception.Message

                # Check if the message is just the number (no translation available)
                if ($win32Message -ne $codeValue.ToString()) {
                    $meanings.Add([PSCustomObject]@{
                        Source       = 'Win32'
                        ConstantName = $null
                        Message      = $win32Message
                        IsSuccess    = $codeValue -eq 0
                    })
                    Write-Verbose "Added direct Win32 translation: $win32Message"
                }
            }
            catch {
                Write-Verbose "Failed direct Win32 translation for $codeValue : $_"
            }
        }

        # Special case: code 0 is always success
        if ($codeValue -eq 0 -and $meanings.Count -eq 0) {
            Write-Verbose 'Adding success message for code 0'
            $meanings.Add([PSCustomObject]@{
                Source       = 'Win32'
                ConstantName = 'ERROR_SUCCESS'
                Message      = 'The operation completed successfully'
                IsSuccess    = $true
            })
        }

        # Build the result object
        $primaryMeaning = $meanings | Select-Object -First 1

        if ($primaryMeaning) {
            $result = [PSCustomObject]@{
                ResultCode   = $codeValue
                HexCode      = $hexCode
                Message      = $primaryMeaning.Message
                Source       = $primaryMeaning.Source
                ConstantName = $primaryMeaning.ConstantName
                IsSuccess    = $primaryMeaning.IsSuccess
                Facility     = $facilityName
                FacilityCode = $facilityCode
                Meanings     = [array]$meanings.ToArray()
            }
        }
        else {
            # Tier 4: Unknown code
            Write-Verbose "No translation found, returning as Unknown"
            $result = [PSCustomObject]@{
                ResultCode   = $codeValue
                HexCode      = $hexCode
                Message      = "Unknown result code: $hexCode"
                Source       = 'Unknown'
                ConstantName = $null
                IsSuccess    = -not $isFailure
                Facility     = $facilityName
                FacilityCode = $facilityCode
                Meanings     = [array]@()
            }
        }

        return $result
    }
}
