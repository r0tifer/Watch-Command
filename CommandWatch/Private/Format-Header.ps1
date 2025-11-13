function Format-Header {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [double]$Interval,
        [Parameter(Mandatory)] [string]$Command,
        [Parameter(Mandatory)] [string]$Timestamp,
        [Parameter(Mandatory)] [int]$ExitCode,
        [Parameter(Mandatory)] [int]$Iteration
    )

    $iv = [double]::Parse([string]$Interval).ToString('0.###')
    return ('Every {0}s: {1} {2} [exit:{3}] [iter:{4}]' -f $iv, $Command, $Timestamp, $ExitCode, $Iteration)
}

