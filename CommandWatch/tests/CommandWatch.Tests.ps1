<#
    Pester tests for CommandWatch module. Run via Invoke-Pester -Script '.\CommandWatch\tests'.
#>

$moduleManifest = Join-Path $PSScriptRoot '..\CommandWatch.psd1'
$invokeOncePath = Join-Path $PSScriptRoot '..\Private\Invoke-Once.ps1'

function New-CommandWatchTestConfigPath {
    Join-Path ([System.IO.Path]::GetTempPath()) ("CommandWatchTests_{0}.json" -f ([guid]::NewGuid()))
}

Describe 'Invoke-Once helper' {
    BeforeAll {
        . $invokeOncePath
    }

    It 'returns output and exit code for expression mode' {
        $result = Invoke-Once -Command "'helper-expr'"
        $result.Output | Should Match 'helper-expr'
        $result.ExitCode | Should Be 0
    }

    It 'returns exit code from exec mode' {
        $result = Invoke-Once -Command 'cmd.exe' -Args '/c','exit 3' -UseExec
        $result.ExitCode | Should Be 3
    }
}

Describe 'Invoke-CommandWatch public surface' {
    BeforeAll {
        $script:publicConfigPath = New-CommandWatchTestConfigPath
        $env:COMMANDWATCH_CONFIG_PATH = $script:publicConfigPath
        Remove-Item -LiteralPath $script:publicConfigPath -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    AfterAll {
        Remove-Item -LiteralPath $script:publicConfigPath -ErrorAction SilentlyContinue
        Remove-Item Env:COMMANDWATCH_CONFIG_PATH -ErrorAction SilentlyContinue
        Remove-Module CommandWatch -ErrorAction SilentlyContinue -Force
    }

    It 'exports expected alias' {
        (Get-Alias 'Watch-Command' -ErrorAction Stop).Definition | Should Be 'Invoke-CommandWatch'
    }

    It 'records expression parameter set metadata' {
        $result = Invoke-CommandWatch -Command "'binding-expr'" -Count 1 -NoTitle -NoClear -NoWrap -PassThru -InformationAction SilentlyContinue
        $payload = @($result)[0]
        $payload.ParameterSet | Should Be 'Expression'
        $payload.DisplayCommand | Should Be "'binding-expr'"
    }

    It 'records exec parameter set metadata' {
        $result = Invoke-CommandWatch -Command 'cmd.exe' -UseExec -Args '/c','exit 0' -Count 1 -NoTitle -NoClear -NoWrap -PassThru -InformationAction SilentlyContinue
        $payload = @($result)[0]
        $payload.ParameterSet | Should Be 'Exec'
        $payload.DisplayCommand | Should Be 'cmd.exe /c exit 0'
    }

    It 'accepts exec mode and returns PassThru objects' {
        $result = Invoke-CommandWatch -Command 'cmd.exe' -UseExec -Args '/c','exit 0' -Count 1 -NoTitle -NoClear -NoWrap -PassThru -InformationAction SilentlyContinue
        $result | Should Not BeNullOrEmpty
        (@($result)[0]).ExitCode | Should Be 0
        ((@($result)[0]).PSTypeNames -contains 'CommandWatch.TickResult') | Should Be $true
    }

    It 'supports disabling host effects for CI scenarios' {
        $result = Invoke-CommandWatch -Command "'ci-mode'" -Count 1 -NoTitle -NoClear -NoWrap -PassThru -InformationAction SilentlyContinue
        ((@($result)[0]).DisplayLines -join [Environment]::NewLine) | Should Match 'ci-mode'
    }

    It 'omits header rendering when -NoTitle is specified' {
        Mock -CommandName Format-Header -ModuleName CommandWatch
        Invoke-CommandWatch -Command "'headerless'" -Count 1 -NoTitle -NoClear -NoWrap -InformationAction SilentlyContinue | Out-Null
        Assert-MockCalled -CommandName Format-Header -ModuleName CommandWatch -Times 0
    }

    It 'keeps scheduled timestamps within acceptable skew' {
        $interval = 0.2
        $result = Invoke-CommandWatch -Command "'schedule-test'" -Count 3 -Interval $interval -Precise -NoTitle -NoClear -NoWrap -PassThru -InformationAction SilentlyContinue
        $ticks = @($result)
        $ticks.Count | Should Be 3
        $deltas = @()
        for ($i = 1; $i -lt $ticks.Count; $i++) {
            $deltas += ($ticks[$i].Timestamp - $ticks[$i-1].Timestamp).TotalSeconds
        }

        foreach ($delta in $deltas) {
            $delta | Should BeGreaterThan 0
            ([math]::Abs($delta - $interval)) | Should BeLessThan 0.26
        }
    }

    It 'honors legacy wait parameters' {
        $result = Invoke-CommandWatch -Command "'legacy-mode'" -waitTime 1 -waitInterval s -Count 1 -NoTitle -NoClear -NoWrap -PassThru -InformationAction SilentlyContinue
        (@($result)[0]).Iteration | Should Be 1
    }

    It 'produces diff metadata when -Differences is supplied' {
        $global:CommandWatchDiffCounter = 0
        $expr = '($global:CommandWatchDiffCounter = $global:CommandWatchDiffCounter + 1); "diff-$($global:CommandWatchDiffCounter)"'
        $result = Invoke-CommandWatch -Command $expr -Count 2 -NoTitle -NoClear -NoWrap -PassThru -Differences -InformationAction SilentlyContinue
        ((@($result)[1]).DiffLines -join [Environment]::NewLine) | Should Match '\+ diff-2'
        Remove-Variable -Name CommandWatchDiffCounter -Scope Global -ErrorAction SilentlyContinue
    }

    It 'exits when -ChangeExit is specified' {
        $global:CommandWatchChangeCounter = 0
        $expr = '($global:CommandWatchChangeCounter = $global:CommandWatchChangeCounter + 1); "val-$($global:CommandWatchChangeCounter)"'
        $result = Invoke-CommandWatch -Command $expr -Count 5 -NoTitle -NoClear -NoWrap -PassThru -ChangeExit -InformationAction SilentlyContinue
        (@($result)).Count | Should Be 2
        Remove-Variable -Name CommandWatchChangeCounter -Scope Global -ErrorAction SilentlyContinue
    }

    It 'emits informational reason when -ChangeExit stops execution' {
        $global:CommandWatchChangeInfo = 0
        $expr = '($global:CommandWatchChangeInfo = $global:CommandWatchChangeInfo + 1); "info-$($global:CommandWatchChangeInfo)"'
        $info = $null
        Invoke-CommandWatch -Command $expr -Count 5 -NoTitle -NoClear -NoWrap -PassThru -ChangeExit -InformationAction Continue -InformationVariable info | Out-Null
        $messages = @($info | ForEach-Object { $_.MessageData })
        ($messages | Where-Object { $_ -like '*-ChangeExit*' }).Count | Should BeGreaterThan 0
        (@($messages)[-1]) | Should Match 'reason: ChangeExit'
        Remove-Variable -Name CommandWatchChangeInfo -Scope Global -ErrorAction SilentlyContinue
    }

    It 'exits when -ErrorExit is specified' {
        $result = Invoke-CommandWatch -Command 'cmd.exe' -UseExec -Args '/c','exit 7' -Count 3 -NoTitle -NoClear -NoWrap -PassThru -ErrorExit -InformationAction SilentlyContinue
        (@($result)).Count | Should Be 1
        (@($result)[0]).ExitCode | Should Be 7
    }

    It 'emits informational reason when -ErrorExit stops execution' {
        $info = $null
        Invoke-CommandWatch -Command 'cmd.exe' -UseExec -Args '/c','exit 9' -Count 4 -NoTitle -NoClear -NoWrap -ErrorExit -InformationAction Continue -InformationVariable info | Out-Null
        $messages = @($info | ForEach-Object { $_.MessageData })
        ($messages | Where-Object { $_ -like '*-ErrorExit*9*' }).Count | Should BeGreaterThan 0
        (@($messages)[-1]) | Should Match 'reason: ErrorExit'
    }

    It 'stops once count iterations are reached and reports the reason' {
        $info = $null
        $result = Invoke-CommandWatch -Command "'count-check'" -Count 2 -NoTitle -NoClear -NoWrap -PassThru -InformationAction Continue -InformationVariable info
        (@($result)).Count | Should Be 2
        $messages = @($info | ForEach-Object { $_.MessageData })
        ($messages | Where-Object { $_ -like '*iteration count*' }).Count | Should BeGreaterThan 0
        (@($messages)[-1]) | Should Match 'reason: Count'
    }
}

Describe 'CommandWatch configuration' {
    BeforeAll {
        $script:configPath = New-CommandWatchTestConfigPath
        $env:COMMANDWATCH_CONFIG_PATH = $script:configPath
        Import-Module $moduleManifest -Force
    }

    AfterAll {
        Remove-Item -LiteralPath $script:configPath -ErrorAction SilentlyContinue
        Remove-Item Env:COMMANDWATCH_CONFIG_PATH -ErrorAction SilentlyContinue
        Remove-Module CommandWatch -ErrorAction SilentlyContinue -Force
    }

    It 'returns defaults when config is absent' {
        Remove-Item -LiteralPath $script:configPath -ErrorAction SilentlyContinue
        $cfg = Get-CommandWatchConfig
        $cfg.Defaults.Interval | Should Be 2
    }

    It 'persists overrides to disk' {
        $overrides = @{ Interval = 1.5; NoClear = $true; LogPath = (Join-Path ([System.IO.Path]::GetTempPath()) 'cw-log.txt') }
        Set-CommandWatchConfig -Defaults $overrides | Out-Null
        $cfg = Get-CommandWatchConfig
        $cfg.Defaults.Interval | Should Be 1.5
        $cfg.Defaults.NoClear | Should Be $true
        $cfg.Defaults.LogPath | Should Be $overrides.LogPath
    }

    It 'applies defaults to Invoke-CommandWatch and writes log' {
        $logFileName = 'cw-log-{0}.txt' -f ([guid]::NewGuid())
        $logPath = Join-Path ([System.IO.Path]::GetTempPath()) $logFileName
        Set-CommandWatchConfig -Defaults @{ LogPath = $logPath; NoTitle = $true; NoClear = $true; NoWrap = $true } | Out-Null
        Invoke-CommandWatch -Command "'cfg-test'" -Count 1 -PassThru -InformationAction SilentlyContinue | Out-Null
        Test-Path -LiteralPath $logPath | Should Be $true
        (Get-Content -LiteralPath $logPath) | Should Match 'cfg-test'
        Remove-Item -LiteralPath $logPath -ErrorAction SilentlyContinue
    }
}

Describe 'CommandWatch helper functions' {
    BeforeAll {
        Import-Module $moduleManifest -Force
    }

    AfterAll {
        Remove-Module CommandWatch -ErrorAction SilentlyContinue -Force
    }

    It 'formats headers with trimmed intervals and metadata' {
        InModuleScope CommandWatch {
            $header = Format-Header -Interval 2.3456 -Command 'pwsh.exe' -Timestamp '2025-01-01 00:00:00' -ExitCode 3 -Iteration 5
            $header
        } | Should Be 'Every 2.346s: pwsh.exe 2025-01-01 00:00:00 [exit:3] [iter:5]'
    }

    It 'detects added and removed lines for deterministic strings' {
        $diffEntries = InModuleScope CommandWatch {
            Get-CommandWatchDifference -Reference @('alpha','beta') -Current @('beta','gamma')
        }

        $added = @($diffEntries | Where-Object Type -eq 'Added').Text
        $removed = @($diffEntries | Where-Object Type -eq 'Removed').Text
        ($added -contains '+ gamma') | Should Be $true
        ($removed -contains '- alpha') | Should Be $true
    }
}
