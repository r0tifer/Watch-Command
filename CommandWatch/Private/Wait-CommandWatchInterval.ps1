if (-not (Get-Variable -Name CommandWatchIntervalWaitHandle -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CommandWatchIntervalWaitHandle = New-Object System.Threading.ManualResetEventSlim($false)
}

function Wait-CommandWatchInterval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Diagnostics.Stopwatch]$Stopwatch,
        [Parameter(Mandatory)][double]$NextDueSeconds
    )

    $waitHandle = $script:CommandWatchIntervalWaitHandle
    while ($true) {
        $remaining = $NextDueSeconds - $Stopwatch.Elapsed.TotalSeconds
        if ($remaining -le 0) { break }

        $timeoutMs = [Math]::Min([int][Math]::Ceiling($remaining * 1000), 200)
        if ($timeoutMs -lt 1) { $timeoutMs = 1 }

        $waitHandle.Wait([TimeSpan]::FromMilliseconds($timeoutMs)) | Out-Null
    }
}
