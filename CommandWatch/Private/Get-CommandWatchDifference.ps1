function Get-CommandWatchDifference {
    [CmdletBinding()]
    param(
        [Parameter()] [string[]]$Reference,
        [Parameter()] [string[]]$Current
    )

    if (-not $Reference) {
        return @()
    }

    $diff = Compare-Object -ReferenceObject $Reference -DifferenceObject $Current -IncludeEqual:$false -SyncWindow 0
    foreach ($entry in $diff) {
        $type = if ($entry.SideIndicator -eq '=>') { 'Added' } else { 'Removed' }
        $prefix = if ($type -eq 'Added') { '+' } else { '-' }
        [pscustomobject]@{
            Type = $type
            Text = '{0} {1}' -f $prefix, ($entry.InputObject)
        }
    }
}
