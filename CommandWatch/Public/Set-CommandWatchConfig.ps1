<#
.SYNOPSIS
    Persists default settings for Invoke-CommandWatch.

.DESCRIPTION
    Accepts a hashtable of defaults (Interval, NoTitle, NoWrap, NoClear, Width, LogPath) and writes
    them to the configuration file so future calls pick them up automatically. Existing values are
    merged with the provided hashtable.

.PARAMETER Defaults
    Hashtable of settings to persist. Use $null values to remove a key (e.g., LogPath).

.EXAMPLE
    Set-CommandWatchConfig -Defaults @{ Interval = 1.5; NoClear = $true }
    Persists a new default interval and disables Clear-Host unless overridden per invocation.
#>
function Set-CommandWatchConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Defaults
    )

    $current = Read-CommandWatchConfig
    foreach ($key in $Defaults.Keys) {
        $current[$key] = $Defaults[$key]
    }

    if ($PSCmdlet.ShouldProcess('CommandWatch configuration', 'Persist defaults')) {
        Write-CommandWatchConfig -Settings $current | Out-Null
    }

    return Get-CommandWatchConfig
}
