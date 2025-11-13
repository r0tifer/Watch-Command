function Invoke-Once {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Command,
        [string[]]$Args,
        [switch]$UseExec,
        [int]$Width = 120
    )

    $global:LASTEXITCODE = $null
    if ($UseExec) {
        $text = (& $Command @Args 2>&1 | Out-String -Width $Width)
    } else {
        $text = (Invoke-Expression $Command 2>&1 | Out-String -Width $Width)
    }
    $code = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }
    [pscustomobject]@{ Output = $text; ExitCode = $code }
}

