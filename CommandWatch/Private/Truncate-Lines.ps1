function Truncate-Lines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()] [string]$Text,
        [Parameter(Mandatory)] [int]$Width
    )

    $ellipsis = '...'
    $lines = $Text -split "`r?`n"
    foreach ($line in $lines) {
        if ($line.Length -gt $Width) {
            if ($Width -gt 1) {
                ($line.Substring(0, [Math]::Max(0, $Width - 1)) + $ellipsis)
            } else {
                ''
            }
        } else {
            $line
        }
    }
}
