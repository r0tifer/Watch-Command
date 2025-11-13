# CommandWatch

CommandWatch is a PowerShell module that mimics the Linux `watch` command: it executes an expression or external program on an interval, clears the screen (unless you opt out), and prints a rich header with timing, exit status, and iteration info. Output can be wrapped or truncated per your preference, and `-PassThru` lets you capture results for automation/CI.

- Public commands: `Invoke-CommandWatch`, `Get-CommandWatchConfig`, `Set-CommandWatchConfig`
- Legacy-friendly alias: `Watch-Command`

## Module layout

```
CommandWatch/
|-- CommandWatch.psd1   # manifest (explicit exports, metadata)
|-- CommandWatch.psm1   # lightweight loader (dot-sources Private/Public)
|-- Public/             # exported functions
|-- Private/            # internal helpers
|-- formats/, types/    # ps1xml stubs for future views/types
|-- en-US/              # external help stub
|-- tests/              # Pester tests
`-- examples/           # runnable samples
```

The loader (`CommandWatch.psm1`) sets strict mode, dot-sources helpers first, then public functions, and exports the function names discovered along with any aliases defined in those scripts. The manifest (`CommandWatch.psd1`) explicitly lists the exported function and alias for faster auto-loading.

## Install (local dev)

Import straight from the manifest (ensures the loader + manifest metadata are honored):

```powershell
Import-Module (Join-Path $PWD 'CommandWatch\CommandWatch.psd1') -Force
```

## Usage

```powershell
Invoke-CommandWatch -n 1.5 -UseExec -- ping 1.1.1.1
Invoke-CommandWatch -n 2 -t -- Get-Process
# Back-compat alias
Watch-Command -n 2 -- Get-Service
Invoke-CommandWatch -Command "'tick-' + (Get-Random)" -Differences -Color -ChangeExit
```

## Parameters (highlight)
- `-UseExec` with `-Args` to run external commands via `&`
- `-Precise` (back-compat only) — precise stopwatch scheduling is always enabled now
- `-NoTitle` to suppress the header
- `-NoWrap` to truncate lines to the calculated width (ASCII ellipsis)
- `-NoClear` to avoid `Clear-Host` for CI logs
- `-Count` to stop after N iterations
- `-PassThru` to emit rich objects per tick (command, output, exit code, iteration, timestamp)
- `-Differences` / `-DifferencesPermanent` to highlight changes (optionally colorized with `-Color`)
- `-ChangeExit` to stop on change and `-ErrorExit`/`-Beep` for error handling
- `-LogPath` to append timestamped summaries per iteration
- Legacy interval mapping via `-waitTime` + `-waitInterval` (emits a warning; prefer `-Interval`/`-n`)

## Tests & linting
- Run Pester tests: `Invoke-Pester -Script '.\CommandWatch\tests'`
- Run ScriptAnalyzer: `Invoke-ScriptAnalyzer -Path .\CommandWatch -Settings .\.config\PSScriptAnalyzerSettings.psd1`

## Tests and examples
- `tests\CommandWatch.Tests.ps1` contains helper + command coverage (including config + PassThru objects).
- `examples\examples.ps1` demonstrates both expression and exec usage.

## Configuration & logging
- `Get-CommandWatchConfig` shows the resolved config path and defaults.
- `Set-CommandWatchConfig -Defaults @{ Interval = 1.5; NoClear = $true }` persists preferred settings to `%APPDATA%\CommandWatch\config.json` (overridable via `COMMANDWATCH_CONFIG_PATH`).
- `Invoke-CommandWatch -LogPath logs\watch.log` appends timestamped summaries per iteration. Store a default log path via the config API.

## Custom formatting
PassThru objects are tagged with the `CommandWatch.TickResult` type name, and `formats\CommandWatch.Format.ps1xml` defines a table view showing timestamp, command, exit code, and iteration.
