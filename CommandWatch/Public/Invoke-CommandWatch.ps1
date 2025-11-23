<#
.SYNOPSIS
    Invoke a command repeatedly at a fixed interval (PowerShell equivalent of Linux watch).

.DESCRIPTION
    Runs either a PowerShell expression or an external executable on a schedule, refreshing the
    console each iteration (unless -NoClear) and printing a header with timing, exit status, and
    iteration count. Output can be truncated (-NoWrap), diffed against prior iterations
    (-Differences / -DifferencesPermanent), surfaced as colored changes (-Color), logged to disk
    (-LogPath), and emitted as rich objects (-PassThru) for automation. Defaults can be persisted
    via Set-CommandWatchConfig (queried with Get-CommandWatchConfig).

.PARAMETER Command
    The PowerShell expression or executable to run.

.PARAMETER UseExec
    Treat Command as an external executable and invoke it with the call operator (&) plus -Args.

.PARAMETER Args
    Arguments passed to the command when -UseExec is set.

.PARAMETER Interval
    Interval in seconds between executions. Alias: -n.

.PARAMETER Precise
    Retained for backward compatibility; precise stopwatch scheduling is now always enabled.

.PARAMETER Count
    Stop after the specified number of iterations.

.PARAMETER NoTitle
    Suppress the header output (still clears unless -NoClear is provided or stored as default).

.PARAMETER NoWrap
    Truncate long lines to the computed width using ellipsis instead of wrapping.

.PARAMETER NoClear
    Skip Clear-Host between iterations (useful for CI logs / transcript captures).

.PARAMETER StreamOutput
    Stream command output directly to the console as it arrives (native tools like ping show per-iteration results
    immediately). Incompatible with -Differences/-DifferencesPermanent because diff rendering requires buffered
    output.

.PARAMETER Differences
    Show only differences compared to the previous iteration, with +/- prefixes (optionally colorized).

.PARAMETER DifferencesPermanent
    Always diff against the first iteration (baseline) instead of the immediately previous iteration.

.PARAMETER ChangeExit
    Exit the loop as soon as the command output changes versus the prior iteration.

.PARAMETER ErrorExit
    Exit the loop immediately when the command returns a non-zero exit code.

.PARAMETER Beep
    Emit a console beep when a non-zero exit code is observed.

.PARAMETER Color
    Enable colored output for headers and diff lines (green additions, red removals).

.PARAMETER Width
    Override the console width when wrapping/truncating output.

.PARAMETER waitTime
    Legacy compatibility that maps to -Interval. Alias: -wait.

.PARAMETER waitInterval
    Legacy units for -waitTime (ms, s, m, h). Alias: -i.

.PARAMETER PassThru
    Emit per-iteration objects (command, output, exit code, diffs, timestamps) in addition to UI output.

.PARAMETER LogPath
    Append each iteration summary to the specified log file (directories are created automatically).

.NOTES
    Defaults can be persisted via Set-CommandWatchConfig / Get-CommandWatchConfig.

.EXAMPLE
    Invoke-CommandWatch -n 3 -UseExec ping -Args '-n','1','1.1.1.1' -StreamOutput
    Streams a single ICMP request every three seconds so each reply is visible for the full interval.

.EXAMPLE
    Invoke-CommandWatch -Command "Get-Process | Sort-Object CPU -Descending | Select -First 5" -Count 3 -PassThru -NoClear -NoTitle
    Captures three iterations of process snapshots without clearing or headers; returns objects for automation.

.EXAMPLE
    Invoke-CommandWatch -Command "'tick-' + (Get-Random)" -Differences -Color -ChangeExit
    Highlights line-level differences, colors additions/removals, and stops once the output changes.

.NOTES
    Backward compatibility alias: Watch-Command
#>
function Invoke-CommandWatch {
    [CmdletBinding(DefaultParameterSetName='Expression')]
    param (
        [Alias('ct')]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Expression')]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Exec')]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Legacy')]
        [string]$Command,

        [Parameter(ParameterSetName='Exec')]
        [switch]$UseExec,

        [Parameter(ParameterSetName='Exec')]
        [string[]]$Args,

        [Alias('n')]
        [double]$Interval = 2,

        [switch]$Precise,

        [Alias('t')]
        [switch]$NoTitle,

        [Alias('d')]
        [switch]$Differences,

        [switch]$DifferencesPermanent,

        [Alias('g')]
        [switch]$ChangeExit,

        [Alias('e')]
        [switch]$ErrorExit,

        [Alias('b')]
        [switch]$Beep,

        [Alias('c')]
        [switch]$Color,

        [Alias('w')]
        [switch]$NoWrap,

        [switch]$NoClear,

        [switch]$StreamOutput,

        [int]$Count,

        [int]$Width,

        # Legacy compatibility (maps to -Interval). Note: -w alias from legacy is not reused.
        [Alias('wait')]
        [Parameter(ParameterSetName='Legacy')]
        [int]$waitTime,

        [Alias('i')]
        [Parameter(ParameterSetName='Legacy')]
        [ValidateSet('ms','milliseconds','s','seconds','m','minutes','h','hours')]
        [string]$waitInterval,

        [switch]$PassThru,

        [string]$LogPath
    )

    $configDefaults = @{}
    try {
        $config = Get-CommandWatchConfig -ErrorAction Stop
        if ($config -and $config.Defaults) {
            $configDefaults = $config.Defaults
        }
    } catch {
        $configDefaults = @{}
    }

    if (-not $PSBoundParameters.ContainsKey('Interval') -and $configDefaults.ContainsKey('Interval') -and $null -ne $configDefaults.Interval) {
        $Interval = [double]$configDefaults.Interval
    }
    if (-not $PSBoundParameters.ContainsKey('NoTitle') -and $configDefaults.ContainsKey('NoTitle') -and $configDefaults.NoTitle) {
        $NoTitle = $true
    }
    if (-not $PSBoundParameters.ContainsKey('NoWrap') -and $configDefaults.ContainsKey('NoWrap') -and $configDefaults.NoWrap) {
        $NoWrap = $true
    }
    if (-not $PSBoundParameters.ContainsKey('NoClear') -and $configDefaults.ContainsKey('NoClear') -and $configDefaults.NoClear) {
        $NoClear = $true
    }

    $widthFromConfig = $false
    if (-not $PSBoundParameters.ContainsKey('Width') -and $configDefaults.ContainsKey('Width') -and $null -ne $configDefaults.Width) {
        $Width = [int]$configDefaults.Width
        $widthFromConfig = $true
    }

    if (-not $PSBoundParameters.ContainsKey('LogPath') -and $configDefaults.ContainsKey('LogPath') -and $configDefaults.LogPath) {
        $LogPath = [string]$configDefaults.LogPath
    }

    $effectiveWidth = if ($PSBoundParameters.ContainsKey('Width') -or $widthFromConfig) { [int]$Width } else { try { $Host.UI.RawUI.BufferSize.Width } catch { 120 } }

    $legacyIntervalUsed = $false
    if ($PSBoundParameters.ContainsKey('waitTime')) {
        $legacyIntervalUsed = $true
        $unit = ($waitInterval | ForEach-Object { ($_ -as [string]) })
        switch ($unit.ToLower()) {
            'ms' { $Interval = [double]$waitTime / 1000 }
            'milliseconds' { $Interval = [double]$waitTime / 1000 }
            's' { $Interval = [double]$waitTime }
            'seconds' { $Interval = [double]$waitTime }
            'm' { $Interval = [double]$waitTime * 60 }
            'minutes' { $Interval = [double]$waitTime * 60 }
            'h' { $Interval = [double]$waitTime * 3600 }
            'hours' { $Interval = [double]$waitTime * 3600 }
            default { throw 'Invalid legacy wait interval provided.' }
        }
    }

    if ($legacyIntervalUsed) {
        Write-Warning 'Legacy parameters -waitTime/-waitInterval are deprecated; prefer -Interval/-n.'
    }

    $displayCmd = if ($PSCmdlet.ParameterSetName -eq 'Exec' -or $UseExec.IsPresent) {
        if ($Args) { "$Command $($Args -join ' ')" } else { $Command }
    } else { $Command }

    if ($StreamOutput -and ($Differences -or $DifferencesPermanent)) {
        throw '-StreamOutput cannot be combined with -Differences or -DifferencesPermanent.'
    }

    $diffMode = $Differences -or $DifferencesPermanent
    $diffModeLabel = if ($DifferencesPermanent) { 'Permanent' } elseif ($Differences) { 'Rolling' } else { 'None' }

    if ($PSBoundParameters.ContainsKey('Precise')) {
        Write-Verbose '-Precise scheduling is always enabled; switch retained for compatibility.'
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $nextDue = $sw.Elapsed.TotalSeconds
    $iteration = 0
    $lastExit = 0
    $stopReason = 'Completed'
    $previousOutputRaw = $null
    $previousLines = $null
    $baselineLines = $null

    try {
        while ($true) {
            $iteration++
            if (-not $NoClear) { Clear-Host }

            $timestamp = Get-Date

            if (-not $NoTitle) {
                $hdr = Format-Header -Interval $Interval -Command $displayCmd -Timestamp ($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) -ExitCode $lastExit -Iteration $iteration
                if ($Color) {
                    Write-Host $hdr -ForegroundColor Cyan
                } else {
                    Write-Host $hdr
                }
                Write-Host ''
            }

            try {
                $result = Invoke-Once -Command $Command -Args $Args -UseExec:($PSCmdlet.ParameterSetName -eq 'Exec' -or $UseExec.IsPresent) -Width $effectiveWidth -StreamOutput:$StreamOutput -ErrorAction Stop
            } catch {
                Write-Error -ErrorRecord $_
                $result = [pscustomobject]@{ Output = ($_ | Out-String -Width $effectiveWidth); ExitCode = 1 }
            }

            $lastExit = [int]$result.ExitCode

            if ($lastExit -ne 0 -and $Beep) {
                try { [console]::Beep() } catch { Write-Host "`a" }
            }

            $displayLines = if ($NoWrap) {
                @(Truncate-Lines -Text $result.Output -Width $effectiveWidth)
            } else {
                $result.Output -split "`r?`n"
            }

            if ($null -eq $displayLines) {
                $displayLines = @('')
            } elseif ($displayLines -isnot [System.Array]) {
                $displayLines = @($displayLines)
            }

            if ($displayLines.Count -eq 0) { $displayLines = @('') }

            if ($DifferencesPermanent -and -not $baselineLines) {
                $baselineLines = $displayLines
            }

            $diffEntries = @()
            $renderDiffEntries = $false
            $linesToRender = $displayLines

            if ($diffMode) {
                $referenceLines = if ($DifferencesPermanent) {
                    if ($iteration -gt 1) { $baselineLines } else { $null }
                } else {
                    $previousLines
                }

                if ($referenceLines) {
                    $diffEntries = @(Get-CommandWatchDifference -Reference $referenceLines -Current $displayLines)
                    if ($diffEntries.Count -gt 0) {
                        $renderDiffEntries = $true
                    } else {
                        $linesToRender = @('(no changes detected)')
                    }
                }
            }

            $alreadyStreamed = ($StreamOutput -and $result.PSObject.Properties.Match('Streamed').Count -gt 0 -and $result.Streamed)

            if (-not $alreadyStreamed) {
                if ($renderDiffEntries) {
                    foreach ($entry in $diffEntries) {
                        if ($Color) {
                            $fg = if ($entry.Type -eq 'Added') { 'Green' } else { 'Red' }
                            Write-Host $entry.Text -ForegroundColor $fg
                        } else {
                            Write-Host $entry.Text
                        }
                    }
                } else {
                    foreach ($line in $linesToRender) {
                        Write-Host $line
                    }
                }
            }

            $hasChanged = $false
            if ($iteration -gt 1) {
                $hasChanged = ($result.Output -ne $previousOutputRaw)
            }
            $previousOutputRaw = $result.Output
            $previousLines = $displayLines

            if ($PassThru -or $LogPath) {
                $payload = [pscustomobject]@{
                    Command        = $Command
                    DisplayCommand = $displayCmd
                    Output         = $result.Output
                    DisplayLines   = $displayLines
                    DiffLines      = if ($diffEntries) { $diffEntries.Text } else { @() }
                    DiffMode       = $diffModeLabel
                    ExitCode       = $lastExit
                    Iteration      = $iteration
                    Timestamp      = $timestamp
                    ParameterSet   = $PSCmdlet.ParameterSetName
                }

                $payload.PSObject.TypeNames.Insert(0, 'CommandWatch.TickResult')

                if ($PassThru) {
                    Write-Output $payload
                }

                if ($LogPath) {
                    try {
                        $logDir = Split-Path -Parent $LogPath
                        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
                            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                        }
                        $line = '{0:o} {1} [exit:{2}] [iter:{3}]' -f $payload.Timestamp, $payload.DisplayCommand, $payload.ExitCode, $payload.Iteration
                        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
                    } catch {
                        Write-Warning ('Unable to write log file: {0}' -f $_.Exception.Message)
                    }
                }
            }

            $shouldBreak = $false
            if ($ErrorExit -and $lastExit -ne 0) {
                $shouldBreak = $true
                $stopReason = 'ErrorExit'
            } elseif ($ChangeExit -and $hasChanged) {
                $shouldBreak = $true
                $stopReason = 'ChangeExit'
            } elseif ($Count -gt 0 -and $iteration -ge $Count) {
                $shouldBreak = $true
                $stopReason = 'Count'
            }

            if ($shouldBreak) {
                switch ($stopReason) {
                    'ErrorExit' {
                        Write-Information ('CommandWatch stopping due to -ErrorExit (exit code {0}).' -f $lastExit)
                    }
                    'ChangeExit' {
                        Write-Information 'CommandWatch stopping due to -ChangeExit (output changed).'
                    }
                    'Count' {
                        Write-Information 'CommandWatch stopping because the requested iteration count was reached.'
                    }
                }
                break
            }

            if ($Interval -le 0) {
                $nextDue = $sw.Elapsed.TotalSeconds
                continue
            }

            $nextDue += [double]$Interval
            Wait-CommandWatchInterval -Stopwatch $sw -NextDueSeconds $nextDue
        }
    }
    finally {
        if ($iteration -gt 0) {
            $infoMessage = 'CommandWatch finished after {0} iteration(s); last exit code {1}; reason: {2}.' -f $iteration, $lastExit, $stopReason
            Write-Information $infoMessage
        }
    }
}

# Back-compat alias for legacy entry point
Set-Alias -Name 'Watch-Command' -Value 'Invoke-CommandWatch' -Force
Set-Alias -Name 'watch' -Value 'Invoke-CommandWatch' -Force
