<#
.SYNOPSIS
    This function watches a command for completion with periodic checks.

.DESCRIPTION
    The Watch-Command function executes a specified command and monitors its status until it completes.
    It checks at user-defined intervals.

.PARAMETER commandTask
    The command to execute and monitor.

.PARAMETER waitTime
    Amount of time to wait between checks.

.PARAMETER waitInterval
    Chosen time interval to use with waitTime: 
    ms or MS or Milliseconds
    s or S or Seconds = Seconds
    m or M or Minutes = Minutes
    h or H or Hours = Hours 

.EXAMPLE
    Example to watch a ping to google.com for 5 seconds 
    Watch-Command -commandTask "ping google.com" -w 5 -i s

.NOTES
    Author: Michael Levesque
    This function demonstrates monitoring a task with a delay.
#>

function Watch-Command {
    param (
        [Alias("ct")]
        [Parameter(Mandatory=$true, HelpMessage="Specify the command to execute.")]
        [string]$commandTask,

        [Alias("w", "wait")]
        [Parameter(Mandatory=$true, HelpMessage="Specify the wait time.")]
        [int]$waitTime,

        [Alias("i", "interval")]
        [Parameter(Mandatory=$true, HelpMessage="Specify the wait interval: MS, Seconds, Minutes, or Hours.")]
        [ValidateSet("ms", "MS", "Milliseconds", "s", "S", "Seconds", "m", "M", "Minutes", "h", "H", "Hours")]
        [string]$waitInterval
    )

    # Determine sleep interval
    $sleepAction = {
        switch ($waitInterval.ToLower()) {
            "ms" { Start-Sleep -Milliseconds $waitTime }
            "s" { Start-Sleep -Seconds $waitTime }
            "m" { Start-Sleep -Minutes $waitTime }
            "h" { Start-Sleep -Seconds ($waitTime * 3600) }
            default { throw "Invalid wait interval provided." }
        }
    }

    # Loop until the user interrupts
    while ($true) {
        Write-Host "Running command: $commandTask"
        try {
            # Run the command and capture output
            $output = Invoke-Expression $commandTask
            if ($output) {
                # Output the result using PowerShell's default formatting system
                $output
            } else {
                Write-Host "No output returned from the command."
            }
        } catch {
            Write-Host "Error executing command: $_"
        }

        Write-Host "Waiting for the next interval..."
        & $sleepAction
        Clear-Host
    }
}