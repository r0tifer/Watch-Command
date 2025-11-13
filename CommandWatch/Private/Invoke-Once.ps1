function Invoke-Once {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Command,
        [string[]]$Args,
        [switch]$UseExec,
        [int]$Width = 120,
        [switch]$StreamOutput
    )

    $global:LASTEXITCODE = $null

    if ($StreamOutput) {
        $lines = New-Object System.Collections.Generic.List[string]

        $appendLines = {
            param($chunk, $lineWidth)

            if ($null -eq $chunk) { return }

            $text = if ($chunk -is [string]) { $chunk } else { $chunk | Out-String -Width $lineWidth }
            if ($null -eq $text) { return }

            $split = $text -split "`r?`n"
            for ($i = 0; $i -lt $split.Length; $i++) {
                $line = $split[$i]
                if ($i -eq ($split.Length - 1) -and [string]::IsNullOrWhiteSpace($line)) { continue }
                $lines.Add($line)
                Write-Host $line
            }
        }

        if ($UseExec) {
            & $Command @Args 2>&1 | ForEach-Object { & $appendLines $_ $Width }
        } else {
            Invoke-Expression $Command 2>&1 | ForEach-Object { & $appendLines $_ $Width }
        }

        $text = [string]::Join([Environment]::NewLine, $lines)
    } else {
        if ($UseExec) {
            $text = (& $Command @Args 2>&1 | Out-String -Width $Width)
        } else {
            $text = (Invoke-Expression $Command 2>&1 | Out-String -Width $Width)
        }
    }

    $code = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }

    [pscustomobject]@{
        Output   = $text
        ExitCode = $code
        Streamed = [bool]$StreamOutput
    }
}
